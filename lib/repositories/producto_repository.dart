import 'package:ada_app/models/producto.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

/// Repository para manejo de productos
/// Estructura de tabla productos actualizada:
/// - id INTEGER PRIMARY KEY
/// - codigo TEXT
/// - codigo_barras TEXT
/// - nombre TEXT NULL
/// - categoria TEXT
abstract class ProductoRepository {
  /// Obtener todos los productos disponibles
  Future<List<Producto>> obtenerProductosDisponibles();

  /// Buscar productos por término (código, nombre o código de barras)
  Future<List<Producto>> buscarProductos(String searchTerm);

  /// Obtener producto por código específico
  Future<Producto?> obtenerProductoPorCodigo(String codigo);

  /// Obtener productos por categoría (para productos de reemplazo)
  Future<List<Producto>> obtenerProductosPorCategoria(String categoria, {int? excluirId}); // 👈 CAMBIO: usar ID

  /// Obtener total de productos
  Future<int> contarProductos();

  /// Guardar productos desde el servidor
  Future<int> guardarProductosDesdeServidor(List<Map<String, dynamic>> productos);

  /// Limpiar todos los productos locales
  Future<void> limpiarProductosLocales();
}

class ProductoRepositoryImpl implements ProductoRepository {
  final DatabaseHelper _dbHelper;
  static final Logger _logger = Logger();

  ProductoRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Logger get logger => _logger;


  @override
  Future<List<Producto>> obtenerProductosDisponibles() async {
    try {
      _logger.d('🔍 Obteniendo productos disponibles...');

      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        orderBy: 'nombre ASC',
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();
      _logger.d('✅ ${productos.length} productos disponibles obtenidos');

      return productos;
    } catch (e) {
      _logger.e('❌ Error obteniendo productos disponibles: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_disponibles',
        errorMessage: 'Error obteniendo productos disponibles: $e',
      );

      return [];
    }
  }

  @override
  Future<List<Producto>> buscarProductos(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _logger.d('⚠️ Término de búsqueda vacío');
      return [];
    }

    try {
      _logger.d('🔍 Buscando productos con término: "$searchTerm"');

      final db = await _dbHelper.database;
      final searchLower = '%${searchTerm.toLowerCase()}%';

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: '''
          (LOWER(codigo) LIKE ? OR 
           LOWER(nombre) LIKE ? OR 
           LOWER(codigo_barras) LIKE ?)
        ''',
        whereArgs: [searchLower, searchLower, searchLower],
        orderBy: 'nombre ASC',
        limit: 50,
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();
      _logger.d('✅ ${productos.length} productos encontrados para "$searchTerm"');

      return productos;
    } catch (e) {
      _logger.e('❌ Error buscando productos con término "$searchTerm": $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'buscar_productos',
        errorMessage: 'Error buscando productos con término "$searchTerm": $e',
      );

      return [];
    }
  }

  @override
  Future<Producto?> obtenerProductoPorCodigo(String codigo) async {
    try {
      _logger.d('🔍 Obteniendo producto por código: $codigo');

      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo = ?',
        whereArgs: [codigo],
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.d('⚠️ Producto con código "$codigo" no encontrado');
        return null;
      }

      final producto = Producto.fromMap(maps.first);
      _logger.d('✅ Producto encontrado: ${producto.displayName}');

      return producto;
    } catch (e) {
      _logger.e('❌ Error obteniendo producto por código $codigo: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_codigo',
        errorMessage: 'Error obteniendo producto por código "$codigo": $e',
      );

      return null;
    }
  }

  @override
  Future<List<Producto>> obtenerProductosPorCategoria(
      String categoria, {
        int? excluirId, // 👈 CAMBIO: Usar ID en lugar de código
      }) async {
    _logger.d('🔍 Obteniendo productos de categoría: $categoria (excluyendo ID: ${excluirId ?? "ninguno"})');

    try {
      final db = await _dbHelper.database;

      // ✅ Construir query dinámicamente
      String whereClause = 'categoria = ?';
      List<dynamic> whereArgs = [categoria];

      if (excluirId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excluirId);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'nombre ASC',
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();
      _logger.d('✅ ${productos.length} productos encontrados en categoría "$categoria"');

      return productos;
    } catch (e) {
      _logger.e('❌ Error obteniendo productos por categoría: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_categoria',
        errorMessage: 'Error obteniendo productos de categoría "$categoria": $e',
      );

      return [];
    }
  }

  @override
  Future<int> contarProductos() async {
    try {
      _logger.d('🔍 Contando productos...');

      final db = await _dbHelper.database;

      final resultado = await db.rawQuery(
        'SELECT COUNT(*) as total FROM productos',
      );

      final total = resultado.first['total'] as int? ?? 0;
      _logger.d('✅ Total de productos: $total');

      return total;
    } catch (e) {
      _logger.e('❌ Error contando productos: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'contar_productos',
        errorMessage: 'Error contando productos: $e',
      );

      return 0;
    }
  }

  @override
  Future<int> guardarProductosDesdeServidor(List<Map<String, dynamic>> productos) async {
    if (productos.isEmpty) {
      _logger.d('⚠️ No hay productos para guardar');
      return 0;
    }

    try {
      _logger.i('💾 Guardando ${productos.length} productos desde servidor...');

      // Usar vaciarEInsertar para reemplazar todos los datos
      await _dbHelper.vaciarEInsertar('productos', productos);

      _logger.i('✅ ${productos.length} productos guardados correctamente');
      return productos.length;

    } catch (e) {
      _logger.e('❌ Error guardando productos desde servidor: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'guardar_desde_servidor',
        errorMessage: 'Error guardando ${productos.length} productos desde servidor: $e',
      );

      throw Exception('Error guardando productos: $e');
    }
  }

  @override
  Future<void> limpiarProductosLocales() async {
    try {
      _logger.i('🗑️ Limpiando productos locales...');

      final db = await _dbHelper.database;
      await db.delete('productos');

      _logger.i('✅ Productos locales eliminados');
    } catch (e) {
      _logger.e('❌ Error limpiando productos locales: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'limpiar_locales',
        errorMessage: 'Error limpiando productos locales: $e',
      );

      throw Exception('Error limpiando productos: $e');
    }
  }

  // ========== MÉTODOS ADICIONALES DE UTILIDAD ==========

  /// Verificar si existe un producto con el código dado
  Future<bool> existeProductoConCodigo(String codigo) async {
    try {
      final producto = await obtenerProductoPorCodigo(codigo);
      return producto != null;
    } catch (e) {
      _logger.e('❌ Error verificando existencia de producto $codigo: $e');
      return false;
    }
  }

  /// Obtener producto por código de barras
  Future<Producto?> obtenerProductoPorCodigoBarras(String codigoBarras) async {
    try {
      _logger.d('🔍 Obteniendo producto por código de barras: $codigoBarras');

      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo_barras = ?',
        whereArgs: [codigoBarras],
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.d('⚠️ Producto con código de barras "$codigoBarras" no encontrado');
        return null;
      }

      final producto = Producto.fromMap(maps.first);
      _logger.d('✅ Producto encontrado por código de barras: ${producto.displayName}');

      return producto;
    } catch (e) {
      _logger.e('❌ Error obteniendo producto por código de barras $codigoBarras: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_codigo_barras',
        errorMessage: 'Error obteniendo producto por código de barras "$codigoBarras": $e',
      );

      return null;
    }
  }

  /// Obtener productos por lista de códigos
  Future<List<Producto>> obtenerProductosPorCodigos(List<String> codigos) async {
    if (codigos.isEmpty) return [];

    try {
      _logger.d('🔍 Obteniendo productos por ${codigos.length} códigos...');

      final db = await _dbHelper.database;
      final placeholders = List.filled(codigos.length, '?').join(',');

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo IN ($placeholders)',
        whereArgs: codigos,
        orderBy: 'nombre ASC',
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();
      _logger.d('✅ ${productos.length} productos encontrados');

      return productos;
    } catch (e) {
      _logger.e('❌ Error obteniendo productos por códigos: $e');
      return [];
    }
  }

  /// Obtener categorías disponibles
  Future<List<String>> obtenerCategorias() async {
    try {
      _logger.d('🔍 Obteniendo categorías...');

      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT categoria FROM productos WHERE categoria IS NOT NULL ORDER BY categoria ASC',
      );

      final categorias = maps
          .map((map) => map['categoria'] as String)
          .where((categoria) => categoria.isNotEmpty)
          .toList();

      _logger.d('✅ ${categorias.length} categorías encontradas');

      return categorias;
    } catch (e) {
      _logger.e('❌ Error obteniendo categorías: $e');
      return [];
    }
  }

  /// 👈 NUEVO: Obtener producto por ID
  Future<Producto?> obtenerProductoPorId(int id) async {
    try {
      _logger.d('🔍 Obteniendo producto por ID: $id');

      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.d('⚠️ Producto con ID $id no encontrado');
        return null;
      }

      final producto = Producto.fromMap(maps.first);
      _logger.d('✅ Producto encontrado: ${producto.displayName}');

      return producto;
    } catch (e) {
      _logger.e('❌ Error obteniendo producto por ID $id: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_id',
        errorMessage: 'Error obteniendo producto por ID $id: $e',
      );

      return null;
    }
  }
}
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

abstract class ProductoRepository {
  Future<List<Producto>> obtenerProductosDisponibles();

  Future<List<Producto>> buscarProductos(String searchTerm);

  Future<Producto?> obtenerProductoPorCodigo(String codigo);

  Future<Producto?> obtenerProductoPorId(int id);

  Future<List<Producto>> obtenerProductosPorCategoria(
    String categoria, {
    int? excluirId,
  });

  Future<int> contarProductos();

  Future<int> guardarProductosDesdeServidor(
    List<Map<String, dynamic>> productos,
  );

  Future<void> limpiarProductosLocales();
}

class ProductoRepositoryImpl implements ProductoRepository {
  final DatabaseHelper _dbHelper;

  ProductoRepositoryImpl({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<List<Producto>> obtenerProductosDisponibles() async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        orderBy: 'nombre ASC',
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();

      return productos;
    } catch (e) {
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
      return [];
    }

    try {
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

      return productos;
    } catch (e) {
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
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo = ?',
        whereArgs: [codigo],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      final producto = Producto.fromMap(maps.first);

      return producto;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_codigo',
        errorMessage: 'Error obteniendo producto por código "$codigo": $e',
      );

      return null;
    }
  }

  @override
  Future<Producto?> obtenerProductoPorId(int id) async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      final producto = Producto.fromMap(maps.first);

      return producto;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_id',
        errorMessage: 'Error obteniendo producto por ID $id: $e',
      );

      return null;
    }
  }

  @override
  Future<List<Producto>> obtenerProductosPorCategoria(
    String categoria, {
    int? excluirId,
  }) async {
    try {
      final db = await _dbHelper.database;

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

      return productos;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_categoria',
        errorMessage:
            'Error obteniendo productos de categoría "$categoria": $e',
      );

      return [];
    }
  }

  @override
  Future<int> contarProductos() async {
    try {
      final db = await _dbHelper.database;

      final resultado = await db.rawQuery(
        'SELECT COUNT(*) as total FROM productos',
      );

      final total = resultado.first['total'] as int? ?? 0;

      return total;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'contar_productos',
        errorMessage: 'Error contando productos: $e',
      );

      return 0;
    }
  }

  @override
  Future<int> guardarProductosDesdeServidor(
    List<Map<String, dynamic>> productos,
  ) async {
    if (productos.isEmpty) {
      return 0;
    }

    try {
      await _dbHelper.vaciarEInsertar('productos', productos);

      return productos.length;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'guardar_desde_servidor',
        errorMessage:
            'Error guardando ${productos.length} productos desde servidor: $e',
      );

      throw Exception('Error guardando productos: $e');
    }
  }

  @override
  Future<void> limpiarProductosLocales() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('productos');
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'limpiar_locales',
        errorMessage: 'Error limpiando productos locales: $e',
      );

      throw Exception('Error limpiando productos: $e');
    }
  }

  Future<bool> existeProductoConCodigo(String codigo) async {
    try {
      final producto = await obtenerProductoPorCodigo(codigo);
      return producto != null;
    } catch (e) {
      return false;
    }
  }

  Future<Producto?> obtenerProductoPorCodigoBarras(String codigoBarras) async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo_barras = ?',
        whereArgs: [codigoBarras],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      final producto = Producto.fromMap(maps.first);

      return producto;
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'productos',
        operation: 'obtener_por_codigo_barras',
        errorMessage:
            'Error obteniendo producto por código de barras "$codigoBarras": $e',
      );

      return null;
    }
  }

  Future<List<Producto>> obtenerProductosPorCodigos(
    List<String> codigos,
  ) async {
    if (codigos.isEmpty) return [];

    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(codigos.length, '?').join(',');

      final List<Map<String, dynamic>> maps = await db.query(
        'productos',
        where: 'codigo IN ($placeholders)',
        whereArgs: codigos,
        orderBy: 'nombre ASC',
      );

      final productos = maps.map((map) => Producto.fromMap(map)).toList();

      return productos;
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> obtenerCategorias() async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT categoria FROM productos WHERE categoria IS NOT NULL ORDER BY categoria ASC',
      );

      final categorias = maps
          .map((map) => map['categoria'] as String)
          .where((categoria) => categoria.isNotEmpty)
          .toList();

      return categorias;
    } catch (e) {
      return [];
    }
  }
}

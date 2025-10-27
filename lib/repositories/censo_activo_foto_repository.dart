import '../models/censo_activo_foto.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class CensoActivoFotoRepository extends BaseRepository<CensoActivoFoto> {
  final Logger _logger = Logger();
  final Uuid _uuid = Uuid();

  @override
  String get tableName => 'censo_activo_foto';

  @override
  CensoActivoFoto fromMap(Map<String, dynamic> map) => CensoActivoFoto.fromMap(map);

  @override
  Map<String, dynamic> toMap(CensoActivoFoto foto) => foto.toMap();

  @override
  String getDefaultOrderBy() => 'orden ASC';

  @override
  String getBuscarWhere() => 'censo_activo_id LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm];
  }

  @override
  String getEntityName() => 'CensoActivoFoto';

  // ========== MÉTODOS PRINCIPALES ==========

  /// Guardar foto para un censo
  Future<CensoActivoFoto> guardarFoto({
    required String censoActivoId,
    String? imagenPath,
    String? imagenBase64,
    int? imagenTamano,
    int? orden,
  }) async {
    try {
      final uuidId = _uuid.v4();
      final now = DateTime.now();

      // Si no se especifica orden, obtener el siguiente disponible
      final ordenFinal = orden ?? await _obtenerSiguienteOrden(censoActivoId);

      _logger.i('📸 Guardando foto para censo $censoActivoId');
      _logger.i('   UUID: $uuidId');
      _logger.i('   Orden: $ordenFinal');
      _logger.i('   Tamaño: $imagenTamano bytes');

      // ✅ LOGS DE DEBUG
      _logger.i('🔍 DEBUG guardarFoto - Parámetros recibidos:');
      _logger.i('🔍   imagenPath: $imagenPath');
      _logger.i('🔍   imagenBase64 != null: ${imagenBase64 != null}');
      _logger.i('🔍   imagenBase64 length: ${imagenBase64?.length ?? 0}');
      if (imagenBase64 != null && imagenBase64.isNotEmpty) {
        final preview = imagenBase64.length > 50 ? imagenBase64.substring(0, 50) : imagenBase64;
        _logger.i('🔍   imagenBase64 preview: $preview...');
      }

      final foto = CensoActivoFoto(
        id: uuidId,
        censoActivoId: censoActivoId,
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        imagenTamano: imagenTamano,
        orden: ordenFinal,
        fechaCreacion: now,
        estaSincronizado: false,
      );

      // ✅ LOG DESPUÉS DE CREAR EL OBJETO
      _logger.i('🔍 DEBUG guardarFoto - Objeto CensoActivoFoto creado:');
      _logger.i('🔍   foto.imagenBase64 != null: ${foto.imagenBase64 != null}');
      _logger.i('🔍   foto.imagenBase64 length: ${foto.imagenBase64?.length ?? 0}');

      final fotoMap = foto.toMap();

      // ✅ LOG DESPUÉS DE CREAR EL MAP
      _logger.i('🔍 DEBUG guardarFoto - Map para insertar:');
      _logger.i('🔍   fotoMap keys: ${fotoMap.keys.toList()}');
      _logger.i('🔍   fotoMap["imagen_base64"] != null: ${fotoMap['imagen_base64'] != null}');
      _logger.i('🔍   fotoMap["imagen_base64"] length: ${fotoMap['imagen_base64']?.toString().length ?? 0}');

      await dbHelper.insertar(tableName, fotoMap);

      _logger.i('✅ Foto guardada con UUID: $uuidId');
      return foto;

    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando foto: $e');
      _logger.e('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Obtener todas las fotos de un censo
  Future<List<CensoActivoFoto>> obtenerFotosPorCenso(String censoActivoId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'censo_activo_id = ?',
        whereArgs: [censoActivoId],
        orderBy: 'orden ASC',
      );

      final fotos = maps.map((map) => fromMap(map)).toList();
      _logger.i('📸 Encontradas ${fotos.length} fotos para censo $censoActivoId');
      return fotos;

    } catch (e) {
      _logger.e('Error obteniendo fotos por censo: $e');
      return [];
    }
  }

  /// Obtener foto específica por orden
  Future<CensoActivoFoto?> obtenerFotoPorOrden(String censoActivoId, int orden) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'censo_activo_id = ? AND orden = ?',
        whereArgs: [censoActivoId, orden],
        limit: 1,
      );

      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      _logger.e('Error obteniendo foto por orden: $e');
      return null;
    }
  }

  /// Obtener fotos pendientes de sincronización
  Future<List<CensoActivoFoto>> obtenerFotosPendientes() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = 0 AND imagen_base64 IS NOT NULL',
        orderBy: 'fecha_creacion ASC',
      );

      final fotos = maps.map((map) => fromMap(map)).toList();
      _logger.i('📸 Encontradas ${fotos.length} fotos pendientes de sincronización');
      return fotos;

    } catch (e) {
      _logger.e('Error obteniendo fotos pendientes: $e');
      return [];
    }
  }

  /// Obtener censo con todas sus fotos
  Future<CensoConFotos> obtenerCensoConFotos(String censoActivoId) async {
    try {
      final fotos = await obtenerFotosPorCenso(censoActivoId);
      return CensoConFotos(
        censoActivoId: censoActivoId,
        fotos: fotos,
      );
    } catch (e) {
      _logger.e('Error obteniendo censo con fotos: $e');
      return CensoConFotos(
        censoActivoId: censoActivoId,
        fotos: [],
      );
    }
  }

  // ========== MÉTODOS DE ACTUALIZACIÓN ==========

  /// Actualizar imagen Base64 de una foto
  Future<void> actualizarImagenBase64(String fotoId, String imagenBase64, int? tamano) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'imagen_base64': imagenBase64,
          'imagen_tamano': tamano,
          'sincronizado': 0, // Marcar como pendiente de sincronización
        },
        where: 'id = ?',
        whereArgs: [fotoId],
      );

      _logger.i('📸 Imagen Base64 actualizada para foto $fotoId');
    } catch (e) {
      _logger.e('Error actualizando imagen Base64: $e');
      rethrow;
    }
  }

  /// Marcar foto como sincronizada y limpiar Base64
  Future<void> marcarComoSincronizada(String fotoId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'imagen_base64': null, // Limpiar Base64 después de sincronizar
        },
        where: 'id = ?',
        whereArgs: [fotoId],
      );

      _logger.i('📸 Foto $fotoId marcada como sincronizada y Base64 limpiado');
    } catch (e) {
      _logger.e('Error marcando foto como sincronizada: $e');
      rethrow;
    }
  }

  /// Marcar múltiples fotos como sincronizadas
  Future<void> marcarMultiplesComoSincronizadas(List<String> fotoIds) async {
    try {
      final placeholders = fotoIds.map((_) => '?').join(',');
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'imagen_base64': null,
        },
        where: 'id IN ($placeholders)',
        whereArgs: fotoIds,
      );

      _logger.i('📸 ${fotoIds.length} fotos marcadas como sincronizadas');
    } catch (e) {
      _logger.e('Error marcando múltiples fotos como sincronizadas: $e');
      rethrow;
    }
  }

  /// Actualizar orden de una foto
  Future<void> actualizarOrden(String fotoId, int nuevoOrden) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {'orden': nuevoOrden},
        where: 'id = ?',
        whereArgs: [fotoId],
      );

      _logger.i('📸 Orden actualizado para foto $fotoId: $nuevoOrden');
    } catch (e) {
      _logger.e('Error actualizando orden de foto: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS DE ELIMINACIÓN ==========

  /// Eliminar foto específica
  Future<void> eliminarFoto(String fotoId) async {
    try {
      await dbHelper.eliminar(
        tableName,
        where: 'id = ?',
        whereArgs: [fotoId],
      );

      _logger.i('📸 Foto $fotoId eliminada');
    } catch (e) {
      _logger.e('Error eliminando foto: $e');
      rethrow;
    }
  }

  /// Eliminar todas las fotos de un censo
  Future<void> eliminarFotosPorCenso(String censoActivoId) async {
    try {
      final eliminadas = await dbHelper.eliminar(
        tableName,
        where: 'censo_activo_id = ?',
        whereArgs: [censoActivoId],
      );

      _logger.i('📸 $eliminadas fotos eliminadas para censo $censoActivoId');
    } catch (e) {
      _logger.e('Error eliminando fotos por censo: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS DE ESTADÍSTICAS ==========

  /// Contar fotos por estado de sincronización
  Future<Map<String, int>> contarPorSincronizacion() async {
    try {
      final pendientes = await obtenerFotosPendientes();
      final totalMaps = await dbHelper.consultar(tableName);
      final sincronizadas = totalMaps.length - pendientes.length;

      return {
        'total': totalMaps.length,
        'sincronizadas': sincronizadas,
        'pendientes': pendientes.length,
      };
    } catch (e) {
      _logger.e('Error contando fotos por sincronización: $e');
      return {
        'total': 0,
        'sincronizadas': 0,
        'pendientes': 0,
      };
    }
  }

  /// Obtener estadísticas por censo
  Future<Map<String, dynamic>> obtenerEstadisticasPorCenso(String censoActivoId) async {
    try {
      final fotos = await obtenerFotosPorCenso(censoActivoId);
      final pendientes = fotos.where((f) => !f.estaSincronizado).length;
      final tamanoTotal = fotos.fold<int>(0, (sum, foto) => sum + (foto.imagenTamano ?? 0));

      return {
        'total_fotos': fotos.length,
        'sincronizadas': fotos.length - pendientes,
        'pendientes': pendientes,
        'tamano_total_mb': (tamanoTotal / (1024 * 1024)).toStringAsFixed(1),
      };
    } catch (e) {
      _logger.e('Error obteniendo estadísticas por censo: $e');
      return {
        'total_fotos': 0,
        'sincronizadas': 0,
        'pendientes': 0,
        'tamano_total_mb': '0.0',
      };
    }
  }

  // ========== MÉTODOS UTILITARIOS ==========

  /// Obtener el siguiente orden disponible para un censo
  Future<int> _obtenerSiguienteOrden(String censoActivoId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'censo_activo_id = ?',
        whereArgs: [censoActivoId],
        orderBy: 'orden DESC',
        limit: 1,
      );

      if (maps.isEmpty) return 1;

      final ultimoOrden = maps.first['orden'] as int;
      return ultimoOrden + 1;
    } catch (e) {
      _logger.e('Error obteniendo siguiente orden: $e');
      return 1;
    }
  }

  /// Reordenar fotos de un censo
  Future<void> reordenarFotos(String censoActivoId, List<String> fotosIdsOrdenados) async {
    try {
      for (int i = 0; i < fotosIdsOrdenados.length; i++) {
        await actualizarOrden(fotosIdsOrdenados[i], i + 1);
      }

      _logger.i('📸 Fotos reordenadas para censo $censoActivoId');
    } catch (e) {
      _logger.e('Error reordenando fotos: $e');
      rethrow;
    }
  }

  /// Limpiar fotos antigas sincronizadas
  Future<void> limpiarFotosAntiguasSincronizadas({int diasAntiguedad = 30}) async {
    try {
      final fechaLimite = DateTime.now().subtract(Duration(days: diasAntiguedad));

      final eliminadas = await dbHelper.eliminar(
        tableName,
        where: 'fecha_creacion < ? AND sincronizado = 1 AND imagen_base64 IS NULL',
        whereArgs: [fechaLimite.toIso8601String()],
      );

      _logger.i('📸 $eliminadas fotos antigas eliminadas');
    } catch (e) {
      _logger.e('Error limpiando fotos antigas: $e');
      rethrow;
    }
  }

  /// Preparar fotos para sincronización
  Future<List<Map<String, dynamic>>> prepararFotosParaSincronizacion() async {
    try {
      final fotosPendientes = await obtenerFotosPendientes();
      return fotosPendientes.map((foto) => foto.toJson()).toList();
    } catch (e) {
      _logger.e('Error preparando fotos para sincronización: $e');
      return [];
    }
  }

  // ========== MÉTODOS DE COMPATIBILIDAD ==========

  /// Migrar fotos desde tabla censo_activo (para migración de datos)
  Future<int> migrarFotosDesdeTablaAntigua() async {
    int migradas = 0;

    try {
      _logger.i('🔄 Iniciando migración de fotos desde tabla censo_activo');

      // Consultar registros con imágenes en la tabla antigua
      final censosConImagenes = await dbHelper.consultar(
        'censo_activo',
        where: 'tiene_imagen = 1 OR tiene_imagen2 = 1',
      );

      for (final censo in censosConImagenes) {
        final censoId = censo['id'] as String;

        // Migrar primera imagen
        if (censo['tiene_imagen'] == 1) {
          await guardarFoto(
            censoActivoId: censoId,
            imagenPath: censo['imagen_path'],
            imagenBase64: censo['imagen_base64'],
            imagenTamano: censo['imagen_tamano'],
            orden: 1,
          );
          migradas++;
        }

        // Migrar segunda imagen
        if (censo['tiene_imagen2'] == 1) {
          await guardarFoto(
            censoActivoId: censoId,
            imagenPath: censo['imagen_path2'],
            imagenBase64: censo['imagen_base64_2'],
            imagenTamano: censo['imagen_tamano2'],
            orden: 2,
          );
          migradas++;
        }
      }

      _logger.i('✅ Migración completada: $migradas fotos migradas');
      return migradas;

    } catch (e) {
      _logger.e('❌ Error en migración de fotos: $e');
      return migradas;
    }
  }
}
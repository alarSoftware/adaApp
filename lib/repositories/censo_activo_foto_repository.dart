import '../models/censo_activo_foto.dart';
import '../utils/logger.dart';
import 'base_repository.dart';

import 'package:uuid/uuid.dart';

class CensoActivoFotoRepository extends BaseRepository<CensoActivoFoto> {
  final Uuid _uuid = Uuid();

  @override
  String get tableName => 'censo_activo_foto';

  @override
  CensoActivoFoto fromMap(Map<String, dynamic> map) =>
      CensoActivoFoto.fromMap(map);

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

      final fotoMap = foto.toMap();

      await dbHelper.insertar(tableName, fotoMap);

      return foto;
    } catch (e) {
      rethrow;
    }
  }

  /// Obtener todas las fotos de un censo
  Future<List<CensoActivoFoto>> obtenerFotosPorCenso(
    String censoActivoId,
  ) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'censo_activo_id = ?',
        whereArgs: [censoActivoId],
        orderBy: 'orden ASC',
      );

      final fotos = maps.map((map) => fromMap(map)).toList();

      return fotos;
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return []; }
  }

  /// Obtener foto específica por orden
  Future<CensoActivoFoto?> obtenerFotoPorOrden(
    String censoActivoId,
    int orden,
  ) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'censo_activo_id = ? AND orden = ?',
        whereArgs: [censoActivoId, orden],
        limit: 1,
      );

      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return null; }
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

      return fotos;
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return []; }
  }

  /// Obtener censo con todas sus fotos
  Future<CensoConFotos> obtenerCensoConFotos(String censoActivoId) async {
    try {
      final fotos = await obtenerFotosPorCenso(censoActivoId);
      return CensoConFotos(censoActivoId: censoActivoId, fotos: fotos);
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return CensoConFotos(censoActivoId: censoActivoId, fotos: []); }
  }

  // ========== MÉTODOS DE ACTUALIZACIÓN ==========

  /// Actualizar imagen Base64 de una foto
  Future<void> actualizarImagenBase64(
    String fotoId,
    String imagenBase64,
    int? tamano,
  ) async {
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
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar foto como sincronizada y limpiar Base64
  Future<void> marcarComoSincronizada(String fotoId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [fotoId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar múltiples fotos como sincronizadas
  Future<void> marcarMultiplesComoSincronizadas(List<String> fotoIds) async {
    try {
      final placeholders = fotoIds.map((_) => '?').join(',');
      await dbHelper.actualizar(
        tableName,
        {'sincronizado': 1, 'imagen_base64': null},
        where: 'id IN ($placeholders)',
        whereArgs: fotoIds,
      );
    } catch (e) {
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
    } catch (e) {
      rethrow;
    }
  }

  // ========== MÉTODOS DE ELIMINACIÓN ==========

  /// Eliminar foto específica
  Future<void> eliminarFoto(String fotoId) async {
    try {
      await dbHelper.eliminar(tableName, where: 'id = ?', whereArgs: [fotoId]);
    } catch (e) {
      rethrow;
    }
  }

  /// Eliminar todas las fotos de un censo
  Future<void> eliminarFotosPorCenso(String censoActivoId) async {
    try {
      await dbHelper.eliminar(
        tableName,
        where: 'censo_activo_id = ?',
        whereArgs: [censoActivoId],
      );
    } catch (e) {
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
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return {'total': 0, 'sincronizadas': 0, 'pendientes': 0}; }
  }

  /// Obtener estadísticas por censo
  Future<Map<String, dynamic>> obtenerEstadisticasPorCenso(
    String censoActivoId,
  ) async {
    try {
      final fotos = await obtenerFotosPorCenso(censoActivoId);
      final pendientes = fotos.where((f) => !f.estaSincronizado).length;
      final tamanoTotal = fotos.fold<int>(
        0,
        (sum, foto) => sum + (foto.imagenTamano ?? 0),
      );

      return {
        'total_fotos': fotos.length,
        'sincronizadas': fotos.length - pendientes,
        'pendientes': pendientes,
        'tamano_total_mb': (tamanoTotal / (1024 * 1024)).toStringAsFixed(1),
      };
    } catch (e) {
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
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return 1; }
  }

  /// Reordenar fotos de un censo
  Future<void> reordenarFotos(
    String censoActivoId,
    List<String> fotosIdsOrdenados,
  ) async {
    try {
      for (int i = 0; i < fotosIdsOrdenados.length; i++) {
        await actualizarOrden(fotosIdsOrdenados[i], i + 1);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Limpiar fotos antigas sincronizadas
  Future<void> limpiarFotosAntiguasSincronizadas({
    int diasAntiguedad = 30,
  }) async {
    try {
      final fechaLimite = DateTime.now().subtract(
        Duration(days: diasAntiguedad),
      );

      await dbHelper.eliminar(
        tableName,
        where:
            'fecha_creacion < ? AND sincronizado = 1 AND imagen_base64 IS NULL',
        whereArgs: [fechaLimite.toIso8601String()],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Preparar fotos para sincronización
  Future<List<Map<String, dynamic>>> prepararFotosParaSincronizacion() async {
    try {
      final fotosPendientes = await obtenerFotosPendientes();
      return fotosPendientes.map((foto) => foto.toJson()).toList();
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return []; }
  }

  // ========== MÉTODOS DE COMPATIBILIDAD ==========

  /// Migrar fotos desde tabla censo_activo (para migración de datos)
  Future<int> migrarFotosDesdeTablaAntigua() async {
    int migradas = 0;

    try {
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

      return migradas;
    } catch (e) { AppLogger.e("CENSO_ACTIVO_FOTO_REPOSITORY: Error", e); return migradas; }
  }
}

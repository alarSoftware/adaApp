// lib/repositories/dynamic_form_sync_repository.dart

import 'package:logger/logger.dart';
import '../services/database_helper.dart';
import 'dynamic_form_response_repository.dart';

/// Repository especializado en gestionar el estado de sincronización
/// de formularios dinámicos en la base de datos local
class DynamicFormSyncRepository {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DynamicFormResponseRepository _responseRepository = DynamicFormResponseRepository();

  String get _responseTableName => 'dynamic_form_response';
  String get _responseDetailTableName => 'dynamic_form_response_detail';
  String get _imageTableName => 'dynamic_form_response_image';

  // ==================== OBTENER RESPUESTAS PENDIENTES ====================

  /// Obtiene respuestas pendientes de sincronización
  Future<List<Map<String, dynamic>>> getPendingResponses() async {
    try {
      final pending = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'creation_date ASC',
      );

      _logger.i('📋 Respuestas pendientes: ${pending.length}');
      return pending;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas pendientes: $e');
      return [];
    }
  }

  /// Obtiene respuestas con error de sincronización
  Future<List<Map<String, dynamic>>> getErrorResponses() async {
    try {
      final errors = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ? OR (intentos_sync > ? AND sync_status != ?)',
        whereArgs: ['error', 0, 'synced'],
        orderBy: 'ultimo_intento_sync ASC',
      );

      _logger.i('⚠️ Respuestas con error: ${errors.length}');
      return errors;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas con error: $e');
      return [];
    }
  }

  /// Obtiene una respuesta específica por ID
  Future<Map<String, dynamic>?> getResponseById(String responseId) async {
    try {
      final results = await _dbHelper.consultar(
        _responseTableName,
        where: 'id = ?',
        whereArgs: [responseId],
        limit: 1,
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuesta $responseId: $e');
      return null;
    }
  }

  /// Obtiene los detalles de una respuesta
  Future<List<Map<String, dynamic>>> getResponseDetails(String responseId) async {
    try {
      return await _dbHelper.consultar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
        orderBy: 'dynamic_form_detail_id ASC',
      );
    } catch (e) {
      _logger.e('❌ Error obteniendo detalles: $e');
      return [];
    }
  }

  /// Obtiene las imágenes de una respuesta
  Future<List<Map<String, dynamic>>> getResponseImages(String responseId) async {
    try {
      // Obtener IDs de los detalles
      final details = await getResponseDetails(responseId);

      if (details.isEmpty) return [];

      final detailIds = details.map((d) => d['id']).toList();

      // Obtener imágenes usando los detail IDs
      final placeholders = detailIds.map((_) => '?').join(',');

      return await _dbHelper.consultarPersonalizada(
        'SELECT * FROM $_imageTableName WHERE dynamic_form_response_detail_id IN ($placeholders) ORDER BY orden ASC',
        detailIds,
      );
    } catch (e) {
      _logger.e('❌ Error obteniendo imágenes: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR ESTADO DE SINCRONIZACIÓN ====================

  /// Marca una respuesta como sincronizada
  Future<bool> markResponseAsSynced(String responseId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'sync_status': 'synced',
          'fecha_sincronizado': now,
          'mensaje_error_sync': null,
          'intentos_sync': 0,
          'ultimo_intento_sync': null,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.i('✅ Respuesta marcada como sincronizada: $responseId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error marcando respuesta como sincronizada: $e');
      return false;
    }
  }

  /// Marca un detalle como sincronizado
  Future<bool> markDetailAsSynced(String detailId) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseDetailTableName,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [detailId],
      );

      return updated > 0;
    } catch (e) {
      _logger.e('❌ Error marcando detalle como sincronizado: $e');
      return false;
    }
  }

  /// Marca todos los detalles de una respuesta como sincronizados
  Future<bool> markAllDetailsAsSynced(String responseId) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseDetailTableName,
        {'sync_status': 'synced'},
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.i('✅ ${updated} detalles marcados como sincronizados');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error marcando detalles como sincronizados: $e');
      return false;
    }
  }

  /// Marca una imagen como sincronizada
  Future<bool> markImageAsSynced(String imageId) async {
    try {
      final updated = await _dbHelper.actualizar(
        _imageTableName,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [imageId],
      );

      return updated > 0;
    } catch (e) {
      _logger.e('❌ Error marcando imagen como sincronizada: $e');
      return false;
    }
  }

  /// Marca todas las imágenes de una respuesta como sincronizadas
  Future<bool> markAllImagesAsSynced(String responseId) async {
    try {
      final details = await getResponseDetails(responseId);
      if (details.isEmpty) return true;

      final detailIds = details.map((d) => d['id']).toList();
      final placeholders = detailIds.map((_) => '?').join(',');

      final db = await _dbHelper.database;
      final updated = await db.rawUpdate(
        'UPDATE $_imageTableName SET sync_status = ? WHERE dynamic_form_response_detail_id IN ($placeholders)',
        ['synced', ...detailIds],
      );

      if (updated > 0) {
        _logger.i('✅ $updated imágenes marcadas como sincronizadas');
      }
      return true;
    } catch (e) {
      _logger.e('❌ Error marcando imágenes como sincronizadas: $e');
      return false;
    }
  }

  /// Marca una respuesta como error con mensaje
  Future<bool> markResponseAsError(String responseId, String errorMessage) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Obtener intentos actuales
      final current = await getResponseById(responseId);
      final intentosActuales = (current?['intentos_sync'] as int?) ?? 0;

      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'sync_status': 'error',
          'intentos_sync': intentosActuales + 1,
          'ultimo_intento_sync': now,
          'mensaje_error_sync': errorMessage,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.w('⚠️ Respuesta marcada como error: $responseId (intento ${intentosActuales + 1})');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error marcando respuesta como error: $e');
      return false;
    }
  }

  /// Actualiza el intento de sincronización
  Future<bool> updateSyncAttempt(String responseId, int intentNumber, String timestamp) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'intentos_sync': intentNumber,
          'ultimo_intento_sync': timestamp,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      return updated > 0;
    } catch (e) {
      _logger.e('❌ Error actualizando intento de sync: $e');
      return false;
    }
  }

  /// Reinicia el contador de intentos de una respuesta
  Future<bool> resetSyncAttempts(String responseId) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'intentos_sync': 0,
          'ultimo_intento_sync': null,
          'mensaje_error_sync': null,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.i('🔄 Intentos reiniciados para: $responseId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error reiniciando intentos: $e');
      return false;
    }
  }

  // ==================== ESTADÍSTICAS ====================

  /// Obtiene estadísticas de sincronización
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final pending = await _countByStatus('pending');
      final synced = await _countByStatus('synced');
      final errors = await _countByStatus('error');
      final draft = await _countByStatus('draft');

      return {
        'pending': pending,
        'synced': synced,
        'error': errors,
        'draft': draft,
        'total': pending + synced + errors + draft,
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'pending': 0,
        'synced': 0,
        'error': 0,
        'draft': 0,
        'total': 0,
      };
    }
  }

  /// Cuenta respuestas por estado
  Future<int> _countByStatus(String status) async {
    try {
      final result = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ?',
        whereArgs: [status],
      );
      return result.length;
    } catch (e) {
      _logger.e('❌ Error contando por estado $status: $e');
      return 0;
    }
  }

  /// Verifica si hay respuestas pendientes
  Future<bool> hasPendingSync() async {
    try {
      final count = await _countByStatus('pending');
      return count > 0;
    } catch (e) {
      _logger.e('❌ Error verificando pendientes: $e');
      return false;
    }
  }

  // ==================== LIMPIEZA ====================

  /// Limpia respuestas sincronizadas antiguas
  Future<int> cleanOldSyncedResponses({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();

      final oldResponses = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ? AND fecha_sincronizado < ?',
        whereArgs: ['synced', cutoffDate],
      );

      int deleted = 0;
      for (var response in oldResponses) {
        final responseId = response['id'].toString();

        // Eliminar imágenes
        final details = await getResponseDetails(responseId);
        if (details.isNotEmpty) {
          final detailIds = details.map((d) => d['id']).toList();
          final placeholders = detailIds.map((_) => '?').join(',');

          final db = await _dbHelper.database;
          await db.rawDelete(
            'DELETE FROM $_imageTableName WHERE dynamic_form_response_detail_id IN ($placeholders)',
            detailIds,
          );
        }

        // Eliminar detalles
        await _dbHelper.eliminar(
          _responseDetailTableName,
          where: 'dynamic_form_response_id = ?',
          whereArgs: [responseId],
        );

        // Eliminar respuesta
        await _dbHelper.eliminar(
          _responseTableName,
          where: 'id = ?',
          whereArgs: [responseId],
        );

        deleted++;
      }

      if (deleted > 0) {
        _logger.i('🗑️ Respuestas antiguas eliminadas: $deleted');
      }
      return deleted;
    } catch (e) {
      _logger.e('❌ Error limpiando respuestas antiguas: $e');
      return 0;
    }
  }

  /// Limpia solo los borradores antiguos
  Future<int> cleanOldDrafts({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();

      final oldDrafts = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ? AND creation_date < ?',
        whereArgs: ['draft', cutoffDate],
      );

      int deleted = 0;
      for (var draft in oldDrafts) {
        final responseId = draft['id'].toString();

        // Eliminar todo relacionado
        final details = await getResponseDetails(responseId);
        if (details.isNotEmpty) {
          final detailIds = details.map((d) => d['id']).toList();
          final placeholders = detailIds.map((_) => '?').join(',');

          final db = await _dbHelper.database;
          await db.rawDelete(
            'DELETE FROM $_imageTableName WHERE dynamic_form_response_detail_id IN ($placeholders)',
            detailIds,
          );
        }

        await _dbHelper.eliminar(
          _responseDetailTableName,
          where: 'dynamic_form_response_id = ?',
          whereArgs: [responseId],
        );

        await _dbHelper.eliminar(
          _responseTableName,
          where: 'id = ?',
          whereArgs: [responseId],
        );

        deleted++;
      }

      if (deleted > 0) {
        _logger.i('🗑️ Borradores antiguos eliminados: $deleted');
      }
      return deleted;
    } catch (e) {
      _logger.e('❌ Error limpiando borradores: $e');
      return 0;
    }
  }

  Future<bool> syncTo(String responseId) async {
    try {
      _logger.i('🔄 Sincronizando respuesta: $responseId');

      // Importar el servicio de upload
      final uploadService = await _getDynamicFormUploadService();

      // Enviar al servidor
      final resultado = await uploadService.enviarRespuestaAlServidor(responseId);

      if (resultado['exito'] == true) {
        _logger.i('✅ Respuesta sincronizada: $responseId');
        return true;
      } else {
        _logger.w('⚠️ Error sincronizando: ${resultado['mensaje']}');
        await markResponseAsError(responseId, resultado['mensaje'] ?? 'Error desconocido');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error en syncTo: $e');
      await markResponseAsError(responseId, 'Excepción: $e');
      return false;
    }
  }

  /// Sincronizar todas las respuestas pendientes
  Future<Map<String, int>> syncAllPending() async {
    try {
      _logger.i('🔄 Sincronizando todas las respuestas pendientes...');

      // Obtener respuestas pendientes y con error (listas para reintentar)
      final pendientes = await getPendingResponses();
      final conError = await getErrorResponses();

      // Combinar ambas listas
      final todasPendientes = [...pendientes, ...conError];

      if (todasPendientes.isEmpty) {
        _logger.i('✅ No hay respuestas pendientes');
        return {'success': 0, 'failed': 0, 'total': 0};
      }

      _logger.i('📋 Total a sincronizar: ${todasPendientes.length}');

      int exitosos = 0;
      int fallidos = 0;

      final uploadService = await _getDynamicFormUploadService();

      for (final response in todasPendientes) {
        final responseId = response['id'].toString();

        try {
          final resultado = await uploadService.enviarRespuestaAlServidor(responseId);

          if (resultado['exito'] == true) {
            exitosos++;
            _logger.i('✅ Sincronizada: $responseId');
          } else {
            fallidos++;
            _logger.w('⚠️ Error: $responseId - ${resultado['mensaje']}');
          }
        } catch (e) {
          fallidos++;
          _logger.e('❌ Error sincronizando $responseId: $e');
        }
      }

      _logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'success': exitosos,
        'failed': fallidos,
        'total': todasPendientes.length,
      };
    } catch (e) {
      _logger.e('❌ Error en syncAllPending: $e');
      return {'success': 0, 'failed': 0, 'total': 0};
    }
  }

  /// Reintentar sincronización de una respuesta específica
  Future<bool> retrySyncResponse(String responseId) async {
    try {
      _logger.i('🔁 Reintentando sincronización: $responseId');

      // Verificar que la respuesta exista
      final response = await getResponseById(responseId);

      if (response == null) {
        _logger.e('❌ Respuesta no encontrada: $responseId');
        return false;
      }

      // Resetear intentos previos
      await resetSyncAttempts(responseId);

      // Reintentar envío
      final uploadService = await _getDynamicFormUploadService();
      final resultado = await uploadService.reintentarEnvioRespuesta(responseId);

      if (resultado['success'] == true) {
        _logger.i('✅ Reintento exitoso: $responseId');
        return true;
      } else {
        _logger.w('⚠️ Reintento fallido: ${resultado['error']}');
        await markResponseAsError(responseId, resultado['error'] ?? 'Error en reintento');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error en retrySyncResponse: $e');
      await markResponseAsError(responseId, 'Excepción en reintento: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================

  /// Obtener instancia del servicio de upload (lazy loading)
  Future<dynamic> _getDynamicFormUploadService() async {
    // Importar dinámicamente para evitar dependencias circulares
    // Nota: Dart no permite import dinámicos, así que usamos un enfoque diferente

    // OPCIÓN 1: Importar al inicio del archivo
    // import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
    // return DynamicFormUploadService();

    // OPCIÓN 2: Inyección de dependencia (mejor práctica)
    // Por ahora, importa al inicio del archivo y usa:
  }
}
import 'package:ada_app/services/data/database_helper.dart';
import '../services/dynamic_form/dynamic_form_upload_service.dart';

/// Repository especializado en gestionar el estado de sincronización
/// de formularios dinámicos en la base de datos local
class DynamicFormSyncRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

      return pending;
    } catch (e) {
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

      return errors;
    } catch (e) {
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
      return null;
    }
  }

  /// Obtiene los detalles de una respuesta
  Future<List<Map<String, dynamic>>> getResponseDetails(
    String responseId,
  ) async {
    try {
      return await _dbHelper.consultar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
        orderBy: 'dynamic_form_detail_id ASC',
      );
    } catch (e) {
      return [];
    }
  }

  /// Obtiene las imágenes de una respuesta
  Future<List<Map<String, dynamic>>> getResponseImages(
    String responseId,
  ) async {
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
        return true;
      }
      return false;
    } catch (e) {
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
        return true;
      }
      return false;
    } catch (e) {
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

      if (updated > 0) {}
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Marca una respuesta como error con mensaje
  Future<bool> markResponseAsError(
    String responseId,
    String errorMessage,
  ) async {
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
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Actualiza el intento de sincronización
  Future<bool> updateSyncAttempt(
    String responseId,
    int intentNumber,
    String timestamp,
  ) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {'intentos_sync': intentNumber, 'ultimo_intento_sync': timestamp},
        where: 'id = ?',
        whereArgs: [responseId],
      );

      return updated > 0;
    } catch (e) {
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
        return true;
      }
      return false;
    } catch (e) {
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
      return {'pending': 0, 'synced': 0, 'error': 0, 'draft': 0, 'total': 0};
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
      return 0;
    }
  }

  /// Verifica si hay respuestas pendientes
  Future<bool> hasPendingSync() async {
    try {
      final count = await _countByStatus('pending');
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  // ==================== LIMPIEZA ====================

  /// Limpia respuestas sincronizadas antiguas
  Future<int> cleanOldSyncedResponses({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysOld))
          .toIso8601String();

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

      if (deleted > 0) {}
      return deleted;
    } catch (e) {
      return 0;
    }
  }

  /// Limpia solo los borradores antiguos
  Future<int> cleanOldDrafts({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysOld))
          .toIso8601String();

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

      if (deleted > 0) {}
      return deleted;
    } catch (e) {
      return 0;
    }
  }

  // ==================== SINCRONIZACIÓN PRINCIPAL ====================

  /// ✅ CORREGIDO: Sincroniza una respuesta al servidor con manejo completo de estados
  Future<bool> syncTo(String responseId) async {
    try {
      // Obtener el servicio de upload
      final uploadService = await _getDynamicFormUploadService();

      // Enviar al servidor
      final resultado = await uploadService.enviarRespuestaAlServidor(
        responseId,
      );

      if (resultado['exito'] == true) {
        // ✅ Actualizar todos los estados locales después del éxito
        await markResponseAsSynced(responseId);
        await markAllDetailsAsSynced(responseId);
        await markAllImagesAsSynced(responseId);

        return true;
      } else {
        await markResponseAsError(
          responseId,
          resultado['mensaje'] ?? 'Error desconocido',
        );
        return false;
      }
    } catch (e) {
      await markResponseAsError(responseId, 'Excepción: $e');
      return false;
    }
  }

  /// Alias para compatibilidad
  Future<bool> syncToServer(String responseId) async {
    return await syncTo(responseId);
  }

  /// Sincronizar todas las respuestas pendientes
  Future<Map<String, int>> syncAllPending() async {
    try {
      // Obtener respuestas pendientes y con error (listas para reintentar)
      final pendientes = await getPendingResponses();
      final conError = await getErrorResponses();

      // Combinar ambas listas
      final todasPendientes = [...pendientes, ...conError];

      if (todasPendientes.isEmpty) {
        return {'success': 0, 'failed': 0, 'total': 0};
      }

      int exitosos = 0;
      int fallidos = 0;

      for (final response in todasPendientes) {
        final responseId = response['id'].toString();

        try {
          final success = await syncTo(responseId);
          if (success) {
            exitosos++;
          } else {
            fallidos++;
          }
        } catch (e) {
          fallidos++;
        }
      }

      return {
        'success': exitosos,
        'failed': fallidos,
        'total': todasPendientes.length,
      };
    } catch (e) {
      return {'success': 0, 'failed': 0, 'total': 0};
    }
  }

  /// Reintentar sincronización de una respuesta específica
  Future<bool> retrySyncResponse(String responseId) async {
    try {
      // Verificar que la respuesta exista
      final response = await getResponseById(responseId);

      if (response == null) {
        return false;
      }

      // Resetear intentos previos
      await resetSyncAttempts(responseId);

      // Reintentar envío usando syncTo
      return await syncTo(responseId);
    } catch (e) {
      await markResponseAsError(responseId, 'Excepción en reintento: $e');
      return false;
    }
  }

  // ==================== HELPER PRIVADO ====================

  /// Obtener instancia del servicio de upload (lazy loading)
  Future<DynamicFormUploadService> _getDynamicFormUploadService() async {
    return DynamicFormUploadService();
  }
}

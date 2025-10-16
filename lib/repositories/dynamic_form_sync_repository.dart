import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../services/database_helper.dart';
import '../services/sync/base_sync_service.dart';
import 'dynamic_form_response_repository.dart';

class DynamicFormSyncRepository {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DynamicFormResponseRepository _responseRepository = DynamicFormResponseRepository();

  String get _responseTableName => 'dynamic_form_response';
  String get _responseDetailTableName => 'dynamic_form_response_detail';

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  /// Sincronizar todas las respuestas pendientes
  Future<Map<String, int>> syncAllPending() async {
    int success = 0;
    int failed = 0;

    try {
      final pending = await _responseRepository.getPendingSync();
      _logger.i('📤 Sincronizando ${pending.length} respuestas pendientes');

      for (final formResponse in pending) {
        final result = await syncToServer(formResponse.id);
        if (result) {
          success++;
        } else {
          failed++;
        }
      }

      _logger.i('✅ Sincronización completada: $success exitosas, $failed fallidas');
    } catch (e) {
      _logger.e('❌ Error en sincronización masiva: $e');
    }

    return {'success': success, 'failed': failed};
  }

  /// Marcar respuesta como sincronizada
  Future<bool> markAsSynced(String responseId, {dynamic serverId}) async {
    try {
      final now = DateTime.now();

      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'sync_status': 'synced',
          'fecha_sincronizado': now.toIso8601String(),
          'mensaje_error_sync': null,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        await markDetailsAsSynced(responseId);
        _logger.i('✅ Response marcada como sincronizada: $responseId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error marcando response como sincronizada: $e');
      return false;
    }
  }

  /// Marcar detalles de respuesta como sincronizados
  Future<bool> markDetailsAsSynced(String responseId) async {
    try {
      final updated = await _dbHelper.actualizar(
        _responseDetailTableName,
        {
          'sync_status': 'synced',
        },
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.i('✅ Response details marcados como sincronizados: $responseId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error marcando details como sincronizados: $e');
      return false;
    }
  }

  /// Registrar intento fallido de sincronización
  Future<bool> markSyncAttemptFailed(String responseId, String errorMessage) async {
    try {
      final now = DateTime.now();

      final current = await _dbHelper.consultar(
        _responseTableName,
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (current.isEmpty) return false;

      final intentosActuales = current.first['intentos_sync'] as int? ?? 0;

      final updated = await _dbHelper.actualizar(
        _responseTableName,
        {
          'intentos_sync': intentosActuales + 1,
          'ultimo_intento_sync': now.toIso8601String(),
          'mensaje_error_sync': errorMessage,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (updated > 0) {
        _logger.w('⚠️ Intento fallido registrado: $responseId (intento ${intentosActuales + 1})');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error registrando intento fallido: $e');
      return false;
    }
  }

  /// Reintentar sincronización de una respuesta específica
  Future<bool> retrySyncResponse(String responseId) async {
    try {
      _logger.i('🔄 Reintentando sincronización: $responseId');

      await _dbHelper.actualizar(
        _responseTableName,
        {
          'intentos_sync': 0,
          'mensaje_error_sync': null,
        },
        where: 'id = ?',
        whereArgs: [responseId],
      );

      return await syncToServer(responseId);
    } catch (e) {
      _logger.e('❌ Error reintentando sync: $e');
      return false;
    }
  }

  /// Sincronización REAL al servidor
  /// Sincronización REAL al servidor
  Future<bool> syncToServer(String responseId) async {
    try {
      _logger.i('📤 Enviando formulario al servidor: $responseId');

      // Obtener la respuesta completa con detalles
      final formResponse = await _responseRepository.getById(responseId);
      if (formResponse == null) {
        _logger.e('❌ Respuesta no encontrada: $responseId');
        return false;
      }

      // Obtener detalles (incluyendo imágenes en Base64)
      final details = await _responseRepository.getDetails(responseId);

      // Obtener imágenes de la tabla separada
      final images = await _responseRepository.getImagesForResponse(responseId);

      // 🎯 CONSTRUIR EL PAYLOAD PARA EL BACKEND
      final payload = {
        'id': formResponse.id,
        'dynamicFormId': formResponse.formTemplateId,
        'contactoId': formResponse.contactoId,
        'edfvendedorId': formResponse.edfVendedorId,
        'usuarioId': formResponse.userId != null ? int.tryParse(formResponse.userId!) : null,
        'equipoId': formResponse.equipoId,
        'estado': formResponse.status,
        'creationDate': formResponse.createdAt.toIso8601String(),
        'completedDate': formResponse.completedAt?.toIso8601String(), // ✅ Siempre incluir, aunque sea null
        'lastUpdateDate': formResponse.completedAt?.toIso8601String() ?? formResponse.createdAt.toIso8601String(), // ✅ Fallback a creationDate
        'details': details.map((d) => {
          'id': d.id,
          'dynamicFormDetailId': d.dynamicFormDetailId,
          'response': d.response,
          'syncStatus': d.syncStatus,
        }).toList(),
        'imagenes': images.map((img) => {
          'id': img.id,
          'dynamicFormResponseDetailId': img.dynamicFormResponseDetailId,
          'imagenBase64': img.imagenBase64,
          'imagenTamano': img.imagenTamano,
          'mimeType': img.mimeType,
          'orden': img.orden,
          'createdAt': img.createdAt,
        }).toList(),
      };

      _logger.d('📦 Payload construido: ${details.length} detalles, ${images.length} imágenes');

      // Obtener la URL dinámica
      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/dynamicFormResponse/insertDynamicFormResponse';

      _logger.i('🌐 URL: $url');

      // Realizar el POST
      final httpResponse = await http.post(
        Uri.parse(url),
        headers: {
          ...BaseSyncService.headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      _logger.i('📡 Respuesta del servidor: ${httpResponse.statusCode}');

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        // ✅ ÉXITO
        _logger.i('✅ Formulario enviado exitosamente');

        // Marcar como sincronizado
        await markAsSynced(responseId);
        return true;

      } else {
        // ❌ ERROR DEL SERVIDOR
        final errorMsg = BaseSyncService.extractErrorMessage(httpResponse);
        _logger.e('❌ Error del servidor: $errorMsg');
        await markSyncAttemptFailed(responseId, errorMsg);
        return false;
      }

    } catch (e) {
      _logger.e('❌ Error sincronizando al servidor: $e');
      await markSyncAttemptFailed(responseId, e.toString());
      return false;
    }
  }

  /// Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final totalPending = await _responseRepository.countPendingSync();
      final totalSynced = await _responseRepository.countSynced();

      final errorMaps = await _dbHelper.consultar(
        _responseTableName,
        where: 'intentos_sync > ?',
        whereArgs: [0],
      );

      return {
        'pending': totalPending,
        'synced': totalSynced,
        'errors': errorMaps.length,
        'total': totalPending + totalSynced,
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'pending': 0,
        'synced': 0,
        'errors': 0,
        'total': 0,
      };
    }
  }

  /// Limpiar respuestas sincronizadas antiguas (opcional, para mantenimiento)
  Future<int> cleanOldSyncedResponses({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final oldResponses = await _dbHelper.consultar(
        _responseTableName,
        where: 'sync_status = ? AND fecha_sincronizado < ?',
        whereArgs: ['synced', cutoffDate.toIso8601String()],
      );

      int deleted = 0;
      for (var response in oldResponses) {
        final responseId = response['id'].toString();

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

      _logger.i('🗑️ Respuestas antiguas eliminadas: $deleted');
      return deleted;
    } catch (e) {
      _logger.e('❌ Error limpiando respuestas antiguas: $e');
      return 0;
    }
  }

  /// Verificar si hay respuestas pendientes de sincronización
  Future<bool> hasPendingSync() async {
    try {
      final count = await _responseRepository.countPendingSync();
      return count > 0;
    } catch (e) {
      _logger.e('❌ Error verificando pendientes: $e');
      return false;
    }
  }
}
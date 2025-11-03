import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../services/database_helper.dart';
import '../services/sync/base_sync_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_log_service.dart..dart';
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


  Future<bool> syncToServer(String responseId) async {
    try {
      _logger.i('📤 Enviando formulario al servidor: $responseId');

      // Obtener la respuesta completa con detalles
      final formResponse = await _responseRepository.getById(responseId);
      if (formResponse == null) {
        _logger.e('❌ Respuesta no encontrada: $responseId');
        return false;
      }

      // Obtener TODOS los detalles
      final allDetails = await _responseRepository.getDetails(responseId);

      // 🎯 FILTRAR: Solo detalles que NO sean imágenes
      final detailsToSend = allDetails
          .where((d) => d.response != '[IMAGE]')
          .toList();

      // Obtener imágenes de la tabla separada
      final images = await _responseRepository.getImagesForResponse(responseId);

      // 🎯 FILTRAR: Solo imágenes con Base64 válido
      final imagesToSend = images.where((img) =>
      img.imagenBase64 != null &&
          img.imagenBase64!.isNotEmpty &&
          img.dynamicFormResponseDetailId != null
      ).toList();

      if (imagesToSend.length < images.length) {
        _logger.w('⚠️ Algunas imágenes sin Base64: ${images.length - imagesToSend.length}');
      }

      _logger.d('📦 Detalles a enviar: ${detailsToSend.length} (${allDetails.length - detailsToSend.length} marcadores de imagen excluidos)');
      _logger.d('📦 Imágenes a enviar: ${imagesToSend.length}');

      // 🎯 AGRUPAR IMÁGENES POR DETAIL ID
      final Map<String, List<dynamic>> imagesByDetailId = {};
      for (final img in imagesToSend) {
        final detailId = img.dynamicFormResponseDetailId!;
        if (!imagesByDetailId.containsKey(detailId)) {
          imagesByDetailId[detailId] = [];
        }
        imagesByDetailId[detailId]!.add({
          'id': img.id,
          'imageBase64': img.imagenBase64,
          'imageTamano': img.imagenTamano,
          'mimeType': img.mimeType,
          'orden': img.orden,
          'createdAt': img.createdAt,
          'url': null,
          'imagePath': img.imagenPath ?? '',
        });
      }

      // 🎯 CONSTRUIR EL PAYLOAD CON EL FORMATO CORRECTO
      final payload = {
        'id': formResponse.id,
        'dynamicFormId': formResponse.formTemplateId,
        'contactoId': formResponse.contactoId,
        'edfvendedorId': formResponse.edfVendedorId,
        'usuarioId': formResponse.userId != null ? int.tryParse(formResponse.userId!) : null,
        'estado': formResponse.status,
        'creationDate': formResponse.createdAt.toIso8601String(),
        'completedDate': formResponse.completedAt?.toIso8601String(),
        'lastUpdateDate': formResponse.completedAt?.toIso8601String() ?? formResponse.createdAt.toIso8601String(),
        'details': [
          // 📝 Incluir detalles NO de imagen con fotos vacías
          ...detailsToSend.map((d) => {
            'id': d.id,
            'dynamicFormDetailId': d.dynamicFormDetailId,
            'response': d.response,
            'syncStatus': d.syncStatus,
            'fotos': [], // Siempre incluir fotos aunque esté vacío
          }),
          // 🖼️ Incluir detalles de imagen con sus fotos correspondientes
          ...allDetails
              .where((d) => d.response == '[IMAGE]')
              .map((d) => {
            'id': d.id,
            'dynamicFormDetailId': d.dynamicFormDetailId,
            'response': d.response,
            'syncStatus': d.syncStatus,
            'fotos': imagesByDetailId[d.id] ?? [], // Fotos correspondientes a este detail
          }),
        ],
      };

      // 🎯 LOG DETALLADO DEL TAMAÑO
      final jsonString = jsonEncode(payload);
      final sizeInBytes = jsonString.length;
      final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
      final sizeInMB = (sizeInBytes / (1024 * 1024)).toStringAsFixed(2);

      _logger.i('📊 Tamaño del payload: $sizeInKB KB ($sizeInMB MB)');
      _logger.d('📋 Details con imágenes: ${imagesByDetailId.keys.length}');

      // ⚠️ ADVERTENCIA si es muy grande
      if (sizeInBytes > 10 * 1024 * 1024) { // > 10MB
        _logger.w('⚠️ ADVERTENCIA: Payload muy grande (${sizeInMB}MB), puede fallar');
      }

      // Obtener la URL dinámica
      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/dynamicFormResponse/insertDynamicFormResponse';

      _logger.i('🌐 URL: $url');

      // 🎯 AUMENTAR TIMEOUT PARA IMÁGENES GRANDES
      final timeoutDuration = sizeInBytes > 5 * 1024 * 1024
          ? Duration(seconds: 120)  // 2 minutos para payloads grandes
          : Duration(seconds: 60);   // 1 minuto normal

      _logger.d('⏱️ Timeout configurado: ${timeoutDuration.inSeconds}s');

      // 📁 GUARDAR LOG DEL JSON ANTES DE ENVIAR
      try {
        final logService = DynamicFormLogService();
        await logService.guardarLogPost(
          url: url,
          headers: {
            ...BaseSyncService.headers,
            'Content-Type': 'application/json',
          },
          body: payload,
          timestamp: DateTime.now().toIso8601String(),
          responseId: responseId,
        );
      } catch (e) {
        _logger.w('⚠️ No se pudo guardar el log: $e');
      }

      // Realizar el POST
      final httpResponse = await http.post(
        Uri.parse(url),
        headers: {
          ...BaseSyncService.headers,
          'Content-Type': 'application/json',
        },
        body: jsonString,
      ).timeout(timeoutDuration);

      _logger.i('📡 Respuesta del servidor: ${httpResponse.statusCode}');

      // 🔍 LOG DEL BODY DE RESPUESTA (para debug)
      if (httpResponse.statusCode >= 400) {
        final bodyText = httpResponse.body;
        if (bodyText.isNotEmpty) {
          final truncatedBody = bodyText.length > 500
              ? bodyText.substring(0, 500)
              : bodyText;
          _logger.e('📄 Body de error: $truncatedBody');
        } else {
          _logger.e('📄 Body de error: (vacío)');
        }
      }

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
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../services/database_helper.dart';
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

      for (final response in pending) {
        final result = await simulateSyncToServer(response.id);
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

      return await simulateSyncToServer(responseId);
    } catch (e) {
      _logger.e('❌ Error reintentando sync: $e');
      return false;
    }
  }

  /// Simulación de sincronización al servidor (TODO: implementar API real)
  Future<bool> simulateSyncToServer(String responseId) async {
    try {
      _logger.i('📤 Simulando envío al servidor: $responseId');

      // Obtener la respuesta completa con detalles
      final response = await _responseRepository.getById(responseId);
      if (response == null) {
        _logger.e('❌ Respuesta no encontrada: $responseId');
        return false;
      }

      // Obtener detalles (incluyendo imágenes en Base64)
      final details = await _responseRepository.getDetails(responseId);

      // ⭐ GENERAR EL JSON QUE SE ENVIARÍA AL API
      final jsonToSend = {
        'id': response.id,
        'dynamicFormId': response.formTemplateId,
        'clienteId': response.clienteId,
        'usuarioId': response.userId,
        'equipoId': response.equipoId,
        'estado': response.status,
        'creationDate': response.createdAt.toIso8601String(),
        'completedDate': response.completedAt?.toIso8601String(),
        'metadata': response.metadata,
        'details': details.map((d) => {
          'id': d.id,
          'dynamicFormDetailId': d.dynamicFormDetailId,
          'response': d.response,
        }).toList(),
      };

      // ⭐ GUARDAR EN ARCHIVO TXT
      final filePath = await _saveJsonToTextFile(jsonToSend, response, details);
      if (filePath != null) {
        _logger.i('💾 Archivo guardado en: $filePath');
      }

      // TODO: Aquí irá la llamada real al API
      // final apiResponse = await _apiService.syncFormResponse(jsonToSend);
      // if (apiResponse.success) {
      //   await markAsSynced(responseId, serverId: apiResponse.serverId);
      //   return true;
      // }

      // Simular delay de red (2-3 segundos)
      await Future.delayed(Duration(seconds: 2));

      // Simular éxito/falla (90% éxito, 10% falla para testing)
      final random = DateTime.now().millisecondsSinceEpoch % 10;
      final success = random < 9;

      if (success) {
        await markAsSynced(responseId);
        _logger.i('✅ Formulario sincronizado exitosamente');
        return true;
      } else {
        await markSyncAttemptFailed(responseId, 'Error simulado de conexión');
        _logger.w('❌ Fallo simulado en envío');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error en simulación: $e');
      await markSyncAttemptFailed(responseId, e.toString());
      return false;
    }
  }

  /// Guardar JSON en archivo TXT legible
  Future<String?> _saveJsonToTextFile(
      Map<String, dynamic> jsonData,
      dynamic response,
      List<dynamic> details,
      ) async {
    try {
      final directory = Directory('/storage/emulated/0/Download');

      if (!await directory.exists()) {
        _logger.w('⚠️ Directorio Download no existe');
        return null;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'form_${response.id}_$timestamp.txt';
      final file = File('${directory.path}/$fileName');

      // Obtener las imágenes de la tabla separada
      final images = await _responseRepository.getImagesForResponse(response.id);

      // Construir contenido legible del archivo
      final buffer = StringBuffer();

      buffer.writeln('╔════════════════════════════════════════════════════════════════╗');
      buffer.writeln('║        FORMULARIO DINÁMICO - DATOS PARA SINCRONIZAR          ║');
      buffer.writeln('╚════════════════════════════════════════════════════════════════╝');
      buffer.writeln('');
      buffer.writeln('📋 INFORMACIÓN GENERAL');
      buffer.writeln('─────────────────────────────────────────────────────────────────');
      buffer.writeln('  ID Respuesta:      ${response.id}');
      buffer.writeln('  ID Formulario:     ${response.formTemplateId}');
      buffer.writeln('  ID Cliente:        ${response.clienteId ?? "N/A"}');
      buffer.writeln('  ID Usuario:        ${response.userId ?? "N/A"}');
      buffer.writeln('  ID Equipo:         ${response.equipoId ?? "N/A"}');
      buffer.writeln('  Estado:            ${response.status}');
      buffer.writeln('  Fecha Creación:    ${response.createdAt}');
      buffer.writeln('  Fecha Completado:  ${response.completedAt ?? "N/A"}');
      buffer.writeln('');

      buffer.writeln('📝 RESPUESTAS (${details.length} campos)');
      buffer.writeln('─────────────────────────────────────────────────────────────────');

      int contador = 1;
      for (var detail in details) {
        buffer.writeln('');
        buffer.writeln('  [$contador] Campo ID: ${detail.dynamicFormDetailId}');
        buffer.writeln('      Respuesta: ${detail.response}');
        buffer.writeln('      Sync Status: ${detail.syncStatus}');
        contador++;
      }

      buffer.writeln('');
      buffer.writeln('📷 IMÁGENES (${images.length} archivos)');
      buffer.writeln('─────────────────────────────────────────────────────────────────');

      if (images.isEmpty) {
        buffer.writeln('  • No hay imágenes adjuntas');
      } else {
        int imgContador = 1;
        for (var img in images) {
          buffer.writeln('');
          buffer.writeln('  [$imgContador] Imagen ID: ${img.id}');
          buffer.writeln('      • Detail ID: ${img.dynamicFormResponseDetailId}');
          buffer.writeln('      • Orden: ${img.orden}');
          buffer.writeln('      • Tamaño: ${img.imagenTamano ?? 0} bytes (${((img.imagenTamano ?? 0) / 1024).toStringAsFixed(2)} KB)');
          buffer.writeln('      • MIME Type: ${img.mimeType}');
          buffer.writeln('      • Path: ${img.imagenPath}');
          buffer.writeln('      • Sync Status: ${img.syncStatus}');
          buffer.writeln('      • Created At: ${img.createdAt}');

          if (img.imagenBase64 != null) {
            buffer.writeln('      • Base64 disponible: SÍ (${img.imagenBase64!.length} caracteres)');
            buffer.writeln('      • Preview (primeros 100 chars):');
            buffer.writeln('        ${img.imagenBase64!.substring(0, img.imagenBase64!.length > 100 ? 100 : img.imagenBase64!.length)}...');
          } else {
            buffer.writeln('      • Base64 disponible: NO (borrador)');
          }

          imgContador++;
        }
      }

      buffer.writeln('');
      buffer.writeln('═════════════════════════════════════════════════════════════════');
      buffer.writeln('📊 RESUMEN');
      buffer.writeln('═════════════════════════════════════════════════════════════════');
      buffer.writeln('  Total de campos respondidos: ${details.length}');
      buffer.writeln('  Total de imágenes adjuntas: ${images.length}');
      buffer.writeln('  Tamaño total de imágenes: ${_formatBytes(images.fold(0, (sum, img) => sum + (img.imagenTamano ?? 0)))}');
      buffer.writeln('');

      buffer.writeln('═════════════════════════════════════════════════════════════════');
      buffer.writeln('🔷 JSON PARA BACKEND - ESTRUCTURA COMPLETA');
      buffer.writeln('═════════════════════════════════════════════════════════════════');
      buffer.writeln('');
      buffer.writeln(JsonEncoder.withIndent('  ').convert(jsonData));
      buffer.writeln('');

      // ========== SECCIÓN: JSON DE IMÁGENES SEPARADO ==========
      if (images.isNotEmpty) {
        buffer.writeln('═════════════════════════════════════════════════════════════════');
        buffer.writeln('📸 JSON ESPECÍFICO DE IMÁGENES (PARA BACKEND)');
        buffer.writeln('═════════════════════════════════════════════════════════════════');
        buffer.writeln('');
        buffer.writeln('// Array de imágenes listo para enviar al endpoint:');
        buffer.writeln('// POST /api/formularios/${response.id}/imagenes');
        buffer.writeln('');

        final imagenesJson = images.map((img) => {
          'id': img.id,
          'dynamicFormResponseDetailId': img.dynamicFormResponseDetailId,
          'imagenBase64': img.imagenBase64,
          'imagenTamano': img.imagenTamano,
          'mimeType': img.mimeType,
          'orden': img.orden,
          'createdAt': img.createdAt,
          'syncStatus': img.syncStatus,
        }).toList();

        buffer.writeln(JsonEncoder.withIndent('  ').convert({
          'responseId': response.id,
          'imagenes': imagenesJson,
          'totalImagenes': images.length,
          'pesoTotal': images.fold(0, (sum, img) => sum + (img.imagenTamano ?? 0)),
        }));
        buffer.writeln('');
      }

      buffer.writeln('═════════════════════════════════════════════════════════════════');
      buffer.writeln('Archivo generado: $timestamp');
      buffer.writeln('Total de líneas: ${buffer.toString().split("\n").length}');
      buffer.writeln('═════════════════════════════════════════════════════════════════');

      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      _logger.e('❌ Error guardando archivo TXT: $e');
      return null;
    }
  }

  /// Formatear bytes a tamaño legible
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
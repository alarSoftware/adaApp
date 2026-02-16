import 'dart:async';
import 'package:ada_app/utils/logger.dart';

import 'package:ada_app/repositories/dynamic_form_sync_repository.dart';
import 'package:ada_app/services/post/dynamic_form_post_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_log_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class DynamicFormUploadService {
  final DynamicFormSyncRepository _syncRepository;
  // final DynamicFormLogService _logService;

  DynamicFormUploadService({
    DynamicFormSyncRepository? syncRepository,
    DynamicFormLogService? logService,
  }) : _syncRepository = syncRepository ?? DynamicFormSyncRepository();
  // _logService = logService ?? DynamicFormLogService();

  /// Envía una respuesta de formulario al servidor
  Future<Map<String, dynamic>> enviarRespuestaAlServidor(
    String responseId, {
    bool guardarLog = false,
    String? userId,
  }) async {
    try {
      AppLogger.i('Preparando envío de respuesta de formulario');

      // Obtener datos completos de la BD
      final respuesta = await _syncRepository.getResponseById(responseId);
      if (respuesta == null) {
        // LOG: Respuesta no encontrada
        // await ErrorLogService.logValidationError(
        //   tableName: 'dynamic_form_response',
        //   operation: 'enviar_respuesta',
        //   errorMessage: 'Respuesta no encontrada en BD local',
        //   registroFailId: responseId,
        //   userId: userId,
        // );

        return {'exito': false, 'mensaje': 'Respuesta no encontrada'};
      }

      final detalles = await _syncRepository.getResponseDetails(responseId);
      final imagenes = await _syncRepository.getResponseImages(responseId);

      // Preparar payload
      final payload = await _prepararPayloadCompleto(
        respuesta,
        detalles,
        imagenes,
        responseId,
        userId,
      );

      // final timestamp = DateTime.now().toIso8601String();

      // Guardar log si está habilitado
      if (guardarLog) {
        // LOG DESHABILITADO POR SOLICITUD
        /*
        await _logService.guardarLogPost(
          url: 'API_ENDPOINT',
          headers: {'Content-Type': 'application/json'},
          body: payload,
          timestamp: timestamp,
          responseId: responseId,
        );
        */
      }

      // USAR DynamicFormPostService con userId
      final resultado = await DynamicFormPostService.enviarRespuestaFormulario(
        respuesta: payload,
        incluirLog: false,
        userId: userId,
      );

      AppLogger.i('Respuesta recibida: ${resultado['exito']}');
      return resultado;
    } catch (e) {
      AppLogger.e('Error en envío de formulario', e);

      // LOG: Error general en envío
      await ErrorLogService.logError(
        tableName: 'dynamic_form_response',
        operation: 'enviar_respuesta',
        errorMessage: 'Error de conexión: $e',
        errorType: 'upload',
        registroFailId: responseId,
        userId: int.tryParse(userId ?? ''),
      );

      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  /// Sincroniza una respuesta específica en segundo plano
  Future<void> sincronizarRespuestaEnBackground(
    String responseId, {
    String? userId,
  }) async {
    Future.delayed(Duration.zero, () async {
      try {
        AppLogger.i('Sincronización background de formulario');

        // Registrar intento
        await _syncRepository.updateSyncAttempt(
          responseId,
          1,
          DateTime.now().toIso8601String(),
        );

        // Enviar
        final resultado = await enviarRespuestaAlServidor(
          responseId,
          userId: userId,
        );

        // Actualizar estado
        if (resultado['exito'] == true) {
          await _syncRepository.markResponseAsSynced(responseId);
          await _syncRepository.markAllDetailsAsSynced(responseId);
          await _syncRepository.markAllImagesAsSynced(responseId);

          AppLogger.i('Sincronización de formulario exitosa');
        } else {
          await _syncRepository.markResponseAsError(
            responseId,
            'Error (intento #1): ${resultado['mensaje']}',
          );

          // LOG: Error en primer intento
          // await ErrorLogService.logError(
          //   tableName: 'dynamic_form_response',
          //   operation: 'sync_background',
          //   errorMessage: 'Error en primer intento: ${resultado['mensaje']}',
          //   errorType: 'sync',
          //   registroFailId: responseId,
          //   syncAttempt: 1,
          //   userId: userId,
          // );

          AppLogger.w('Error en envío - reintento programado');
        }
      } catch (e) {
        AppLogger.e('Excepción en sincronización de formulario', e);

        // LOG: Excepción en background sync
        await ErrorLogService.logError(
          tableName: 'dynamic_form_response',
          operation: 'sync_background',
          errorMessage: 'Excepción en sincronización: $e',
          errorType: 'exception',
          registroFailId: responseId,
          userId: int.tryParse(userId ?? ''),
        );

        await _syncRepository.markResponseAsError(responseId, 'Excepción: $e');
      }
    });
  }

  /// Sincroniza todas las respuestas pendientes
  Future<Map<String, int>> sincronizarRespuestasPendientes(
    String usuarioId,
  ) async {
    try {
      AppLogger.i('Sincronización de respuestas pendientes...');

      final respuestasPendientes = await _syncRepository.getPendingResponses();
      final respuestasError = await _syncRepository.getErrorResponses();
      final respuestasErrorListas = await _filtrarRespuestasListasParaReintento(
        respuestasError,
      );

      final todasLasRespuestas = [
        ...respuestasPendientes,
        ...respuestasErrorListas,
      ];

      if (todasLasRespuestas.isEmpty) {
        AppLogger.i('No hay respuestas pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      AppLogger.i('Formularios a sincronizar: ${todasLasRespuestas.length}');

      int exitosos = 0;
      int fallidos = 0;

      for (final respuesta in todasLasRespuestas) {
        try {
          final responseId = respuesta['id'] as String;
          await _sincronizarRespuestaIndividual(responseId, usuarioId);
          exitosos++;
        } catch (e) {
          AppLogger.e('Error sincronizando formulario', e);

          // LOG: Error en sincronización individual
          await ErrorLogService.logError(
            tableName: 'dynamic_form_response',
            operation: 'sync_pendientes',
            errorMessage: 'Error sincronizando respuesta: $e',
            errorType: 'sync_batch',
            registroFailId: respuesta['id'] as String?,
            userId: int.tryParse(usuarioId),
          );

          fallidos++;
        }
      }

      AppLogger.i(
        'Sync formularios - Exitosos: $exitosos, Fallidos: $fallidos',
      );

      // LOG: Si hay muchos fallos, registrar
      if (fallidos > 0 && fallidos >= exitosos) {
        // await ErrorLogService.logError(
        //   tableName: 'dynamic_form_response',
        //   operation: 'sync_pendientes',
        //   errorMessage: 'Alta tasa de fallos: $fallidos de ${todasLasRespuestas.length}',
        //   errorType: 'sync_batch_high_failure',
        //   userId: usuarioId,
        // );
      }

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': todasLasRespuestas.length,
      };
    } catch (e) {
      AppLogger.e('Error general en sincronización de formularios', e);

      // LOG: Error general en sincronización batch
      await ErrorLogService.logError(
        tableName: 'dynamic_form_response',
        operation: 'sync_pendientes',
        errorMessage: 'Error en sincronización masiva: $e',
        errorType: 'sync_batch',
        userId: int.tryParse(usuarioId),
      );

      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Reintenta el envío de una respuesta específica
  Future<Map<String, dynamic>> reintentarEnvioRespuesta(
    String responseId, {
    String? userId,
  }) async {
    try {
      AppLogger.i('Reintentando envío de formulario');

      // Obtener número de intentos previos
      final intentosPrevios = await _obtenerNumeroIntentos(responseId);
      final numeroIntento = intentosPrevios + 1;

      // Resetear intentos
      await _syncRepository.resetSyncAttempts(responseId);

      // Enviar
      final resultado = await enviarRespuestaAlServidor(
        responseId,
        userId: userId,
      );

      if (resultado['exito'] == true) {
        await _syncRepository.markResponseAsSynced(responseId);
        await _syncRepository.markAllDetailsAsSynced(responseId);
        await _syncRepository.markAllImagesAsSynced(responseId);

        return {'success': true, 'message': 'Respuesta sincronizada'};
      } else {
        await _syncRepository.markResponseAsError(
          responseId,
          'Error: ${resultado['mensaje']}',
        );

        // LOG: Reintento fallido
        // await ErrorLogService.logError(
        //   tableName: 'dynamic_form_response',
        //   operation: 'RETRY_POST',
        //   errorMessage: 'Reintento #$numeroIntento falló: ${resultado['mensaje']}',
        //   errorType: 'retry_failed',
        //   registroFailId: responseId,
        //   syncAttempt: numeroIntento,
        //   userId: userId,
        // );

        return {'success': false, 'error': resultado['mensaje']};
      }
    } catch (e) {
      AppLogger.e('Error en reintento de formulario', e);

      // LOG: Excepción en reintento
      await ErrorLogService.logError(
        tableName: 'dynamic_form_response',
        operation: 'RETRY_POST',
        errorMessage: 'Excepción en reintento: $e',
        errorType: 'retry_exception',
        registroFailId: responseId,
        userId: int.tryParse(userId ?? ''),
      );

      await _syncRepository.markResponseAsError(responseId, 'Excepción: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  // ==================== MÉTODOS PRIVADOS ====================

  /// Prepara el payload completo con detalles e imágenes
  Future<Map<String, dynamic>> _prepararPayloadCompleto(
    Map<String, dynamic> respuesta,
    List<Map<String, dynamic>> detalles,
    List<Map<String, dynamic>> imagenes,
    String responseId,
    String? userId,
  ) async {
    try {
      AppLogger.i('Preparando payload de formulario');

      // Agrupar imágenes por detail ID
      final Map<String, List<dynamic>> imagesByDetailId = {};
      for (final img in imagenes) {
        final detailId = img['dynamic_form_response_detail_id'] as String?;
        if (detailId != null) {
          if (!imagesByDetailId.containsKey(detailId)) {
            imagesByDetailId[detailId] = [];
          }
          imagesByDetailId[detailId]!.add({
            'id': img['id'],
            'imageBase64': img['imagen_base64'],
            'imageTamano': img['imagen_tamano'],
            'mimeType': img['mime_type'] ?? 'image/jpeg',
            'orden': img['orden'] ?? 1,
            'createdAt': img['created_at'],
            'imagePath': img['imagen_path'] ?? '',
          });
        }
      }

      // Construir array de detalles
      final detallesFormateados = detalles.map((detalle) {
        final detailId = detalle['id'] as String;
        final response = detalle['response'];

        return {
          'id': detailId,
          'dynamicFormDetailId': detalle['dynamic_form_detail_id'],
          'response': response,
          'syncStatus': detalle['sync_status'],
          'fotos': imagesByDetailId[detailId] ?? [],
        };
      }).toList();

      final completedDate = _getCompletedDate(respuesta);
      final estado = respuesta['estado'] as String?;

      AppLogger.i(
        'Payload: ${detallesFormateados.length} detalles, ${imagenes.length} fotos',
      );

      final payload = {
        'id': respuesta['id'],
        'dynamicFormId': respuesta['dynamic_form_id'],
        'employeeId': respuesta['employee_id'],
        'usuarioId': respuesta['usuario_id'] != null
            ? int.tryParse(respuesta['usuario_id'].toString())
            : null,
        'estado': estado,
        'creationDate': respuesta['creation_date'],
        'completedDate': completedDate,
        'lastUpdateDate':
            respuesta['last_update_date'] ?? respuesta['creation_date'],
        'details': detallesFormateados,
      };

      final contactoIdArg = respuesta['contacto_id']?.toString();
      if (contactoIdArg != null && contactoIdArg.isNotEmpty) {
        payload['contactoId'] = contactoIdArg;
      }

      return payload;
    } catch (e) {
      AppLogger.e('Error preparando payload de formulario', e);

      // LOG: Error preparando payload
      // await ErrorLogService.logError(
      //   tableName: 'dynamic_form_response',
      //   operation: 'preparar_payload',
      //   errorMessage: 'Error preparando payload: $e',
      //   errorType: 'preparation',
      //   registroFailId: responseId,
      //   userId: userId,
      // );

      rethrow;
    }
  }

  /// Método helper para obtener completedDate correctamente
  String? _getCompletedDate(Map<String, dynamic> respuesta) {
    final estado = respuesta['estado'] as String?;

    if (estado == 'completed' || estado == 'synced') {
      final lastUpdateDate = respuesta['last_update_date'] as String?;

      if (lastUpdateDate != null && lastUpdateDate.isNotEmpty) {
        return lastUpdateDate;
      }

      final creationDate = respuesta['creation_date'] as String?;
      return creationDate ?? DateTime.now().toIso8601String();
    }

    return null;
  }

  /// Sincroniza una respuesta individual con backoff
  Future<void> _sincronizarRespuestaIndividual(
    String responseId,
    String? userId,
  ) async {
    final intentosPrevios = await _obtenerNumeroIntentos(responseId);
    final numeroIntento = intentosPrevios + 1;

    AppLogger.i('Sincronizando formulario (intento #$numeroIntento)');

    await _syncRepository.updateSyncAttempt(
      responseId,
      numeroIntento,
      DateTime.now().toIso8601String(),
    );

    final resultado = await enviarRespuestaAlServidor(
      responseId,
      userId: userId,
    );

    if (resultado['exito'] == true) {
      await _syncRepository.markResponseAsSynced(responseId);
      await _syncRepository.markAllDetailsAsSynced(responseId);
      await _syncRepository.markAllImagesAsSynced(responseId);

      AppLogger.i('Formulario sincronizado después de $numeroIntento intentos');
    } else {
      await _syncRepository.markResponseAsError(
        responseId,
        'Error (intento #$numeroIntento): ${resultado['mensaje']}',
      );

      // LOG: Intento fallido con backoff
      // await ErrorLogService.logError(
      //   tableName: 'dynamic_form_response',
      //   operation: 'sync_individual',
      //   errorMessage: 'Error en intento #$numeroIntento: ${resultado['mensaje']}',
      //   errorType: 'sync_retry',
      //   registroFailId: responseId,
      //   syncAttempt: numeroIntento,
      //   userId: userId,
      // );

      final proximoIntento = _calcularProximoIntento(numeroIntento);
      AppLogger.w(
        'Error intento #$numeroIntento - próximo en $proximoIntento min',
      );
    }
  }

  /// Filtra respuestas listas para reintento según backoff
  Future<List<Map<String, dynamic>>> _filtrarRespuestasListasParaReintento(
    List<Map<String, dynamic>> respuestasError,
  ) async {
    final respuestasListas = <Map<String, dynamic>>[];
    final ahora = DateTime.now();

    for (final respuesta in respuestasError) {
      try {
        final responseId = respuesta['id'] as String;
        final intentos = await _obtenerNumeroIntentos(responseId);
        final ultimoIntento = await _obtenerUltimoIntento(responseId);

        if (ultimoIntento == null) {
          respuestasListas.add(respuesta);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
        final tiempoProximoIntento = ultimoIntento.add(
          Duration(minutes: minutosEspera),
        );

        if (ahora.isAfter(tiempoProximoIntento)) {
          respuestasListas.add(respuesta);
        }
      } catch (e) {
        AppLogger.e('Error verificando reintento de formulario', e);
        respuestasListas.add(respuesta);
      }
    }

    return respuestasListas;
  }

  int _calcularProximoIntento(int numeroIntento) {
    switch (numeroIntento) {
      case 1:
        return 2;
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 20;
      case 5:
        return 30;
      default:
        return 60;
    }
  }

  Future<int> _obtenerNumeroIntentos(String responseId) async {
    try {
      final respuesta = await _syncRepository.getResponseById(responseId);
      if (respuesta != null) {
        return respuesta['intentos_sync'] as int? ?? 0;
      }
    } catch (e) {
      AppLogger.e('Error obteniendo intentos de sync', e);
    }
    return 0;
  }

  Future<DateTime?> _obtenerUltimoIntento(String responseId) async {
    try {
      final respuesta = await _syncRepository.getResponseById(responseId);
      if (respuesta != null) {
        final ultimoIntentoStr = respuesta['ultimo_intento_sync'] as String?;
        if (ultimoIntentoStr != null && ultimoIntentoStr.isNotEmpty) {
          return DateTime.parse(ultimoIntentoStr);
        }
      }
    } catch (e) {
      AppLogger.e('Error obteniendo último intento de sync', e);
    }
    return null;
  }
}

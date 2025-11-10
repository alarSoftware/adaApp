// lib/services/dynamic_form/dynamic_form_upload_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:ada_app/repositories/dynamic_form_sync_repository.dart';
import 'package:ada_app/services/post/dynamic_form_post_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_log_service.dart';

class DynamicFormUploadService {
  final Logger _logger = Logger();
  final DynamicFormSyncRepository _syncRepository;
  final DynamicFormLogService _logService;

  // Variables para sincronización automática
  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static String? _usuarioActual;

  DynamicFormUploadService({
    DynamicFormSyncRepository? syncRepository,
    DynamicFormLogService? logService,
  })  : _syncRepository = syncRepository ?? DynamicFormSyncRepository(),
        _logService = logService ?? DynamicFormLogService();

  /// Envía una respuesta de formulario al servidor
  Future<Map<String, dynamic>> enviarRespuestaAlServidor(
      String responseId, {
        bool guardarLog = false,
      }) async {
    try {
      _logger.i('📤 Preparando envío de respuesta: $responseId');

      // Obtener datos completos de la BD
      final respuesta = await _syncRepository.getResponseById(responseId);
      if (respuesta == null) {
        return {'exito': false, 'mensaje': 'Respuesta no encontrada'};
      }

      final detalles = await _syncRepository.getResponseDetails(responseId);
      final imagenes = await _syncRepository.getResponseImages(responseId);

      // Preparar payload
      final payload = await _prepararPayloadCompleto(respuesta, detalles, imagenes);

      final timestamp = DateTime.now().toIso8601String();

      // Guardar log si está habilitado
      if (guardarLog) {
        await _logService.guardarLogPost(
          url: 'API_ENDPOINT',
          headers: {'Content-Type': 'application/json'},
          body: payload,
          timestamp: timestamp,
          responseId: responseId,
        );
      }

      // ✅ USAR DynamicFormPostService
      final resultado = await DynamicFormPostService.enviarRespuestaFormulario(
        respuesta: payload,
        incluirLog: false,
      );

      _logger.i('✅ Respuesta recibida: ${resultado['exito']}');
      return resultado;

    } catch (e) {
      _logger.e('❌ Error en envío: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Sincroniza una respuesta específica en segundo plano
  Future<void> sincronizarRespuestaEnBackground(String responseId) async {
    Future.delayed(Duration.zero, () async {
      try {
        _logger.i('🔄 Sincronización background para: $responseId');

        // Registrar intento
        await _syncRepository.updateSyncAttempt(
          responseId,
          1,
          DateTime.now().toIso8601String(),
        );

        // Enviar
        final resultado = await enviarRespuestaAlServidor(responseId);

        // Actualizar estado
        if (resultado['exito'] == true) {
          await _syncRepository.markResponseAsSynced(responseId);
          await _syncRepository.markAllDetailsAsSynced(responseId);
          await _syncRepository.markAllImagesAsSynced(responseId);

          _logger.i('✅ Sincronización exitosa: $responseId');
        } else {
          await _syncRepository.markResponseAsError(
            responseId,
            'Error (intento #1): ${resultado['mensaje']}',
          );

          _logger.w('⚠️ Error - reintento programado');
        }
      } catch (e) {
        _logger.e('💥 Excepción en sincronización: $e');
        await _syncRepository.markResponseAsError(responseId, 'Excepción: $e');
      }
    });
  }

  /// Sincroniza todas las respuestas pendientes
  Future<Map<String, int>> sincronizarRespuestasPendientes(String usuarioId) async {
    try {
      _logger.i('🔄 Sincronización de respuestas pendientes...');

      final respuestasPendientes = await _syncRepository.getPendingResponses();
      final respuestasError = await _syncRepository.getErrorResponses();
      final respuestasErrorListas = await _filtrarRespuestasListasParaReintento(respuestasError);

      final todasLasRespuestas = [...respuestasPendientes, ...respuestasErrorListas];

      if (todasLasRespuestas.isEmpty) {
        _logger.i('✅ No hay respuestas pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      _logger.i('📋 Total a sincronizar: ${todasLasRespuestas.length}');

      int exitosos = 0;
      int fallidos = 0;

      for (final respuesta in todasLasRespuestas) {
        try {
          final responseId = respuesta['id'] as String;
          await _sincronizarRespuestaIndividual(responseId);
          exitosos++;
        } catch (e) {
          _logger.e('❌ Error: $e');
          fallidos++;
        }
      }

      _logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': todasLasRespuestas.length,
      };
    } catch (e) {
      _logger.e('💥 Error en sincronización: $e');
      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Reintenta el envío de una respuesta específica
  Future<Map<String, dynamic>> reintentarEnvioRespuesta(String responseId) async {
    try {
      _logger.i('🔁 Reintentando: $responseId');

      // Resetear intentos
      await _syncRepository.resetSyncAttempts(responseId);

      // Enviar
      final resultado = await enviarRespuestaAlServidor(responseId);

      if (resultado['exito'] == true) {
        await _syncRepository.markResponseAsSynced(responseId);
        await _syncRepository.markAllDetailsAsSynced(responseId);
        await _syncRepository.markAllImagesAsSynced(responseId);

        return {'success': true, 'message': 'Respuesta sincronizada'};
      } else {
        await _syncRepository.markResponseAsError(responseId, 'Error: ${resultado['mensaje']}');
        return {'success': false, 'error': resultado['mensaje']};
      }
    } catch (e) {
      _logger.e('💥 Error en reintento: $e');
      await _syncRepository.markResponseAsError(responseId, 'Excepción: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static void iniciarSincronizacionAutomatica(String usuarioId) {
    if (_syncActivo) {
      Logger().i('⚠️ Sincronización de formularios ya está activa');
      return;
    }

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática de formularios cada 2 minutos...');

    _syncTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    // Primera ejecución después de 30 segundos
    Timer(Duration(seconds: 30), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _usuarioActual = null;
      Logger().i('⏹️ Sincronización automática de formularios detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo || _usuarioActual == null) return;

    try {
      final logger = Logger();
      logger.i('🔄 Ejecutando sincronización automática de formularios...');

      final service = DynamicFormUploadService();
      final resultado = await service.sincronizarRespuestasPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        logger.i('✅ Auto-sync formularios: ${resultado['exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en auto-sync formularios: $e');
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static String? get usuarioActualSync => _usuarioActual;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) {
      Logger().w('⚠️ No se puede forzar sincronización de formularios');
      return null;
    }

    Logger().i('⚡ Forzando sincronización de formularios...');
    final service = DynamicFormUploadService();
    return await service.sincronizarRespuestasPendientes(_usuarioActual!);
  }

  // ==================== MÉTODOS PRIVADOS ====================

  /// ✅ CORREGIDO: Prepara el payload completo con detalles e imágenes
  Future<Map<String, dynamic>> _prepararPayloadCompleto(
      Map<String, dynamic> respuesta,
      List<Map<String, dynamic>> detalles,
      List<Map<String, dynamic>> imagenes,
      ) async {
    try {
      _logger.i('📦 Preparando payload para: ${respuesta['id']}');

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

      // ✅ FIX: Obtener completedDate correctamente
      final completedDate = _getCompletedDate(respuesta);
      final estado = respuesta['estado'] as String?;

      _logger.i('📦 Payload: ${detallesFormateados.length} detalles, ${imagenes.length} fotos');
      _logger.i('🔍 DEBUG estado: $estado, completedDate: $completedDate');

      final payload = {
        'id': respuesta['id'],
        'dynamicFormId': respuesta['dynamic_form_id'],
        'contactoId': respuesta['contacto_id'],
        'edfvendedorId': respuesta['edf_vendedor_id'],
        'usuarioId': respuesta['usuario_id'] != null
            ? int.tryParse(respuesta['usuario_id'].toString())
            : null,
        'estado': estado,
        'creationDate': respuesta['creation_date'],
        'completedDate': completedDate, // ✅ Usar método helper
        'lastUpdateDate': respuesta['last_update_date'] ?? respuesta['creation_date'],
        'details': detallesFormateados,
      };

      // ✅ DEBUG adicional
      _logger.i('🔍 PAYLOAD FINAL:');
      _logger.i('  - ID: ${payload['id']}');
      _logger.i('  - Estado: ${payload['estado']}');
      _logger.i('  - CreationDate: ${payload['creationDate']}');
      _logger.i('  - CompletedDate: ${payload['completedDate']}');
      _logger.i('  - LastUpdateDate: ${payload['lastUpdateDate']}');
      _logger.i('  - Details: ${(payload['details'] as List).length}');

      return payload;
    } catch (e) {
      _logger.e('❌ Error preparando payload: $e');
      rethrow;
    }
  }

  /// ✅ NUEVO: Método helper para obtener completedDate correctamente
  String? _getCompletedDate(Map<String, dynamic> respuesta) {
    final estado = respuesta['estado'] as String?;

    _logger.d('🔍 _getCompletedDate - Estado: $estado');

    // Solo enviar completedDate si el formulario está completado o sincronizado
    if (estado == 'completed' || estado == 'synced') {
      // Usar last_update_date como fecha de completado
      final lastUpdateDate = respuesta['last_update_date'] as String?;

      _logger.d('🔍 LastUpdateDate en BD: $lastUpdateDate');

      if (lastUpdateDate != null && lastUpdateDate.isNotEmpty) {
        _logger.i('✅ Usando lastUpdateDate como completedDate: $lastUpdateDate');
        return lastUpdateDate;
      }

      // Fallback: usar creation_date si no hay last_update_date
      final creationDate = respuesta['creation_date'] as String?;
      _logger.w('⚠️ No hay lastUpdateDate, usando creationDate: $creationDate');

      return creationDate ?? DateTime.now().toIso8601String();
    }

    // Para drafts, no enviar completedDate (el servidor lo espera como null)
    _logger.d('🔍 Estado es draft, completedDate será null');
    return null;
  }

  /// Sincroniza una respuesta individual con backoff
  Future<void> _sincronizarRespuestaIndividual(String responseId) async {
    final intentosPrevios = await _obtenerNumeroIntentos(responseId);
    final numeroIntento = intentosPrevios + 1;

    _logger.i('🔄 Sincronizando $responseId (intento #$numeroIntento)');

    await _syncRepository.updateSyncAttempt(
      responseId,
      numeroIntento,
      DateTime.now().toIso8601String(),
    );

    final resultado = await enviarRespuestaAlServidor(responseId);

    if (resultado['exito'] == true) {
      await _syncRepository.markResponseAsSynced(responseId);
      await _syncRepository.markAllDetailsAsSynced(responseId);
      await _syncRepository.markAllImagesAsSynced(responseId);

      _logger.i('✅ $responseId sincronizado después de $numeroIntento intentos');
    } else {
      await _syncRepository.markResponseAsError(
        responseId,
        'Error (intento #$numeroIntento): ${resultado['mensaje']}',
      );

      final proximoIntento = _calcularProximoIntento(numeroIntento);
      _logger.w('⚠️ Error intento #$numeroIntento - próximo en $proximoIntento min');
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
        final tiempoProximoIntento = ultimoIntento.add(Duration(minutes: minutosEspera));

        if (ahora.isAfter(tiempoProximoIntento)) {
          respuestasListas.add(respuesta);
        }
      } catch (e) {
        _logger.w('⚠️ Error verificando ${respuesta['id']}: $e');
        respuestasListas.add(respuesta);
      }
    }

    return respuestasListas;
  }

  int _calcularProximoIntento(int numeroIntento) {
    switch (numeroIntento) {
      case 1: return 2;
      case 2: return 5;
      case 3: return 10;
      case 4: return 20;
      case 5: return 30;
      default: return 60;
    }
  }

  Future<int> _obtenerNumeroIntentos(String responseId) async {
    try {
      final respuesta = await _syncRepository.getResponseById(responseId);
      if (respuesta != null) {
        return respuesta['intentos_sync'] as int? ?? 0;
      }
    } catch (e) {
      _logger.w('⚠️ Error obteniendo intentos: $e');
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
      _logger.w('⚠️ Error obteniendo último intento: $e');
    }
    return null;
  }
}
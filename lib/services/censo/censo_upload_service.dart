// lib/services/censo/censo_upload_service.dart

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;

  CensoUploadService({
    EstadoEquipoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService();

  /// Envía un censo al servidor con timeout configurable
  Future<Map<String, dynamic>> enviarCensoAlServidor(
      Map<String, dynamic> datos, {
        int timeoutSegundos = 10,
        bool guardarLog = true,
      }) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final endpoint = '/censoActivo/insertCensoActivo';
      final fullUrl = '$baseUrl$endpoint';

      final timestamp = DateTime.now().toIso8601String();
      final jsonBody = json.encode(datos);

      _logger.i('📤 POST a $fullUrl (timeout: ${timeoutSegundos}s)');
      _logger.i('📦 Payload: ${jsonBody.length} caracteres');

      // Guardar log si está habilitado
      if (guardarLog) {
        await _logService.guardarLogPost(
          url: fullUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: datos,
          timestamp: timestamp,
          censoActivoId: datos['id_local'],
        );
      }

      // Enviar request
      final response = await http
          .post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonBody,
      )
          .timeout(Duration(seconds: timeoutSegundos));

      _logger.i('📥 Response: ${response.statusCode}');

      // Procesar respuesta
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _procesarRespuestaExitosa(response);
      } else {
        return {
          'exito': false,
          'mensaje': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      _logger.e('❌ Error en POST: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Sincroniza un censo específico en segundo plano
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    Future.delayed(Duration.zero, () async {
      try {
        _logger.i('🔄 Sincronización background para: $estadoId');

        // Obtener fotos asociadas
        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        // Agregar fotos a los datos
        final datosConFotos = Map<String, dynamic>.from(datos);
        if (fotos.isNotEmpty) {
          datosConFotos['imagen_base64'] = fotos.first.imagenBase64;
        }
        if (fotos.length > 1) {
          datosConFotos['imagen_base64_2'] = fotos[1].imagenBase64;
        }

        // Preparar y enviar
        final respuesta = await enviarCensoAlServidor(
          datosConFotos,
          timeoutSegundos: 10,
        );

        // Actualizar estado según resultado
        if (respuesta['exito'] == true) {
          await _estadoEquipoRepository.marcarComoMigrado(
            estadoId,
            servidorId: respuesta['servidor_id'],
          );

          // Marcar fotos como sincronizadas
          for (final foto in fotos) {
            if (foto.id != null) {
              await _fotoRepository.marcarComoSincronizada(foto.id!);
            }
          }

          _logger.i('✅ Sincronización exitosa: $estadoId (${fotos.length} fotos)');
        } else {
          await _estadoEquipoRepository.marcarComoError(
            estadoId,
            'Error: ${respuesta['detalle'] ?? respuesta['mensaje']}',
          );
          _logger.w('⚠️ Error en sincronización: ${respuesta['mensaje']}');
        }
      } catch (e) {
        _logger.e('💥 Excepción en sincronización: $e');
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      }
    });
  }

  /// Sincroniza todos los registros pendientes
  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    try {
      _logger.i('🔄 Iniciando sincronización de pendientes...');

      final registrosPendientes = await _estadoEquipoRepository.obtenerCreados();

      if (registrosPendientes.isEmpty) {
        _logger.i('✅ No hay registros pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      _logger.i('📋 Encontrados: ${registrosPendientes.length} pendientes');

      int exitosos = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          await _sincronizarRegistroIndividual(registro, usuarioId);
          exitosos++;
        } catch (e) {
          _logger.e('❌ Error procesando ${registro.id}: $e');
          fallidos++;

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
              registro.id!,
              'Excepción: $e',
            );
          }
        }
      }

      _logger.i('✅ Sincronización finalizada - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': registrosPendientes.length,
      };
    } catch (e) {
      _logger.e('💥 Error en sincronización automática: $e');
      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Reintenta el envío de un censo específico
  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      _logger.i('🔁 Reintentando envío: $estadoId');

      // Obtener datos del registro
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return {
          'success': false,
          'error': 'No se encontró el registro',
        };
      }

      final estadoMap = maps.first;

      // Obtener fotos
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      _logger.i('📸 Fotos para reintento: ${fotos.length}');

      // Preparar datos
      final datosParaApi = _prepararDatosParaReintento(
        estadoMap,
        fotos,
        usuarioId,
        edfVendedorId,
      );

      // Enviar
      final respuesta = await enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 8,
      );

      // Procesar resultado
      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(
          estadoId,
          servidorId: respuesta['id'],
        );

        // Marcar fotos como sincronizadas
        for (final foto in fotos) {
          if (foto.id != null) {
            await _fotoRepository.marcarComoSincronizada(foto.id!);
          }
        }

        _logger.i('✅ Reenvío exitoso: $estadoId (${fotos.length} fotos)');

        return {
          'success': true,
          'message': 'Registro sincronizado correctamente',
        };
      } else {
        await _estadoEquipoRepository.marcarComoError(
          estadoId,
          'Error: ${respuesta['mensaje']}',
        );

        return {
          'success': false,
          'error': 'Error del servidor: ${respuesta['mensaje']}',
        };
      }
    } catch (e) {
      _logger.e('💥 Error en reintento: $e');
      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');

      return {
        'success': false,
        'error': 'Error al reintentar: $e',
      };
    }
  }

  // ==================== MÉTODOS PRIVADOS ====================

  Map<String, dynamic> _procesarRespuestaExitosa(http.Response response) {
    dynamic servidorId = _uuid.v4();
    String mensaje = 'Estado registrado correctamente';

    try {
      final responseBody = json.decode(response.body);
      servidorId = responseBody['estado']?['id'] ??
          responseBody['id'] ??
          responseBody['insertId'] ??
          servidorId;

      if (responseBody['message'] != null) {
        mensaje = responseBody['message'].toString();
      }
    } catch (e) {
      _logger.w('⚠️ No se pudo parsear response body: $e');
    }

    return {
      'exito': true,
      'id': servidorId,
      'servidor_id': servidorId,
      'mensaje': mensaje,
    };
  }

  Future<void> _sincronizarRegistroIndividual(
      dynamic registro,
      int usuarioId,
      ) async {
    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);

    final datosParaApi = {
      'fecha_revision': _formatearFechaLocal(registro.fechaRevision),
      'equipo_id': (registro.equipoId ?? '').toString(),
      'latitud': registro.latitud ?? 0.0,
      'longitud': registro.longitud ?? 0.0,
      'usuario_id': usuarioId,
      'funcionando': true,
      'cliente_id': registro.clienteId,
      'observaciones': registro.observaciones ?? 'Sincronización automática',
      'imageBase64_1': fotos.isNotEmpty ? fotos.first.imagenBase64 : null,
      'imageBase64_2': fotos.length > 1 ? fotos[1].imagenBase64 : null,
      'tiene_imagen': fotos.isNotEmpty,
      'tiene_imagen2': fotos.length > 1,
    };

    final respuesta = await enviarCensoAlServidor(
      datosParaApi,
      timeoutSegundos: 5,
      guardarLog: false, // No guardar log en sync automático
    );

    if (respuesta['exito'] == true) {
      await _estadoEquipoRepository.marcarComoMigrado(
        registro.id!,
        servidorId: respuesta['id'],
      );

      for (final foto in fotos) {
        if (foto.id != null) {
          await _fotoRepository.marcarComoSincronizada(foto.id!);
        }
      }

      _logger.i('✅ Registro ${registro.id} sincronizado (${fotos.length} fotos)');
    } else {
      await _estadoEquipoRepository.marcarComoError(
        registro.id!,
        'Error: ${respuesta['mensaje']}',
      );
      _logger.w('⚠️ Error ${registro.id}: ${respuesta['mensaje']}');
    }
  }

  Map<String, dynamic> _prepararDatosParaReintento(
      Map<String, dynamic> estadoMap,
      List<dynamic> fotos,
      int usuarioId,
      String? edfVendedorId,
      ) {
    final now = DateTime.now().toLocal();
    final timestampId = _uuid.v4();

    return {
      'id': timestampId.toString(),
      'edfVendedorSucursalId': edfVendedorId ?? '',
      'edfEquipoId': estadoMap['equipo_id']?.toString() ?? '',
      'usuarioId': usuarioId,
      'edfClienteId': estadoMap['cliente_id'] ?? 0,
      'fecha_revision': estadoMap['fecha_revision'] ?? _formatearFechaLocal(now),
      'latitud': estadoMap['latitud'] ?? 0.0,
      'longitud': estadoMap['longitud'] ?? 0.0,
      'enLocal': true,
      'fechaDeRevision': estadoMap['fecha_revision'] ?? _formatearFechaLocal(now),
      'estadoCenso': 'pendiente',
      'observaciones': estadoMap['observaciones'] ?? '',
      'imageBase64_1': fotos.isNotEmpty ? fotos.first.imagenBase64 : null,
      'imageBase64_2': fotos.length > 1 ? fotos[1].imagenBase64 : null,
      'tiene_imagen': fotos.isNotEmpty,
      'tiene_imagen2': fotos.length > 1,
      'equipo_codigo_barras': '',
      'equipo_numero_serie': '',
      'equipo_modelo': '',
      'equipo_marca': '',
      'equipo_logo': '',
      'cliente_nombre': '',
      'usuario_id': usuarioId,
      'cliente_id': estadoMap['cliente_id'] ?? 0,
    };
  }

  String _formatearFechaLocal(DateTime fecha) {
    final local = fecha.toLocal();
    return local.toIso8601String().replaceAll('Z', '');
  }
}
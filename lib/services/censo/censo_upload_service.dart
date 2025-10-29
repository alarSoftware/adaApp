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

  // ==================== VARIABLES PARA SINCRONIZACIÓN AUTOMÁTICA ====================
  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static int? _usuarioActual;

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
        int timeoutSegundos = 60,
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

  /// Sincroniza un censo específico en segundo plano con sistema de backoff
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    Future.delayed(Duration.zero, () async {
      try {
        _logger.i('🔄 Sincronización background para: $estadoId');

        // Obtener datos DIRECTOS de la tabla censo_activo
        final maps = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoId],
          limit: 1,
        );

        if (maps.isEmpty) {
          _logger.e('❌ No se encontró el estado en BD: $estadoId');
          return;
        }

        // ✅ USAR DIRECTAMENTE LOS DATOS DE LA TABLA
        final datosDeTabla = Map<String, dynamic>.from(maps.first);

        // Obtener fotos asociadas
        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        // Solo agregar las imágenes base64 a los datos existentes
        if (fotos.isNotEmpty) {
          datosDeTabla['imagen_base64'] = fotos.first.imagenBase64;
          datosDeTabla['imageBase64_1'] = fotos.first.imagenBase64; // Por compatibilidad
        }
        if (fotos.length > 1) {
          datosDeTabla['imagen_base64_2'] = fotos[1].imagenBase64;
          datosDeTabla['imageBase64_2'] = fotos[1].imagenBase64; // Por compatibilidad
        }

        // 🔍 LOG TEMPORAL PARA VER QUÉ SE ENVÍA:
        final jsonParaEnviar = Map<String, dynamic>.from(datosDeTabla);
        // Remover base64 del log para que no sea gigante
        if (jsonParaEnviar.containsKey('imagen_base64')) {
          jsonParaEnviar['imagen_base64'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaEnviar.containsKey('imagen_base64_2')) {
          jsonParaEnviar['imagen_base64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaEnviar.containsKey('imageBase64_1')) {
          jsonParaEnviar['imageBase64_1'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaEnviar.containsKey('imageBase64_2')) {
          jsonParaEnviar['imageBase64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        _logger.i('🔍 JSON DIRECTO DE TABLA: ${json.encode(jsonParaEnviar)}');

        // Registrar intento (primer intento = 1)
        await _actualizarUltimoIntento(estadoId, 1);

        // Enviar los datos tal como están en la tabla + imágenes
        final respuesta = await enviarCensoAlServidor(
          datosDeTabla,
          timeoutSegundos: 45,
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

          _logger.i('✅ Sincronización exitosa inmediata: $estadoId (${fotos.length} fotos)');
        } else {
          // Marcar como error CON tracking de intentos
          await _estadoEquipoRepository.marcarComoError(
            estadoId,
            'Error (intento #1): ${respuesta['detalle'] ?? respuesta['mensaje']}',
          );

          final proximoIntento = _calcularProximoIntento(1);
          _logger.w('⚠️ Error en sincronización inmediata: ${respuesta['mensaje']} - Sistema automático reintentará en $proximoIntento minuto(s)');
        }
      } catch (e) {
        _logger.e('💥 Excepción en sincronización inmediata: $e');

        // Marcar como error CON tracking de intentos
        await _actualizarUltimoIntento(estadoId, 1);
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción (intento #1): $e');

        _logger.w('⚠️ Sistema automático reintentará en 1 minuto');
      }
    });
  }

  /// Sincroniza todos los registros pendientes con backoff exponencial
  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    try {
      _logger.i('🔄 Iniciando sincronización inteligente de pendientes...');

      // Obtener tanto registros 'creado' como 'error'
      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();
      final registrosError = await _estadoEquipoRepository.obtenerConError();

      // Filtrar registros con error que ya pueden reintentarse
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(registrosError);

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      if (todosLosRegistros.isEmpty) {
        _logger.i('✅ No hay registros pendientes de sincronización');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      _logger.i('📋 Encontrados: ${registrosCreados.length} nuevos + ${registrosErrorListos.length} para reintentar = ${todosLosRegistros.length} total');

      int exitosos = 0;
      int fallidos = 0;

      for (final registro in todosLosRegistros) {
        try {
          await _sincronizarRegistroIndividualConBackoff(registro, usuarioId);
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

      _logger.i('✅ Sincronización inteligente finalizada - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': todosLosRegistros.length,
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

      // 🔍 LOG TEMPORAL PARA COMPARAR JSONs:
      final jsonParaEnviar = Map<String, dynamic>.from(datosParaApi);
      // Remover base64 del log para que no sea gigante
      if (jsonParaEnviar.containsKey('imageBase64_1')) {
        jsonParaEnviar['imageBase64_1'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      if (jsonParaEnviar.containsKey('imageBase64_2')) {
        jsonParaEnviar['imageBase64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      _logger.i('🔍 JSON REINTENTO: ${json.encode(jsonParaEnviar)}');

      // Enviar con timeout más alto
      final respuesta = await enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 45, // Aumentado de 8 a 45 segundos
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

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  /// Inicia la sincronización automática cada 1 minuto (con backoff inteligente)
  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo) {
      Logger().i('⚠️ Sincronización automática ya está activa');
      return;
    }

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática inteligente cada 1 minuto para usuario $usuarioId...');

    _syncTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    // También ejecutar una vez al iniciar (después de 15 segundos para que la app esté lisa)
    Timer(Duration(seconds: 15), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  /// Detiene la sincronización automática
  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _usuarioActual = null;
      Logger().i('⏹️ Sincronización automática detenida');
    }
  }

  /// Ejecuta la sincronización automática (método privado)
  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo || _usuarioActual == null) return;

    try {
      final logger = Logger();
      logger.i('🔄 Ejecutando sincronización automática...');

      final service = CensoUploadService();
      final resultado = await service.sincronizarRegistrosPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        logger.i('✅ Auto-sync: ${resultado['exitosos']}/${resultado['total']} exitosos, ${resultado['fallidos']} fallidos');
      } else {
        logger.i('✅ Auto-sync: Sin registros pendientes');
      }

    } catch (e) {
      Logger().e('❌ Error en sincronización automática: $e');
    }
  }

  /// Verifica si la sincronización automática está activa
  static bool get esSincronizacionActiva => _syncActivo;

  /// Obtiene el ID del usuario actual en la sincronización
  static int? get usuarioActualSync => _usuarioActual;

  /// Fuerza una sincronización inmediata (útil para testing o eventos específicos)
  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) {
      Logger().w('⚠️ No se puede forzar sincronización: servicio no activo');
      return null;
    }

    Logger().i('⚡ Forzando sincronización inmediata...');
    final service = CensoUploadService();
    return await service.sincronizarRegistrosPendientes(_usuarioActual!);
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

  /// Sincroniza un registro individual con manejo de backoff exponencial
  Future<void> _sincronizarRegistroIndividualConBackoff(
      dynamic registro,
      int usuarioId,
      ) async {
    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);

    // Obtener número de intentos previos
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento)');

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

    // Actualizar timestamp del último intento
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    final respuesta = await enviarCensoAlServidor(
      datosParaApi,
      timeoutSegundos: 60,
      guardarLog: false,
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

      _logger.i('✅ Registro ${registro.id} sincronizado exitosamente después de $numeroIntento intento(s) (${fotos.length} fotos)');
    } else {
      await _estadoEquipoRepository.marcarComoError(
        registro.id!,
        'Error (intento #$numeroIntento): ${respuesta['mensaje']}',
      );

      final proximoIntento = _calcularProximoIntento(numeroIntento);
      _logger.w('⚠️ Error ${registro.id} intento #$numeroIntento: ${respuesta['mensaje']} - Próximo intento en $proximoIntento minutos');
    }
  }

  /// Filtra registros con error que ya pueden reintentarse según el backoff
  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(List<dynamic> registrosError) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);
        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);

        if (ultimoIntento == null) {
          // Si no hay registro de último intento, puede reintentarse
          registrosListos.add(registro);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
        final tiempoProximoIntento = ultimoIntento.add(Duration(minutes: minutosEspera));

        if (ahora.isAfter(tiempoProximoIntento)) {
          registrosListos.add(registro);
          _logger.i('📅 ${registro.id} listo para reintento (${intentos} intentos previos, espera de ${minutosEspera}min completada)');
        } else {
          final minutosRestantes = tiempoProximoIntento.difference(ahora).inMinutes;
          _logger.d('⏰ ${registro.id} debe esperar ${minutosRestantes} minutos más');
        }
      } catch (e) {
        _logger.w('⚠️ Error verificando reintento para ${registro.id}: $e');
        // En caso de error, permitir el reintento
        registrosListos.add(registro);
      }
    }

    return registrosListos;
  }

  /// Calcula el tiempo de espera para el próximo intento basado en el número de intentos
  int _calcularProximoIntento(int numeroIntento) {
    // Progresión: 1, 5, 10, 15, 20, 25, 30 (máximo)
    switch (numeroIntento) {
      case 1:
        return 1;   // 1 minuto después del primer fallo
      case 2:
        return 5;   // 5 minutos después del segundo fallo
      case 3:
        return 10;  // 10 minutos después del tercer fallo
      case 4:
        return 15;  // 15 minutos después del cuarto fallo
      case 5:
        return 20;  // 20 minutos después del quinto fallo
      case 6:
        return 25;  // 25 minutos después del sexto fallo
      default:
        return 30;  // 30 minutos máximo para intentos 7+
    }
  }

  /// Obtiene el número de intentos de sincronización de un registro
  Future<int> _obtenerNumeroIntentos(String estadoId) async {
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final registro = maps.first;
        return registro['intentos_sync'] as int? ?? 0;
      }
    } catch (e) {
      _logger.w('⚠️ Error obteniendo intentos para $estadoId: $e');
    }
    return 0;
  }

  /// Obtiene la fecha del último intento de sincronización
  Future<DateTime?> _obtenerUltimoIntento(String estadoId) async {
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final registro = maps.first;
        final ultimoIntentoStr = registro['ultimo_intento'] as String?;
        if (ultimoIntentoStr != null && ultimoIntentoStr.isNotEmpty) {
          return DateTime.parse(ultimoIntentoStr);
        }
      }
    } catch (e) {
      _logger.w('⚠️ Error obteniendo último intento para $estadoId: $e');
    }
    return null;
  }

  /// Actualiza el contador de intentos y timestamp del último intento
  Future<void> _actualizarUltimoIntento(String estadoId, int numeroIntento) async {
    try {
      final ahora = DateTime.now().toIso8601String();

      await _estadoEquipoRepository.dbHelper.actualizar(
        'censo_activo',
        {
          'intentos_sync': numeroIntento,
          'ultimo_intento': ahora,
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      _logger.w('⚠️ Error actualizando último intento para $estadoId: $e');
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
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

  /// Prepara datos directamente desde la BD sin transformaciones restrictivas
  Future<Map<String, dynamic>> _prepararPayloadDirectoDesdeBD(
      String estadoId,
      List<dynamic> fotos,
      ) async {
    try {
      _logger.i('📦 Preparando payload directo desde BD para: $estadoId');

      // Obtener TODOS los datos de la tabla censo_activo
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw Exception('No se encontró el censo: $estadoId');
      }

      // Clonar TODO el mapa (sin restricciones)
      final payload = Map<String, dynamic>.from(maps.first);

      // 🔄 CONVERTIR usuario_id → edfvendedorid para el servidor
      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(payload['usuario_id']);
      if (edfVendedorId != null) {
        payload['edfvendedorid'] = edfVendedorId;
        _logger.i('👤 Resuelto: usuario_id=${payload['usuario_id']} → edfvendedorid=$edfVendedorId');
      } else {
        payload['edfvendedorid'] = null;
        _logger.w('⚠️ No se pudo resolver edfvendedorid para usuario_id: ${payload['usuario_id']}');
      }

      // Solo agregar las imágenes base64 que no están en la tabla
      if (fotos.isNotEmpty) {
        payload['imagen_base64'] = fotos.first.imagenBase64;
        payload['imageBase64_1'] = fotos.first.imagenBase64;
        payload['tiene_imagen'] = true;
      }

      if (fotos.length > 1) {
        payload['imagen_base64_2'] = fotos[1].imagenBase64;
        payload['imageBase64_2'] = fotos[1].imagenBase64;
        payload['tiene_imagen2'] = true;
      }

      // Agregar array de fotos para el backend
      payload['fotos_censo_activo_foto'] = fotos.map((foto) => {
        'orden': foto.orden,
        'uuid': foto.id ?? 'N/A',
        'path': foto.imagenPath ?? '',
        'tamano': foto.imagenTamano ?? 0,
      }).toList();

      payload['total_imagenes'] = fotos.length;

      _logger.i('✅ Payload preparado con ${payload.keys.length} campos y ${fotos.length} fotos');

      return payload;
    } catch (e) {
      _logger.e('❌ Error preparando payload directo: $e');
      rethrow;
    }
  }

  /// Método helper para obtener edfvendedorid desde usuario_id
  Future<String?> _obtenerEdfVendedorIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) {
        _logger.i('👤 usuario_id es null - edfvendedorid será null');
        return null;
      }

      _logger.i('🔍 Buscando edfvendedorid para usuario_id: $usuarioId');

      // Consultar tabla Users para obtener el edf_vendedor_id
      final usuarioEncontrado = await _estadoEquipoRepository.dbHelper.consultar(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );

      if (usuarioEncontrado.isNotEmpty) {
        final edfVendedorId = usuarioEncontrado.first['edf_vendedor_id'] as String?;
        _logger.i('✅ edfvendedorid encontrado: usuario_id=$usuarioId → edfvendedorid=$edfVendedorId');
        return edfVendedorId;
      } else {
        _logger.w('⚠️ No se encontró usuario con id: $usuarioId');
        return null;
      }

    } catch (e) {
      _logger.e('❌ Error resolviendo edfvendedorid desde usuario_id: $e');
      return null;
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

        // Verificar que el registro existe
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

        // Obtener fotos asociadas
        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        // ✅ USAR MÉTODO DIRECTO SIN RESTRICCIONES
        final datosDeTabla = await _prepararPayloadDirectoDesdeBD(estadoId, fotos);

        // 🔍 LOG TEMPORAL PARA VER QUÉ SE ENVÍA (sin base64)
        final jsonParaLog = Map<String, dynamic>.from(datosDeTabla);
        if (jsonParaLog.containsKey('imagen_base64')) {
          jsonParaLog['imagen_base64'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaLog.containsKey('imagen_base64_2')) {
          jsonParaLog['imagen_base64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaLog.containsKey('imageBase64_1')) {
          jsonParaLog['imageBase64_1'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        if (jsonParaLog.containsKey('imageBase64_2')) {
          jsonParaLog['imageBase64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
        }
        _logger.i('🔍 JSON DIRECTO DE TABLA (${datosDeTabla.keys.length} campos): ${json.encode(jsonParaLog)}');

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

      // Verificar que el registro existe
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

      // Obtener fotos
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      _logger.i('📸 Fotos para reintento: ${fotos.length}');

      // ✅ USAR MÉTODO DIRECTO SIN RESTRICCIONES
      final datosParaApi = await _prepararPayloadDirectoDesdeBD(estadoId, fotos);

      // 🔍 LOG TEMPORAL PARA COMPARAR (sin imágenes base64 para que no sea gigante)
      final jsonParaLog = Map<String, dynamic>.from(datosParaApi);
      if (jsonParaLog.containsKey('imageBase64_1')) {
        jsonParaLog['imageBase64_1'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      if (jsonParaLog.containsKey('imageBase64_2')) {
        jsonParaLog['imageBase64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      if (jsonParaLog.containsKey('imagen_base64')) {
        jsonParaLog['imagen_base64'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      if (jsonParaLog.containsKey('imagen_base64_2')) {
        jsonParaLog['imagen_base64_2'] = '[BASE64_REMOVIDO_DEL_LOG]';
      }
      _logger.i('🔍 JSON REINTENTO (${datosParaApi.keys.length} campos): ${json.encode(jsonParaLog)}');

      // Enviar con timeout más alto
      final respuesta = await enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 45,
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

    // También ejecutar una vez al iniciar (después de 15 segundos para que la app esté lista)
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

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento, ${fotos.length} fotos)');

    // ✅ USAR MÉTODO DIRECTO SIN RESTRICCIONES
    final datosParaApi = await _prepararPayloadDirectoDesdeBD(registro.id!, fotos);

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
          _logger.i('📅 ${registro.id} listo para reintento ($intentos intentos previos, espera de ${minutosEspera}min completada)');
        } else {
          final minutosRestantes = tiempoProximoIntento.difference(ahora).inMinutes;
          _logger.d('⏰ ${registro.id} debe esperar $minutosRestantes minutos más');
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

}
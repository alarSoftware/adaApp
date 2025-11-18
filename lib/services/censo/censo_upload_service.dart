import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart'; // ✅ NUEVO IMPORT
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;
  final EquipoPendienteRepository _equipoPendienteRepository; // ✅ NUEVO REPOSITORY

  // ========== CONFIGURACIÓN ==========
  static const int maxIntentos = 10;
  static const Duration intervaloTimer = Duration(minutes: 1);

  // ========== VARIABLES ESTÁTICAS ==========
  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static bool _syncEnProgreso = false;
  static int? _usuarioActual;
  static final Set<String> _censosEnProceso = {};

  CensoUploadService({
    EstadoEquipoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
    EquipoPendienteRepository? equipoPendienteRepository, // ✅ INYECTABLE
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService(),
        _equipoPendienteRepository = equipoPendienteRepository ?? EquipoPendienteRepository(); // ✅ INICIALIZADO


  /// Ejecuta una función, la envuelve en try/catch, loguea el error y lo relanza.
  Future<T> _executeAndLogError<T>(
      Future<T> Function() future,
      String operation, {
        String? id,
        String? userId,
        String? endpoint,
        String tableName = 'censo_activo',
      }) async {
    try {
      return await future();
    } catch (e) {
      await ErrorLogService.logError(
        tableName: tableName,
        operation: operation,
        errorMessage: e.toString(),
        errorType: e is TimeoutException || e is SocketException || e is http.ClientException ? 'network' : 'unknown',
        registroFailId: id,
        userId: userId,
        endpoint: endpoint,
      );
      _logger.e('❌ Excepción atrapada y relanzada ($operation): $e');
      rethrow;
    }
  }

  // ==================== ENVÍO AL SERVIDOR ====================

  Future<Map<String, dynamic>> enviarCensoAlServidor(
      Map<String, dynamic> datos, {
        int timeoutSegundos = 60,
        bool guardarLog = false,
      }) async {
    final censoId = datos['id'] ?? datos['id_local'];
    final userId = datos['usuario_id']?.toString();
    const endpoint = '/censoActivo/insertCensoActivo';

    return await _executeAndLogError<Map<String, dynamic>>(() async {

      if (guardarLog) { /* ... lógica de log ... */ }

      final resultado = await BasePostService.post(
        endpoint: endpoint,
        body: datos,
        timeout: Duration(seconds: timeoutSegundos),
      );

      // 🚨 VALIDACIÓN ESTRICTA DE ÉXITO LÓGICO
      final serverAction = resultado['serverAction'] as int? ?? -999;

      if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
        return resultado; // ÉXITO
      } else {
        // ❌ ERROR LÓGICO (-501, 205, etc.)
        final errorMsg = resultado['resultError'] ?? resultado['mensaje'] ?? 'Error desconocido';

        // 🛑 Logueamos el error LÓGICO que generó el FALSO NEGATIVO
        await ErrorLogService.logServerError(
          tableName: 'censo_activo',
          operation: 'upload_logic_fail',
          errorMessage: errorMsg,
          errorCode: serverAction.toString(),
          registroFailId: censoId,
          endpoint: endpoint,
          userId: userId,
        );

        // Retornamos el resultado negativo para que el llamador lo marque como error.
        return {'exito': false, 'mensaje': errorMsg, 'serverAction': serverAction};
      }
    }, 'upload', id: censoId, userId: userId, endpoint: endpoint);
  }

  Future<Map<String, dynamic>> _prepararPayloadConMapper(
      String estadoId,
      List<dynamic> fotos,
      ) async {
    return await _executeAndLogError<Map<String, dynamic>>(() async {

      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo', where: 'id = ?', whereArgs: [estadoId], limit: 1,
      );

      if (maps.isEmpty) throw Exception('No se encontró el censo: $estadoId');

      final datosLocales = maps.first;
      final usuarioId = datosLocales['usuario_id'] as int?;
      if (usuarioId == null) throw Exception('usuario_id es requerido');

      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      final estaAsignado = await _verificarEquipoAsignado(datosLocales['equipo_id']?.toString(), datosLocales['cliente_id']);

      final datosLocalesMutable = Map<String, dynamic>.from(datosLocales);
      datosLocalesMutable['ya_asignado'] = estaAsignado;

      final payload = CensoApiMapper.prepararDatosParaApi(
        datosLocales: datosLocalesMutable,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId!,
        fotosConBase64: fotos,
      );

      return payload;
    }, 'prepare_payload', id: estadoId);
  }

  // ==================== SINCRONIZACIÓN EN BACKGROUND ====================

  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    if (_censosEnProceso.contains(estadoId)) return;
    _censosEnProceso.add(estadoId);

    try {
      _logger.i('🔄 Sincronización background para: $estadoId');

      // 🛑 VALIDACIÓN: BLOQUEAR SI HAY PENDIENTE LOCAL
      final equipoId = datos['equipo_id'] as String?;
      final clienteId = datos['cliente_id'] as int?;

      if (equipoId != null && clienteId != null) {
        final hayPendiente = await _existePendienteAsignacion(equipoId, clienteId);
        if (hayPendiente) {
          _logger.w('⏸️ Background sync pospuesto para $estadoId: Pendiente de asignación en cola (equipo: $equipoId, cliente: $clienteId)');
          return;
        }
      }

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);

      final datosParaApi = await _prepararPayloadConMapper(estadoId, fotos);
      await _actualizarUltimoIntento(estadoId, 1);

      final respuesta = await enviarCensoAlServidor(datosParaApi, timeoutSegundos: 45);

      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(estadoId, servidorId: respuesta['servidor_id']);
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);
        for (final foto in fotos) {
          if (foto.id != null) await _fotoRepository.marcarComoSincronizada(foto.id!);
        }
        _logger.i('✅ Sincronización exitosa: $estadoId');
      } else {
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Error Lógico: ${respuesta['mensaje']}');
      }
    } catch (e) {
      await _actualizarUltimoIntento(estadoId, 1);
      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción técnica: ${e.toString()}');
    } finally {
      _censosEnProceso.remove(estadoId);
    }
  }

  // ==================== SINCRONIZACIÓN DE PENDIENTES ====================

  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    _logger.i('🔄 Sincronización de pendientes...');
    int exitosos = 0;
    int fallidos = 0;

    final registrosCreados = await _estadoEquipoRepository.obtenerCreados();
    final registrosError = await _estadoEquipoRepository.obtenerConError();
    final registrosErrorListos = await _filtrarRegistrosListosParaReintento(registrosError);
    final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

    if (todosLosRegistros.isEmpty) return {'exitosos': 0, 'fallidos': 0, 'total': 0};

    for (final registro in todosLosRegistros) {
      try {
        await _sincronizarRegistroIndividualConBackoff(registro, usuarioId);
        exitosos++;
      } catch (e) {
        fallidos++;
        if (registro.id != null) {
          await _estadoEquipoRepository.marcarComoError(registro.id!, 'Excepción: ${e.toString()}');
        }
      }
    }

    _logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');
    return {'exitosos': exitosos, 'fallidos': fallidos, 'total': todosLosRegistros.length};
  }

  Future<void> _sincronizarRegistroIndividualConBackoff(
      dynamic registro,
      int usuarioId,
      ) async {

    final equipoId = registro.equipoId as String?;
    final clienteId = registro.clienteId as int?;

    if (equipoId != null && clienteId != null) {
      final hayPendiente = await _existePendienteAsignacion(equipoId, clienteId);

      if (hayPendiente) {
        _logger.w('⏸️ Censo ${registro.id} pospuesto: Pendiente de asignación en cola (equipo: $equipoId, cliente: $clienteId)');
        // NO incrementamos intentos, simplemente salimos sin hacer nada
        await ErrorLogService.logValidationError(
            tableName: 'censo_activo',
            operation: 'SYNC_PAUSED_DEPENDENCY', // Operación clara para identificar la causa
            errorMessage: 'Censo bloqueado. Equipo pendiente de asignación no sincronizado.',
            registroFailId: registro.id,
            userId: usuarioId.toString(),
        );

        return;
      }
    }

    // ✅ Si llegamos aquí, NO hay bloqueos, continuar normalmente
    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    if (numeroIntento > maxIntentos) {
      await _estadoEquipoRepository.marcarComoError(registro.id!, 'Fallo permanente: máximo de intentos alcanzado');
      await ErrorLogService.logError(tableName: 'censo_activo', operation: 'sync_max_retries', errorMessage: 'Máximo de intentos alcanzado', errorType: 'max_retries', registroFailId: registro.id, userId: usuarioId.toString());
      return;
    }

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento/$maxIntentos)');

    final datosParaApi = await _prepararPayloadConMapper(registro.id!, fotos);
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    final respuesta = await enviarCensoAlServidor(datosParaApi, timeoutSegundos: 60);

    if (respuesta['exito'] == true) {
      await _estadoEquipoRepository.marcarComoMigrado(registro.id!, servidorId: respuesta['id']);
      await _estadoEquipoRepository.marcarComoSincronizado(registro.id!);
      for (final foto in fotos) {
        if (foto.id != null) await _fotoRepository.marcarComoSincronizada(foto.id!);
      }
    } else {
      await _estadoEquipoRepository.marcarComoError(registro.id!, 'Error (intento #$numeroIntento): ${respuesta['mensaje']}');
    }
  }

  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      // 🛑 VALIDACIÓN: BLOQUEAR SI HAY PENDIENTE LOCAL
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo', where: 'id = ?', whereArgs: [estadoId], limit: 1,
      );

      if (maps.isNotEmpty) {
        final equipoId = maps.first['equipo_id'] as String?;
        final clienteId = maps.first['cliente_id'] as int?;

        if (equipoId != null && clienteId != null) {
          final hayPendiente = await _existePendienteAsignacion(equipoId, clienteId);
          if (hayPendiente) {
            return {
              'success': false,
              'error': 'Censo bloqueado: existe un pendiente de asignación en cola para este equipo'
            };
          }
        }
      }

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await _prepararPayloadConMapper(estadoId, fotos);

      final respuesta = await enviarCensoAlServidor(datosParaApi, timeoutSegundos: 45);

      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(estadoId, servidorId: respuesta['id']);
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);
        for (final foto in fotos) {
          if (foto.id != null) {
            await _fotoRepository.marcarComoSincronizada(foto.id!);
          }
        }
        return {'success': true, 'message': 'Registro sincronizado'};
      } else {
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Error: ${respuesta['mensaje']}');
        return {'success': false, 'error': respuesta['mensaje']};
      }
    } catch (e) {
      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción en reintento manual: ${e.toString()}');
      return {'success': false, 'error': 'Error de conexión o datos: ${e.toString()}'};
    }
  }

  // ==================== MÉTODOS ESTÁTICOS Y AUXILIARES ====================

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('⚠️ Sincronización ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática cada ${intervaloTimer.inMinutes} min para usuario $usuarioId');

    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    Timer(const Duration(seconds: 15), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _syncEnProgreso = false;
      _usuarioActual = null;
      _censosEnProceso.clear();
      Logger().i('⏹️ Sincronización automática detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) return;

    _syncEnProgreso = true;

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        Logger().w('⚠️ Sin conexión al servidor: ${conexion.mensaje}');
        return;
      }

      final service = CensoUploadService();
      final resultado = await service.sincronizarRegistrosPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        Logger().i('✅ Auto-sync: ${resultado['exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en sincronización automática: $e');
    } finally {
      _syncEnProgreso = false;
    }
  }

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) return null;

    Logger().i('⚡ Forzando sincronización...');
    final service = CensoUploadService();
    return await service.sincronizarRegistrosPendientes(_usuarioActual!);
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;

  // ==================== MÉTODOS PRIVADOS ====================

  /// ✅ NUEVO: Verifica si existe un pendiente de asignación no sincronizado
  Future<bool> _existePendienteAsignacion(String equipoId, int clienteId) async {
    try {
      final maps = await _equipoPendienteRepository.dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ? AND sincronizado = 0',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        _logger.i('🔒 Pendiente local detectado para equipo $equipoId - cliente $clienteId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error verificando pendiente de asignación: $e');
      // En caso de error de DB, ser conservador y bloquear
      return true;
    }
  }

  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(List<dynamic> registrosError) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);
        if (intentos >= maxIntentos) continue;

        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);
        if (ultimoIntento == null) { registrosListos.add(registro); continue; }

        final minutosEspera = _calcularProximoIntento(intentos);
        if (minutosEspera < 0) continue;

        final tiempoProximoIntento = ultimoIntento.add(Duration(minutes: minutosEspera));

        if (ahora.isAfter(tiempoProximoIntento)) registrosListos.add(registro);
      } catch (e) {
        _logger.w('⚠️ Error verificando ${registro.id}: $e');
        registrosListos.add(registro);
      }
    }
    return registrosListos;
  }

  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;
    switch (numeroIntento) {
      case 1: return 1;
      case 2: return 5;
      case 3: return 10;
      case 4: return 15;
      case 5: return 20;
      case 6: return 25;
      default: return 30;
    }
  }

  Future<int> _obtenerNumeroIntentos(String estadoId) async {
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoId],
          limit: 1
      );
      return maps.isNotEmpty ? maps.first['intentos_sync'] as int? ?? 0 : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<DateTime?> _obtenerUltimoIntento(String estadoId) async {
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoId],
          limit: 1
      );
      if (maps.isNotEmpty) {
        final ultimoIntentoStr = maps.first['ultimo_intento'] as String?;
        if (ultimoIntentoStr != null && ultimoIntentoStr.isNotEmpty) {
          return DateTime.parse(ultimoIntentoStr);
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _actualizarUltimoIntento(String estadoId, int numeroIntento) async {
    try {
      await _estadoEquipoRepository.dbHelper.actualizar(
          'censo_activo',
          {
            'intentos_sync': numeroIntento,
            'ultimo_intento': DateTime.now().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [estadoId]
      );
    } catch (e) {
      _logger.w('⚠️ Error actualizando último intento: $e');
    }
  }

  Future<String?> _obtenerEdfVendedorIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) return null;
      final usuarioEncontrado = await _estadoEquipoRepository.dbHelper.consultar(
          'Users',
          where: 'id = ?',
          whereArgs: [usuarioId],
          limit: 1
      );
      return usuarioEncontrado.isNotEmpty ? usuarioEncontrado.first['edf_vendedor_id'] as String? : null;
    } catch (e) {
      _logger.e('❌ Error resolviendo edfvendedorid: $e');
      return null;
    }
  }

  Future<bool> _verificarEquipoAsignado(String? equipoId, dynamic clienteId) async {
    try {
      if (equipoId == null || clienteId == null) return false;
      final equipoRepository = EquipoRepository();
      return await equipoRepository.verificarAsignacionEquipoCliente(
          equipoId,
          _convertirAInt(clienteId)
      );
    } catch (e) {
      _logger.w('⚠️ Error verificando asignación: $e');
      return false;
    }
  }

  int _convertirAInt(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor;
    if (valor is String) return int.tryParse(valor) ?? 0;
    if (valor is double) return valor.toInt();
    return 0;
  }
}
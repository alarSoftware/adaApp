import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/post/equipo_post_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;
  final EquipoPendienteRepository _equipoPendienteRepository; // ✅ NUEVO
  final EquipoRepository _equipoRepository; // ✅ NUEVO

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
    EquipoPendienteRepository? equipoPendienteRepository, // ✅ NUEVO
    EquipoRepository? equipoRepository, // ✅ NUEVO
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService(),
        _equipoPendienteRepository = equipoPendienteRepository ?? EquipoPendienteRepository(), // ✅ NUEVO
        _equipoRepository = equipoRepository ?? EquipoRepository(); // ✅ NUEVO

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

        await ErrorLogService.logServerError(
          tableName: 'censo_activo',
          operation: 'upload_logic_fail',
          errorMessage: errorMsg,
          errorCode: serverAction.toString(),
          registroFailId: censoId,
          endpoint: endpoint,
          userId: userId,
        );

        return {'exito': false, 'mensaje': errorMsg, 'serverAction': serverAction};
      }
    }, 'upload', id: censoId, userId: userId, endpoint: endpoint);
  }

  /// TODO: PREPARAR PAYLOAD CON MAPPER (usado por ViewModel)
  /// Obtiene datos del censo desde BD y prepara payload para API
  Future<Map<String, dynamic>> prepararPayloadConMapper(
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

      // 🔍 LOG DE DEBUG PARA ENCONTRAR PROBLEMA
      _logger.i('🔍 DEBUG prepararPayloadConMapper:');
      _logger.i('   estadoId: $estadoId');
      _logger.i('   usuario_id en BD: $usuarioId');
      _logger.i('   datosLocales keys: ${datosLocales.keys.toList()}');

      if (usuarioId == null) {
        _logger.e('❌ usuario_id es NULL en la BD');
        _logger.e('   Datos completos del censo: $datosLocales');
        throw Exception('usuario_id es requerido');
      }

      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      final estaAsignado = await _verificarEquipoAsignado(
          datosLocales['equipo_id']?.toString(),
          datosLocales['cliente_id']
      );

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

  /// TODO: SINCRONIZACIÓN INDIVIDUAL EN BACKGROUND (llamada desde ViewModel)
  /// Se ejecuta después de guardar localmente, sin bloquear al usuario
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    if (_censosEnProceso.contains(estadoId)) return;
    _censosEnProceso.add(estadoId);

    try {
      _logger.i('🔄 Sincronización background para: $estadoId');

      // ✅ SIN VALIDACIONES DE BLOQUEO
      // El ViewModel ya sincronizó equipo y pendiente ANTES de llamar aquí

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await prepararPayloadConMapper(estadoId, fotos);
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

  // ==================== SINCRONIZACIÓN PERIÓDICA ====================

  /// TODO: SISTEMA DE REINTENTOS PERIÓDICOS MEJORADO
  /// Este método se ejecuta automáticamente cada minuto
  /// Sincroniza Equipos → Pendientes → Censos en orden
  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    _logger.i('═══════════════════════════════════════════════════════');
    _logger.i('🔄 SINCRONIZACIÓN PERIÓDICA AUTOMÁTICA');
    _logger.i('═══════════════════════════════════════════════════════');

    int equiposExitosos = 0;
    int pendientesExitosos = 0;
    int censosExitosos = 0;
    int totalFallidos = 0;

    try {
      // ============================================================
      // TODO: PASO 1 - SINCRONIZAR EQUIPOS PENDIENTES
      // ============================================================
      _logger.i('📤 PASO 1: Sincronizando EQUIPOS pendientes...');

      final equiposPendientes = await _equipoRepository.obtenerEquiposNoSincronizados();

      _logger.i('   Equipos encontrados: ${equiposPendientes.length}');

      // Limitar a 10 equipos por ciclo (rate limiting)
      for (final equipo in equiposPendientes.take(10)) {
        try {
          final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
          if (edfVendedorId == null) {
            _logger.w('   ⚠️ Sin edfVendedorId para equipo ${equipo['id']}');
            continue;
          }

          final resultado = await EquipoPostService.enviarEquipoNuevo(
            equipoId: equipo['id'],
            codigoBarras: equipo['cod_barras'] ?? '',
            marcaId: equipo['marca_id'],
            modeloId: equipo['modelo_id'],
            logoId: equipo['logo_id'],
            numeroSerie: equipo['numero_serie'],
            clienteId: equipo['cliente_id'],
            edfVendedorId: edfVendedorId,
          ).timeout(Duration(seconds: 20));

          if (resultado['exito'] == true) {
            await _equipoRepository.marcarEquipoComoSincronizado(equipo['id']);
            equiposExitosos++;
            _logger.i('   ✅ Equipo sincronizado: ${equipo['id']}');
          } else {
            _logger.w('   ⚠️ Equipo NO sincronizado: ${equipo['id']} - ${resultado['mensaje']}');
          }

          // Rate limiting: 500ms entre cada request
          await Future.delayed(Duration(milliseconds: 500));

        } catch (e) {
          _logger.w('   ⚠️ Error en equipo ${equipo['id']}: $e');
          totalFallidos++;
        }
      }

      _logger.i('   Resultado PASO 1: $equiposExitosos/${equiposPendientes.take(10).length} exitosos');

      // ============================================================
      // TODO: PASO 2 - SINCRONIZAR PENDIENTES
      // ============================================================
      _logger.i('📤 PASO 2: Sincronizando PENDIENTES...');

      try {
        final pendientesResult = await _equipoPendienteRepository.sincronizarPendientesAlServidor();

        if (pendientesResult['exito'] == true) {
          pendientesExitosos = 1;
          _logger.i('   ✅ Pendientes sincronizados correctamente');
        } else {
          _logger.w('   ⚠️ Error en pendientes: ${pendientesResult['mensaje']}');
        }
      } catch (e) {
        _logger.w('   ⚠️ Excepción en pendientes: $e');
      }

      // ============================================================
      // TODO: PASO 3 - SINCRONIZAR CENSOS
      // ============================================================
      _logger.i('📤 PASO 3: Sincronizando CENSOS...');

      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();
      final registrosError = await _estadoEquipoRepository.obtenerConError();
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(registrosError);

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      _logger.i('   Censos creados: ${registrosCreados.length}');
      _logger.i('   Censos con error listos: ${registrosErrorListos.length}');
      _logger.i('   Total a procesar: ${todosLosRegistros.length}');

      // Limitar a 20 censos por ciclo
      final registrosAProcesar = todosLosRegistros.take(20);

      _logger.i('   Procesando: ${registrosAProcesar.length} censos');

      for (final registro in registrosAProcesar) {
        try {
          await _sincronizarRegistroIndividualConBackoff(registro, usuarioId);
          censosExitosos++;
          _logger.i('   ✅ Censo sincronizado: ${registro.id}');
        } catch (e) {
          _logger.e('   ❌ Error en censo ${registro.id}: $e');
          totalFallidos++;

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
              registro.id!,
              'Excepción: ${e.toString()}',
            );
          }
        }

        // Rate limiting: 500ms entre cada request
        await Future.delayed(Duration(milliseconds: 500));
      }

      _logger.i('   Resultado PASO 3: $censosExitosos/${registrosAProcesar.length} exitosos');

      // ============================================================
      // RESUMEN FINAL
      // ============================================================
      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('✅ SINCRONIZACIÓN PERIÓDICA COMPLETADA');
      _logger.i('   - Equipos exitosos: $equiposExitosos');
      _logger.i('   - Pendientes exitosos: $pendientesExitosos');
      _logger.i('   - Censos exitosos: $censosExitosos');
      _logger.i('   - Total fallidos: $totalFallidos');
      _logger.i('═══════════════════════════════════════════════════════');

      return {
        'equipos_exitosos': equiposExitosos,
        'pendientes_exitosos': pendientesExitosos,
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': equiposExitosos + pendientesExitosos + censosExitosos,
      };

    } catch (e) {
      _logger.e('❌ Error en sincronización periódica: $e');
      return {
        'equipos_exitosos': equiposExitosos,
        'pendientes_exitosos': pendientesExitosos,
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': 0,
      };
    }
  }

  /// TODO: SINCRONIZACIÓN INDIVIDUAL CON BACKOFF (reintentos automáticos)
  /// Intenta sincronizar un censo individual con lógica de reintentos
  Future<void> _sincronizarRegistroIndividualConBackoff(
      dynamic registro,
      int usuarioId,
      ) async {

    // ✅ VALIDACIONES DE BLOQUEO ELIMINADAS
    // Todos los censos intentan sincronizarse sin restricciones

    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    if (numeroIntento > maxIntentos) {
      await _estadoEquipoRepository.marcarComoError(
          registro.id!,
          'Fallo permanente: máximo de intentos alcanzado'
      );
      await ErrorLogService.logError(
          tableName: 'censo_activo',
          operation: 'sync_max_retries',
          errorMessage: 'Máximo de intentos alcanzado',
          errorType: 'max_retries',
          registroFailId: registro.id,
          userId: usuarioId.toString()
      );
      return;
    }

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento/$maxIntentos)');

    final datosParaApi = await prepararPayloadConMapper(registro.id!, fotos);
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    final respuesta = await enviarCensoAlServidor(datosParaApi, timeoutSegundos: 60);

    if (respuesta['exito'] == true) {
      await _estadoEquipoRepository.marcarComoMigrado(registro.id!, servidorId: respuesta['id']);
      await _estadoEquipoRepository.marcarComoSincronizado(registro.id!);
      for (final foto in fotos) {
        if (foto.id != null) await _fotoRepository.marcarComoSincronizada(foto.id!);
      }
    } else {
      await _estadoEquipoRepository.marcarComoError(
          registro.id!,
          'Error (intento #$numeroIntento): ${respuesta['mensaje']}'
      );
    }
  }

  /// TODO: REINTENTO MANUAL (desde UI)
  /// Permite al usuario reintentar manualmente un censo fallido
  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      // ✅ SIN VALIDACIONES DE BLOQUEO - Permitimos reintentos manuales siempre

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await prepararPayloadConMapper(estadoId, fotos);

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

  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(List<dynamic> registrosError) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);
        if (intentos >= maxIntentos) continue;

        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);
        if (ultimoIntento == null) {
          registrosListos.add(registro);
          continue;
        }

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
      return await _equipoRepository.verificarAsignacionEquipoCliente(
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
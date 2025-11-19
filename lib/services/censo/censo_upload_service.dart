import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/post/censo_unificado_post_service.dart'; // 🔥 NUEVO
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;
  final EquipoPendienteRepository _equipoPendienteRepository;
  final EquipoRepository _equipoRepository;

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
    EquipoPendienteRepository? equipoPendienteRepository,
    EquipoRepository? equipoRepository,
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService(),
        _equipoPendienteRepository = equipoPendienteRepository ?? EquipoPendienteRepository(),
        _equipoRepository = equipoRepository ?? EquipoRepository();

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

  // ==================== ENVÍO AL SERVIDOR (UNIFICADO) ====================

  /// 🔥 MÉTODO PRINCIPAL ACTUALIZADO - Usa el nuevo servicio unificado
  Future<Map<String, dynamic>> enviarCensoUnificadoAlServidor(
      Map<String, dynamic> datosLocales,
      List<dynamic> fotos, {
        int timeoutSegundos = 60,
        bool guardarLog = false,
      }) async {
    final censoId = datosLocales['id'] ?? datosLocales['id_local'];
    final userId = datosLocales['usuario_id']?.toString();

    return await _executeAndLogError<Map<String, dynamic>>(() async {
      _logger.i('🔄 Enviando censo unificado: $censoId');

      // Obtener datos adicionales necesarios
      final usuarioId = datosLocales['usuario_id'] as int;
      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);

      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw Exception('edfVendedorId es requerido para el envío');
      }

      // Determinar si es nuevo equipo y si crear pendiente
      final esNuevoEquipo = datosLocales['es_nuevo_equipo'] == true;
      final equipoId = datosLocales['equipo_id']?.toString();
      final clienteId = _convertirAInt(datosLocales['cliente_id']);

      // Verificar si necesita crear pendiente
      final crearPendiente = esNuevoEquipo || !await _verificarEquipoAsignado(equipoId, clienteId);

      // 🔥 LLAMADA AL NUEVO SERVICIO UNIFICADO
      final resultado = await CensoUnificadoPostService.enviarCensoUnificado(
        // Datos del equipo (si es nuevo)
        equipoId: equipoId,
        codigoBarras: datosLocales['codigo_barras']?.toString(),
        marcaId: datosLocales['marca_id'] as int?,
        modeloId: datosLocales['modelo_id'] as int?,
        logoId: datosLocales['logo_id'] as int?,
        numeroSerie: datosLocales['numero_serie']?.toString(),
        esNuevoEquipo: esNuevoEquipo,

        // Datos del pendiente
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        crearPendiente: crearPendiente,

        // Datos del censo activo
        usuarioId: usuarioId,
        latitud: datosLocales['latitud']?.toDouble() ?? 0.0,
        longitud: datosLocales['longitud']?.toDouble() ?? 0.0,
        observaciones: datosLocales['observaciones']?.toString(),
        enLocal: datosLocales['en_local'] == true,
        estadoCenso: datosLocales['ya_asignado'] == true ? 'asignado' : 'pendiente',

        // Fotos
        fotos: fotos,

        // Datos adicionales del equipo
        clienteNombre: datosLocales['cliente_nombre']?.toString(),
        marca: datosLocales['marca_nombre']?.toString(),
        modelo: datosLocales['modelo']?.toString(),
        logo: datosLocales['logo']?.toString(),

        // Control
        timeoutSegundos: timeoutSegundos,
        userId: userId,
      );

      if (guardarLog) {
        // TODO: Implementar logging específico para unificado si es necesario
      }

      return resultado;

    }, 'upload_unificado', id: censoId, userId: userId);
  }

  /// TODO: PREPARAR PAYLOAD CON MAPPER (actualizado para unificado)
  Future<Map<String, dynamic>> prepararPayloadUnificado(
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

      _logger.i('🔍 DEBUG prepararPayloadUnificado:');
      _logger.i('   estadoId: $estadoId');
      _logger.i('   usuario_id en BD: $usuarioId');

      if (usuarioId == null) {
        _logger.e('❌ usuario_id es NULL en la BD');
        throw Exception('usuario_id es requerido');
      }

      // Preparar datos adicionales
      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      final equipoId = datosLocales['equipo_id']?.toString();
      final clienteId = datosLocales['cliente_id'];

      final estaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);

      final datosLocalesMutable = Map<String, dynamic>.from(datosLocales);
      datosLocalesMutable['ya_asignado'] = estaAsignado;

      // Retornar datos preparados para envío unificado
      return datosLocalesMutable;

    }, 'prepare_payload_unificado', id: estadoId);
  }

  // ==================== SINCRONIZACIÓN EN BACKGROUND (SIMPLIFICADA) ====================

  /// TODO: SINCRONIZACIÓN INDIVIDUAL SIMPLIFICADA (ya no necesita 3 pasos)
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    if (_censosEnProceso.contains(estadoId)) return;
    _censosEnProceso.add(estadoId);

    try {
      _logger.i('🔄 Sincronización unificada para: $estadoId');

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await prepararPayloadUnificado(estadoId, fotos);
      await _actualizarUltimoIntento(estadoId, 1);

      // 🔥 UNA SOLA LLAMADA UNIFICADA
      final respuesta = await enviarCensoUnificadoAlServidor(datosParaApi, fotos, timeoutSegundos: 45);

      if (respuesta['exito'] == true) {
        // Marcar todo como sincronizado
        await _estadoEquipoRepository.marcarComoMigrado(estadoId, servidorId: respuesta['servidor_id']);
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

        // Si era nuevo equipo, marcarlo como sincronizado
        final equipoId = datosParaApi['equipo_id']?.toString();
        if (equipoId != null && datosParaApi['es_nuevo_equipo'] == true) {
          await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
        }

        // Si tenía pendiente, marcarlo como sincronizado
        final clienteId = datosParaApi['cliente_id'];
        if (equipoId != null && clienteId != null) {
          await _equipoPendienteRepository.marcarSincronizadosPorCenso(equipoId, clienteId);
        }

        // Marcar fotos como sincronizadas
        for (final foto in fotos) {
          if (foto.id != null) await _fotoRepository.marcarComoSincronizada(foto.id!);
        }

        _logger.i('✅ Sincronización unificada exitosa: $estadoId');
      } else {
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Error: ${respuesta['mensaje']}');
      }
    } catch (e) {
      await _actualizarUltimoIntento(estadoId, 1);
      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: ${e.toString()}');
    } finally {
      _censosEnProceso.remove(estadoId);
    }
  }

  // ==================== SINCRONIZACIÓN PERIÓDICA (SIMPLIFICADA) ====================

  /// TODO: SINCRONIZACIÓN PERIÓDICA SIMPLIFICADA (solo censos, ya no equipos y pendientes separados)
  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    _logger.i('═══════════════════════════════════════════════════════');
    _logger.i('🔄 SINCRONIZACIÓN PERIÓDICA UNIFICADA');
    _logger.i('═══════════════════════════════════════════════════════');

    int censosExitosos = 0;
    int totalFallidos = 0;

    try {
      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();
      final registrosError = await _estadoEquipoRepository.obtenerConError();
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(registrosError);

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      _logger.i('📊 Total censos a procesar: ${todosLosRegistros.length}');

      // Limitar a 20 censos por ciclo
      final registrosAProcesar = todosLosRegistros.take(20);

      for (final registro in registrosAProcesar) {
        try {
          await _sincronizarRegistroIndividualUnificado(registro, usuarioId);
          censosExitosos++;
          _logger.i('✅ Censo unificado sincronizado: ${registro.id}');
        } catch (e) {
          _logger.e('❌ Error en censo ${registro.id}: $e');
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

      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('✅ SINCRONIZACIÓN UNIFICADA COMPLETADA');
      _logger.i('   - Censos exitosos: $censosExitosos');
      _logger.i('   - Total fallidos: $totalFallidos');
      _logger.i('═══════════════════════════════════════════════════════');

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': censosExitosos,
      };

    } catch (e) {
      _logger.e('❌ Error en sincronización periódica unificada: $e');
      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': 0,
      };
    }
  }

  /// TODO: SINCRONIZACIÓN INDIVIDUAL UNIFICADA
  Future<void> _sincronizarRegistroIndividualUnificado(
      dynamic registro,
      int usuarioId,
      ) async {

    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    if (numeroIntento > maxIntentos) {
      await _estadoEquipoRepository.marcarComoError(
          registro.id!,
          'Fallo permanente: máximo de intentos alcanzado'
      );
      return;
    }

    _logger.i('🔄 Sincronizando unificado ${registro.id} (intento #$numeroIntento/$maxIntentos)');

    final datosParaApi = await prepararPayloadUnificado(registro.id!, fotos);
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    // 🔥 UNA SOLA LLAMADA UNIFICADA
    final respuesta = await enviarCensoUnificadoAlServidor(datosParaApi, fotos, timeoutSegundos: 60);

    if (respuesta['exito'] == true) {
      await _estadoEquipoRepository.marcarComoMigrado(registro.id!, servidorId: respuesta['id']);
      await _estadoEquipoRepository.marcarComoSincronizado(registro.id!);

      // Marcar dependencias como sincronizadas
      final equipoId = datosParaApi['equipo_id']?.toString();
      final clienteId = datosParaApi['cliente_id'];

      if (equipoId != null && datosParaApi['es_nuevo_equipo'] == true) {
        await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
      }

      if (equipoId != null && clienteId != null) {
        await _equipoPendienteRepository.marcarSincronizadosPorCenso(equipoId, clienteId);
      }

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

  /// TODO: REINTENTO MANUAL UNIFICADO
  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await prepararPayloadUnificado(estadoId, fotos);

      // 🔥 UNA SOLA LLAMADA UNIFICADA
      final respuesta = await enviarCensoUnificadoAlServidor(datosParaApi, fotos, timeoutSegundos: 45);

      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(estadoId, servidorId: respuesta['id']);
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

        // Marcar dependencias
        final equipoId = datosParaApi['equipo_id']?.toString();
        final clienteId = datosParaApi['cliente_id'];

        if (equipoId != null && datosParaApi['es_nuevo_equipo'] == true) {
          await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
        }

        if (equipoId != null && clienteId != null) {
          await _equipoPendienteRepository.marcarSincronizadosPorCenso(equipoId, clienteId);
        }

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

  // ==================== MÉTODOS ESTÁTICOS Y AUXILIARES (sin cambios) ====================

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('⚠️ Sincronización ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática unificada cada ${intervaloTimer.inMinutes} min para usuario $usuarioId');

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
        Logger().i('✅ Auto-sync unificado: ${resultado['censos_exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en sincronización automática unificada: $e');
    } finally {
      _syncEnProgreso = false;
    }
  }

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) return null;

    Logger().i('⚡ Forzando sincronización unificada...');
    final service = CensoUploadService();
    return await service.sincronizarRegistrosPendientes(_usuarioActual!);
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;

  // ==================== MÉTODOS PRIVADOS (sin cambios) ====================

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
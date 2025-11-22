import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
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

  // ==================== SINCRONIZACIÓN EN BACKGROUND ====================

  /// Sincronización individual en background (usa servicio unificado directamente)
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    if (_censosEnProceso.contains(estadoId)) return;
    _censosEnProceso.add(estadoId);

    try {
      _logger.i('🔄 Sincronización background unificada: $estadoId');

      // 1. Obtener datos frescos de BD
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.w('⚠️ Censo no encontrado: $estadoId');
        return;
      }

      final datosLocales = Map<String, dynamic>.from(maps.first);

      // 2. Enriquecer datos del equipo
      final equipoId = datosLocales['equipo_id']?.toString();
      if (equipoId != null) {
        await _enriquecerDatosEquipo(datosLocales, equipoId);
      }

      // 3. Obtener fotos
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);

      // 4. Obtener datos del usuario
      final usuarioId = datosLocales['usuario_id'] as int?;
      if (usuarioId == null) {
        throw Exception('usuario_id no encontrado en censo');
      }

      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw Exception('edfVendedorId no encontrado');
      }

      // 5. Determinar flags
      final esNuevoEquipo = datosLocales['es_nuevo_equipo'] == true;
      final clienteId = _convertirAInt(datosLocales['cliente_id']);
      final yaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);
      final crearPendiente = !yaAsignado;

      await _actualizarUltimoIntento(estadoId, 1);

      // 🔥 LLAMADA DIRECTA AL SERVICIO UNIFICADO
      final respuesta = await CensoActivoPostService.enviarCensoActivo(
        equipoId: equipoId,
        codigoBarras: datosLocales['codigo_barras']?.toString(),
        marcaId: datosLocales['marca_id'] as int?,
        modeloId: datosLocales['modelo_id'] as int?,
        logoId: datosLocales['logo_id'] as int?,
        numeroSerie: datosLocales['numero_serie']?.toString(),
        esNuevoEquipo: esNuevoEquipo,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        crearPendiente: crearPendiente,
        usuarioId: usuarioId,
        latitud: datosLocales['latitud']?.toDouble() ?? 0.0,
        longitud: datosLocales['longitud']?.toDouble() ?? 0.0,
        observaciones: datosLocales['observaciones']?.toString(),
        enLocal: datosLocales['en_local'] == true,
        estadoCenso: yaAsignado ? 'asignado' : 'pendiente',
        fotos: fotos,
        clienteNombre: datosLocales['cliente_nombre']?.toString(),
        marca: datosLocales['marca_nombre']?.toString(),
        modelo: datosLocales['modelo']?.toString(),
        logo: datosLocales['logo']?.toString(),
        timeoutSegundos: 45,
        userId: usuarioId.toString(),
        guardarLog: false,
      );

      // 6. Procesar resultado
      if (respuesta['exito'] == true) {
        await _marcarComoSincronizadoCompleto(
          estadoId: estadoId,
          servidorId: respuesta['servidor_id'],
          equipoId: equipoId,
          clienteId: clienteId,
          esNuevoEquipo: esNuevoEquipo,
          crearPendiente: crearPendiente,
          fotos: fotos,
        );
        _logger.i('✅ Sincronización background exitosa: $estadoId');
      } else {
        await _estadoEquipoRepository.marcarComoError(
          estadoId,
          'Error: ${respuesta['mensaje']}',
        );
      }
    } catch (e) {
      _logger.e('❌ Error en sync background: $e');
      await _actualizarUltimoIntento(estadoId, 1);
      await _estadoEquipoRepository.marcarComoError(
        estadoId,
        'Excepción: ${e.toString()}',
      );
    } finally {
      _censosEnProceso.remove(estadoId);
    }
  }

  // ==================== SINCRONIZACIÓN PERIÓDICA ====================

  /// Sincronización periódica (procesa múltiples censos)
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
          _logger.i('✅ Censo sincronizado: ${registro.id}');
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
      _logger.i('✅ SINCRONIZACIÓN COMPLETADA');
      _logger.i('   - Exitosos: $censosExitosos');
      _logger.i('   - Fallidos: $totalFallidos');
      _logger.i('═══════════════════════════════════════════════════════');

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': censosExitosos,
      };

    } catch (e) {
      _logger.e('❌ Error en sincronización periódica: $e');
      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': 0,
      };
    }
  }

  /// 🔥 Sincronización individual (usa servicio unificado directamente)
  Future<void> _sincronizarRegistroIndividualUnificado(
      dynamic registro,
      int usuarioId,
      ) async {

    final estadoId = registro.id as String;

    // 1. Verificar límite de intentos
    final intentosPrevios = await _obtenerNumeroIntentos(estadoId);
    final numeroIntento = intentosPrevios + 1;

    if (numeroIntento > maxIntentos) {
      await _estadoEquipoRepository.marcarComoError(
        estadoId,
        'Fallo permanente: máximo de intentos alcanzado',
      );
      return;
    }

    _logger.i('🔄 Sincronizando $estadoId (intento #$numeroIntento/$maxIntentos)');

    // 2. Obtener datos del censo
    final maps = await _estadoEquipoRepository.dbHelper.consultar(
      'censo_activo',
      where: 'id = ?',
      whereArgs: [estadoId],
      limit: 1,
    );

    if (maps.isEmpty) {
      throw Exception('Censo no encontrado: $estadoId');
    }

    final datosLocales = Map<String, dynamic>.from(maps.first);

    // 3. Enriquecer datos del equipo
    final equipoId = datosLocales['equipo_id']?.toString();
    if (equipoId != null) {
      await _enriquecerDatosEquipo(datosLocales, equipoId);
    }

    // 4. Obtener fotos
    final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);

    // 5. Obtener edfVendedorId
    final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
    if (edfVendedorId == null || edfVendedorId.isEmpty) {
      throw Exception('edfVendedorId no encontrado');
    }

    // 6. Determinar flags
    final esNuevoEquipo = datosLocales['es_nuevo_equipo'] == true;
    final clienteId = _convertirAInt(datosLocales['cliente_id']);
    final yaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);
    final crearPendiente = !yaAsignado;

    await _actualizarUltimoIntento(estadoId, numeroIntento);

    // 🔥 LLAMADA DIRECTA AL SERVICIO UNIFICADO
    final respuesta = await CensoActivoPostService.enviarCensoActivo(
      equipoId: equipoId,
      codigoBarras: datosLocales['codigo_barras']?.toString(),
      marcaId: datosLocales['marca_id'] as int?,
      modeloId: datosLocales['modelo_id'] as int?,
      logoId: datosLocales['logo_id'] as int?,
      numeroSerie: datosLocales['numero_serie']?.toString(),
      esNuevoEquipo: esNuevoEquipo,
      clienteId: clienteId,
      edfVendedorId: edfVendedorId,
      crearPendiente: crearPendiente,
      usuarioId: usuarioId,
      latitud: datosLocales['latitud']?.toDouble() ?? 0.0,
      longitud: datosLocales['longitud']?.toDouble() ?? 0.0,
      observaciones: datosLocales['observaciones']?.toString(),
      enLocal: datosLocales['en_local'] == true,
      estadoCenso: yaAsignado ? 'asignado' : 'pendiente',
      fotos: fotos,
      clienteNombre: datosLocales['cliente_nombre']?.toString(),
      marca: datosLocales['marca_nombre']?.toString(),
      modelo: datosLocales['modelo']?.toString(),
      logo: datosLocales['logo']?.toString(),
      timeoutSegundos: 60,
      userId: usuarioId.toString(),
      guardarLog: false,
    );

    // 7. Procesar resultado
    if (respuesta['exito'] == true) {
      await _marcarComoSincronizadoCompleto(
        estadoId: estadoId,
        servidorId: respuesta['servidor_id'],
        equipoId: equipoId,
        clienteId: clienteId,
        esNuevoEquipo: esNuevoEquipo,
        crearPendiente: crearPendiente,
        fotos: fotos,
      );
    } else {
      await _estadoEquipoRepository.marcarComoError(
        estadoId,
        'Error (intento #$numeroIntento): ${respuesta['mensaje']}',
      );
    }
  }

  // ==================== REINTENTO MANUAL ====================

  /// 🔥 Reintento manual (usa servicio unificado directamente - MISMO JSON QUE CONFIRMAR)
  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      _logger.i('🔄 Reintento manual con JSON unificado: $estadoId');

      // 1. Obtener datos del censo
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw Exception('No se encontró el censo: $estadoId');
      }

      final datosLocales = Map<String, dynamic>.from(maps.first);

      // 2. Enriquecer datos del equipo
      final equipoId = datosLocales['equipo_id']?.toString();
      if (equipoId != null) {
        await _enriquecerDatosEquipo(datosLocales, equipoId);
      }

      // 3. Obtener fotos
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);

      // 4. Validar edfVendedorId
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw Exception('edfVendedorId es requerido');
      }

      // 5. Determinar flags
      final esNuevoEquipo = datosLocales['es_nuevo_equipo'] == true;
      final clienteId = _convertirAInt(datosLocales['cliente_id']);
      final yaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);
      final crearPendiente = !yaAsignado;

      _logger.i('📋 Reintento - Nuevo: $esNuevoEquipo, Pendiente: $crearPendiente');

      // 🔥 LLAMADA DIRECTA AL SERVICIO UNIFICADO (MISMO JSON QUE CONFIRMAR CENSO)
      final respuesta = await CensoActivoPostService.enviarCensoActivo(
        equipoId: equipoId,
        codigoBarras: datosLocales['codigo_barras']?.toString(),
        marcaId: datosLocales['marca_id'] as int?,
        modeloId: datosLocales['modelo_id'] as int?,
        logoId: datosLocales['logo_id'] as int?,
        numeroSerie: datosLocales['numero_serie']?.toString(),
        esNuevoEquipo: esNuevoEquipo,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        crearPendiente: crearPendiente,
        usuarioId: usuarioId,
        latitud: datosLocales['latitud']?.toDouble() ?? 0.0,
        longitud: datosLocales['longitud']?.toDouble() ?? 0.0,
        observaciones: datosLocales['observaciones']?.toString(),
        enLocal: datosLocales['en_local'] == true,
        estadoCenso: yaAsignado ? 'asignado' : 'pendiente',
        fotos: fotos,
        clienteNombre: datosLocales['cliente_nombre']?.toString(),
        marca: datosLocales['marca_nombre']?.toString(),
        modelo: datosLocales['modelo']?.toString(),
        logo: datosLocales['logo']?.toString(),
        timeoutSegundos: 45,
        userId: usuarioId.toString(),
        guardarLog: true,
      );

      // 6. Procesar resultado
      if (respuesta['exito'] == true) {
        await _marcarComoSincronizadoCompleto(
          estadoId: estadoId,
          servidorId: respuesta['servidor_id'],
          equipoId: equipoId,
          clienteId: clienteId,
          esNuevoEquipo: esNuevoEquipo,
          crearPendiente: crearPendiente,
          fotos: fotos,
        );

        _logger.i('✅ Reintento exitoso con JSON unificado');
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
          'error': respuesta['mensaje'],
        };
      }
    } catch (e) {
      _logger.e('❌ Error en reintento: $e');
      await _estadoEquipoRepository.marcarComoError(
        estadoId,
        'Excepción en reintento: ${e.toString()}',
      );
      return {
        'success': false,
        'error': 'Error de conexión o datos: ${e.toString()}',
      };
    }
  }

  // ==================== MÉTODOS AUXILIARES PRIVADOS ====================

  /// Enriquece datosLocales con información de la tabla equipos
  Future<void> _enriquecerDatosEquipo(
      Map<String, dynamic> datosLocales,
      String equipoId,
      ) async {
    try {
      final equiposList = await _equipoRepository.dbHelper.consultar(
        'equipos',
        where: 'id = ?',
        whereArgs: [equipoId],
        limit: 1,
      );

      if (equiposList.isNotEmpty) {
        final infoEquipo = equiposList.first;
        datosLocales['marca_id'] ??= infoEquipo['marca_id'];
        datosLocales['modelo_id'] ??= infoEquipo['modelo_id'];
        datosLocales['logo_id'] ??= infoEquipo['logo_id'];
        datosLocales['numero_serie'] ??= infoEquipo['numero_serie'];
        datosLocales['codigo_barras'] ??= infoEquipo['cod_barras'];
        datosLocales['marca_nombre'] ??= infoEquipo['marca_nombre'];
        datosLocales['modelo'] ??= infoEquipo['modelo_nombre'];

        _logger.i('✅ Datos enriquecidos desde equipos');
      }
    } catch (e) {
      _logger.w('⚠️ No se pudo enriquecer datos: $e');
    }
  }

  /// Marca el censo y todas sus dependencias como sincronizadas
  Future<void> _marcarComoSincronizadoCompleto({
    required String estadoId,
    required dynamic servidorId,
    required String? equipoId,
    required int clienteId,
    required bool esNuevoEquipo,
    required bool crearPendiente,
    required List<dynamic> fotos,
  }) async {
    // Marcar censo como sincronizado
    await _estadoEquipoRepository.marcarComoMigrado(
      estadoId,
      servidorId: servidorId,
    );
    await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

    // Marcar equipo como sincronizado (si era nuevo)
    if (equipoId != null && esNuevoEquipo) {
      await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
    }

    // Marcar pendientes como sincronizados (si se crearon)
    if (equipoId != null && crearPendiente) {
      await _equipoPendienteRepository.marcarSincronizadosPorCenso(
        equipoId,
        clienteId,
      );
    }

    // Marcar fotos como sincronizadas
    for (final foto in fotos) {
      if (foto.id != null) {
        await _fotoRepository.marcarComoSincronizada(foto.id!);
      }
    }
  }

  // ==================== MÉTODOS ESTÁTICOS (SINCRONIZACIÓN AUTOMÁTICA) ====================

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('⚠️ Sincronización ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática cada ${intervaloTimer.inMinutes} min');

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
        Logger().i('✅ Auto-sync: ${resultado['censos_exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en auto-sync: $e');
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

  // ==================== MÉTODOS AUXILIARES DE REINTENTOS ====================

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

        if (ahora.isAfter(tiempoProximoIntento)) {
          registrosListos.add(registro);
        }
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
        limit: 1,
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
        limit: 1,
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
          'ultimo_intento': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      _logger.w('⚠️ Error actualizando último intento: $e');
    }
  }

  // ==================== MÉTODOS AUXILIARES DE DATOS ====================

  Future<String?> _obtenerEdfVendedorIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) return null;
      final usuarioEncontrado = await _estadoEquipoRepository.dbHelper.consultar(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );
      return usuarioEncontrado.isNotEmpty
          ? usuarioEncontrado.first['edf_vendedor_id'] as String?
          : null;
    } catch (e) {
      _logger.e('❌ Error resolviendo edfVendedorId: $e');
      return null;
    }
  }

  Future<bool> _verificarEquipoAsignado(String? equipoId, dynamic clienteId) async {
    try {
      if (equipoId == null || clienteId == null) return false;
      return await _equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        _convertirAInt(clienteId),
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
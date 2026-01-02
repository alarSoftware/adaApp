import 'dart:async';
import 'package:ada_app/models/censo_activo.dart';

import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final CensoActivoRepository censoActivoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;
  final EquipoPendienteRepository _equipoPendienteRepository;
  final EquipoRepository _equipoRepository;

  static const String _tableName = 'censo_activo';
  static const int maxIntentos = 10;
  static const Duration intervaloTimer = Duration(minutes: 1);

  // static Timer? _syncTimer;
  // static bool _syncActivo = false;
  // static bool _syncEnProgreso = false;
  // static int? _usuarioActual;
  // static final Set<String> _censosEnProceso = {};

  CensoUploadService({
    CensoActivoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
    EquipoPendienteRepository? equipoPendienteRepository,
    EquipoRepository? equipoRepository,
  }) : censoActivoRepository =
           estadoEquipoRepository ?? CensoActivoRepository(),
       _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
       _logService = logService ?? CensoLogService(),
       _equipoPendienteRepository =
           equipoPendienteRepository ?? EquipoPendienteRepository(),
       _equipoRepository = equipoRepository ?? EquipoRepository();

  //=====METODO UNIFICADO PARA CONSULTAR Y ENVIAR POST CENSO ACTIVO=====
  Future<void> enviarCensoUnificado({
    required String censoActivoId,
    required int usuarioId,
    required String employeeId,
  }) async {
    String? fullUrl;

    try {
      print('Enviando censo unificado: $censoActivoId');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final maps = await censoActivoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [censoActivoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw Exception('Censo no encontrado en BD: $censoActivoId');
      }

      final censoActivoMap = Map<String, dynamic>.from(maps.first);
      var estado = censoActivoMap['estado_censo']?.toString();

      if (estado == 'migrado') {
        print('Censo ya migrado: $censoActivoId');
        return;
      }

      final equipoId = censoActivoMap['equipo_id']?.toString();
      var equipoDataMap;

      if (equipoId != null) {
        await _enriquecerDatosEquipo(censoActivoMap, equipoId);

        var equipoDataMapList = await _equipoRepository.dbHelper.consultar(
          'equipos',
          where: 'id = ?',
          whereArgs: [equipoId],
          limit: 1,
        );

        if (equipoDataMapList.isEmpty) {
          throw Exception('Equipo no encontrado: $equipoId');
        }

        equipoDataMap = equipoDataMapList[0];
      }

      final fotos = await _fotoRepository.obtenerFotosPorCenso(censoActivoId);

      final esNuevoEquipo = censoActivoMap['es_nuevo_equipo'] == true;
      final clienteId = _convertirAInt(censoActivoMap['cliente_id']);
      final yaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);
      final crearPendiente = !yaAsignado;

      print('Flags - Nuevo: $esNuevoEquipo, Crear pendiente: $crearPendiente');

      final pendienteExistente = await _equipoPendienteRepository.dbHelper
          .consultar(
            'equipos_pendientes',
            where: 'equipo_id = ? AND cliente_id = ?',
            whereArgs: [equipoId, clienteId],
            orderBy: 'fecha_creacion DESC',
            limit: 1,
          );

      await CensoActivoPostService.enviarCensoActivo(
        censoId: censoActivoId,
        equipoId: equipoId,
        codigoBarras: censoActivoMap['codigo_barras']?.toString(),
        marcaId: censoActivoMap['marca_id'] as int?,
        modeloId: censoActivoMap['modelo_id'] as int?,
        logoId: censoActivoMap['logo_id'] as int?,
        numeroSerie: censoActivoMap['numero_serie']?.toString(),
        esNuevoEquipo: esNuevoEquipo,
        clienteId: clienteId,
        employeeId: employeeId,
        crearPendiente: crearPendiente,
        pendienteExistente: pendienteExistente,
        usuarioId: usuarioId,
        latitud: censoActivoMap['latitud']?.toDouble() ?? 0.0,
        longitud: censoActivoMap['longitud']?.toDouble() ?? 0.0,
        observaciones: censoActivoMap['observaciones']?.toString(),
        enLocal: censoActivoMap['en_local'] == 1,
        estadoCenso: yaAsignado ? 'asignado' : 'pendiente',
        fotos: fotos,
        clienteNombre: censoActivoMap['cliente_nombre']?.toString(),
        marca: censoActivoMap['marca_nombre']?.toString(),
        modelo: censoActivoMap['modelo']?.toString(),
        logo: censoActivoMap['logo']?.toString(),
        equipoDataMap: equipoDataMap,
      );
    } catch (e) {
      print('Error en enviarCensoUnificado: $e');

      await censoActivoRepository.marcarComoError(
        censoActivoId,
        'Excepción: ${e.toString()}',
      );

      await ErrorLogService.manejarExcepcion(
        e,
        censoActivoId,
        fullUrl,
        usuarioId,
        _tableName,
      );
    }
  }

  Future<Map<String, int>> sincronizarCensosNoMigrados(int usuarioId) async {
    print('=== SINCRONIZACIÓN PERIÓDICA UNIFICADA ===');

    int censosExitosos = 0;
    int totalFallidos = 0;

    try {
      final registrosCreados = await censoActivoRepository.obtenerCreados();
      final registrosError = await censoActivoRepository.obtenerConError();
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(
        registrosError,
        registrosCreados,
      );

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      print('Total censos a procesar: ${todosLosRegistros.length}');

      final censoActivoList = todosLosRegistros.take(20);

      for (final censoActivo in censoActivoList) {
        try {
          await _sincronizarCensoActivoIndividualUnificado(
            censoActivo,
            usuarioId,
          );
          censosExitosos++;
        } catch (e) {
          print('Error en censo ${censoActivo.id}: $e');
          totalFallidos++;
          if (censoActivo.id != null) {
            await censoActivoRepository.marcarComoError(
              censoActivo.id!,
              'Excepción: ${e.toString()}',
            );
            await ErrorLogService.manejarExcepcion(
              e,
              censoActivo.id!,
              null,
              usuarioId,
              _tableName,
            );
          }
        }
        await Future.delayed(Duration(milliseconds: 500));
      }

      print('=== SINCRONIZACIÓN COMPLETADA ===');
      print('   - Exitosos: $censosExitosos');
      print('   - Fallidos: $totalFallidos');

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': censosExitosos,
      };
    } catch (e) {
      print('Error en sincronización periódica: $e');

      await ErrorLogService.manejarExcepcion(
        e,
        null,
        null,
        usuarioId,
        _tableName,
      );

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': 0,
      };
    }
  }

  Future<void> _sincronizarCensoActivoIndividualUnificado(
    dynamic registro,
    int usuarioId,
  ) async {
    try {
      final censoActivoId = registro.id as String;

      final intentosPrevios = await _obtenerNumeroIntentos(censoActivoId);
      final numeroIntento = intentosPrevios + 1;

      if (numeroIntento > maxIntentos) {
        return;
      }

      print(
        'Sincronizando $censoActivoId (intento #$numeroIntento/$maxIntentos)',
      );

      final employeeId = await _obtenerEmployeeIdDesdeUsuarioId(usuarioId);
      if (employeeId == null || employeeId.isEmpty) {
        throw Exception('employeeId no encontrado');
      }

      await _actualizarUltimoIntento(censoActivoId, numeroIntento);

      await enviarCensoUnificado(
        censoActivoId: censoActivoId,
        usuarioId: usuarioId,
        employeeId: employeeId,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> reintentarEnvioCenso(
    String censoActivoId,
    int usuarioId,
    String? employeeId,
  ) async {
    bool success = false;
    String message = '';

    try {
      print('Reintento manual: $censoActivoId');

      if (employeeId == null || employeeId.isEmpty) {
        throw Exception('employeeId es requerido');
      }

      await enviarCensoUnificado(
        censoActivoId: censoActivoId,
        usuarioId: usuarioId,
        employeeId: employeeId,
      );

      final censoActivoMapList = await censoActivoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [censoActivoId],
        limit: 1,
      );

      if (censoActivoMapList.isEmpty) {
        throw Exception('Censo no encontrado después del envío');
      }

      final censoActivoMap = Map<String, dynamic>.from(
        censoActivoMapList.first,
      );
      var estadoCenso = censoActivoMap['estado_censo'];

      if (estadoCenso == 'migrado') {
        success = true;
        message = 'Registro sincronizado correctamente';
      } else {
        success = false;
        message = censoActivoMap['error_mensaje'] ?? 'Error desconocido';
      }
    } catch (e) {
      print('Error en reintentarEnvioCenso: $e');
      success = false;
      message = e.toString();
    }

    return {'success': success, 'message': message};
  }

  Future<void> _enriquecerDatosEquipo(
    Map<String, dynamic> datosLocales,
    String equipoId,
  ) async {
    try {
      final db = await _equipoRepository.dbHelper.database;
      final result = await db.rawQuery(
        '''
      SELECT 
        e.id,
        e.cod_barras,
        e.marca_id,
        e.modelo_id,
        e.logo_id,
        e.numero_serie,
        e.app_insert,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      WHERE e.id = ?
    ''',
        [equipoId],
      );

      if (result.isNotEmpty) {
        final infoEquipo = result.first;

        datosLocales['marca_id'] ??= infoEquipo['marca_id'];
        datosLocales['modelo_id'] ??= infoEquipo['modelo_id'];
        datosLocales['logo_id'] ??= infoEquipo['logo_id'];
        datosLocales['numero_serie'] ??= infoEquipo['numero_serie'];
        datosLocales['codigo_barras'] ??= infoEquipo['cod_barras'];
        datosLocales['marca_nombre'] ??= infoEquipo['marca_nombre'];
        datosLocales['modelo'] ??= infoEquipo['modelo_nombre'];
        datosLocales['logo'] ??= infoEquipo['logo_nombre'];
        datosLocales['es_nuevo_equipo'] ??= (infoEquipo['app_insert'] == 1);

        print('Datos enriquecidos desde equipos');
      }
    } catch (e) {
      print('No se pudo enriquecer datos: $e');
      rethrow;
    }
  }

  Future<void> marcarComoSincronizadoCompleto({
    required String censoId,
    required String? equipoId,
    required int clienteId,
    required bool esNuevoEquipo,
    required bool crearPendiente,
    required List<dynamic> fotos,
  }) async {
    await censoActivoRepository.marcarComoMigrado(censoId);
    await ErrorLogService.marcarErroresComoResueltos(
      registroFailId: censoId,
      tableName: 'censo_activo',
    );

    if (equipoId != null && esNuevoEquipo) {
      await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
    }

    if (equipoId != null && crearPendiente) {
      await _equipoPendienteRepository.marcarSincronizadosPorCenso(
        equipoId,
        clienteId,
      );
    }

    for (final foto in fotos) {
      if (foto.id != null) {
        await _fotoRepository.marcarComoSincronizada(foto.id!);
      }
    }
  }

  //
  //   _syncEnProgreso = true;
  //
  //   try {
  //     final conexion = await BaseSyncService.testConnection();
  //     if (!conexion.exito) {
  //       Logger().w('Sin conexión al servidor: ${conexion.mensaje}');
  //       return;
  //     }
  //
  //     final service = CensoUploadService();
  //     final resultado = await service.sincronizarCensosNoMigrados(
  //       _usuarioActual!,
  //     );
  //
  //     if (resultado['total']! > 0) {
  //       Logger().i(
  //         'Auto-sync: ${resultado['censos_exitosos']}/${resultado['total']}',
  //       );
  //     }
  //   } catch (e, stackTrace) {
  //     Logger().e('Error en auto-sync: $e', stackTrace: stackTrace);
  //
  //     await ErrorLogService.manejarExcepcion(
  //       e,
  //       null,
  //       null,
  //       _usuarioActual,
  //       'censo_activo',
  //     );
  //   } finally {
  //     _syncEnProgreso = false;
  //   }
  // }

  // static bool get esSincronizacionActiva => _syncActivo;
  // static bool get estaEnProgreso => _syncEnProgreso;

  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(
    List<dynamic> registrosError, [
    List<CensoActivo>? registrosCreados,
  ]) async {
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

        final tiempoProximoIntento = ultimoIntento.add(
          Duration(minutes: minutosEspera),
        );

        if (ahora.isAfter(tiempoProximoIntento)) {
          registrosListos.add(registro);
        }
      } catch (e) {
        print('Error verificando ${registro.id}: $e');
        registrosListos.add(registro);
      }
    }
    return registrosListos;
  }

  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;
    switch (numeroIntento) {
      case 1:
        return 1;
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 15;
      case 5:
        return 20;
      case 6:
        return 25;
      default:
        return 30;
    }
  }

  Future<int> _obtenerNumeroIntentos(String estadoId) async {
    try {
      final maps = await censoActivoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );
      return maps.isNotEmpty ? maps.first['intentos_sync'] as int? ?? 0 : 0;
    } catch (e) {
      print('Error obteniendo intentos: $e');
      return 0;
    }
  }

  Future<DateTime?> _obtenerUltimoIntento(String estadoId) async {
    try {
      final maps = await censoActivoRepository.dbHelper.consultar(
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
      print('Error obteniendo último intento: $e');
      return null;
    }
    return null;
  }

  Future<void> _actualizarUltimoIntento(
    String estadoId,
    int numeroIntento,
  ) async {
    try {
      await censoActivoRepository.dbHelper.actualizar(
        'censo_activo',
        {
          'intentos_sync': numeroIntento,
          'ultimo_intento': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      print('Error actualizando último intento: $e');
      rethrow;
    }
  }

  Future<String?> _obtenerEmployeeIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) return null;

      final usuarioEncontrado = await censoActivoRepository.dbHelper.consultar(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );

      return usuarioEncontrado.isNotEmpty
          ? usuarioEncontrado.first['employee_id'] as String?
          : null;
    } catch (e) {
      print('Error resolviendo employeeId: $e');
      rethrow;
    }
  }

  Future<bool> _verificarEquipoAsignado(
    String? equipoId,
    dynamic clienteId,
  ) async {
    try {
      if (equipoId == null || clienteId == null) return false;

      return await _equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        _convertirAInt(clienteId),
      );
    } catch (e) {
      print('Error verificando asignación: $e');
      rethrow;
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

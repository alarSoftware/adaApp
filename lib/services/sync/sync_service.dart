import 'package:ada_app/services/sync/operacion_comercial_sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/producto_sync_service.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/services/sync/censo_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/services/sync/equipos_pendientes_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/services/sync/censo_image_sync_service.dart';
import 'package:ada_app/services/data/database_validation_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database_helper.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/api/auth_service.dart';

class SyncService {
  static final _clienteRepo = ClienteRepository();

  static Future<SyncResultUnificado> sincronizarYLimpiarDatos() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final validationService = DatabaseValidationService(db);

    try {
      final syncResult = await sincronizarTodosLosDatos();

      if (!syncResult.exito) {
        return syncResult;
      }

      final validation = await validationService.canDeleteDatabase();

      if (validation.canDelete) {
        await _limpiarDatosSincronizados(db);
        syncResult.mensaje += '\n\n✅ Base de datos limpiada exitosamente';
      } else {
        syncResult.mensaje += '\n\n⚠️ Advertencia: ${validation.message}';
      }

      return syncResult;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'sync_general',
        operation: 'sincronizar_y_limpiar',
        errorMessage: e.toString(),
        errorType: 'sync_error',
      );

      final errorResult = SyncResultUnificado();
      errorResult.exito = false;
      errorResult.mensaje = 'Error durante sincronización y limpieza: $e';
      return errorResult;
    }
  }

  static Future<Map<String, dynamic>> verificarEstadoSincronizacion() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final validationService = DatabaseValidationService(db);

      return await validationService.getPendingSyncSummary();
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'sync_general',
        operation: 'verificar_estado',
        errorMessage: e.toString(),
      );

      return {
        'can_delete': false,
        'total_pending': -1,
        'pending_by_table': [],
        'message': 'Error verificando estado: $e',
        'error': true,
      };
    }
  }

  static Future<void> _limpiarDatosSincronizados(Database db) async {
    await db.transaction((txn) async {
      await txn.delete(
        'dynamic_form_response',
        where: 'sync_status = ?',
        whereArgs: ['synced'],
      );

      await txn.delete(
        'dynamic_form_response_detail',
        where: 'sync_status = ?',
        whereArgs: ['synced'],
      );

      await txn.delete(
        'dynamic_form_response_image',
        where: 'sync_status = ?',
        whereArgs: ['synced'],
      );

      await txn.delete(
        'equipos_pendientes',
        where: 'sincronizado = ?',
        whereArgs: [1],
      );

      await txn.delete('censo_activo');
      await txn.delete('censo_activo_foto');

      await txn.delete('device_log', where: 'sincronizado = ?', whereArgs: [1]);
    });
  }

  static Future<SyncResultUnificado> sincronizarTodosLosDatos({
    Function(double progress, String message)? onProgress,
  }) async {
    final resultado = SyncResultUnificado();

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        await ErrorLogService.logNetworkError(
          tableName: 'sync_general',
          operation: 'test_connection',
          errorMessage: conexion.mensaje,
          endpoint: await BaseSyncService.getBaseUrl(),
        );

        resultado.exito = false;
        resultado.mensaje = 'Sin conexión al servidor: ${conexion.mensaje}';
        return resultado;
      }

      resultado.conexionOK = true;

      String employeeId;
      try {
        employeeId = await obtenerEmployeeId();
      } catch (e) {
        resultado.exito = false;
        resultado.mensaje =
            'Error: No se pudo obtener información del usuario. $e';
        return resultado;
      }

      // 1. Intentar subir censos pendientes (REINTENTO)
      try {
        final currentUser = await AuthService().getCurrentUser();
        if (currentUser != null && currentUser.id != null) {
          onProgress?.call(0.05, 'Subiendo censos pendientes...');
          final censoUploadService = CensoUploadService();
          await censoUploadService.sincronizarCensosNoMigrados(currentUser.id!);
        }
      } catch (e) {
        // No interrumpimos la sincronización general, pero logueamos
        await ErrorLogService.logError(
          tableName: 'censo_activo',
          operation: 'retry_sync_upload',
          errorMessage: 'Error subiendo pendientes: $e',
          errorType: 'upload_error',
        );
      }

      onProgress?.call(0.1, 'Sincronizando marcas...');
      await EquipmentSyncService.sincronizarMarcas();
      onProgress?.call(0.15, 'Sincronizando modelos...');
      await EquipmentSyncService.sincronizarModelos();
      onProgress?.call(0.2, 'Sincronizando logos...');
      await EquipmentSyncService.sincronizarLogos();

      try {
        onProgress?.call(0.25, 'Sincronizando clientes...');
        final resultadoClientes =
            await ClientSyncService.sincronizarClientesDelUsuario();
        resultado.clientesSincronizados = resultadoClientes.itemsSincronizados;
        resultado.clientesExito = resultadoClientes.exito;

        if (!resultadoClientes.exito) {
          resultado.erroresClientes = resultadoClientes.mensaje;
        }
      } catch (e) {
        resultado.clientesExito = false;
        resultado.erroresClientes = 'Error al sincronizar clientes: $e';
        resultado.clientesSincronizados = 0;
      }

      try {
        onProgress?.call(0.35, 'Sincronizando equipos...');
        final resultadoEquipos =
            await EquipmentSyncService.sincronizarEquipos();
        resultado.equiposSincronizados = resultadoEquipos.itemsSincronizados;
        resultado.equiposExito = resultadoEquipos.exito;

        if (!resultadoEquipos.exito) {
          resultado.erroresEquipos = resultadoEquipos.mensaje;
        }
      } catch (e) {
        resultado.equiposExito = false;
        resultado.erroresEquipos = 'Error al sincronizar equipos: $e';
        resultado.equiposSincronizados = 0;
      }

      try {
        onProgress?.call(0.45, 'Sincronizando productos...');
        final resultadoProductos = await ProductoSyncService.obtenerProductos();
        resultado.productosSincronizados =
            resultadoProductos.itemsSincronizados;
        resultado.productosExito = resultadoProductos.exito;

        if (!resultadoProductos.exito) {
          resultado.erroresProductos = resultadoProductos.mensaje;
        }
      } catch (e) {
        resultado.productosExito = false;
        resultado.erroresProductos = 'Error al sincronizar productos: $e';
        resultado.productosSincronizados = 0;
      }

      try {
        onProgress?.call(0.55, 'Sincronizando censos...');
        final resultadoCensos = await CensusSyncService.obtenerCensosActivos(
          employeeId: employeeId,
        );
        resultado.censosSincronizados = resultadoCensos.itemsSincronizados;
        resultado.censosExito = resultadoCensos.exito;

        if (!resultadoCensos.exito) {
          resultado.erroresCensos = resultadoCensos.mensaje;
        }
      } catch (e) {
        resultado.censosExito = false;
        resultado.erroresCensos = 'Error al sincronizar censos: $e';
        resultado.censosSincronizados = 0;
      }

      if (resultado.censosExito) {
        try {
          onProgress?.call(0.60, 'Descargando imágenes de censos...');
          final resultadoImagenes =
              await CensusImageSyncService.obtenerFotosCensos(
                employeeId: employeeId,
              );
          resultado.imagenesCensosSincronizadas =
              resultadoImagenes.itemsSincronizados;
          resultado.imagenesCensosExito = resultadoImagenes.exito;

          if (!resultadoImagenes.exito) {
            resultado.erroresImagenesCensos = resultadoImagenes.mensaje;
          }
        } catch (e) {
          resultado.imagenesCensosExito = false;
          resultado.erroresImagenesCensos =
              'Error al sincronizar imágenes de censos: $e';
          resultado.imagenesCensosSincronizadas = 0;
        }
      } else {
        resultado.imagenesCensosExito = true;
        resultado.imagenesCensosSincronizadas = 0;
        resultado.erroresImagenesCensos = null;
      }

      try {
        onProgress?.call(0.65, 'Sincronizando equipos pendientes...');
        final resultadoPendientes =
            await EquiposPendientesSyncService.obtenerEquiposPendientes(
              employeeId: employeeId,
            );
        resultado.equiposPendientesSincronizados =
            resultadoPendientes.itemsSincronizados;
        resultado.equiposPendientesExito = resultadoPendientes.exito;

        if (!resultadoPendientes.exito) {
          resultado.erroresEquiposPendientes = resultadoPendientes.mensaje;
        }
      } catch (e) {
        resultado.equiposPendientesExito = false;
        resultado.erroresEquiposPendientes =
            'Error al sincronizar equipos pendientes: $e';
        resultado.equiposPendientesSincronizados = 0;
      }

      try {
        onProgress?.call(0.70, 'Sincronizando formularios...');
        final resultadoFormularios =
            await DynamicFormSyncService.obtenerFormulariosDinamicos();
        resultado.formulariosSincronizados =
            resultadoFormularios.itemsSincronizados;
        resultado.formulariosExito = resultadoFormularios.exito;

        if (!resultadoFormularios.exito) {
          resultado.erroresFormularios = resultadoFormularios.mensaje;
        }
      } catch (e) {
        resultado.formulariosExito = false;
        resultado.erroresFormularios = 'Error al sincronizar formularios: $e';
        resultado.formulariosSincronizados = 0;
      }

      resultado.detallesFormulariosSincronizados = 0;
      resultado.detallesFormulariosExito = true;

      try {
        onProgress?.call(0.75, 'Sincronizando respuestas...');
        final resultadoRespuestas =
            await DynamicFormSyncService.obtenerRespuestasPorVendedor(
              employeeId,
            );
        resultado.respuestasFormulariosSincronizadas =
            resultadoRespuestas.itemsSincronizados;
        resultado.respuestasFormulariosExito = resultadoRespuestas.exito;

        if (!resultadoRespuestas.exito) {
          resultado.erroresRespuestasFormularios = resultadoRespuestas.mensaje;
        }
      } catch (e) {
        resultado.respuestasFormulariosExito = false;
        resultado.erroresRespuestasFormularios =
            'Error al sincronizar respuestas: $e';
        resultado.respuestasFormulariosSincronizadas = 0;
      }

      if (resultado.respuestasFormulariosExito) {
        try {
          onProgress?.call(0.80, 'Descargando imágenes de formularios...');
          final resultadoImagenesFormularios =
              await DynamicFormSyncService.obtenerImagenesFormularios(
                employeeId: employeeId,
              );
          resultado.imagenesFormulariosSincronizadas =
              resultadoImagenesFormularios.itemsSincronizados;
          resultado.imagenesFormulariosExito =
              resultadoImagenesFormularios.exito;

          if (!resultadoImagenesFormularios.exito) {
            resultado.erroresImagenesFormularios =
                resultadoImagenesFormularios.mensaje;
          }
        } catch (e) {
          resultado.imagenesFormulariosExito = false;
          resultado.erroresImagenesFormularios =
              'Error al sincronizar imágenes de formularios: $e';
          resultado.imagenesFormulariosSincronizadas = 0;
        }
      } else {
        resultado.imagenesFormulariosExito = true;
        resultado.imagenesFormulariosSincronizadas = 0;
        resultado.erroresImagenesFormularios = null;
      }

      try {
        onProgress?.call(0.85, 'Sincronizando operaciones comerciales...');
        final resultadoOperaciones =
            await OperacionComercialSyncService.obtenerOperacionesPorVendedor(
              employeeId,
            );
        resultado.operacionesComercialesSincronizadas =
            resultadoOperaciones.itemsSincronizados;
        resultado.operacionesComercialesExito = resultadoOperaciones.exito;

        if (!resultadoOperaciones.exito) {
          resultado.erroresOperacionesComerciales =
              resultadoOperaciones.mensaje;
        }
      } catch (e) {
        resultado.operacionesComercialesExito = false;
        resultado.erroresOperacionesComerciales =
            'Error al sincronizar operaciones comerciales: $e';
        resultado.operacionesComercialesSincronizadas = 0;
      }

      final exitosos = [
        resultado.clientesExito,
        resultado.equiposExito,
        resultado.productosExito,
        resultado.censosExito,
        resultado.imagenesCensosExito,
        resultado.equiposPendientesExito,
        resultado.formulariosExito,
        resultado.detallesFormulariosExito,
        resultado.respuestasFormulariosExito,
        resultado.imagenesFormulariosExito,
        resultado.asignacionesExito,
        resultado.operacionesComercialesExito,
      ];
      final totalExitosos = exitosos.where((e) => e).length;

      if (totalExitosos >= 7) {
        resultado.exito = true;
        resultado.mensaje =
            'Sincronización completa: ${resultado.resumenCompacto}';
      } else if (totalExitosos > 0) {
        resultado.exito = true;
        resultado.mensaje =
            'Sincronización parcial: ${resultado.resumenCompacto}';
      } else {
        resultado.exito = false;
        resultado.mensaje = 'Error: no se pudo sincronizar ningún dato';
      }

      return resultado;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'sync_general',
        operation: 'sincronizar_todos',
        errorMessage: e.toString(),
        errorType: 'sync_general',
        errorCode: 'SYNC_FAILED',
      );

      resultado.exito = false;
      resultado.mensaje = 'Error inesperado: ${e.toString()}';
      return resultado;
    }
  }

  static Future<SyncResult> sincronizarUsuarios() =>
      UserSyncService.sincronizarUsuarios();

  static Future<SyncResult> sincronizarClientes({String? employeeId}) {
    if (employeeId != null) {
      return ClientSyncService.sincronizarClientesPorVendedor(employeeId);
    }
    return ClientSyncService.sincronizarClientesDelUsuario();
  }

  static Future<SyncResult> sincronizarEquipos() =>
      EquipmentSyncService.sincronizarEquipos();

  static Future<SyncResult> sincronizarProductos() =>
      ProductoSyncService.obtenerProductos();

  static Future<SyncResult> sincronizarEquiposPendientes({
    String? employeeId,
  }) => EquiposPendientesSyncService.obtenerEquiposPendientes(
    employeeId: employeeId,
  );

  static Future<SyncResult> sincronizarImagenesCensos({String? employeeId}) =>
      CensusImageSyncService.obtenerFotosCensos(employeeId: employeeId);

  static Future<SyncResult> sincronizarImagenesFormularios({
    String? employeeId,
  }) =>
      DynamicFormSyncService.obtenerImagenesFormularios(employeeId: employeeId);

  static Future<SyncResult> sincronizarFormulariosDinamicos() =>
      DynamicFormSyncService.obtenerFormulariosDinamicos();

  static Future<SyncResult> sincronizarRespuestasFormularios({
    String? employeeId,
  }) => DynamicFormSyncService.obtenerRespuestasFormularios(
    employeeId: employeeId,
  );

  static Future<SyncResult> obtenerCensosActivos({
    int? clienteId,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
    String? estado,
    bool? enLocal,
    int? limit,
    int? offset,
    String? employeeId,
  }) => CensusSyncService.obtenerCensosActivos(
    clienteId: clienteId,
    equipoId: equipoId,
    fechaDesde: fechaDesde,
    fechaHasta: fechaHasta,
    estado: estado,
    enLocal: enLocal,
    limit: limit,
    offset: offset,
    employeeId: employeeId,
  );

  static Future<SyncResult> obtenerCensoPorId(int censoId) =>
      CensusSyncService.obtenerCensoPorId(censoId);

  static Future<SyncResult> buscarCensosPorCodigo(String codigoBarras) =>
      CensusSyncService.buscarPorCodigoBarras(codigoBarras);

  static Future<SyncResult> obtenerCensosDeCliente(int clienteId) =>
      CensusSyncService.obtenerCensosDeCliente(clienteId);

  static Future<SyncResult> obtenerHistoricoEquipo(int equipoId) =>
      CensusSyncService.obtenerHistoricoEquipo(equipoId);

  static Future<SyncResult> obtenerCensosPendientes() =>
      CensusSyncService.obtenerCensosPendientes();

  static Future<ApiResponse> probarConexion() =>
      BaseSyncService.testConnection();

  static Future<String> obtenerEmployeeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsername = prefs.getString('current_user');

      if (currentUsername == null || currentUsername.isEmpty) {
        await ErrorLogService.logValidationError(
          tableName: 'Users',
          operation: 'obtener_employee_id',
          errorMessage: 'No hay usuario logueado en el sistema',
        );
        throw 'No hay usuario logueado en el sistema';
      }

      final dbHelper = DatabaseHelper();
      final resultado = await dbHelper.consultarPersonalizada(
        'SELECT employee_id FROM Users WHERE username = ? LIMIT 1',
        [currentUsername],
      );

      if (resultado.isEmpty) {
        await ErrorLogService.logDatabaseError(
          tableName: 'Users',
          operation: 'obtener_employee_id',
          errorMessage:
              'Usuario $currentUsername no encontrado en la base de datos',
        );
        throw 'Usuario $currentUsername no encontrado en la base de datos';
      }

      final employeeId = resultado.first['employee_id']?.toString();

      if (employeeId == null || employeeId.isEmpty) {
        throw 'Usuario $currentUsername no tiene employee_id configurado';
      }

      return employeeId;
    } catch (e) {
      if (!e.toString().contains('no tiene employee_id') &&
          !e.toString().contains('no encontrado') &&
          !e.toString().contains('No hay usuario')) {
        await ErrorLogService.logError(
          tableName: 'Users',
          operation: 'obtener_employee_id',
          errorMessage: e.toString(),
          errorType: 'unknown',
        );
      }

      rethrow;
    }
  }

  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final estadisticasDB = await _clienteRepo.obtenerEstadisticas();
      final conexion = await BaseSyncService.testConnection();
      final baseUrl = await BaseSyncService.getBaseUrl();

      return {
        ...estadisticasDB,
        'conexionServidor': conexion.exito,
        'mensajeConexion': conexion.mensaje,
        'ultimaVerificacion': DateTime.now().toIso8601String(),
        'servidorURL': baseUrl,
      };
    } catch (e) {
      final baseUrl = await BaseSyncService.getBaseUrl();

      await ErrorLogService.logError(
        tableName: 'sync_general',
        operation: 'obtener_estadisticas',
        errorMessage: e.toString(),
        errorType: 'statistics',
      );

      return {
        'error': e.toString(),
        'conexionServidor': false,
        'servidorURL': baseUrl,
      };
    }
  }
}

/// Clase helper para representar un paso de sincronización
class SyncStep {
  final String summary;
  final String description;

  SyncStep(this.summary, this.description);
}

class SyncResultUnificado {
  bool exito = false;
  String mensaje = '';
  String estadoActual = '';

  bool conexionOK = false;

  bool clientesExito = false;
  int clientesSincronizados = 0;
  String? erroresClientes;

  bool equiposExito = false;
  int equiposSincronizados = 0;
  String? erroresEquipos;

  bool productosExito = false;
  int productosSincronizados = 0;
  String? erroresProductos;

  bool censosExito = false;
  int censosSincronizados = 0;
  String? erroresCensos;

  bool imagenesCensosExito = false;
  int imagenesCensosSincronizadas = 0;
  String? erroresImagenesCensos;

  bool equiposPendientesExito = false;
  int equiposPendientesSincronizados = 0;
  String? erroresEquiposPendientes;

  bool formulariosExito = false;
  int formulariosSincronizados = 0;
  String? erroresFormularios;

  bool detallesFormulariosExito = false;
  int detallesFormulariosSincronizados = 0;
  String? erroresDetallesFormularios;

  bool respuestasFormulariosExito = false;
  int respuestasFormulariosSincronizadas = 0;
  String? erroresRespuestasFormularios;

  bool imagenesFormulariosExito = false;
  int imagenesFormulariosSincronizadas = 0;
  String? erroresImagenesFormularios;

  bool asignacionesExito = false;
  int asignacionesSincronizadas = 0;
  String? erroresAsignaciones;

  bool operacionesComercialesExito = false;
  int operacionesComercialesSincronizadas = 0;
  String? erroresOperacionesComerciales;

  int get totalItemsSincronizados {
    return clientesSincronizados +
        equiposSincronizados +
        productosSincronizados +
        censosSincronizados +
        imagenesCensosSincronizadas +
        equiposPendientesSincronizados +
        formulariosSincronizados +
        detallesFormulariosSincronizados +
        respuestasFormulariosSincronizadas +
        imagenesFormulariosSincronizadas +
        asignacionesSincronizadas +
        operacionesComercialesSincronizadas;
  }

  List<SyncStep> get syncSteps {
    return [
      if (clientesSincronizados > 0)
        SyncStep('$clientesSincronizados clientes', 'Clientes descargados'),
      if (equiposSincronizados > 0)
        SyncStep('$equiposSincronizados equipos', 'Equipos descargados'),
      if (productosSincronizados > 0)
        SyncStep('$productosSincronizados productos', 'Productos descargados'),
      if (censosSincronizados > 0)
        SyncStep('$censosSincronizados censos', 'Censos descargados'),
      if (imagenesCensosSincronizadas > 0)
        SyncStep(
          '$imagenesCensosSincronizadas imágenes de censos',
          'Imágenes de censos descargadas',
        ),
      if (equiposPendientesSincronizados > 0)
        SyncStep(
          '$equiposPendientesSincronizados equipos pendientes',
          'Equipos pendientes descargados',
        ),
      if (formulariosSincronizados > 0)
        SyncStep(
          '$formulariosSincronizados formularios',
          'Formularios descargados',
        ),
      if (detallesFormulariosSincronizados > 0)
        SyncStep(
          '$detallesFormulariosSincronizados detalles',
          'Detalles descargados',
        ),
      if (respuestasFormulariosSincronizadas > 0)
        SyncStep(
          '$respuestasFormulariosSincronizadas respuestas',
          'Respuestas descargadas',
        ),
      if (imagenesFormulariosSincronizadas > 0)
        SyncStep(
          '$imagenesFormulariosSincronizadas imágenes de formularios',
          'Imágenes de formularios descargadas',
        ),
      SyncStep(
        '$asignacionesSincronizadas asignaciones',
        'Asignaciones descargadas',
      ),
      if (operacionesComercialesSincronizadas > 0)
        SyncStep(
          '$operacionesComercialesSincronizadas operaciones comerciales',
          'Operaciones comerciales descargadas',
        ),
    ];
  }

  /// Resumen compacto para mensajes
  String get resumenCompacto {
    final partes = <String>[];
    if (clientesSincronizados > 0) {
      partes.add('$clientesSincronizados clientes');
    }
    if (equiposSincronizados > 0) {
      partes.add('$equiposSincronizados equipos');
    }
    if (productosSincronizados > 0) {
      partes.add('$productosSincronizados productos');
    }
    if (censosSincronizados > 0) {
      partes.add('$censosSincronizados censos');
    }
    if (imagenesCensosSincronizadas > 0) {
      partes.add('$imagenesCensosSincronizadas imágenes de censos');
    }
    if (equiposPendientesSincronizados > 0) {
      partes.add('$equiposPendientesSincronizados equipos pendientes');
    }
    if (formulariosSincronizados > 0) {
      partes.add('$formulariosSincronizados formularios');
    }
    if (detallesFormulariosSincronizados > 0) {
      partes.add('$detallesFormulariosSincronizados detalles');
    }
    if (respuestasFormulariosSincronizadas > 0) {
      partes.add('$respuestasFormulariosSincronizadas respuestas');
    }
    if (imagenesFormulariosSincronizadas > 0) {
      partes.add('$imagenesFormulariosSincronizadas imágenes de formularios');
    }
    if (asignacionesSincronizadas > 0) {
      partes.add('$asignacionesSincronizadas asignaciones');
    }
    if (operacionesComercialesSincronizadas > 0) {
      partes.add(
        '$operacionesComercialesSincronizadas operaciones comerciales',
      );
    }
    return partes.join(', ');
  }

  @override
  String toString() {
    return 'SyncResultUnificado(exito: $exito, total: $totalItemsSincronizados, mensaje: $mensaje)';
  }
}

import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/services/sync/censo_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/services/sync/equipos_pendientes_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/services/sync/censo_image_sync_service.dart';
import 'package:ada_app/services/database_validation_service.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class SyncService {
  static final _clienteRepo = ClienteRepository();

  // Método para sincronizar y limpiar datos de forma segura
  static Future<SyncResultUnificado> sincronizarYLimpiarDatos() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final validationService = DatabaseValidationService(db);

    try {
      // 1. Primero hacer la sincronización normal
      BaseSyncService.logger.i('🔄 Iniciando sincronización antes de limpiar...');
      final syncResult = await sincronizarTodosLosDatos();

      if (!syncResult.exito) {
        BaseSyncService.logger.w('⚠️ Sincronización falló, no se limpiará la base de datos');
        return syncResult;
      }

      // 2. Verificar qué datos están pendientes después de la sincronización
      BaseSyncService.logger.i('🔍 Verificando datos pendientes de sincronización...');
      final validation = await validationService.canDeleteDatabase();

      if (validation.canDelete) {
        BaseSyncService.logger.i('✅ Todos los datos están sincronizados, procediendo a limpiar...');
        await _limpiarDatosSincronizados(db);
        syncResult.mensaje += '\n\n✅ Base de datos limpiada exitosamente';
      } else {
        BaseSyncService.logger.w('⚠️ Aún hay datos pendientes, no se limpiará la base de datos');
        syncResult.mensaje += '\n\n⚠️ Advertencia: ${validation.message}';

        // Opcional: mostrar detalles de qué quedó pendiente
        for (final item in validation.pendingItems) {
          BaseSyncService.logger.w('  - ${item.displayName}: ${item.count} registros pendientes');
        }
      }

      return syncResult;

    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronización y limpieza: $e');
      final errorResult = SyncResultUnificado();
      errorResult.exito = false;
      errorResult.mensaje = 'Error durante sincronización y limpieza: $e';
      return errorResult;
    }
  }

  // Método para verificar estado de sincronización sin hacer sync
  static Future<Map<String, dynamic>> verificarEstadoSincronizacion() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final validationService = DatabaseValidationService(db);

      return await validationService.getPendingSyncSummary();
    } catch (e) {
      BaseSyncService.logger.e('❌ Error verificando estado: $e');
      return {
        'can_delete': false,
        'total_pending': -1,
        'pending_by_table': [],
        'message': 'Error verificando estado: $e',
        'error': true,
      };
    }
  }

  // Método privado para limpiar datos ya sincronizados
  static Future<void> _limpiarDatosSincronizados(Database db) async {
    await db.transaction((txn) async {
      BaseSyncService.logger.i('🧹 Limpiando tablas con sync_status = "synced"...');

      // Limpiar formularios dinámicos con sync_status = 'synced'
      final deletedResponses = await txn.delete(
          'dynamic_form_response',
          where: 'sync_status = ?',
          whereArgs: ['synced']
      );

      final deletedDetails = await txn.delete(
          'dynamic_form_response_detail',
          where: 'sync_status = ?',
          whereArgs: ['synced']
      );

      final deletedImages = await txn.delete(
          'dynamic_form_response_image',
          where: 'sync_status = ?',
          whereArgs: ['synced']
      );

      BaseSyncService.logger.i('🧹 Limpiando tablas con sincronizado = 1...');

      // Limpiar equipos pendientes sincronizados
      final deletedEquiposPendientes = await txn.delete(
          'equipos_pendientes',
          where: 'sincronizado = ?',
          whereArgs: [1]
      );

      // Limpiar censos sincronizados y con estado correcto
      final deletedCensos = await txn.delete(
          'censo_activo',
          where: 'sincronizado = ? AND estado_censo IN (?, ?)',
          whereArgs: [1, 'migrado', 'completado']
      );

      // Limpiar fotos de censos sincronizadas
      final deletedFotos = await txn.delete(
          'censo_activo_foto',
          where: 'sincronizado = ?',
          whereArgs: [1]
      );

      // Limpiar device logs sincronizados
      final deletedLogs = await txn.delete(
          'device_log',
          where: 'sincronizado = ?',
          whereArgs: [1]
      );

      BaseSyncService.logger.i(
          '✅ Limpieza completada: '
              'Respuestas: $deletedResponses, '
              'Detalles: $deletedDetails, '
              'Imágenes: $deletedImages, '
              'Eq. Pendientes: $deletedEquiposPendientes, '
              'Censos: $deletedCensos, '
              'Fotos: $deletedFotos, '
              'Logs: $deletedLogs'
      );
    });
  }

  static Future<SyncResultUnificado> sincronizarTodosLosDatos() async {
    final resultado = SyncResultUnificado();

    try {
      // Probar conexión
      BaseSyncService.logger.i('🔄 INICIANDO SINCRONIZACIÓN COMPLETA');
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        resultado.exito = false;
        resultado.mensaje = 'Sin conexión al servidor: ${conexion.mensaje}';
        return resultado;
      }

      resultado.conexionOK = true;
      BaseSyncService.logger.i('✅ Conexión establecida con el servidor');

      // Obtener edf_vendedor_id del usuario actual
      String edfVendedorId;
      try {
        edfVendedorId = await obtenerEdfVendedorId();
        BaseSyncService.logger.i('✅ edf_vendedor_id obtenido: $edfVendedorId');
      } catch (e) {
        BaseSyncService.logger.e('❌ No se pudo obtener edf_vendedor_id: $e');
        resultado.exito = false;
        resultado.mensaje = 'Error: No se pudo obtener información del usuario. $e';
        return resultado;
      }

      // Sincronizar datos base (marcas, modelos, logos, usuarios)
      BaseSyncService.logger.i('📦 Sincronizando marcas...');
      await EquipmentSyncService.sincronizarMarcas();

      BaseSyncService.logger.i('📦 Sincronizando modelos...');
      await EquipmentSyncService.sincronizarModelos();

      BaseSyncService.logger.i('📦 Sincronizando logos...');
      await EquipmentSyncService.sincronizarLogos();

      // Sincronizar clientes
      BaseSyncService.logger.i('🏢 Sincronizando clientes...');
      final resultadoClientes = await ClientSyncService.sincronizarClientesDelUsuario();
      resultado.clientesSincronizados = resultadoClientes.itemsSincronizados;
      resultado.clientesExito = resultadoClientes.exito;
      if (!resultadoClientes.exito) resultado.erroresClientes = resultadoClientes.mensaje;
      BaseSyncService.logger.i('✅ Clientes sincronizados: ${resultadoClientes.itemsSincronizados} (Éxito: ${resultadoClientes.exito})');

      // Sincronizar equipos
      BaseSyncService.logger.i('⚙️ Sincronizando equipos...');
      final resultadoEquipos = await EquipmentSyncService.sincronizarEquipos();
      resultado.equiposSincronizados = resultadoEquipos.itemsSincronizados;
      resultado.equiposExito = resultadoEquipos.exito;
      if (!resultadoEquipos.exito) resultado.erroresEquipos = resultadoEquipos.mensaje;
      BaseSyncService.logger.i('✅ Equipos sincronizados: ${resultadoEquipos.itemsSincronizados} (Éxito: ${resultadoEquipos.exito})');

      // Sincronizar censos
      BaseSyncService.logger.i('📊 Iniciando sincronización de censos...');
      try {
        final resultadoCensos = await CensusSyncService.obtenerCensosActivos(
          edfVendedorId: edfVendedorId,
        );
        resultado.censosSincronizados = resultadoCensos.itemsSincronizados;
        resultado.censosExito = resultadoCensos.exito;
        if (!resultadoCensos.exito) resultado.erroresCensos = resultadoCensos.mensaje;
        BaseSyncService.logger.i('✅ Censos sincronizados: ${resultadoCensos.itemsSincronizados} (Éxito: ${resultadoCensos.exito})');
      } catch (e) {
        BaseSyncService.logger.e('❌ ERROR ESPECÍFICO EN CENSOS: $e');
        resultado.censosExito = false;
        resultado.erroresCensos = 'Error al sincronizar censos: $e';
        resultado.censosSincronizados = 0;
      }

      // Sincronizar imágenes de censos (solo si hay censos exitosos)
      if (resultado.censosExito && resultado.censosSincronizados > 0) {
        BaseSyncService.logger.i('🖼️ Iniciando sincronización de imágenes de censos...');
        try {
          final resultadoImagenes = await CensusImageSyncService.obtenerFotosCensos(
            edfVendedorId: edfVendedorId,
          );
          resultado.imagenesCensosSincronizadas = resultadoImagenes.itemsSincronizados;
          resultado.imagenesCensosExito = resultadoImagenes.exito;
          if (!resultadoImagenes.exito) resultado.erroresImagenesCensos = resultadoImagenes.mensaje;
          BaseSyncService.logger.i('✅ Imágenes de censos sincronizadas: ${resultadoImagenes.itemsSincronizados} (Éxito: ${resultadoImagenes.exito})');
        } catch (e) {
          BaseSyncService.logger.e('❌ ERROR EN IMÁGENES DE CENSOS: $e');
          resultado.imagenesCensosExito = false;
          resultado.erroresImagenesCensos = 'Error al sincronizar imágenes de censos: $e';
          resultado.imagenesCensosSincronizadas = 0;
        }
      } else {
        BaseSyncService.logger.w('⚠️ No se sincronizarán imágenes porque no hay censos exitosos');
        resultado.imagenesCensosExito = true;
        resultado.imagenesCensosSincronizadas = 0;
        resultado.erroresImagenesCensos = null;
      }

      // Sincronizar equipos pendientes
      BaseSyncService.logger.i('📋 Iniciando sincronización de equipos pendientes...');
      BaseSyncService.logger.i('🔍 edfVendedorId que se pasará: "$edfVendedorId"');
      try {
        final resultadoPendientes = await EquiposPendientesSyncService.obtenerEquiposPendientes(
          edfVendedorId: edfVendedorId,
        );
        resultado.equiposPendientesSincronizados = resultadoPendientes.itemsSincronizados;
        resultado.equiposPendientesExito = resultadoPendientes.exito;
        if (!resultadoPendientes.exito) resultado.erroresEquiposPendientes = resultadoPendientes.mensaje;
        BaseSyncService.logger.i('✅ Equipos pendientes sincronizados: ${resultadoPendientes.itemsSincronizados} (Éxito: ${resultadoPendientes.exito})');
      } catch (e) {
        BaseSyncService.logger.e('❌ ERROR EN EQUIPOS PENDIENTES: $e');
        resultado.equiposPendientesExito = false;
        resultado.erroresEquiposPendientes = 'Error al sincronizar equipos pendientes: $e';
        resultado.equiposPendientesSincronizados = 0;
      }

      // Sincronizar formularios dinámicos
      BaseSyncService.logger.i('📋 Sincronizando formularios dinámicos...');
      try {
        final resultadoFormularios = await DynamicFormSyncService.obtenerFormulariosDinamicos();
        resultado.formulariosSincronizados = resultadoFormularios.itemsSincronizados;
        resultado.formulariosExito = resultadoFormularios.exito;
        if (!resultadoFormularios.exito) resultado.erroresFormularios = resultadoFormularios.mensaje;
        BaseSyncService.logger.i('✅ Formularios sincronizados: ${resultadoFormularios.itemsSincronizados} (Éxito: ${resultadoFormularios.exito})');
      } catch (e) {
        BaseSyncService.logger.e('❌ ERROR EN FORMULARIOS: $e');
        resultado.formulariosExito = false;
        resultado.erroresFormularios = 'Error al sincronizar formularios: $e';
        resultado.formulariosSincronizados = 0;
      }

      // Los detalles de formularios ya se sincronizaron automáticamente
      resultado.detallesFormulariosSincronizados = 0;
      resultado.detallesFormulariosExito = true;

      // Sincronizar respuestas de formularios
      BaseSyncService.logger.i('📝 Sincronizando respuestas de formularios...');
      try {
        final resultadoRespuestas = await DynamicFormSyncService.obtenerRespuestasPorVendedor(edfVendedorId);
        resultado.respuestasFormulariosSincronizadas = resultadoRespuestas.itemsSincronizados;
        resultado.respuestasFormulariosExito = resultadoRespuestas.exito;
        if (!resultadoRespuestas.exito) resultado.erroresRespuestasFormularios = resultadoRespuestas.mensaje;
        BaseSyncService.logger.i('✅ Respuestas sincronizadas: ${resultadoRespuestas.itemsSincronizados} (Éxito: ${resultadoRespuestas.exito})');
      } catch (e) {
        BaseSyncService.logger.e('❌ ERROR EN RESPUESTAS DE FORMULARIOS: $e');
        resultado.respuestasFormulariosExito = false;
        resultado.erroresRespuestasFormularios = 'Error al sincronizar respuestas: $e';
        resultado.respuestasFormulariosSincronizadas = 0;
      }

      // Sincronizar imágenes de formularios dinámicos (solo si hay respuestas exitosas)
      if (resultado.respuestasFormulariosExito && resultado.respuestasFormulariosSincronizadas > 0) {
        BaseSyncService.logger.i('🖼️ Iniciando sincronización de imágenes de formularios...');
        try {
          final resultadoImagenesFormularios = await DynamicFormSyncService.obtenerImagenesFormularios(
            edfVendedorId: edfVendedorId,
          );
          resultado.imagenesFormulariosSincronizadas = resultadoImagenesFormularios.itemsSincronizados;
          resultado.imagenesFormulariosExito = resultadoImagenesFormularios.exito;
          if (!resultadoImagenesFormularios.exito) resultado.erroresImagenesFormularios = resultadoImagenesFormularios.mensaje;
          BaseSyncService.logger.i('✅ Imágenes de formularios sincronizadas: ${resultadoImagenesFormularios.itemsSincronizados} (Éxito: ${resultadoImagenesFormularios.exito})');
        } catch (e) {
          BaseSyncService.logger.e('❌ ERROR EN IMÁGENES DE FORMULARIOS: $e');
          resultado.imagenesFormulariosExito = false;
          resultado.erroresImagenesFormularios = 'Error al sincronizar imágenes de formularios: $e';
          resultado.imagenesFormulariosSincronizadas = 0;
        }
      } else {
        BaseSyncService.logger.w('⚠️ No se sincronizarán imágenes de formularios porque no hay respuestas exitosas');
        resultado.imagenesFormulariosExito = true;
        resultado.imagenesFormulariosSincronizadas = 0;
        resultado.erroresImagenesFormularios = null;
      }

      // Evaluar resultado general
      final exitosos = [
        resultado.clientesExito,
        resultado.equiposExito,
        resultado.censosExito,
        resultado.imagenesCensosExito,
        resultado.equiposPendientesExito,
        resultado.formulariosExito,
        resultado.detallesFormulariosExito,
        resultado.respuestasFormulariosExito,
        resultado.imagenesFormulariosExito,
        resultado.asignacionesExito
      ];
      final totalExitosos = exitosos.where((e) => e).length;

      if (totalExitosos >= 7) {
        resultado.exito = true;
        resultado.mensaje = 'Sincronización completa: ${resultado.clientesSincronizados} clientes, ${resultado.equiposSincronizados} equipos, ${resultado.censosSincronizados} censos, ${resultado.imagenesCensosSincronizadas} imágenes de censos, ${resultado.equiposPendientesSincronizados} equipos pendientes, ${resultado.formulariosSincronizados} formularios, ${resultado.detallesFormulariosSincronizados} detalles, ${resultado.respuestasFormulariosSincronizadas} respuestas, ${resultado.imagenesFormulariosSincronizadas} imágenes de formularios y ${resultado.asignacionesSincronizadas} asignaciones';
      } else if (totalExitosos > 0) {
        resultado.exito = true;
        final partes = <String>[];
        if (resultado.clientesExito) partes.add('${resultado.clientesSincronizados} clientes');
        if (resultado.equiposExito) partes.add('${resultado.equiposSincronizados} equipos');
        if (resultado.censosExito) partes.add('${resultado.censosSincronizados} censos');
        if (resultado.imagenesCensosExito && resultado.imagenesCensosSincronizadas > 0) partes.add('${resultado.imagenesCensosSincronizadas} imágenes de censos');
        if (resultado.equiposPendientesExito) partes.add('${resultado.equiposPendientesSincronizados} equipos pendientes');
        if (resultado.formulariosExito) partes.add('${resultado.formulariosSincronizados} formularios');
        if (resultado.detallesFormulariosExito) partes.add('${resultado.detallesFormulariosSincronizados} detalles');
        if (resultado.respuestasFormulariosExito) partes.add('${resultado.respuestasFormulariosSincronizadas} respuestas');
        if (resultado.imagenesFormulariosExito && resultado.imagenesFormulariosSincronizadas > 0) partes.add('${resultado.imagenesFormulariosSincronizadas} imágenes de formularios');
        if (resultado.asignacionesExito) partes.add('${resultado.asignacionesSincronizadas} asignaciones');
        resultado.mensaje = 'Sincronización parcial: ${partes.join(', ')}';
      } else {
        resultado.exito = false;
        resultado.mensaje = 'Error: no se pudo sincronizar ningún dato';
      }

      BaseSyncService.logger.i('🎉 SINCRONIZACIÓN COMPLETADA: ${resultado.mensaje}');
      return resultado;

    } catch (e) {
      BaseSyncService.logger.e('💥 ERROR GENERAL EN SINCRONIZACIÓN: $e');
      resultado.exito = false;
      resultado.mensaje = 'Error inesperado: ${e.toString()}';
      return resultado;
    }
  }

  // Métodos de acceso directo esenciales (solo los que realmente se usan)
  static Future<SyncResult> sincronizarUsuarios() => UserSyncService.sincronizarUsuarios();

  static Future<SyncResult> sincronizarClientes({String? edfVendedorId}) {
    if (edfVendedorId != null) {
      return ClientSyncService.sincronizarClientesPorVendedor(edfVendedorId);
    }
    return ClientSyncService.sincronizarClientesDelUsuario();
  }

  static Future<SyncResult> sincronizarEquipos() => EquipmentSyncService.sincronizarEquipos();

  static Future<SyncResult> sincronizarEquiposPendientes({String? edfVendedorId}) =>
      EquiposPendientesSyncService.obtenerEquiposPendientes(edfVendedorId: edfVendedorId);

  // Método simplificado para imágenes de censos
  static Future<SyncResult> sincronizarImagenesCensos({String? edfVendedorId}) =>
      CensusImageSyncService.obtenerFotosCensos(edfVendedorId: edfVendedorId);

  // Método simplificado para imágenes de formularios dinámicos
  static Future<SyncResult> sincronizarImagenesFormularios({String? edfVendedorId}) =>
      DynamicFormSyncService.obtenerImagenesFormularios(edfVendedorId: edfVendedorId);

  // Métodos de formularios dinámicos
  static Future<SyncResult> sincronizarFormulariosDinamicos() =>
      DynamicFormSyncService.obtenerFormulariosDinamicos();

  static Future<SyncResult> sincronizarRespuestasFormularios({String? edfVendedorId}) =>
      DynamicFormSyncService.obtenerRespuestasFormularios(edfvendedorId: edfVendedorId);

  // Métodos de envío
  static Future<SyncResult> enviarClientesPendientes() => ClientSyncService.enviarClientesPendientes();
  static Future<int> subirRegistrosEquipos() => EquipmentSyncService.subirRegistrosEquipos();

  static Future<int> crearRegistroEquipo({
    required int clienteId,
    String? clienteNombre,
    String? clienteDireccion,
    String? clienteTelefono,
    int? equipoId,
    String? codigoBarras,
    String? modelo,
    int? marcaId,
    String? numeroSerie,
    int? logoId,
    String? observaciones,
    double? latitud,
    double? longitud,
    bool funcionando = true,
    String? estadoGeneral,
    double? temperaturaActual,
    double? temperaturaFreezer,
    String? versionApp,
    String? dispositivo,
  }) => EquipmentSyncService.crearRegistroEquipo(
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    clienteDireccion: clienteDireccion,
    clienteTelefono: clienteTelefono,
    equipoId: equipoId,
    codigoBarras: codigoBarras,
    modelo: modelo,
    marcaId: marcaId,
    numeroSerie: numeroSerie,
    logoId: logoId,
    observaciones: observaciones,
    latitud: latitud,
    longitud: longitud,
    funcionando: funcionando,
    estadoGeneral: estadoGeneral,
    temperaturaActual: temperaturaActual,
    temperaturaFreezer: temperaturaFreezer,
    versionApp: versionApp,
    dispositivo: dispositivo,
  );

  // Métodos de censo esenciales
  static Future<SyncResult> obtenerCensosActivos({
    int? clienteId,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
    String? estado,
    bool? enLocal,
    int? limit,
    int? offset,
  }) => CensusSyncService.obtenerCensosActivos(
    clienteId: clienteId,
    equipoId: equipoId,
    fechaDesde: fechaDesde,
    fechaHasta: fechaHasta,
    estado: estado,
    enLocal: enLocal,
    limit: limit,
    offset: offset,
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

  // Métodos de utilidad
  static Future<ApiResponse> probarConexion() => BaseSyncService.testConnection();

  static Future<String> obtenerEdfVendedorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsername = prefs.getString('current_user');

      if (currentUsername == null || currentUsername.isEmpty) {
        throw 'No hay usuario logueado en el sistema';
      }

      final dbHelper = DatabaseHelper();
      final resultado = await dbHelper.consultarPersonalizada(
          'SELECT edf_vendedor_id FROM Users WHERE username = ? LIMIT 1',
          [currentUsername]
      );

      if (resultado.isEmpty) {
        throw 'Usuario $currentUsername no encontrado en la base de datos';
      }

      final edfVendedorId = resultado.first['edf_vendedor_id']?.toString();

      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw 'Usuario $currentUsername no tiene edf_vendedor_id configurado';
      }

      logger.i('✅ edf_vendedor_id obtenido: $edfVendedorId');
      return edfVendedorId;

    } catch (e) {
      logger.e('❌ Error obteniendo edf_vendedor_id: $e');
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
      return {
        'error': e.toString(),
        'conexionServidor': false,
        'servidorURL': baseUrl,
      };
    }
  }
}

// Clase de resultado unificado (sin cambios)
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

  @override
  String toString() {
    return 'SyncResultUnificado(exito: $exito, clientes: $clientesSincronizados, equipos: $equiposSincronizados, censos: $censosSincronizados, imagenes: $imagenesCensosSincronizadas, equiposPendientes: $equiposPendientesSincronizados, formularios: $formulariosSincronizados, detalles: $detallesFormulariosSincronizados, respuestas: $respuestasFormulariosSincronizadas, imagenesFormularios: $imagenesFormulariosSincronizadas, asignaciones: $asignacionesSincronizadas, mensaje: $mensaje)';
  }
}
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/services/sync/census_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/services/sync/equipos_pendientes_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import '../database_helper.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class SyncService {
  static final _clienteRepo = ClienteRepository();

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

      // Sincronizar clientes (solo si el usuario tiene edf_vendedor_id)
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

      // CHECKPOINT: Verificar que llegamos hasta aquí
      BaseSyncService.logger.i('🎯 CHECKPOINT: A punto de sincronizar censos...');

      // Sincronizar censos activos con edf_vendedor_id
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

      BaseSyncService.logger.i('📋 Iniciando sincronización de equipos pendientes...');

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

      // Sincronizar detalles de formularios
      BaseSyncService.logger.i('📋 Sincronizando detalles de formularios...');

      try {
        final resultadoDetalles = await DynamicFormSyncService.sincronizarTodosLosDetalles();
        resultado.detallesFormulariosSincronizados = resultadoDetalles.itemsSincronizados;
        resultado.detallesFormulariosExito = resultadoDetalles.exito;
        if (!resultadoDetalles.exito) resultado.erroresDetallesFormularios = resultadoDetalles.mensaje;
        BaseSyncService.logger.i('✅ Detalles sincronizados: ${resultadoDetalles.itemsSincronizados} (Éxito: ${resultadoDetalles.exito})');
      } catch (e) {
        BaseSyncService.logger.e('❌ ERROR EN DETALLES DE FORMULARIOS: $e');
        resultado.detallesFormulariosExito = false;
        resultado.erroresDetallesFormularios = 'Error al sincronizar detalles: $e';
        resultado.detallesFormulariosSincronizados = 0;
      }

      BaseSyncService.logger.i('🏁 EVALUANDO RESULTADO GENERAL...');

      // Evaluar resultado general
      final exitosos = [
        resultado.clientesExito,
        resultado.equiposExito,
        resultado.censosExito,
        resultado.equiposPendientesExito,
        resultado.formulariosExito,
        resultado.detallesFormulariosExito,
        resultado.asignacionesExito
      ];
      final totalExitosos = exitosos.where((e) => e).length;

      BaseSyncService.logger.i('📊 Resultados: Clientes(${resultado.clientesExito}), Equipos(${resultado.equiposExito}), Censos(${resultado.censosExito}), EquiposPendientes(${resultado.equiposPendientesExito}), Formularios(${resultado.formulariosExito}), Detalles(${resultado.detallesFormulariosExito}), Total exitosos: $totalExitosos');

      if (totalExitosos >= 5) {
        resultado.exito = true;
        resultado.mensaje = 'Sincronización completa: ${resultado.clientesSincronizados} clientes, ${resultado.equiposSincronizados} equipos, ${resultado.censosSincronizados} censos, ${resultado.equiposPendientesSincronizados} equipos pendientes, ${resultado.formulariosSincronizados} formularios, ${resultado.detallesFormulariosSincronizados} detalles y ${resultado.asignacionesSincronizadas} asignaciones';
      } else if (totalExitosos > 0) {
        resultado.exito = true;
        final partes = <String>[];
        if (resultado.clientesExito) partes.add('${resultado.clientesSincronizados} clientes');
        if (resultado.equiposExito) partes.add('${resultado.equiposSincronizados} equipos');
        if (resultado.censosExito) partes.add('${resultado.censosSincronizados} censos');
        if (resultado.equiposPendientesExito) partes.add('${resultado.equiposPendientesSincronizados} equipos pendientes');
        if (resultado.formulariosExito) partes.add('${resultado.formulariosSincronizados} formularios');
        if (resultado.detallesFormulariosExito) partes.add('${resultado.detallesFormulariosSincronizados} detalles');
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

  // Métodos de acceso directo para compatibilidad
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

  // Métodos de formularios dinámicos
  static Future<SyncResult> sincronizarFormulariosDinamicos() =>
      DynamicFormSyncService.obtenerFormulariosDinamicos();

  static Future<SyncResult> obtenerFormularioPorId(int formId) =>
      DynamicFormSyncService.obtenerFormularioPorId(formId);

  static Future<SyncResult> obtenerFormulariosActivos() =>
      DynamicFormSyncService.obtenerFormulariosActivos();

  static Future<SyncResult> sincronizarDetallesFormularios() =>
      DynamicFormSyncService.sincronizarTodosLosDetalles();

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

  // ========== MÉTODOS DE CENSO ==========

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

  // Métodos de estadísticas y conexión
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

// Clase de resultado unificado - CON SOPORTE PARA CENSOS Y FORMULARIOS
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

  bool equiposPendientesExito = false;
  int equiposPendientesSincronizados = 0;
  String? erroresEquiposPendientes;

  bool formulariosExito = false;
  int formulariosSincronizados = 0;
  String? erroresFormularios;

  bool detallesFormulariosExito = false;
  int detallesFormulariosSincronizados = 0;
  String? erroresDetallesFormularios;

  bool asignacionesExito = false;
  int asignacionesSincronizadas = 0;
  String? erroresAsignaciones;

  @override
  String toString() {
    return 'SyncResultUnificado(exito: $exito, clientes: $clientesSincronizados, equipos: $equiposSincronizados, censos: $censosSincronizados, equiposPendientes: $equiposPendientesSincronizados, formularios: $formulariosSincronizados, detalles: $detallesFormulariosSincronizados, asignaciones: $asignacionesSincronizadas, mensaje: $mensaje)';
  }
}
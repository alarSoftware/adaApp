// lib/viewmodels/preview_screen_view_model.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/cliente.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/equipo_post_service.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/censo/censo_log_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/censo/censo_foto_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

final _logger = Logger();
final Uuid _uuid = const Uuid();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isSaving = false;
  String? _statusMessage;
  bool _isProcessing = false;
  String? _currentProcessId;

  final EquipoRepository _equipoRepository = EquipoRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();
  final CensoActivoFotoRepository _fotoRepository = CensoActivoFotoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository();

  final AuthService _authService = AuthService();

  late final CensoLogService _logService;
  late final CensoUploadService _uploadService;
  late final CensoFotoService _fotoService;

  Usuario? _usuarioActual;

  PreviewScreenViewModel() {
    _logService = CensoLogService();
    _fotoService = CensoFotoService();
    _uploadService = CensoUploadService(
      estadoEquipoRepository: _estadoEquipoRepository,
      fotoRepository: _fotoRepository,
      logService: _logService,
    );
  }

  bool get isSaving => _isSaving;
  String? get statusMessage => _statusMessage;
  bool get canConfirm => !_isProcessing && !_isSaving;

  // =================================================================
  // GETTERS DE USUARIO
  // =================================================================

  Future<int> get _getUsuarioId async {
    try {
      if (_usuarioActual != null && _usuarioActual!.id != null) return _usuarioActual!.id!;
      _usuarioActual = await _authService.getCurrentUser();
      if (_usuarioActual?.id != null) return _usuarioActual!.id!;

      await ErrorLogService.logValidationError(
        tableName: 'Users', operation: 'get_usuario_id', errorMessage: 'No se pudo obtener usuario actual, usando fallback',
      );
      _logger.w('No se pudo obtener usuario, usando ID 1 como fallback');
      return 1;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users', operation: 'get_usuario_id', errorMessage: 'Error obteniendo usuario: $e', errorType: 'auth',
      );
      _logger.e('Error obteniendo usuario: $e');
      return 1;
    }
  }

  Future<String?> get _getEdfVendedorId async {
    try {
      if (_usuarioActual != null) return _usuarioActual!.edfVendedorId;
      _usuarioActual = await _authService.getCurrentUser();
      return _usuarioActual?.edfVendedorId;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users', operation: 'get_edf_vendedor_id', errorMessage: 'Error obteniendo edf_vendedor_id: $e', errorType: 'auth',
      );
      _logger.e('Error obteniendo edf_vendedor_id: $e');
      return null;
    }
  }

  // =================================================================
  // LÓGICA PRINCIPAL (MIGRACIÓN EN CADENA)
  // =================================================================

  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    if (_isProcessing) {
      return {'success': false, 'error': 'Ya hay un proceso de confirmación en curso. Por favor espere.'};
    }

    final processId = _uuid.v4();
    _currentProcessId = processId;
    _isProcessing = true;

    try {
      return await _ejecutarConfirmacion(datos, processId);
    } finally {
      if (_currentProcessId == processId) {
        _isProcessing = false;
        _currentProcessId = null;
      }
    }
  }

  Future<Map<String, dynamic>> _ejecutarConfirmacion(
      Map<String, dynamic> datos,
      String processId,
      ) async {
    _setSaving(true);
    _setStatusMessage(null);
    String? estadoIdActual;
    String? userId;
    bool dependenciaSincronizada = true; // Asumimos éxito por defecto o si no hay dependencia

    try {
      _logger.i('🔄 Confirmando registro [Process: $processId]');

      if (_currentProcessId != processId) return {'success': false, 'error': 'Proceso cancelado'};

      final esNuevoEquipo = datos['es_nuevo_equipo'] as bool? ?? false;
      var equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      final usuarioId = await _getUsuarioId;
      userId = usuarioId.toString();

      String equipoId;

      // PASO 1: Creación de Equipo Local (si aplica)
      if (esNuevoEquipo) {
        _logger.i('🆕 === PASO 1: CREAR EQUIPO NUEVO LOCALMENTE ===');
        equipoId = await _crearEquipoNuevo(datos, null, processId, userId);
        equipoCompleto = _construirEquipoCompleto(datos, equipoId, null);
      } else {
        if (equipoCompleto == null || equipoCompleto['id'] == null) throw 'Equipo ID no válido';
        equipoId = equipoCompleto['id'].toString();
      }

      final cliente = datos['cliente'] as Cliente?;
      if (cliente == null || cliente.id == null) throw 'Cliente no válido';
      final clienteId = _convertirAInt(cliente.id, 'cliente_id');

      if (esNuevoEquipo) {
        equipoCompleto = _construirEquipoCompleto(datos, equipoId, clienteId);

        // PASO 2: ENVÍO BLOQUEANTE DEL EQUIPO (Dependencia)
        _logger.i('📤 === PASO 2: ENVIAR EQUIPO NUEVO (BLOQUEANTE) ===');
        _setStatusMessage('Sincronizando equipo...');

        dependenciaSincronizada = await _enviarEquipoAlServidorBloqueante(
          equipoId: equipoId,
          codigoBarras: datos['codigo_barras']?.toString() ?? '',
          marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
          modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
          logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
          numeroSerie: datos['numero_serie']?.toString(),
          clienteId: clienteId,
          userId: userId,
        );

        _logger.i('🔍 Resultado de la dependencia (Equipo): $dependenciaSincronizada');
      }

      // PASO 3: Verificación y registro de asignación (pendientes)
      final yaAsignado = await _verificarYRegistrarAsignacion(
        equipoId, clienteId, processId, userId, esNuevoEquipo, datos,
      );

      // PASO 4: Creación del Censo Local
      _logger.i('💾 === PASO 4: CREAR CENSO LOCAL ===');
      estadoIdActual = await _crearCensoLocal(
        equipoId: equipoId, clienteId: clienteId, datos: datos, processId: processId,
        yaAsignado: yaAsignado, userId: userId,
      );
      if (estadoIdActual == null) throw 'No se pudo crear el estado en la base de datos';

      final idsImagenes = await _fotoService.guardarFotosDelCenso(estadoIdActual, datos);

      final datosCompletos = CensoApiMapper.prepararDatosCompletos(
        estadoId: estadoIdActual, equipoId: equipoId, cliente: cliente, usuarioId: usuarioId,
        datosOriginales: datos, equipoCompleto: equipoCompleto, esCenso: datos['es_censo'] as bool? ?? true,
        esNuevoEquipo: esNuevoEquipo, yaAsignado: yaAsignado, imagenId1: idsImagenes['imagen_id_1'],
        imagenId2: idsImagenes['imagen_id_2'],
      );

      await _guardarRegistroLocal(datosCompletos, userId);

      // PASO 5: SINCRONIZACIÓN CONDICIONAL DEL CENSO
      _logger.i('📤 === PASO 5: SINCRONIZACIÓN CONDICIONAL DEL CENSO ===');
      if (dependenciaSincronizada) {
        _logger.i('✅ Dependencia OK. Iniciando sync de Censo...');
        _uploadService.sincronizarCensoEnBackground(estadoIdActual, datosCompletos);
      } else {
        _logger.w('⚠️ Dependencia fallida. Censo $estadoIdActual queda PENDIENTE (Sincronizado = 0).');
      }

      final mensajeFinal = dependenciaSincronizada
          ? (esNuevoEquipo ? 'Equipo y Censo registrados. Sincronizando...' : 'Censo registrado. Sincronizando...')
          : 'Guardado local. Se encontró un error (-501 o red) al enviar el equipo. Reintente o verifique logs.';

      return {
        'success': true,
        'message': mensajeFinal,
        'migrado_inmediatamente': dependenciaSincronizada,
        'estado_id': estadoIdActual,
        'equipo_completo': equipoCompleto,
      };

    } catch (e) {
      _logger.e('❌ Error crítico en confirmación: $e');
      await ErrorLogService.logError(
        tableName: 'censo_activo', operation: 'confirmar_registro', errorMessage: 'Error crítico en confirmación: $e',
        errorType: 'general', registroFailId: estadoIdActual, userId: userId,
      );
      return {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setSaving(false);
    }
  }

  /// Envía el equipo y espera el resultado. Retorna true solo si hay Action 100.
  Future<bool> _enviarEquipoAlServidorBloqueante({
    required String equipoId, required String codigoBarras, required int marcaId,
    required int modeloId, required int logoId, String? numeroSerie,
    int? clienteId, String? userId,
  }) async {
    try {
      final edfVendedorId = await _getEdfVendedorId;

      if (edfVendedorId == null || edfVendedorId.isEmpty) return false;

      final resultado = await EquipoPostService.enviarEquipoNuevo(
        equipoId: equipoId, codigoBarras: codigoBarras, marcaId: marcaId,
        modeloId: modeloId, logoId: logoId, numeroSerie: numeroSerie,
        clienteId: clienteId?.toString(), edfVendedorId: edfVendedorId,
      );

      if (resultado['exito'] == true) {
        await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
        _logger.i('✅ Equipo $equipoId sincronizado exitosamente (Action 100)');
        return true;
      } else {
        _logger.w('⚠️ Falla de dependencia (Equipo): ${resultado['mensaje']}');
        return false;
      }
    } catch (e) {
      _logger.e('💥 Excepción bloqueante en envío de equipo: $e');
      return false;
    }
  }

  // =================================================================
  // MÉTODOS AUXILIARES Y MANEJO DE ESTADO
  // =================================================================

  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void _setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<String> _crearEquipoNuevo(
      Map<String, dynamic> datos, int? clienteId, String processId, String? userId,
      ) async {
    _setStatusMessage('Registrando equipo nuevo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final equipoId = await _equipoRepository.crearEquipoNuevo(
        codigoBarras: datos['codigo_barras']?.toString() ?? '',
        marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
        modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
        numeroSerie: datos['numero_serie']?.toString(),
        logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
      );
      _logger.i('✅ Equipo creado localmente (disponible): $equipoId');
      return equipoId;
    } catch (e, stackTrace) {
      _logger.e('❌ Error creando equipo: $e', stackTrace: stackTrace);
      await ErrorLogService.logDatabaseError(
        tableName: 'equipments', operation: 'crear_equipo_nuevo',
        errorMessage: 'Error registrando equipo nuevo: $e', registroFailId: datos['codigo_barras']?.toString(),
      );
      throw 'Error registrando equipo nuevo: $e';
    }
  }

  Future<bool> _verificarYRegistrarAsignacion(
      String equipoId, int clienteId, String processId, String? userId,
      bool esNuevoEquipo, Map<String, dynamic>? datosEquipo,
      ) async {
    _setStatusMessage('Verificando estado del equipo...');
    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final userIdInt = userId != null ? int.tryParse(userId) : null;
      final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(equipoId, clienteId);

      _logger.i('🔍 Estado del equipo $equipoId: Nuevo=$esNuevoEquipo, Asignado=$yaAsignado');

      if (esNuevoEquipo || !yaAsignado) {
        // Registrar el pendiente localmente (Necesario para el sync masivo)
        await _equipoPendienteRepository.procesarEscaneoCenso(
          equipoId: equipoId, clienteId: clienteId, usuarioId: userIdInt,
        );

        return false;
      }
      return true; // CASO C: YA ASIGNADO (Envío del Censo puede continuar)
    } catch (e) {
      _logger.e('❌ Error verificando asignación: $e');
      throw 'Error verificando asignación: $e';
    }
  }

  Future<String?> _crearCensoLocal({
    required String equipoId, required int clienteId, required Map<String, dynamic> datos,
    required String processId, required bool yaAsignado, String? userId,
  }) async {
    _setStatusMessage('Registrando censo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final now = DateTime.now().toLocal();
      final estadoCenso = yaAsignado ? 'asignado' : 'pendiente';

      final estadoCreado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoId: equipoId, clienteId: clienteId, latitud: datos['latitud'],
        longitud: datos['longitud'], fechaRevision: now, enLocal: true,
        observaciones: datos['observaciones']?.toString(), estadoCenso: estadoCenso,
      );

      if (estadoCreado.id != null) return estadoCreado.id!;

      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo', operation: 'crear_estado',
        errorMessage: 'Estado creado pero sin ID retornado', registroFailId: equipoId,
      );
      return null;
    } catch (e) {
      _logger.e('❌ Error creando estado: $e');
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo', operation: 'crear_censo_local',
        errorMessage: 'Error creando censo: $e', registroFailId: equipoId,
      );
      throw 'Error creando censo: $e';
    }
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos, String? userId) async {
    try {
      final estadoId = datos['id'];
      if (estadoId == null) throw 'No se pudo obtener el ID del estado';

      await _estadoEquipoRepository.dbHelper.actualizar(
        'censo_activo',
        {'usuario_id': datos['usuario_id'], 'fecha_actualizacion': datos['fecha_creacion']},
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      _logger.e('❌ Error guardando datos localmente: $e');
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo', operation: 'guardar_registro_local',
        errorMessage: 'Error guardando datos localmente: $e', registroFailId: datos['id']?.toString(),
      );
      throw 'Error guardando datos localmente: $e';
    }
  }

  Map<String, dynamic> _construirEquipoCompleto(
      Map<String, dynamic> datos, String equipoId, int? clienteId,
      ) {
    return {
      'id': equipoId, 'cod_barras': datos['codigo_barras'], 'marca_id': datos['marca_id'],
      'modelo_id': datos['modelo_id'], 'modelo_nombre': datos['modelo'], 'numero_serie': datos['numero_serie'],
      'logo_id': datos['logo_id'], 'logo_nombre': datos['logo'], 'marca_nombre': datos['marca'] ?? 'Sin marca',
      'cliente_id': clienteId, 'app_insert': 1,
    };
  }

  // =================================================================
  // MÉTODOS PÚBLICOS DE UTILIDAD
  // =================================================================

  String formatearFecha(String? fechaIso) {
    if (fechaIso == null) return 'No disponible';
    try {
      final fecha = DateTime.parse(fechaIso).toLocal();
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final ano = fecha.year;
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano - $hora:$minuto';
    } catch (e) {
      return 'Formato inválido';
    }
  }

  Future<Map<String, dynamic>> verificarSincronizacionPendiente(String? estadoId) async {
    if (estadoId == null) return {'pendiente': false};
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo', where: 'id = ?', whereArgs: [estadoId], limit: 1,
      );
      if (maps.isEmpty) return {'pendiente': false};
      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;
      return {'pendiente': (estadoCenso == 'creado' || estadoCenso == 'error') && sincronizado == 0};
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo', operation: 'verificar_sincronizacion',
        errorMessage: 'Error verificando sincronización: $e', registroFailId: estadoId,
      );
      return {'pendiente': false};
    }
  }

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(String? estadoId) async {
    if (estadoId == null) { return {'pendiente': false, 'estado': 'desconocido', 'mensaje': 'No hay ID de estado', 'icono': Icons.help_outline, 'color': Colors.grey,}; }
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo', where: 'id = ?', whereArgs: [estadoId], limit: 1,
      );
      if (maps.isEmpty) { return {'pendiente': false, 'estado': 'no_encontrado', 'mensaje': 'Estado no encontrado', 'icono': Icons.error_outline, 'color': Colors.grey,}; }
      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      String mensaje; IconData icono; Color color;
      if (sincronizado == 1) { mensaje = 'Registro sincronizado correctamente'; icono = Icons.cloud_done; color = Colors.green;
      } else if (estadoCenso == 'error') { mensaje = 'Error en sincronización - Puede reintentar'; icono = Icons.cloud_off; color = Colors.red;
      } else { mensaje = 'Pendiente de sincronización automática'; icono = Icons.cloud_upload; color = Colors.orange; }

      return {
        'pendiente': (estadoCenso == 'creado' || estadoCenso == 'error') && sincronizado == 0,
        'estado': estadoCenso, 'sincronizado': sincronizado, 'mensaje': mensaje, 'icono': icono,
        'color': color, 'fecha_creacion': estado['fecha_creacion'], 'observaciones': estado['observaciones'],
      };
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo', operation: 'obtener_info_sincronizacion',
        errorMessage: 'Error consultando estado: $e', registroFailId: estadoId,
      );
      return {'pendiente': false, 'estado': 'error', 'mensaje': 'Error consultando estado: $e', 'icono': Icons.error, 'color': Colors.red,};
    }
  }

  Future<Map<String, dynamic>> reintentarEnvio(String estadoId) async {
    try {
      final usuarioId = await _getUsuarioId;
      final edfVendedorId = await _getEdfVendedorId;

      return await _uploadService.reintentarEnvioCenso(estadoId, usuarioId, edfVendedorId);

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'censo_activo', operation: 'reintentar_envio',
        errorMessage: 'Error al reintentar envío: $e', errorType: 'retry', registroFailId: estadoId,
      );
      return {'success': false, 'error': 'Error al reintentar: $e',};
    }
  }

  Future<List<String>> obtenerLogsGuardados() async {
    return await _logService.obtenerLogsGuardados();
  }

  void cancelarProcesoActual() {
    if (_isProcessing) {
      _logger.i('⚠️ Cancelando proceso: $_currentProcessId');
      _currentProcessId = null;
      _isProcessing = false;
      _setSaving(false);
      _setStatusMessage(null);
    }
  }

  @override
  void dispose() {
    cancelarProcesoActual();
    super.dispose();
  }

  // =================================================================
  // HELPERS PRIVADOS DE CASTEO
  // =================================================================

  int _convertirAInt(dynamic valor, String nombreCampo) {
    if (valor == null) throw 'El campo $nombreCampo es null';
    if (valor is int) return valor;
    if (valor is String) {
      if (valor.isEmpty) throw 'El campo $nombreCampo está vacío';
      final int? parsed = int.tryParse(valor);
      if (parsed != null) return parsed;
      throw 'El campo $nombreCampo ("$valor") no es un número válido';
    }
    if (valor is double) return valor.toInt();
    throw 'El campo $nombreCampo tiene un tipo no soportado: ${valor.runtimeType}';
  }

  int? _safeCastToInt(dynamic value, String fieldName) {
    try {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    } catch (e) {
      return null;
    }
  }
}
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/cliente.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/censo/censo_log_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/censo/censo_foto_service.dart';

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

  // Nuevos servicios
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

  Future<int> get _getUsuarioId async {
    if (_usuarioActual != null && _usuarioActual!.id != null) {
      return _usuarioActual!.id!;
    }
    _usuarioActual = await _authService.getCurrentUser();
    if (_usuarioActual?.id != null) {
      return _usuarioActual!.id!;
    }
    _logger.w('No se pudo obtener usuario, usando ID 1 como fallback');
    return 1;
  }

  Future<String?> get _getEdfVendedorId async {
    if (_usuarioActual != null) {
      return _usuarioActual!.edfVendedorId;
    }
    _usuarioActual = await _authService.getCurrentUser();
    return _usuarioActual?.edfVendedorId;
  }

  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void _setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

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

  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    if (_isProcessing) {
      return {
        'success': false,
        'error': 'Ya hay un proceso de confirmación en curso. Por favor espere.'
      };
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

    try {
      _logger.i('🔄 Confirmando registro [Process: $processId]');

      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      final cliente = datos['cliente'] as Cliente?;
      final esCenso = datos['es_censo'] as bool? ?? true;
      final esNuevoEquipo = datos['es_nuevo_equipo'] as bool? ?? false;
      var equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;

      if (cliente == null) throw 'Cliente no encontrado';
      if (cliente.id == null) throw 'El cliente no tiene ID';

      final usuarioId = await _getUsuarioId;
      final clienteId = _convertirAInt(cliente.id, 'cliente_id');

      // CREAR EQUIPO NUEVO SI CORRESPONDE
      String equipoId;
      if (esNuevoEquipo) {
        equipoId = await _crearEquipoNuevo(datos, clienteId, processId);
        equipoCompleto = _construirEquipoCompleto(datos, equipoId, clienteId);
      } else {
        if (equipoCompleto == null) throw 'No se encontró información del equipo';
        if (equipoCompleto['id'] == null) throw 'El equipo no tiene ID';
        equipoId = equipoCompleto['id'].toString();
      }

      // VERIFICAR Y REGISTRAR ASIGNACIÓN
      final yaAsignado = await _verificarYRegistrarAsignacion(
        equipoId,
        clienteId,
        processId,
      );

      // CREAR CENSO EN BD LOCAL
      estadoIdActual = await _crearCensoLocal(
        equipoId: equipoId,
        clienteId: clienteId,
        datos: datos,
        processId: processId,
      );

      if (estadoIdActual == null) {
        throw 'No se pudo crear el estado en la base de datos';
      }

      // GUARDAR FOTOS Y OBTENER IDs
      final idsImagenes = await _fotoService.guardarFotosDelCenso(estadoIdActual, datos);

      // PREPARAR DATOS COMPLETOS
      final datosCompletos = CensoApiMapper.prepararDatosCompletos(
        estadoId: estadoIdActual,
        equipoId: equipoId,
        cliente: cliente,
        usuarioId: usuarioId,
        datosOriginales: datos,
        equipoCompleto: equipoCompleto,
        esCenso: esCenso,
        esNuevoEquipo: esNuevoEquipo,
        yaAsignado: yaAsignado,
        imagenId1: idsImagenes['imagen_id_1'],
        imagenId2: idsImagenes['imagen_id_2'],
      );

      // GUARDAR REGISTRO LOCAL
      await _guardarRegistroLocal(datosCompletos);

      // SINCRONIZAR EN BACKGROUND
      _uploadService.sincronizarCensoEnBackground(estadoIdActual, datosCompletos);

      _logger.i('✅ Registro guardado. Sincronización en segundo plano iniciada');

      final mensajeFinal = esNuevoEquipo
          ? 'Equipo nuevo registrado. Sincronizando en segundo plano...'
          : 'Censo registrado. Sincronizando en segundo plano...';

      return {
        'success': true,
        'message': mensajeFinal,
        'migrado_inmediatamente': false,
        'estado_id': estadoIdActual,
        'equipo_completo': equipoCompleto,
      };
    } catch (e) {
      _logger.e('❌ Error crítico en confirmación: $e');
      return {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setSaving(false);
    }
  }

  // ==================== MÉTODOS AUXILIARES ====================

  Future<String> _crearEquipoNuevo(
      Map<String, dynamic> datos,
      int clienteId,
      String processId,
      ) async {
    _setStatusMessage('Registrando equipo nuevo...');

    if (_currentProcessId != processId) {
      throw 'Proceso cancelado';
    }

    try {
      final equipoId = await _equipoRepository.crearEquipoNuevo(
        codigoBarras: datos['codigo_barras']?.toString() ?? '',
        marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
        modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
        numeroSerie: datos['numero_serie']?.toString(),
        logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
      );

      _logger.i('✅ Equipo nuevo creado: $equipoId');
      return equipoId;
    } catch (e) {
      _logger.e('❌ Error creando equipo: $e');
      throw 'Error registrando equipo nuevo: $e';
    }
  }

  Map<String, dynamic> _construirEquipoCompleto(
      Map<String, dynamic> datos,
      String equipoId,
      int clienteId,
      ) {
    return {
      'id': equipoId,
      'cod_barras': datos['codigo_barras'],
      'marca_id': datos['marca_id'],
      'modelo_id': datos['modelo_id'],
      'modelo_nombre': datos['modelo'],
      'numero_serie': datos['numero_serie'],
      'logo_id': datos['logo_id'],
      'logo_nombre': datos['logo'],
      'marca_nombre': datos['marca'] ?? 'Sin marca',
      'cliente_id': clienteId,
      'app_insert': 1,
    };
  }

  Future<bool> _verificarYRegistrarAsignacion(
      String equipoId,
      int clienteId,
      String processId,
      ) async {
    _setStatusMessage('Verificando estado del equipo...');

    if (_currentProcessId != processId) {
      throw 'Proceso cancelado';
    }

    final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(
      equipoId,
      clienteId,
    );

    _logger.i('Equipo $equipoId ya asignado: $yaAsignado');

    if (!yaAsignado) {
      _setStatusMessage('Registrando equipo pendiente...');

      if (_currentProcessId != processId) {
        throw 'Proceso cancelado';
      }

      try {
        await _equipoPendienteRepository.procesarEscaneoCenso(
          equipoId: equipoId,
          clienteId: clienteId,
        );
        _logger.i('✅ Registro pendiente creado');
      } catch (e) {
        _logger.w('⚠️ Error registrando pendiente: $e');
      }
    }

    return yaAsignado;
  }

  Future<String?> _crearCensoLocal({
    required String equipoId,
    required int clienteId,
    required Map<String, dynamic> datos,
    required String processId,
  }) async {
    _setStatusMessage('Registrando censo...');

    if (_currentProcessId != processId) {
      throw 'Proceso cancelado';
    }

    try {
      final now = DateTime.now().toLocal();

      final estadoCreado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoId: equipoId,
        clienteId: clienteId,
        latitud: datos['latitud'],
        longitud: datos['longitud'],
        fechaRevision: now,
        enLocal: true,
        observaciones: datos['observaciones']?.toString(),
      );

      if (estadoCreado.id != null) {
        _logger.i('✅ Estado creado: ${estadoCreado.id}');
        return estadoCreado.id!;
      } else {
        _logger.w('⚠️ Estado creado sin ID');
        return null;
      }
    } catch (e) {
      _logger.e('❌ Error creando estado: $e');
      throw 'Error creando censo: $e';
    }
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos) async {
    try {
      _logger.i('💾 Guardando registro local: ${datos['id_local']}');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw 'Error guardando datos localmente';
    }
  }

  // ==================== MÉTODOS PÚBLICOS DE SINCRONIZACIÓN ====================

  Future<Map<String, dynamic>> verificarSincronizacionPendiente(String? estadoId) async {
    if (estadoId == null) return {'pendiente': false};

    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) return {'pendiente': false};

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      return {
        'pendiente': (estadoCenso == 'creado' || estadoCenso == 'error') && sincronizado == 0,
      };
    } catch (e) {
      _logger.e('❌ Error verificando sincronización: $e');
      return {'pendiente': false};
    }
  }

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(String? estadoId) async {
    if (estadoId == null) {
      return {
        'pendiente': false,
        'estado': 'desconocido',
        'mensaje': 'No hay ID de estado',
        'icono': Icons.help_outline,
        'color': Colors.grey,
      };
    }

    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return {
          'pendiente': false,
          'estado': 'no_encontrado',
          'mensaje': 'Estado no encontrado',
          'icono': Icons.error_outline,
          'color': Colors.grey,
        };
      }

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      final estaPendiente = (estadoCenso == 'creado' || estadoCenso == 'error') &&
          sincronizado == 0;

      String mensaje;
      IconData icono;
      Color color;

      if (sincronizado == 1) {
        mensaje = 'Registro sincronizado correctamente';
        icono = Icons.cloud_done;
        color = Colors.green;
      } else if (estadoCenso == 'error') {
        mensaje = 'Error en sincronización - Puede reintentar';
        icono = Icons.cloud_off;
        color = Colors.red;
      } else {
        mensaje = 'Pendiente de sincronización automática';
        icono = Icons.cloud_upload;
        color = Colors.orange;
      }

      return {
        'pendiente': estaPendiente,
        'estado': estadoCenso,
        'sincronizado': sincronizado,
        'mensaje': mensaje,
        'icono': icono,
        'color': color,
        'fecha_creacion': estado['fecha_creacion'],
        'observaciones': estado['observaciones'],
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo info: $e');
      return {
        'pendiente': false,
        'estado': 'error',
        'mensaje': 'Error consultando estado: $e',
        'icono': Icons.error,
        'color': Colors.red,
      };
    }
  }

  Future<Map<String, dynamic>> reintentarEnvio(String estadoId) async {
    final usuarioId = await _getUsuarioId;
    final edfVendedorId = await _getEdfVendedorId;

    return await _uploadService.reintentarEnvioCenso(
      estadoId,
      usuarioId,
      edfVendedorId,
    );
  }

  // ==================== LOGS ====================

  Future<List<String>> obtenerLogsGuardados() async {
    return await _logService.obtenerLogsGuardados();
  }

  // ==================== HELPERS ====================

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
}
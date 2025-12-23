import 'package:ada_app/viewmodels/preview_screen_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../repositories/censo_activo_repository.dart';
import '../repositories/equipo_repository.dart';
import '../models/censo_activo.dart';
import 'package:ada_app/services/device/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:uuid/uuid.dart';

final Uuid _uuid = const Uuid();

abstract class EquiposClienteDetailUIEvent {}

class ShowMessageEvent extends EquiposClienteDetailUIEvent {
  final String message;
  final MessageType type;
  ShowMessageEvent(this.message, this.type);
}

class ShowRetireConfirmationDialogEvent extends EquiposClienteDetailUIEvent {
  final dynamic equipoCliente;
  ShowRetireConfirmationDialogEvent(this.equipoCliente);
}

enum MessageType { error, success, info, warning }

class EquiposClienteDetailState {
  final dynamic equipoCliente;
  final bool isProcessing;
  final bool equipoEnLocal;
  final List<CensoActivo> historialCambios;
  final List<CensoActivo> historialUltimos5;

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
    this.historialCambios = const [],
    this.historialUltimos5 = const [],
  }) : equipoEnLocal =
           equipoEnLocal ?? (equipoCliente['tipo_estado'] == 'asignado');

  EquiposClienteDetailState copyWith({
    dynamic equipoCliente,
    bool? isProcessing,
    bool? equipoEnLocal,
    List<CensoActivo>? historialCambios,
    List<CensoActivo>? historialUltimos5,
  }) {
    return EquiposClienteDetailState(
      equipoCliente: equipoCliente ?? this.equipoCliente,
      isProcessing: isProcessing ?? this.isProcessing,
      equipoEnLocal: equipoEnLocal ?? this.equipoEnLocal,
      historialCambios: historialCambios ?? this.historialCambios,
      historialUltimos5: historialUltimos5 ?? this.historialUltimos5,
    );
  }
}

class EquiposClienteDetailScreenViewModel extends ChangeNotifier {
  final CensoActivoRepository _estadoEquipoRepository;
  final EquipoRepository _equipoRepository;

  final LocationService _locationService = LocationService();

  EquiposClienteDetailState _state;

  bool? _estadoUbicacionEquipo;
  bool _hasUnsavedChanges = false;
  int _estadoLocalActual;

  final StreamController<EquiposClienteDetailUIEvent> _eventController =
      StreamController<EquiposClienteDetailUIEvent>.broadcast();
  Stream<EquiposClienteDetailUIEvent> get uiEvents => _eventController.stream;

  EquiposClienteDetailScreenViewModel(
    dynamic equipoCliente,
    this._estadoEquipoRepository,
    this._equipoRepository,
  ) : _state = EquiposClienteDetailState(equipoCliente: equipoCliente),
      _estadoLocalActual = _determinarEstadoInicial(equipoCliente) {
    _initializeState();
    _verificarEstadoReal();
  }

  static int _determinarEstadoInicial(dynamic equipoCliente) {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();
    if (tipoEstado == 'asignado') {
      return 1;
    } else {
      return 0;
    }
  }

  String _getDiaActual() {
    final diasSemana = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final now = DateTime.now();
    return diasSemana[now.weekday - 1];
  }

  bool _validarDiaRuta() {
    // Obtener rutaDia del equipoCliente
    final rutaDia = equipoCliente['ruta_dia']?.toString();

    // Si el cliente no tiene día de ruta asignado, permitir acceso
    if (rutaDia == null || rutaDia.isEmpty) return true;

    final diaActual = _getDiaActual();

    // Validar que el día actual coincida con el día de ruta
    return rutaDia == diaActual;
  }

  bool puedeRealizarCambios() {
    return _validarDiaRuta();
  }

  String obtenerMensajeRestriccionDia() {
    final diaActual = _getDiaActual();
    final rutaDia = equipoCliente['ruta_dia']?.toString() ?? 'sin asignar';

    return 'No puedes realizar cambios hoy.\n'
        'Este cliente corresponde al día: $rutaDia\n'
        'Hoy es: $diaActual';
  }

  void _initializeState() {
    _estadoUbicacionEquipo = null;
    _hasUnsavedChanges = false;
  }

  // VALIDAR ESTADO REAL CON REPOSITORIOS (ASIGNADO vs PENDIENTE)
  Future<void> _verificarEstadoReal() async {
    try {
      final equipoId = equipoCliente['equipo_id'] ?? equipoCliente['id'];
      final clienteId = equipoCliente['cliente_id'];

      if (equipoId == null || clienteId == null) {
        _loadInitialState();
        return;
      }

      final cId = int.tryParse(clienteId.toString());
      if (cId == null) {
        _loadInitialState();
        return;
      }

      String nuevoTipoEstado;

      // Usar la lógica estricta de "Asignado" que usa la pantalla de Cliente
      final esAsignado = await _equipoRepository.verificarAsignacionEstricta(
        equipoId.toString(),
        cId,
      );

      if (esAsignado) {
        nuevoTipoEstado = 'asignado';
      } else {
        // Si no pasa la validación estricta de asignado, asumimos pendiente
        // (ya que debería estar en una de las dos listas)
        nuevoTipoEstado = 'pendiente';
      }

      // Actualizar el estado local si cambió
      if (nuevoTipoEstado != equipoCliente['tipo_estado']) {
        final nuevoEquipoCliente = Map<String, dynamic>.from(equipoCliente);
        nuevoEquipoCliente['tipo_estado'] = nuevoTipoEstado;

        _state = _state.copyWith(equipoCliente: nuevoEquipoCliente);

        // Recalcular estado local based on new type
        _estadoLocalActual = _determinarEstadoInicial(nuevoEquipoCliente);

        // Notificar cambio
        notifyListeners();
      }

      // Finalmente cargar historial
      await _loadInitialState();
    } catch (e) {
      _loadInitialState();
    }
  }

  // CARGAR ESTADO INICIAL Y HISTORIAL
  Future<void> _loadInitialState() async {
    try {
      final codigoBarras = equipoCliente['cod_barras']?.toString();
      final clienteId = equipoCliente['cliente_id'];

      if (codigoBarras == null || codigoBarras.isEmpty || clienteId == null) {
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      CensoActivo? estadoActual;
      List<CensoActivo> historialCompleto = [];

      try {
        historialCompleto = await _estadoEquipoRepository
            .obtenerHistorialDirectoPorEquipoCliente(
              codigoBarras,
              int.parse(clienteId.toString()),
            );
      } catch (e) {
        try {
          historialCompleto = await _estadoEquipoRepository
              .obtenerHistorialCompleto(
                codigoBarras,
                int.parse(clienteId.toString()),
              );
        } catch (e2) {
          historialCompleto = [];
        }
      }

      estadoActual = historialCompleto.isNotEmpty
          ? historialCompleto.first
          : null;

      if (estadoActual == null && tipoEstado == 'asignado') {
        print("ESTOY");
        try {
          print("antes");
          estadoActual = await _estadoEquipoRepository.obtenerUltimoEstado(
            codigoBarras,
            int.parse(clienteId.toString()),
          );

          if (estadoActual != null) {
            historialCompleto = [estadoActual];
          }
        } catch (e) {
          //LOG ERROR
          print("Error al obtener último estado: $e");
        }
      }

      if (estadoActual != null) {
        _estadoLocalActual = estadoActual.enLocal ? 1 : 0;
      } else {
        _estadoLocalActual = tipoEstado == 'asignado' ? 1 : 0;
      }

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();
    } catch (e) {
      _estadoLocalActual = equipoCliente['tipo_estado'] == 'asignado' ? 1 : 0;

      _state = _state.copyWith(
        historialCambios: [],
        historialUltimos5: [],
        equipoEnLocal: _estadoLocalActual == 1,
      );

      notifyListeners();
    }
  }

  // ========== GETTERS PÚBLICOS ==========
  EquiposClienteDetailState get state => _state;
  dynamic get equipoCliente => _state.equipoCliente;
  bool get isProcessing => _state.isProcessing;
  bool get isEquipoActivo {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();
    return tipoEstado == 'asignado';
  }

  bool? get estadoUbicacionEquipo => _estadoUbicacionEquipo;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get saveButtonEnabled => _estadoUbicacionEquipo != null;

  String get saveButtonText {
    if (_estadoUbicacionEquipo == null) return 'Seleccione ubicación';
    return 'Guardar cambios';
  }

  List<CensoActivo> get historialUltimos5 => _state.historialUltimos5;
  List<CensoActivo> get historialCompleto => _state.historialCambios;
  int get totalCambios => _state.historialCambios.length;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== MÉTODOS PARA DROPDOWN ==========

  // Getter para saber si el dropdown debe estar habilitado
  bool get dropdownHabilitado => _validarDiaRuta();

  void cambiarUbicacionEquipo(bool? nuevaUbicacion) {
    // VALIDAR DÍA DE RUTA ANTES DE PERMITIR CAMBIOS
    if (!_validarDiaRuta()) {
      _eventController.add(
        ShowMessageEvent(obtenerMensajeRestriccionDia(), MessageType.error),
      );
      return;
    }

    _estadoUbicacionEquipo = nuevaUbicacion;
    _hasUnsavedChanges = _estadoUbicacionEquipo != null;
    notifyListeners();
  }

  Future<void> toggleEquipoEnLocal(bool value) async {
    cambiarUbicacionEquipo(value);
  }

  Future<void> recargarHistorial() async {
    try {
      final equipoId = equipoCliente['id'];
      final clienteId = equipoCliente['cliente_id'];

      if (equipoId == null || clienteId == null) {
        return;
      }

      final tipoEstado = equipoCliente['tipo_estado']?.toString();
      List<CensoActivo> historialCompleto = [];

      historialCompleto = await _estadoEquipoRepository
          .obtenerHistorialCompleto(
            equipoId.toString(),
            int.parse(clienteId.toString()),
          );

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
      );

      notifyListeners();
    } catch (e) {
      // Error recargando historial
    }
  }

  // ========== GUARDAR CAMBIOS DESDE EQUIPO FUERA DE LOCAL ==========
  Future<void> saveAllChanges() async {
    // VALIDAR DÍA DE RUTA ANTES DE GUARDAR
    if (!_validarDiaRuta()) {
      _eventController.add(
        ShowMessageEvent(obtenerMensajeRestriccionDia(), MessageType.error),
      );
      return;
    }

    if (_estadoUbicacionEquipo == null) {
      _eventController.add(
        ShowMessageEvent(
          'Debe seleccionar una ubicación para el equipo antes de guardar',
          MessageType.error,
        ),
      );
      return;
    }

    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      late final Position position;
      try {
        position = await _locationService.getCurrentLocationRequired(
          timeout: Duration(seconds: 30),
        );
      } on LocationException catch (e) {
        _state = _state.copyWith(isProcessing: false);
        notifyListeners();
        _eventController.add(
          ShowMessageEvent('GPS requerido: ${e.message}', MessageType.error),
        );
        return;
      }

      final clienteId = equipoCliente['cliente_id'];
      final codigoBarras = equipoCliente['cod_barras']?.toString();

      if (clienteId == null || codigoBarras == null || codigoBarras.isEmpty) {
        throw Exception('Código de barras o cliente no disponible');
      }

      // Obtener usuario actual antes de crear el registro
      final currentUser = await AuthService().getCurrentUser();

      Map<String, dynamic> datos = {};
      final processId = _uuid.v4();

      datos['es_nuevo_equipo'] = false;
      datos['cliente'] = {'id': int.parse(clienteId.toString())};

      // CORRECCIÓN: equipo_completo debe ser un Map, no un ID
      datos['equipo_completo'] = {
        'id': equipoCliente['id'],
        'cod_barras': codigoBarras,
        'numero_serie': equipoCliente['numero_serie'],
        'marca_id': equipoCliente['marca_id'],
        'modelo_id': equipoCliente['modelo_id'],
        'logo_id': equipoCliente['logo_id'],
        'marca_nombre': equipoCliente['marca_nombre'],
        'modelo_nombre': equipoCliente['modelo_nombre'],
        'logo_nombre': equipoCliente['logo_nombre'],
        'cliente_id': clienteId,
        'tipo_estado':
            'asignado', // Asumimos asignado al guardar cambios de ubicación
      };

      datos['codigo_barras'] = codigoBarras;
      datos['numero_serie'] = equipoCliente['numero_serie'];
      datos['modelo_id'] = equipoCliente['modelo_id'];
      datos['logo_id'] = equipoCliente['logo_id'];
      datos['marca_id'] = equipoCliente['marca_id'];
      datos['marca_nombre'] = equipoCliente['marca_nombre'];
      datos['modelo'] = equipoCliente['modelo_nombre'];
      datos['logo'] = equipoCliente['logo_nombre'];
      datos['latitud'] = position.latitude;
      datos['longitud'] = position.longitude;
      datos['observaciones'] = '';
      datos['usuario_id'] = currentUser?.id;
      datos['equipo_id'] = equipoCliente['id'];

      // Asignar el valor seleccionado en el dropdown
      datos['en_local'] = _estadoUbicacionEquipo;

      final result = await PreviewScreenViewModel.insertarEnviarCensoActivo(
        datos,
        processId,
      );

      if (result['success'] != true) {
        throw result['error'] ?? 'Error desconocido';
      }

      _estadoLocalActual = _estadoUbicacionEquipo! ? 1 : 0;
      _estadoUbicacionEquipo = null;
      _hasUnsavedChanges = false;

      // Recargar historial para reflejar cambios
      await recargarHistorial();

      _state = _state.copyWith(isProcessing: false);

      notifyListeners();

      _eventController.add(
        ShowMessageEvent(
          'Cambios guardados con ubicación GPS',
          MessageType.success,
        ),
      );
    } catch (e) {
      _state = _state.copyWith(isProcessing: false);
      notifyListeners();
      _eventController.add(
        ShowMessageEvent('Error al guardar los cambios: $e', MessageType.error),
      );
    }
  }

  bool canSaveChanges() {
    return _estadoUbicacionEquipo != null;
  }

  void resetChanges() {
    _estadoUbicacionEquipo = null;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  bool get isEquipoEnLocal {
    return _estadoUbicacionEquipo ?? _state.equipoEnLocal;
  }

  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String formatearFechaHora(DateTime fecha) {
    return '${formatearFecha(fecha)} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  String formatearFechaHistorial(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours}h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return formatearFechaHora(fecha);
    }
  }

  String getNombreCompletoEquipo() {
    return '${equipoCliente['marca_nombre'] ?? ''} ${equipoCliente['modelo_nombre'] ?? ''}'
        .trim();
  }

  bool shouldShowMarca() {
    return equipoCliente['marca_nombre'] != null &&
        equipoCliente['marca_nombre']!.isNotEmpty;
  }

  bool shouldShowModelo() {
    return equipoCliente['modelo_nombre'] != null &&
        equipoCliente['modelo_nombre']!.isNotEmpty;
  }

  bool shouldShowCodBarras() {
    return equipoCliente['cod_barras'] != null &&
        equipoCliente['cod_barras']!.isNotEmpty;
  }

  String getMarcaText() {
    return equipoCliente['marca_nombre'] ?? '';
  }

  String getModeloText() {
    return equipoCliente['modelo_nombre'] ?? '';
  }

  String getCodBarrasText() {
    return equipoCliente['cod_barras'] ?? '';
  }

  String getLogoText() {
    return equipoCliente['logo_nombre'] ?? '';
  }

  String getTiempoAsignadoText() {
    final fechaString = equipoCliente['fecha_creacion'];
    if (fechaString == null) return '0 días';

    try {
      final fecha = DateTime.parse(fechaString);
      final diferencia = DateTime.now().difference(fecha);
      return '${diferencia.inDays} días';
    } catch (e) {
      return '0 días';
    }
  }

  String getFechaRetiroText() {
    return 'No disponible';
  }

  String getEstadoText() {
    final tipoEstado = equipoCliente['tipo_estado']?.toString();

    if (tipoEstado == 'asignado') {
      return _estadoLocalActual == 1 ? 'En local' : 'Fuera del local';
    } else if (tipoEstado == 'pendiente') {
      return 'Pendiente';
    } else {
      return 'Sin estado';
    }
  }

  Map<String, String> getRetireDialogData() {
    return {
      'equipoNombre': getNombreCompletoEquipo(),
      'equipoCodigo': equipoCliente['cod_barras'] ?? 'Sin código',
      'clienteNombre':
          'Cliente ID: ${equipoCliente['cliente_id'] ?? "No asignado"}',
    };
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'equipo_id': equipoCliente['id'],
      'cliente_id': equipoCliente['cliente_id'],
      'tipo_estado': equipoCliente['tipo_estado'],
      'equipo_marca': equipoCliente['marca_nombre'],
      'equipo_modelo': equipoCliente['modelo_nombre'],
      'codigo_barras': equipoCliente['cod_barras'],
      'cliente_nombre': equipoCliente['cliente_nombre'],
      'is_processing': _state.isProcessing,
      'equipo_en_local': _state.equipoEnLocal,
      'estado_dropdown': _estadoUbicacionEquipo,
      'estado_local_actual': _estadoLocalActual,
      'has_unsaved_changes': _hasUnsavedChanges,
      'total_cambios_historial': _state.historialCambios.length,
      'ultimos_5_cambios': _state.historialUltimos5.length,
    };
  }
}

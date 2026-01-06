import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/cliente.dart';
import '../repositories/equipo_repository.dart';
import '../repositories/equipo_pendiente_repository.dart';
import '../repositories/censo_activo_repository.dart';

abstract class ClienteDetailUIEvent {}

class ShowErrorEvent extends ClienteDetailUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class NavigateToFormsEvent extends ClienteDetailUIEvent {
  final Cliente cliente;
  NavigateToFormsEvent(this.cliente);
}

class NavigateToEquipoDetailEvent extends ClienteDetailUIEvent {
  final Map<String, dynamic> equipoData;
  NavigateToEquipoDetailEvent(this.equipoData);
}

class RefreshCompletedEvent extends ClienteDetailUIEvent {}

class ClienteDetailState {
  final bool isLoading;
  final List<Map<String, dynamic>> equiposAsignadosList;
  final List<Map<String, dynamic>> equiposPendientesList;
  final String? errorMessage;

  ClienteDetailState({
    this.isLoading = false,
    this.equiposAsignadosList = const [],
    this.equiposPendientesList = const [],
    this.errorMessage,
  });

  ClienteDetailState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? equiposAsignadosList,
    List<Map<String, dynamic>>? equiposPendientesList,
    String? errorMessage,
  }) {
    return ClienteDetailState(
      isLoading: isLoading ?? this.isLoading,
      equiposAsignadosList: equiposAsignadosList ?? this.equiposAsignadosList,
      equiposPendientesList:
          equiposPendientesList ?? this.equiposPendientesList,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isEmpty =>
      equiposAsignadosList.isEmpty &&
      equiposPendientesList.isEmpty &&
      !isLoading &&
      !hasError;

  int get equiposAsignadosCount => equiposAsignadosList.length;
  int get equiposPendientesCount => equiposPendientesList.length;
  int get totalEquiposCount =>
      equiposAsignadosList.length + equiposPendientesList.length;

  bool get tieneEquiposAsignados => equiposAsignadosList.isNotEmpty;
  bool get tieneEquiposPendientes => equiposPendientesList.isNotEmpty;

  List<Map<String, dynamic>> get equiposCompletos => [
    ...equiposAsignadosList,
    ...equiposPendientesList,
  ];
}

class ClienteDetailScreenViewModel extends ChangeNotifier {
  final EquipoRepository _equipoRepository = EquipoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository =
      EquipoPendienteRepository();
  final CensoActivoRepository _estadoEquipoRepository = CensoActivoRepository();

  ClienteDetailState _state = ClienteDetailState();
  Cliente? _cliente;

  final StreamController<ClienteDetailUIEvent> _eventController =
      StreamController<ClienteDetailUIEvent>.broadcast();
  Stream<ClienteDetailUIEvent> get uiEvents => _eventController.stream;

  ClienteDetailState get state => _state;
  bool get isLoading => _state.isLoading;
  List<Map<String, dynamic>> get equiposAsignadosList =>
      _state.equiposAsignadosList;
  List<Map<String, dynamic>> get equiposPendientesList =>
      _state.equiposPendientesList;
  List<Map<String, dynamic>> get equiposCompletos => _state.equiposCompletos;

  String? get errorMessage => _state.errorMessage;
  bool get hasError => _state.hasError;
  bool get isEmpty => _state.isEmpty;

  int get equiposAsignadosCount => _state.equiposAsignadosCount;
  int get equiposPendientesCount => _state.equiposPendientesCount;
  int get totalEquiposCount => _state.totalEquiposCount;

  bool get tieneEquiposAsignados => _state.tieneEquiposAsignados;
  bool get tieneEquiposPendientes => _state.tieneEquiposPendientes;
  bool get noTieneEquipos => isEmpty && !isLoading && !hasError;

  Cliente? get cliente => _cliente;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  bool _canCreateCenso = true;
  bool get canCreateCenso => _canCreateCenso;

  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;
    // _canCreateCenso = await PermissionsService.hasPermission('CrearCensoActivo'); -> SIMPLIFICADO
    await cargarEquipos();
  }

  Future<void> cargarEquipos() async {
    _updateState(_state.copyWith(isLoading: true, errorMessage: null));

    try {
      if (_cliente?.id == null) {
        _setEquiposVacios();
        return;
      }

      final equiposAsignadosList = await _equipoRepository
          .obtenerEquiposAsignados(_cliente!.id!);
      final equiposPendientesList = await _equipoPendienteRepository
          .obtenerEquiposPendientesPorCliente(_cliente!.id!);

      _updateState(
        _state.copyWith(
          isLoading: false,
          equiposAsignadosList: equiposAsignadosList,
          equiposPendientesList: equiposPendientesList,
        ),
      );
    } catch (e, stackTrace) {
      _updateState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Error cargando equipos: ${e.toString()}',
        ),
      );

      _eventController.add(
        ShowErrorEvent('Error cargando equipos: ${e.toString()}'),
      );
    }
  }

  void _setEquiposVacios() {
    _updateState(
      _state.copyWith(
        isLoading: false,
        equiposAsignadosList: [],
        equiposPendientesList: [],
      ),
    );
  }

  Future<void> refresh() async {
    await cargarEquipos();
    _eventController.add(RefreshCompletedEvent());
  }

  void navegarAAsignarEquipo() {
    if (_cliente != null) {
      _eventController.add(NavigateToFormsEvent(_cliente!));
    }
  }

  void navegarADetalleEquipo(Map<String, dynamic> equipoData) {
    bool isAsignado = _state.equiposAsignadosList.any(
      (e) => e['id'] == equipoData['id'],
    );

    final equipoDataWithType = {
      ...equipoData,
      'tipo_estado': isAsignado ? 'asignado' : 'pendiente',
    };

    _eventController.add(NavigateToEquipoDetailEvent(equipoDataWithType));
  }

  void onNavigationResult(bool? result) {
    if (result == true) {
      cargarEquipos();
    }
  }

  String getNombreCliente() {
    return _cliente?.nombre ?? 'Cliente no especificado';
  }

  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  String getEquipoTitle(Map<String, dynamic> equipoData) {
    final marca = equipoData['marca_nombre'] ?? 'Sin marca';
    final modelo = equipoData['modelo_nombre'] ?? 'Sin modelo';
    return '$marca $modelo';
  }

  String? getEquipoBarcode(Map<String, dynamic> equipoData) {
    final barcode = equipoData['cod_barras']?.toString();
    return barcode?.isNotEmpty == true ? barcode : null;
  }

  String? getEquipoLogo(Map<String, dynamic> equipoData) {
    final logo = equipoData['logo_nombre']?.toString();
    return logo?.isNotEmpty == true ? logo : null;
  }

  String? getEquipoNumeroSerie(Map<String, dynamic> equipoData) {
    final numeroSerie = equipoData['numero_serie']?.toString();
    return numeroSerie?.isNotEmpty == true ? numeroSerie : null;
  }

  String getEquipoFechaCensado(Map<String, dynamic> equipoData) {
    final fechaStr =
        equipoData['fecha_revision'] ??
        equipoData['censo_fecha_creacion'] ??
        equipoData['censo_fecha_actualizacion'];

    if (fechaStr != null) {
      try {
        final fecha = DateTime.parse(fechaStr).toLocal();
        return 'Censado: ${formatearFecha(fecha)}';
      } catch (e) {}
    }
    return 'Fecha no disponible';
  }

  String getEquipoEstado(Map<String, dynamic> equipoData) {
    return equipoData['estado']?.toString() ?? 'Sin estado';
  }

  bool isEquipoDisponible(Map<String, dynamic> equipoData) {
    final clienteId = equipoData['cliente_id']?.toString();
    return clienteId == null || clienteId.isEmpty || clienteId == '0';
  }

  String getEstadoColor(Map<String, dynamic> equipoData) {
    final estado = equipoData['estado']?.toString().toLowerCase();
    switch (estado) {
      case 'asignado':
        return '#4CAF50';
      case 'pendiente':
        return '#FF9800';
      case 'disponible':
        return '#2196F3';
      default:
        return '#9E9E9E';
    }
  }

  String getEstadoIcon(Map<String, dynamic> equipoData) {
    final estado = equipoData['estado']?.toString().toLowerCase();
    switch (estado) {
      case 'asignado':
        return 'check_circle';
      case 'pendiente':
        return 'schedule';
      case 'disponible':
        return 'radio_button_unchecked';
      default:
        return 'help';
    }
  }

  Future<Map<String, dynamic>?> getEstadoCensoInfo(
    Map<String, dynamic> equipoData,
  ) async {
    try {
      final clienteId = int.tryParse(_cliente?.id?.toString() ?? '');
      if (clienteId == null) {
        return null;
      }

      final tipoEstado =
          equipoData['tipo_estado']?.toString() ??
          equipoData['estado']?.toString();

      Map<String, dynamic>? resultado;

      if (tipoEstado == 'pendiente') {
        final equipoId =
            equipoData['equipo_id']?.toString() ?? equipoData['id']?.toString();

        if (equipoId != null && equipoId.isNotEmpty) {
          final ultimoEstado = await _estadoEquipoRepository
              .obtenerUltimoEstado(equipoId, clienteId);
          resultado = ultimoEstado?.toMap();
        }
      } else if (tipoEstado == 'asignado') {
        final equipoId =
            equipoData['equipo_id']?.toString() ?? equipoData['id']?.toString();
        if (equipoId != null) {
          final historial = await _estadoEquipoRepository
              .obtenerHistorialDirectoPorEquipoCliente(equipoId, clienteId);
          if (historial.isNotEmpty) {
            resultado = historial.first.toMap();
          }
        }
      }

      return resultado;
    } catch (e) {
      return null;
    }
  }

  bool shouldShowCliente() => _cliente?.nombre.isNotEmpty == true;
  bool shouldShowPhone() => _cliente?.telefono?.isNotEmpty == true;
  bool shouldShowAddress() => _cliente?.direccion?.isNotEmpty == true;
  String getClientePhone() => _cliente?.telefono ?? '';
  String getClienteAddress() => _cliente?.direccion ?? '';

  String getEmptyStateTitle() => 'Sin equipos censados';
  String getEmptyStateSubtitle() =>
      'Este cliente no tiene equipos censados actualmente';
  String getErrorStateTitle() => 'Error al cargar equipos';
  String getLoadingMessage() => 'Cargando equipos...';

  void _updateState(ClienteDetailState newState) {
    _state = newState;
    notifyListeners();
  }

  String getTabAsignadosTitle() {
    return tieneEquiposAsignados
        ? 'Asignados ($equiposAsignadosCount)'
        : 'Asignados';
  }

  String getTabPendientesTitle() {
    return tieneEquiposPendientes
        ? 'Pendientes ($equiposPendientesCount)'
        : 'Pendientes';
  }

  bool shouldShowTabLoading() => isLoading;

  bool shouldShowEmptyAsignados() =>
      !isLoading && !hasError && equiposAsignadosCount == 0;

  bool shouldShowEmptyPendientes() =>
      !isLoading && !hasError && equiposPendientesCount == 0;
}

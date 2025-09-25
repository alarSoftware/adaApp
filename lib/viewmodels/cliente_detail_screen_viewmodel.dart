// viewmodels/cliente_detail_screen_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/cliente.dart';
import '../models/equipos.dart';
import '../repositories/equipo_repository.dart';
import '../repositories/equipo_pendiente_repository.dart'; // AGREGAR: Repository para equipos pendientes
import '../repositories/estado_equipo_repository.dart';
import 'package:ada_app/models/estado_equipo.dart';

// ========== EVENTOS PARA LA UI ==========
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

// ========== ESTADO PURO - CORREGIDO ==========
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
      equiposPendientesList: equiposPendientesList ?? this.equiposPendientesList,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isEmpty => equiposAsignadosList.isEmpty && equiposPendientesList.isEmpty && !isLoading && !hasError;

  int get equiposAsignadosCount => equiposAsignadosList.length;
  int get equiposPendientesCount => equiposPendientesList.length;
  int get totalEquiposCount => equiposAsignadosList.length + equiposPendientesList.length;

  bool get tieneEquiposAsignados => equiposAsignadosList.isNotEmpty;
  bool get tieneEquiposPendientes => equiposPendientesList.isNotEmpty;

  // Lista combinada para compatibilidad con código existente
  List<Map<String, dynamic>> get equiposCompletos => [...equiposAsignadosList, ...equiposPendientesList];
}

// ========== VIEWMODEL CORREGIDO ==========
class ClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EquipoRepository _equipoRepository = EquipoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository(); // AGREGAR
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();

  // ========== ESTADO INTERNO ==========
  ClienteDetailState _state = ClienteDetailState();
  Cliente? _cliente;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<ClienteDetailUIEvent> _eventController =
  StreamController<ClienteDetailUIEvent>.broadcast();
  Stream<ClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== GETTERS PÚBLICOS ==========
  ClienteDetailState get state => _state;
  bool get isLoading => _state.isLoading;
  List<Map<String, dynamic>> get equiposAsignadosList => _state.equiposAsignadosList;
  List<Map<String, dynamic>> get equiposPendientesList => _state.equiposPendientesList;
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

  // ========== INICIALIZACIÓN ==========
  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;
    await cargarEquipos();
  }

  // ========== CARGA DE DATOS - CORREGIDO ==========
  Future<void> cargarEquipos() async {
    _updateState(_state.copyWith(
      isLoading: true,
      errorMessage: null,
    ));

    try {
      if (_cliente?.id == null) {
        _setEquiposVacios();
        return;
      }

      _logger.i('Cargando equipos para cliente: ${_cliente!.id}');

      // CORREGIDO: Usar los repositories correctos
      final equiposAsignadosList = await _equipoRepository.obtenerEquiposAsignados(_cliente!.id!);
      final equiposPendientesList = await _equipoPendienteRepository.obtenerEquiposPendientesPorCliente(_cliente!.id!);

      // DEBUG LOGS
      _logger.i('=== DEBUG SEPARACIÓN ===');
      _logger.i('Equipos ASIGNADOS obtenidos: ${equiposAsignadosList.length}');
      equiposAsignadosList.forEach((eq) => _logger.i('  - Asignado: ${eq['cod_barras']} | Estado: ${eq['estado']}'));

      _logger.i('Equipos PENDIENTES obtenidos: ${equiposPendientesList.length}');
      equiposPendientesList.forEach((eq) => _logger.i('  - Pendiente: ${eq['cod_barras']} | Estado: ${eq['estado']}'));

      _updateState(_state.copyWith(
        isLoading: false,
        equiposAsignadosList: equiposAsignadosList,
        equiposPendientesList: equiposPendientesList,
      ));

      _logger.i('✅ Equipos cargados exitosamente');
      _logger.i('Total: ${totalEquiposCount}, Asignados: ${equiposAsignadosCount}, Pendientes: ${equiposPendientesCount}');

    } catch (e, stackTrace) {
      _logger.e('❌ Error cargando equipos del cliente', error: e, stackTrace: stackTrace);

      _updateState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Error cargando equipos: ${e.toString()}',
      ));

      _eventController.add(ShowErrorEvent('Error cargando equipos: ${e.toString()}'));
    }
  }

  void _setEquiposVacios() {
    _updateState(_state.copyWith(
      isLoading: false,
      equiposAsignadosList: [],
      equiposPendientesList: [],
    ));
  }

  // ========== MÉTODOS DE NAVEGACIÓN ==========
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
    // CORRECCIÓN: Determinar si es asignado basándose en la lista de origen
    bool isAsignado = _state.equiposAsignadosList.any((e) => e['id'] == equipoData['id']);

    // Agregar el tipo_estado al equipoData
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

  // ========== UTILIDADES PARA LA UI ==========
  String getNombreCliente() {
    return _cliente?.nombre ?? 'Cliente no especificado';
  }

  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
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
    // Para equipos pendientes: usar fecha_censo
    final fechaStr = equipoData['fecha_censo'] ?? equipoData['fecha_creacion'] ?? equipoData['fecha_actualizacion'];
    if (fechaStr != null) {
      try {
        final fecha = DateTime.parse(fechaStr);
        return 'Censado: ${formatearFecha(fecha)}';
      } catch (e) {
        _logger.w('Error parseando fecha: $fechaStr');
      }
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
        return '#4CAF50'; // Verde
      case 'pendiente':
        return '#FF9800'; // Naranja
      case 'disponible':
        return '#2196F3'; // Azul
      case 'mantenimiento':
        return '#F44336'; // Rojo
      default:
        return '#9E9E9E'; // Gris
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
      case 'mantenimiento':
        return 'build';
      default:
        return 'help';
    }
  }

  // ========== MÉTODOS PARA OBTENER ESTADO DE CENSO ==========
  Future<Map<String, dynamic>?> getEstadoCensoInfo(Map<String, dynamic> equipoData) async {
    try {
      final equipoId = int.tryParse(equipoData['id']?.toString() ?? '');
      final clienteId = int.tryParse(_cliente?.id?.toString() ?? '');

      if (equipoId == null || clienteId == null) return null;

      final estado = equipoData['estado']?.toString().toLowerCase();

      if (estado == 'pendiente') {
        // Para equipos pendientes, usar el método que existe
        final ultimoEstado = await _estadoEquipoRepository.obtenerUltimoEstadoPorEquipoPendiente(equipoId);
        return ultimoEstado;
      } else if (estado == 'asignado') {
        // CAMBIO: Para equipos asignados, usar el método correcto que consulta por equipo_id y cliente_id
        final ultimoEstado = await _estadoEquipoRepository.obtenerHistorialDirectoPorEquipoCliente(equipoId.toString(), clienteId);
        return ultimoEstado.isNotEmpty ? ultimoEstado.first.toMap() : null;
      }

      return null;
    } catch (e) {
      _logger.e('Error obteniendo estado censo: $e');
      return null;
    }
  }

  // ========== MÉTODOS DE INFORMACIÓN DEL CLIENTE ==========
  bool shouldShowCliente() => _cliente?.nombre.isNotEmpty == true;
  bool shouldShowPhone() => _cliente?.telefono?.isNotEmpty == true;
  bool shouldShowAddress() => _cliente?.direccion?.isNotEmpty == true;
  String getClientePhone() => _cliente?.telefono ?? '';
  String getClienteAddress() => _cliente?.direccion ?? '';

  // ========== MÉTODOS PARA EMPTY STATES ==========
  String getEmptyStateTitle() => 'Sin equipos censados';
  String getEmptyStateSubtitle() => 'Este cliente no tiene equipos censados actualmente';
  String getErrorStateTitle() => 'Error al cargar equipos';
  String getLoadingMessage() => 'Cargando equipos...';

  // ========== HELPER PRIVADO ==========
  void _updateState(ClienteDetailState newState) {
    _state = newState;
    notifyListeners();
  }

  // ========== MÉTODOS ESPECÍFICOS PARA TABS ==========

  /// Obtener título del tab de equipos asignados
  String getTabAsignadosTitle() {
    return tieneEquiposAsignados
        ? 'Asignados ($equiposAsignadosCount)'
        : 'Asignados';
  }

  /// Obtener título del tab de equipos pendientes
  String getTabPendientesTitle() {
    return tieneEquiposPendientes
        ? 'Pendientes ($equiposPendientesCount)'
        : 'Pendientes';
  }

  /// Verificar si se debe mostrar el indicador de carga en el tab
  bool shouldShowTabLoading() => isLoading;

  /// Verificar si se debe mostrar el empty state para asignados
  bool shouldShowEmptyAsignados() => !isLoading && !hasError && equiposAsignadosCount == 0;

  /// Verificar si se debe mostrar el empty state para pendientes
  bool shouldShowEmptyPendientes() => !isLoading && !hasError && equiposPendientesCount == 0;
}
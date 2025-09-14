// viewmodels/cliente_detail_screen_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/cliente.dart';
import '../models/equipos_cliente.dart';
import '../repositories/equipo_cliente_repository.dart';
import '../repositories/estado_equipo_repository.dart'; // AGREGAR IMPORT
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
  final EquipoCliente equipoCliente;
  NavigateToEquipoDetailEvent(this.equipoCliente);
}

class RefreshCompletedEvent extends ClienteDetailUIEvent {}

// ========== ESTADO PURO - ACTUALIZADO ==========
class ClienteDetailState {
  final bool isLoading;
  final List<Map<String, dynamic>> equiposCompletos; // MANTENER para compatibilidad
  final List<EquipoCliente> equiposAsignados;
  // NUEVAS PROPIEDADES
  final List<Map<String, dynamic>> equiposAsignadosList;
  final List<Map<String, dynamic>> equiposPendientesList;
  final String? errorMessage;

  ClienteDetailState({
    this.isLoading = false,
    this.equiposCompletos = const [],
    this.equiposAsignados = const [],
    this.equiposAsignadosList = const [],
    this.equiposPendientesList = const [],
    this.errorMessage,
  });

  ClienteDetailState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? equiposCompletos,
    List<EquipoCliente>? equiposAsignados,
    List<Map<String, dynamic>>? equiposAsignadosList,
    List<Map<String, dynamic>>? equiposPendientesList,
    String? errorMessage,
  }) {
    return ClienteDetailState(
      isLoading: isLoading ?? this.isLoading,
      equiposCompletos: equiposCompletos ?? this.equiposCompletos,
      equiposAsignados: equiposAsignados ?? this.equiposAsignados,
      equiposAsignadosList: equiposAsignadosList ?? this.equiposAsignadosList,
      equiposPendientesList: equiposPendientesList ?? this.equiposPendientesList,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isEmpty => equiposCompletos.isEmpty && !isLoading && !hasError;
  bool get noTieneEquipos => equiposAsignadosList.isEmpty && equiposPendientesList.isEmpty && !isLoading && !hasError;

  int get equiposCount => equiposCompletos.length;
  int get equiposAsignadosCount => equiposAsignadosList.length;
  int get equiposPendientesCount => equiposPendientesList.length;
  int get totalEquiposCount => equiposAsignadosList.length + equiposPendientesList.length;

  bool get tieneEquiposAsignados => equiposAsignadosList.isNotEmpty;
  bool get tieneEquiposPendientes => equiposPendientesList.isNotEmpty;
}

// ========== VIEWMODEL LIMPIO - ACTUALIZADO ==========
class ClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EquipoClienteRepository _repository = EquipoClienteRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository(); // AGREGAR

  // ========== ESTADO INTERNO ==========
  ClienteDetailState _state = ClienteDetailState();
  Cliente? _cliente;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<ClienteDetailUIEvent> _eventController =
  StreamController<ClienteDetailUIEvent>.broadcast();
  Stream<ClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== GETTERS PÚBLICOS - ACTUALIZADO ==========
  ClienteDetailState get state => _state;
  bool get isLoading => _state.isLoading;
  List<Map<String, dynamic>> get equiposCompletos => _state.equiposCompletos;
  List<EquipoCliente> get equiposAsignados => _state.equiposAsignados;
  // NUEVOS GETTERS
  List<Map<String, dynamic>> get equiposAsignadosList => _state.equiposAsignadosList;
  List<Map<String, dynamic>> get equiposPendientesList => _state.equiposPendientesList;

  String? get errorMessage => _state.errorMessage;
  bool get hasError => _state.hasError;
  bool get isEmpty => _state.isEmpty;
  bool get noTieneEquipos => _state.noTieneEquipos;

  int get equiposCount => _state.equiposCount;
  int get equiposAsignadosCount => _state.equiposAsignadosCount;
  int get equiposPendientesCount => _state.equiposPendientesCount;
  int get totalEquiposCount => _state.totalEquiposCount;

  bool get tieneEquiposAsignados => _state.tieneEquiposAsignados;
  bool get tieneEquiposPendientes => _state.tieneEquiposPendientes;

  Cliente? get cliente => _cliente;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== INICIALIZACIÓN ==========
  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;
    await cargarEquiposAsignados();
  }

  // ========== CARGA DE DATOS - ACTUALIZADO ==========
  Future<void> cargarEquiposAsignados() async {
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

      // USAR LOS NUEVOS MÉTODOS SEPARADOS DEL REPOSITORIO
      final equiposAsignadosList = await _repository.obtenerEquiposAsignados(_cliente!.id!);
      final equiposPendientesList = await _repository.obtenerEquiposPendientes(_cliente!.id!);

      // DEBUG LOGS
      _logger.i('=== DEBUG SEPARACIÓN ===');
      _logger.i('Equipos ASIGNADOS obtenidos: ${equiposAsignadosList.length}');
      equiposAsignadosList.forEach((eq) => _logger.i('  - Asignado: ${eq['equipo_cod_barras']} | Estado: ${eq['estado']}'));

      _logger.i('Equipos PENDIENTES obtenidos: ${equiposPendientesList.length}');
      equiposPendientesList.forEach((eq) => _logger.i('  - Pendiente: ${eq['equipo_cod_barras']} | Estado: ${eq['estado']}'));

      // Combinar ambas listas para compatibilidad con código existente
      final equiposCompletos = [...equiposAsignadosList, ...equiposPendientesList];

      // Convertir a objetos EquipoCliente para compatibilidad
      final equiposAsignados = equiposCompletos.map((equipoData) {
        return EquipoCliente.fromMap(equipoData);
      }).toList();

      _updateState(_state.copyWith(
        isLoading: false,
        equiposCompletos: equiposCompletos,
        equiposAsignados: equiposAsignados,
        equiposAsignadosList: equiposAsignadosList,
        equiposPendientesList: equiposPendientesList,
      ));

      _logger.i('✅ Equipos cargados exitosamente');
      _logger.i('Total: ${equiposCompletos.length}, Asignados: ${equiposAsignadosList.length}, Pendientes: ${equiposPendientesList.length}');

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
      equiposCompletos: [],
      equiposAsignados: [],
      equiposAsignadosList: [],
      equiposPendientesList: [],
    ));
  }

  // ========== RESTO DE MÉTODOS IGUAL ==========
  Future<void> refresh() async {
    await cargarEquiposAsignados();
    _eventController.add(RefreshCompletedEvent());
  }

  void navegarAAsignarEquipo() {
    if (_cliente != null) {
      _eventController.add(NavigateToFormsEvent(_cliente!));
    }
  }

  void navegarADetalleEquipo(Map<String, dynamic> equipoData) {
    final equipoDataCorregido = Map<String, dynamic>.from(equipoData);

    if (equipoData.containsKey('marca_nombre')) {
      equipoDataCorregido['equipo_marca'] = equipoData['marca_nombre'];
    }

    if (equipoData.containsKey('modelo_nombre')) {
      equipoDataCorregido['equipo_modelo'] = equipoData['modelo_nombre'];
    }

    if (equipoData.containsKey('equipo_nombre') && !equipoDataCorregido.containsKey('equipo_nombre')) {
      equipoDataCorregido['equipo_nombre'] = equipoData['equipo_nombre'];
    }

    final equipoCliente = EquipoCliente.fromMap(equipoDataCorregido);
    _eventController.add(NavigateToEquipoDetailEvent(equipoCliente));
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
    final barcode = equipoData['equipo_cod_barras']?.toString();
    return barcode?.isNotEmpty == true ? barcode : null;
  }

  String? getEquipoLogo(Map<String, dynamic> equipoData) {
    final logo = equipoData['logo_nombre']?.toString();
    return logo?.isNotEmpty == true ? logo : null;
  }

  String getEquipoFechaCensado(Map<String, dynamic> equipoData) {
    final fechaStr = equipoData['fecha_asignacion'];
    if (fechaStr != null) {
      final fecha = DateTime.parse(fechaStr);
      return 'Censado: ${formatearFecha(fecha)}';
    }
    return 'Fecha no disponible';
  }

  // Agregar al ClienteDetailScreenViewModel
  Future<Map<String, dynamic>?> getEstadoCensoInfo(Map<String, dynamic> equipoData) async {
    try {
      final equipoClienteId = equipoData['id'] as int?;
      if (equipoClienteId == null) return null;

      // Obtener registros de estado de este equipo
      final registrosEstado = await _estadoEquipoRepository.obtenerPorEquipoCliente(equipoClienteId);

      if (registrosEstado.isEmpty) {
        return null; // No hay registros de censo
      }

      // Contar registros por estado
      final migrados = registrosEstado.where((r) => r.estadoCensoEnum == EstadoEquipoCenso.migrado).length;
      final creados = registrosEstado.where((r) => r.estadoCensoEnum == EstadoEquipoCenso.creado).length;
      final total = registrosEstado.length;

      return {
        'total_registros': total,
        'migrados_count': migrados,
        'pendientes_count': creados,
        'todos_migrados': creados == 0 && migrados > 0,
        'tiene_pendientes': creados > 0,
        'ultimo_estado': registrosEstado.isNotEmpty ? registrosEstado.first.estadoCenso : null,
      };

    } catch (e) {
      _logger.e('Error obteniendo estado censo: $e');
      return null;
    }
  }

  bool shouldShowCliente() => _cliente?.nombre.isNotEmpty == true;
  bool shouldShowPhone() => _cliente?.telefono?.isNotEmpty == true;
  bool shouldShowAddress() => _cliente?.direccion?.isNotEmpty == true;
  String getClientePhone() => _cliente?.telefono ?? '';
  String getClienteAddress() => _cliente?.direccion ?? '';

  String getEmptyStateTitle() => 'Sin equipos censados';
  String getEmptyStateSubtitle() => 'Este cliente no tiene equipos censados actualmente';
  String getErrorStateTitle() => 'Error al cargar equipos';
  String getLoadingMessage() => 'Cargando equipos...';

  void _updateState(ClienteDetailState newState) {
    _state = newState;
    notifyListeners();
  }

  void onNavigationResult(bool? result) {
    if (result == true) {
      cargarEquiposAsignados();
    }
  }
}
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../repositories/estado_equipo_repository.dart';
import '../repositories/equipo_repository.dart';
import '../models/estado_equipo.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

// ========== EVENTOS PARA LA UI ==========
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

// ========== ESTADO PURO ==========
class EquiposClienteDetailState {
  final dynamic equipoCliente;
  final bool isProcessing;
  final bool equipoEnLocal;
  final List<EstadoEquipo> historialCambios;
  final List<EstadoEquipo> historialUltimos5;

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
    this.historialCambios = const [],
    this.historialUltimos5 = const [],
  }) : equipoEnLocal = equipoEnLocal ?? (equipoCliente['estado_local'] == 1);

  EquiposClienteDetailState copyWith({
    dynamic equipoCliente,
    bool? isProcessing,
    bool? equipoEnLocal,
    List<EstadoEquipo>? historialCambios,
    List<EstadoEquipo>? historialUltimos5,
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

// ========== VIEWMODEL LIMPIO ==========
class EquiposClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final EquipoRepository _equipoRepository;
  final LocationService _locationService = LocationService();

  // ========== ESTADO INTERNO ==========
  EquiposClienteDetailState _state;

  // ========== NUEVOS CAMPOS PARA DROPDOWN ==========
  bool? _estadoUbicacionEquipo;
  bool _hasUnsavedChanges = false;
  int _estadoLocalActual; // Variable para mantener el estado actual

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<EquiposClienteDetailUIEvent> _eventController =
  StreamController<EquiposClienteDetailUIEvent>.broadcast();
  Stream<EquiposClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== CONSTRUCTOR ==========
  EquiposClienteDetailScreenViewModel(
      dynamic equipoCliente,
      this._estadoEquipoRepository,
      this._equipoRepository,
      ) : _state = EquiposClienteDetailState(equipoCliente: equipoCliente),
        _estadoLocalActual = equipoCliente['estado_local'] {
    _initializeState();
    _loadInitialState();
    _logDebugInfo();
  }

  // ========== INICIALIZAR ESTADO DEL DROPDOWN ==========
  void _initializeState() {
    // Inicializar con el estado actual del equipo
    _estadoLocalActual = equipoCliente['estado_local'];
    _estadoUbicacionEquipo = _estadoLocalActual == 1;
    _hasUnsavedChanges = false;
  }

  // CARGAR ESTADO INICIAL Y HISTORIAL
  Future<void> _loadInitialState() async {
    try {
      final equipoId = equipoCliente['id'];

      if (equipoId == null) {
        _logger.w('No se encontró ID del equipo');
        return;
      }

      final estadoActual = await _estadoEquipoRepository.obtenerUltimoEstado(equipoId);
      final historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(equipoId);
      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        equipoEnLocal: estadoActual?.enLocal ?? (_estadoLocalActual == 1),
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
      );

      notifyListeners();

      _logger.i('✅ Historial cargado: ${historialCompleto.length} registros totales, mostrando ${ultimos5.length}');

    } catch (e) {
      _logger.e('❌ Error cargando estado inicial: $e');
    }
  }

  // ========== GETTERS PÚBLICOS ==========
  EquiposClienteDetailState get state => _state;
  dynamic get equipoCliente => _state.equipoCliente;
  bool get isProcessing => _state.isProcessing;
  bool get isEquipoActivo => _state.equipoCliente['activo'] == 1;

  // ========== NUEVOS GETTERS PARA DROPDOWN ==========
  bool? get estadoUbicacionEquipo => _estadoUbicacionEquipo;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get saveButtonEnabled => _estadoUbicacionEquipo != null && _hasUnsavedChanges;

  String get saveButtonText {
    if (_estadoUbicacionEquipo == null) return 'Seleccione ubicación';
    if (!_hasUnsavedChanges) return 'Sin cambios';
    return 'Guardar cambios';
  }

  // GETTERS PARA HISTORIAL
  List<EstadoEquipo> get historialUltimos5 => _state.historialUltimos5;
  List<EstadoEquipo> get historialCompleto => _state.historialCambios;
  int get totalCambios => _state.historialCambios.length;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== NUEVO MÉTODO PARA DROPDOWN ==========
  void cambiarUbicacionEquipo(bool? nuevaUbicacion) {
    if (_estadoUbicacionEquipo != nuevaUbicacion) {
      _estadoUbicacionEquipo = nuevaUbicacion;

      final estadoActual = _estadoLocalActual == 1;
      _hasUnsavedChanges = _estadoUbicacionEquipo != estadoActual;

      notifyListeners();
      _logger.i('🔄 Dropdown cambiado a: $nuevaUbicacion (pendiente de guardar)');
    }
  }

  Future<void> toggleEquipoEnLocal(bool value) async {
    cambiarUbicacionEquipo(value);
  }

  Future<void> recargarHistorial() async {
    try {
      _logger.i('🔄 Recargando historial completo...');

      if (equipoCliente['id'] == null) {
        _logger.w('⚠️ equipoCliente id es null, no se puede recargar historial');
        return;
      }

      final historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(
          equipoCliente['id']
      );

      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        historialCambios: historialCompleto,
        historialUltimos5: ultimos5,
      );

      notifyListeners();

      _logger.i('✅ Historial recargado: ${historialCompleto.length} registros');

    } catch (e) {
      _logger.e('❌ Error recargando historial: $e');
    }
  }

  // ========== GUARDAR CAMBIOS ACTUALIZADO CON VALIDACIÓN ==========
  Future<void> saveAllChanges() async {
    if (_estadoUbicacionEquipo == null) {
      _eventController.add(ShowMessageEvent(
        'Debe seleccionar una ubicación para el equipo antes de guardar',
        MessageType.error,
      ));
      return;
    }

    if (!_hasUnsavedChanges) {
      _eventController.add(ShowMessageEvent(
        'No hay cambios para guardar',
        MessageType.info,
      ));
      return;
    }

    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      _logger.i('Guardando cambios: enLocal=$_estadoUbicacionEquipo');

      late final Position position;
      try {
        position = await _locationService.getCurrentLocationRequired(
          timeout: Duration(seconds: 30),
        );

        _logger.i('Ubicación GPS obtenida: ${_locationService.formatCoordinates(position)}');

      } on LocationException catch (e) {
        _state = _state.copyWith(isProcessing: false);
        notifyListeners();

        _eventController.add(ShowMessageEvent(
          'GPS requerido: ${e.message}',
          MessageType.error,
        ));

        return;
      }

      if (equipoCliente['id'] == null) {
        _logger.w('No se puede crear estado: equipoCliente id es null');
        return;
      }

      // Crear registro con GPS obligatorio
      final nuevoEstado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoClienteId: equipoCliente['id'],
        enLocal: _estadoUbicacionEquipo!,
        fechaRevision: DateTime.now(),
        latitud: position.latitude,
        longitud: position.longitude,
      );

      // Actualizar estado_local en la tabla equipos
      await _equipoRepository.dbHelper.actualizar(
          'equipos',
          {'estado_local': _estadoUbicacionEquipo! ? 1 : 0},
          where: 'id = ?',
          whereArgs: [equipoCliente['id']]
      );

      // Actualizar la variable local de estado
      _estadoLocalActual = _estadoUbicacionEquipo! ? 1 : 0;

      // Actualizar estado interno
      _state = _state.copyWith(equipoEnLocal: _estadoUbicacionEquipo!);
      _hasUnsavedChanges = false;

      // Actualizar historial local
      final historialActualizado = [nuevoEstado, ..._state.historialCambios];
      final ultimos5Actualizado = historialActualizado.take(5).toList();

      _state = _state.copyWith(
        equipoEnLocal: _estadoUbicacionEquipo!,
        historialCambios: historialActualizado,
        historialUltimos5: ultimos5Actualizado,
        isProcessing: false,
      );

      notifyListeners();

      _eventController.add(ShowMessageEvent(
        'Cambios guardados con ubicación GPS',
        MessageType.success,
      ));

    } catch (e) {
      _logger.e('Error al guardar cambios: $e');

      _state = _state.copyWith(isProcessing: false);
      notifyListeners();

      _eventController.add(ShowMessageEvent(
        'Error al guardar los cambios: $e',
        MessageType.error,
      ));
    }
  }

  bool canSaveChanges() {
    return _estadoUbicacionEquipo != null && _hasUnsavedChanges;
  }

  void resetChanges() {
    _estadoUbicacionEquipo = _estadoLocalActual == 1;
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
    return '${equipoCliente['marca_nombre'] ?? ''} ${equipoCliente['modelo_nombre'] ?? ''}'.trim();
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

  bool shouldShowFechaRetiro() {
    return false;
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

  String getFechaAsignacionText() {
    final fechaString = equipoCliente['fecha_creacion'];
    if (fechaString == null) return 'No disponible';

    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (e) {
      return 'No disponible';
    }
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
    if (equipoCliente['activo'] != 1) {
      return 'Inactivo';
    }
    if (_estadoLocalActual == 1) {
      return 'Asignado';
    } else {
      return 'Pendiente';
    }
  }

  Map<String, String> getRetireDialogData() {
    return {
      'equipoNombre': getNombreCompletoEquipo(),
      'equipoCodigo': equipoCliente['cod_barras'] ?? 'Sin código',
      'clienteNombre': 'Cliente ID: ${equipoCliente['cliente_id'] ?? "No asignado"}',
    };
  }

  String getInactiveEquipoTitle() {
    return 'Equipo no activo';
  }

  String getInactiveEquipoSubtitle() {
    return 'Este equipo ya no está asignado activamente a este cliente';
  }

  void _logDebugInfo() {
    _logger.i('DEBUG - Equipo Marca: ${equipoCliente['marca_nombre']}');
    _logger.i('DEBUG - Equipo Modelo: ${equipoCliente['modelo_nombre']}');
    _logger.i('DEBUG - Nombre completo calculado: ${getNombreCompletoEquipo()}');
    _logger.i('DEBUG - En local: ${_state.equipoEnLocal}');
    _logger.i('DEBUG - Estado dropdown: $_estadoUbicacionEquipo');
    _logger.i('DEBUG - Estado local actual: $_estadoLocalActual');
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'equipo_id': equipoCliente['id'],
      'cliente_id': equipoCliente['cliente_id'],
      'equipo_marca': equipoCliente['marca_nombre'],
      'equipo_modelo': equipoCliente['modelo_nombre'],
      'codigo_barras': equipoCliente['cod_barras'],
      'activo': equipoCliente['activo'],
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

  void logDebugInfo() {
    _logger.d('EquiposClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}
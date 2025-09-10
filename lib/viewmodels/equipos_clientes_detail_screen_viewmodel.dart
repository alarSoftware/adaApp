import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/equipos_cliente.dart';
import '../repositories/estado_equipo_repository.dart';
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
  final EquipoCliente equipoCliente;
  ShowRetireConfirmationDialogEvent(this.equipoCliente);
}

enum MessageType { error, success, info, warning }

// ========== ESTADO PURO ==========
class EquiposClienteDetailState {
  final EquipoCliente equipoCliente;
  final bool isProcessing;
  final bool equipoEnLocal;
  final List<EstadoEquipo> historialCambios; // Historial completo
  final List<EstadoEquipo> historialUltimos5; // Solo últimos 5 para UI

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
    this.historialCambios = const [],
    this.historialUltimos5 = const [],
  }) : equipoEnLocal = equipoEnLocal ?? (equipoCliente.enLocal ?? false);

  EquiposClienteDetailState copyWith({
    EquipoCliente? equipoCliente,
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
  final LocationService _locationService = LocationService();

  // ========== ESTADO INTERNO ==========
  EquiposClienteDetailState _state;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<EquiposClienteDetailUIEvent> _eventController =
  StreamController<EquiposClienteDetailUIEvent>.broadcast();
  Stream<EquiposClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== CONSTRUCTOR ==========
  EquiposClienteDetailScreenViewModel(
      EquipoCliente equipoCliente,
      this._estadoEquipoRepository,
      ) : _state = EquiposClienteDetailState(equipoCliente: equipoCliente) {
    _loadInitialState();
    _logDebugInfo();
  }

  // CARGAR ESTADO INICIAL Y HISTORIAL
  Future<void> _loadInitialState() async {
    try {
      // Cargar el estado más reciente
      final estadoActual = await _estadoEquipoRepository.obtenerPorEquipoYCliente(
          equipoCliente.equipoId,
          equipoCliente.clienteId
      );

      // Cargar TODOS los registros de historial
      final historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(
          equipoCliente.equipoId,
          equipoCliente.clienteId
      );

      // Tomar solo los últimos 5 para la UI
      final ultimos5 = historialCompleto.take(5).toList();

      _state = _state.copyWith(
        equipoEnLocal: estadoActual?.enLocal ?? false,
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
  EquipoCliente get equipoCliente => _state.equipoCliente;
  bool get isProcessing => _state.isProcessing;
  bool get isEquipoActivo => _state.equipoCliente.asignacionActiva;

  // 🆕 GETTERS PARA HISTORIAL
  List<EstadoEquipo> get historialUltimos5 => _state.historialUltimos5;
  List<EstadoEquipo> get historialCompleto => _state.historialCambios;
  int get totalCambios => _state.historialCambios.length;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== CAMBIO DE ESTADO ==========

  Future<void> toggleEquipoEnLocal(bool value) async {
    _state = _state.copyWith(equipoEnLocal: value);
    notifyListeners();

    _logger.i('🔄 Switch cambiado a: $value (pendiente de guardar)');
  }

  // 🆕 MÉTODO PARA RECARGAR HISTORIAL COMPLETO
  Future<void> recargarHistorial() async {
    try {
      _logger.i('🔄 Recargando historial completo...');

      final historialCompleto = await _estadoEquipoRepository.obtenerHistorialCompleto(
          equipoCliente.equipoId,
          equipoCliente.clienteId
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

  // ========== GUARDAR CAMBIOS - IMPLEMENTACIÓN REAL CON GPS ==========

  Future<void> saveAllChanges() async {
    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      _logger.i('Guardando cambios: enLocal=${_state.equipoEnLocal}');

      // GPS OBLIGATORIO
      late final Position position;
      try {
        position = await _locationService.getCurrentLocationRequired(
          timeout: Duration(seconds: 15),
        );

        _logger.i('Ubicación GPS obtenida: ${_locationService.formatCoordinates(position)}');

      } on LocationException catch (e) {
        _state = _state.copyWith(isProcessing: false);
        notifyListeners();

        _eventController.add(ShowMessageEvent(
          'GPS requerido: ${e.message}',
          MessageType.error,
        ));

        return; // No continuar sin GPS
      }

      // Crear registro con GPS obligatorio
      final nuevoEstado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoId: equipoCliente.equipoId,
        clienteId: equipoCliente.clienteId,
        enLocal: _state.equipoEnLocal,
        fechaRevision: DateTime.now(),
        latitud: position.latitude,
        longitud: position.longitude,
      );

      // Actualizar historial local
      final historialActualizado = [nuevoEstado, ..._state.historialCambios];
      final ultimos5Actualizado = historialActualizado.take(5).toList();

      _state = _state.copyWith(
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
        'Error al guardar los cambios',
        MessageType.error,
      ));
    }
  }

  // ========== GETTERS PARA ESTADO LOCAL ==========

  bool get isEquipoEnLocal {
    return _state.equipoEnLocal;
  }

  // ========== UTILIDADES PARA LA UI ==========

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

  // 🆕 FORMATEO ESPECÍFICO PARA HISTORIAL
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
    return equipoCliente.equipoNombreCompleto;
  }

  // ========== INFORMACIÓN DEL EQUIPO ==========

  bool shouldShowMarca() {
    return equipoCliente.equipoMarca != null &&
        equipoCliente.equipoMarca!.isNotEmpty;
  }

  bool shouldShowModelo() {
    return equipoCliente.equipoModelo != null &&
        equipoCliente.equipoModelo!.isNotEmpty;
  }

  bool shouldShowCodBarras() {
    return equipoCliente.equipoCodBarras != null &&
        equipoCliente.equipoCodBarras!.isNotEmpty;
  }

  bool shouldShowFechaRetiro() {
    return equipoCliente.fechaRetiro != null;
  }

  String getMarcaText() {
    return equipoCliente.equipoMarca ?? '';
  }

  String getModeloText() {
    return equipoCliente.equipoModelo ?? '';
  }

  String getCodBarrasText() {
    return equipoCliente.equipoCodBarras ?? '';
  }

  String getFechaAsignacionText() {
    final fecha = equipoCliente.fechaAsignacion;
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String getTiempoAsignadoText() {
    return '${equipoCliente.diasDesdeAsignacion} días';
  }

  String getFechaRetiroText() {
    return equipoCliente.fechaRetiro != null
        ? formatearFechaHora(equipoCliente.fechaRetiro!)
        : '';
  }

  String getEstadoText() {
    return equipoCliente.estadoTexto;
  }

  // ========== DATOS PARA DIÁLOGO DE CONFIRMACIÓN ==========

  Map<String, String> getRetireDialogData() {
    return {
      'equipoNombre': equipoCliente.equipoNombreCompleto,
      'equipoCodigo': equipoCliente.equipoCodBarras ?? 'Sin código',
      'clienteNombre': equipoCliente.clienteNombreCompleto,
    };
  }

  // ========== MENSAJES PREDEFINIDOS ==========

  String getInactiveEquipoTitle() {
    return 'Equipo no activo';
  }

  String getInactiveEquipoSubtitle() {
    return 'Este equipo ya no está asignado activamente a este cliente';
  }

  // ========== MÉTODO PRIVADO ==========

  void _logDebugInfo() {
    _logger.i('DEBUG - Equipo Marca: ${equipoCliente.equipoMarca}');
    _logger.i('DEBUG - Equipo Modelo: ${equipoCliente.equipoModelo}');
    _logger.i('DEBUG - Equipo Nombre: ${equipoCliente.equipoNombre}');
    _logger.i('DEBUG - Nombre completo calculado: ${equipoCliente.equipoNombreCompleto}');
    _logger.i('DEBUG - En local: ${_state.equipoEnLocal}');
  }

  // ========== DEBUG INFO ==========

  Map<String, dynamic> getDebugInfo() {
    return {
      'equipo_id': equipoCliente.equipoId,
      'cliente_id': equipoCliente.clienteId,
      'equipo_marca': equipoCliente.equipoMarca,
      'equipo_modelo': equipoCliente.equipoModelo,
      'equipo_nombre': equipoCliente.equipoNombre,
      'codigo_barras': equipoCliente.equipoCodBarras,
      'asignacion_activa': equipoCliente.asignacionActiva,
      'cliente_nombre': equipoCliente.clienteNombreCompleto,
      'is_processing': _state.isProcessing,
      'equipo_en_local': _state.equipoEnLocal,
      'total_cambios_historial': _state.historialCambios.length,
      'ultimos_5_cambios': _state.historialUltimos5.length,
    };
  }

  void logDebugInfo() {
    _logger.d('EquiposClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}
// viewmodels/equipos_cliente_detail_screen_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/equipos_cliente.dart';

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

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
  });

  EquiposClienteDetailState copyWith({
    EquipoCliente? equipoCliente,
    bool? isProcessing,
  }) {
    return EquiposClienteDetailState(
      equipoCliente: equipoCliente ?? this.equipoCliente,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

// ========== VIEWMODEL LIMPIO ==========
class EquiposClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();

  // ========== ESTADO INTERNO ==========
  EquiposClienteDetailState _state;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<EquiposClienteDetailUIEvent> _eventController =
  StreamController<EquiposClienteDetailUIEvent>.broadcast();
  Stream<EquiposClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== CONSTRUCTOR ==========
  EquiposClienteDetailScreenViewModel(EquipoCliente equipoCliente)
      : _state = EquiposClienteDetailState(equipoCliente: equipoCliente) {
    _logDebugInfo();
  }

  // ========== GETTERS PÚBLICOS ==========
  EquiposClienteDetailState get state => _state;
  EquipoCliente get equipoCliente => _state.equipoCliente;
  bool get isProcessing => _state.isProcessing;
  bool get isEquipoActivo => _state.equipoCliente.asignacionActiva;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== ACCIONES PRINCIPALES ==========

  Future<void> verificarEquipo() async {
    if (equipoCliente.equipoCodBarras?.isNotEmpty == true) {
      // TODO: Implementar navegación a pantalla de cámara para verificar
      _eventController.add(ShowMessageEvent(
        'Verificando equipo ${equipoCliente.equipoCodBarras}',
        MessageType.info,
      ));
      _logger.i('Verificando equipo: ${equipoCliente.equipoCodBarras}');
    } else {
      _eventController.add(ShowMessageEvent(
        'No hay código de barras para verificar',
        MessageType.error,
      ));
    }
  }

  Future<void> reportarEstado() async {
    _setProcessing(true);

    try {
      // TODO: Implementar lógica real de reporte de estado
      await Future.delayed(Duration(milliseconds: 500)); // Simular operación

      _eventController.add(ShowMessageEvent(
        'Reportando estado del equipo...',
        MessageType.warning,
      ));

      _logger.i('Reportando estado del equipo: ${equipoCliente.id}');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> cambiarCliente() async {
    _setProcessing(true);

    try {
      // TODO: Implementar lógica real de cambio de cliente
      await Future.delayed(Duration(milliseconds: 500)); // Simular operación

      _eventController.add(ShowMessageEvent(
        'Función de cambio de cliente...',
        MessageType.info,
      ));

      _logger.i('Cambiando cliente del equipo: ${equipoCliente.id}');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> solicitarRetiroEquipo() async {
    _eventController.add(ShowRetireConfirmationDialogEvent(equipoCliente));
  }

  Future<void> confirmarRetiroEquipo() async {
    _setProcessing(true);

    try {
      // TODO: Implementar lógica real de retiro
      await Future.delayed(Duration(seconds: 1)); // Simular operación

      _eventController.add(ShowMessageEvent(
        'Retirando equipo...',
        MessageType.error,
      ));

      _logger.i('Retirando equipo: ${equipoCliente.id}');

      // En una implementación real, aquí actualizarías el estado del equipo
      // y notificarías el cambio
    } catch (e) {
      _eventController.add(ShowMessageEvent(
        'Error al retirar equipo: $e',
        MessageType.error,
      ));
    } finally {
      _setProcessing(false);
    }
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

  String getNombreCompletoEquipo() {
    final marca = equipoCliente.equipoMarca ?? 'Sin marca';
    final modelo = equipoCliente.equipoModelo ?? 'Sin modelo';
    return '$marca $modelo';
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
    return formatearFechaHora(equipoCliente.fechaAsignacion);
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
      'equipoNombre': getNombreCompletoEquipo(),
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

  void _setProcessing(bool processing) {
    _state = _state.copyWith(isProcessing: processing);
    notifyListeners();
  }

  void _logDebugInfo() {
    _logger.i('DEBUG - Marca: ${equipoCliente.equipoMarca}');
    _logger.i('DEBUG - Modelo: ${equipoCliente.equipoModelo}');
    _logger.i('DEBUG - Nombre completo: ${equipoCliente.equipoNombreCompleto}');
  }

  // ========== DEBUG INFO ==========

  Map<String, dynamic> getDebugInfo() {
    return {
      'equipo_id': equipoCliente.id,
      'equipo_marca': equipoCliente.equipoMarca,
      'equipo_modelo': equipoCliente.equipoModelo,
      'codigo_barras': equipoCliente.equipoCodBarras,
      'asignacion_activa': equipoCliente.asignacionActiva,
      'cliente_nombre': equipoCliente.clienteNombreCompleto,
      'is_processing': _state.isProcessing,
    };
  }

  void logDebugInfo() {
    _logger.d('EquiposClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}
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
  final bool equipoEnLocal;

  EquiposClienteDetailState({
    required this.equipoCliente,
    this.isProcessing = false,
    bool? equipoEnLocal,
  }) : equipoEnLocal = equipoEnLocal ?? (equipoCliente.enLocal ?? false);

  EquiposClienteDetailState copyWith({
    EquipoCliente? equipoCliente,
    bool? isProcessing,
    bool? equipoEnLocal,
  }) {
    return EquiposClienteDetailState(
      equipoCliente: equipoCliente ?? this.equipoCliente,
      isProcessing: isProcessing ?? this.isProcessing,
      equipoEnLocal: equipoEnLocal ?? this.equipoEnLocal,
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
    // Usar el getter del modelo que ya maneja esta lógica correctamente
    return equipoCliente.equipoNombreCompleto;
  }

  // ========== ESTADO DEL EQUIPO EN LOCAL ==========

  bool get isEquipoEnLocal {
    return _state.equipoEnLocal;
  }


  Future<void> toggleEquipoEnLocal(bool value) async {
    // Actualizar el estado local inmediatamente para mejor UX
    _state = _state.copyWith(equipoEnLocal: value);
    notifyListeners();

    try {
      _logger.i('Cambiando estado de equipo en local: $value para equipo ${equipoCliente.id}');

      // TODO: Aquí deberías implementar la llamada real a tu servicio/API
      // Ejemplo de cómo podría ser:
      // await _equiposService.updateEquipoEnLocal(equipoCliente.id, value);

      // Simular una operación asíncrona
      await Future.delayed(Duration(milliseconds: 300));

      // Si la operación es exitosa, mostrar mensaje de confirmación
      _eventController.add(ShowMessageEvent(
        value
            ? 'Equipo marcado como presente en el local'
            : 'Equipo marcado como no presente en el local',
        MessageType.success,
      ));

      // En una implementación real, aquí actualizarías el objeto equipoCliente
      // con los datos actualizados del servidor
      // final updatedEquipo = await _equiposService.getEquipoById(equipoCliente.id);
      // _state = _state.copyWith(equipoCliente: updatedEquipo);
      // notifyListeners();

    } catch (e) {
      _logger.e('Error al cambiar estado del equipo en local: $e');

      // Si hay error, revertir el estado local
      _state = _state.copyWith(equipoEnLocal: !value);
      notifyListeners();

      _eventController.add(ShowMessageEvent(
        'Error al actualizar el estado del equipo',
        MessageType.error,
      ));
    }
  }

  Future<void> saveAllChanges() async {
    _state = _state.copyWith(isProcessing: true);
    notifyListeners();

    try {
      // Aquí implementas la llamada real a tu API/servicio
      // await _equiposService.updateEquipoEnLocal(equipoCliente.id, _state.equipoEnLocal);

      // Por ahora simular
      await Future.delayed(Duration(milliseconds: 500));

      _eventController.add(ShowMessageEvent(
        'Todos los cambios guardados correctamente',
        MessageType.success,
      ));

    } catch (e) {
      _logger.e('Error al guardar cambios: $e');
      _eventController.add(ShowMessageEvent(
        'Error al guardar los cambios',
        MessageType.error,
      ));
    } finally {
      _state = _state.copyWith(isProcessing: false);
      notifyListeners();
    }
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
    };
  }

  void logDebugInfo() {
    _logger.d('EquiposClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}
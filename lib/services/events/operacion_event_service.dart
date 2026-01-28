import 'package:flutter/foundation.dart';
import 'dart:async';

/// Tipos de eventos de operaciones
enum OperacionEventType { created, updated, deleted, syncStatusChanged }

/// Evento de operación
class OperacionEvent {
  final OperacionEventType type;
  final String? operacionId;
  final String? newStatus;

  OperacionEvent({required this.type, this.operacionId, this.newStatus});
}

/// Servicio singleton para eventos de operaciones en tiempo real
class OperacionEventService {
  static final OperacionEventService _instance =
      OperacionEventService._internal();
  factory OperacionEventService() => _instance;

  OperacionEventService._internal();

  // Stream controller para eventos
  final _eventController = StreamController<OperacionEvent>.broadcast();

  /// Stream de eventos de operaciones
  Stream<OperacionEvent> get eventos => _eventController.stream;

  /// Notificar que una operación fue creada
  void notificarCreacion(String operacionId) {
    _eventController.add(
      OperacionEvent(
        type: OperacionEventType.created,
        operacionId: operacionId,
      ),
    );
    debugPrint('📢 [EVENT] Evento emitido: created ID: $operacionId');
  }

  /// Notificar que una operación fue actualizada
  void notificarActualizacion(String operacionId) {
    _eventController.add(
      OperacionEvent(
        type: OperacionEventType.updated,
        operacionId: operacionId,
      ),
    );
    debugPrint('📢 [EVENT] Evento emitido: updated ID: $operacionId');
  }

  /// Notificar que el estado de sincronización cambió
  void notificarCambioEstado(String operacionId, String nuevoEstado) {
    _eventController.add(
      OperacionEvent(
        type: OperacionEventType.syncStatusChanged,
        operacionId: operacionId,
        newStatus: nuevoEstado,
      ),
    );
    debugPrint(
      '📢 [EVENT] Evento emitido: syncStatusChanged ID: $operacionId Status: $nuevoEstado',
    );
  }

  /// Notificar que una operación fue eliminada
  void notificarEliminacion(String operacionId) {
    _eventController.add(
      OperacionEvent(
        type: OperacionEventType.deleted,
        operacionId: operacionId,
      ),
    );
  }

  /// Cerrar el stream controller (llamar al cerrar la app)
  void dispose() {
    _eventController.close();
  }
}

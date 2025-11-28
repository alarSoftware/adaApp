// lib/models/operaciones_comerciales/enums/estado_operacion.dart
enum EstadoOperacion {
  borrador,
  pendiente,
  enviado,
  sincronizado,
  error,
}

extension EstadoOperacionExtension on EstadoOperacion {
  String get valor {
    switch (this) {
      case EstadoOperacion.borrador:
        return 'borrador';
      case EstadoOperacion.pendiente:
        return 'pendiente';
      case EstadoOperacion.enviado:
        return 'enviado';
      case EstadoOperacion.sincronizado:
        return 'sincronizado';
      case EstadoOperacion.error:
        return 'error';
    }
  }

  String get displayName {
    switch (this) {
      case EstadoOperacion.borrador:
        return 'Borrador';
      case EstadoOperacion.pendiente:
        return 'Pendiente';
      case EstadoOperacion.enviado:
        return 'Enviado';
      case EstadoOperacion.sincronizado:
        return 'Sincronizado';
      case EstadoOperacion.error:
        return 'Error';
    }
  }

  static EstadoOperacion fromString(String? estado) {
    if (estado == null) return EstadoOperacion.borrador;

    switch (estado.toLowerCase()) {
      case 'borrador':
        return EstadoOperacion.borrador;
      case 'pendiente':
        return EstadoOperacion.pendiente;
      case 'enviado':
        return EstadoOperacion.enviado;
      case 'sincronizado':
        return EstadoOperacion.sincronizado;
      case 'error':
        return EstadoOperacion.error;
      default:
        return EstadoOperacion.borrador;
    }
  }
}
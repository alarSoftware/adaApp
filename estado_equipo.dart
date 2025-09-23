enum EstadoEquipoCenso {
  creado,
  migrado,
  error,
}

extension EstadoEquipoCensoExtension on EstadoEquipoCenso {
  String get valor {
    switch (this) {
      case EstadoEquipoCenso.creado:
        return 'creado';
      case EstadoEquipoCenso.migrado:
        return 'migrado';
      case EstadoEquipoCenso.error:
        return 'error';
    }
  }

  static EstadoEquipoCenso fromString(String? estado) {
    if (estado == null) return EstadoEquipoCenso.creado;

    switch (estado.toLowerCase()) {
      case 'creado':
        return EstadoEquipoCenso.creado;
      case 'migrado':
        return EstadoEquipoCenso.migrado;
      case 'error':
        return EstadoEquipoCenso.error;
      default:
        return EstadoEquipoCenso.creado;
    }
  }
}

class EstadoEquipo {
  final int? id;
  final int equipoClienteId;
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final DateTime fechaRevision;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;
  final String? estadoCenso;

  // NUEVOS CAMPOS PARA IMAGENES - Solo agregamos estos
  final String? imagenPath;
  final String? imagenBase64;
  final bool tieneImagen;
  final int? imagenTamano;

  EstadoEquipo({
    this.id,
    required this.equipoClienteId,
    required this.enLocal,
    this.latitud,
    this.longitud,
    required this.fechaRevision,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estaSincronizado = false,
    this.estadoCenso,

    // Nuevos parametros opcionales
    this.imagenPath,
    this.imagenBase64,
    this.tieneImagen = false,
    this.imagenTamano,
  });

  factory EstadoEquipo.fromMap(Map<String, dynamic> map) {
    return EstadoEquipo(
      id: map['id'] as int?,
      equipoClienteId: map['equipo_cliente_id'] as int,
      enLocal: (map['en_local'] as int?) == 1,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      fechaRevision: DateTime.parse(map['fecha_revision'] as String),
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      estadoCenso: map['estado_censo'] as String?,

      // Nuevos campos de imagen
      imagenPath: map['imagen_path'] as String?,
      imagenBase64: map['imagen_base64'] as String?,
      tieneImagen: (map['tiene_imagen'] as int? ?? 0) == 1,
      imagenTamano: map['imagen_tamano'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'equipo_cliente_id': equipoClienteId,
      'en_local': enLocal ? 1 : 0,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,

      // Nuevos campos de imagen
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'tiene_imagen': tieneImagen ? 1 : 0,
      'imagen_tamano': imagenTamano,
    };

    if (estadoCenso != null) {
      map['estado_censo'] = estadoCenso;
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_cliente_id': equipoClienteId,
      'en_local': enLocal,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado,
      'estado_censo': estadoCenso,

      // Nuevos campos de imagen para JSON
      'imagen_path': imagenPath,
      'tiene_imagen': tieneImagen,
      'imagen_tamano': imagenTamano,
      // Nota: No incluimos imagen_base64 en JSON para ahorrar espacio
    };
  }

  EstadoEquipo copyWith({
    int? id,
    int? equipoClienteId,
    bool? enLocal,
    double? latitud,
    double? longitud,
    DateTime? fechaRevision,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
    String? estadoCenso,

    // Nuevos parametros para copyWith
    String? imagenPath,
    String? imagenBase64,
    bool? tieneImagen,
    int? imagenTamano,
  }) {
    return EstadoEquipo(
      id: id ?? this.id,
      equipoClienteId: equipoClienteId ?? this.equipoClienteId,
      enLocal: enLocal ?? this.enLocal,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      estadoCenso: estadoCenso ?? this.estadoCenso,

      // Nuevos campos
      imagenPath: imagenPath ?? this.imagenPath,
      imagenBase64: imagenBase64 ?? this.imagenBase64,
      tieneImagen: tieneImagen ?? this.tieneImagen,
      imagenTamano: imagenTamano ?? this.imagenTamano,
    );
  }

  // Helpers existentes - SIN CAMBIOS
  EstadoEquipoCenso get estadoCensoEnum => EstadoEquipoCensoExtension.fromString(estadoCenso);
  bool get estaCreado => estadoCenso == EstadoEquipoCenso.creado.valor;
  bool get estaMigrado => estadoCenso == EstadoEquipoCenso.migrado.valor;
  bool get tieneError => estadoCenso == EstadoEquipoCenso.error.valor;

  // NUEVOS HELPERS PARA IMAGENES
  bool get necesitaSincronizarImagen => tieneImagen && !estaSincronizado && imagenBase64 != null;

  String get infoImagen {
    if (!tieneImagen) return 'Sin imagen';
    final tamanoMB = imagenTamano != null ? (imagenTamano! / (1024 * 1024)).toStringAsFixed(1) : '?';
    final estado = estaSincronizado ? 'Sincronizada' : 'Pendiente';
    return 'Imagen ($tamanoMB MB) - $estado';
  }
}
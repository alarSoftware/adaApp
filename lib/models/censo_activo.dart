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
  final String? id;
  final String equipoId;
  final int clienteId;
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final DateTime fechaRevision;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;
  final String? estadoCenso;
  final String? observaciones;

  EstadoEquipo({
    this.id,
    required this.equipoId,
    required this.clienteId,
    required this.enLocal,
    this.latitud,
    this.longitud,
    required this.fechaRevision,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estaSincronizado = false,
    this.estadoCenso,
    this.observaciones,
  });

  factory EstadoEquipo.fromMap(Map<String, dynamic> map) {
    return EstadoEquipo(
      id: map['id'] as String?,
      equipoId: map['equipo_id'] as String? ?? '0',
      clienteId: map['cliente_id'] as int? ?? 0,
      enLocal: (map['en_local'] as int?) == 1,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      fechaRevision: map['fecha_revision'] != null
          ? DateTime.parse(map['fecha_revision'] as String)
          : DateTime.now(),
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      estadoCenso: map['estado_censo'] as String?,
      observaciones: map['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'en_local': enLocal ? 1 : 0,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
      'observaciones': observaciones,
    };

    if (estadoCenso != null) {
      map['estado_censo'] = estadoCenso;
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'en_local': enLocal,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado,
      'estado_censo': estadoCenso,
      'observaciones': observaciones,
    };
  }

  EstadoEquipo copyWith({
    String? id,
    String? equipoId,
    int? clienteId,
    bool? enLocal,
    double? latitud,
    double? longitud,
    DateTime? fechaRevision,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
    String? estadoCenso,
    String? observaciones,
  }) {
    return EstadoEquipo(
      id: id ?? this.id,
      equipoId: equipoId ?? this.equipoId,
      clienteId: clienteId ?? this.clienteId,
      enLocal: enLocal ?? this.enLocal,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      estadoCenso: estadoCenso ?? this.estadoCenso,
      observaciones: observaciones ?? this.observaciones,
    );
  }

  // Estados del censo
  EstadoEquipoCenso get estadoCensoEnum => EstadoEquipoCensoExtension.fromString(estadoCenso);
  bool get estaCreado => estadoCenso == EstadoEquipoCenso.creado.valor;
  bool get estaMigrado => estadoCenso == EstadoEquipoCenso.migrado.valor;
  bool get tieneError => estadoCenso == EstadoEquipoCenso.error.valor;
}
import 'package:flutter/material.dart';

class EstadoEquipo {
  final int? id;
  final int equipoId;
  final int clienteId;
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final DateTime fechaRevision;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;

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
  });

  factory EstadoEquipo.fromMap(Map<String, dynamic> map) {
    return EstadoEquipo(
      id: map['id'] as int?,
      equipoId: map['equipo_id'] as int,
      clienteId: map['id_clientes'] as int,
      enLocal: (map['en_local'] as int?) == 1,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      fechaRevision: DateTime.parse(map['fecha_revision'] as String),
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: (map['sincronizado'] as int?) == 1,
    );
  }

  factory EstadoEquipo.fromJson(Map<String, dynamic> json) {
    return EstadoEquipo(
      id: json['id'] as int?,
      equipoId: json['equipo_id'] as int,
      clienteId: json['id_clientes'] as int,
      enLocal: json['en_local'] as bool,
      latitud: json['latitud'] as double?,
      longitud: json['longitud'] as double?,
      fechaRevision: DateTime.parse(json['fecha_revision'] as String),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'] as String)
          : DateTime.now(),
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.parse(json['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: json['sincronizado'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'id_clientes': clienteId,
      'en_local': enLocal ? 1 : 0,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'id_clientes': clienteId,
      'en_local': enLocal,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  EstadoEquipo copyWith({
    int? id,
    int? equipoId,
    int? clienteId,
    bool? enLocal,
    double? latitud,
    double? longitud,
    DateTime? fechaRevision,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
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
    );
  }

  String get ubicacionTexto => enLocal ? 'En local' : 'Fuera del local';

  Color get colorUbicacion => enLocal ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);

  @override
  String toString() {
    return 'EstadoEquipo(id: $id, equipoId: $equipoId, clienteId: $clienteId, enLocal: $enLocal)';
  }
}
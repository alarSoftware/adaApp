class EquiposPendientes {
  final int? id;
  final int equipoId;
  final int clienteId;
  final DateTime fechaCenso;
  final int usuarioCensoId;
  final double latitud;
  final double longitud;
  final String? observaciones;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  // Campos adicionales para JOINs
  final String? codBarras;
  final String? numeroSerie;
  final String? marcaNombre;
  final String? modeloNombre;
  final String? logoNombre;
  final String? clienteNombre;

  EquiposPendientes({
    this.id,
    required this.equipoId,
    required this.clienteId,
    required this.fechaCenso,
    required this.usuarioCensoId,
    required this.latitud,
    required this.longitud,
    this.observaciones,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.codBarras,
    this.numeroSerie,
    this.marcaNombre,
    this.modeloNombre,
    this.logoNombre,
    this.clienteNombre,
  });

  factory EquiposPendientes.fromMap(Map<String, dynamic> map) {
    return EquiposPendientes(
      id: map['id'] as int?,
      equipoId: map['equipo_id'] as int,
      clienteId: map['cliente_id'] as int,
      fechaCenso: DateTime.parse(map['fecha_censo'] as String),
      usuarioCensoId: map['usuario_censo_id'] as int,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      observaciones: map['observaciones'] as String?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      codBarras: map['cod_barras'] as String?,
      numeroSerie: map['numero_serie'] as String?,
      marcaNombre: map['marca_nombre'] as String?,
      modeloNombre: map['modelo_nombre'] as String?,
      logoNombre: map['logo_nombre'] as String?,
      clienteNombre: map['cliente_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'fecha_censo': fechaCenso.toIso8601String(),
      'usuario_censo_id': usuarioCensoId,
      'latitud': latitud,
      'longitud': longitud,
      'observaciones': observaciones,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }
}
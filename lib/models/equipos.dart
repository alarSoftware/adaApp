class Equipo {
  final int? id;
  final String codBarras;
  final String marca;
  final String modelo;
  final String tipoEquipo;
  final int activo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final int sincronizado;

  Equipo({
    this.id,
    required this.codBarras,
    required this.marca,
    required this.modelo,
    required this.tipoEquipo,
    this.activo = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.sincronizado = 0,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'],
      codBarras: map['cod_barras'] ?? '',
      marca: map['marca'] ?? '',
      modelo: map['modelo'] ?? '',
      tipoEquipo: map['tipo_equipo'] ?? '',
      activo: map['activo'] ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
      sincronizado: map['sincronizado'] ?? 0,
    );
  }

  factory Equipo.fromJson(Map<String, dynamic> json) {
    DateTime fecha;
    DateTime? fechaAct;

    try {
      fecha = DateTime.parse(
          json['fecha_creacion'] ??
              json['fechaCreacion'] ??
              DateTime.now().toIso8601String()
      );
    } catch (_) {
      fecha = DateTime.now();
    }

    try {
      if (json['fecha_actualizacion'] != null || json['fechaActualizacion'] != null) {
        fechaAct = DateTime.parse(
            json['fecha_actualizacion'] ?? json['fechaActualizacion']
        );
      }
    } catch (_) {
      fechaAct = null;
    }

    return Equipo(
      id: json['id'],
      codBarras: json['cod_barras'] ?? json['codBarras'] ?? '',
      marca: json['marca'] ?? '',
      modelo: json['modelo'] ?? '',
      tipoEquipo: json['tipo_equipo'] ?? json['tipoEquipo'] ?? '',
      activo: json['activo'] ?? 1,
      fechaCreacion: fecha,
      fechaActualizacion: fechaAct,
      sincronizado: json['sincronizado'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'marca': marca,
      'modelo': modelo,
      'tipo_equipo': tipoEquipo,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': sincronizado,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'codBarras': codBarras, // Para compatibilidad con API
      'marca': marca,
      'modelo': modelo,
      'tipo_equipo': tipoEquipo,
      'tipoEquipo': tipoEquipo, // Para compatibilidad con API
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(), // Para compatibilidad
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(), // Para compatibilidad
      'sincronizado': sincronizado,
    };
  }

  Equipo copyWith({
    int? id,
    String? codBarras,
    String? marca,
    String? modelo,
    String? tipoEquipo,
    int? activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? sincronizado,
  }) {
    return Equipo(
      id: id ?? this.id,
      codBarras: codBarras ?? this.codBarras,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      tipoEquipo: tipoEquipo ?? this.tipoEquipo,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  // Métodos de utilidad que usa tu vista
  bool get estaActivo => activo == 1;
  bool get estaSincronizado => sincronizado == 1;
  String get nombreCompleto => '$marca $modelo';

  @override
  String toString() {
    return 'Equipo{id: $id, codBarras: $codBarras, marca: $marca, modelo: $modelo, tipoEquipo: $tipoEquipo, activo: $activo, sincronizado: $sincronizado}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Equipo &&
        other.id == id &&
        other.codBarras == codBarras;
  }

  @override
  int get hashCode => id.hashCode ^ codBarras.hashCode;
}
class Marca {
  final int? id;
  final String nombre;
  final bool activo;
  final bool sincronizado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  const Marca({
    this.id,
    required this.nombre,
    this.activo = true,
    this.sincronizado = false,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id']?.toInt(),
      nombre: map['nombre'] ?? '',
      activo: (map['activo'] ?? 1) == 1,
      sincronizado: (map['sincronizado'] ?? 0) == 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'activo': activo ? 1 : 0,
      'sincronizado': sincronizado ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      if (fechaActualizacion != null)
        'fecha_actualizacion': fechaActualizacion!.toIso8601String(),
    };
  }

  Marca copyWith({
    int? id,
    String? nombre,
    bool? activo,
    bool? sincronizado,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return Marca(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      activo: activo ?? this.activo,
      sincronizado: sincronizado ?? this.sincronizado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() => 'Marca(id: $id, nombre: $nombre, activo: $activo)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Marca &&
        other.id == id &&
        other.nombre == nombre &&
        other.activo == activo;
  }

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode ^ activo.hashCode;
}
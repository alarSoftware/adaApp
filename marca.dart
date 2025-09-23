class Marca {
  final int? id;
  final String nombre;
  final bool activo;
  final DateTime fechaCreacion;

  // Campos que NO van a la base de datos - solo para uso local
  final bool sincronizado;
  final DateTime? fechaActualizacion;

  const Marca({
    this.id,
    required this.nombre,
    this.activo = true,
    required this.fechaCreacion,
    // Campos locales con valores por defecto
    this.sincronizado = false,
    this.fechaActualizacion,
  });

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id']?.toInt(),
      nombre: map['nombre'] ?? '',
      activo: (map['activo'] ?? 1) == 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      // Campos locales - no vienen de la BD
      sincronizado: true, // Si viene de BD, asumimos que está sincronizado
    );
  }

  // Método para crear desde la API
  factory Marca.fromAPI(Map<String, dynamic> apiData) {
    return Marca(
      id: apiData['id']?.toInt(),
      nombre: (apiData['nombre'] ?? '').toString().trim(),
      activo: apiData['activo'] == null ? true :
      (apiData['activo'] == 1 || apiData['activo'] == true),
      fechaCreacion: apiData['fecha_creacion'] != null
          ? DateTime.parse(apiData['fecha_creacion'])
          : DateTime.now(),
      sincronizado: true,
      fechaActualizacion: DateTime.now(),
    );
  }

  // toMap() solo incluye campos que existen en la tabla
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'activo': activo ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  Marca copyWith({
    int? id,
    String? nombre,
    bool? activo,
    DateTime? fechaCreacion,
    bool? sincronizado,
    DateTime? fechaActualizacion,
  }) {
    return Marca(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      sincronizado: sincronizado ?? this.sincronizado,
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
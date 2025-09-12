class Usuario {
  final int? id;
  final String nombre;
  final String password;
  final String rol;
  final bool activo;
  final bool sincronizado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Usuario({
    this.id,
    required this.nombre,
    required this.password,
    required this.rol,
    this.activo = true,
    this.sincronizado = false,
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      password: map['password'] as String,
      rol: map['rol'] as String,
      activo: (map['activo'] as int?) == 1,
      sincronizado: (map['sincronizado'] as int?) == 1,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int?,
      nombre: json['nombre'] as String,
      password: json['password'] as String,
      rol: json['rol'] as String,
      activo: true,
      sincronizado: true,
      fechaCreacion: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'password': password,
      'rol': rol,
      'activo': activo ? 1 : 0,
      'sincronizado': sincronizado ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  bool get esAdmin => rol == 'admin';
  bool get esVendedor => rol == 'vendedor';
}
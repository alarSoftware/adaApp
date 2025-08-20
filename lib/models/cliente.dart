

class Cliente {
  final int? id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? direccion;
  final DateTime fechaCreacion;
  final bool estaSincronizado;

  Cliente({
    this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.direccion,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now(),
       estaSincronizado = false;

  // Convertir de Map (base de datos) a Cliente
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
      email: map['email'],
      telefono: map['telefono'],
      direccion: map['direccion'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
    );
  }

  // Constructor desde JSON (para API)
  factory Cliente.fromJson(Map<String, dynamic> json) {
    DateTime fechaCreacion;
    try {
      if (json['fecha_creacion'] != null) {
        fechaCreacion = DateTime.parse(json['fecha_creacion']);
      } else if (json['fechaCreacion'] != null) {
        fechaCreacion = DateTime.parse(json['fechaCreacion']);
      } else {
        fechaCreacion = DateTime.now();
      }
    } catch (e) {
      fechaCreacion = DateTime.now();
    }

    return Cliente(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'],
      direccion: json['direccion'],
      fechaCreacion: fechaCreacion,
    );
  }

  // Convertir de Cliente a Map (para guardar en base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  // Convertir a JSON para enviar al API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono ?? '',
      'direccion': direccion ?? '',
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  // Método para crear una copia con cambios
  Cliente copyWith({
    int? id,
    String? nombre,
    String? email,
    String? telefono,
    String? direccion,
    DateTime? fechaCreacion,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  String toString() {
    return 'Cliente{id: $id, nombre: $nombre, email: $email}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Cliente &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              nombre == other.nombre &&
              email == other.email;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode ^ email.hashCode;
}

class Cliente {
  final int? id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? direccion;
  final DateTime fechaCreacion;

  Cliente({
    this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.direccion,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

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

  // Convertir a JSON para enviar al EDP
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
}
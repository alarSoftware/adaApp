class Usuario {
  final int? id;
  final String? edfVendedorId;
  final int code;
  final String username;
  final String password;
  final String fullname;
  final int sincronizado;
  final String fechaCreacion;
  final String fechaActualizacion;

  Usuario({
    this.id,
    this.edfVendedorId,
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
    this.sincronizado = 0,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  // Constructor para crear desde Map (base de datos)
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id']?.toInt(),
      edfVendedorId: map['edf_vendedor_id']?.toString(),
      code: map['code']?.toInt() ?? 0,
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      fullname: map['fullname']?.toString() ?? '',
      sincronizado: map['sincronizado']?.toInt() ?? 0,
      fechaCreacion: map['fecha_creacion']?.toString() ??
          DateTime.now().toIso8601String(),
      fechaActualizacion: map['fecha_actualizacion']?.toString() ??
          DateTime.now().toIso8601String(),
    );
  }

  // Constructor para crear desde JSON (API)
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id']?.toInt(),
      edfVendedorId: json['edf_vendedor_id']?.toString(),
      code: json['code']?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      sincronizado: json['sincronizado']?.toInt() ?? 0,
      fechaCreacion: json['fecha_creacion']?.toString() ??
          DateTime.now().toIso8601String(),
      fechaActualizacion: json['fecha_actualizacion']?.toString() ??
          DateTime.now().toIso8601String(),
    );
  }

  // Convertir a Map para insertar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'edf_vendedor_id': edfVendedorId,
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
      'sincronizado': sincronizado,
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
    };
  }

  // Convertir a JSON para enviar a API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'edf_vendedor_id': edfVendedorId,
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
      'sincronizado': sincronizado,
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
    };
  }
}
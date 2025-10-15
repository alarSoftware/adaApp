class Usuario {
  final int? id;
  final String? edfVendedorId;
  final int code;
  final String username;
  final String password;
  final String fullname;

  Usuario({
    this.id,
    this.edfVendedorId,
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
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
    );
  }

  // Constructor para crear desde JSON (API)
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id']?.toInt(),  // ✅ ID viene de la API
      edfVendedorId: json['edfVendedorId']?.toString(),  // ✅ camelCase de la API
      code: json['id']?.toInt() ?? 0,  // ✅ code usa el mismo ID de la API
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
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
    };
  }

  // Convertir a JSON para enviar a API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'edfVendedorId': edfVendedorId,  // ✅ camelCase para la API
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
    };
  }
}
class Usuario {
  final int? id;
  final int code;
  final String username;
  final String password;
  final String fullname;

  Usuario({
    this.id,
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int?,
      code: map['code'] as int,
      username: map['username'] as String,
      password: map['password'] as String,
      fullname: map['fullname'] as String,
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int?,
      code: json['id'] as int, // Mapear id de API a code
      username: json['username'] as String,
      password: json['password'] as String,
      fullname: json['fullname'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
    };
  }


// Puedes mantener estos getters si los necesitas,
// aunque tendrías que definir cómo determinar el rol
// bool get esAdmin => username == 'admin'; // ejemplo
// bool get esVendedor => !esAdmin; // ejemplo
}
import 'package:ada_app/utils/parsing_helpers.dart';

class Usuario {
  final int? id;
  final String? edfVendedorId;
  final String? edfVendedorNombre; // <--- NUEVO CAMPO
  final int code;
  final String username;
  final String password;
  final String fullname;

  const Usuario({
    this.id,
    this.edfVendedorId,
    this.edfVendedorNombre, // <--- Añadido al constructor
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
  });

  // ========== FACTORY CONSTRUCTORS ==========

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: ParsingHelpers.parseInt(map['id']),
      edfVendedorId: ParsingHelpers.parseString(map['employed_id']),
      // Asegúrate de que la clave coincida con tu CREATE TABLE ('edfVendedorNombre')
      edfVendedorNombre: ParsingHelpers.parseString(map['edf_vendedor_nombre']),
      code: ParsingHelpers.parseInt(map['code']),
      username: ParsingHelpers.parseString(map['username']) ?? '',
      password: ParsingHelpers.parseString(map['password']) ?? '',
      fullname: ParsingHelpers.parseString(map['fullname']) ?? '',
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: ParsingHelpers.parseInt(json['id']),
      edfVendedorId: ParsingHelpers.parseString(json['edfVendedorId']),
      // Asumiendo que el JSON de la API trae la misma clave
      edfVendedorNombre: ParsingHelpers.parseString(json['edfVendedorNombre']),
      code: ParsingHelpers.parseInt(
        json['id'],
      ), // code usa el mismo ID según tu lógica original
      username: ParsingHelpers.parseString(json['username']) ?? '',
      password: ParsingHelpers.parseString(json['password']) ?? '',
      fullname: ParsingHelpers.parseString(json['fullname']) ?? '',
    );
  }

  // ========== SERIALIZATION ==========

  // Para Base de Datos Local (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employed_id': edfVendedorId,
      'edf_vendedor_nombre': edfVendedorNombre,
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
    };
  }

  // Para enviar a API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'edfVendedorId': edfVendedorId,
      'edfVendedorNombre': edfVendedorNombre, // <--- Añadido
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
    };
  }

  // ========== UTILITIES ==========

  Usuario copyWith({
    int? id,
    String? edfVendedorId,
    String? edfVendedorNombre, // <--- Añadido parámetro
    int? code,
    String? username,
    String? password,
    String? fullname,
  }) {
    return Usuario(
      id: id ?? this.id,
      edfVendedorId: edfVendedorId ?? this.edfVendedorId,
      edfVendedorNombre:
          edfVendedorNombre ?? this.edfVendedorNombre, // <--- Lógica de copia
      code: code ?? this.code,
      username: username ?? this.username,
      password: password ?? this.password,
      fullname: fullname ?? this.fullname,
    );
  }

  @override
  String toString() =>
      'Usuario(id: $id, username: $username, code: $code, edfVendedorNombre: $edfVendedorNombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}

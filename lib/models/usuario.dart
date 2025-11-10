import 'package:ada_app/utils/parsing_helpers.dart';

class Usuario {
  final int? id;
  final String? edfVendedorId;
  final int code;
  final String username;
  final String password;
  final String fullname;

  const Usuario({
    this.id,
    this.edfVendedorId,
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
  });

  // ========== FACTORY CONSTRUCTORS ==========

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: ParsingHelpers.parseInt(map['id']),
      edfVendedorId: ParsingHelpers.parseString(map['edf_vendedor_id']),
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
      code: ParsingHelpers.parseInt(json['id']), // code usa el mismo ID
      username: ParsingHelpers.parseString(json['username']) ?? '',
      password: ParsingHelpers.parseString(json['password']) ?? '',
      fullname: ParsingHelpers.parseString(json['fullname']) ?? '',
    );
  }

  // ========== SERIALIZATION ==========

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'edfVendedorId': edfVendedorId,
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
    int? code,
    String? username,
    String? password,
    String? fullname,
  }) {
    return Usuario(
      id: id ?? this.id,
      edfVendedorId: edfVendedorId ?? this.edfVendedorId,
      code: code ?? this.code,
      username: username ?? this.username,
      password: password ?? this.password,
      fullname: fullname ?? this.fullname,
    );
  }

  @override
  String toString() => 'Usuario(id: $id, username: $username, code: $code)';

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
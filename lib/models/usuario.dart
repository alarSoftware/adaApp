import 'package:ada_app/utils/parsing_helpers.dart';

class Usuario {
  final int? id;
  final String? employeeId;
  final String? employeeName;
  final int code;
  final String username;
  final String password;
  final String fullname;

  const Usuario({
    this.id,
    this.employeeId,
    this.employeeName,
    required this.code,
    required this.username,
    required this.password,
    required this.fullname,
  });

  // ========== FACTORY CONSTRUCTORS ==========

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: ParsingHelpers.parseInt(map['id']),
      employeeId: ParsingHelpers.parseString(map['employee_id']),
      // Now using 'employee_name'
      employeeName: ParsingHelpers.parseString(map['employee_name']),
      code: ParsingHelpers.parseInt(map['code']),
      username: ParsingHelpers.parseString(map['username']) ?? '',
      password: ParsingHelpers.parseString(map['password']) ?? '',
      fullname: ParsingHelpers.parseString(map['fullname']) ?? '',
    );
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: ParsingHelpers.parseInt(json['id']),
      employeeId: ParsingHelpers.parseString(json['employeeId']),
      // Prefer 'employeeName' but keep fallback if needed or just switch
      employeeName:
          ParsingHelpers.parseString(json['employeeName']) ??
          ParsingHelpers.parseString(json['edfVendedorNombre']),
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
      'employee_id': employeeId,
      'employee_name': employeeName,
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
      'employeeId': employeeId,
      'employeeName': employeeName,
      'code': code,
      'username': username,
      'password': password,
      'fullname': fullname,
    };
  }

  // ========== UTILITIES ==========

  Usuario copyWith({
    int? id,
    String? employeeId,
    String? employeeName,
    int? code,
    String? username,
    String? password,
    String? fullname,
  }) {
    return Usuario(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      code: code ?? this.code,
      username: username ?? this.username,
      password: password ?? this.password,
      fullname: fullname ?? this.fullname,
    );
  }

  @override
  String toString() =>
      'Usuario(id: $id, username: $username, code: $code, employeeName: $employeeName)';

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

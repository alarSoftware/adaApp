import 'package:ada_app/utils/parsing_helpers.dart';

class Logo {
  final int? id;
  final String nombre;

  const Logo({this.id, required this.nombre});

  // ========== FACTORY CONSTRUCTORS ==========

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: ParsingHelpers.parseInt(map['id']),
      nombre: ParsingHelpers.parseString(map['nombre']) ?? '',
    );
  }

  factory Logo.fromJson(Map<String, dynamic> json) => Logo.fromMap(json);

  // ========== SERIALIZATION ==========

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nombre': nombre.trim()};
  }

  Map<String, dynamic> toJson() => toMap();

  // ========== UTILITIES ==========

  Logo copyWith({int? id, String? nombre}) {
    return Logo(id: id ?? this.id, nombre: nombre ?? this.nombre);
  }

  @override
  String toString() => 'Logo(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Logo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}

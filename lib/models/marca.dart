import 'package:ada_app/utils/parsing_helpers.dart';

class Marca {
  final int? id;
  final String nombre;

  const Marca({
    this.id,
    required this.nombre,
  });

  // ========== FACTORY CONSTRUCTORS ==========

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: ParsingHelpers.parseInt(map['id']),
      nombre: ParsingHelpers.parseString(map['nombre']) ?? '',
    );
  }

  /// Alias de fromMap para consistencia con API
  factory Marca.fromJson(Map<String, dynamic> json) => Marca.fromMap(json);

  // ========== SERIALIZATION ==========

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre.trim(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  // ========== UTILITIES ==========

  Marca copyWith({
    int? id,
    String? nombre,
  }) {
    return Marca(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
    );
  }

  @override
  String toString() => 'Marca(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Marca &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}
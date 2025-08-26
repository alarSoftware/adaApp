// models/modelo.dart
class Modelo {
  final int? id;
  final String nombre;

  Modelo({
    this.id,
    required this.nombre,
  }

// Script SQL para crear la tabla modelos
/*
CREATE TABLE modelos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE
);

-- Índices para optimización
CREATE INDEX idx_modelos_nombre ON modelos(nombre);
*/);

  factory Modelo.fromMap(Map<String, dynamic> map) {
    return Modelo(
      id: map['id'],
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  Modelo copyWith({
    int? id,
    String? nombre,
  }) {
    return Modelo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
    );
  }

  @override
  String toString() {
    return 'Modelo{id: $id, nombre: $nombre}';
  }
}


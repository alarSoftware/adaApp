class Marca {
  final int? id;
  final String nombre;

  const Marca({
    this.id,
    required this.nombre,
  });

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id']?.toInt(),
      nombre: (map['nombre'] ?? '').toString().trim(),
    );
  }

  // Método para crear desde la API
  factory Marca.fromAPI(Map<String, dynamic> apiData) {
    return Marca(
      id: apiData['id']?.toInt().tri,
      nombre: (apiData['nombre'] ?? '').toString().trim(),
    );
  }

  // toMap() solo incluye campos que existen en la tabla
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre.trim(),
    };
  }

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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Marca &&
        other.id == id &&
        other.nombre == nombre;
  }

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}
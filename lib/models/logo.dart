class Logo {
  final int? id;
  final String nombre;

  const Logo({
    this.id,
    required this.nombre,
  });

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: map['id']?.toInt(),
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
    };
  }

  Logo copyWith({
    int? id,
    String? maca,
  }) {
    return Logo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
    );
  }

  @override
  String toString() => 'Logo(id: $id, modelo $nombre)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Logo &&
        other.id == id &&
        other.nombre == nombre;
  }

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}
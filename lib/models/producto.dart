// lib/models/producto.dart
class Producto {
  final int? id;
  final String? codigo;
  final String? codigoBarras;
  final String? nombre;
  final String? categoria;

  const Producto({
    this.id,
    this.codigo,
    this.codigoBarras,
    this.nombre,
    this.categoria,
  });

  String get displayName {
    if (codigo != null && codigo!.isNotEmpty && nombre != null) {
      return '[$codigo] $nombre';
    }
    return nombre ?? 'Sin nombre';
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as int?,
      codigo: _parseString(json['codigo']),
      codigoBarras: _parseString(json['codigo_barras']) ?? _parseString(json['codigoBarras']),
      nombre: _parseString(json['nombre']),
      categoria: _parseString(json['categoria']),
    );
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),
      codigo: map['codigo']?.toString(),
      codigoBarras: map['codigo_barras']?.toString(),
      nombre: map['nombre']?.toString(),
      categoria: map['categoria']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'categoria': categoria,
    };
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'codigo': codigo,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'categoria': categoria,
    };

    if (id != null) json['id'] = id;
    return json;
  }

  Producto copyWith({
    int? id,
    String? codigo,
    String? codigoBarras,
    String? nombre,
    String? categoria,
  }) {
    return Producto(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
    );
  }

  // Validación básica de campos requeridos
  bool get isValid => nombre != null && nombre!.isNotEmpty;

  // Getters útiles
  bool get tieneCodigo => codigo != null && codigo!.isNotEmpty;
  bool get tieneCodigoBarras => codigoBarras != null && codigoBarras!.isNotEmpty;
  bool get tieneCategoria => categoria != null && categoria!.isNotEmpty;
  String get displayCategoria => categoria ?? 'Sin categoría';

  // Métodos de parsing
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Producto &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              codigo == other.codigo &&
              codigoBarras == other.codigoBarras &&
              nombre == other.nombre &&
              categoria == other.categoria;

  @override
  int get hashCode =>
      id.hashCode ^
      codigo.hashCode ^
      codigoBarras.hashCode ^
      nombre.hashCode ^
      categoria.hashCode;

  @override
  String toString() {
    return 'Producto{id: $id, codigo: $codigo, codigoBarras: $codigoBarras, nombre: $nombre, categoria: $categoria}';
  }
}
// lib/models/producto.dart
class Producto {
  final int? id;
  final String codigo;
  final String descripcion;
  final String? categoria;
  final double? precio;
  final double? stock;
  final bool activo;

  const Producto({
    this.id,
    required this.codigo,
    required this.descripcion,
    this.categoria,
    this.precio,
    this.stock,
    this.activo = true,
  });

  String get displayName {
    if (codigo.isNotEmpty) {
      return '[$codigo] $descripcion';
    }
    return descripcion;
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as int?,
      codigo: _parseString(json['codigo']) ?? '',
      descripcion: _parseString(json['descripcion']) ?? '',
      categoria: _parseString(json['categoria']),
      precio: _parseDouble(json['precio']),
      stock: _parseDouble(json['stock']),
      activo: json['activo'] == 1 || json['activo'] == true,
    );
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),
      codigo: map['codigo']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      categoria: map['categoria']?.toString(),
      precio: _parseDouble(map['precio']),
      stock: _parseDouble(map['stock']),
      activo: map['activo'] == 1 || map['activo'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'descripcion': descripcion,
      'categoria': categoria,
      'precio': precio,
      'stock': stock,
      'activo': activo ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'codigo': codigo,
      'descripcion': descripcion,
      'categoria': categoria,
      'precio': precio,
      'stock': stock,
      'activo': activo,
    };

    if (id != null) json['id'] = id;
    return json;
  }

  Producto copyWith({
    int? id,
    String? codigo,
    String? descripcion,
    String? categoria,
    double? precio,
    double? stock,
    bool? activo,
  }) {
    return Producto(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      activo: activo ?? this.activo,
    );
  }

  // Validación básica de campos requeridos
  bool get isValid => codigo.isNotEmpty && descripcion.isNotEmpty;

  // Getters útiles
  bool get tieneStock => stock != null && stock! > 0;
  bool get tienePrecio => precio != null && precio! > 0;
  bool get tieneCategoria => categoria != null && categoria!.isNotEmpty;
  String get displayCategoria => categoria ?? 'Sin categoría';
  String get displayPrecio => precio != null ? 'Gs. ${precio!.toStringAsFixed(0)}' : 'Sin precio';
  String get displayStock => stock != null ? stock!.toStringAsFixed(2) : 'Sin stock';

  // Métodos de parsing
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final str = value.toString().trim();
    return double.tryParse(str);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Producto &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              codigo == other.codigo &&
              descripcion == other.descripcion &&
              categoria == other.categoria &&
              precio == other.precio &&
              stock == other.stock &&
              activo == other.activo;

  @override
  int get hashCode =>
      id.hashCode ^
      codigo.hashCode ^
      descripcion.hashCode ^
      categoria.hashCode ^
      precio.hashCode ^
      stock.hashCode ^
      activo.hashCode;

  @override
  String toString() {
    return 'Producto{id: $id, codigo: $codigo, descripcion: $descripcion, categoria: $categoria, precio: $precio, stock: $stock, activo: $activo}';
  }
}

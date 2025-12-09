import 'package:ada_app/utils/unidad_medida_helper.dart';

class Producto {
  final int? id;
  final String? codigo;
  final String? codigoBarras;
  final String? nombre;
  final String? categoria;
  final String unidadMedida;

  const Producto({
    this.id,
    this.codigo,
    this.codigoBarras,
    this.nombre,
    this.categoria,
    required this.unidadMedida,
  });

  String get displayName {
    if (codigo != null && codigo!.isNotEmpty && nombre != null) {
      return '[$codigo] $nombre';
    }
    return nombre ?? 'Sin nombre';
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    // Obtener unidad de medida de la API y normalizarla
    final unidadRaw = _parseString(json['unidad_medida']) ??
        _parseString(json['unidadMedida']);

    return Producto(
      id: json['id'] as int?,
      codigo: _parseString(json['codigo']),
      codigoBarras: _parseString(json['codigo_barras']) ??
          _parseString(json['codigoBarras']),
      nombre: _parseString(json['nombre']),
      categoria: _parseString(json['categoria']),
      unidadMedida: UnidadMedidaHelper.normalizarDesdeAPI(unidadRaw),
    );
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    // Obtener unidad de medida del mapa y normalizarla
    final unidadRaw = map['unidad_medida']?.toString();

    return Producto(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),
      codigo: map['codigo']?.toString(),
      codigoBarras: map['codigo_barras']?.toString(),
      nombre: map['nombre']?.toString(),
      categoria: map['categoria']?.toString(),
      unidadMedida: UnidadMedidaHelper.normalizarDesdeAPI(unidadRaw),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'categoria': categoria,
      'unidad_medida': unidadMedida,
    };
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'codigo': codigo,
      'codigoBarras': codigoBarras,
      'nombre': nombre,
      'categoria': categoria,
      'unidadMedida': unidadMedida,
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
    String? unidadMedida,
  }) {
    return Producto(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      unidadMedida: unidadMedida ?? this.unidadMedida,
    );
  }

  bool get isValid => nombre != null && nombre!.isNotEmpty;

  bool get tieneCodigo => codigo != null && codigo!.isNotEmpty;
  bool get tieneCodigoBarras => codigoBarras != null && codigoBarras!.isNotEmpty;
  bool get tieneCategoria => categoria != null && categoria!.isNotEmpty;
  bool get tieneUnidadMedida => unidadMedida.isNotEmpty;

  String get displayCategoria => categoria ?? 'Sin categoría';
  String get displayUnidadMedida => UnidadMedidaHelper.obtenerNombreDisplay(unidadMedida);

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
              categoria == other.categoria &&
              unidadMedida == other.unidadMedida;

  @override
  int get hashCode =>
      id.hashCode ^
      codigo.hashCode ^
      codigoBarras.hashCode ^
      nombre.hashCode ^
      categoria.hashCode ^
      unidadMedida.hashCode;

  @override
  String toString() {
    return 'Producto{id: $id, codigo: $codigo, codigoBarras: $codigoBarras, nombre: $nombre, categoria: $categoria, unidadMedida: $unidadMedida}';
  }
}
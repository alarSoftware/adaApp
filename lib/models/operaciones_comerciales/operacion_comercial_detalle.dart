// lib/models/operaciones_comerciales/operacion_comercial_detalle.dart
class OperacionComercialDetalle {
  final String? id;
  final String operacionComercialId;
  final String productoCodigo;
  final String productoDescripcion;
  final String? productoCategoria;
  final double cantidad;
  final String unidadMedida;
  final String? ticket;
  final double? precioUnitario;
  final double? subtotal;
  final int orden;
  final DateTime fechaCreacion;
  final bool estaSincronizado;

  // 🆕 CAMPOS PARA INTERCAMBIO (RETIRO DISCONTINUOS)
  final String? productoReemplazoCodigo;
  final String? productoReemplazoDescripcion;
  final String? productoReemplazoCategoria;

  const OperacionComercialDetalle({
    this.id,
    required this.operacionComercialId,
    required this.productoCodigo,
    required this.productoDescripcion,
    this.productoCategoria,
    required this.cantidad,
    required this.unidadMedida,
    this.ticket,
    this.precioUnitario,
    this.subtotal,
    this.orden = 1,
    required this.fechaCreacion,
    this.estaSincronizado = false,
    this.productoReemplazoCodigo,
    this.productoReemplazoDescripcion,
    this.productoReemplazoCategoria,
  });

  factory OperacionComercialDetalle.fromMap(Map<String, dynamic> map) {
    return OperacionComercialDetalle(
      id: map['id'] as String?,
      operacionComercialId: map['operacion_comercial_id'] as String? ?? '',
      productoCodigo: map['producto_codigo'] as String? ?? '',
      productoDescripcion: map['producto_descripcion'] as String? ?? '',
      productoCategoria: map['producto_categoria'] as String?,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      unidadMedida: map['unidad_medida'] as String? ?? '',
      ticket: map['ticket'] as String?,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble(),
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      orden: map['orden'] as int? ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      productoReemplazoCodigo: map['producto_reemplazo_codigo'] as String?,
      productoReemplazoDescripcion: map['producto_reemplazo_descripcion'] as String?,
      productoReemplazoCategoria: map['producto_reemplazo_categoria'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operacion_comercial_id': operacionComercialId,
      'producto_codigo': productoCodigo,
      'producto_descripcion': productoDescripcion,
      'producto_categoria': productoCategoria,
      'cantidad': cantidad,
      'unidad_medida': unidadMedida,
      'ticket': ticket,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'orden': orden,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
      'producto_reemplazo_codigo': productoReemplazoCodigo,
      'producto_reemplazo_descripcion': productoReemplazoDescripcion,
      'producto_reemplazo_categoria': productoReemplazoCategoria,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_codigo': productoCodigo,
      'producto_descripcion': productoDescripcion,
      'producto_categoria': productoCategoria,
      'cantidad': cantidad,
      'unidad_medida': unidadMedida,
      'ticket': ticket,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'orden': orden,
      'producto_reemplazo_codigo': productoReemplazoCodigo,
      'producto_reemplazo_descripcion': productoReemplazoDescripcion,
      'producto_reemplazo_categoria': productoReemplazoCategoria,
    };
  }

  OperacionComercialDetalle copyWith({
    String? id,
    String? operacionComercialId,
    String? productoCodigo,
    String? productoDescripcion,
    String? productoCategoria,
    double? cantidad,
    String? unidadMedida,
    String? ticket,
    double? precioUnitario,
    double? subtotal,
    int? orden,
    DateTime? fechaCreacion,
    bool? estaSincronizado,
    String? productoReemplazoCodigo,
    String? productoReemplazoDescripcion,
    String? productoReemplazoCategoria,
  }) {
    return OperacionComercialDetalle(
      id: id ?? this.id,
      operacionComercialId: operacionComercialId ?? this.operacionComercialId,
      productoCodigo: productoCodigo ?? this.productoCodigo,
      productoDescripcion: productoDescripcion ?? this.productoDescripcion,
      productoCategoria: productoCategoria ?? this.productoCategoria,
      cantidad: cantidad ?? this.cantidad,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      ticket: ticket ?? this.ticket,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      orden: orden ?? this.orden,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      productoReemplazoCodigo: productoReemplazoCodigo ?? this.productoReemplazoCodigo,
      productoReemplazoDescripcion: productoReemplazoDescripcion ?? this.productoReemplazoDescripcion,
      productoReemplazoCategoria: productoReemplazoCategoria ?? this.productoReemplazoCategoria,
    );
  }

  // Getters útiles
  String get displayInfo => '$productoCodigo - $productoDescripcion';
  bool get tieneTicket => ticket != null && ticket!.isNotEmpty;
  bool get tienePrecio => precioUnitario != null && precioUnitario! > 0;
  bool get esIntercambio => productoReemplazoCodigo != null;
  bool get intercambioCompleto => productoReemplazoCodigo != null && productoReemplazoDescripcion != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OperacionComercialDetalle &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              operacionComercialId == other.operacionComercialId &&
              productoCodigo == other.productoCodigo;

  @override
  int get hashCode => id.hashCode ^ operacionComercialId.hashCode ^ productoCodigo.hashCode;

  @override
  String toString() {
    return 'OperacionComercialDetalle{id: $id, codigo: $productoCodigo, descripcion: $productoDescripcion, cantidad: $cantidad, unidad: $unidadMedida, reemplazo: $productoReemplazoCodigo}';
  }
}
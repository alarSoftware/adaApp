class OperacionComercialDetalle {
  final String? id;
  final String operacionComercialId;
  final int? productoId;
  final double cantidad;
  final String? ticket;
  final double? precioUnitario;
  final double? subtotal;
  final int orden;
  final DateTime fechaCreacion;
  final int? productoReemplazoId;

  const OperacionComercialDetalle({
    this.id,
    required this.operacionComercialId,
    this.productoId,
    required this.cantidad,
    this.ticket,
    this.precioUnitario,
    this.subtotal,
    this.orden = 1,
    required this.fechaCreacion,
    this.productoReemplazoId,
  });

  factory OperacionComercialDetalle.fromMap(Map<String, dynamic> map) {
    return OperacionComercialDetalle(
      id: map['id'] as String?,
      operacionComercialId: map['operacion_comercial_id'] as String? ?? '',
      productoId: map['producto_id'] as int?,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      ticket: map['ticket'] as String?,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble(),
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      orden: map['orden'] as int? ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      productoReemplazoId: map['producto_reemplazo_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operacion_comercial_id': operacionComercialId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'ticket': ticket,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'orden': orden,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'producto_reemplazo_id': productoReemplazoId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_id': productoId,
      'cantidad': cantidad,
      'ticket': ticket,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'orden': orden,
      'producto_reemplazo_id': productoReemplazoId,
    };
  }

  OperacionComercialDetalle copyWith({
    String? id,
    String? operacionComercialId,
    int? productoId,
    double? cantidad,
    String? ticket,
    double? precioUnitario,
    double? subtotal,
    int? orden,
    DateTime? fechaCreacion,
    int? productoReemplazoId,
  }) {
    return OperacionComercialDetalle(
      id: id ?? this.id,
      operacionComercialId: operacionComercialId ?? this.operacionComercialId,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
      ticket: ticket ?? this.ticket,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      orden: orden ?? this.orden,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      productoReemplazoId: productoReemplazoId ?? this.productoReemplazoId,
    );
  }

  bool get tieneTicket => ticket != null && ticket!.isNotEmpty;
  bool get tienePrecio => precioUnitario != null && precioUnitario! > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OperacionComercialDetalle &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              operacionComercialId == other.operacionComercialId;

  @override
  int get hashCode => id.hashCode ^ operacionComercialId.hashCode;

  @override
  String toString() {
    return 'OperacionComercialDetalle{id: $id, productoId: $productoId, cantidad: $cantidad, reemplazoId: $productoReemplazoId}';
  }
}
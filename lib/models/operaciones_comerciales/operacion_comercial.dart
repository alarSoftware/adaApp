// lib/models/operaciones_comerciales/operacion_comercial.dart
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';

class OperacionComercial {
  final String? id;
  final int clienteId;
  final TipoOperacion tipoOperacion;
  final DateTime fechaCreacion;
  final DateTime? fechaRetiro;
  final EstadoOperacion estado;
  final String? observaciones;
  final int totalProductos;
  final int? usuarioId;
  final bool estaSincronizado;
  final DateTime? fechaSincronizacion;
  final int? serverId;
  final String syncStatus;
  final int intentosSync;
  final DateTime? ultimoIntentoSync;
  final String? mensajeErrorSync;

  // ✅ CAMPO CALCULADO - NO VA A LA BASE DE DATOS
  final List<OperacionComercialDetalle> detalles;

  const OperacionComercial({
    this.id,
    required this.clienteId,
    required this.tipoOperacion,
    required this.fechaCreacion,
    this.fechaRetiro,
    this.estado = EstadoOperacion.borrador,
    this.observaciones,
    this.totalProductos = 0,
    this.usuarioId,
    this.estaSincronizado = false,
    this.fechaSincronizacion,
    this.serverId,
    this.syncStatus = 'pending',
    this.intentosSync = 0,
    this.ultimoIntentoSync,
    this.mensajeErrorSync,
    this.detalles = const [],
  });

  factory OperacionComercial.fromMap(Map<String, dynamic> map) {
    return OperacionComercial(
      id: map['id'] as String?,
      clienteId: map['cliente_id'] as int? ?? 0,
      tipoOperacion: TipoOperacionExtension.fromString(map['tipo_operacion'] as String?),
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaRetiro: map['fecha_retiro'] != null
          ? DateTime.parse(map['fecha_retiro'] as String)
          : null,
      estado: EstadoOperacionExtension.fromString(map['estado'] as String?),
      observaciones: map['observaciones'] as String?,
      totalProductos: map['total_productos'] as int? ?? 0,
      usuarioId: map['usuario_id'] as int?,
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'] as String)
          : null,
      serverId: map['server_id'] as int?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      intentosSync: map['intentos_sync'] as int? ?? 0,
      ultimoIntentoSync: map['ultimo_intento_sync'] != null
          ? DateTime.parse(map['ultimo_intento_sync'] as String)
          : null,
      mensajeErrorSync: map['mensaje_error_sync'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'tipo_operacion': tipoOperacion.valor,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'estado': estado.valor,
      'observaciones': observaciones,
      'total_productos': totalProductos,
      'usuario_id': usuarioId,
      'sincronizado': estaSincronizado ? 1 : 0,
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
      'server_id': serverId,
      'sync_status': syncStatus,
      'intentos_sync': intentosSync,
      'ultimo_intento_sync': ultimoIntentoSync?.toIso8601String(),
      'mensaje_error_sync': mensajeErrorSync,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'tipo_operacion': tipoOperacion.valor,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'estado': estado.valor,
      'observaciones': observaciones,
      'detalles': detalles.map((d) => d.toJson()).toList(),
    };
  }

  OperacionComercial copyWith({
    String? id,
    int? clienteId,
    TipoOperacion? tipoOperacion,
    DateTime? fechaCreacion,
    DateTime? fechaRetiro,
    EstadoOperacion? estado,
    String? observaciones,
    int? totalProductos,
    int? usuarioId,
    bool? estaSincronizado,
    DateTime? fechaSincronizacion,
    int? serverId,
    String? syncStatus,
    int? intentosSync,
    DateTime? ultimoIntentoSync,
    String? mensajeErrorSync,
    List<OperacionComercialDetalle>? detalles,
  }) {
    return OperacionComercial(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      totalProductos: totalProductos ?? this.totalProductos,
      usuarioId: usuarioId ?? this.usuarioId,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      fechaSincronizacion: fechaSincronizacion ?? this.fechaSincronizacion,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      intentosSync: intentosSync ?? this.intentosSync,
      ultimoIntentoSync: ultimoIntentoSync ?? this.ultimoIntentoSync,
      mensajeErrorSync: mensajeErrorSync ?? this.mensajeErrorSync,
      detalles: detalles ?? this.detalles,
    );
  }

  // Getters útiles
  bool get esBorrador => estado == EstadoOperacion.borrador;
  bool get estaPendiente => estado == EstadoOperacion.pendiente;
  bool get fueEnviado => estado == EstadoOperacion.enviado;
  bool get estaSinc => estaSincronizado || estado == EstadoOperacion.sincronizado;
  bool get tieneError => estado == EstadoOperacion.error || syncStatus == 'error';
  bool get tieneDetalles => detalles.isNotEmpty;
  bool get necesitaFechaRetiro =>
      tipoOperacion == TipoOperacion.notaRetiro ||
          tipoOperacion == TipoOperacion.notaRetiroDiscontinuos;

  String get displayTipo => tipoOperacion.displayName;
  String get displayEstado => estado.displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OperacionComercial &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              clienteId == other.clienteId &&
              tipoOperacion == other.tipoOperacion;

  @override
  int get hashCode => id.hashCode ^ clienteId.hashCode ^ tipoOperacion.hashCode;

  @override
  String toString() {
    return 'OperacionComercial{id: $id, tipo: ${tipoOperacion.valor}, cliente: $clienteId, estado: ${estado.valor}, detalles: ${detalles.length}, sync: $syncStatus}';
  }
}
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionComercial {
  final String? id;
  final int clienteId;
  final TipoOperacion tipoOperacion;
  final DateTime fechaCreacion;
  final DateTime? fechaRetiro;
  final String? snc;
  final String? observaciones;
  final int totalProductos;
  final int? usuarioId;
  final int? serverId;
  final String syncStatus;
  final String? syncError;
  final DateTime? syncedAt;
  final int syncRetryCount;
  final String? edfVendedorId;
  final double? latitud;
  final double? longitud;

  final List<OperacionComercialDetalle> detalles;

  const OperacionComercial({
    this.id,
    required this.clienteId,
    required this.tipoOperacion,
    required this.fechaCreacion,
    this.fechaRetiro,
    this.snc,
    this.observaciones,
    this.totalProductos = 0,
    this.usuarioId,
    this.serverId,
    this.syncStatus = 'creado',
    this.syncError,
    this.syncedAt,
    this.syncRetryCount = 0,
    this.edfVendedorId,
    this.latitud,
    this.longitud,
    this.detalles = const [],
  });

  factory OperacionComercial.fromMap(Map<String, dynamic> map) {
    return OperacionComercial(
      id: map['id'] as String?,
      clienteId: map['cliente_id'] as int? ?? 0,
      tipoOperacion: TipoOperacionExtension.fromString(
        map['tipo_operacion'] as String?,
      ),
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaRetiro: map['fecha_retiro'] != null
          ? DateTime.parse(map['fecha_retiro'] as String)
          : null,
      snc: map['snc'] as String?,
      observaciones: map['observaciones'] as String?,
      totalProductos: map['total_productos'] as int? ?? 0,
      usuarioId: map['usuario_id'] as int?,
      serverId: map['server_id'] as int?,
      syncStatus: map['sync_status'] as String? ?? 'creado',
      syncError: map['sync_error'] as String?,
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      syncRetryCount: map['sync_retry_count'] as int? ?? 0,
      edfVendedorId: map['edf_vendedor_id'] as String?,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'tipo_operacion': tipoOperacion.valor,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      if (snc != null) 'snc': snc,
      'observaciones': observaciones,
      'total_productos': totalProductos,
      'usuario_id': usuarioId,
      'server_id': serverId,
      'sync_status': syncStatus,
      'sync_error': syncError,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_retry_count': syncRetryCount,
      'edf_vendedor_id': edfVendedorId,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'tipo_operacion': tipoOperacion.valor,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      if (snc != null) 'snc': snc,
      'observaciones': observaciones,
      'edf_vendedor_id': edfVendedorId,
      'latitud': latitud,
      'longitud': longitud,
      'detalles': detalles.map((d) => d.toJson()).toList(),
    };
  }

  OperacionComercial copyWith({
    String? id,
    int? clienteId,
    TipoOperacion? tipoOperacion,
    DateTime? fechaCreacion,
    DateTime? fechaRetiro,
    String? snc,
    String? observaciones,
    int? totalProductos,
    int? usuarioId,
    int? serverId,
    String? syncStatus,
    String? syncError,
    DateTime? syncedAt,
    int? syncRetryCount,
    String? edfVendedorId,
    double? latitud,
    double? longitud,
    List<OperacionComercialDetalle>? detalles,
  }) {
    return OperacionComercial(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      snc: snc ?? this.snc,
      observaciones: observaciones ?? this.observaciones,
      totalProductos: totalProductos ?? this.totalProductos,
      usuarioId: usuarioId ?? this.usuarioId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncedAt: syncedAt ?? this.syncedAt,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      edfVendedorId: edfVendedorId ?? this.edfVendedorId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      detalles: detalles ?? this.detalles,
    );
  }

  // Getters útiles basados en syncStatus
  bool get estaSincronizado => syncStatus == 'migrado';
  bool get tieneError => syncStatus == 'error';
  bool get estaPendiente => syncStatus == 'creado';
  bool get tieneDetalles => detalles.isNotEmpty;
  bool get necesitaFechaRetiro =>
      tipoOperacion == TipoOperacion.notaRetiro ||
      tipoOperacion == TipoOperacion.notaRetiroDiscontinuos;

  String get displayTipo => tipoOperacion.displayName;
  String get displaySyncStatus {
    switch (syncStatus) {
      case 'creado':
        return 'Pendiente';
      case 'migrado':
        return 'Sincronizado';
      case 'error':
        return 'Error';
      default:
        return syncStatus;
    }
  }

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
    return 'OperacionComercial{id: $id, tipo: ${tipoOperacion.valor}, cliente: $clienteId, snc: $snc, detalles: ${detalles.length}, sync: $syncStatus, retries: $syncRetryCount}';
  }
}

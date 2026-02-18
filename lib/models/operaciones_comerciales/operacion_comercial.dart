import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionComercial {
  final String? id;
  final int clienteId;
  final TipoOperacion tipoOperacion;
  final DateTime fechaCreacion;
  final DateTime? fechaRetiro;
  final String? snc;
  final int totalProductos;
  final int? usuarioId;
  final int? serverId;
  final String syncStatus;
  final String? syncError;
  final DateTime? syncedAt;
  final int syncRetryCount;
  final String? employeeId;
  final double? latitud;
  final double? longitud;
  final String? odooName;
  final String? adaSequence;
  final String? estadoPortal;
  final String? estadoMotivoPortal;
  final String? estadoOdoo;
  final String? motivoOdoo;
  final String? ordenTransporteOdoo;
  final String? adaEstado;

  final List<OperacionComercialDetalle> detalles;

  const OperacionComercial({
    this.id,
    required this.clienteId,
    required this.tipoOperacion,
    required this.fechaCreacion,
    this.fechaRetiro,
    this.snc,
    this.totalProductos = 0,
    this.usuarioId,
    this.serverId,
    this.syncStatus = 'creado',
    this.syncError,
    this.syncedAt,
    this.syncRetryCount = 0,
    this.employeeId,
    this.latitud,
    this.longitud,
    this.odooName,
    this.adaSequence,
    this.estadoPortal,
    this.estadoMotivoPortal,
    this.estadoOdoo,
    this.motivoOdoo,
    this.ordenTransporteOdoo,
    this.adaEstado,
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
      totalProductos: map['total_productos'] as int? ?? 0,
      usuarioId: map['usuario_id'] as int?,
      serverId: map['server_id'] as int?,
      syncStatus: map['sync_status'] as String? ?? 'creado',
      syncError: map['sync_error'] as String?,
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      syncRetryCount: map['sync_retry_count'] as int? ?? 0,
      employeeId: map['employee_id'] as String?,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      odooName: map['odoo_name'] as String?,
      adaSequence: map['ada_sequence'] as String?,
      estadoPortal: map['estado_portal'] as String?,
      estadoMotivoPortal: map['estado_motivo_portal'] as String?,
      estadoOdoo: map['estado_odoo'] as String?,
      motivoOdoo: map['motivo_odoo'] as String?,
      ordenTransporteOdoo: map['orden_transporte_odoo'] as String?,
      adaEstado: map['ada_estado'] as String?,
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
      'total_productos': totalProductos,
      'usuario_id': usuarioId,
      'server_id': serverId,
      'sync_status': syncStatus,
      'sync_error': syncError,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_retry_count': syncRetryCount,
      'employee_id': employeeId,
      'latitud': latitud,
      'longitud': longitud,
      'odoo_name': odooName,
      'ada_sequence': adaSequence,
      'estado_portal': estadoPortal,
      'estado_motivo_portal': estadoMotivoPortal,
      'estado_odoo': estadoOdoo,
      'motivo_odoo': motivoOdoo,
      'orden_transporte_odoo': ordenTransporteOdoo,
      'ada_estado': adaEstado,
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
      'employee_id': employeeId,
      'latitud': latitud,
      'longitud': longitud,
      'odoo_name': odooName,
      'ada_sequence': adaSequence,
      'estado_portal': estadoPortal,
      'estado_motivo_portal': estadoMotivoPortal,
      'estado_odoo': estadoOdoo,
      'motivo_odoo': motivoOdoo,
      'orden_transporte_odoo': ordenTransporteOdoo,
      'ada_estado': adaEstado,
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
    int? totalProductos,
    int? usuarioId,
    int? serverId,
    String? syncStatus,
    String? syncError,
    DateTime? syncedAt,
    int? syncRetryCount,
    String? employeeId,
    double? latitud,
    double? longitud,
    String? odooName,
    String? adaSequence,
    String? estadoPortal,
    String? estadoMotivoPortal,
    String? estadoOdoo,
    String? motivoOdoo,
    String? ordenTransporteOdoo,
    String? adaEstado,
    List<OperacionComercialDetalle>? detalles,
  }) {
    return OperacionComercial(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      snc: snc ?? this.snc,
      totalProductos: totalProductos ?? this.totalProductos,
      usuarioId: usuarioId ?? this.usuarioId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncedAt: syncedAt ?? this.syncedAt,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
      employeeId: employeeId ?? this.employeeId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      odooName: odooName ?? this.odooName,
      adaSequence: adaSequence ?? this.adaSequence,
      estadoPortal: estadoPortal ?? this.estadoPortal,
      estadoMotivoPortal: estadoMotivoPortal ?? this.estadoMotivoPortal,
      estadoOdoo: estadoOdoo ?? this.estadoOdoo,
      motivoOdoo: motivoOdoo ?? this.motivoOdoo,
      ordenTransporteOdoo: ordenTransporteOdoo ?? this.ordenTransporteOdoo,
      adaEstado: adaEstado ?? this.adaEstado,
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
}

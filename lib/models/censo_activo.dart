enum EstadoEquipoCenso { creado, migrado, error }

extension EstadoEquipoCensoExtension on EstadoEquipoCenso {
  String get valor {
    switch (this) {
      case EstadoEquipoCenso.creado:
        return 'creado';
      case EstadoEquipoCenso.migrado:
        return 'migrado';
      case EstadoEquipoCenso.error:
        return 'error';
    }
  }

  static EstadoEquipoCenso fromString(String? estado) {
    if (estado == null) return EstadoEquipoCenso.creado;

    switch (estado.toLowerCase()) {
      case 'creado':
        return EstadoEquipoCenso.creado;
      case 'migrado':
        return EstadoEquipoCenso.migrado;
      case 'error':
        return EstadoEquipoCenso.error;
      default:
        return EstadoEquipoCenso.creado;
    }
  }
}

class CensoActivo {
  final String? id;
  final String? employeeId;
  final String equipoId;
  final int clienteId;
  final int? usuarioId;
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final DateTime fechaRevision;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final String? estadoCenso;
  final String? observaciones;
  final int intentosSync;
  final DateTime? ultimoIntento;
  final String? errorMensaje;

  CensoActivo({
    this.id,
    this.employeeId,
    required this.equipoId,
    required this.clienteId,
    this.usuarioId,
    required this.enLocal,
    this.latitud,
    this.longitud,
    required this.fechaRevision,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estadoCenso,
    this.observaciones,
    this.intentosSync = 0,
    this.ultimoIntento,
    this.errorMensaje,
  });

  factory CensoActivo.fromMap(Map<String, dynamic> map) {
    return CensoActivo(
      id: map['id'] as String?,
      employeeId: map['employee_id'],
      equipoId: map['equipo_id'] as String? ?? '0',
      clienteId: map['cliente_id'] as int? ?? 0,
      usuarioId: map['usuario_id'] as int?,
      enLocal: (map['en_local'] as int?) == 1,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      fechaRevision: map['fecha_revision'] != null
          ? DateTime.parse(map['fecha_revision'] as String)
          : DateTime.now(),
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      estadoCenso: map['estado_censo'] as String?,
      observaciones: map['observaciones'] as String?,
      intentosSync: map['intentos_sync'] as int? ?? 0,
      ultimoIntento: map['ultimo_intento'] != null
          ? DateTime.parse(map['ultimo_intento'] as String)
          : null,
      errorMensaje: map['error_mensaje'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'en_local': enLocal ? 1 : 0,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'estado_censo': estadoCenso,
      'observaciones': observaciones,
      'intentos_sync': intentosSync,
      'ultimo_intento': ultimoIntento?.toIso8601String(),
      'error_mensaje': errorMensaje,
      'employee_id': employeeId,
    };

    if (estadoCenso != null) {
      map['estado_censo'] = estadoCenso;
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'en_local': enLocal,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'estado_censo': estadoCenso,
      'observaciones': observaciones,
      'intentos_sync': intentosSync,
      'ultimo_intento': ultimoIntento?.toIso8601String(),
      'error_mensaje': errorMensaje,
    };
  }

  CensoActivo copyWith({
    String? id,
    String? equipoId,
    int? clienteId,
    int? usuarioId,
    bool? enLocal,
    double? latitud,
    double? longitud,
    DateTime? fechaRevision,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? estadoCenso,
    String? observaciones,
    int? intentosSync,
    DateTime? ultimoIntento,
    String? errorMensaje,
  }) {
    return CensoActivo(
      id: id ?? this.id,
      equipoId: equipoId ?? this.equipoId,
      clienteId: clienteId ?? this.clienteId,
      usuarioId: usuarioId ?? this.usuarioId,
      enLocal: enLocal ?? this.enLocal,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estadoCenso: estadoCenso ?? this.estadoCenso,
      observaciones: observaciones ?? this.observaciones,
      intentosSync: intentosSync ?? this.intentosSync,
      ultimoIntento: ultimoIntento ?? this.ultimoIntento,
      errorMensaje: errorMensaje ?? this.errorMensaje,
    );
  }

  // Estados del censo

  bool get estaCreado => estadoCenso == EstadoEquipoCenso.creado.valor;
  bool get estaMigrado => estadoCenso == EstadoEquipoCenso.migrado.valor;
  bool get tieneError => estadoCenso == EstadoEquipoCenso.error.valor;

  // Helpers para reintentos

  bool get puedeReintentar {
    if (ultimoIntento == null) return true;
    final minutos = _calcularEsperaMinutos(intentosSync);
    final proximoIntento = ultimoIntento!.add(Duration(minutes: minutos));
    return DateTime.now().isAfter(proximoIntento);
  }

  int _calcularEsperaMinutos(int intentos) {
    switch (intentos) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 5;
      case 3:
        return 10;
      default:
        return 30;
    }
  }
}

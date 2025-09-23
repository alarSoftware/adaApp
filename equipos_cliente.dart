import 'package:flutter/material.dart';

enum EstadoEquipoCliente {
  pendiente('pendiente'),
  asignado('asignado');

  const EstadoEquipoCliente(this.valor);
  final String valor;

  static EstadoEquipoCliente fromString(String valor) {
    return EstadoEquipoCliente.values.firstWhere(
          (estado) => estado.valor == valor,
      orElse: () => throw Exception('Estado desconocido: $valor'),
    );
  }

}

class EquipoCliente {
  final int? id;
  final int equipoId;
  final int clienteId;
  final EstadoEquipoCliente estado; // NUEVO CAMPO
  final DateTime fechaAsignacion;
  final DateTime? fechaRetiro;
  final bool estaActivo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;
  final bool? enLocal; // Campo agregado para control de ubicación

  // Propiedades opcionales para datos relacionados (cuando se hace JOIN)
  final String? equipoNombre;
  final String? equipoMarca;
  final String? equipoModelo;
  final String? equipoCodBarras;
  final String? clienteNombre;
  final String? clienteTelefono;

  EquipoCliente({
    this.id,
    required this.equipoId,
    required this.clienteId,
    this.estado = EstadoEquipoCliente.pendiente, // DEFAULT pendiente
    required this.fechaAsignacion,
    this.fechaRetiro,
    this.estaActivo = true,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estaSincronizado = false,
    this.enLocal, // Campo agregado
    // Datos relacionados opcionales
    this.equipoNombre,
    this.equipoMarca,
    this.equipoModelo,
    this.equipoCodBarras,
    this.clienteNombre,
    this.clienteTelefono,
  });

  // ════════════════════════════════════════════════════════════════════════════════════
  // FACTORY CONSTRUCTORS
  // ════════════════════════════════════════════════════════════════════════════════════

  /// Crear desde Map (base de datos local)
  factory EquipoCliente.fromMap(Map<String, dynamic> map) {
    return EquipoCliente(
      id: map['id'] as int?,
      equipoId: map['equipo_id'] as int,
      clienteId: map['cliente_id'] as int,
      estado: EstadoEquipoCliente.fromString(map['estado'] as String? ?? 'pendiente'),
      fechaAsignacion: DateTime.parse(map['fecha_asignacion'] as String),
      fechaRetiro: map['fecha_retiro'] != null
          ? DateTime.parse(map['fecha_retiro'] as String)
          : null,
      estaActivo: (map['activo'] as int?) == 1,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      enLocal: map['en_local'] != null
          ? (map['en_local'] as int?) == 1
          : null,
      // Datos relacionados (para JOINs)
      equipoNombre: map['equipo_nombre'] as String?,
      equipoMarca: map['equipo_marca'] as String?,
      equipoModelo: map['equipo_modelo'] as String?,
      equipoCodBarras: map['equipo_cod_barras'] as String?,
      clienteNombre: map['cliente_nombre'] as String?,
      clienteTelefono: map['cliente_telefono'] as String?,
    );
  }

  /// Crear desde JSON (API)
  factory EquipoCliente.fromJson(Map<String, dynamic> json) {
    return EquipoCliente(
      id: json['id'] as int?,
      equipoId: json['equipo_id'] as int,
      clienteId: json['cliente_id'] as int,
      estado: EstadoEquipoCliente.fromString(json['estado'] as String? ?? 'pendiente'), // NUEVO
      fechaAsignacion: DateTime.parse(json['fecha_asignacion'] as String),
      fechaRetiro: json['fecha_retiro'] != null
          ? DateTime.parse(json['fecha_retiro'] as String)
          : null,
      estaActivo: json['activo'] as bool? ?? true,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'] as String)
          : DateTime.now(),
      fechaActualizacion: json['fecha_actualizacion'] != null
          ? DateTime.parse(json['fecha_actualizacion'] as String)
          : null,
      estaSincronizado: json['sincronizado'] as bool? ?? true, // Viene de API = sincronizado
      enLocal: json['en_local'] as bool?,
      // Datos relacionados del JSON
      equipoNombre: json['equipo_nombre'] as String?,
      equipoMarca: json['equipo_marca'] as String?,
      equipoModelo: json['equipo_modelo'] as String?,
      equipoCodBarras: json['equipo_cod_barras'] as String?,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE CONVERSIÓN
  // ════════════════════════════════════════════════════════════════════════════════════

  /// Convertir a Map (para base de datos local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'estado': estado.valor, // NUEVO
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'activo': estaActivo ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
      //'en_local': enLocal != null ? (enLocal! ? 1 : 0) : null,
    };
  }

  /// Convertir a JSON (para enviar a API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'estado': estado.valor, // NUEVO
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'activo': estaActivo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'en_local': enLocal,
    };
  }

  // ════════════════════════════════════════════════════════════════════════════════════
  // MÉTODOS ÚTILES
  // ════════════════════════════════════════════════════════════════════════════════════

  /// Copiar con modificaciones
  EquipoCliente copyWith({
    int? id,
    int? equipoId,
    int? clienteId,
    EstadoEquipoCliente? estado, // NUEVO
    DateTime? fechaAsignacion,
    DateTime? fechaRetiro,
    bool? estaActivo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
    bool? enLocal,
    String? equipoNombre,
    String? equipoMarca,
    String? equipoModelo,
    String? equipoCodBarras,
    String? clienteNombre,
    String? clienteTelefono,
  }) {
    return EquipoCliente(
      id: id ?? this.id,
      equipoId: equipoId ?? this.equipoId,
      clienteId: clienteId ?? this.clienteId,
      estado: estado ?? this.estado, // NUEVO
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      estaActivo: estaActivo ?? this.estaActivo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      enLocal: enLocal ?? this.enLocal,
      equipoNombre: equipoNombre ?? this.equipoNombre,
      equipoMarca: equipoMarca ?? this.equipoMarca,
      equipoModelo: equipoModelo ?? this.equipoModelo,
      equipoCodBarras: equipoCodBarras ?? this.equipoCodBarras,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
    );
  }

  /// Verificar si la asignación está activa
  bool get asignacionActiva => estaActivo && fechaRetiro == null;

  /// Verificar si el equipo está pendiente
  bool get estaPendiente => estado == EstadoEquipoCliente.pendiente;

  /// Verificar si el equipo está asignado
  bool get estaAsignado => estado == EstadoEquipoCliente.asignado;

  /// Obtener duración de la asignación
  Duration get duracionAsignacion {
    final fechaFin = fechaRetiro ?? DateTime.now();
    return fechaFin.difference(fechaAsignacion);
  }

  /// Obtener días desde la asignación
  int get diasDesdeAsignacion => DateTime.now().difference(fechaAsignacion).inDays;

  /// Nombre completo del equipo (si está disponible)
  String get equipoNombreCompleto {
    if (equipoMarca != null && equipoModelo != null) {
      return '$equipoMarca $equipoModelo';
    }
    if (equipoNombre != null) {
      return equipoNombre!;
    }
    return 'Equipo #$equipoId';
  }

  /// Nombre del cliente (si está disponible)
  String get clienteNombreCompleto {
    return clienteNombre ?? 'Cliente #$clienteId';
  }

  /// Estado de la asignación como texto
  String get estadoTexto {
    if (!estaActivo) return 'Inactiva';
    if (fechaRetiro != null) return 'Retirada';
    return estado == EstadoEquipoCliente.asignado ? 'Asignado' : 'Pendiente';
  }

  /// Estado de ubicación como texto
  String get ubicacionTexto {
    if (enLocal == null) return 'No especificado';
    return enLocal! ? 'En local' : 'Fuera del local';
  }

  /// Color según el estado ACTUALIZADO
  Color get colorEstado {
    if (!estaActivo) return const Color(0xFF9E9E9E); // Gris
    if (fechaRetiro != null) return const Color(0xFFFF9800); // Naranja

    // Colores según el nuevo estado
    switch (estado) {
      case EstadoEquipoCliente.asignado:
        return const Color(0xFF4CAF50); // Verde para asignado
      case EstadoEquipoCliente.pendiente:
        return const Color(0xFFFFC107); // Amarillo para pendiente
    }
  }

  /// Color según la ubicación
  Color get colorUbicacion {
    if (enLocal == null) return const Color(0xFF9E9E9E); // Gris para no especificado
    return enLocal!
        ? const Color(0xFF4CAF50) // Verde para en local
        : const Color(0xFFFFC107); // Amarillo para fuera del local
  }

  /// Verificar si el equipo está disponible para operaciones
  bool get estaDisponible {
    return asignacionActiva && estaAsignado && (enLocal ?? false);
  }

  @override
  String toString() {
    return 'EquipoCliente(id: $id, equipoId: $equipoId, clienteId: $clienteId, '
        'estado: ${estado.valor}, fechaAsignacion: $fechaAsignacion, activo: $estaActivo, enLocal: $enLocal, '
        'equipo: $equipoNombreCompleto, cliente: $clienteNombreCompleto)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EquipoCliente &&
        other.id == id &&
        other.equipoId == equipoId &&
        other.clienteId == clienteId &&
        other.fechaAsignacion == fechaAsignacion;
  }

  @override
  int get hashCode {
    return Object.hash(id, equipoId, clienteId, fechaAsignacion);
  }
}
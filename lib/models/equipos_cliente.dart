import 'package:flutter/material.dart';
class EquipoCliente {
  final int? id;
  final int equipoId;
  final int clienteId;
  final DateTime fechaAsignacion;
  final DateTime? fechaRetiro;
  final bool estaActivo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;

  // Propiedades opcionales para datos relacionados (cuando se hace JOIN)
  final String? equipoNombre;
  final String? equipoMarca;
  final String? equipoModelo;
  final String? equipoCodBarras;
  final String? clienteNombre;
  final String? clienteEmail;
  final String? clienteTelefono;

  EquipoCliente({
    this.id,
    required this.equipoId,
    required this.clienteId,
    required this.fechaAsignacion,
    this.fechaRetiro,
    this.estaActivo = true,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estaSincronizado = false,
    // Datos relacionados opcionales
    this.equipoNombre,
    this.equipoMarca,
    this.equipoModelo,
    this.equipoCodBarras,
    this.clienteNombre,
    this.clienteEmail,
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
      // Datos relacionados (para JOINs)
      equipoNombre: map['equipo_nombre'] as String?,
      equipoMarca: map['equipo_marca'] as String?,
      equipoModelo: map['equipo_modelo'] as String?,
      equipoCodBarras: map['equipo_cod_barras'] as String?,
      clienteNombre: map['cliente_nombre'] as String?,
      clienteEmail: map['cliente_email'] as String?,
      clienteTelefono: map['cliente_telefono'] as String?,
    );
  }

  /// Crear desde JSON (API)
  factory EquipoCliente.fromJson(Map<String, dynamic> json) {
    return EquipoCliente(
      id: json['id'] as int?,
      equipoId: json['equipo_id'] as int,
      clienteId: json['cliente_id'] as int,
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
      // Datos relacionados del JSON
      equipoNombre: json['equipo_nombre'] as String?,
      equipoMarca: json['equipo_marca'] as String?,
      equipoModelo: json['equipo_modelo'] as String?,
      equipoCodBarras: json['equipo_cod_barras'] as String?,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteEmail: json['cliente_email'] as String?,
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
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'activo': estaActivo ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
    };
  }

  /// Convertir a JSON (para enviar a API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_retiro': fechaRetiro?.toIso8601String(),
      'activo': estaActivo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
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
    DateTime? fechaAsignacion,
    DateTime? fechaRetiro,
    bool? estaActivo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
    String? equipoNombre,
    String? equipoMarca,
    String? equipoModelo,
    String? equipoCodBarras,
    String? clienteNombre,
    String? clienteEmail,
    String? clienteTelefono,
  }) {
    return EquipoCliente(
      id: id ?? this.id,
      equipoId: equipoId ?? this.equipoId,
      clienteId: clienteId ?? this.clienteId,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      fechaRetiro: fechaRetiro ?? this.fechaRetiro,
      estaActivo: estaActivo ?? this.estaActivo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      equipoNombre: equipoNombre ?? this.equipoNombre,
      equipoMarca: equipoMarca ?? this.equipoMarca,
      equipoModelo: equipoModelo ?? this.equipoModelo,
      equipoCodBarras: equipoCodBarras ?? this.equipoCodBarras,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
    );
  }

  /// Verificar si la asignación está activa
  bool get asignacionActiva => estaActivo && fechaRetiro == null;

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
    return 'Activa';
  }

  /// Color según el estado
  /// Útil para mostrar en la UI
  Color get colorEstado {
    if (!estaActivo) return const Color(0xFF9E9E9E); // Gris
    if (fechaRetiro != null) return const Color(0xFFFF9800); // Naranja
    return const Color(0xFF4CAF50); // Verde
  }

  @override
  String toString() {
    return 'EquipoCliente(id: $id, equipoId: $equipoId, clienteId: $clienteId, '
        'fechaAsignacion: $fechaAsignacion, activo: $estaActivo, '
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

// CLASE PARA RESPUESTAS DE LA API

class BusquedaResponseEquipoCliente {
  final bool exito;
  final String mensaje;
  final List<EquipoCliente> asignaciones;
  final int total;
  final int pagina;
  final int totalPaginas;
  final int? codigoEstado;

  BusquedaResponseEquipoCliente({
    required this.exito,
    required this.mensaje,
    required this.asignaciones,
    this.total = 0,
    this.pagina = 1,
    this.totalPaginas = 1,
    this.codigoEstado,
  });

  @override
  String toString() {
    return 'BusquedaResponseEquipoCliente{exito: $exito, mensaje: $mensaje, '
        'asignaciones: ${asignaciones.length}, total: $total}';
  }
}


// EJEMPLO DE USO
/*
// Crear desde JSON de la API
final jsonData = {
  "id": 1,
  "equipo_id": 14,
  "cliente_id": 3,
  "fecha_asignacion": "2024-08-20T18:30:00.000Z",
  "fecha_retiro": null,
  "activo": true
};

final asignacion = EquipoCliente.fromJson(jsonData);

// Usar las propiedades
print(asignacion.equipoNombreCompleto); // "Equipo #14"
print(asignacion.estadoTexto); // "Activa"
print(asignacion.diasDesdeAsignacion); // Número de días
print(asignacion.asignacionActiva); // true

// Convertir para la base de datos
final mapParaBD = asignacion.toMap();

// Crear copia con modificaciones
final asignacionRetirada = asignacion.copyWith(
  fechaRetiro: DateTime.now(),
  estaActivo: false,
);
*/
class EquiposPendientes {
  final String? id;                     // 🔧 Cambiar de int? a String?
  final String equipoId;                // 🔧 Cambiar de int a String
  final String clienteId;               // 🔧 Cambiar de int a String
  final DateTime fechaCenso;
  final int usuarioCensoId;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool sincronizado;              // 🆕 AGREGAR
  final DateTime? fechaSincronizacion;  // 🆕 AGREGAR
  final int intentosSync;               // 🆕 AGREGAR
  final DateTime? ultimoIntento;        // 🆕 AGREGAR
  final String? errorMensaje;           // 🆕 AGREGAR

  // Campos adicionales para JOINs
  final String? codBarras;
  final String? numeroSerie;
  final String? marcaNombre;
  final String? modeloNombre;
  final String? logoNombre;
  final String? clienteNombre;

  EquiposPendientes({
    this.id,
    required this.equipoId,
    required this.clienteId,
    required this.fechaCenso,
    required this.usuarioCensoId,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.sincronizado = false,                    // 🆕 AGREGAR
    this.fechaSincronizacion,                     // 🆕 AGREGAR
    this.intentosSync = 0,                        // 🆕 AGREGAR
    this.ultimoIntento,                           // 🆕 AGREGAR
    this.errorMensaje,                            // 🆕 AGREGAR
    this.codBarras,
    this.numeroSerie,
    this.marcaNombre,
    this.modeloNombre,
    this.logoNombre,
    this.clienteNombre,
  });

  factory EquiposPendientes.fromMap(Map<String, dynamic> map) {
    return EquiposPendientes(
      id: map['id'] as String?,
      equipoId: map['equipo_id'] as String,
      clienteId: map['cliente_id'] as String,
      fechaCenso: DateTime.parse(map['fecha_censo'] as String),
      usuarioCensoId: map['usuario_censo_id'] as int,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'] as String)
          : null,
      sincronizado: (map['sincronizado'] as int?) == 1,                           // 🆕 AGREGAR
      fechaSincronizacion: map['fecha_sincronizacion'] != null                    // 🆕 AGREGAR
          ? DateTime.parse(map['fecha_sincronizacion'] as String)
          : null,
      intentosSync: map['intentos_sync'] as int? ?? 0,                            // 🆕 AGREGAR
      ultimoIntento: map['ultimo_intento'] != null                                // 🆕 AGREGAR
          ? DateTime.parse(map['ultimo_intento'] as String)
          : null,
      errorMensaje: map['error_mensaje'] as String?,                              // 🆕 AGREGAR
      codBarras: map['cod_barras'] as String?,
      numeroSerie: map['numero_serie'] as String?,
      marcaNombre: map['marca_nombre'] as String?,
      modeloNombre: map['modelo_nombre'] as String?,
      logoNombre: map['logo_nombre'] as String?,
      clienteNombre: map['cliente_nombre'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'cliente_id': clienteId,
      'fecha_censo': fechaCenso.toIso8601String(),
      'usuario_censo_id': usuarioCensoId,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,                                        // 🆕 AGREGAR
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),             // 🆕 AGREGAR
      'intentos_sync': intentosSync,                                               // 🆕 AGREGAR
      'ultimo_intento': ultimoIntento?.toIso8601String(),                         // 🆕 AGREGAR
      'error_mensaje': errorMensaje,                                               // 🆕 AGREGAR
    };
  }

  // 🆕 AGREGAR Helpers
  bool get necesitaSincronizar => !sincronizado;
  bool get tieneError => errorMensaje != null && errorMensaje!.isNotEmpty;
}
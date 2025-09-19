class Equipo {
  final int? id;
  final String codBarras;
  final int marcaId;
  final int modeloId;  // CAMBIADO: de String modelo a int modeloId
  final String? numeroSerie;
  final int logoId;
  final int estadoLocal;
  final int activo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final int sincronizado;

  // Campos adicionales para JOIN (no se almacenan en DB)
  final String? marcaNombre;
  final String? modeloNombre;  // CAMBIADO: de logoNombre duplicado
  final String? logoNombre;

  Equipo({
    this.id,
    required this.codBarras,
    required this.marcaId,
    required this.modeloId,  // CAMBIADO
    this.numeroSerie,
    required this.logoId,
    this.estadoLocal = 1,
    this.activo = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.sincronizado = 0,
    this.marcaNombre,
    this.modeloNombre,  // CAMBIADO
    this.logoNombre,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'],
      codBarras: map['cod_barras'] ?? '',
      marcaId: map['marca_id'] ?? 1,
      modeloId: map['modelo_id'] ?? 1,  // CAMBIADO
      numeroSerie: map['numero_serie'],
      logoId: map['logo_id'] ?? 1,
      estadoLocal: map['estado_local'] ?? 1,
      activo: map['activo'] ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
      sincronizado: map['sincronizado'] ?? 0,
      marcaNombre: map['marca_nombre'], // Para JOINs
      modeloNombre: map['modelo_nombre'], // CAMBIADO
      logoNombre: map['logo_nombre'],   // Para JOINs
    );
  }

  factory Equipo.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir a int de forma segura
    int _safeParseInt(dynamic value, {int defaultValue = 1}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    DateTime fecha;
    DateTime? fechaAct;

    try {
      fecha = DateTime.parse(
          json['fecha_creacion'] ??
              json['fechaCreacion'] ??
              json['fecha'] ??
              DateTime.now().toIso8601String()
      );
    } catch (_) {
      fecha = DateTime.now();
    }

    try {
      if (json['fecha_actualizacion'] != null || json['fechaActualizacion'] != null) {
        fechaAct = DateTime.parse(
            json['fecha_actualizacion'] ?? json['fechaActualizacion']
        );
      }
    } catch (_) {
      fechaAct = null;
    }

    return Equipo(
      // ← ID: No uses json['id'] porque es string, mejor genera uno o usa null
      id: null, // La BD asignará el ID automáticamente

      // ← EL CÓDIGO DE BARRAS VIENE EN equipoId
      codBarras: json['equipoId']?.toString().trim() ?? '',

      // ← marcaId viene como string "101", convertir a int
      marcaId: _safeParseInt(json['marcaId']),

      // ← edfModeloId es el modelo (viene como int 102)
      modeloId: _safeParseInt(json['edfModeloId']),

      // ← numSerie es el número de serie
      numeroSerie: json['numSerie']?.toString().trim(),

      // ← edfLogoId es el logo (viene como int 20, 24, etc.)
      logoId: _safeParseInt(json['edfLogoId']),

      // ← Estados basados en los campos de tu API
      estadoLocal: json['esDisponible'] == true ? 1 : 0,
      activo: json['esActivo'] == true ? 1 : 0,

      fechaCreacion: fecha,
      fechaActualizacion: fechaAct,
      sincronizado: 0, // Siempre 0 para datos que vienen de API

      // ← Nombres para mostrar (temporal hasta hacer JOIN)
      marcaNombre: null, // Se llenará con JOIN posteriormente
      modeloNombre: json['equipo']?.toString().replaceAll('\n', ' ').trim(), // Limpiar saltos de línea
      logoNombre: null, // Se llenará con JOIN posteriormente
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'marca_id': marcaId,
      'modelo_id': modeloId,  // CAMBIADO
      'numero_serie': numeroSerie,
      'logo_id': logoId,
      'estado_local': estadoLocal,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': sincronizado,
      // No incluir nombres en el map para DB
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'codBarras': codBarras, // Para compatibilidad con API
      'marca_id': marcaId,
      'marcaId': marcaId, // Para compatibilidad con API
      'modelo_id': modeloId,  // CAMBIADO
      'modeloId': modeloId,   // Para compatibilidad con API
      'numero_serie': numeroSerie,
      'numeroSerie': numeroSerie, // Para compatibilidad
      'logo_id': logoId,
      'logoId': logoId, // Para compatibilidad con API
      'estado_local': estadoLocal,
      'estadoLocal': estadoLocal, // Para compatibilidad
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(), // Para compatibilidad
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(), // Para compatibilidad
      'sincronizado': sincronizado,
      'marca_nombre': marcaNombre, // Incluir para respuestas completas
      'modelo_nombre': modeloNombre, // CAMBIADO
      'logo_nombre': logoNombre,   // Incluir para respuestas completas
    };
  }

  Equipo copyWith({
    int? id,
    String? codBarras,
    int? marcaId,
    int? modeloId,  // CAMBIADO
    String? numeroSerie,
    int? logoId,
    int? estadoLocal,
    int? activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? sincronizado,
    String? marcaNombre,
    String? modeloNombre,  // CAMBIADO
    String? logoNombre,
  }) {
    return Equipo(
      id: id ?? this.id,
      codBarras: codBarras ?? this.codBarras,
      marcaId: marcaId ?? this.marcaId,
      modeloId: modeloId ?? this.modeloId,  // CAMBIADO
      numeroSerie: numeroSerie ?? this.numeroSerie,
      logoId: logoId ?? this.logoId,
      estadoLocal: estadoLocal ?? this.estadoLocal,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      sincronizado: sincronizado ?? this.sincronizado,
      marcaNombre: marcaNombre ?? this.marcaNombre,
      modeloNombre: modeloNombre ?? this.modeloNombre,  // CAMBIADO
      logoNombre: logoNombre ?? this.logoNombre,
    );
  }

  // Métodos de utilidad - CORREGIDOS
  bool get estaActivo => activo == 1;
  bool get estaSincronizado => sincronizado == 1;
  bool get estaDisponible => estadoLocal == 1;
  String get nombreCompleto => '$marcaNombre $modeloNombre';  // CAMBIADO
  String get nombreCompletoFallback => 'MarcaID:$marcaId ModeloID:$modeloId'; // CAMBIADO

  @override
  String toString() {
    return 'Equipo{id: $id, codBarras: $codBarras, marcaId: $marcaId, modeloId: $modeloId, '  // CAMBIADO
        'numeroSerie: $numeroSerie, logoId: $logoId, estadoLocal: $estadoLocal, '
        'activo: $activo, sincronizado: $sincronizado, marcaNombre: $marcaNombre, '
        'modeloNombre: $modeloNombre, logoNombre: $logoNombre}';  // CAMBIADO
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Equipo &&
        other.id == id &&
        other.codBarras == codBarras;
  }

  @override
  int get hashCode => id.hashCode ^ codBarras.hashCode;
}

// Modelos auxiliares para las tablas de referencia
class Marca {
  final int? id;
  final String nombre;
  final int activo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Marca({
    this.id,
    required this.nombre,
    this.activo = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      activo: map['activo'] ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}

class Logo {
  final int? id;
  final String nombre;
  final int activo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Logo({
    this.id,
    required this.nombre,
    this.activo = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      activo: map['activo'] ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'])
          : DateTime.now(),
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.parse(map['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}
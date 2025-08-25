class Equipo {
  final int? id;
  final String codBarras;
  final int marcaId;  // ← Cambio: ahora es ID de llave foránea
  final String modelo;
  final String? numeroSerie;
  final int logoId;  // ← Cambio: ahora es ID de llave foránea
  final int estadoLocal;
  final int activo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final int sincronizado;

  // Campos adicionales para JOIN (no se almacenan en DB)
  final String? marcaNombre;
  final String? logoNombre;

  Equipo({
    this.id,
    required this.codBarras,
    required this.marcaId,
    required this.modelo,
    this.numeroSerie,
    required this.logoId,
    this.estadoLocal = 1,
    this.activo = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.sincronizado = 0,
    this.marcaNombre,
    this.logoNombre,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'],
      codBarras: map['cod_barras'] ?? '',
      marcaId: map['marca_id'] ?? 1,
      modelo: map['modelo'] ?? '',
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
      logoNombre: map['logo_nombre'],   // Para JOINs
    );
  }

  factory Equipo.fromJson(Map<String, dynamic> json) {
    DateTime fecha;
    DateTime? fechaAct;

    try {
      fecha = DateTime.parse(
          json['fecha_creacion'] ??
              json['fechaCreacion'] ??
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
      id: json['id'],
      codBarras: json['cod_barras'] ?? json['codBarras'] ?? '',
      marcaId: json['marca_id'] ?? json['marcaId'] ?? 1,
      modelo: json['modelo'] ?? '',
      numeroSerie: json['numero_serie'] ?? json['numeroSerie'],
      logoId: json['logo_id'] ?? json['logoId'] ?? 1,
      estadoLocal: json['estado_local'] ?? json['estadoLocal'] ?? 1,
      activo: json['activo'] ?? 1,
      fechaCreacion: fecha,
      fechaActualizacion: fechaAct,
      sincronizado: json['sincronizado'] ?? 0,
      marcaNombre: json['marca_nombre'] ?? json['marcaNombre'],
      logoNombre: json['logo_nombre'] ?? json['logoNombre'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'marca_id': marcaId,
      'modelo': modelo,
      'numero_serie': numeroSerie,
      'logo_id': logoId,
      'estado_local': estadoLocal,
      'activo': activo,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': sincronizado,
      // No incluir marcaNombre y logoNombre en el map para DB
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_barras': codBarras,
      'codBarras': codBarras, // Para compatibilidad con API
      'marca_id': marcaId,
      'marcaId': marcaId, // Para compatibilidad con API
      'modelo': modelo,
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
      'logo_nombre': logoNombre,   // Incluir para respuestas completas
    };
  }

  Equipo copyWith({
    int? id,
    String? codBarras,
    int? marcaId,
    String? modelo,
    String? numeroSerie,
    int? logoId,
    int? estadoLocal,
    int? activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? sincronizado,
    String? marcaNombre,
    String? logoNombre,
  }) {
    return Equipo(
      id: id ?? this.id,
      codBarras: codBarras ?? this.codBarras,
      marcaId: marcaId ?? this.marcaId,
      modelo: modelo ?? this.modelo,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      logoId: logoId ?? this.logoId,
      estadoLocal: estadoLocal ?? this.estadoLocal,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      sincronizado: sincronizado ?? this.sincronizado,
      marcaNombre: marcaNombre ?? this.marcaNombre,
      logoNombre: logoNombre ?? this.logoNombre,
    );
  }

  // Métodos de utilidad
  bool get estaActivo => activo == 1;
  bool get estaSincronizado => sincronizado == 1;
  bool get estaDisponible => estadoLocal == 1;
  String get nombreCompleto => '$marcaNombre $modelo';
  String get nombreCompletoFallback => 'ID:$marcaId $modelo'; // Fallback si no hay JOIN

  @override
  String toString() {
    return 'Equipo{id: $id, codBarras: $codBarras, marcaId: $marcaId, modelo: $modelo, '
        'numeroSerie: $numeroSerie, logoId: $logoId, estadoLocal: $estadoLocal, '
        'activo: $activo, sincronizado: $sincronizado, marcaNombre: $marcaNombre, '
        'logoNombre: $logoNombre}';
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
  final int sincronizado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Marca({
    this.id,
    required this.nombre,
    this.activo = 1,
    this.sincronizado = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      activo: map['activo'] ?? 1,
      sincronizado: map['sincronizado'] ?? 1,
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
      'sincronizado': sincronizado,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }
}

class Logo {
  final int? id;
  final String nombre;
  final int activo;
  final int sincronizado;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  Logo({
    this.id,
    required this.nombre,
    this.activo = 1,
    this.sincronizado = 1,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      activo: map['activo'] ?? 1,
      sincronizado: map['sincronizado'] ?? 1,
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
      'sincronizado': sincronizado,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }
}
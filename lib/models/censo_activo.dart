enum EstadoEquipoCenso {
  creado,
  migrado,
  error,
}

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

class EstadoEquipo {
  final int? id;
  final String equipoId;      // ← CAMBIO: String en lugar de int equipoPendienteId
  final int clienteId;        // ← CAMBIO: Nuevo campo
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final DateTime fechaRevision;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final bool estaSincronizado;
  final String? estadoCenso;
  final String? observaciones;

  // Primera imagen
  final String? imagenPath;
  final String? imagenBase64;
  final bool tieneImagen;
  final int? imagenTamano;

  // Segunda imagen
  final String? imagenPath2;
  final String? imagenBase64_2;
  final bool tieneImagen2;
  final int? imagenTamano2;

  EstadoEquipo({
    this.id,
    required this.equipoId,     // ← CAMBIO
    required this.clienteId,    // ← CAMBIO
    required this.enLocal,
    this.latitud,
    this.longitud,
    required this.fechaRevision,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.estaSincronizado = false,
    this.estadoCenso,
    this.observaciones,
    // Primera imagen
    this.imagenPath,
    this.imagenBase64,
    this.tieneImagen = false,
    this.imagenTamano,
    // Segunda imagen
    this.imagenPath2,
    this.imagenBase64_2,
    this.tieneImagen2 = false,
    this.imagenTamano2,
  });

  factory EstadoEquipo.fromMap(Map<String, dynamic> map) {
    return EstadoEquipo(
        id: map['id'] as int?,
        equipoId: map['equipo_id'] as String? ?? '0',        // ← CAMBIO
        clienteId: map['cliente_id'] as int? ?? 0,           // ← CAMBIO
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
          : DateTime.now(),
      estaSincronizado: (map['sincronizado'] as int?) == 1,
      // Primera imagen
      imagenPath: map['imagen_path'] as String?,
      imagenBase64: map['imagen_base64'] as String?,
      tieneImagen: (map['tiene_imagen'] as int?) == 1,
      imagenTamano: map['imagen_tamano'] as int?,
      // Segunda imagen
      imagenPath2: map['imagen_path2'] as String?,
      imagenBase64_2: map['imagen_base64_2'] as String?,
      tieneImagen2: (map['tiene_imagen2'] as int?) == 1,
      imagenTamano2: map['imagen_tamano2'] as int?,
      estadoCenso: map['estado_censo'] as String?,
      observaciones: map ['observaciones'] as String?
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'equipo_id': equipoId,        // ← CAMBIO
      'cliente_id': clienteId,
      'en_local': enLocal ? 1 : 0,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
      'observaciones': observaciones,
      // Primera imagen
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'tiene_imagen': tieneImagen ? 1 : 0,
      'imagen_tamano': imagenTamano,
      // Segunda imagen
      'imagen_path2': imagenPath2,
      'imagen_base64_2': imagenBase64_2,
      'tiene_imagen2': tieneImagen2 ? 1 : 0,
      'imagen_tamano2': imagenTamano2,
    };

    if (estadoCenso != null) {
      map['estado_censo'] = estadoCenso;
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipo_id': equipoId,        // ← CAMBIO
      'cliente_id': clienteId,
      'en_local': enLocal,
      'latitud': latitud,
      'longitud': longitud,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'sincronizado': estaSincronizado,
      'estado_censo': estadoCenso,
      'observaciones': observaciones,
      // Primera imagen
      'imagen_path': imagenPath,
      'tiene_imagen': tieneImagen,
      'imagen_tamano': imagenTamano,
      // Segunda imagen
      'imagen_path2': imagenPath2,
      'tiene_imagen2': tieneImagen2,
      'imagen_tamano2': imagenTamano2,
    };
  }

  EstadoEquipo copyWith({
    int? id,
    int? equipoClienteId,
    bool? enLocal,
    double? latitud,
    double? longitud,
    DateTime? fechaRevision,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    bool? estaSincronizado,
    String? estadoCenso,
    String? observaciones,
    // Primera imagen
    String? imagenPath,
    String? imagenBase64,
    bool? tieneImagen,
    int? imagenTamano,
    // Segunda imagen
    String? imagenPath2,
    String? imagenBase64_2,
    bool? tieneImagen2,
    int? imagenTamano2,
  }) {
    return EstadoEquipo(
      id: id ?? this.id,
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: enLocal ?? this.enLocal,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
      estadoCenso: estadoCenso ?? this.estadoCenso,
      observaciones: observaciones ?? this.observaciones,
      // Primera imagen
      imagenPath: imagenPath ?? this.imagenPath,
      imagenBase64: imagenBase64 ?? this.imagenBase64,
      tieneImagen: tieneImagen ?? this.tieneImagen,
      imagenTamano: imagenTamano ?? this.imagenTamano,
      // Segunda imagen
      imagenPath2: imagenPath2 ?? this.imagenPath2,
      imagenBase64_2: imagenBase64_2 ?? this.imagenBase64_2,
      tieneImagen2: tieneImagen2 ?? this.tieneImagen2,
      imagenTamano2: imagenTamano2 ?? this.imagenTamano2,
    );
  }

  EstadoEquipoCenso get estadoCensoEnum => EstadoEquipoCensoExtension.fromString(estadoCenso);
  bool get estaCreado => estadoCenso == EstadoEquipoCenso.creado.valor;
  bool get estaMigrado => estadoCenso == EstadoEquipoCenso.migrado.valor;
  bool get tieneError => estadoCenso == EstadoEquipoCenso.error.valor;

  // Helpers para imágenes
  bool get necesitaSincronizarImagen =>
      (tieneImagen && imagenBase64 != null) ||
          (tieneImagen2 && imagenBase64_2 != null);

  String get infoImagen {
    if (!tieneImagen && !tieneImagen2) return 'Sin imágenes';

    List<String> infos = [];

    if (tieneImagen) {
      final tamanoMB = imagenTamano != null ? (imagenTamano! / (1024 * 1024)).toStringAsFixed(1) : '?';
      infos.add('Img1 ($tamanoMB MB)');
    }

    if (tieneImagen2) {
      final tamanoMB = imagenTamano2 != null ? (imagenTamano2! / (1024 * 1024)).toStringAsFixed(1) : '?';
      infos.add('Img2 ($tamanoMB MB)');
    }

    final estado = estaSincronizado ? 'Sincronizadas' : 'Pendientes';
    return '${infos.join(' + ')} - $estado';
  }

  int get totalImagenes {
    int count = 0;
    if (tieneImagen) count++;
    if (tieneImagen2) count++;
    return count;
  }
}
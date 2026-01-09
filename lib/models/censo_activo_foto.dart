class CensoActivoFoto {
  final String? id;
  final String censoActivoId;
  final String? imagenPath;
  final String? imagenBase64;
  final int? imagenTamano;
  final int orden;
  final DateTime fechaCreacion;
  final bool estaSincronizado;

  CensoActivoFoto({
    this.id,
    required this.censoActivoId,
    this.imagenPath,
    this.imagenBase64,
    this.imagenTamano,
    this.orden = 1,
    required this.fechaCreacion,
    this.estaSincronizado = false,
  });

  factory CensoActivoFoto.fromMap(Map<String, dynamic> map) {
    return CensoActivoFoto(
      id: map['id'] as String?,
      censoActivoId: map['censo_activo_id'] as String,
      imagenPath: map['imagen_path'] as String?,
      imagenBase64: map['imagen_base64'] as String?,
      imagenTamano: map['imagen_tamano'] as int?,
      orden: map['orden'] as int? ?? 1,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : DateTime.now(),
      estaSincronizado: (map['sincronizado'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'censo_activo_id': censoActivoId,
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'imagen_tamano': imagenTamano,
      'orden': orden,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'sincronizado': estaSincronizado ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'censo_activo_id': censoActivoId,
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'imagen_tamano': imagenTamano,
      'orden': orden,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'sincronizado': estaSincronizado,
    };
  }

  CensoActivoFoto copyWith({
    String? id,
    String? censoActivoId,
    String? imagenPath,
    String? imagenBase64,
    int? imagenTamano,
    int? orden,
    DateTime? fechaCreacion,
    bool? estaSincronizado,
  }) {
    return CensoActivoFoto(
      id: id ?? this.id,
      censoActivoId: censoActivoId ?? this.censoActivoId,
      imagenPath: imagenPath ?? this.imagenPath,
      imagenBase64: imagenBase64 ?? this.imagenBase64,
      imagenTamano: imagenTamano ?? this.imagenTamano,
      orden: orden ?? this.orden,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      estaSincronizado: estaSincronizado ?? this.estaSincronizado,
    );
  }

  // Helpers útiles
  bool get tieneImagen => imagenPath != null || imagenBase64 != null;

  bool get necesitaSincronizar => tieneImagen && !estaSincronizado;
}

// Clase helper para trabajar con múltiples fotos de un censo
class CensoConFotos {
  final String censoActivoId;
  final List<CensoActivoFoto> fotos;

  CensoConFotos({required this.censoActivoId, required this.fotos});

  // Helpers útiles
  int get totalFotos => fotos.length;

  bool get tieneFotos => fotos.isNotEmpty;

  List<CensoActivoFoto> get fotosSincronizadas =>
      fotos.where((f) => f.estaSincronizado).toList();

  List<CensoActivoFoto> get fotosPendientes =>
      fotos.where((f) => !f.estaSincronizado).toList();

  bool get todasSincronizadas => fotos.every((f) => f.estaSincronizado);

  String get infoResumen {
    if (!tieneFotos) return 'Sin fotos';

    final pendientes = fotosPendientes.length;

    if (todasSincronizadas) {
      return '$totalFotos foto${totalFotos > 1 ? 's' : ''} sincronizada${totalFotos > 1 ? 's' : ''}';
    } else {
      return '$totalFotos foto${totalFotos > 1 ? 's' : ''} ($pendientes pendiente${pendientes > 1 ? 's' : ''})';
    }
  }

  // Obtener foto por orden
  CensoActivoFoto? getFotoPorOrden(int orden) {
    try {
      return fotos.firstWhere((f) => f.orden == orden);
    } catch (e) {
      return null;
    }
  }

  // Obtener la primera foto
  CensoActivoFoto? get primeraFoto => fotos.isNotEmpty ? fotos.first : null;
}

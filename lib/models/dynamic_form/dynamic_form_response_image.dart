/// Representa una imagen asociada a un detalle de respuesta del formulario
/// Permite múltiples imágenes por cada campo de respuesta
class DynamicFormResponseImage {
  final String id;
  final String dynamicFormResponseDetailId; // FK a dynamic_form_response_detail
  final String? imagenPath;
  final String? imagenBase64;
  final int? imagenTamano;
  final String mimeType;
  final int orden; // Para ordenar múltiples imágenes
  final String createdAt;
  final String syncStatus;

  DynamicFormResponseImage({
    required this.id,
    required this.dynamicFormResponseDetailId,
    this.imagenPath,
    this.imagenBase64,
    this.imagenTamano,
    this.mimeType = 'image/jpeg',
    this.orden = 1,
    required this.createdAt,
    this.syncStatus = 'pending',
  });

  /// Crea desde la base de datos (SQLite)
  factory DynamicFormResponseImage.fromMap(Map<String, dynamic> map) {
    return DynamicFormResponseImage(
      id: map['id'] as String,
      dynamicFormResponseDetailId: map['dynamic_form_response_detail_id'] as String,
      imagenPath: map['imagen_path'] as String?,
      imagenBase64: map['imagen_base64'] as String?,
      imagenTamano: map['imagen_tamano'] as int?,
      mimeType: map['mime_type'] as String? ?? 'image/jpeg',
      orden: map['orden'] as int? ?? 1,
      createdAt: map['created_at'] as String,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  /// Convierte a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dynamic_form_response_detail_id': dynamicFormResponseDetailId,
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'imagen_tamano': imagenTamano,
      'mime_type': mimeType,
      'orden': orden,
      'created_at': createdAt,
      'sync_status': syncStatus,
      // ❌ NO incluir fecha_creacion ni fecha_actualizacion
    };
  }

  /// Crea desde JSON (API)
  factory DynamicFormResponseImage.fromJson(Map<String, dynamic> json) {
    return DynamicFormResponseImage(
      id: json['id'] as String,
      dynamicFormResponseDetailId: json['dynamicFormResponseDetailId'] as String,
      imagenPath: json['imagenPath'] as String?,
      imagenBase64: json['imagenBase64'] as String?,
      imagenTamano: json['imagenTamano'] as int?,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      orden: json['orden'] as int? ?? 1,
      createdAt: json['createdAt'] as String,
      syncStatus: json['syncStatus'] as String? ?? 'pending',
    );
  }

  /// Convierte a JSON para API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dynamicFormResponseDetailId': dynamicFormResponseDetailId,
      if (imagenPath != null) 'imagenPath': imagenPath,
      if (imagenBase64 != null) 'imagenBase64': imagenBase64,
      if (imagenTamano != null) 'imagenTamano': imagenTamano,
      'mimeType': mimeType,
      'orden': orden,
      'createdAt': createdAt,
      'syncStatus': syncStatus,
    };
  }

  /// Crea una copia con modificaciones
  DynamicFormResponseImage copyWith({
    String? id,
    String? dynamicFormResponseDetailId,
    String? imagenPath,
    String? imagenBase64,
    int? imagenTamano,
    String? mimeType,
    int? orden,
    String? createdAt,
    String? syncStatus,
  }) {
    return DynamicFormResponseImage(
      id: id ?? this.id,
      dynamicFormResponseDetailId: dynamicFormResponseDetailId ?? this.dynamicFormResponseDetailId,
      imagenPath: imagenPath ?? this.imagenPath,
      imagenBase64: imagenBase64 ?? this.imagenBase64,
      imagenTamano: imagenTamano ?? this.imagenTamano,
      mimeType: mimeType ?? this.mimeType,
      orden: orden ?? this.orden,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Verifica si tiene datos de imagen válidos
  bool get hasValidImage => imagenPath != null || imagenBase64 != null;

  /// Verifica si está listo para sincronizar
  bool get isPending => syncStatus == 'pending';

  /// Verifica si está sincronizado
  bool get isSynced => syncStatus == 'synced';

  /// Verifica si tiene error
  bool get hasError => syncStatus == 'error';

  /// Marca como sincronizado
  DynamicFormResponseImage markAsSynced() {
    return copyWith(syncStatus: 'synced');
  }

  /// Marca como error
  DynamicFormResponseImage markAsError() {
    return copyWith(syncStatus: 'error');
  }

  /// Marca como pendiente
  DynamicFormResponseImage markAsPending() {
    return copyWith(syncStatus: 'pending');
  }

  @override
  String toString() {
    return 'DynamicFormResponseImage(id: $id, detailId: $dynamicFormResponseDetailId, orden: $orden, hasImage: $hasValidImage, syncStatus: $syncStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicFormResponseImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
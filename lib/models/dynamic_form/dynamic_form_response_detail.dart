/// Representa el detalle de una respuesta individual de un campo del formulario
class DynamicFormResponseDetail {
  final String id;
  final int? version;
  final String? response;  // La respuesta en texto/JSON
  final String dynamicFormResponseId;  // FK a dynamic_form_response
  final String dynamicFormDetailId;    // FK a dynamic_form_detail (el campo)
  final String syncStatus;

  // Campos para imágenes (siguiendo el patrón de censo_activo)
  final String? imagenPath;
  final String? imagenBase64;
  final bool tieneImagen;
  final int? imagenTamano;

  DynamicFormResponseDetail({
    required this.id,
    this.version,
    this.response,
    required this.dynamicFormResponseId,
    required this.dynamicFormDetailId,
    this.syncStatus = 'pending',
    this.imagenPath,
    this.imagenBase64,
    this.tieneImagen = false,
    this.imagenTamano,
  });

  /// Crea desde la base de datos (SQLite)
  factory DynamicFormResponseDetail.fromMap(Map<String, dynamic> map) {
    return DynamicFormResponseDetail(
      id: map['id'] as String,
      version: map['version'] as int?,
      response: map['response'] as String?,
      dynamicFormResponseId: map['dynamic_form_response_id'] as String,
      dynamicFormDetailId: map['dynamic_form_detail_id'] as String,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      imagenPath: map['imagen_path'] as String?,
      imagenBase64: map['imagen_base64'] as String?,
      tieneImagen: (map['tiene_imagen'] as int?) == 1,
      imagenTamano: map['imagen_tamano'] as int?,
    );
  }

  /// Convierte a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': version,
      'response': response,
      'dynamic_form_response_id': dynamicFormResponseId,
      'dynamic_form_detail_id': dynamicFormDetailId,
      'sync_status': syncStatus,
      'imagen_path': imagenPath,
      'imagen_base64': imagenBase64,
      'tiene_imagen': tieneImagen ? 1 : 0,
      'imagen_tamano': imagenTamano,
    };
  }

  /// Crea desde JSON (API)
  factory DynamicFormResponseDetail.fromJson(Map<String, dynamic> json) {
    return DynamicFormResponseDetail(
      id: json['id'] as String,
      version: json['version'] as int?,
      response: json['response'] as String?,
      dynamicFormResponseId: json['dynamicFormResponseId'] as String,
      dynamicFormDetailId: json['dynamicFormDetailId'] as String,
      syncStatus: json['syncStatus'] as String? ?? 'pending',
      imagenPath: json['imagenPath'] as String?,
      imagenBase64: json['imagenBase64'] as String?,
      tieneImagen: json['tieneImagen'] as bool? ?? false,
      imagenTamano: json['imagenTamano'] as int?,
    );
  }

  /// Convierte a JSON para API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (version != null) 'version': version,
      if (response != null) 'response': response,
      'dynamicFormResponseId': dynamicFormResponseId,
      'dynamicFormDetailId': dynamicFormDetailId,
      'syncStatus': syncStatus,
      if (imagenPath != null) 'imagenPath': imagenPath,
      if (imagenBase64 != null) 'imagenBase64': imagenBase64,
      'tieneImagen': tieneImagen,
      if (imagenTamano != null) 'imagenTamano': imagenTamano,
    };
  }

  /// Crea una copia con modificaciones
  DynamicFormResponseDetail copyWith({
    String? id,
    int? version,
    String? response,
    String? dynamicFormResponseId,
    String? dynamicFormDetailId,
    String? syncStatus,
    String? imagenPath,
    String? imagenBase64,
    bool? tieneImagen,
    int? imagenTamano,
  }) {
    return DynamicFormResponseDetail(
      id: id ?? this.id,
      version: version ?? this.version,
      response: response ?? this.response,
      dynamicFormResponseId: dynamicFormResponseId ?? this.dynamicFormResponseId,
      dynamicFormDetailId: dynamicFormDetailId ?? this.dynamicFormDetailId,
      syncStatus: syncStatus ?? this.syncStatus,
      imagenPath: imagenPath ?? this.imagenPath,
      imagenBase64: imagenBase64 ?? this.imagenBase64,
      tieneImagen: tieneImagen ?? this.tieneImagen,
      imagenTamano: imagenTamano ?? this.imagenTamano,
    );
  }

  /// Verifica si es un campo de imagen con datos
  bool get hasImage => tieneImagen && imagenPath != null;

  /// Verifica si está listo para sincronizar
  bool get isPending => syncStatus == 'pending';

  /// Verifica si está sincronizado
  bool get isSynced => syncStatus == 'synced';

  /// Marca como sincronizado
  DynamicFormResponseDetail markAsSynced() {
    return copyWith(syncStatus: 'synced');
  }

  /// Marca como error
  DynamicFormResponseDetail markAsError() {
    return copyWith(syncStatus: 'error');
  }

  @override
  String toString() {
    return 'DynamicFormResponseDetail(id: $id, fieldId: $dynamicFormDetailId, hasImage: $hasImage)';
  }
}
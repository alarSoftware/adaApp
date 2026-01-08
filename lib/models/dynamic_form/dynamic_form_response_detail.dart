/// Representa el detalle de una respuesta individual de un campo del formulario
class DynamicFormResponseDetail {
  final String id;
  final int? version;
  final String? response; // La respuesta en texto/JSON
  final String dynamicFormResponseId; // FK a dynamic_form_response
  final String dynamicFormDetailId; // FK a dynamic_form_detail (el campo)
  final String syncStatus;

  DynamicFormResponseDetail({
    required this.id,
    this.version,
    this.response,
    required this.dynamicFormResponseId,
    required this.dynamicFormDetailId,
    this.syncStatus = 'pending',
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
  }) {
    return DynamicFormResponseDetail(
      id: id ?? this.id,
      version: version ?? this.version,
      response: response ?? this.response,
      dynamicFormResponseId:
          dynamicFormResponseId ?? this.dynamicFormResponseId,
      dynamicFormDetailId: dynamicFormDetailId ?? this.dynamicFormDetailId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  bool get isSynced => syncStatus == 'synced';
}

import 'dart:convert';

/// Representa una respuesta/instancia completada de un formulario dinámico
class DynamicFormResponse {
  final String id;
  final String formTemplateId;
  final Map<String, dynamic> answers;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? syncedAt;
  final String status;
  final String? userId;
  final String? contactoId;
  final String? employeeId;
  final String? errorMessage;

  DynamicFormResponse({
    required this.id,
    required this.formTemplateId,
    required this.answers,
    required this.createdAt,
    this.completedAt,
    this.syncedAt,
    this.status = 'draft',
    this.userId,
    this.contactoId,
    this.employeeId,
    this.errorMessage,
  });

  /// Crea una respuesta desde JSON (de la API)
  factory DynamicFormResponse.fromJson(Map<String, dynamic> json) {
    return DynamicFormResponse(
      id: json['id'] as String,
      formTemplateId: json['formTemplateId'] as String,
      answers: Map<String, dynamic>.from(json['answers'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'draft',
      userId: json['userId'] as String?,
      contactoId: json['contactoId'] as String?,
      employeeId: json['employeeId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Convierte la respuesta a JSON (para API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formTemplateId': formTemplateId,
      'answers': answers,
      'createdAt': createdAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
      'status': status,
      if (userId != null) 'userId': userId,
      if (contactoId != null) 'contactoId': contactoId,
      if (employeeId != null) 'employeeId': employeeId,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Crea desde Map de base de datos
  factory DynamicFormResponse.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> answers = {};

    if (map['answers'] != null) {
      if (map['answers'] is String) {
        answers = Map<String, dynamic>.from(jsonDecode(map['answers']));
      } else if (map['answers'] is Map) {
        answers = Map<String, dynamic>.from(map['answers'] as Map);
      }
    }

    return DynamicFormResponse(
      id: map['id'] as String,
      formTemplateId: map['dynamic_form_id'] as String,
      answers: answers,
      createdAt: DateTime.parse(map['creation_date'] as String),
      completedAt: map['last_update_date'] != null
          ? DateTime.parse(map['last_update_date'] as String)
          : null,

      syncedAt: map['fecha_sincronizado'] != null
          ? DateTime.parse(map['fecha_sincronizado'] as String)
          : null,
      status: map['estado'] as String? ?? 'draft',
      userId: map['usuario_id']?.toString(),
      contactoId: map['contacto_id'] as String?,
      employeeId: map['employee_id'] as String?,
      errorMessage: map['mensaje_error_sync'] as String?,
    );
  }

  /// Convierte a Map para guardar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': 1,
      'contacto_id': contactoId ?? '',
      'employee_id': employeeId,
      'last_update_user_id': null,
      'dynamic_form_id': formTemplateId,
      'usuario_id': userId != null ? int.tryParse(userId!) : null,
      'estado': status,
      'sync_status': 'pending',
      'intentos_sync': 0,
      'creation_date': createdAt.toIso8601String(),
      'last_update_date':
          completedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  // Getters simplificados
  // Getters
  bool get isCompleted => status == 'completed';
  bool get isSynced => status == 'synced' || syncedAt != null;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  DynamicFormResponse copyWith({
    String? id,
    String? formTemplateId,
    Map<String, dynamic>? answers,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? syncedAt,
    String? status,
    String? userId,
    String? contactoId,
    String? employeeId,
    String? equipoId,
    String? errorMessage,
  }) {
    return DynamicFormResponse(
      id: id ?? this.id,
      formTemplateId: formTemplateId ?? this.formTemplateId,
      answers: answers ?? this.answers,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      contactoId: contactoId ?? this.contactoId,
      employeeId: employeeId ?? this.employeeId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

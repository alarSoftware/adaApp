/// Representa una respuesta/instancia completada de un formulario dinámico
class DynamicFormResponse {
  final String id;                    // ID único de la respuesta
  final String formTemplateId;        // ID del formulario que se llenó
  final Map<String, dynamic> answers; // Respuestas: {key: valor}
  final DateTime createdAt;           // Cuándo se creó
  final DateTime? completedAt;        // Cuándo se completó
  final DateTime? syncedAt;           // Cuándo se sincronizó al servidor
  final String status;                // pending, completed, synced, error
  final String? userId;               // Usuario que llenó el formulario
  final String? clienteId;            // Cliente asociado (si aplica)
  final String? equipoId;             // Equipo asociado (si aplica)
  final Map<String, dynamic>? metadata; // Datos adicionales (ubicación, fotos, etc.)
  final String? errorMessage;         // Mensaje de error si falló el sync

  DynamicFormResponse({
    required this.id,
    required this.formTemplateId,
    required this.answers,
    required this.createdAt,
    this.completedAt,
    this.syncedAt,
    this.status = 'pending',
    this.userId,
    this.clienteId,
    this.equipoId,
    this.metadata,
    this.errorMessage,
  });

  /// Crea una respuesta desde JSON
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
      status: json['status'] as String? ?? 'pending',
      userId: json['userId'] as String?,
      clienteId: json['clienteId'] as String?,
      equipoId: json['equipoId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Convierte la respuesta a JSON
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
      if (clienteId != null) 'clienteId': clienteId,
      if (equipoId != null) 'equipoId': equipoId,
      if (metadata != null) 'metadata': metadata,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Verifica si la respuesta está completa
  bool get isCompleted => status == 'completed' || status == 'synced';

  /// Verifica si está sincronizada
  bool get isSynced => status == 'synced';

  /// Verifica si tiene errores
  bool get hasError => status == 'error';

  /// Verifica si está pendiente
  bool get isPending => status == 'pending';

  /// Obtiene el valor de una respuesta específica
  dynamic getAnswer(String key) {
    return answers[key];
  }

  /// Actualiza una respuesta específica
  DynamicFormResponse updateAnswer(String key, dynamic value) {
    final updatedAnswers = Map<String, dynamic>.from(answers);
    updatedAnswers[key] = value;
    return copyWith(answers: updatedAnswers);
  }

  /// Marca como completada
  DynamicFormResponse markAsCompleted() {
    return copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
    );
  }

  /// Marca como sincronizada
  DynamicFormResponse markAsSynced() {
    return copyWith(
      status: 'synced',
      syncedAt: DateTime.now(),
      errorMessage: null,
    );
  }

  /// Marca como error
  DynamicFormResponse markAsError(String error) {
    return copyWith(
      status: 'error',
      errorMessage: error,
    );
  }

  /// Crea una copia con modificaciones
  DynamicFormResponse copyWith({
    String? id,
    String? formTemplateId,
    Map<String, dynamic>? answers,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? syncedAt,
    String? status,
    String? userId,
    String? clienteId,
    String? equipoId,
    Map<String, dynamic>? metadata,
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
      clienteId: clienteId ?? this.clienteId,
      equipoId: equipoId ?? this.equipoId,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'DynamicFormResponse(id: $id, formTemplateId: $formTemplateId, status: $status)';
  }
}
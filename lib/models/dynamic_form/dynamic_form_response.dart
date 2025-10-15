import 'dart:convert';

/// Representa una respuesta/instancia completada de un formulario dinámico
class DynamicFormResponse {
  final String id;                    // ID único de la respuesta
  final String formTemplateId;        // ID del formulario que se llenó
  final Map<String, dynamic> answers; // Respuestas: {key: valor}
  final DateTime createdAt;           // Cuándo se creó
  final DateTime? completedAt;        // Cuándo se completó
  final DateTime? syncedAt;           // Cuándo se sincronizó al servidor
  final String status;                // draft, completed, synced, error
  final String? userId;               // Usuario que llenó el formulario
  final String? contactoId;           // Cliente asociado (si aplica)
  final String? edfVendedorId;        // ID del vendedor (para filtrar respuestas)
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
    this.status = 'draft',
    this.userId,
    this.contactoId,
    this.edfVendedorId,
    this.equipoId,
    this.metadata,
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
      edfVendedorId: json['edfVendedorId'] as String?,
      equipoId: json['equipoId'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
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
      if (edfVendedorId != null) 'edfVendedorId': edfVendedorId,
      if (equipoId != null) 'equipoId': equipoId,
      if (metadata != null) 'metadata': metadata,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Crea desde Map de base de datos (usa los nombres de columnas de tu BD)
  factory DynamicFormResponse.fromMap(Map<String, dynamic> map) {
    // Reconstruir answers desde los detalles (si existen)
    Map<String, dynamic> answers = {};

    // Si el map incluye 'answers' directamente (guardado como JSON string)
    if (map['answers'] != null) {
      if (map['answers'] is String) {
        answers = Map<String, dynamic>.from(jsonDecode(map['answers']));
      } else if (map['answers'] is Map) {
        answers = Map<String, dynamic>.from(map['answers'] as Map);
      }
    }

    return DynamicFormResponse(
      id: map['id'] as String,
      formTemplateId: map['dynamic_form_id'] as String, // ← Nombre correcto de tu BD
      answers: answers,
      createdAt: DateTime.parse(map['creation_date'] as String), // ← Nombre correcto
      completedAt: map['last_update_date'] != null
          ? DateTime.parse(map['last_update_date'] as String)
          : null,
      syncedAt: null, // No guardas esto en BD aún
      status: map['estado'] as String? ?? 'draft', // ← Nombre correcto
      userId: map['usuario_id']?.toString(), // ← Convertir int a String
      contactoId: map['contacto_id'] as String?,
      edfVendedorId: map['edf_vendedor_id'] as String?, // ← AGREGADO
      equipoId: null, // No lo guardas en la tabla principal
      metadata: null, // No lo guardas en la tabla principal
      errorMessage: null,
    );
  }

  /// Convierte a Map para guardar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': 1,
      'contacto_id': contactoId ?? '',
      'edf_vendedor_id': edfVendedorId, // ← AGREGADO
      'last_update_user_id': null,
      'dynamic_form_id': formTemplateId,
      'usuario_id': userId != null ? int.tryParse(userId!) : null,
      'estado': status,
      'sync_status': 'pending',
      'intentos_sync': 0,
      'creation_date': createdAt.toIso8601String(),
      'last_update_date': completedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  /// Verifica si la respuesta está completa
  bool get isCompleted => status == 'completed' || status == 'synced';

  /// Verifica si está sincronizada
  bool get isSynced => status == 'synced';

  /// Verifica si tiene errores
  bool get hasError => status == 'error';

  /// Verifica si es un borrador
  bool get isDraft => status == 'draft';

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
    String? contactoId,
    String? edfVendedorId,
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
      contactoId: contactoId ?? this.contactoId,
      edfVendedorId: edfVendedorId ?? this.edfVendedorId,
      equipoId: equipoId ?? this.equipoId,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'DynamicFormResponse(id: $id, formTemplateId: $formTemplateId, status: $status, edfVendedorId: $edfVendedorId)';
  }
}
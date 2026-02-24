class DynamicFormField {
  final String id;
  final String type;
  final String label;
  final String? parentId;
  final int? sequence;
  final double? points;
  final bool? respuestaCorrectaOpt;
  final String? respuestaCorrectaText;
  final double? percentage;
  final bool isParent;
  final bool isRequired;
  final double? minValue;
  final double? maxValue;
  final List<DynamicFormField> children;
  final Map<String, dynamic>? metadata;

  DynamicFormField({
    required this.id,
    required this.type,
    required this.label,
    this.parentId,
    this.sequence,
    this.points,
    this.respuestaCorrectaOpt,
    this.respuestaCorrectaText,
    this.percentage,
    this.isParent = false,
    this.isRequired = false,
    this.minValue,
    this.maxValue,
    this.children = const [],
    this.metadata,
  });

  factory DynamicFormField.fromApiJson(Map<String, dynamic> json) {
    return DynamicFormField(
      id: json['id'].toString(),
      type: json['type'] as String,
      label: json['label'] as String,
      parentId: json['parent']?['id']?.toString(),
      sequence: json['sequence'] as int?,
      points: json['points'] != null
          ? (json['points'] as num).toDouble()
          : null,
      respuestaCorrectaOpt: json['respuestaCorrectaOpt'] as bool?,
      respuestaCorrectaText: json['respuestaCorrectaText'] as String?,
      percentage: json['percentage'] != null
          ? (json['percentage'] as num).toDouble()
          : null,
      isParent: _isParentType(json['type'] as String),
      isRequired:
          json['required'] == true ||
          json['is_required'] == 1 ||
          json['is_required'] == true,
      minValue: json['minValue'] != null
          ? (json['minValue'] as num).toDouble()
          : null,
      maxValue: json['maxValue'] != null
          ? (json['maxValue'] as num).toDouble()
          : null,
    );
  }

  // ==================== HELPERS ESTÁTICOS ====================

  static bool _isParentType(String type) {
    return const ['titulo', 'radio_button', 'checkbox'].contains(type);
  }

  static bool isAnswerableType(String type) {
    return !const ['titulo', 'opt'].contains(type);
  }

  // ==================== GETTERS ====================

  bool get required => isRequired;

  bool get isAnswerable => isAnswerableType(type);

  String get widgetType {
    return switch (type) {
      'titulo' => 'header',
      'radio_button' => 'radio_group',
      'checkbox' => 'checkbox_group',
      'resp_abierta' => 'text_field',
      'image' => 'image_picker',
      _ => 'text_field',
    };
  }

  String? get placeholder {
    return type == 'resp_abierta' ? 'Escribe tu respuesta aquí...' : null;
  }

  int? get maxLength => type == 'resp_abierta' ? 500 : null;

  // ==================== COPIA Y MODIFICACIÓN ====================

  DynamicFormField withChildren(List<DynamicFormField> children) {
    return DynamicFormField(
      id: id,
      type: type,
      label: label,
      parentId: parentId,
      sequence: sequence,
      points: points,
      respuestaCorrectaOpt: respuestaCorrectaOpt,
      respuestaCorrectaText: respuestaCorrectaText,
      percentage: percentage,
      isParent: isParent,
      isRequired: isRequired,
      minValue: minValue,
      maxValue: maxValue,
      children: children,
      metadata: metadata,
    );
  }

  DynamicFormField copyWith({
    String? id,
    String? type,
    String? label,
    String? parentId,
    int? sequence,
    double? points,
    bool? respuestaCorrectaOpt,
    String? respuestaCorrectaText,
    double? percentage,
    bool? isParent,
    bool? isRequired,
    double? minValue,
    double? maxValue,
    List<DynamicFormField>? children,
    Map<String, dynamic>? metadata,
  }) {
    return DynamicFormField(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      parentId: parentId ?? this.parentId,
      sequence: sequence ?? this.sequence,
      points: points ?? this.points,
      respuestaCorrectaOpt: respuestaCorrectaOpt ?? this.respuestaCorrectaOpt,
      respuestaCorrectaText:
          respuestaCorrectaText ?? this.respuestaCorrectaText,
      percentage: percentage ?? this.percentage,
      isParent: isParent ?? this.isParent,
      isRequired: isRequired ?? this.isRequired,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      children: children ?? this.children,
      metadata: metadata ?? this.metadata,
    );
  }

  // ==================== SERIALIZACIÓN ====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'label': label,
      if (parentId != null) 'parentId': parentId,
      if (sequence != null) 'sequence': sequence,
      if (points != null) 'points': points,
      if (respuestaCorrectaOpt != null)
        'respuestaCorrectaOpt': respuestaCorrectaOpt,
      if (respuestaCorrectaText != null)
        'respuestaCorrectaText': respuestaCorrectaText,
      if (percentage != null) 'percentage': percentage,
      'isParent': isParent,
      'isRequired': isRequired,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (children.isNotEmpty)
        'children': children.map((c) => c.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

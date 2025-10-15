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
      points: json['points'] != null ? (json['points'] as num).toDouble() : null,
      respuestaCorrectaOpt: json['respuestaCorrectaOpt'] as bool?,
      respuestaCorrectaText: json['respuestaCorrectaText'] as String?,
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      isParent: _isParentType(json['type'] as String),
    );
  }

  static bool _isParentType(String type) {
    return ['titulo', 'radio_button', 'checkbox'].contains(type);
  }

  bool get required {
    return type != 'titulo' && type != 'opt';
  }

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

  String? validate(dynamic value) {
    if (type == 'titulo' || type == 'opt') return null;

    if (required && (value == null || value.toString().trim().isEmpty)) {
      return '$label es obligatorio';
    }

    return null;
  }

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
      respuestaCorrectaText: respuestaCorrectaText ?? this.respuestaCorrectaText,
      percentage: percentage ?? this.percentage,
      isParent: isParent ?? this.isParent,
      children: children ?? this.children,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'label': label,
      if (parentId != null) 'parentId': parentId,
      if (sequence != null) 'sequence': sequence,
      if (points != null) 'points': points,
      if (respuestaCorrectaOpt != null) 'respuestaCorrectaOpt': respuestaCorrectaOpt,
      if (respuestaCorrectaText != null) 'respuestaCorrectaText': respuestaCorrectaText,
      if (percentage != null) 'percentage': percentage,
      'isParent': isParent,
      if (children.isNotEmpty) 'children': children.map((c) => c.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'DynamicFormField(id: $id, type: $type, label: $label, children: ${children.length})';
  }
}
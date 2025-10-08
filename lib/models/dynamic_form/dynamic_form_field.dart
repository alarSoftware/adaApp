/// Representa un campo/pregunta individual del formulario dinámico
class DynamicFormField {
  final String id;                    // ID único del campo (viene del API)
  final String type;                  // titulo, radio_button, checkbox, resp_abierta, opt
  final String label;                 // Texto de la pregunta/opción
  final String? parentId;             // ID del parent (para opciones anidadas)
  final int? sequence;                // Orden de la pregunta
  final double? points;               // Puntos asignados
  final bool? respuestaCorrectaOpt;   // Si es la respuesta correcta (para opts)
  final String? respuestaCorrectaText; // Respuesta correcta en texto
  final double? percentage;           // Porcentaje asignado

  // Campos derivados para facilitar el uso
  final bool isParent;                // Si es un campo padre (titulo, checkbox, radio_button)
  final List<DynamicFormField> children; // Opciones hijas (si las tiene)

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
  });

  /// Crea un campo desde el JSON del API
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

  /// Determina si un tipo de campo puede tener hijos
  static bool _isParentType(String type) {
    return ['titulo', 'radio_button', 'checkbox'].contains(type);
  }

  /// Verifica si este campo es obligatorio
  bool get required {
    // Los títulos y opciones individuales no son obligatorios
    // Los campos de respuesta sí lo son
    return type != 'titulo' && type != 'opt';
  }

  /// Obtiene el tipo de widget que debe renderizarse
  String get widgetType {
    switch (type) {
      case 'titulo':
        return 'header';
      case 'radio_button':
        return 'radio_group';
      case 'checkbox':
        return 'checkbox_group';
      case 'resp_abierta':
        return 'text_field';
      case 'opt':
        return 'option';
      default:
        return 'text_field';
    }
  }

  /// Placeholder para el campo
  String? get placeholder {
    if (type == 'resp_abierta') {
      return 'Escribe tu respuesta aquí...';
    }
    return null;
  }

  /// Hint/ayuda para el campo
  String? get hint => null;

  /// Longitud máxima (solo para texto)
  int? get maxLength => type == 'resp_abierta' ? 500 : null;

  /// Opciones del campo (para dropdowns, etc.)
  List<String>? get options {
    if (children.isEmpty) return null;
    return children.map((c) => c.label).toList();
  }

  /// Validación simple
  String? validate(dynamic value) {
    if (type == 'titulo' || type == 'opt') {
      return null; // Los títulos y opciones no se validan directamente
    }

    if (required && (value == null || value.toString().trim().isEmpty)) {
      return '$label es obligatorio';
    }

    return null;
  }

  /// Crea una copia con hijos asignados
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
    );
  }

  /// Convierte a JSON
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
    };
  }

  @override
  String toString() {
    return 'DynamicFormField(id: $id, type: $type, label: $label, children: ${children.length})';
  }

  // Propiedades adicionales para compatibilidad con código antiguo
  String get key => id;
  String? get defaultValue => null;
  num? get minValue => null;
  num? get maxValue => null;
  Map<String, dynamic>? get validation => null;
}
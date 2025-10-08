import 'dynamic_form_field.dart';
class DynamicFormTemplate {
  final String id;
  final String title;
  final String description;
  final List<DynamicFormField> fields;
  final String? category;
  final int version;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  DynamicFormTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
    this.category,
    this.version = 1,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.metadata,
  });

  /// Crea un template desde el JSON del API
  factory DynamicFormTemplate.fromApiJson(
      Map<String, dynamic> formJson,
      List<Map<String, dynamic>> detailsJson,
      ) {
    // Primero, crear todos los campos
    final allFields = detailsJson
        .map((detail) => DynamicFormField.fromApiJson(detail))
        .toList();

    // Organizar los campos en jerarquía (padres con sus hijos)
    final organizedFields = _organizeFieldsHierarchy(allFields);

    return DynamicFormTemplate(
      id: formJson['id'].toString(),
      title: formJson['name'] as String? ?? 'Sin título',
      description: formJson['estado'] as String? ?? '',
      fields: organizedFields,
      version: 1,
      createdAt: formJson['creationDate'] != null
          ? DateTime.parse(formJson['creationDate'] as String)
          : DateTime.now(),
      updatedAt: formJson['lastUpdateDate'] != null
          ? DateTime.parse(formJson['lastUpdateDate'] as String)
          : null,
      isActive: formJson['estado'] != 'INACTIVO',
      metadata: {
        'totalPuntos': formJson['totalPuntos'],
        'creationUserId': formJson['creationUser']?['id'],
        'lastUpdateUserId': formJson['lastUpdateUser'],
        'estado': formJson['estado'],
      },
    );
  }

  /// Organiza los campos en jerarquía (padres con sus hijos)
  static List<DynamicFormField> _organizeFieldsHierarchy(List<DynamicFormField> allFields) {
    // Crear un mapa para búsqueda rápida por ID
    final Map<String, DynamicFormField> fieldsById = {};
    for (final field in allFields) {
      fieldsById[field.id] = field;
    }

    // Construir el árbol completo recursivamente
    Map<String, List<DynamicFormField>> childrenMap = {};

    // Agrupar hijos por su parent_id
    for (final field in allFields) {
      if (field.parentId != null) {
        if (!childrenMap.containsKey(field.parentId)) {
          childrenMap[field.parentId!] = [];
        }
        childrenMap[field.parentId]!.add(field);
      }
    }

    // Función recursiva para construir el árbol COMPLETO
    DynamicFormField buildTree(DynamicFormField field) {
      final children = childrenMap[field.id] ?? [];
      final childrenWithTheirChildren = children.map((child) => buildTree(child)).toList();
      return field.withChildren(childrenWithTheirChildren);
    }

    // Obtener solo los nodos raíz (sin parent)
    final rootFields = allFields.where((f) => f.parentId == null).toList();

    // Construir el árbol completo para cada raíz
    final organizedFields = rootFields.map((root) => buildTree(root)).toList();

    // Filtrar y procesar según tipo, pero MANTENER la jerarquía
    final List<DynamicFormField> finalFields = [];

    for (final root in organizedFields) {
      if (root.type == 'titulo') {
        // Agregar el título
        finalFields.add(root);

        // Procesar sus hijos directos (radio_button, checkbox, resp_abierta, etc.)
        for (final child in root.children) {
          if (child.type == 'radio_button' || child.type == 'checkbox') {
            // Mantener la estructura jerárquica completa
            finalFields.add(child);
          } else if (child.type == 'resp_abierta' || child.type == 'resp_abierta_larga') {
            finalFields.add(child);
          }
        }
      } else if (root.type == 'radio_button' || root.type == 'checkbox') {
        // Radio o checkbox sin título padre - mantener jerarquía
        finalFields.add(root);
      } else if (root.type == 'resp_abierta' || root.type == 'resp_abierta_larga') {
        // Campo de texto sin padre
        finalFields.add(root);
      }
    }

    return finalFields;
  }

  static List<DynamicFormField> _extractOptions(DynamicFormField field) {
    List<DynamicFormField> options = [];

    for (final child in field.children) {
      if (child.type == 'opt') {
        // Es una opción directa
        options.add(child);

        // Buscar opciones anidadas (como Si_2, Si_3, etc.)
        options.addAll(_extractOptionsRecursive(child));
      } else if (child.type == 'radio_button' || child.type == 'checkbox') {
        // Caso especial: hay otro radio/checkbox anidado
        // Esto no debería pasar según tu estructura, pero por si acaso
        options.addAll(_extractOptions(child));
      }
    }

    return options;
  }

  /// Extrae opciones de forma recursiva (para manejar Si -> Si_2 -> Si_3 -> Si_4)
  static List<DynamicFormField> _extractOptionsRecursive(DynamicFormField option) {
    List<DynamicFormField> nestedOptions = [];

    for (final child in option.children) {
      if (child.type == 'opt') {
        nestedOptions.add(child);
        nestedOptions.addAll(_extractOptionsRecursive(child));
      }
    }

    return nestedOptions;
  }

  /// Obtiene un campo por su ID
  DynamicFormField? getFieldById(String id) {
    for (final field in fields) {
      if (field.id == id) return field;

      // Buscar en los hijos
      for (final child in field.children) {
        if (child.id == id) return child;
      }
    }
    return null;
  }

  /// Obtiene todos los campos que necesitan respuesta (excluyendo títulos y opts solos)
  List<DynamicFormField> get answerableFields {
    return fields.where((f) => f.type != 'titulo').toList();
  }

  /// Obtiene todos los campos obligatorios
  List<DynamicFormField> get requiredFields {
    return answerableFields.where((f) => f.required).toList();
  }

  /// Cuenta total de campos
  int get fieldCount => answerableFields.length;

  /// Cuenta de campos obligatorios
  int get requiredFieldCount => requiredFields.length;

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fields': fields.map((f) => f.toJson()).toList(),
      if (category != null) 'category': category,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'isActive': isActive,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Crea una copia con modificaciones
  DynamicFormTemplate copyWith({
    String? id,
    String? title,
    String? description,
    List<DynamicFormField>? fields,
    String? category,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return DynamicFormTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      category: category ?? this.category,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'DynamicFormTemplate(id: $id, title: $title, fields: ${fields.length})';
  }
}

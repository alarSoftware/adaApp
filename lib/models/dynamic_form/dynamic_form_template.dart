import 'package:ada_app/models/dynamic_form/dynamic_form_field.dart';

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

  factory DynamicFormTemplate.fromApiJson(
      Map<String, dynamic> formJson,
      List<Map<String, dynamic>> detailsJson,
      ) {
    final sortedDetailsJson = List<Map<String, dynamic>>.from(detailsJson);
    sortedDetailsJson.sort((a, b) {
      final idA = _extractNumericId(a['id']);
      final idB = _extractNumericId(b['id']);
      return idA.compareTo(idB);
    });

    final allFields = sortedDetailsJson
        .map((detail) => DynamicFormField.fromApiJson(detail))
        .toList();

    // ⭐ NUEVA ESTRATEGIA: NO aplanar, mantener jerarquía completa
    final organizedFields = _organizeFieldsKeepingHierarchy(allFields);

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

  static int _extractNumericId(dynamic id) {
    if (id == null) return 999999;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 999999;
    return 999999;
  }

  static int _compareFields(DynamicFormField a, DynamicFormField b) {
    if (a.sequence != null && b.sequence != null) {
      return a.sequence!.compareTo(b.sequence!);
    }
    if (a.sequence != null) return -1;
    if (b.sequence != null) return 1;

    final idA = _extractNumericId(a.id);
    final idB = _extractNumericId(b.id);
    return idA.compareTo(idB);
  }

  /// ⭐ NUEVA ESTRATEGIA: Mantener la jerarquía completa sin aplanar
  static List<DynamicFormField> _organizeFieldsKeepingHierarchy(List<DynamicFormField> allFields) {
    // 1. Crear mapa de búsqueda rápida
    final Map<String, DynamicFormField> fieldsById = {};
    for (final field in allFields) {
      fieldsById[field.id] = field;
    }

    // 2. Agrupar hijos por parent_id
    Map<String, List<DynamicFormField>> childrenMap = {};
    for (final field in allFields) {
      if (field.parentId != null) {
        childrenMap.putIfAbsent(field.parentId!, () => []).add(field);
      }
    }

    // 3. Ordenar los hijos de cada padre
    childrenMap.forEach((parentId, children) {
      children.sort(_compareFields);
    });

    // 4. Construir árbol completo recursivamente
    DynamicFormField buildTree(DynamicFormField field) {
      final children = childrenMap[field.id] ?? [];
      final childrenWithTheirChildren = children.map((child) => buildTree(child)).toList();
      return field.withChildren(childrenWithTheirChildren);
    }

    // 5. Obtener campos raíz y construir árbol
    final rootFields = allFields.where((f) => f.parentId == null).toList();
    rootFields.sort(_compareFields);
    final fieldsWithChildren = rootFields.map((root) => buildTree(root)).toList();

    // 6. ⭐ NUEVA LÓGICA: Solo retornar campos de primer nivel
    // Los campos anidados se quedan en children y el widget los renderiza
    final List<DynamicFormField> topLevelFields = [];

    for (final root in fieldsWithChildren) {
      if (root.type == 'titulo') {
        topLevelFields.add(root);
        // Agregar solo los hijos directos que sean renderizables (no opts)
        for (final child in root.children) {
          if (child.type == 'radio_button' ||
              child.type == 'checkbox' ||
              child.type == 'resp_abierta' ||
              child.type == 'resp_abierta_larga') {
            topLevelFields.add(child);
          }
        }
      } else if (root.type == 'radio_button' || root.type == 'checkbox') {
        // Radio/Checkbox con su jerarquía completa de children
        topLevelFields.add(root);
      } else if (root.type == 'resp_abierta' || root.type == 'resp_abierta_larga') {
        // Campos de texto standalone
        topLevelFields.add(root);
      }
    }

    return topLevelFields;
  }

  /// Obtiene un campo por su ID (búsqueda recursiva completa)
  DynamicFormField? getFieldById(String id) {
    for (final field in fields) {
      if (field.id == id) return field;
      final found = _findFieldInChildren(field, id);
      if (found != null) return found;
    }
    return null;
  }

  /// Busca un campo en los hijos recursivamente
  DynamicFormField? _findFieldInChildren(DynamicFormField parent, String id) {
    for (final child in parent.children) {
      if (child.id == id) return child;
      final found = _findFieldInChildren(child, id);
      if (found != null) return found;
    }
    return null;
  }

  /// ⭐ SIMPLIFICADO: Ya no necesitamos getVisibleFields porque el widget maneja la visibilidad
  List<DynamicFormField> getVisibleFields(Map<String, dynamic> answers) {
    // Simplemente retornar todos los campos de primer nivel
    // El widget DynamicFormFieldWidget se encarga de mostrar/ocultar los children
    return fields;
  }

  /// Obtiene todos los campos que necesitan respuesta (recursivo)
  List<DynamicFormField> get answerableFields {
    List<DynamicFormField> answerable = [];

    void collectAnswerable(DynamicFormField field) {
      if (field.type != 'titulo' && field.type != 'opt') {
        answerable.add(field);
      }
      for (final child in field.children) {
        collectAnswerable(child);
      }
    }

    for (final field in fields) {
      collectAnswerable(field);
    }

    return answerable;
  }

  /// Obtiene todos los campos obligatorios (recursivo)
  List<DynamicFormField> get requiredFields {
    return answerableFields.where((f) => f.required).toList();
  }

  /// Cuenta total de campos
  int get fieldCount => answerableFields.length;

  /// Cuenta de campos obligatorios
  int get requiredFieldCount => requiredFields.length;

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
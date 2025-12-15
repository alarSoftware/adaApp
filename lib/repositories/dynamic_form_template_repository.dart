import '../models/dynamic_form/dynamic_form_template.dart';
import '../services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';

class DynamicFormTemplateRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String get _tableName => 'dynamic_form';
  String get _detailTableName => 'dynamic_form_detail';

  // ==================== MÉTODOS PARA TEMPLATES ====================

  /// Obtener todas las plantillas disponibles
  Future<List<DynamicFormTemplate>> getAll() async {
    try {
      final maps = await _dbHelper.consultar(
        _tableName,
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormTemplate> templates = [];

      for (var map in maps) {
        final template = await _mapToTemplateWithDetails(map);
        if (template != null) {
          templates.add(template);
        }
      }

      return templates;
    } catch (e) {
      return [];
    }
  }

  /// Obtener template por ID
  Future<DynamicFormTemplate?> getById(String id) async {
    try {
      final maps = await _dbHelper.consultar(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      return await _mapToTemplateWithDetails(maps.first);
    } catch (e) {
      return null;
    }
  }

  /// Obtener templates por estado
  Future<List<DynamicFormTemplate>> getByStatus(String estado) async {
    try {
      final maps = await _dbHelper.consultar(
        _tableName,
        where: 'estado = ?',
        whereArgs: [estado],
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormTemplate> templates = [];

      for (var map in maps) {
        final template = await _mapToTemplateWithDetails(map);
        if (template != null) {
          templates.add(template);
        }
      }

      return templates;
    } catch (e) {
      return [];
    }
  }

  /// Descargar templates desde el servidor (limpia antes de descargar)
  Future<bool> downloadFromServer() async {
    try {
      // 1. Limpiar formularios locales primero

      await _dbHelper.eliminar(_detailTableName);
      await _dbHelper.eliminar(_tableName);

      // 2. Descargar del servidor
      final resultado =
          await DynamicFormSyncService.obtenerFormulariosDinamicos();

      if (!resultado.exito) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Guardar templates desde el servidor
  Future<int> saveTemplatesFromServer(
    List<Map<String, dynamic>> templates,
  ) async {
    int saved = 0;

    try {
      for (final template in templates) {
        try {
          final formId = template['id'].toString();
          final existing = await _dbHelper.consultar(
            _tableName,
            where: 'id = ?',
            whereArgs: [formId],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            await _dbHelper.actualizar(
              _tableName,
              _mapTemplateForDB(template),
              where: 'id = ?',
              whereArgs: [formId],
            );
            saved++;
            continue;
          }

          await _dbHelper.insertar(_tableName, _mapTemplateForDB(template));
          saved++;
        } catch (e) {}
      }

      return saved;
    } catch (e) {
      return saved;
    }
  }

  /// Guardar detalles de templates desde el servidor
  Future<int> saveDetailsFromServer(List<Map<String, dynamic>> details) async {
    int saved = 0;

    try {
      for (final detail in details) {
        try {
          final detailId = detail['id'].toString();

          // Extraer formId
          String? formId;
          if (detail['dynamicForm'] != null && detail['dynamicForm'] is Map) {
            formId = detail['dynamicForm']['id']?.toString();
          }
          formId ??= detail['dynamicFormId']?.toString();
          formId ??= detail['dynamic_form_id']?.toString();
          formId ??= detail['formId']?.toString();

          if (formId == null) {
            continue;
          }

          // Verificar si existe
          final existing = await _dbHelper.consultar(
            _detailTableName,
            where: 'id = ?',
            whereArgs: [detailId],
            limit: 1,
          );

          final detailData = _mapDetailForDB(detail, formId);

          if (existing.isNotEmpty) {
            await _dbHelper.actualizar(
              _detailTableName,
              detailData,
              where: 'id = ?',
              whereArgs: [detailId],
            );
          } else {
            await _dbHelper.insertar(_detailTableName, detailData);
          }

          saved++;
        } catch (e) {}
      }

      return saved;
    } catch (e) {
      return saved;
    }
  }

  /// Eliminar template y sus detalles
  Future<bool> delete(String id) async {
    try {
      await _dbHelper.eliminar(
        _detailTableName,
        where: 'dynamic_form_id = ?',
        whereArgs: [id],
      );

      await _dbHelper.eliminar(_tableName, where: 'id = ?', whereArgs: [id]);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Contar templates
  Future<int> count() async {
    try {
      final maps = await _dbHelper.consultar(_tableName);
      return maps.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== MÉTODOS PRIVADOS DE MAPEO ====================

  /// Mapear template de BD a modelo con sus detalles
  Future<DynamicFormTemplate?> _mapToTemplateWithDetails(
    Map<String, dynamic> map,
  ) async {
    try {
      final formId = map['id']?.toString() ?? '';
      if (formId.isEmpty) {
        return null;
      }

      // Obtener detalles
      var details = await _dbHelper.consultar(
        _detailTableName,
        where: 'dynamic_form_id = ?',
        whereArgs: [formId],
      );

      if (details.isEmpty) {
        return null;
      }

      // ⚠️ FIX: Crear una copia MUTABLE de la lista antes de ordenar
      details = List<Map<String, dynamic>>.from(details);

      // Ordenar por ID
      details.sort((a, b) {
        final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        return idA.compareTo(idB);
      });

      // Preparar formJson
      final formJson = {
        'id': int.tryParse(formId) ?? formId,
        'name': map['name']?.toString() ?? 'Sin título',
        'estado': map['estado']?.toString() ?? 'BORRADOR',
        'totalPuntos': map['total_puntos'] ?? 0,
        'creationDate':
            map['creation_date']?.toString() ??
            DateTime.now().toIso8601String(),
        'lastUpdateDate': map['last_update_date']?.toString(),
        'creationUser': map['creator_user_id'] != null
            ? {'id': map['creator_user_id']}
            : null,
        'lastUpdateUser': map['last_update_user_id'],
      };

      // Preparar detailsJson
      final detailsJson = <Map<String, dynamic>>[];

      for (var detalle in details) {
        if (detalle['id'] == null || detalle['id'].toString().isEmpty) {
          continue;
        }

        detailsJson.add({
          'id': detalle['id'],
          'type': detalle['type']?.toString() ?? 'text',
          'label': detalle['label']?.toString() ?? 'Sin etiqueta',
          'parent': detalle['parent_id'] != null
              ? {'id': detalle['parent_id']}
              : null,
          'sequence': detalle['sequence'],
          'points': detalle['points'] ?? 0,
          'respuestaCorrectaOpt': _parseBooleanFromDb(
            detalle['respuesta_correcta_opt'],
          ),
          'respuestaCorrectaText': detalle['respuesta_correcta']?.toString(),
          'percentage': detalle['percentage'],
          'dynamicForm': {'id': formId},
        });
      }

      return DynamicFormTemplate.fromApiJson(formJson, detailsJson);
    } catch (e, stackTrace) {
      return null;
    }
  }

  /// Mapear template para BD
  Map<String, dynamic> _mapTemplateForDB(Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'].toString(),
      'last_update_user_id': apiData['lastUpdateUser']?['id'],
      'estado': apiData['estado'],
      'name': apiData['name'],
      'total_puntos': (apiData['totalPuntos'] ?? 0).toInt(),
      'creation_date':
          apiData['creationDate'] ?? DateTime.now().toIso8601String(),
      'creator_user_id': apiData['creationUser']?['id'],
      'last_update_date': apiData['lastUpdateDate'],
    };
  }

  /// Mapear detalle para BD
  Map<String, dynamic> _mapDetailForDB(
    Map<String, dynamic> apiData,
    String formId,
  ) {
    String? parentId;
    if (apiData['parent'] != null) {
      if (apiData['parent'] is Map) {
        parentId = apiData['parent']['id']?.toString();
      } else {
        parentId = apiData['parent'].toString();
      }
    }

    return {
      'id': apiData['id']?.toString() ?? '',
      'version': apiData['version'] ?? 1,
      'respuesta_correcta':
          apiData['respuestaCorrectaText']?.toString() ??
          apiData['respuestaCorrecta']?.toString(),
      'dynamic_form_id': formId,
      'sequence': apiData['sequence'] ?? 0,
      'points': apiData['points'] ?? 0,
      'type': apiData['type']?.toString() ?? 'text',
      'respuesta_correcta_opt': apiData['respuestaCorrectaOpt']?.toString(),
      'label': apiData['label']?.toString() ?? '',
      'parent_id': parentId,
      'percentage': apiData['percentage'],
    };
  }

  /// Parsear booleanos desde BD
  bool? _parseBooleanFromDb(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final stringValue = value.toString().toLowerCase();
    if (stringValue == 'true' || stringValue == '1') return true;
    if (stringValue == 'false' || stringValue == '0') return false;

    return null;
  }
}

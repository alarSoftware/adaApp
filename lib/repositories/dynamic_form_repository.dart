import 'dart:convert';
import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_template.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../adapter/dynamic_form_api_adapter.dart';
import '../services/database_helper.dart';

class DynamicFormRepository {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Nombres de tablas según tu BD
  String get tableName => 'dynamic_form';
  String get detailTableName => 'dynamic_form_detail';
  String get responseTableName => 'dynamic_form_response';
  String get responseDetailTableName => 'dynamic_form_response_detail';

  // ==================== MÉTODOS PARA PLANTILLAS ====================

  /// Obtener plantillas disponibles (templates)
  Future<List<DynamicFormTemplate>> getAvailableTemplates() async {
    return await obtenerTodos();
  }

  /// Descargar plantillas desde el servidor
  Future<bool> downloadTemplatesFromServer() async {
    try {
      _logger.i('📋 Solicitud de descarga de formularios desde servidor');
      return true;
    } catch (e) {
      _logger.e('❌ Error descargando plantillas: $e');
      return false;
    }
  }

  /// Guardar formularios desde el servidor en la base de datos local
  Future<int> guardarFormulariosDesdeServidor(List<Map<String, dynamic>> formulariosServidor) async {
    int guardados = 0;

    try {
      for (final form in formulariosServidor) {
        try {
          _logger.i('📦 Procesando formulario: ${form['id']}');

          final formId = form['id'].toString();
          final existente = await _dbHelper.consultar(
            tableName,
            where: 'id = ?',
            whereArgs: [formId],
            limit: 1,
          );

          if (existente.isNotEmpty) {
            _logger.i('⏭️ Formulario ya existe - Actualizando');
            await _dbHelper.actualizar(
              tableName,
              _mapearFormularioParaBD(form),
              where: 'id = ?',
              whereArgs: [formId],
            );
            guardados++;
            continue;
          }

          await _dbHelper.insertar(
            tableName,
            _mapearFormularioParaBD(form),
          );

          guardados++;
          _logger.i('✅ Formulario insertado: ${form['name']}');

        } catch (e) {
          _logger.w('⚠️ Error guardando formulario individual: $e');
        }
      }

      _logger.i('✅ Formularios guardados: $guardados de ${formulariosServidor.length}');
      return guardados;

    } catch (e) {
      _logger.e('❌ Error guardando formularios: $e');
      return guardados;
    }
  }

  /// Mapear datos del servidor a formato de BD local (tabla dynamic_form)
  Map<String, dynamic> _mapearFormularioParaBD(Map<String, dynamic> apiData) {
    return {
      'id': apiData['id'].toString(),
      'last_update_user_id': apiData['lastUpdateUser']?['id'],
      'estado': apiData['estado'],
      'name': apiData['name'],
      'total_puntos': (apiData['totalPuntos'] ?? 0).toInt(),
      'creation_date': apiData['creationDate'] ?? DateTime.now().toIso8601String(),
      'creator_user_id': apiData['creationUser']?['id'],
      'last_update_date': apiData['lastUpdateDate'],
    };
  }

  /// Obtener todos los formularios con sus detalles
  Future<List<DynamicFormTemplate>> obtenerTodos() async {
    try {
      final maps = await _dbHelper.consultar(
        tableName,
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormTemplate> templates = [];

      for (var map in maps) {
        final template = await _mapearBDaTemplateConDetalles(map);
        if (template != null) {
          templates.add(template);
        }
      }

      _logger.i('✅ Templates cargados desde BD: ${templates.length}');
      return templates;
    } catch (e) {
      _logger.e('❌ Error obteniendo formularios: $e');
      return [];
    }
  }

  /// Obtener formulario por ID con sus detalles
  Future<DynamicFormTemplate?> obtenerPorId(String id) async {
    try {
      final maps = await _dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      return await _mapearBDaTemplateConDetalles(maps.first);
    } catch (e) {
      _logger.e('❌ Error obteniendo formulario por ID: $e');
      return null;
    }
  }

  /// Obtener formularios por estado
  Future<List<DynamicFormTemplate>> obtenerPorEstado(String estado) async {
    try {
      final maps = await _dbHelper.consultar(
        tableName,
        where: 'estado = ?',
        whereArgs: [estado],
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormTemplate> templates = [];

      for (var map in maps) {
        final template = await _mapearBDaTemplateConDetalles(map);
        if (template != null) {
          templates.add(template);
        }
      }

      return templates;
    } catch (e) {
      _logger.e('❌ Error obteniendo formularios por estado: $e');
      return [];
    }
  }

  /// ✅ MÉTODO MEJORADO: Mapear datos de BD a DynamicFormTemplate con ordenamiento correcto
  Future<DynamicFormTemplate?> _mapearBDaTemplateConDetalles(Map<String, dynamic> map) async {
    try {
      _logger.d('🔍 === INICIO MAPEO TEMPLATE ===');
      _logger.d('📋 Map recibido: $map');

      // Validar formId
      final formId = map['id']?.toString() ?? '';
      if (formId.isEmpty) {
        _logger.e('❌ Formulario sin ID');
        return null;
      }

      _logger.d('✅ FormID: $formId');

      // Obtener detalles
      _logger.d('🔍 Consultando detalles para form_id: $formId');
      var detalles = await _dbHelper.consultar(
        detailTableName,
        where: 'dynamic_form_id = ?',
        whereArgs: [formId],
      );

      _logger.i('📋 Formulario "${map['name']}": ${detalles.length} detalles encontrados');

      // Si no hay detalles, retornar null o template vacío según tu lógica
      if (detalles.isEmpty) {
        _logger.w('⚠️ Formulario sin detalles, retornando null');
        return null;
      }

      // Ordenar por ID
      try {
        detalles.sort((a, b) {
          final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
          final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
          return idA.compareTo(idB);
        });
        _logger.d('✅ ${detalles.length} detalles ordenados por ID');
      } catch (e) {
        _logger.w('⚠️ Error ordenando detalles: $e (continuando sin ordenar)');
      }

      // Preparar formJson
      final formJson = {
        'id': int.tryParse(formId) ?? formId,
        'name': map['name']?.toString() ?? 'Sin título',
        'estado': map['estado']?.toString() ?? 'BORRADOR',
        'totalPuntos': map['total_puntos'] ?? 0,
        'creationDate': map['creation_date']?.toString() ?? DateTime.now().toIso8601String(),
        'lastUpdateDate': map['last_update_date']?.toString(),
        'creationUser': map['creator_user_id'] != null
            ? {'id': map['creator_user_id']}
            : null,
        'lastUpdateUser': map['last_update_user_id'],
      };

      _logger.d('✅ formJson: ${formJson['name']} (ID: ${formJson['id']})');

      // Preparar detailsJson
      final detailsJson = <Map<String, dynamic>>[];

      for (var detalle in detalles) {
        try {
          // Validar ID del detalle
          if (detalle['id'] == null || detalle['id'].toString().isEmpty) {
            _logger.w('⚠️ Detalle sin ID, omitiendo');
            continue;
          }

          final detalleMap = {
            'id': detalle['id'],
            'type': detalle['type']?.toString() ?? 'text',
            'label': detalle['label']?.toString() ?? 'Sin etiqueta',
            'parent': detalle['parent_id'] != null
                ? {'id': detalle['parent_id']}
                : null,
            'sequence': detalle['sequence'],
            'points': detalle['points'] ?? 0,
            'respuestaCorrectaOpt': _parseBooleanFromDb(detalle['respuesta_correcta_opt']),
            'respuestaCorrectaText': detalle['respuesta_correcta']?.toString(),
            'percentage': detalle['percentage'],
            'dynamicForm': {'id': formId},
          };

          detailsJson.add(detalleMap);

        } catch (e) {
          _logger.w('⚠️ Error procesando detalle ${detalle['id']}: $e');
          continue;
        }
      }

      _logger.i('✅ ${detailsJson.length} detalles procesados correctamente');

      if (detailsJson.isEmpty) {
        _logger.e('❌ No se pudo procesar ningún detalle');
        return null;
      }

      // Crear template
      _logger.d('🔨 Creando DynamicFormTemplate...');

      final template = DynamicFormTemplate.fromApiJson(formJson, detailsJson);

      _logger.i('✅ Template creado: "${template.title}" con ${template.fields.length} campos');
      _logger.d('🔍 === FIN MAPEO TEMPLATE ===\n');

      return template;

    } catch (e, stackTrace) {
      _logger.e('❌ ERROR CRÍTICO en _mapearBDaTemplateConDetalles: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parsear valores booleanos desde la BD
  bool? _parseBooleanFromDb(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final stringValue = value.toString().toLowerCase();
    if (stringValue == 'true' || stringValue == '1') return true;
    if (stringValue == 'false' || stringValue == '0') return false;

    return null;
  }

  // ==================== MÉTODOS PARA RESPUESTAS ====================

  /// Guardar detalles de respuestas en dynamic_form_response_detail
  Future<bool> saveResponse(DynamicFormResponse response) async {
    try {
      _logger.i('💾 Guardando respuesta: ${response.id}');

      // Validar que los campos requeridos no sean null
      if (response.id.isEmpty || response.formTemplateId.isEmpty) {
        _logger.e('❌ Response con ID o formTemplateId vacío');
        return false;
      }

      // Guardar en tabla dynamic_form_response
      final responseData = {
        'id': response.id,
        'version': 1,
        'cliente_id': response.clienteId ?? '',
        'last_update_user_id': null,
        'dynamic_form_id': response.formTemplateId,
        'usuario_id': response.userId != null ? int.tryParse(response.userId!) : null,
        'estado': response.status,
        'creation_date': response.createdAt.toIso8601String(),
        'creation_user_id': response.userId != null ? int.tryParse(response.userId!) : null,
        'last_update_date': response.completedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
      };

      // Verificar si existe
      final existe = await _dbHelper.consultar(
        responseTableName,
        where: 'id = ?',
        whereArgs: [response.id],
        limit: 1,
      );

      if (existe.isNotEmpty) {
        await _dbHelper.actualizar(
          responseTableName,
          responseData,
          where: 'id = ?',
          whereArgs: [response.id],
        );
        _logger.d('🔄 Respuesta actualizada');
      } else {
        await _dbHelper.insertar(responseTableName, responseData);
        _logger.d('➕ Respuesta insertada');
      }

      // Guardar detalles de respuestas (answers)
      await _guardarRespuestasDetalle(response);

      _logger.i('✅ Respuesta guardada exitosamente: ${response.id}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando respuesta: $e');
      _logger.e('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _guardarRespuestasDetalle(DynamicFormResponse response) async {
    try {
      // Primero eliminar detalles existentes
      await _dbHelper.eliminar(
        responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [response.id],
      );

      _logger.d('📝 Guardando ${response.answers.length} respuestas detalle');

      // Insertar nuevos detalles
      for (var entry in response.answers.entries) {
        // Validar que la key no esté vacía
        if (entry.key.isEmpty) {
          _logger.w('⚠️ Campo con ID vacío, omitiendo');
          continue;
        }

        final detailData = {
          'id': '${response.id}_${entry.key}',
          'version': 1,
          'response': entry.value?.toString() ?? '',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
        };

        await _dbHelper.insertar(responseDetailTableName, detailData);
        _logger.d('  ✓ Campo ${entry.key}: ${entry.value}');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando detalles de respuesta: $e');
      _logger.e('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Obtener respuestas locales
  Future<List<DynamicFormResponse>> getLocalResponses() async {
    try {
      final maps = await _dbHelper.consultar(
        responseTableName,
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormResponse> responses = [];

      for (var map in maps) {
        final response = await _mapearBDaResponseConDetalles(map);
        if (response != null) {
          responses.add(response);
        }
      }

      _logger.i('✅ Respuestas locales cargadas: ${responses.length}');
      return responses;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas locales: $e');
      return [];
    }
  }

  /// Obtener respuestas pendientes de sincronización
  Future<List<DynamicFormResponse>> getPendingResponses() async {
    try {
      final maps = await _dbHelper.consultar(
        responseTableName,
        where: 'estado IN (?, ?)',
        whereArgs: ['pending', 'completed'],
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormResponse> responses = [];

      for (var map in maps) {
        final response = await _mapearBDaResponseConDetalles(map);
        if (response != null) {
          responses.add(response);
        }
      }

      return responses;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas pendientes: $e');
      return [];
    }
  }

  /// Mapear datos de BD a DynamicFormResponse con sus detalles
  Future<DynamicFormResponse?> _mapearBDaResponseConDetalles(Map<String, dynamic> map) async {
    try {
      // Validar que tenga ID
      if (map['id'] == null) {
        _logger.e('❌ Response sin ID');
        return null;
      }

      // Obtener los detalles de respuestas
      final detalles = await _dbHelper.consultar(
        responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [map['id']],
      );

      // Construir el Map de answers
      Map<String, dynamic> answers = {};
      for (var detalle in detalles) {
        final fieldId = detalle['dynamic_form_detail_id']?.toString();
        if (fieldId != null && fieldId.isNotEmpty) {
          answers[fieldId] = detalle['response'];
        }
      }

      // Parsear fechas de forma segura
      DateTime? parseDateTime(dynamic value) {
        if (value == null) return null;
        try {
          return DateTime.parse(value.toString());
        } catch (e) {
          _logger.w('⚠️ Error parseando fecha: $value');
          return null;
        }
      }

      final createdAt = parseDateTime(map['creation_date']) ?? DateTime.now();
      final estado = map['estado']?.toString() ?? 'draft';

      return DynamicFormResponse(
        id: map['id'].toString(),
        formTemplateId: map['dynamic_form_id']?.toString() ?? '',
        answers: answers,
        createdAt: createdAt,
        completedAt: estado == 'completed'
            ? parseDateTime(map['last_update_date'])
            : null,
        syncedAt: estado == 'synced' ? DateTime.now() : null,
        status: estado,
        userId: map['usuario_id']?.toString(),
        clienteId: map['cliente_id']?.toString(),
        equipoId: null,
        metadata: null,
        errorMessage: null,
      );
    } catch (e, stackTrace) {
      _logger.e('❌ Error mapeando response: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Sincronizar una respuesta al servidor
  Future<bool> syncResponse(DynamicFormResponse response) async {
    try {
      _logger.i('📤 Sincronizando respuesta: ${response.id}');

      // TODO: Implementar llamada real al API
      // Por ahora solo actualizamos el estado local
      final syncedResponse = response.markAsSynced();
      return await saveResponse(syncedResponse);
    } catch (e) {
      _logger.e('❌ Error sincronizando respuesta: $e');
      return false;
    }
  }

  /// Sincronizar todas las respuestas pendientes
  Future<Map<String, int>> syncAllPendingResponses() async {
    int success = 0;
    int failed = 0;

    try {
      final pending = await getPendingResponses();
      _logger.i('📤 Sincronizando ${pending.length} respuestas pendientes');

      for (final response in pending) {
        final result = await syncResponse(response);
        if (result) {
          success++;
        } else {
          failed++;
        }
      }

      _logger.i('✅ Sincronización completada: $success exitosas, $failed fallidas');
    } catch (e) {
      _logger.e('❌ Error en sincronización masiva: $e');
    }

    return {'success': success, 'failed': failed};
  }

  /// Eliminar una respuesta
  Future<bool> deleteResponse(String responseId) async {
    try {
      // Primero eliminar los detalles
      await _dbHelper.eliminar(
        responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      // Luego eliminar la respuesta
      await _dbHelper.eliminar(
        responseTableName,
        where: 'id = ?',
        whereArgs: [responseId],
      );

      _logger.i('✅ Respuesta eliminada: $responseId');
      return true;
    } catch (e) {
      _logger.e('❌ Error eliminando respuesta: $e');
      return false;
    }
  }

  /// Guardar todos los detalles de todos los formularios
  Future<int> guardarTodosLosDetallesDesdeServidor(
      List<Map<String, dynamic>> detallesServidor
      ) async {
    int guardados = 0;

    try {
      for (final detalle in detallesServidor) {
        try {
          final detalleId = detalle['id'].toString();

          // Extraer el ID del objeto anidado dynamicForm
          String? formId;

          if (detalle['dynamicForm'] != null && detalle['dynamicForm'] is Map) {
            formId = detalle['dynamicForm']['id']?.toString();
          }

          formId ??= detalle['dynamicFormId']?.toString();
          formId ??= detalle['dynamic_form_id']?.toString();
          formId ??= detalle['formId']?.toString();

          if (formId == null) {
            _logger.w('⚠️ Detalle sin dynamicFormId: ${detalle['id']}');
            continue;
          }

          // Verificar si ya existe
          final existente = await _dbHelper.consultar(
            detailTableName,
            where: 'id = ?',
            whereArgs: [detalleId],
            limit: 1,
          );

          final detalleData = _mapearDetalleParaBD(detalle, formId);

          if (existente.isNotEmpty) {
            await _dbHelper.actualizar(
              detailTableName,
              detalleData,
              where: 'id = ?',
              whereArgs: [detalleId],
            );
          } else {
            await _dbHelper.insertar(detailTableName, detalleData);
          }

          guardados++;
        } catch (e) {
          _logger.w('⚠️ Error guardando detalle individual: $e');
        }
      }

      _logger.i('✅ Detalles guardados: $guardados de ${detallesServidor.length}');
      return guardados;

    } catch (e) {
      _logger.e('❌ Error guardando detalles: $e');
      return guardados;
    }
  }

  /// Mapear detalle del servidor a formato de BD
  Map<String, dynamic> _mapearDetalleParaBD(Map<String, dynamic> apiData, String formId) {
    // Extraer parentId si viene como objeto anidado
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
      'respuesta_correcta': apiData['respuestaCorrectaText']?.toString() ??
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

  // ==================== MÉTODOS AUXILIARES ====================

  /// Contar formularios
  Future<int> contarFormularios() async {
    try {
      final maps = await _dbHelper.consultar(tableName);
      return maps.length;
    } catch (e) {
      _logger.e('❌ Error contando formularios: $e');
      return 0;
    }
  }

  /// Guardar detalles de un formulario específico desde el servidor
  Future<int> guardarDetallesDesdeServidor(
      List<Map<String, dynamic>> detallesServidor,
      String formId
      ) async {
    int guardados = 0;

    try {
      for (final detalle in detallesServidor) {
        try {
          _logger.i('📦 Procesando detalle: ${detalle['id']}');

          final detalleId = detalle['id'].toString();

          // Verificar si ya existe
          final existente = await _dbHelper.consultar(
            detailTableName,
            where: 'id = ?',
            whereArgs: [detalleId],
            limit: 1,
          );

          final detalleData = _mapearDetalleParaBD(detalle, formId);

          if (existente.isNotEmpty) {
            _logger.i('⏭️ Detalle ya existe - Actualizando');
            await _dbHelper.actualizar(
              detailTableName,
              detalleData,
              where: 'id = ?',
              whereArgs: [detalleId],
            );
          } else {
            await _dbHelper.insertar(detailTableName, detalleData);
          }

          guardados++;
          _logger.i('✅ Detalle insertado/actualizado: ${detalle['label'] ?? detalle['id']}');

        } catch (e) {
          _logger.w('⚠️ Error guardando detalle individual: $e');
        }
      }

      _logger.i('✅ Detalles guardados: $guardados de ${detallesServidor.length}');
      return guardados;

    } catch (e) {
      _logger.e('❌ Error guardando detalles: $e');
      return guardados;
    }
  }

  /// Eliminar formulario (template) y sus detalles
  Future<bool> eliminar(String id) async {
    try {
      // Primero eliminar los detalles
      await _dbHelper.eliminar(
        detailTableName,
        where: 'dynamic_form_id = ?',
        whereArgs: [id],
      );

      // Luego eliminar el formulario
      await _dbHelper.eliminar(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      _logger.i('✅ Formulario eliminado: $id');
      return true;
    } catch (e) {
      _logger.e('❌ Error eliminando formulario: $e');
      return false;
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_response_detail.dart';
import '../models/dynamic_form/dynamic_form_response_image.dart';
import '../services/database_helper.dart';

class DynamicFormResponseRepository {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = Uuid();

  // ==================== CONSTANTES ====================

  static const String _responseTable = 'dynamic_form_response';
  static const String _detailTable = 'dynamic_form_response_detail';
  static const String _imageTable = 'dynamic_form_response_image';

  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};

  static const Map<String, String> _mimeTypes = {
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
  };

  // ==================== MÉTODOS PÚBLICOS - RESPUESTAS ====================

  Future<bool> save(DynamicFormResponse response) async {
    try {
      _logger.i('💾 Guardando respuesta: ${response.id}');

      if (response.id.isEmpty || response.formTemplateId.isEmpty) {
        _logger.e('❌ Response con ID o formTemplateId vacío');
        return false;
      }

      final responseData = _buildResponseData(response);
      await _upsertResponse(response.id, responseData);
      await _saveResponseDetails(response);

      _logger.i('✅ Respuesta guardada exitosamente: ${response.id}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando respuesta: $e\n$stackTrace');
      return false;
    }
  }

  Future<List<DynamicFormResponse>> getAll() async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTable,
        orderBy: 'creation_date DESC',
      );

      return await _mapListToResponses(maps);
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas: $e');
      return [];
    }
  }

  Future<DynamicFormResponse?> getById(String id) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return await _mapToResponseWithDetails(maps.first);
    } catch (e) {
      _logger.e('❌ Error obteniendo respuesta por ID: $e');
      return null;
    }
  }

  Future<List<DynamicFormResponse>> getByStatus(String status) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTable,
        where: 'estado = ?',
        whereArgs: [status],
        orderBy: 'creation_date DESC',
      );

      return await _mapListToResponses(maps);
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas por estado: $e');
      return [];
    }
  }

  Future<List<DynamicFormResponse>> getPendingSync() async {
    try {
      final maps = await _dbHelper.consultar(
        'dynamic_form_response',
        where: 'estado = ?',  // ✅ Solo buscar 'completed'
        whereArgs: ['completed'],
        orderBy: 'creation_date ASC',
      );

      _logger.d('📤 Formularios completados para sincronizar: ${maps.length}');
      return await _mapListToResponses(maps);

    } catch (e) {
      _logger.e('❌ Error obteniendo pendientes: $e');
      return [];
    }
  }

  Future<bool> delete(String responseId) async {
    try {
      _logger.i('🗑️ Eliminando respuesta: $responseId');

      final images = await getImagesForResponse(responseId);
      await _deleteImageFiles(images);
      await _deleteImageRecords(images);
      await _deleteDetails(responseId);
      await _deleteResponse(responseId);

      _logger.i('✅ Respuesta eliminada completamente: $responseId');
      return true;
    } catch (e) {
      _logger.e('❌ Error eliminando respuesta: $e');
      return false;
    }
  }

  // ==================== MÉTODOS PÚBLICOS - CONTADORES ====================

  Future<int> countPendingSync() async {
    try {
      final result = await _dbHelper.database.then((db) =>
          db.rawQuery(
              'SELECT COUNT(*) as count FROM dynamic_form_response WHERE estado = ?',
              ['completed']
          )
      );

      // ✅ CORRECCIÓN: Usar el método correcto
      final count = result.first['count'] as int?;
      return count ?? 0;

    } catch (e) {
      _logger.e('❌ Error contando pendientes: $e');
      return 0;
    }
  }

  Future<int> countSynced() async {
    return await _count(
      where: 'sync_status = ?',
      whereArgs: ['synced'],
    );
  }

  // ==================== MÉTODOS PÚBLICOS - METADATA ====================

  Future<Map<String, dynamic>> getSyncMetadata(String responseId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        _responseTable,
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (result.isEmpty) return _getDefaultSyncMetadata();

      final map = result.first;
      return {
        'sync_status': map['sync_status'] ?? 'pending',
        'intentos_sync': map['intentos_sync'] ?? 0,
        'mensaje_error_sync': map['mensaje_error_sync'],
        'fecha_sincronizado': map['fecha_sincronizado'],
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo sync metadata: $e');
      return _getDefaultSyncMetadata();
    }
  }

  // ==================== MÉTODOS PÚBLICOS - DETALLES ====================

  Future<List<DynamicFormResponseDetail>> getDetails(String responseId) async {
    try {
      final maps = await _dbHelper.consultar(
        _detailTable,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      return maps.map((map) => DynamicFormResponseDetail.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo detalles: $e');
      return [];
    }
  }

  // ==================== MÉTODOS PÚBLICOS - IMÁGENES ====================

  Future<List<DynamicFormResponseImage>> getImagesForDetail(String detailId) async {
    try {
      final maps = await _dbHelper.consultar(
        _imageTable,
        where: 'dynamic_form_response_detail_id = ?',
        whereArgs: [detailId],
        orderBy: 'orden ASC',
      );

      return maps.map((map) => DynamicFormResponseImage.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo imágenes del detalle: $e');
      return [];
    }
  }

  Future<List<DynamicFormResponseImage>> getImagesForResponse(String responseId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT i.* 
        FROM $_imageTable i
        INNER JOIN $_detailTable d 
          ON i.dynamic_form_response_detail_id = d.id
        WHERE d.dynamic_form_response_id = ?
        ORDER BY i.orden ASC
      ''', [responseId]);

      return maps.map((map) => DynamicFormResponseImage.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo imágenes de la respuesta: $e');
      return [];
    }
  }

  Future<void> deleteImageFile(DynamicFormResponseImage image) async {
    if (image.imagenPath == null || image.imagenPath!.isEmpty) return;

    try {
      final file = File(image.imagenPath!);
      if (await file.exists()) {
        await file.delete();
        _logger.d('🗑️ Archivo eliminado: ${image.imagenPath}');
      }
    } catch (e) {
      _logger.w('⚠️ No se pudo eliminar archivo: ${image.imagenPath} - $e');
    }
  }

  // ==================== MÉTODOS PÚBLICOS - SINCRONIZACIÓN CON SERVIDOR ====================

  Future<int> saveResponsesFromServer(List<Map<String, dynamic>> responses) async {
    int count = 0;

    for (var responseData in responses) {
      try {
        final responseMap = _buildServerResponseData(responseData);
        await _upsertResponse(responseMap['id'], responseMap);

        final details = responseData['details'] as List<dynamic>? ?? [];
        if (details.isNotEmpty) {
          await _saveServerDetails(responseMap['id'], details);
        }

        count++;
      } catch (e, stackTrace) {
        _logger.e('❌ Error guardando response desde servidor: $e\n$stackTrace');
      }
    }

    _logger.i('💾 Total de responses guardados desde servidor: $count');
    return count;
  }

  Future<int> saveResponseDetailsFromServer(List<Map<String, dynamic>> details) async {
    int count = 0;

    for (var detailData in details) {
      try {
        final detailForDB = {
          'id': detailData['id']?.toString() ?? _uuid.v4(),
          'version': 1,
          'response': detailData['response']?.toString() ?? '',
          'dynamic_form_response_id': detailData['dynamicFormResponseId']?.toString() ?? '',
          'dynamic_form_detail_id': detailData['dynamicFormDetailId']?.toString() ?? '',
          'sync_status': 'synced',
        };

        await _dbHelper.insertar(_detailTable, detailForDB);
        count++;
      } catch (e) {
        _logger.e('❌ Error guardando detalle desde servidor: $e');
      }
    }

    _logger.i('✅ Total detalles guardados: $count');
    return count;
  }

  // ==================== MÉTODOS PRIVADOS - CONSTRUCCIÓN DE DATOS ====================

  Map<String, dynamic> _buildResponseData(DynamicFormResponse response) {
    return {
      'id': response.id,
      'version': 1,
      'contacto_id': response.contactoId ?? '',
      'edf_vendedor_id': response.edfVendedorId,
      'last_update_user_id': null,
      'dynamic_form_id': response.formTemplateId,
      'usuario_id': response.userId != null ? int.tryParse(response.userId!) : null,
      'estado': response.status,
      'sync_status': 'pending',
      'intentos_sync': 0,
      'creation_date': response.createdAt.toIso8601String(),
      'last_update_date': response.completedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _buildServerResponseData(Map<String, dynamic> data) {
    return {
      'id': data['id'].toString(),
      'version': 1,
      'contacto_id': data['contactoId']?.toString() ?? '',
      'edf_vendedor_id': data['edfVendedorId']?.toString(),
      'last_update_user_id': null,
      'dynamic_form_id': data['dynamicFormId'].toString(),
      'usuario_id': data['usuarioId'] != null ? int.tryParse(data['usuarioId'].toString()) : null,
      'estado': data['estado'] as String? ?? 'completed',
      'sync_status': 'synced',
      'intentos_sync': 0,
      'creation_date': data['creationDate'] as String,
      'last_update_date': data['completedDate'] ?? data['creationDate'],
      'fecha_sincronizado': DateTime.now().toIso8601String(),
    };
  }

  // ==================== MÉTODOS PRIVADOS - OPERACIONES DB ====================

  Future<void> _upsertResponse(String id, Map<String, dynamic> data) async {
    final existing = await _dbHelper.consultar(
      _responseTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await _dbHelper.actualizar(_responseTable, data, where: 'id = ?', whereArgs: [id]);
      _logger.d('🔄 Respuesta actualizada');
    } else {
      await _dbHelper.insertar(_responseTable, data);
      _logger.d('➕ Respuesta insertada');
    }
  }

  Future<void> _saveResponseDetails(DynamicFormResponse response) async {
    await _dbHelper.eliminar(
      _detailTable,
      where: 'dynamic_form_response_id = ?',
      whereArgs: [response.id],
    );

    _logger.d('📝 Guardando ${response.answers.length} respuestas detalle');

    for (var entry in response.answers.entries) {
      if (entry.key.isEmpty) {
        _logger.w('⚠️ Campo con ID vacío, omitiendo');
        continue;
      }

      final detailId = _uuid.v4();

      if (_isImagePath(entry.value)) {
        await _saveImageForDetail(
          detailId: detailId,
          responseId: response.id,
          fieldId: entry.key,
          imagePath: entry.value as String,
          isCompleted: response.status == 'completed',
        );

        await _dbHelper.insertar(_detailTable, {
          'id': detailId,
          'version': 1,
          'response': '[IMAGE]',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
          'sync_status': 'pending',
        });

        _logger.d('  ✓ Campo ${entry.key}: [IMAGEN en tabla separada]');
      } else {
        await _dbHelper.insertar(_detailTable, {
          'id': detailId,
          'version': 1,
          'response': entry.value?.toString() ?? '',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
          'sync_status': 'pending',
        });

        _logger.d('  ✓ Campo ${entry.key}: ${entry.value}');
      }
    }
  }

  Future<void> _saveServerDetails(String responseId, List<dynamic> details) async {
    _logger.d('📝 Guardando ${details.length} detalles desde servidor');

    await _dbHelper.eliminar(
      _detailTable,
      where: 'dynamic_form_response_id = ?',
      whereArgs: [responseId],
    );

    for (var detail in details) {
      await _dbHelper.insertar(_detailTable, {
        'id': detail['id'].toString(),
        'version': 1,
        'response': detail['response']?.toString() ?? '',
        'dynamic_form_response_id': responseId,
        'dynamic_form_detail_id': detail['dynamicFormDetailId'].toString(),
        'sync_status': 'synced',
      });
    }
  }

  Future<void> _saveImageForDetail({
    required String detailId,
    required String responseId,
    required String fieldId,
    required String imagePath,
    required bool isCompleted,
    int orden = 1,
  }) async {
    try {
      final imageId = _uuid.v4();
      String? imagenBase64;
      int? imagenTamano;

      if (isCompleted) {
        final imageData = await _convertImageToBase64(imagePath);
        imagenBase64 = imageData['base64'];
        imagenTamano = imageData['tamano'];
      }

      await _dbHelper.insertar(_imageTable, {
        'id': imageId,
        'dynamic_form_response_detail_id': detailId,
        'imagen_path': imagePath,
        'imagen_base64': imagenBase64,
        'imagen_tamano': imagenTamano,
        'mime_type': _getMimeType(imagePath),
        'orden': orden,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      });

      _logger.d('✅ Imagen guardada: $imageId');
    } catch (e) {
      _logger.e('❌ Error guardando imagen: $e');
      rethrow;
    }
  }

  Future<void> _deleteImageFiles(List<DynamicFormResponseImage> images) async {
    for (var image in images) {
      await deleteImageFile(image);
    }
  }

  Future<void> _deleteImageRecords(List<DynamicFormResponseImage> images) async {
    for (var image in images) {
      await _dbHelper.eliminar(_imageTable, where: 'id = ?', whereArgs: [image.id]);
    }
    _logger.d('🗑️ ${images.length} registros de imágenes eliminados');
  }

  Future<void> _deleteDetails(String responseId) async {
    await _dbHelper.eliminar(
      _detailTable,
      where: 'dynamic_form_response_id = ?',
      whereArgs: [responseId],
    );
  }

  Future<void> _deleteResponse(String responseId) async {
    await _dbHelper.eliminar(_responseTable, where: 'id = ?', whereArgs: [responseId]);
  }

  Future<int> _count({String? where, List<dynamic>? whereArgs}) async {
    try {
      return await _dbHelper.contarRegistros(_responseTable, where: where, whereArgs: whereArgs);
    } catch (e) {
      _logger.e('❌ Error contando registros: $e');
      return 0;
    }
  }

  // ==================== MÉTODOS PRIVADOS - MAPEO ====================

  Future<List<DynamicFormResponse>> _mapListToResponses(
      List<Map<String, dynamic>> maps,
      ) async {
    final List<DynamicFormResponse> responses = [];

    for (var map in maps) {
      final response = await _mapToResponseWithDetails(map);
      if (response != null) {
        responses.add(response);
      }
    }

    return responses;
  }

  Future<DynamicFormResponse?> _mapToResponseWithDetails(
      Map<String, dynamic> map,
      ) async {
    try {
      if (map['id'] == null) {
        _logger.e('❌ Response sin ID');
        return null;
      }

      final answers = await _loadAnswers(map['id']);

      return DynamicFormResponse(
        id: map['id'].toString(),
        formTemplateId: map['dynamic_form_id']?.toString() ?? '',
        answers: answers,
        createdAt: _parseDateTime(map['creation_date']) ?? DateTime.now(),
        completedAt: map['estado'] == 'completed' || map['estado'] == 'synced'
            ? _parseDateTime(map['last_update_date'])
            : null,
        // ✅ CORREGIR: Leer fecha_sincronizado de la BD
        syncedAt: _parseDateTime(map['fecha_sincronizado']),
        status: map['estado']?.toString() ?? 'draft',
        userId: map['usuario_id']?.toString(),
        contactoId: map['contacto_id']?.toString(),
        edfVendedorId: map['edf_vendedor_id']?.toString(),
        errorMessage: map['mensaje_error_sync']?.toString(),
      );
    } catch (e, stackTrace) {
      _logger.e('❌ Error mapeando response: $e\n$stackTrace');
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadAnswers(String responseId) async {
    final detalles = await _dbHelper.consultar(
      _detailTable,
      where: 'dynamic_form_response_id = ?',
      whereArgs: [responseId],
    );

    final Map<String, dynamic> answers = {};

    for (var detalle in detalles) {
      final fieldId = detalle['dynamic_form_detail_id']?.toString();
      if (fieldId == null || fieldId.isEmpty) continue;

      final response = detalle['response']?.toString();

      if (response == '[IMAGE]') {
        final imagenes = await getImagesForDetail(detalle['id']);
        if (imagenes.isNotEmpty) {
          answers[fieldId] = imagenes.first.imagenPath ?? '';
        }
      } else {
        answers[fieldId] = response ?? '';
      }
    }

    return answers;
  }

  // ==================== MÉTODOS PRIVADOS - HELPERS ====================

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      _logger.w('⚠️ Error parseando fecha: $value');
      return null;
    }
  }

  bool _isImagePath(dynamic value) {
    if (value is! String || value.isEmpty) return false;

    final lower = value.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext)) ||
        lower.contains('/cache/image_picker') ||
        lower.contains('image_picker');
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();

    for (var entry in _mimeTypes.entries) {
      if (lower.endsWith(entry.key)) {
        return entry.value;
      }
    }

    return 'image/jpeg';
  }

  Future<Map<String, dynamic>> _convertImageToBase64(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return {'base64': null, 'tamano': null};
      }

      final bytes = await file.readAsBytes();
      return {
        'base64': base64Encode(bytes),
        'tamano': bytes.length,
      };
    } catch (e) {
      _logger.w('⚠️ Error convirtiendo imagen: $e');
      return {'base64': null, 'tamano': null};
    }
  }

  Map<String, dynamic> _getDefaultSyncMetadata() {
    return {
      'sync_status': 'pending',
      'intentos_sync': 0,
      'mensaje_error_sync': null,
      'fecha_sincronizado': null,
    };
  }
}
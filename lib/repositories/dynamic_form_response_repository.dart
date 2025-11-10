import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_response_detail.dart';
import '../models/dynamic_form/dynamic_form_response_image.dart';
import 'package:path_provider/path_provider.dart';
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
        where: 'estado = ?',
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

  // ==================== MÉTODO PARA GUARDAR IMAGEN INMEDIATAMENTE ====================

  /// Guarda una imagen inmediatamente cuando se selecciona (sin esperar a completar el form)
  Future<String?> saveImageImmediately({
    required String responseId,
    required String fieldId,
    required String imagePath,
  }) async {
    try {
      _logger.i('📸 Guardando imagen inmediatamente para campo: $fieldId');

      // 1. Crear o buscar el detailId para este campo
      String detailId = await _getOrCreateDetailId(responseId, fieldId);

      // 2. Eliminar imágenes previas de este detalle (si existen)
      await _deleteImagesForDetail(detailId);

      // 3. Convertir imagen a Base64
      final imageData = await _convertImageToBase64(imagePath);

      if (imageData['base64'] == null) {
        _logger.e('❌ No se pudo convertir la imagen a Base64');
        return null;
      }

      // 4. Guardar en la tabla de imágenes
      final imageId = _uuid.v4();
      await _dbHelper.insertar(_imageTable, {
        'id': imageId,
        'dynamic_form_response_detail_id': detailId,
        'imagen_path': imagePath,
        'imagen_base64': imageData['base64'],
        'imagen_tamano': imageData['tamano'],
        'mime_type': _getMimeType(imagePath),
        'orden': 1,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      });

      _logger.i('✅ Imagen guardada inmediatamente: $imageId (${imageData['tamano']} bytes)');
      return imageId;
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando imagen inmediatamente: $e\n$stackTrace');
      return null;
    }
  }

  /// Obtiene o crea un detail_id para un campo específico
  Future<String> _getOrCreateDetailId(String responseId, String fieldId) async {
    try {
      // Buscar si ya existe un detalle para este campo
      final existing = await _dbHelper.consultar(
        _detailTable,
        where: 'dynamic_form_response_id = ? AND dynamic_form_detail_id = ?',
        whereArgs: [responseId, fieldId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first['id'].toString();
      }

      // Si no existe, crear uno nuevo
      final detailId = _uuid.v4();
      await _dbHelper.insertar(_detailTable, {
        'id': detailId,
        'version': 1,
        'response': '[IMAGE]',
        'dynamic_form_response_id': responseId,
        'dynamic_form_detail_id': fieldId,
        'sync_status': 'pending',
      });

      _logger.d('➕ Detail creado para imagen: $detailId');
      return detailId;
    } catch (e) {
      _logger.e('❌ Error obteniendo/creando detailId: $e');
      rethrow;
    }
  }

  /// Elimina imágenes previas de un detalle específico
  Future<void> _deleteImagesForDetail(String detailId) async {
    try {
      // Obtener imágenes para eliminar archivos físicos
      final images = await getImagesForDetail(detailId);

      // Eliminar archivos físicos
      for (var image in images) {
        await deleteImageFile(image);
      }

      // Eliminar registros de la BD
      await _dbHelper.eliminar(
        _imageTable,
        where: 'dynamic_form_response_detail_id = ?',
        whereArgs: [detailId],
      );

      if (images.isNotEmpty) {
        _logger.d('🗑️ ${images.length} imagen(es) anterior(es) eliminada(s)');
      }
    } catch (e) {
      _logger.w('⚠️ Error eliminando imágenes previas: $e');
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

  Future<int> saveResponseImagesFromServer(List<Map<String, dynamic>> images) async {
    int count = 0;

    for (var imageData in images) {
      try {
        String? localPath;
        int? imageSize;

        // 👇 DECODIFICAR BASE64 Y GUARDAR LOCALMENTE
        if (imageData['imageBase64'] != null && imageData['imageBase64'].toString().isNotEmpty) {
          final base64String = imageData['imageBase64'].toString();
          final bytes = base64Decode(base64String);

          // Crear archivo local
          final directory = await getApplicationDocumentsDirectory();
          final fileName = '${_uuid.v4()}.jpg';
          final file = File('${directory.path}/$fileName');

          await file.writeAsBytes(bytes);
          localPath = file.path;
          imageSize = bytes.length;

          _logger.d('💾 Imagen reconstruida localmente: $localPath');
        }

        final imageForDB = {
          'id': imageData['id']?.toString() ?? _uuid.v4(),
          'dynamic_form_response_detail_id': imageData['dynamicFormResponseDetail']?['id']?.toString() ?? '',
          'imagen_path': localPath ?? imageData['imagePath']?.toString(), // 👈 USA PATH LOCAL
          'imagen_base64': imageData['imageBase64']?.toString(),
          'imagen_tamano': imageSize,
          'mime_type': imageData['mimeType']?.toString() ?? 'image/jpeg',
          'orden': imageData['orden'] != null ? int.tryParse(imageData['orden'].toString()) ?? 1 : 1,
          'created_at': imageData['creationDate']?.toString() ?? DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        };

        await _upsertImage(imageForDB['id']!.toString(), imageForDB);
        count++;

      } catch (e, stackTrace) {
        _logger.e('❌ Error guardando imagen desde servidor: $e\n$stackTrace');
      }
    }

    _logger.i('🖼️ Total de imágenes guardadas desde servidor: $count');
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

  Future<void> _upsertImage(String id, Map<String, dynamic> data) async {
    final existing = await _dbHelper.consultar(
      _imageTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await _dbHelper.actualizar(_imageTable, data, where: 'id = ?', whereArgs: [id]);
      _logger.d('🔄 Imagen actualizada: $id');
    } else {
      await _dbHelper.insertar(_imageTable, data);
      _logger.d('➕ Imagen insertada: $id');
    }
  }

  Future<void> _saveResponseDetails(DynamicFormResponse response) async {
    _logger.d('📝 Guardando ${response.answers.length} respuestas detalle');
    _logger.d('🔍 Respuestas: ${response.answers}');

    for (var entry in response.answers.entries) {
      if (entry.key.isEmpty) {
        _logger.w('⚠️ Campo con ID vacío, omitiendo');
        continue;
      }

      // 🎯 CAMBIO: Verificar si ya existe un detalle con imagen guardada
      final existingDetails = await _dbHelper.consultar(
        _detailTable,
        where: 'dynamic_form_response_id = ? AND dynamic_form_detail_id = ?',
        whereArgs: [response.id, entry.key],
        limit: 1,
      );

      if (existingDetails.isNotEmpty) {
        // Ya existe (probablemente con imagen), solo actualizar sync_status
        final detailId = existingDetails.first['id'].toString();
        await _dbHelper.actualizar(
          _detailTable,
          {'sync_status': 'pending'},
          where: 'id = ?',
          whereArgs: [detailId],
        );
        _logger.d('  ✓ Campo ${entry.key}: [YA EXISTÍA]');
        continue;
      }

      // Si no existe, crear nuevo detalle
      final detailId = _uuid.v4();

      if (_isImagePath(entry.value)) {
        // Para imágenes, verificar si ya está guardada
        final hasImage = await _hasImageForField(response.id, entry.key);

        if (!hasImage) {
          // Si no está guardada, guardarla ahora
          await _saveImageForDetail(
            detailId: detailId,
            responseId: response.id,
            fieldId: entry.key,
            imagePath: entry.value as String,
            isCompleted: response.status == 'completed',
          );
        }

        await _dbHelper.insertar(_detailTable, {
          'id': detailId,
          'version': 1,
          'response': '[IMAGE]',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
          'sync_status': 'pending',
        });

        _logger.d('  ✓ Campo ${entry.key}: [IMAGEN]');
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

  /// Verifica si ya existe una imagen guardada para un campo
  Future<bool> _hasImageForField(String responseId, String fieldId) async {
    try {
      final details = await _dbHelper.consultar(
        _detailTable,
        where: 'dynamic_form_response_id = ? AND dynamic_form_detail_id = ?',
        whereArgs: [responseId, fieldId],
        limit: 1,
      );

      if (details.isEmpty) return false;

      final images = await getImagesForDetail(details.first['id']);
      return images.isNotEmpty;
    } catch (e) {
      return false;
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
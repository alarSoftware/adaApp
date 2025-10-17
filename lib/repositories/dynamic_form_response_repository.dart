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

  String get _responseTableName => 'dynamic_form_response';
  String get _responseDetailTableName => 'dynamic_form_response_detail';
  String get _responseImageTableName => 'dynamic_form_response_image';

  // ==================== MÉTODOS PARA RESPUESTAS ====================

  /// Guardar respuesta completa (con sus detalles e imágenes)
  Future<bool> save(DynamicFormResponse response) async {
    try {
      _logger.i('💾 Guardando respuesta: ${response.id}');

      if (response.id.isEmpty || response.formTemplateId.isEmpty) {
        _logger.e('❌ Response con ID o formTemplateId vacío');
        return false;
      }

      // Guardar en tabla dynamic_form_response
      final responseData = {
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
        'last_update_date': response.completedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

      // Verificar si existe
      final existing = await _dbHelper.consultar(
        _responseTableName,
        where: 'id = ?',
        whereArgs: [response.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await _dbHelper.actualizar(
          _responseTableName,
          responseData,
          where: 'id = ?',
          whereArgs: [response.id],
        );
        _logger.d('🔄 Respuesta actualizada');
      } else {
        await _dbHelper.insertar(_responseTableName, responseData);
        _logger.d('➕ Respuesta insertada');
      }

      // Guardar detalles de respuestas (ahora sin imágenes)
      await _saveResponseDetails(response);

      _logger.i('✅ Respuesta guardada exitosamente: ${response.id}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando respuesta: $e');
      _logger.e('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Obtener todas las respuestas locales
  Future<List<DynamicFormResponse>> getAll() async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTableName,
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormResponse> responses = [];

      for (var map in maps) {
        final response = await _mapToResponseWithDetails(map);
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

  /// Obtener respuesta por ID
  Future<DynamicFormResponse?> getById(String id) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTableName,
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

  /// Obtener respuestas por estado
  Future<List<DynamicFormResponse>> getByStatus(String status) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTableName,
        where: 'estado = ?',
        whereArgs: [status],
        orderBy: 'creation_date DESC',
      );

      List<DynamicFormResponse> responses = [];

      for (var map in maps) {
        final response = await _mapToResponseWithDetails(map);
        if (response != null) {
          responses.add(response);
        }
      }

      return responses;
    } catch (e) {
      _logger.e('❌ Error obteniendo respuestas por estado: $e');
      return [];
    }
  }

  /// Obtener respuestas pendientes de sincronización
  Future<List<DynamicFormResponse>> getPendingSync() async {
    try {
      final maps = await _dbHelper.consultar(
        _responseTableName,
        where: 'estado = ? AND sync_status = ?',
        whereArgs: ['completed', 'pending'],
        orderBy: 'creation_date ASC',
      );

      List<DynamicFormResponse> responses = [];

      for (var map in maps) {
        final response = await _mapToResponseWithDetails(map);
        if (response != null) {
          responses.add(response);
        }
      }

      _logger.i('✅ Respuestas pendientes de sync: ${responses.length}');
      return responses;
    } catch (e) {
      _logger.e('❌ Error obteniendo pendientes de sync: $e');
      return [];
    }
  }

  /// Eliminar respuesta y sus detalles
  Future<bool> delete(String responseId) async {
    try {
      final images = await getImagesForResponse(responseId);

      _logger.i('🗑️ Eliminando respuesta $responseId con ${images.length} imágenes');

      for (var image in images) {
        if (image.imagenPath != null && image.imagenPath!.isNotEmpty) {
          try {
            final file = File(image.imagenPath!);
            if (await file.exists()) {
              await file.delete();
              _logger.d('  🗑️ Archivo eliminado: ${image.imagenPath}');
            }
          } catch (e) {
            _logger.w('⚠️ No se pudo eliminar archivo: ${image.imagenPath} - $e');
          }
        }
      }

      for (var image in images) {
        await _dbHelper.eliminar(
          _responseImageTableName,
          where: 'id = ?',
          whereArgs: [image.id],
        );
      }
      _logger.d('  🗑️ ${images.length} registros de imágenes eliminados de la BD');

      await _dbHelper.eliminar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      await _dbHelper.eliminar(
        _responseTableName,
        where: 'id = ?',
        whereArgs: [responseId],
      );

      _logger.i('✅ Respuesta eliminada completamente: $responseId');
      return true;
    } catch (e) {
      _logger.e('❌ Error eliminando respuesta: $e');
      return false;
    }
  }

  /// Contar respuestas pendientes de sincronización
  Future<int> countPendingSync() async {
    try {
      return await _dbHelper.contarRegistros(
        _responseTableName,
        where: 'estado = ? AND sync_status = ?',
        whereArgs: ['completed', 'pending'],
      );
    } catch (e) {
      _logger.e('❌ Error contando pendientes de sync: $e');
      return 0;
    }
  }

  /// Contar respuestas sincronizadas
  Future<int> countSynced() async {
    try {
      return await _dbHelper.contarRegistros(
        _responseTableName,
        where: 'sync_status = ?',
        whereArgs: ['synced'],
      );
    } catch (e) {
      _logger.e('❌ Error contando sincronizadas: $e');
      return 0;
    }
  }

  /// Obtener metadata de sincronización
  Future<Map<String, dynamic>> getSyncMetadata(String responseId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        _responseTableName,
        where: 'id = ?',
        whereArgs: [responseId],
      );

      if (result.isEmpty) {
        return {
          'sync_status': 'pending',
          'intentos_sync': 0,
          'mensaje_error_sync': null,
          'fecha_sincronizado': null,
        };
      }

      final map = result.first;
      return {
        'sync_status': map['sync_status'] ?? 'pending',
        'intentos_sync': map['intentos_sync'] ?? 0,
        'mensaje_error_sync': map['mensaje_error_sync'],
        'fecha_sincronizado': map['fecha_sincronizado'],
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo sync metadata: $e');
      return {
        'sync_status': 'pending',
        'intentos_sync': 0,
        'mensaje_error_sync': null,
        'fecha_sincronizado': null,
      };
    }
  }

  // ==================== MÉTODOS PARA DETALLES DE RESPUESTAS ====================

  /// Guardar detalles de una respuesta
  Future<void> _saveResponseDetails(DynamicFormResponse response) async {
    try {
      await _dbHelper.eliminar(
        _responseDetailTableName,
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

        if (entry.value is String && _isImagePath(entry.value as String)) {
          await _saveImageForDetail(
            detailId: detailId,
            responseId: response.id,
            fieldId: entry.key,
            imagePath: entry.value as String,
            isCompleted: response.status == 'completed',
          );

          final detailData = {
            'id': detailId,
            'version': 1,
            'response': '[IMAGE]',
            'dynamic_form_response_id': response.id,
            'dynamic_form_detail_id': entry.key,
            'sync_status': 'pending',
          };

          await _dbHelper.insertar(_responseDetailTableName, detailData);
          _logger.d('  ✓ Campo ${entry.key}: [IMAGEN en tabla separada]');
          continue;
        }

        final detailData = {
          'id': detailId,
          'version': 1,
          'response': entry.value?.toString() ?? '',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
          'sync_status': 'pending',
        };

        await _dbHelper.insertar(_responseDetailTableName, detailData);
        _logger.d('  ✓ Campo ${entry.key}: ${entry.value}');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando detalles de respuesta: $e');
      _logger.e('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Obtener detalles de una respuesta
  Future<List<DynamicFormResponseDetail>> getDetails(String responseId) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      return maps.map((map) => DynamicFormResponseDetail.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo detalles: $e');
      return [];
    }
  }

  // ==================== MÉTODOS PARA IMÁGENES ====================

  /// Guardar imagen en la tabla separada
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
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            imagenBase64 = base64Encode(bytes);
            imagenTamano = bytes.length;
            _logger.d('  📷 Imagen convertida a Base64: $fieldId (${imagenTamano} bytes)');
          }
        } catch (e) {
          _logger.w('⚠️ Error convirtiendo imagen: $e');
        }
      } else {
        _logger.d('  📷 Imagen guardada como ruta (borrador): $fieldId');
      }

      final imageData = {
        'id': imageId,
        'dynamic_form_response_detail_id': detailId,
        'imagen_path': imagePath,
        'imagen_base64': imagenBase64,
        'imagen_tamano': imagenTamano,
        'mime_type': _getMimeType(imagePath),
        'orden': orden,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      };

      await _dbHelper.insertar(_responseImageTableName, imageData);
      _logger.d('  ✅ Imagen guardada en tabla separada con UUID: $imageId');
    } catch (e) {
      _logger.e('❌ Error guardando imagen: $e');
      rethrow;
    }
  }

  /// Obtener imágenes de un detalle específico
  Future<List<DynamicFormResponseImage>> getImagesForDetail(String detailId) async {
    try {
      final maps = await _dbHelper.consultar(
        _responseImageTableName,
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

  /// Obtener todas las imágenes de una respuesta
  Future<List<DynamicFormResponseImage>> getImagesForResponse(String responseId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT i.* 
        FROM $_responseImageTableName i
        INNER JOIN $_responseDetailTableName d 
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

  // ==================== MÉTODOS PARA SINCRONIZACIÓN CON SERVIDOR ====================

  /// Guardar respuestas descargadas del servidor
  Future<int> saveResponsesFromServer(List<Map<String, dynamic>> responses) async {
    int count = 0;

    for (var responseData in responses) {
      try {
        _logger.d('📦 Procesando response del servidor: ${responseData['id']}');

        // 🎯 MAPEAR RESPUESTA PRINCIPAL
        final responseId = responseData['id'].toString(); // Convertir a string
        final formTemplateId = responseData['dynamicFormId'].toString();
        final contactoId = responseData['contactoId']?.toString();
        final edfVendedorId = responseData['edfVendedorId']?.toString();
        final usuarioId = responseData['usuarioId']?.toString();
        final estado = responseData['estado'] as String? ?? 'completed';
        final creationDate = responseData['creationDate'] as String;
        final completedDate = responseData['completedDate'] as String?;

        // Guardar en tabla dynamic_form_response
        final responseMap = {
          'id': responseId,
          'version': 1,
          'contacto_id': contactoId ?? '',
          'edf_vendedor_id': edfVendedorId, // No viene del servidor
          'last_update_user_id': null,
          'dynamic_form_id': formTemplateId,
          'usuario_id': usuarioId != null ? int.tryParse(usuarioId) : null,
          'estado': estado,
          'sync_status': 'synced', // ✅ Ya está sincronizado desde el servidor
          'intentos_sync': 0,
          'creation_date': creationDate,
          'last_update_date': completedDate ?? creationDate,
          'fecha_sincronizado': DateTime.now().toIso8601String(),
        };

        // Verificar si existe
        final existing = await _dbHelper.consultar(
          _responseTableName,
          where: 'id = ?',
          whereArgs: [responseId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          await _dbHelper.actualizar(
            _responseTableName,
            responseMap,
            where: 'id = ?',
            whereArgs: [responseId],
          );
          _logger.d('  🔄 Response actualizado');
        } else {
          await _dbHelper.insertar(_responseTableName, responseMap);
          _logger.d('  ➕ Response insertado');
        }

        // 🎯 GUARDAR DETALLES
        final details = responseData['details'] as List<dynamic>? ?? [];

        if (details.isNotEmpty) {
          _logger.d('  📝 Guardando ${details.length} detalles');

          // Eliminar detalles existentes para este response
          await _dbHelper.eliminar(
            _responseDetailTableName,
            where: 'dynamic_form_response_id = ?',
            whereArgs: [responseId],
          );

          // Insertar nuevos detalles
          for (var detail in details) {
            final detailId = detail['id'].toString(); // Convertir a string
            final dynamicFormDetailId = detail['dynamicFormDetailId'].toString();
            final response = detail['response']?.toString() ?? '';

            final detailMap = {
              'id': detailId,
              'version': 1,
              'response': response,
              'dynamic_form_response_id': responseId,
              'dynamic_form_detail_id': dynamicFormDetailId,
              'sync_status': 'synced',
            };

            await _dbHelper.insertar(_responseDetailTableName, detailMap);
            _logger.d('    ✓ Detalle guardado: $dynamicFormDetailId = $response');
          }
        }

        count++;
        _logger.i('✅ Response guardado: $responseId con ${details.length} detalles');

      } catch (e, stackTrace) {
        _logger.e('❌ Error guardando response desde servidor: $e');
        _logger.e('Stack trace: $stackTrace');
      }
    }

    _logger.i('💾 Total de responses guardados desde servidor: $count');
    return count;
  }

  /// Guardar detalles de respuestas descargados del servidor
  Future<int> saveResponseDetailsFromServer(List<Map<String, dynamic>> details) async {
    int count = 0;

    for (var detailData in details) {
      try {
        // Construir datos para insertar en la tabla local
        final detailForDB = {
          'id': detailData['id']?.toString() ?? _uuid.v4(),
          'version': 1,
          'response': detailData['response']?.toString() ?? '',
          'dynamic_form_response_id': detailData['dynamicFormResponseId']?.toString() ?? '',
          'dynamic_form_detail_id': detailData['dynamicFormDetailId']?.toString() ?? '',
          'sync_status': 'synced', // Viene del servidor, ya está sincronizado
        };

        await _dbHelper.insertar(_responseDetailTableName, detailForDB);
        count++;

      } catch (e) {
        _logger.e('❌ Error guardando detalle desde servidor: $e');
      }
    }

    _logger.i('✅ Total detalles guardados: $count');
    return count;
  }

  // ==================== MÉTODOS PRIVADOS ====================

  /// Mapear datos de BD a DynamicFormResponse con sus detalles
  Future<DynamicFormResponse?> _mapToResponseWithDetails(Map<String, dynamic> map) async {
    try {
      if (map['id'] == null) {
        _logger.e('❌ Response sin ID');
        return null;
      }

      final detalles = await _dbHelper.consultar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [map['id']],
      );

      Map<String, dynamic> answers = {};
      for (var detalle in detalles) {
        final fieldId = detalle['dynamic_form_detail_id']?.toString();
        if (fieldId != null && fieldId.isNotEmpty) {
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
      }

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
        completedAt: estado == 'completed' ? parseDateTime(map['last_update_date']) : null,
        syncedAt: estado == 'synced' ? DateTime.now() : null,
        status: estado,
        userId: map['usuario_id']?.toString(),
        contactoId: map['contacto_id']?.toString(),
        edfVendedorId: map['edf_vendedor_id']?.toString(),
        errorMessage: map['mensaje_error_sync']?.toString(),
      );
    } catch (e, stackTrace) {
      _logger.e('❌ Error mapeando response: $e');
      _logger.e('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Verificar si un string es una ruta de imagen
  bool _isImagePath(String value) {
    if (value.isEmpty) return false;

    final lowerValue = value.toLowerCase();
    return lowerValue.endsWith('.jpg') ||
        lowerValue.endsWith('.jpeg') ||
        lowerValue.endsWith('.png') ||
        lowerValue.endsWith('.gif') ||
        lowerValue.endsWith('.webp') ||
        lowerValue.contains('/cache/image_picker') ||
        lowerValue.contains('image_picker');
  }

  /// Obtener mime type de una ruta de imagen
  String _getMimeType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.gif')) return 'image/gif';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
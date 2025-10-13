import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import '../models/dynamic_form/dynamic_form_response.dart';
import '../models/dynamic_form/dynamic_form_response_detail.dart';
import '../services/database_helper.dart';

class DynamicFormResponseRepository {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String get _responseTableName => 'dynamic_form_response';
  String get _responseDetailTableName => 'dynamic_form_response_detail';

  // ==================== MÉTODOS PARA RESPUESTAS ====================

  /// Guardar respuesta completa (con sus detalles)
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
        'cliente_id': response.clienteId ?? '',
        'contacto_id': response.metadata?['contactoId']?.toString(),
        'edf_vendedor_id': response.metadata?['edfVendedorId']?.toString(),
        'last_update_user_id': null,
        'dynamic_form_id': response.formTemplateId,
        'usuario_id': response.userId != null ? int.tryParse(response.userId!) : null,
        'estado': response.status,
        'sync_status': 'pending',
        'intentos_sync': 0,
        'creation_date': response.createdAt.toIso8601String(),
        'creation_user_id': response.userId != null ? int.tryParse(response.userId!) : null,
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

      // Guardar detalles de respuestas
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
      // Primero eliminar los detalles
      await _dbHelper.eliminar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [responseId],
      );

      // Luego eliminar la respuesta
      await _dbHelper.eliminar(
        _responseTableName,
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

  /// Guardar detalles de una respuesta (con soporte condicional para imágenes)
  Future<void> _saveResponseDetails(DynamicFormResponse response) async {
    try {
      // Primero eliminar detalles existentes
      await _dbHelper.eliminar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [response.id],
      );

      _logger.d('📝 Guardando ${response.answers.length} respuestas detalle');

      // Insertar nuevos detalles
      for (var entry in response.answers.entries) {
        if (entry.key.isEmpty) {
          _logger.w('⚠️ Campo con ID vacío, omitiendo');
          continue;
        }

        // ⚠️ CAMBIO: Solo convertir imágenes si el estado es 'completed'
        String? imagenPath;
        String? imagenBase64;
        bool tieneImagen = false;
        int? imagenTamano;

        final isCompleted = response.status == 'completed';

        if (entry.value is String && _isImagePath(entry.value as String)) {
          imagenPath = entry.value as String;

          // Solo convertir a Base64 si está completado
          if (isCompleted) {
            try {
              final file = File(imagenPath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                imagenBase64 = base64Encode(bytes);
                tieneImagen = true;
                imagenTamano = bytes.length;
                _logger.d('  📷 Imagen convertida a Base64: ${entry.key} (${imagenTamano} bytes)');
              }
            } catch (e) {
              _logger.w('⚠️ Error convirtiendo imagen: $e');
            }
          } else {
            // Si es borrador, solo guardar la ruta (sin Base64)
            _logger.d('  📷 Imagen guardada como ruta (borrador): ${entry.key}');
          }
        }

        final detailData = {
          'id': '${response.id}_${entry.key}',
          'version': 1,
          'response': entry.value?.toString() ?? '',
          'dynamic_form_response_id': response.id,
          'dynamic_form_detail_id': entry.key,
          'sync_status': 'pending',
          'imagen_path': imagenPath,
          'imagen_base64': imagenBase64, // null si es borrador
          'tiene_imagen': tieneImagen ? 1 : 0,
          'imagen_tamano': imagenTamano,
        };

        await _dbHelper.insertar(_responseDetailTableName, detailData);

        if (isCompleted && tieneImagen) {
          _logger.d('  ✓ Campo ${entry.key}: imagen con Base64');
        } else if (imagenPath != null) {
          _logger.d('  ✓ Campo ${entry.key}: ruta de imagen (borrador)');
        } else {
          _logger.d('  ✓ Campo ${entry.key}: ${entry.value}');
        }
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Error guardando detalles de respuesta: $e');
      _logger.e('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Obtener detalles de una respuesta (incluyendo imágenes)
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

  // ==================== MÉTODOS PRIVADOS ====================

  /// Mapear datos de BD a DynamicFormResponse con sus detalles
  Future<DynamicFormResponse?> _mapToResponseWithDetails(Map<String, dynamic> map) async {
    try {
      if (map['id'] == null) {
        _logger.e('❌ Response sin ID');
        return null;
      }

      // Obtener los detalles de respuestas
      final detalles = await _dbHelper.consultar(
        _responseDetailTableName,
        where: 'dynamic_form_response_id = ?',
        whereArgs: [map['id']],
      );

      // Construir el Map de answers
      Map<String, dynamic> answers = {};
      for (var detalle in detalles) {
        final fieldId = detalle['dynamic_form_detail_id']?.toString();
        if (fieldId != null && fieldId.isNotEmpty) {
          // Si tiene imagen, usar la ruta de la imagen
          if (detalle['tiene_imagen'] == 1 && detalle['imagen_path'] != null) {
            answers[fieldId] = detalle['imagen_path'];
          } else {
            answers[fieldId] = detalle['response'];
          }
        }
      }

      // Parsear fechas
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
        clienteId: map['cliente_id']?.toString(),
        equipoId: null,
        metadata: {
          'contactoId': map['contacto_id'],
          'edfVendedorId': map['edf_vendedor_id'],
        },
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
}
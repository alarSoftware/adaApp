// lib/services/sync/sync_tables_config.dart
import 'package:flutter/foundation.dart';

import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/post/dynamic_form_post_service.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/models/device_log.dart';

/// Resultado del envío de una tabla
class TableSyncResult {
  final bool success;
  final int itemsSent;
  final String message;
  final String? error;

  TableSyncResult({
    required this.success,
    required this.itemsSent,
    required this.message,
    this.error,
  });
}

/// Configuración de una tabla para sincronización
class SyncTableConfig {
  final String tableName;
  final String displayName;
  final String description;
  final String whereClause;
  final List<dynamic> whereArgs;
  final Future<TableSyncResult> Function(List<Map<String, dynamic>> items)
  syncFunction;

  SyncTableConfig({
    required this.tableName,
    required this.displayName,
    required this.description,
    required this.whereClause,
    required this.whereArgs,
    required this.syncFunction,
  });
}

/// Gestor centralizado de configuración de tablas de sincronización
class SyncTablesConfig {
  static final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtiene todas las configuraciones de tablas para sincronización
  static List<SyncTableConfig> getAllTableConfigs() {
    return [
      // 1. CENSOS ACTIVOS
      SyncTableConfig(
        tableName: 'censo_activo',
        displayName: 'Censos Activos',
        description: 'Censos pendientes de sincronización',
        whereClause: 'estado_censo = ?',
        whereArgs: ['error'],
        syncFunction: _syncCensos,
      ),

      // 2. OPERACIONES COMERCIALES
      SyncTableConfig(
        tableName: 'operacion_comercial',
        displayName: 'Operaciones Comerciales',
        description: 'Operaciones comerciales con error de sincronización',
        whereClause: 'sync_status = ?',
        whereArgs: ['error'],
        syncFunction: _syncOperacionesComerciales,
      ),

      // 3. FORMULARIOS DINÁMICOS
      SyncTableConfig(
        tableName: 'dynamic_form_response',
        displayName: 'Formularios',
        description: 'Respuestas de formularios completados',
        whereClause: 'sync_status IN (?, ?)',
        whereArgs: ['pending', 'error'],
        syncFunction: _syncFormularios,
      ),

      // 4. IMÁGENES DE FORMULARIOS
      SyncTableConfig(
        tableName: 'dynamic_form_response_image',
        displayName: 'Imágenes',
        description: 'Imágenes adjuntas a formularios',
        whereClause: 'sync_status = ? AND imagen_base64 IS NOT NULL',
        whereArgs: ['pending'],
        syncFunction: _syncImagenes,
      ),

      // 5. LOGS DE DISPOSITIVO
      SyncTableConfig(
        tableName: 'device_log',
        displayName: 'Logs',
        description: 'Registros de actividad del dispositivo',
        whereClause: 'sincronizado = ?',
        whereArgs: [0],
        syncFunction: _syncLogs,
      ),

      // 🆕 6. AGREGAR MÁS TABLAS AQUÍ EN EL FUTURO...
      // SyncTableConfig(
      //   tableName: 'otra_tabla',
      //   displayName: 'Otra Tabla',
      //   description: 'Descripción',
      //   whereClause: 'estado = ?',
      //   whereArgs: ['pendiente'],
      //   syncFunction: _syncOtraTabla,
      // ),
    ];
  }

  /// Obtiene el conteo de registros pendientes por tabla
  static Future<Map<String, int>> getPendingCounts() async {
    final db = await _dbHelper.database;
    final counts = <String, int>{};

    for (final config in getAllTableConfigs()) {
      try {
        final result = await db.query(
          config.tableName,
          where: config.whereClause,
          whereArgs: config.whereArgs,
        );
        counts[config.tableName] = result.length;
      } catch (e) {
        debugPrint('Error obteniendo conteo de ${config.tableName}: $e');
        counts[config.tableName] = 0;
      }
    }

    return counts;
  }

  // ═══════════════════════════════════════════════════════════════════
  // FUNCIONES DE SINCRONIZACIÓN POR TABLA
  // ═══════════════════════════════════════════════════════════════════

  /// Sincroniza censos activos
  static Future<TableSyncResult> _syncCensos(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final db = await _dbHelper.database;

      // Obtener usuario actual
      final usuarios = await db.query('Users', limit: 1);
      if (usuarios.isEmpty) {
        return TableSyncResult(
          success: false,
          itemsSent: 0,
          message: 'Usuario no encontrado',
        );
      }

      final usuarioId = usuarios.first['id'] as int;

      // Usar el servicio unificado
      final censoService = CensoUploadService();
      final resultado = await censoService.sincronizarCensosNoMigrados(
        usuarioId,
      );

      final censosExitosos = resultado['censos_exitosos'] ?? 0;
      final censosFallidos = resultado['fallidos'] ?? 0;

      return TableSyncResult(
        success: censosExitosos > 0 || censosFallidos == 0,
        itemsSent: censosExitosos,
        message: censosExitosos > 0
            ? '$censosExitosos censos sincronizados'
            : 'No hay censos pendientes',
        error: censosFallidos > 0 ? '$censosFallidos censos fallaron' : null,
      );
    } catch (e) {
      debugPrint('Error sincronizando censos: $e');
      return TableSyncResult(
        success: false,
        itemsSent: 0,
        message: 'Error en sincronización de censos',
        error: e.toString(),
      );
    }
  }

  /// Sincroniza operaciones comerciales
  static Future<TableSyncResult> _syncOperacionesComerciales(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      if (items.isEmpty) {
        return TableSyncResult(
          success: true,
          itemsSent: 0,
          message: 'No hay operaciones pendientes',
        );
      }

      debugPrint('📤 Reintentando ${items.length} operaciones comerciales...');

      int sentCount = 0;
      final errors = <String>[];

      final repository = OperacionComercialRepositoryImpl();

      for (final operacionMap in items) {
        final operacionId = operacionMap['id'] as String;

        try {
          await repository.marcarPendienteSincronizacion(operacionId);
          final operacionCompleta = await repository.obtenerOperacionPorId(
            operacionId,
          );

          if (operacionCompleta != null) {
            // await repository.sincronizarOperacionesPendientes();
            final operacionActualizada = await repository.obtenerOperacionPorId(
              operacionId,
            );

            if (operacionActualizada?.syncStatus == 'migrado') {
              sentCount++;
              debugPrint('✅ Operación $operacionId sincronizada');
            } else {
              errors.add(
                'Operación $operacionId: ${operacionActualizada?.syncError ?? "Error desconocido"}',
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Error sincronizando operación $operacionId: $e');
          errors.add('Operación $operacionId: $e');
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }

      return TableSyncResult(
        success: sentCount > 0,
        itemsSent: sentCount,
        message: '$sentCount de ${items.length} operaciones sincronizadas',
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );
    } catch (e) {
      debugPrint('Error sincronizando operaciones comerciales: $e');
      return TableSyncResult(
        success: false,
        itemsSent: 0,
        message: 'Error en sincronización de operaciones',
        error: e.toString(),
      );
    }
  }

  /// Sincroniza formularios dinámicos
  static Future<TableSyncResult> _syncFormularios(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      if (items.isEmpty) {
        return TableSyncResult(
          success: true,
          itemsSent: 0,
          message: 'No hay formularios pendientes',
        );
      }

      final db = await _dbHelper.database;
      int sentCount = 0;
      final errors = <String>[];

      for (final form in items) {
        try {
          final respuesta = await _prepareFormResponse(form);
          final response =
              await DynamicFormPostService.enviarRespuestaFormulario(
                respuesta: respuesta,
                incluirLog: true,
              );

          if (response['exito'] == true) {
            await db.update(
              'dynamic_form_response',
              {
                'sync_status': 'sent',
                'fecha_sincronizado': DateTime.now().toIso8601String(),
                'last_update_date': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [form['id']],
            );

            await db.update(
              'dynamic_form_response_detail',
              {'sync_status': 'sent'},
              where: 'dynamic_form_response_id = ?',
              whereArgs: [form['id']],
            );

            sentCount++;
          } else {
            errors.add(
              'Formulario ${form['id']}: ${response['mensaje'] ?? "Error desconocido"}',
            );
          }
        } catch (e) {
          errors.add('Formulario ${form['id']}: $e');
        }
      }

      return TableSyncResult(
        success: sentCount > 0,
        itemsSent: sentCount,
        message: '$sentCount de ${items.length} formularios enviados',
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );
    } catch (e) {
      return TableSyncResult(
        success: false,
        itemsSent: 0,
        message: 'Error en sincronización de formularios',
        error: e.toString(),
      );
    }
  }

  /// Sincroniza imágenes
  static Future<TableSyncResult> _syncImagenes(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      if (items.isEmpty) {
        return TableSyncResult(
          success: true,
          itemsSent: 0,
          message: 'No hay imágenes pendientes',
        );
      }

      final db = await _dbHelper.database;
      int sentCount = 0;
      final errors = <String>[];

      for (final image in items) {
        try {
          final response = await BasePostService.post(
            endpoint: '/api/upload-image',
            body: {
              'image_id': image['id'],
              'dynamic_form_response_detail_id':
                  image['dynamic_form_response_detail_id'],
              'imagen_base64': image['imagen_base64'],
              'mime_type': image['mime_type'],
              'orden': image['orden'],
            },
            timeout: const Duration(seconds: 60),
          );

          if (response['exito'] == true) {
            await db.update(
              'dynamic_form_response_image',
              {'sync_status': 'sent'},
              where: 'id = ?',
              whereArgs: [image['id']],
            );
            sentCount++;
          } else {
            errors.add(
              'Imagen ${image['id']}: ${response['mensaje'] ?? "Error desconocido"}',
            );
          }
        } catch (e) {
          errors.add('Imagen ${image['id']}: $e');
        }
      }

      return TableSyncResult(
        success: sentCount > 0,
        itemsSent: sentCount,
        message: '$sentCount de ${items.length} imágenes enviadas',
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );
    } catch (e) {
      return TableSyncResult(
        success: false,
        itemsSent: 0,
        message: 'Error en sincronización de imágenes',
        error: e.toString(),
      );
    }
  }

  /// Sincroniza logs de dispositivo
  static Future<TableSyncResult> _syncLogs(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      if (items.isEmpty) {
        return TableSyncResult(
          success: true,
          itemsSent: 0,
          message: 'No hay logs pendientes',
        );
      }

      final db = await _dbHelper.database;
      final pendingLogs = items
          .map((logData) => DeviceLog.fromMap(logData))
          .toList();

      final resultado = await DeviceLogPostService.enviarDeviceLogsBatch(
        pendingLogs,
      );

      final sentCount = resultado['exitosos'] ?? 0;
      final failedCount = resultado['fallidos'] ?? 0;

      if (sentCount > 0 && sentCount > failedCount) {
        await db.update(
          'device_log',
          {'sincronizado': 1},
          where: 'sincronizado = ?',
          whereArgs: [0],
        );
      }

      return TableSyncResult(
        success: sentCount > 0,
        itemsSent: sentCount,
        message:
            '$sentCount de ${items.length} logs enviados${failedCount > 0 ? ' ($failedCount fallaron)' : ''}',
        error: failedCount > 0 ? '$failedCount logs fallaron' : null,
      );
    } catch (e) {
      return TableSyncResult(
        success: false,
        itemsSent: 0,
        message: 'Error en sincronización de logs',
        error: e.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> _prepareFormResponse(
    Map<String, Object?> form,
  ) async {
    final db = await _dbHelper.database;

    final details = await db.query(
      'dynamic_form_response_detail',
      where: 'dynamic_form_response_id = ?',
      whereArgs: [form['id']],
    );

    final images = await db.rawQuery(
      '''
      SELECT dri.* FROM dynamic_form_response_image dri
      INNER JOIN dynamic_form_response_detail drd ON dri.dynamic_form_response_detail_id = drd.id
      WHERE drd.dynamic_form_response_id = ?
    ''',
      [form['id']],
    );

    return {
      'id': form['id'],
      'dynamic_form_id': form['dynamic_form_id'],
      'usuario_id': form['usuario_id'],
      'contacto_id': form['contacto_id'],
      'employee_id': form['employee_id'],
      'creation_date': form['creation_date'],
      'last_update_date': form['last_update_date'],
      'estado': form['estado'],
      'details': details,
      'images': images,
    };
  }
}

import 'dart:convert';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class ErrorLogService {
  static final Logger _logger = Logger();
  static const _uuid = Uuid();

  // ==================== REGISTRO DE ERRORES LOCAL ====================

  /// Registra un error en la tabla error_log LOCAL
  static Future<void> logError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
    String? errorCode,
    String? errorType,
    int syncAttempt = 1,
    String? userId,
    String? endpoint,
  }) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final errorLog = {
        'id': _uuid.v4(),
        'timestamp': DateTime.now().toIso8601String(),
        'table_name': tableName,
        'operation': operation,
        'registro_fail_id': registroFailId,
        'error_code': errorCode,
        'error_message': errorMessage,
        'error_type': errorType ?? 'unknown',
        'sync_attempt': syncAttempt,
        'user_id': userId,
        'endpoint': endpoint,
      };

      await db.insert('error_log', errorLog);

      _logger.w('🚨 Error logged: $tableName - $errorMessage');

    } catch (e) {
      _logger.e('❌ Error guardando en error_log: $e');
      // No re-throw para evitar loops infinitos de errores
    }
  }

  // ==================== ENVÍO AL SERVIDOR ====================

  /// Envía todos los error logs pendientes al servidor
  static Future<SyncErrorLogsResult> enviarErrorLogsAlServidor({
    int limit = 50,
  }) async {
    try {
      _logger.i('📤 Iniciando envío de error logs al servidor...');

      // 1. Obtener errores de la BD local
      final errores = await getAllErrors(limit: limit);

      if (errores.isEmpty) {
        _logger.i('✅ No hay error logs para enviar');
        return SyncErrorLogsResult(
          exito: true,
          mensaje: 'No hay error logs para enviar',
          logsEnviados: 0,
        );
      }

      _logger.i('📊 Encontrados ${errores.length} error logs para enviar');

      // 2. Enviar cada error al servidor
      int enviados = 0;
      int fallidos = 0;
      final erroresEnviados = <String>[];

      for (final error in errores) {
        try {
          final enviado = await _enviarErrorLogIndividual(error);

          if (enviado) {
            enviados++;
            erroresEnviados.add(error['id'] as String);
          } else {
            fallidos++;
          }
        } catch (e) {
          fallidos++;
          _logger.e('Error enviando log ${error['id']}: $e');
        }
      }

      // 3. Eliminar errores enviados exitosamente de la BD local
      if (erroresEnviados.isNotEmpty) {
        await _eliminarErrorsEnviados(erroresEnviados);
        _logger.i('🗑️ Eliminados $enviados error logs de la BD local');
      }

      _logger.i('✅ Envío completado: $enviados enviados, $fallidos fallidos');

      return SyncErrorLogsResult(
        exito: true,
        mensaje: 'Error logs enviados: $enviados exitosos, $fallidos fallidos',
        logsEnviados: enviados,
        logsFallidos: fallidos,
      );

    } catch (e) {
      _logger.e('💥 Error general enviando error logs: $e');
      return SyncErrorLogsResult(
        exito: false,
        mensaje: 'Error enviando logs: $e',
        logsEnviados: 0,
      );
    }
  }

  /// Envía un error log individual al servidor
  static Future<bool> _enviarErrorLogIndividual(Map<String, dynamic> errorLog) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final endpoint = '$baseUrl/appErrorLog/insertAppErrorLog';

      // Preparar payload según el formato del servidor
      final payload = {
        'id': errorLog['id'],
        'timestamp': errorLog['timestamp'],
        'tableName': errorLog['table_name'],
        'operation': errorLog['operation'],
        'registroFailId': errorLog['registro_fail_id'],
        'errorCode': errorLog['error_code'],
        'errorMessage': errorLog['error_message'],
        'errorType': errorLog['error_type'],
        'syncAttempt': errorLog['sync_attempt'],
        'userId': errorLog['user_id'],
        'endpoint': errorLog['endpoint'],
      };

      _logger.d('📤 Enviando error log: ${errorLog['id']}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.d('✅ Error log enviado: ${errorLog['id']}');
        return true;
      } else {
        _logger.w('⚠️ Error del servidor al enviar log: ${response.statusCode}');
        return false;
      }

    } catch (e) {
      _logger.e('❌ Error enviando log individual: $e');
      return false;
    }
  }

  /// Elimina error logs que fueron enviados exitosamente
  static Future<void> _eliminarErrorsEnviados(List<String> ids) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        'error_log',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );

      _logger.i('🗑️ ${ids.length} error logs eliminados de BD local');
    } catch (e) {
      _logger.e('❌ Error eliminando logs enviados: $e');
    }
  }

  // ==================== CONSULTAS LOCALES ====================

  /// Obtiene todos los errores
  static Future<List<Map<String, dynamic>>> getAllErrors({int? limit}) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'error_log',
        orderBy: 'timestamp DESC',
        limit: limit ?? 100,
      );

      return result;

    } catch (e) {
      _logger.e('❌ Error obteniendo errores: $e');
      return [];
    }
  }

  /// Obtiene errores por tabla
  static Future<List<Map<String, dynamic>>> getErrorsByTable(String tableName) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'error_log',
        where: 'table_name = ?',
        whereArgs: [tableName],
        orderBy: 'timestamp DESC',
        limit: 50,
      );

      return result;

    } catch (e) {
      _logger.e('❌ Error obteniendo errores de tabla $tableName: $e');
      return [];
    }
  }

  /// Obtiene errores por tipo
  static Future<List<Map<String, dynamic>>> getErrorsByType(String errorType) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'error_log',
        where: 'error_type = ?',
        whereArgs: [errorType],
        orderBy: 'timestamp DESC',
        limit: 50,
      );

      return result;

    } catch (e) {
      _logger.e('❌ Error obteniendo errores por tipo $errorType: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de errores
  static Future<Map<String, dynamic>> getErrorStats() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Total de errores
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM error_log');
      final total = (totalResult.first['total'] as int?) ?? 0;

      // Errores por tipo
      final typeResult = await db.rawQuery('''
        SELECT error_type, COUNT(*) as count 
        FROM error_log 
        GROUP BY error_type
        ORDER BY count DESC
      ''');

      // Errores por tabla
      final tableResult = await db.rawQuery('''
        SELECT table_name, COUNT(*) as count 
        FROM error_log 
        GROUP BY table_name
        ORDER BY count DESC
      ''');

      // Errores recientes (últimas 24 horas)
      final yesterday = DateTime.now().subtract(Duration(days: 1)).toIso8601String();
      final recentResult = await db.rawQuery('''
        SELECT COUNT(*) as recent_count 
        FROM error_log 
        WHERE timestamp > ?
      ''', [yesterday]);
      final recentCount = (recentResult.first['recent_count'] as int?) ?? 0;

      return {
        'total_errors': total,
        'recent_errors_24h': recentCount,
        'errors_by_type': typeResult,
        'errors_by_table': tableResult,
      };

    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'total_errors': 0,
        'recent_errors_24h': 0,
        'errors_by_type': [],
        'errors_by_table': [],
      };
    }
  }

  // ==================== LIMPIEZA ====================

  /// Limpia errores antiguos (más de 30 días)
  static Future<int> cleanOldErrors({int days = 30}) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final deletedCount = await db.delete(
        'error_log',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate],
      );

      _logger.i('🧹 Limpiados $deletedCount errores antiguos (> $days días)');
      return deletedCount;

    } catch (e) {
      _logger.e('❌ Error limpiando errores antiguos: $e');
      return 0;
    }
  }

  /// Limpia TODOS los errores (usar con precaución)
  static Future<void> clearAllErrors() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      await db.delete('error_log');
      _logger.i('🗑️ Todos los error logs eliminados');

    } catch (e) {
      _logger.e('❌ Error limpiando todos los errores: $e');
    }
  }

  // ==================== MÉTODOS DE CONVENIENCIA ====================

  static Future<void> logNetworkError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
    String? endpoint,
    String? userId,
  }) async {
    await logError(
      tableName: tableName,
      operation: operation,
      errorMessage: errorMessage,
      registroFailId: registroFailId,
      errorType: 'network',
      errorCode: 'NETWORK_ERROR',
      endpoint: endpoint,
      userId: userId,
    );
  }

  static Future<void> logServerError({
    required String tableName,
    required String operation,
    required String errorMessage,
    required String errorCode,
    String? registroFailId,
    String? endpoint,
    String? userId,
  }) async {
    await logError(
      tableName: tableName,
      operation: operation,
      errorMessage: errorMessage,
      registroFailId: registroFailId,
      errorType: 'server',
      errorCode: errorCode,
      endpoint: endpoint,
      userId: userId,
    );
  }

  static Future<void> logValidationError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
    String? userId,
  }) async {
    await logError(
      tableName: tableName,
      operation: operation,
      errorMessage: errorMessage,
      registroFailId: registroFailId,
      errorType: 'validation',
      errorCode: 'VALIDATION_ERROR',
      userId: userId,
    );
  }

  static Future<void> logDatabaseError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
  }) async {
    await logError(
      tableName: tableName,
      operation: operation,
      errorMessage: errorMessage,
      registroFailId: registroFailId,
      errorType: 'database',
      errorCode: 'DATABASE_ERROR',
    );
  }
}

// ==================== CLASE DE RESULTADO ====================

class SyncErrorLogsResult {
  final bool exito;
  final String mensaje;
  final int logsEnviados;
  final int logsFallidos;

  SyncErrorLogsResult({
    required this.exito,
    required this.mensaje,
    required this.logsEnviados,
    this.logsFallidos = 0,
  });

  @override
  String toString() {
    return 'SyncErrorLogsResult(exito: $exito, mensaje: $mensaje, enviados: $logsEnviados, fallidos: $logsFallidos)';
  }
}
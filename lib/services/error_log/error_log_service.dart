import 'package:ada_app/services/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class ErrorLogService {
  static final Logger _logger = Logger();
  static const _uuid = Uuid();

  /// Registra un error en la tabla error_log
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

  /// Limpia errores antiguos (más de 30 días)
  static Future<void> cleanOldErrors() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).toIso8601String();

      final deletedCount = await db.delete(
        'error_log',
        where: 'timestamp < ?',
        whereArgs: [thirtyDaysAgo],
      );

      _logger.i('🧹 Limpiados $deletedCount errores antiguos');

    } catch (e) {
      _logger.e('❌ Error limpiando errores antiguos: $e');
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

  /// Métodos de conveniencia para tipos específicos de errores

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
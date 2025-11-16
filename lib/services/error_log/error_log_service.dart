import 'dart:convert';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class ErrorLogService {
  static final Logger _logger = Logger();
  static const _uuid = Uuid();

  // Configuración de reintentos
  static const int _maxRetriesBeforeBackoff = 5; // Después de 5 intentos, aumenta el delay
  static const Duration _baseRetryDelay = Duration(minutes: 5);
  static const Duration _maxRetryDelay = Duration(hours: 24);

  // ==================== REGISTRO DE ERRORES LOCAL ====================

  /// Registra un error y LO ENVÍA INMEDIATAMENTE AL SERVIDOR
  /// ✅ INTENTA ENVIAR AL SERVIDOR INMEDIATAMENTE
  /// ✅ Si falla, guarda en BD local para reintentos automáticos infinitos
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
      final errorId = _uuid.v4();
      final now = DateTime.now();

      final errorLog = {
        'id': errorId,
        'timestamp': now.toIso8601String(),
        'table_name': tableName,
        'operation': operation,
        'registro_fail_id': registroFailId,
        'error_code': errorCode,
        'error_message': errorMessage,
        'error_type': errorType ?? 'unknown',
        'sync_attempt': syncAttempt,
        'user_id': userId,
        'endpoint': endpoint,
        'retry_count': 0,
        'last_retry_at': null,
        'next_retry_at': now.toIso8601String(),
      };

      _logger.w('🚨 Error detectado: $tableName - $errorMessage');

      // 🎯 INTENTO INMEDIATO DE ENVÍO AL SERVIDOR
      final enviadoExitosamente = await _enviarErrorLogIndividual(errorLog);

      if (enviadoExitosamente) {
        _logger.i('✅ Error log enviado inmediatamente al servidor');
        // NO guardar en BD local si se envió exitosamente
        return;
      }

      // ❌ Si falló el envío, GUARDAR EN BD LOCAL para reintentos
      _logger.w('⚠️ Error log NO enviado, guardando para reintentos...');
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.insert('error_log', errorLog);
      _logger.i('💾 Error log guardado localmente para reintento');

    } catch (e) {
      _logger.e('❌ Error en logError: $e');
      // No re-throw para evitar loops infinitos de errores
    }
  }

  // ==================== ENVÍO AL SERVIDOR CON REINTENTOS ====================

  /// Envía todos los error logs pendientes al servidor
  /// Incluye lógica de reintentos INFINITOS con backoff exponencial
  static Future<SyncErrorLogsResult> enviarErrorLogsAlServidor({
    int limit = 50,
  }) async {
    try {
      _logger.i('📤 Iniciando envío de error logs pendientes...');

      // 1. Obtener errores LISTOS para reintento (respetando next_retry_at)
      final errores = await _getErrorsReadyForRetry(limit: limit);

      if (errores.isEmpty) {
        _logger.i('✅ No hay error logs pendientes para enviar');
        return SyncErrorLogsResult(
          exito: true,
          mensaje: 'No hay error logs pendientes',
          logsEnviados: 0,
        );
      }

      _logger.i('📊 Encontrados ${errores.length} error logs para reintento');

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
            // Actualizar para el siguiente reintento
            await _actualizarParaReintento(error);
          }
        } catch (e) {
          fallidos++;
          _logger.e('Error reenviando log ${error['id']}: $e');
          // Actualizar para el siguiente reintento
          await _actualizarParaReintento(error);
        }
      }

      // 3. Eliminar errores enviados exitosamente de la BD local
      if (erroresEnviados.isNotEmpty) {
        await _eliminarErrorsEnviados(erroresEnviados);
        _logger.i('🗑️ Eliminados $enviados error logs de la BD local');
      }

      _logger.i('✅ Reintento completado: $enviados enviados, $fallidos programados para próximo reintento');

      return SyncErrorLogsResult(
        exito: true,
        mensaje: 'Error logs: $enviados enviados, $fallidos programados para reintento',
        logsEnviados: enviados,
        logsFallidos: fallidos,
      );

    } catch (e) {
      _logger.e('💥 Error general en reintentos: $e');
      return SyncErrorLogsResult(
        exito: false,
        mensaje: 'Error en reintentos: $e',
        logsEnviados: 0,
      );
    }
  }

  /// Obtiene error logs que están listos para ser enviados (respetando next_retry_at)
  static Future<List<Map<String, dynamic>>> _getErrorsReadyForRetry({
    required int limit,
  }) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final now = DateTime.now().toIso8601String();

      final result = await db.query(
        'error_log',
        where: 'next_retry_at <= ?',
        whereArgs: [now],
        orderBy: 'next_retry_at ASC', // Los más antiguos primero
        limit: limit,
      );

      return result;

    } catch (e) {
      _logger.e('❌ Error obteniendo errores listos: $e');
      return [];
    }
  }

  /// Actualiza el error log para el siguiente reintento con backoff exponencial
  /// ♾️ REINTENTOS INFINITOS - nunca se descarta
  static Future<void> _actualizarParaReintento(Map<String, dynamic> error) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final retryCount = (error['retry_count'] as int? ?? 0) + 1;
      final now = DateTime.now();

      // Calcular el siguiente tiempo de reintento con backoff exponencial
      Duration delay;

      if (retryCount <= _maxRetriesBeforeBackoff) {
        // Primeros 5 intentos: cada 5 minutos
        delay = _baseRetryDelay;
      } else {
        // Después de 5 intentos: backoff exponencial con límite de 24 horas
        final exponentialDelay = _baseRetryDelay * (1 << (retryCount - _maxRetriesBeforeBackoff));
        delay = exponentialDelay > _maxRetryDelay ? _maxRetryDelay : exponentialDelay;
      }

      final nextRetryAt = now.add(delay);

      await db.update(
        'error_log',
        {
          'retry_count': retryCount,
          'last_retry_at': now.toIso8601String(),
          'next_retry_at': nextRetryAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [error['id']],
      );

      _logger.d('🔄 Error log ${error['id']} programado para reintento #$retryCount en ${delay.inMinutes} minutos');

    } catch (e) {
      _logger.e('❌ Error actualizando para reintento: $e');
    }
  }

  /// Envía un error log individual al servidor
  static Future<bool> _enviarErrorLogIndividual(Map<String, dynamic> errorLog) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final endpoint = '$baseUrl/appErrorLog/insertAppErrorLog';

      // Preparar el JSON interno con todos los datos del error
      final jsonData = {
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
        'retryCount': errorLog['retry_count'],
        'lastRetryAt': errorLog['last_retry_at'],
      };

      // 🎯 Payload según formato Groovy: todo dentro de "jsonData"
      final payload = {
        'jsonData': jsonEncode(jsonData),
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
        _logger.d('✅ Error log enviado exitosamente');
        return true;
      } else {
        _logger.w('⚠️ Error del servidor: ${response.statusCode} - ${response.body}');
        return false;
      }

    } catch (e) {
      _logger.e('❌ Error enviando log: $e');
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

  /// Obtiene todos los errores pendientes
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

      // Total de errores pendientes
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

      // Errores con más de 10 reintentos
      final highRetryResult = await db.rawQuery('''
        SELECT COUNT(*) as high_retry_count 
        FROM error_log 
        WHERE retry_count >= 10
      ''');
      final highRetryCount = (highRetryResult.first['high_retry_count'] as int?) ?? 0;

      // Próximo reintento programado
      final nextRetryResult = await db.rawQuery('''
        SELECT MIN(next_retry_at) as next_retry
        FROM error_log
      ''');
      final nextRetry = nextRetryResult.first['next_retry'] as String?;

      return {
        'total_pending_errors': total,
        'errors_with_high_retries': highRetryCount,
        'next_retry_at': nextRetry,
        'errors_by_type': typeResult,
        'errors_by_table': tableResult,
      };

    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'total_pending_errors': 0,
        'errors_with_high_retries': 0,
        'next_retry_at': null,
        'errors_by_type': [],
        'errors_by_table': [],
      };
    }
  }

  // ==================== LIMPIEZA ====================

  /// Limpia errores exitosamente enviados (normalmente esto se hace automáticamente)
  /// Este método es por si acaso quedan registros huérfanos
  static Future<int> cleanSentErrors() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // En realidad no deberían existir porque se eliminan al enviar
      // Pero por si acaso, limpiamos registros muy antiguos con muchos reintentos exitosos
      _logger.i('🧹 Verificando registros huérfanos...');

      // Por ahora no eliminamos nada automáticamente ya que queremos reintentos infinitos
      return 0;

    } catch (e) {
      _logger.e('❌ Error en limpieza: $e');
      return 0;
    }
  }

  /// Limpia TODOS los errores (usar con precaución - solo para debugging)
  static Future<void> clearAllErrors() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      await db.delete('error_log');
      _logger.i('🗑️ ⚠️ Todos los error logs eliminados (USAR SOLO PARA DEBUG)');

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
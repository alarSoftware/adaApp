import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:synchronized/synchronized.dart';

class ErrorLogService {
  static final Logger _logger = Logger();
  static const _uuid = Uuid();

  static final _locksByKey = <String, Lock>{};
  static final _mainLock = Lock();

  static const int _maxRetriesBeforeBackoff = 5;
  static const Duration _baseRetryDelay = Duration(minutes: 5);
  static const Duration _maxRetryDelay = Duration(hours: 24);

  static Future<void> logError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
    String? errorCode,
    String? errorType,
    int syncAttempt = 1,
    int? userId,
    String? endpoint,
  }) async {
    try {
      final now = DateTime.now();
      _logger.i('INICIANDO logError para $tableName - $operation');
      _logger.w('Error detectado: $tableName - $errorMessage');

      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final lockKey = '$tableName:$errorMessage';
      final lock = await _mainLock.synchronized(() {
        return _locksByKey.putIfAbsent(lockKey, () => Lock());
      });

      await lock.synchronized(() async {
        String? errorId;

        await db.transaction((txn) async {
          // MODIFICADO: Buscamos coincidencias incluyendo registro_fail_id y SIN filtrar por sincronizado
          // Esto permite encontrar logs previos aunque ya se hayan enviado, para solo actualizar el contador.
          final existente = await txn.rawQuery(
            '''
          SELECT id, retry_count 
          FROM error_log 
          WHERE table_name = ? 
            AND error_message = ? 
            AND (registro_fail_id = ? OR (? IS NULL AND registro_fail_id IS NULL))
          LIMIT 1
        ''',
            [tableName, errorMessage, registroFailId, registroFailId],
          );

          if (existente.isNotEmpty) {
            errorId = existente.first['id'] as String;
            final nuevoRetryCount =
                ((existente.first['retry_count'] as int?) ?? 0) + 1;

            _logger.i(
              'Error pendiente encontrado. Actualizando retry_count a $nuevoRetryCount',
            );

            // MODIFICADO: Al actualizar, reseteamos 'sincronizado' a 0 para que se vuelva a enviar
            await txn.rawUpdate(
              '''
            UPDATE error_log 
            SET retry_count = ?,
                last_retry_at = ?,
                next_retry_at = ?,
                timestamp = ?,
                sincronizado = 0,
                fecha_sincronizacion = NULL
            WHERE id = ?
          ''',
              [
                nuevoRetryCount,
                now.toIso8601String(),
                now.toIso8601String(),
                now.toIso8601String(),
                errorId,
              ],
            );

            _logger.i('Error log actualizado con ID: $errorId');
          } else {
            errorId = _uuid.v4();

            await txn.rawInsert(
              '''
            INSERT INTO error_log (
              id, timestamp, table_name, operation, registro_fail_id,
              error_code, error_message, error_type, sync_attempt, user_id,
              endpoint, retry_count, last_retry_at, next_retry_at,
              sincronizado, fecha_sincronizacion
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
              [
                errorId,
                now.toIso8601String(),
                tableName,
                operation,
                registroFailId,
                errorCode,
                errorMessage,
                errorType ?? 'unknown',
                syncAttempt,
                userId,
                endpoint,
                0,
                null,
                now.toIso8601String(),
                0,
                null,
              ],
            );

            _logger.i('Error log nuevo guardado con ID: $errorId');
          }
        });

        // El bloque de envío inmediato se mantiene igual, pero ahora actuará también sobre actualizaciones
        if (errorId != null) {
          final verificacion = await db.rawQuery(
            '''
          SELECT * FROM error_log 
          WHERE id = ?
        ''',
            [errorId],
          );

          if (verificacion.isNotEmpty) {
            _logger.i('VERIFICACION: Registro encontrado para envío inmediato');

            final enviadoExitosamente = await _enviarErrorLogIndividual(
              verificacion.first,
            );

            if (enviadoExitosamente) {
              _logger.i('Error log enviado inmediatamente al servidor');
              await db.rawUpdate(
                '''
              UPDATE error_log 
              SET sincronizado = 1,
                  fecha_sincronizacion = ?
              WHERE id = ?
            ''',
                [DateTime.now().toIso8601String(), errorId],
              );
              _logger.i('Marcado como sincronizado');
            }
          }
        }
      });
    } catch (e, stackTrace) {
      _logger.e('Error en logError: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  static Future<void> manejarExcepcion(
    dynamic excepcion,
    String? elementId,
    String? fullUrl,
    int? userId,
    String tableName,
  ) async {
    String tipoError;
    String codigoError;
    String mensajeUsuario;
    String mensajeDetallado;
    int timeoutSegundos = 60;

    if (excepcion is SocketException) {
      tipoError = 'network';
      codigoError = 'NETWORK_CONNECTION_ERROR';
      mensajeUsuario = 'Sin conexión de red';
      mensajeDetallado = 'Error de conexión de red: ${excepcion.message}';
    } else if (excepcion is TimeoutException) {
      tipoError = 'network';
      codigoError = 'REQUEST_TIMEOUT_ERROR';
      mensajeUsuario = 'Tiempo de espera agotado';
      mensajeDetallado = 'Timeout tras ${timeoutSegundos}s: $excepcion';
    } else if (excepcion is http.ClientException) {
      tipoError = 'network';
      codigoError = 'HTTP_CLIENT_ERROR';
      mensajeUsuario = 'Error de red: ${excepcion.message}';
      mensajeDetallado = 'Error HTTP del cliente: ${excepcion.message}';
    } else {
      tipoError = 'crash';
      codigoError = 'UNEXPECTED_EXCEPTION';
      mensajeUsuario = 'Error interno: $excepcion';
      mensajeDetallado = 'Excepción no manejada: $excepcion';
    }

    String operacion = '';
    if (tableName == 'censo_activo') {
    } else if (tableName == 'operacion_comercial') {}

    await ErrorLogService.logError(
      tableName: tableName,
      operation: 'EXCEPTION',
      errorMessage: mensajeDetallado,
      errorType: tipoError,
      errorCode: codigoError,
      registroFailId: elementId,
      endpoint: fullUrl,
      userId: userId,
    );
  }

  static Future<SyncErrorLogsResult> enviarErrorLogsAlServidor({
    int limit = 50,
  }) async {
    try {
      _logger.i('Iniciando envío de error logs pendientes...');

      final errores = await _getErrorsReadyForRetry(limit: limit);

      if (errores.isEmpty) {
        _logger.i('No hay error logs pendientes para enviar');
        return SyncErrorLogsResult(
          exito: true,
          mensaje: 'No hay error logs pendientes',
          logsEnviados: 0,
        );
      }

      _logger.i('Encontrados ${errores.length} error logs para reintento');

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
            await _actualizarParaReintento(error);
          }
        } catch (e) {
          fallidos++;
          await _actualizarParaReintento(error);
        }
      }

      if (erroresEnviados.isNotEmpty) {
        await _marcarErrorsComoEnviados(erroresEnviados);
      }
      return SyncErrorLogsResult(
        exito: true,
        mensaje:
            'Error logs: $enviados enviados, $fallidos programados para reintento',
        logsEnviados: enviados,
        logsFallidos: fallidos,
      );
    } catch (e) {
      return SyncErrorLogsResult(
        exito: false,
        mensaje: 'Error en reintentos: $e',
        logsEnviados: 0,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> _getErrorsReadyForRetry({
    required int limit,
  }) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final now = DateTime.now().toIso8601String();

      final result = await db.query(
        'error_log',
        where:
            'next_retry_at <= ? AND error_type != ? AND (sincronizado IS NULL OR sincronizado = 0)',
        whereArgs: [now, 'resuelto'],
        orderBy: 'next_retry_at ASC',
        limit: limit,
      );

      return result;
    } catch (e) {
      _logger.e('Error obteniendo errores listos: $e');
      return [];
    }
  }

  static Future<void> _actualizarParaReintento(
    Map<String, dynamic> error,
  ) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final retryCount = (error['retry_count'] as int? ?? 0) + 1;
      final now = DateTime.now();

      Duration delay;

      if (retryCount <= _maxRetriesBeforeBackoff) {
        delay = _baseRetryDelay;
      } else {
        final exponentialDelay =
            _baseRetryDelay * (1 << (retryCount - _maxRetriesBeforeBackoff));
        delay = exponentialDelay > _maxRetryDelay
            ? _maxRetryDelay
            : exponentialDelay;
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

      _logger.d(
        'Error log ${error['id']} programado para reintento #$retryCount en ${delay.inMinutes} minutos',
      );
    } catch (e) {
      _logger.e('Error actualizando para reintento: $e');
    }
  }

  static Future<bool> _enviarErrorLogIndividual(
    Map<String, dynamic> errorLog,
  ) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final endpoint = '$baseUrl/appErrorLog/insertAppErrorLog';

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

      final payload = {'jsonData': jsonEncode(jsonData)};

      _logger.d('Enviando error log: ${errorLog['id']}');

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.d('Error log enviado exitosamente');
        return true;
      } else {
        _logger.w(
          'Error del servidor: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Error enviando log: $e');
      return false;
    }
  }

  static Future<void> _marcarErrorsComoEnviados(List<String> ids) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final now = DateTime.now().toIso8601String();

      final placeholders = List.filled(ids.length, '?').join(',');
      await db.update(
        'error_log',
        {'sincronizado': 1, 'fecha_sincronizacion': now},
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );

      _logger.i('${ids.length} error logs marcados como sincronizados');
    } catch (e) {
      _logger.e('Error marcando logs como enviados: $e');
    }
  }

  static Future<void> marcarErroresComoResueltos({
    required String registroFailId,
    required String tableName,
  }) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final updated = await db.update(
        'error_log',
        {
          'error_status': 'done',
          'next_retry_at': null,
          'last_retry_at': DateTime.now().toIso8601String(),
        },
        where: 'registro_fail_id = ? AND table_name = ? AND error_status != ?',
        whereArgs: [registroFailId, tableName, 'done'],
      );

      if (updated > 0) {
        _logger.i(
          '$updated error(es) marcado(s) como resuelto(s) para $tableName:$registroFailId',
        );
      }
    } catch (e) {
      _logger.e('Error marcando errores como resueltos: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllErrors({int? limit}) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'error_log',
        where: 'error_type != ? AND (sincronizado IS NULL OR sincronizado = 0)',
        whereArgs: ['resuelto'],
        orderBy: 'timestamp DESC',
        limit: limit ?? 100,
      );

      return result;
    } catch (e) {
      _logger.e('Error obteniendo errores: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllErrorsIncludingResolved({
    int? limit,
  }) async {
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
      _logger.e('Error obteniendo errores: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getErrorsByTable(
    String tableName,
  ) async {
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
      _logger.e('Error obteniendo errores de tabla $tableName: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getErrorsByType(
    String errorType,
  ) async {
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
      _logger.e('Error obteniendo errores por tipo $errorType: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getErrorStats() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final totalResult = await db.rawQuery('''
        SELECT COUNT(*) as total 
        FROM error_log 
        WHERE error_type != 'resuelto' AND (sincronizado IS NULL OR sincronizado = 0)
      ''');
      final total = (totalResult.first['total'] as int?) ?? 0;

      final resolvedResult = await db.rawQuery('''
        SELECT COUNT(*) as resolved 
        FROM error_log 
        WHERE error_type = 'resuelto'
      ''');
      final resolved = (resolvedResult.first['resolved'] as int?) ?? 0;

      final syncedResult = await db.rawQuery('''
        SELECT COUNT(*) as synced 
        FROM error_log 
        WHERE sincronizado = 1
      ''');
      final synced = (syncedResult.first['synced'] as int?) ?? 0;

      final typeResult = await db.rawQuery('''
        SELECT error_type, COUNT(*) as count 
        FROM error_log 
        GROUP BY error_type
        ORDER BY count DESC
      ''');

      final tableResult = await db.rawQuery('''
        SELECT table_name, COUNT(*) as count 
        FROM error_log 
        GROUP BY table_name
        ORDER BY count DESC
      ''');

      final highRetryResult = await db.rawQuery('''
        SELECT COUNT(*) as high_retry_count 
        FROM error_log 
        WHERE retry_count >= 10 AND error_type != 'resuelto'
      ''');
      final highRetryCount =
          (highRetryResult.first['high_retry_count'] as int?) ?? 0;

      final nextRetryResult = await db.rawQuery('''
        SELECT MIN(next_retry_at) as next_retry
        FROM error_log
        WHERE error_type != 'resuelto' AND (sincronizado IS NULL OR sincronizado = 0)
      ''');
      final nextRetry = nextRetryResult.first['next_retry'] as String?;

      return {
        'total_pending_errors': total,
        'total_resolved_errors': resolved,
        'total_synced_errors': synced,
        'errors_with_high_retries': highRetryCount,
        'next_retry_at': nextRetry,
        'errors_by_type': typeResult,
        'errors_by_table': tableResult,
      };
    } catch (e) {
      _logger.e('Error obteniendo estadísticas: $e');
      return {
        'total_pending_errors': 0,
        'total_resolved_errors': 0,
        'total_synced_errors': 0,
        'errors_with_high_retries': 0,
        'next_retry_at': null,
        'errors_by_type': [],
        'errors_by_table': [],
      };
    }
  }

  static Future<int> cleanOldResolvedErrors({int daysOld = 30}) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final deleted = await db.delete(
        'error_log',
        where: 'error_type = ? AND sincronizado = 1 AND timestamp < ?',
        whereArgs: ['resuelto', cutoffDate.toIso8601String()],
      );

      if (deleted > 0) {
        _logger.i(
          'Eliminados $deleted error logs antiguos resueltos y sincronizados',
        );
      }

      return deleted;
    } catch (e) {
      _logger.e('Error en limpieza: $e');
      return 0;
    }
  }

  static Future<void> clearAllErrors() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      await db.delete('error_log');
      _logger.i('Todos los error logs eliminados (USAR SOLO PARA DEBUG)');
    } catch (e) {
      _logger.e('Error limpiando todos los errores: $e');
    }
  }

  static Future<void> logNetworkError({
    required String tableName,
    required String operation,
    required String errorMessage,
    String? registroFailId,
    String? endpoint,
    int? userId,
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
    int? userId,
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
    int? userId,
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

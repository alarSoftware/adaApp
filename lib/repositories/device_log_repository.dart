// lib/repositories/device_log_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:logger/logger.dart';

class DeviceLogRepository {
  final Database db;
  final _uuid = const Uuid();
  final _logger = Logger();

  DeviceLogRepository(this.db);

  // ==================== MÉTODOS EXISTENTES ====================

  Future<String> guardarLog({
    String? edfVendedorId,
    required double latitud,
    required double longitud,
    required int bateria,
    required String modelo,
  }) async {
    final log = DeviceLog(
      id: _uuid.v4(),
      edfVendedorId: edfVendedorId,
      latitudLongitud: '$latitud,$longitud',
      bateria: bateria,
      modelo: modelo,
      fechaRegistro: DateTime.now().toIso8601String(),
      sincronizado: 0, // ✅ Por defecto no sincronizado
    );

    await db.insert('device_log', log.toMap());
    _logger.i('✅ Device log guardado: ${log.id}');
    return log.id;
  }

  Future<List<DeviceLog>> obtenerTodos() async {
    final maps = await db.query('device_log', orderBy: 'fecha_registro DESC');
    return maps.map((map) => DeviceLog.fromMap(map)).toList();
  }

  // ==================== NUEVOS MÉTODOS PARA SINCRONIZACIÓN ====================

  /// Obtener todos los logs no sincronizados
  Future<List<DeviceLog>> obtenerNoSincronizados() async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_registro ASC',
      );

      final logs = maps.map((map) => DeviceLog.fromMap(map)).toList();
      _logger.i('📋 Logs no sincronizados encontrados: ${logs.length}');
      return logs;
    } catch (e) {
      _logger.e('❌ Error obteniendo logs no sincronizados: $e');
      return [];
    }
  }

  /// Marcar un log como sincronizado
  Future<void> marcarComoSincronizado(String logId) async {
    try {
      final count = await db.update(
        'device_log',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [logId],
      );

      if (count > 0) {
        _logger.i('✅ Log marcado como sincronizado: $logId');
      } else {
        _logger.w('⚠️ No se encontró el log: $logId');
      }
    } catch (e) {
      _logger.e('❌ Error marcando log como sincronizado: $e');
      rethrow;
    }
  }

  /// Obtener log por ID
  Future<DeviceLog?> obtenerPorId(String logId) async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'id = ?',
        whereArgs: [logId],
        limit: 1,
      );

      if (maps.isEmpty) {
        _logger.w('⚠️ Log no encontrado: $logId');
        return null;
      }

      return DeviceLog.fromMap(maps.first);
    } catch (e) {
      _logger.e('❌ Error obteniendo log por ID: $e');
      return null;
    }
  }

  /// Obtener logs sincronizados
  Future<List<DeviceLog>> obtenerSincronizados() async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'sincronizado = ?',
        whereArgs: [1],
        orderBy: 'fecha_registro DESC',
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo logs sincronizados: $e');
      return [];
    }
  }

  /// Obtener logs por vendedor
  Future<List<DeviceLog>> obtenerPorVendedor(String edfVendedorId) async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'edf_vendedor_id = ?',
        whereArgs: [edfVendedorId],
        orderBy: 'fecha_registro DESC',
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo logs por vendedor: $e');
      return [];
    }
  }

  /// Obtener logs en un rango de fechas
  Future<List<DeviceLog>> obtenerPorRangoFechas({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'fecha_registro BETWEEN ? AND ?',
        whereArgs: [
          fechaInicio.toIso8601String(),
          fechaFin.toIso8601String(),
        ],
        orderBy: 'fecha_registro DESC',
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo logs por rango de fechas: $e');
      return [];
    }
  }

  /// Contar logs pendientes de sincronización
  Future<int> contarPendientes() async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM device_log WHERE sincronizado = 0',
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      _logger.e('❌ Error contando pendientes: $e');
      return 0;
    }
  }

  /// Contar logs sincronizados
  Future<int> contarSincronizados() async {
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM device_log WHERE sincronizado = 1',
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      _logger.e('❌ Error contando sincronizados: $e');
      return 0;
    }
  }

  /// Eliminar logs sincronizados antiguos
  Future<int> eliminarSincronizadosAntiguos({int diasAntiguos = 7}) async {
    try {
      final fechaLimite = DateTime.now()
          .subtract(Duration(days: diasAntiguos))
          .toIso8601String();

      final count = await db.delete(
        'device_log',
        where: 'sincronizado = ? AND fecha_registro < ?',
        whereArgs: [1, fechaLimite],
      );

      _logger.i('🧹 Logs antiguos eliminados: $count');
      return count;
    } catch (e) {
      _logger.e('❌ Error eliminando logs antiguos: $e');
      return 0;
    }
  }

  /// Eliminar log específico
  Future<bool> eliminarLog(String logId) async {
    try {
      final count = await db.delete(
        'device_log',
        where: 'id = ?',
        whereArgs: [logId],
      );

      if (count > 0) {
        _logger.i('✅ Log eliminado: $logId');
        return true;
      } else {
        _logger.w('⚠️ No se encontró el log para eliminar: $logId');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error eliminando log: $e');
      return false;
    }
  }

  /// Eliminar todos los logs (usar con precaución)
  Future<int> eliminarTodos() async {
    try {
      final count = await db.delete('device_log');
      _logger.w('⚠️ Todos los logs eliminados: $count');
      return count;
    } catch (e) {
      _logger.e('❌ Error eliminando todos los logs: $e');
      return 0;
    }
  }

  /// Obtener estadísticas generales
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN sincronizado = 0 THEN 1 ELSE 0 END) as pendientes,
          SUM(CASE WHEN sincronizado = 1 THEN 1 ELSE 0 END) as sincronizados,
          MIN(fecha_registro) as primer_registro,
          MAX(fecha_registro) as ultimo_registro
        FROM device_log
      ''');

      final row = result.first;

      return {
        'total': row['total'] ?? 0,
        'pendientes': row['pendientes'] ?? 0,
        'sincronizados': row['sincronizados'] ?? 0,
        'primer_registro': row['primer_registro'],
        'ultimo_registro': row['ultimo_registro'],
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'pendientes': 0,
        'sincronizados': 0,
        'primer_registro': null,
        'ultimo_registro': null,
      };
    }
  }

  /// Obtener logs más recientes (útil para debugging)
  Future<List<DeviceLog>> obtenerRecientes({int limite = 10}) async {
    try {
      final maps = await db.query(
        'device_log',
        orderBy: 'fecha_registro DESC',
        limit: limite,
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
      _logger.e('❌ Error obteniendo logs recientes: $e');
      return [];
    }
  }

  /// Resetear estado de sincronización (útil para testing)
  Future<int> resetearSincronizacion() async {
    try {
      final count = await db.update(
        'device_log',
        {'sincronizado': 0},
      );

      _logger.w('⚠️ Sincronización reseteada para $count logs');
      return count;
    } catch (e) {
      _logger.e('❌ Error reseteando sincronización: $e');
      return 0;
    }
  }
}
import 'package:ada_app/models/data_usage_record.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:flutter/foundation.dart';

/// Servicio para registrar y consultar el consumo de datos
class DataUsageService {
  static const String _tableName = 'data_usage';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Registrar un nuevo uso de datos
  Future<void> recordUsage(DataUsageRecord record) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(_tableName, record.toMap());
    } catch (e) {
      debugPrint('Error registrando consumo de datos: $e');
    }
  }

  /// Obtener consumo total de hoy
  Future<int> getTodayUsage() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT SUM(total_bytes) as total
        FROM $_tableName
        WHERE timestamp >= ? AND timestamp < ?
      ''',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('Error obteniendo consumo de hoy: $e');
      return 0;
    }
  }

  /// Obtener consumo por período
  Future<int> getUsageByPeriod(DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT SUM(total_bytes) as total
        FROM $_tableName
        WHERE timestamp >= ? AND timestamp < ?
      ''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('Error obteniendo consumo por período: $e');
      return 0;
    }
  }

  /// Obtener consumo desglosado por categoría en un período
  Future<Map<String, int>> getUsageByCategory(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT operation_type, SUM(total_bytes) as total
        FROM $_tableName
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY operation_type
        ORDER BY total DESC
      ''',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final Map<String, int> categoryUsage = {};
      for (final row in result) {
        final type = row['operation_type'] as String;
        final total = row['total'] as int;
        categoryUsage[type] = total;
      }

      return categoryUsage;
    } catch (e) {
      debugPrint('Error obteniendo consumo por categoría: $e');
      return {};
    }
  }

  /// Obtener consumo diario de los últimos N días
  Future<Map<String, int>> getDailyUsage(int days) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days - 1));

      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT DATE(timestamp) as date, SUM(total_bytes) as total
        FROM $_tableName
        WHERE timestamp >= ?
        GROUP BY DATE(timestamp)
        ORDER BY date ASC
      ''',
        [startDate.toIso8601String()],
      );

      final Map<String, int> dailyUsage = {};
      for (final row in result) {
        final date = row['date'] as String;
        final total = row['total'] as int;
        dailyUsage[date] = total;
      }

      return dailyUsage;
    } catch (e) {
      debugPrint('Error obteniendo consumo diario: $e');
      return {};
    }
  }

  /// Obtener los registros más recientes
  Future<List<DataUsageRecord>> getRecentRecords({int limit = 100}) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        _tableName,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return result.map((map) => DataUsageRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error obteniendo registros recientes: $e');
      return [];
    }
  }

  /// Limpiar registros antiguos (más de 30 días)
  Future<int> clearOldRecords({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final db = await _dbHelper.database;

      final count = await db.delete(
        _tableName,
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      debugPrint('Registros antiguos eliminados: $count');
      return count;
    } catch (e) {
      debugPrint('Error limpiando registros antiguos: $e');
      return 0;
    }
  }

  /// Obtener estadísticas resumidas
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final today = await getTodayUsage();

      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: 7));
      final week = await getUsageByPeriod(startOfWeek, now);

      final startOfMonth = now.subtract(Duration(days: 30));
      final month = await getUsageByPeriod(startOfMonth, now);

      final categories = await getUsageByCategory(startOfMonth, now);

      return {
        'today': today,
        'week': week,
        'month': month,
        'categories': categories,
      };
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      return {'today': 0, 'week': 0, 'month': 0, 'categories': <String, int>{}};
    }
  }
}

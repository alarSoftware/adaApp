// lib/repositories/device_log_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/models/device_log.dart';

class DeviceLogRepository {
  final Database db;
  final _uuid = const Uuid();

  DeviceLogRepository(this.db);

  // ==================== MÉTODOS EXISTENTES ====================

  Future<String> guardarLog({
    String? employeeId,
    required double latitud,
    required double longitud,
    required int bateria,
    required String modelo,
  }) async {
    final log = DeviceLog(
      id: _uuid.v4(),
      employeeId: employeeId,
      latitudLongitud: '$latitud,$longitud',
      bateria: bateria,
      modelo: modelo,
      fechaRegistro: DateTime.now().toIso8601String(),
      sincronizado: 0, // ✅ Por defecto no sincronizado
    );

    await db.insert('device_log', log.toMapLocal());

    return log.id;
  }

  Future<List<DeviceLog>> obtenerTodos() async {
    final maps = await db.query('device_log', orderBy: 'fecha_registro DESC');
    return maps.map((map) => DeviceLog.fromMap(map)).toList();
  }

  // ==================== 🆕 NUEVOS MÉTODOS ANTI-DUPLICADOS ====================

  /// 🆕 Obtener el último log de un vendedor
  Future<DeviceLog?> obtenerUltimoLog(String? employeeId) async {
    try {
      // Si no hay vendedor, buscar el último log sin filtro
      final List<Map<String, dynamic>> maps;

      if (employeeId != null) {
        maps = await db.query(
          'device_log',
          where: 'employee_id = ?',
          whereArgs: [employeeId],
          orderBy: 'fecha_registro DESC',
          limit: 1,
        );
      } else {
        maps = await db.query(
          'device_log',
          orderBy: 'fecha_registro DESC',
          limit: 1,
        );
      }

      if (maps.isEmpty) return null;
      return DeviceLog.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  /// 🆕 Verificar si existe un log muy reciente (prevenir duplicados)
  Future<bool> existeLogReciente(
    String? employeeId, {
    int minutos = 8,
  }) async {
    try {
      final ultimoLog = await obtenerUltimoLog(employeeId);

      if (ultimoLog == null) return false;

      final tiempoDesdeUltimo = DateTime.now().difference(
        DateTime.parse(ultimoLog.fechaRegistro),
      );

      final esReciente = tiempoDesdeUltimo.inMinutes < minutos;

      if (esReciente) {}

      return esReciente;
    } catch (e) {
      return false; // En caso de error, permitir crear log
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

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

      return logs;
    } catch (e) {
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
      } else {}
    } catch (e) {
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
        return null;
      }

      return DeviceLog.fromMap(maps.first);
    } catch (e) {
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
      return [];
    }
  }

  /// Obtener logs por vendedor
  Future<List<DeviceLog>> obtenerPorVendedor(String employeeId) async {
    try {
      final maps = await db.query(
        'device_log',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'fecha_registro DESC',
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
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
        whereArgs: [fechaInicio.toIso8601String(), fechaFin.toIso8601String()],
        orderBy: 'fecha_registro DESC',
      );

      return maps.map((map) => DeviceLog.fromMap(map)).toList();
    } catch (e) {
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

      return count;
    } catch (e) {
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
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Eliminar todos los logs (usar con precaución)
  Future<int> eliminarTodos() async {
    try {
      final count = await db.delete('device_log');

      return count;
    } catch (e) {
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
      return [];
    }
  }

  /// Resetear estado de sincronización (útil para testing)
  Future<int> resetearSincronizacion() async {
    try {
      final count = await db.update('device_log', {'sincronizado': 0});

      return count;
    } catch (e) {
      return 0;
    }
  }
}

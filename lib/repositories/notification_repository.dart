import 'dart:convert';
import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class NotificationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'notifications';

  Future<void> _ensureTableExists() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isRead INTEGER DEFAULT 0
      )
    ''');

    // Intentar agregar nuevas columnas si no existen (Migración manual)
    try {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN target TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN targetConfig TEXT');
    } catch (_) {}
  }

  Future<int> insert(NotificationModel notification) async {
    await _ensureTableExists();

    // Serializar campos complejos para SQLite
    final Map<String, dynamic> data = notification.toJson();
    if (data['target'] != null && data['target'] is! String) {
      data['target'] = jsonEncode(data['target']);
    }
    if (data['targetConfig'] != null) {
      data['targetConfig'] = jsonEncode(data['targetConfig']);
    }

    return await _dbHelper.insertar(
      _tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NotificationModel>> getAll() async {
    await _ensureTableExists();
    final List<Map<String, dynamic>> maps = await _dbHelper.consultar(
      _tableName,
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return NotificationModel.fromJson(maps[i]);
    });
  }

  Future<int> getUnreadCount() async {
    await _ensureTableExists();
    return await _dbHelper.contarRegistros(
      _tableName,
      where: 'isRead = 0',
    );
  }

  Future<void> markAsRead(int id) async {
    await _ensureTableExists();
    await _dbHelper.actualizar(
      _tableName,
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllAsRead() async {
    await _ensureTableExists();
    await _dbHelper.actualizar(
      _tableName,
      {'isRead': 1},
      where: 'isRead = 0',
    );
  }

  Future<void> delete(int id) async {
    await _ensureTableExists();
    await _dbHelper.eliminar(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    await _ensureTableExists();
    await _dbHelper.eliminar(_tableName);
  }
}

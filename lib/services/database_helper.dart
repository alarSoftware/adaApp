import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cliente.dart';
import 'package:logger/logger.dart';

var logger= Logger();

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;


  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'clientes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telefono TEXT,
        direccion TEXT,
        fecha_creacion TEXT NOT NULL
      )
    ''');
  }

  /*Future<void> _insertarDatosEjemplo(Database db) async {
    List<Map<String, dynamic>> clientesEjemplo = [
      {
        'nombre': 'Juan Pérez',
        'email': 'juan@email.com',
        'telefono': '0981-123456',
        'direccion': 'Asunción, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'María García',
        'email': 'maria@email.com',
        'telefono': '0984-654321',
        'direccion': 'Luque, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Carlos López',
        'email': 'carlos@email.com',
        'telefono': '0985-789123',
        'direccion': 'San Lorenzo, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
    ];

    for (var cliente in clientesEjemplo) {
      await db.insert('clientes', cliente);
    }
  }*/

  // NUEVO: Método público para limpiar y sincronizar con datos de API
  Future<void> limpiarYSincronizar(List<Cliente> clientesAPI) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Limpiar tabla existente
        await txn.delete('clientes');

        // Insertar nuevos clientes
        for (Cliente cliente in clientesAPI) {
          await txn.insert('clientes', cliente.toMap());
        }
      });

      logger.i('✅ Base de datos sincronizada: ${clientesAPI.length} clientes');
    } catch (e) {
      logger.e('❌ Error en sincronización de base de datos: $e');
      throw Exception('Error sincronizando base de datos: $e');
    }
  }

  // NUEVO: Método público para limpiar y reiniciar con datos de ejemplo
  Future<void> reiniciarConDatosEjemplo() async {
    final db = await database;

    await db.transaction((txn) async {
      // Limpiar tabla
      await txn.delete('clientes');
      logger.i('🗑️ Tabla clientes limpiada');

      // Insertar datos de ejemplo
      List<Map<String, dynamic>> clientesEjemplo = [
        {
          'nombre': 'Juan Pérez',
          'email': 'juan@email.com',
          'telefono': '0981-123456',
          'direccion': 'Asunción, Paraguay',
          'fecha_creacion': DateTime.now().toIso8601String(),
        },
        {
          'nombre': 'María García',
          'email': 'maria@email.com',
          'telefono': '0984-654321',
          'direccion': 'Luque, Paraguay',
          'fecha_creacion': DateTime.now().toIso8601String(),
        },
        {
          'nombre': 'Carlos López',
          'email': 'carlos@email.com',
          'telefono': '0985-789123',
          'direccion': 'San Lorenzo, Paraguay',
          'fecha_creacion': DateTime.now().toIso8601String(),
        },
      ];

      for (var cliente in clientesEjemplo) {
        await txn.insert('clientes', cliente);
      }
    });

    logger.i('🔄 Base de datos reiniciada con datos de ejemplo');
  }

  // NUEVO: Obtener estadísticas de la base de datos
  Future<Map<String, int>> obtenerEstadisticas() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM clientes'
    );

    return {
      'totalClientes': result.first['total'] ?? 0,
    };
  }

  // Obtener todos los clientes
  Future<List<Cliente>> obtenerTodosLosClientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      orderBy: 'nombre ASC',
    );

    return List.generate(maps.length, (i) {
      return Cliente.fromMap(maps[i]);
    });
  }

  // Buscar clientes por nombre o email
  Future<List<Cliente>> buscarClientes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      where: 'nombre LIKE ? OR email LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nombre ASC',
    );

    return List.generate(maps.length, (i) {
      return Cliente.fromMap(maps[i]);
    });
  }

  // Insertar un cliente
  Future<int> insertarCliente(Cliente cliente) async {
    final db = await database;
    try {
      return await db.insert('clientes', cliente.toMap());
    } catch (e) {
      // Si hay error de duplicado de email, intentar actualizar
      if (e.toString().contains('UNIQUE constraint failed')) {
        logger.e('⚠️ Email duplicado, intentando actualizar: ${cliente.email}');
        return await db.update(
          'clientes',
          cliente.toMap(),
          where: 'email = ?',
          whereArgs: [cliente.email],
        );
      }
      rethrow;
    }
  }

  // Insertar múltiples clientes (útil para sincronización)
  Future<int> insertarMultiplesClientes(List<Cliente> clientes) async {
    final db = await database;
    int insertados = 0;

    await db.transaction((txn) async {
      for (Cliente cliente in clientes) {
        try {
          await txn.insert('clientes', cliente.toMap());
          insertados++;
        } catch (e) {
          if (e.toString().contains('UNIQUE constraint failed')) {
            await txn.update(
              'clientes',
              cliente.toMap(),
              where: 'email = ?',
              whereArgs: [cliente.email],
            );
            insertados++;
          }
        }
      }
    });

    return insertados;
  }

  // Actualizar un cliente
  Future<int> actualizarCliente(Cliente cliente) async {
    final db = await database;
    return await db.update(
      'clientes',
      cliente.toMap(),
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  // Eliminar un cliente
  Future<int> eliminarCliente(int id) async {
    final db = await database;
    return await db.delete(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtener un cliente por ID
  Future<Cliente?> obtenerClientePorId(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Cliente.fromMap(maps.first);
    }
    return null;
  }

  // Verificar si existe un cliente con el email
  Future<bool> existeEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // Cerrar la base de datos
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
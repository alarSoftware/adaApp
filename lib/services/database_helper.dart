import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cliente.dart';

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

    // Insertar algunos datos de ejemplo
    await _insertarDatosEjemplo(db);
  }

  Future<void> _insertarDatosEjemplo(Database db) async {
    List<Map<String, dynamic>> clientesEjemplo = [
      {
        'nombre': 'Ana Torres',
        'email': 'ana.torres@email.com',
        'telefono': '0981-222333',
        'direccion': 'Encarnación, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Luis Fernández',
        'email': 'luis.fernandez@email.com',
        'telefono': '0982-334455',
        'direccion': 'Ciudad del Este, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Carmen Duarte',
        'email': 'carmen.duarte@email.com',
        'telefono': '0983-556677',
        'direccion': 'Villarrica, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Pedro González',
        'email': 'pedro.gonzalez@email.com',
        'telefono': '0984-778899',
        'direccion': 'Caaguazú, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Sofía Benítez',
        'email': 'sofia.benitez@email.com',
        'telefono': '0985-112233',
        'direccion': 'Itauguá, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Diego Martínez',
        'email': 'diego.martinez@email.com',
        'telefono': '0986-445566',
        'direccion': 'Limpio, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Patricia López',
        'email': 'patricia.lopez@email.com',
        'telefono': '0987-778800',
        'direccion': 'Areguá, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Miguel Romero',
        'email': 'miguel.romero@email.com',
        'telefono': '0981-998877',
        'direccion': 'Coronel Oviedo, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Valeria Chávez',
        'email': 'valeria.chavez@email.com',
        'telefono': '0982-667788',
        'direccion': 'Paraguarí, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
      {
        'nombre': 'Andrés Castro',
        'email': 'andres.castro@email.com',
        'telefono': '0983-445599',
        'direccion': 'Ypacaraí, Paraguay',
        'fecha_creacion': DateTime.now().toIso8601String(),
      },
    ];

    for (var cliente in clientesEjemplo) {
      await db.insert('clientes', cliente);
    }
  }

  // Obtener todos los clientes con límite
  Future<List<Cliente>> obtenerTodosLosClientes({int limit = 3}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      orderBy: 'nombre ASC',
      limit: limit,
    );

    return maps.map((e) => Cliente.fromMap(e)).toList();
  }

// Buscar clientes con límite
  Future<List<Cliente>> buscarClientes(String query, {int limit = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clientes',
      where: 'nombre LIKE ? OR email LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'nombre ASC',
      limit: limit,
    );

    return maps.map((e) => Cliente.fromMap(e)).toList();
  }


  // Insertar un cliente
  Future<int> insertarCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
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

  // Cerrar la base de datos
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
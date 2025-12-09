import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';

class Modelo {
  final int? id;
  final String nombre;

  Modelo({
    this.id,
    required this.nombre,
  });

  factory Modelo.fromMap(Map<String, dynamic> map) {
    return Modelo(
      id: map['id'],
      nombre: (map['nombre'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre.trim(),
    };
  }
}

class ModeloRepository {
  static const String _tableName = 'modelos';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Modelo>> obtenerTodos() async {
    try {
      final result = await _dbHelper.consultar(
        _tableName,
        orderBy: 'nombre ASC',
      );

      return result.map((map) => Modelo.fromMap(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Modelo?> obtenerPorId(int id) async {
    try {
      final result = await _dbHelper.consultarPorId(_tableName, id);
      return result != null ? Modelo.fromMap(result) : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Modelo>> buscarPorNombre(String nombre) async {
    try {
      final result = await _dbHelper.consultar(
        _tableName,
        where: 'nombre LIKE ?',
        whereArgs: ['%$nombre%'],
        orderBy: 'nombre ASC',
      );

      return result.map((map) => Modelo.fromMap(map)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> insertar(Modelo modelo) async {
    try {
      return await _dbHelper.insertar(_tableName, modelo.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> actualizar(Modelo modelo) async {
    try {
      if (modelo.id == null) {
        throw ArgumentError('El modelo debe tener un ID para actualizar');
      }

      final count = await _dbHelper.actualizar(
        _tableName,
        modelo.toMap(),
        where: 'id = ?',
        whereArgs: [modelo.id],
      );

      return count > 0;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      final count = await _dbHelper.eliminarPorId(_tableName, id);
      return count > 0;
    } catch (e) {
      rethrow;
    }
  }

  Future<SyncResult> sincronizarDesdeServidor() async {
    try {
      return await EquipmentSyncService.sincronizarModelos();
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final total = await _dbHelper.contarRegistros(_tableName);

      return {
        'total_modelos': total,
        'tabla': _tableName,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'total_modelos': 0,
      };
    }
  }

  Future<bool> existePorNombre(String nombre) async {
    try {
      return await _dbHelper.existeRegistro(
        _tableName,
        'LOWER(nombre) = LOWER(?)',
        [nombre.trim()],
      );
    } catch (e) {
      return false;
    }
  }
}
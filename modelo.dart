import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

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
      nombre: map['nombre'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class ModeloRepository {
  static const String _tableName = 'modelos';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Obtener todos los modelos
  Future<List<Modelo>> obtenerTodos() async {
    try {
      final result = await _dbHelper.consultar(
        _tableName,
        orderBy: 'nombre ASC',
      );

      return result.map((map) => Modelo.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error obteniendo modelos: $e');
      rethrow;
    }
  }

  /// Obtener modelo por ID
  Future<Modelo?> obtenerPorId(int id) async {
    try {
      final result = await _dbHelper.consultarPorId(_tableName, id);
      return result != null ? Modelo.fromMap(result) : null;
    } catch (e) {
      _logger.e('Error obteniendo modelo por ID $id: $e');
      rethrow;
    }
  }

  /// Buscar modelos por nombre (búsqueda parcial)
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
      _logger.e('Error buscando modelos por nombre "$nombre": $e');
      rethrow;
    }
  }

  /// Insertar nuevo modelo
  Future<int> insertar(Modelo modelo) async {
    try {
      return await _dbHelper.insertar(_tableName, modelo.toMap());
    } catch (e) {
      _logger.e('Error insertando modelo: $e');
      rethrow;
    }
  }

  /// Actualizar modelo existente
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
      _logger.e('Error actualizando modelo: $e');
      rethrow;
    }
  }

  /// Eliminar modelo
  Future<bool> eliminar(int id) async {
    try {
      final count = await _dbHelper.eliminarPorId(_tableName, id);
      return count > 0;
    } catch (e) {
      _logger.e('Error eliminando modelo: $e');
      rethrow;
    }
  }

  /// Sincronizar modelos desde el servidor
  Future<SyncResult> sincronizarDesdeServidor() async {
    try {
      _logger.i('Iniciando sincronización de modelos desde servidor');
      return await EquipmentSyncService.sincronizarModelos();
    } catch (e) {
      _logger.e('Error en sincronización de modelos: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener estadísticas de modelos
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final total = await _dbHelper.contarRegistros(_tableName);

      return {
        'total_modelos': total,
        'tabla': _tableName,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e('Error obteniendo estadísticas de modelos: $e');
      return {
        'error': e.toString(),
        'total_modelos': 0,
      };
    }
  }

  /// Verificar si existe un modelo por nombre
  Future<bool> existePorNombre(String nombre) async {
    try {
      return await _dbHelper.existeRegistro(
        _tableName,
        'LOWER(nombre) = LOWER(?)',
        [nombre.trim()],
      );
    } catch (e) {
      _logger.e('Error verificando existencia de modelo "$nombre": $e');
      return false;
    }
  }
}
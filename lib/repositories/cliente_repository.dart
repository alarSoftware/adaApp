import '../models/cliente.dart';
import 'base_repository.dart';

class ClienteRepository extends BaseRepository<Cliente> {
  @override
  String get tableName => 'clientes';

  @override
  Cliente fromMap(Map<String, dynamic> map) => Cliente.fromMap(map);

  @override
  Map<String, dynamic> toMap(Cliente cliente) => cliente.toMap();

  @override
  String getDefaultOrderBy() => 'nombre ASC';

  @override
  String getBuscarWhere() =>
      'LOWER(nombre) LIKE ? OR LOWER(propietario) LIKE ? OR LOWER(ruc_ci) LIKE ? OR LOWER(telefono) LIKE ? OR LOWER(direccion) LIKE ? OR CAST(codigo AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Cliente';

  // ✅ VERSIÓN SIMPLIFICADA - Excluye solo errores
  @override
  Future<List<Cliente>> buscar(String query) async {
    try {
      String sql = '''
        SELECT 
          c.*,
          -- ✅ Censo HOY (cualquier estado excepto error)
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo != 'error'
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          -- ✅ Formulario completado HOY
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo
           
        FROM $tableName c
        WHERE 1=1
      ''';

      final List<dynamic> params = [];

      if (query.trim().isNotEmpty) {
        sql += ' AND (${getBuscarWhere()})';
        params.addAll(getBuscarArgs(query));
      }

      sql += ' ORDER BY ${getDefaultOrderBy()}';

      final db = await dbHelper.database;
      final List<Map<String, dynamic>> rows = await db.rawQuery(sql, params);

      return rows.map((row) => fromMap(row)).toList();

    } catch (e) {
      logger.e('Error en ${getEntityName()}Repository.buscar: $e');
      throw Exception('Error al buscar ${getEntityName().toLowerCase()}s: $e');
    }
  }

  @override
  Future<List<Cliente>> obtenerTodos() async {
    return await buscar('');
  }

  @override
  Future<Cliente?> obtenerPorId(dynamic id) async {
    try {
      final sql = '''
        SELECT 
          c.*,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo != 'error'
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo
           
        FROM $tableName c
        WHERE c.id = ?
      ''';

      final db = await dbHelper.database;
      final result = await db.rawQuery(sql, [id]);

      if (result.isEmpty) return null;

      return fromMap(result.first);

    } catch (e) {
      logger.e('Error en ${getEntityName()}Repository.obtenerPorId: $e');
      throw Exception('Error al obtener ${getEntityName().toLowerCase()}: $e');
    }
  }

  Future<List<Cliente>> obtenerConCensoPendiente() async {
    try {
      final sql = '''
        SELECT 
          c.*,
          0 as tiene_censo_hoy,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo
           
        FROM $tableName c
        WHERE NOT EXISTS(
          SELECT 1 FROM censo_activo 
          WHERE cliente_id = c.id 
          AND DATE(fecha_revision) = DATE('now', 'localtime')
          AND estado_censo != 'error'
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();

    } catch (e) {
      logger.e('Error en obtenerConCensoPendiente: $e');
      throw Exception('Error al obtener clientes con censo pendiente: $e');
    }
  }

  Future<List<Cliente>> obtenerConFormularioPendiente() async {
    try {
      final sql = '''
        SELECT 
          c.*,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo != 'error'
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          0 as tiene_formulario_completo
           
        FROM $tableName c
        WHERE NOT EXISTS(
          SELECT 1 FROM dynamic_form_response 
          WHERE contacto_id = CAST(c.id AS TEXT)
          AND DATE(creation_date) = DATE('now', 'localtime')
          AND estado = 'completed'
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();

    } catch (e) {
      logger.e('Error en obtenerConFormularioPendiente: $e');
      throw Exception('Error al obtener clientes con formulario pendiente: $e');
    }
  }

  Future<List<Cliente>> obtenerCompletados() async {
    try {
      final sql = '''
        SELECT 
          c.*,
          1 as tiene_censo_hoy,
          1 as tiene_formulario_completo
           
        FROM $tableName c
        WHERE EXISTS(
          SELECT 1 FROM censo_activo 
          WHERE cliente_id = c.id 
          AND DATE(fecha_revision) = DATE('now', 'localtime')
          AND estado_censo != 'error'
        )
        AND EXISTS(
          SELECT 1 FROM dynamic_form_response 
          WHERE contacto_id = CAST(c.id AS TEXT)
          AND DATE(creation_date) = DATE('now', 'localtime')
          AND estado = 'completed'
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();

    } catch (e) {
      logger.e('Error en obtenerCompletados: $e');
      throw Exception('Error al obtener clientes completados: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final statsBase = await super.obtenerEstadisticas();

      final sql = '''
        SELECT 
          COUNT(*) as total_clientes,
          
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = clientes.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo != 'error'
            ) THEN 1 ELSE 0 
          END) as con_censo_hoy,
          
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(clientes.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END) as con_formulario_hoy,
          
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = clientes.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo != 'error'
            )
            AND EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(clientes.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END) as completados_hoy
          
        FROM $tableName
      ''';

      final result = await consultarPersonalizada(sql);
      final row = result.first;

      return {
        ...statsBase,
        'conCensoHoy': row['con_censo_hoy'] as int,
        'conFormularioHoy': row['con_formulario_hoy'] as int,
        'completadosHoy': row['completados_hoy'] as int,
        'pendientesHoy': (row['total_clientes'] as int) - (row['completados_hoy'] as int),
      };

    } catch (e) {
      logger.e('Error en obtenerEstadisticas: $e');
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  Future<Cliente?> obtenerPorRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty ? clientes.first : null;
  }

  Future<bool> existeRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty;
  }

  Future<List<Cliente>> obtenerPorCodigo(int codigo) async {
    return await buscar(codigo.toString());
  }

  Future<bool> existeCodigo(int codigo) async {
    final clientes = await obtenerPorCodigo(codigo);
    return clientes.isNotEmpty;
  }

  Future<bool> verificarTablasEstado() async {
    try {
      final db = await dbHelper.database;

      final censoActivo = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='censo_activo'"
      );

      final dynamicFormResponse = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='dynamic_form_response'"
      );

      final tieneCensoActivo = censoActivo.isNotEmpty;
      final tieneDynamicForm = dynamicFormResponse.isNotEmpty;

      logger.i('Verificación de tablas - CensoActivo: $tieneCensoActivo, DynamicFormResponse: $tieneDynamicForm');

      return tieneCensoActivo && tieneDynamicForm;

    } catch (e) {
      logger.e('Error verificando tablas de estado: $e');
      return false;
    }
  }

  Future<void> verificarEsquemaCompleto() async {
    await debugEsquemaTabla();

    try {
      final tieneTablasEstado = await verificarTablasEstado();
      if (!tieneTablasEstado) {
        logger.w('⚠️  Las tablas de estado (censo_activo/dynamic_form_response) no existen aún');
      }
    } catch (e) {
      logger.e('Error en verificación completa: $e');
    }
  }
}
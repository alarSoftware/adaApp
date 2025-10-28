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

  // ✅ SOBRESCRIBIR EL MÉTODO BUSCAR PARA INCLUIR ESTADOS REALES
  @override
  Future<List<Cliente>> buscar(String query) async {
    try {
      // Query con las tablas reales y estados 'completed'
      String sql = '''
        SELECT 
          c.*,
          -- ✅ Censo completado HOY (censo_activo)
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          -- ✅ Formulario completado HOY (dynamic_form_response)
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

      // Agregar filtros de búsqueda si hay query
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

  // ✅ MÉTODO PARA OBTENER TODOS LOS CLIENTES CON ESTADOS
  @override
  Future<List<Cliente>> obtenerTodos() async {
    return await buscar(''); // Reutiliza buscar() con query vacío
  }

  // ✅ MÉTODO PARA OBTENER UN CLIENTE POR ID CON ESTADOS ACTUALIZADOS
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
              AND estado_censo = 'completed'
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

  // ✅ MÉTODOS ESPECÍFICOS PARA ESTADOS (CON TABLAS REALES)

  /// Obtiene clientes que NO han recibido censo hoy
  Future<List<Cliente>> obtenerConCensoPendiente() async {
    try {
      final sql = '''
        SELECT 
          c.*,
          0 as tiene_censo_hoy,  -- Por definición, no tienen censo hoy
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
          AND estado_censo = 'completed'
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

  /// Obtiene clientes que NO han completado formulario hoy
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
              AND estado_censo = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          0 as tiene_formulario_completo  -- Por definición, no tienen formulario hoy
           
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

  /// Obtiene clientes completamente atendidos HOY (censo + formulario)
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
          AND estado_censo = 'completed'
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

  /// Obtiene estadísticas de estado de todos los clientes HOY
  @override
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      // Obtener estadísticas básicas del BaseRepository
      final statsBase = await super.obtenerEstadisticas();

      // Agregar estadísticas específicas de estado HOY
      final sql = '''
        SELECT 
          COUNT(*) as total_clientes,
          
          -- Censos completados hoy
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = clientes.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo = 'completed'
            ) THEN 1 ELSE 0 
          END) as con_censo_hoy,
          
          -- Formularios completados hoy
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(clientes.id AS TEXT)
              AND DATE(creation_date) = DATE('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END) as con_formulario_hoy,
          
          -- Clientes completamente atendidos hoy (ambos)
          SUM(CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = clientes.id 
              AND DATE(fecha_revision) = DATE('now', 'localtime')
              AND estado_censo = 'completed'
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

      // Combinar estadísticas
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

  // ========== MÉTODOS ESPECÍFICOS ORIGINALES ==========

  /// Busca cliente por RUC/CI específico
  Future<Cliente?> obtenerPorRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty ? clientes.first : null;
  }

  /// Verifica si existe un cliente con el RUC/CI dado
  Future<bool> existeRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty;
  }

  /// Obtiene clientes por código específico
  Future<List<Cliente>> obtenerPorCodigo(int codigo) async {
    return await buscar(codigo.toString());
  }

  /// Verifica si existe un cliente con el código dado
  Future<bool> existeCodigo(int codigo) async {
    final clientes = await obtenerPorCodigo(codigo);
    return clientes.isNotEmpty;
  }

  // ✅ MÉTODO ÚTIL PARA DEBUG - VERIFICAR SI LAS TABLAS REALES EXISTEN
  Future<bool> verificarTablasEstado() async {
    try {
      final db = await dbHelper.database;

      // Verificar tabla censo_activo
      final censoActivo = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='censo_activo'"
      );

      // Verificar tabla dynamic_form_response
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

  // ✅ MÉTODO PARA VERIFICAR ESQUEMA COMPLETO
  Future<void> verificarEsquemaCompleto() async {
    await debugEsquemaTabla(); // Del BaseRepository

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
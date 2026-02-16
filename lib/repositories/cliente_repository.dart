import '../models/cliente.dart';
import '../utils/logger.dart';
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
    return [
      searchTerm,
      searchTerm,
      searchTerm,
      searchTerm,
      searchTerm,
      searchTerm,
    ];
  }

  @override
  String getEntityName() => 'Cliente';

  // MÉTODO PRINCIPAL CON FILTROS COMBINADOS
  Future<List<Cliente>> buscarConFiltros({
    String? query,
    String? rutaDia,
  }) async {
    try {
      String sql =
          '''
        SELECT 
          c.*,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND date(fecha_revision) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND date(creation_date) = date('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM operacion_comercial 
              WHERE cliente_id = c.id 
              AND date(fecha_creacion) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_operacion_comercial_hoy
           
        FROM $tableName c
        WHERE 1=1
      ''';

      final List<dynamic> params = [];

      // Filtro por día de ruta
      if (rutaDia != null && rutaDia.isNotEmpty) {
        sql += ' AND c.ruta_dia = ?';
        params.add(rutaDia);
      }

      // Filtro por búsqueda
      if (query != null && query.trim().isNotEmpty) {
        sql += ' AND (${getBuscarWhere()})';
        params.addAll(getBuscarArgs(query));
      }

      sql += ' ORDER BY ${getDefaultOrderBy()}';

      final db = await dbHelper.database;
      final List<Map<String, dynamic>> rows = await db.rawQuery(sql, params);

      return rows.map((row) => fromMap(row)).toList();
    } catch (e) {
      throw Exception('Error al buscar ${getEntityName().toLowerCase()}s: $e');
    }
  }

  @override
  Future<List<Cliente>> buscar(String query) async {
    return await buscarConFiltros(query: query);
  }

  @override
  Future<List<Cliente>> obtenerTodos() async {
    return await buscarConFiltros();
  }

  @override
  Future<Cliente?> obtenerPorId(dynamic id) async {
    try {
      final sql =
          '''
        SELECT 
          c.*,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND date(fecha_revision) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND date(creation_date) = date('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM operacion_comercial 
              WHERE cliente_id = c.id 
              AND date(fecha_creacion) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_operacion_comercial_hoy
           
        FROM $tableName c
        WHERE c.id = ?
      ''';

      final db = await dbHelper.database;
      final result = await db.rawQuery(sql, [id]);

      if (result.isEmpty) return null;

      return fromMap(result.first);
    } catch (e) {
      throw Exception('Error al obtener ${getEntityName().toLowerCase()}: $e');
    }
  }

  Future<List<Cliente>> obtenerConCensoPendiente() async {
    try {
      final sql =
          '''
        SELECT 
          c.*,
          0 as tiene_censo_hoy,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM dynamic_form_response 
              WHERE contacto_id = CAST(c.id AS TEXT)
              AND date(creation_date) = date('now', 'localtime')
              AND estado = 'completed'
            ) THEN 1 ELSE 0 
          END as tiene_formulario_completo,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM operacion_comercial 
              WHERE cliente_id = c.id 
              AND date(fecha_creacion) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_operacion_comercial_hoy
           
        FROM $tableName c
        WHERE NOT EXISTS(
          SELECT 1 FROM censo_activo 
          WHERE cliente_id = c.id 
          AND date(fecha_revision) = date('now', 'localtime')
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();
    } catch (e) {
      throw Exception('Error al obtener clientes con censo pendiente: $e');
    }
  }

  Future<List<Cliente>> obtenerConFormularioPendiente() async {
    try {
      final sql =
          '''
        SELECT 
          c.*,
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM censo_activo 
              WHERE cliente_id = c.id 
              AND date(fecha_revision) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_censo_hoy,
          
          0 as tiene_formulario_completo,
          
          CASE 
            WHEN EXISTS(
              SELECT 1 FROM operacion_comercial 
              WHERE cliente_id = c.id 
              AND date(fecha_creacion) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_operacion_comercial_hoy
           
        FROM $tableName c
        WHERE NOT EXISTS(
          SELECT 1 FROM dynamic_form_response 
          WHERE contacto_id = CAST(c.id AS TEXT)
          AND date(creation_date) = date('now', 'localtime')
          AND estado = 'completed'
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();
    } catch (e) {
      throw Exception('Error al obtener clientes con formulario pendiente: $e');
    }
  }

  Future<List<Cliente>> obtenerCompletados() async {
    try {
      final sql =
          '''
        SELECT 
          c.*,
          1 as tiene_censo_hoy,
          1 as tiene_formulario_completo,

          CASE 
            WHEN EXISTS(
              SELECT 1 FROM operacion_comercial 
              WHERE cliente_id = c.id 
              AND date(fecha_creacion) = date('now', 'localtime')
            ) THEN 1 ELSE 0 
          END as tiene_operacion_comercial_hoy
           
        FROM $tableName c
        WHERE EXISTS(
          SELECT 1 FROM censo_activo 
          WHERE cliente_id = c.id 
          AND date(fecha_revision) = date('now', 'localtime')
        )
        AND EXISTS(
          SELECT 1 FROM dynamic_form_response 
          WHERE contacto_id = CAST(c.id AS TEXT)
          AND date(creation_date) = date('now', 'localtime')
          AND estado = 'completed'
        )
        ORDER BY ${getDefaultOrderBy()}
      ''';

      final result = await consultarPersonalizada(sql);
      return result.map((row) => fromMap(row)).toList();
    } catch (e) {
      throw Exception('Error al obtener clientes completados: $e');
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
        "SELECT name FROM sqlite_master WHERE type='table' AND name='censo_activo'",
      );

      final dynamicFormResponse = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='dynamic_form_response'",
      );

      final tieneCensoActivo = censoActivo.isNotEmpty;
      final tieneDynamicForm = dynamicFormResponse.isNotEmpty;

      return tieneCensoActivo && tieneDynamicForm;
    } catch (e) {
      AppLogger.e('CLIENTE_REPOSITORY: Error en verificarTablasEstado', e);
      return false;
    }
  }

  Future<void> verificarEsquemaCompleto() async {
    await debugEsquemaTabla();

    try {
      final tieneTablasEstado = await verificarTablasEstado();
      if (!tieneTablasEstado) {
        AppLogger.w(
          'CLIENTE_REPOSITORY: Esquema incompleto - Faltan tablas de estado',
        );
      }
    } catch (e) {
      AppLogger.e('CLIENTE_REPOSITORY: Error en verificarEsquemaCompleto', e);
    }
  }
}

// database_queries.dart
import 'package:sqflite/sqflite.dart';

class DatabaseQueries {

  // ================================================================
  // CONSULTAS ESPECÍFICAS DEL NEGOCIO - ACTUALIZADAS
  // ================================================================

  Future<List<Map<String, dynamic>>> obtenerClientesConEquipos(Database db) async {
    return await db.rawQuery(_sqlClientesConEquipos());
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposDisponibles(Database db) async {
    return await db.rawQuery(_sqlEquiposDisponibles());
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposConDetalles(Database db) async {
    return await db.rawQuery(_sqlEquiposConDetalles());
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(Database db, int equipoId) async {
    return await db.rawQuery(_sqlHistorialEquipo(), [equipoId]);
  }

  // NUEVAS CONSULTAS PARA EQUIPOS PENDIENTES
  Future<List<Map<String, dynamic>>> obtenerEquiposPendientesPorCliente(Database db, int clienteId) async {
    return await db.rawQuery(_sqlEquiposPendientesPorCliente(), [clienteId]);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposAsignadosPorCliente(Database db, int clienteId) async {
    return await db.rawQuery(_sqlEquiposAsignadosPorCliente(), [clienteId]);
  }

  // ================================================================
  // DEFINICIONES SQL CORREGIDAS - SIN COLUMNAS INEXISTENTES
  // ================================================================

  String _sqlClientesConEquipos() => '''
    SELECT 
      c.*,
      COUNT(DISTINCT e.id) as total_equipos_asignados,
      COUNT(DISTINCT ep.id) as total_equipos_pendientes
    FROM clientes c
    LEFT JOIN equipos e ON c.id = e.cliente_id
    LEFT JOIN equipos_pendientes ep ON c.id = ep.cliente_id
    GROUP BY c.id
    ORDER BY c.nombre
  ''';

  String _sqlEquiposDisponibles() => '''
    SELECT 
      e.*,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre
    FROM equipos e
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    WHERE (e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0')
    ORDER BY m.nombre, mo.nombre
  ''';

  String _sqlEquiposConDetalles() => '''
    SELECT 
      e.*,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      CASE 
        WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 'Asignado'
        ELSE 'Disponible'
      END as estado_asignacion,
      c.nombre as cliente_nombre
    FROM equipos e
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON e.cliente_id = c.id
    ORDER BY m.nombre, mo.nombre
  ''';

  String _sqlHistorialEquipo() => '''
    SELECT 
      'asignado' as tipo,
      e.cliente_id,
      c.nombre as cliente_nombre,
      c.ruc_ci as cliente_ruc_ci,
      e.fecha_creacion as fecha,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre
    FROM equipos e
    JOIN clientes c ON e.cliente_id = c.id
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    WHERE e.id = ? AND e.cliente_id IS NOT NULL
    
    UNION ALL
    
    SELECT 
      'pendiente' as tipo,
      ep.cliente_id,
      c.nombre as cliente_nombre,
      c.ruc_ci as cliente_ruc_ci,
      ep.fecha_censo as fecha,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre
    FROM equipos_pendientes ep
    JOIN clientes c ON ep.cliente_id = c.id
    JOIN equipos e ON ep.equipo_id = e.id
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    WHERE ep.equipo_id = ?
    
    ORDER BY fecha DESC
  ''';

  // NUEVAS CONSULTAS CORREGIDAS
  String _sqlEquiposPendientesPorCliente() => '''
    SELECT 
      ep.*,
      e.cod_barras,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      c.nombre as cliente_nombre,
      'pendiente' as estado
    FROM equipos_pendientes ep
    INNER JOIN equipos e ON ep.equipo_id = e.id
    INNER JOIN marcas m ON e.marca_id = m.id
    INNER JOIN modelos mo ON e.modelo_id = mo.id
    INNER JOIN logo l ON e.logo_id = l.id
    INNER JOIN clientes c ON ep.cliente_id = c.id
    WHERE ep.cliente_id = ?
    ORDER BY ep.fecha_creacion DESC
  ''';

  String _sqlEquiposAsignadosPorCliente() => '''
    SELECT 
      e.*,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      c.nombre as cliente_nombre,
      'asignado' as estado
    FROM equipos e
    INNER JOIN marcas m ON e.marca_id = m.id
    INNER JOIN modelos mo ON e.modelo_id = mo.id
    INNER JOIN logo l ON e.logo_id = l.id
    INNER JOIN clientes c ON e.cliente_id = c.id
    WHERE e.cliente_id = ?
    ORDER BY e.fecha_creacion DESC
  ''';
}
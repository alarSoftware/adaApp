// database_queries.dart
import 'package:sqflite/sqflite.dart';

class DatabaseQueries {

  // ================================================================
  // CONSULTAS ESPECÍFICAS DEL NEGOCIO
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

  // ================================================================
  // DEFINICIONES SQL ORGANIZADAS Y LEGIBLES
  // ================================================================

  String _sqlClientesConEquipos() => '''
    SELECT 
      c.*,
      COUNT(ec.equipo_id) as total_equipos
    FROM clientes c
    LEFT JOIN equipo_cliente ec ON c.id = ec.cliente_id AND ec.activo = 1
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
    LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
      AND ec.activo = 1 
      AND ec.fecha_retiro IS NULL
    WHERE e.activo = 1 
      AND e.estado_local = 1 
      AND ec.equipo_id IS NULL
    ORDER BY m.nombre, mo.nombre
  ''';

  String _sqlEquiposConDetalles() => '''
    SELECT 
      e.*,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      CASE 
        WHEN ec.id IS NOT NULL THEN 'Asignado'
        ELSE 'Disponible'
      END as estado_asignacion,
      c.nombre as cliente_nombre
    FROM equipos e
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
      AND ec.activo = 1 
      AND ec.fecha_retiro IS NULL
    LEFT JOIN clientes c ON ec.cliente_id = c.id
    WHERE e.activo = 1
    ORDER BY m.nombre, mo.nombre
  ''';

  String _sqlHistorialEquipo() => '''
    SELECT 
      ec.*,
      c.nombre as cliente_nombre,
      c.ruc_ci as cliente_ruc_ci,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre
    FROM equipo_cliente ec
    JOIN clientes c ON ec.cliente_id = c.id
    JOIN equipos e ON ec.equipo_id = e.id
    JOIN marcas m ON e.marca_id = m.id
    JOIN modelos mo ON e.modelo_id = mo.id
    JOIN logo l ON e.logo_id = l.id
    WHERE ec.equipo_id = ?
    ORDER BY ec.fecha_asignacion DESC
  ''';
}
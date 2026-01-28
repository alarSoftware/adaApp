import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/services/data/database_helper.dart';

abstract class OperacionComercialDetalleRepository {
  Future<List<OperacionComercialDetalle>> obtenerDetallesPorOperacionId(
    String operacionId,
  );
}

class OperacionComercialDetalleRepositoryImpl
    implements OperacionComercialDetalleRepository {
  final DatabaseHelper dbHelper = DatabaseHelper();

  @override
  Future<List<OperacionComercialDetalle>> obtenerDetallesPorOperacionId(
    String operacionId,
  ) async {
    try {
      final db = await dbHelper.database;

      final resultado = await db.rawQuery(
        '''
        SELECT 
          ocd.id,
          ocd.operacion_comercial_id,
          ocd.producto_id,
          ocd.cantidad,
          ocd.ticket,
          ocd.precio_unitario,
          ocd.subtotal,
          ocd.orden,
          ocd.fecha_creacion,
          ocd.producto_reemplazo_id,
          p.codigo_barras AS producto_codigo_barras,
          pr.codigo_barras AS producto_reemplazo_codigo_barras
        FROM operacion_comercial_detalle ocd
        LEFT JOIN productos p ON ocd.producto_id = p.id
        LEFT JOIN productos pr ON ocd.producto_reemplazo_id = pr.id
        WHERE ocd.operacion_comercial_id = ?
        ORDER BY ocd.orden ASC
      ''',
        [operacionId],
      );

      return resultado
          .map((map) => OperacionComercialDetalle.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

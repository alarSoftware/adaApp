import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/models/device_log.dart';

class DeviceLogRepository {
  final Database db;
  final _uuid = Uuid();

  DeviceLogRepository(this.db);

  Future<String> guardarLog({
    String? edfVendedorId,
    required double latitud,
    required double longitud,
    required int bateria,
    required String modelo,
  }) async {
    final log = DeviceLog(
      id: _uuid.v4(),
      edfVendedorId: edfVendedorId,
      latitudLongitud: '$latitud,$longitud',
      bateria: bateria,
      modelo: modelo,
      fechaRegistro: DateTime.now().toIso8601String(),
    );

    await db.insert('device_log', log.toMap());
    return log.id;
  }

  Future<List<DeviceLog>> obtenerTodos() async {
    final maps = await db.query('device_log', orderBy: 'fecha_registro DESC');
    return maps.map((map) => DeviceLog.fromMap(map)).toList();
  }
}
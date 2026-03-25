// lib/models/device_log.dart

class DeviceLog {
  final String id;
  final String? employeeId;
  final String latitudLongitud;
  final int bateria;
  final String modelo;
  final String fechaRegistro;
  final int sincronizado;
  final String? imei;

  DeviceLog({
    required this.id,
    this.employeeId,
    required this.latitudLongitud,
    required this.bateria,
    required this.modelo,
    required this.fechaRegistro,
    this.sincronizado = 1,
    this.imei,
  });

  /// Metodo coincidente con backend Grails
  Map<String, dynamic> toMap() {
    return {
      'uuid': id,
      'employeeId': employeeId,
      'latitudLongitud': latitudLongitud,
      'bateria': bateria,
      'modelo': modelo,
      'fechaRegistro': fechaRegistro,
      'imei': imei,
    };
  }

  /// Metodo para BD local (mantiene formato con snake_case)
  Map<String, dynamic> toMapLocal() {
    return {
      'id': id,
      'employee_id': employeeId,
      'latitud_longitud': latitudLongitud,
      'bateria': bateria,
      'modelo': modelo,
      'fecha_registro': fechaRegistro,
      'sincronizado': sincronizado,
      'imei': imei,
    };
  }

  factory DeviceLog.fromMap(Map<String, dynamic> map) {
    return DeviceLog(
      id: map['id'],
      employeeId: map['employee_id'],
      latitudLongitud: map['latitud_longitud'],
      bateria: map['bateria'],
      modelo: map['modelo'],
      fechaRegistro: map['fecha_registro'],
      sincronizado: map['sincronizado'] ?? 1,
      imei: map['imei'],
    );
  }
}

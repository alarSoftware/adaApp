// lib/models/device_log.dart

class DeviceLog {
  final String id;
  final String? edfVendedorId;
  final String latitudLongitud;
  final int bateria;
  final String modelo;
  final String fechaRegistro;
  final int sincronizado;

  DeviceLog({
    required this.id,
    this.edfVendedorId,
    required this.latitudLongitud,
    required this.bateria,
    required this.modelo,
    required this.fechaRegistro,
    this.sincronizado = 1,
  });

  /// 🎯 MÉTODO CORREGIDO - Coincide exactamente con backend Grails
  Map<String, dynamic> toMap() {
    return {
      'uuid': id,                           // ✅ Backend espera 'uuid'
      'edfVendedorId': edfVendedorId,       // ✅ camelCase
      'latitudLongitud': latitudLongitud,   // ✅ camelCase
      'bateria': bateria,                   // ✅ igual
      'modelo': modelo,                     // ✅ igual
      'fechaRegistro': fechaRegistro,       // ✅ camelCase
      // ❌ NO enviar 'sincronizado' - no existe en backend
    };
  }

  /// 📦 Método para BD local (mantiene formato con snake_case)
  Map<String, dynamic> toMapLocal() {
    return {
      'id': id,
      'employed_id': edfVendedorId,
      'latitud_longitud': latitudLongitud,
      'bateria': bateria,
      'modelo': modelo,
      'fecha_registro': fechaRegistro,
      'sincronizado': sincronizado,
    };
  }

  factory DeviceLog.fromMap(Map<String, dynamic> map) {
    return DeviceLog(
      id: map['id'],
      edfVendedorId: map['employed_id'],
      latitudLongitud: map['latitud_longitud'],
      bateria: map['bateria'],
      modelo: map['modelo'],
      fechaRegistro: map['fecha_registro'],
      sincronizado: map['sincronizado'] ?? 1,
    );
  }

  /// 🔍 Ver exactamente qué se envía al backend (para debugging)
  String toBackendJsonDebug() {
    final map = toMap();
    return '''
🎯 JSON QUE SE ENVÍA AL BACKEND GRAILS:
{
  "uuid": "${map['uuid']}",
  "edfVendedorId": "${map['edfVendedorId']}",
  "latitudLongitud": "${map['latitudLongitud']}",
  "bateria": ${map['bateria']},
  "modelo": "${map['modelo']}",
  "fechaRegistro": "${map['fechaRegistro']}"
}

✅ Todos los campos coinciden con AppDeviceLog.groovy
''';
  }
}
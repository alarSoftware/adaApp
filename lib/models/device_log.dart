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
    this.sincronizado = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'edf_vendedor_id': edfVendedorId,
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
      edfVendedorId: map['edf_vendedor_id'],
      latitudLongitud: map['latitud_longitud'],
      bateria: map['bateria'],
      modelo: map['modelo'],
      fechaRegistro: map['fecha_registro'],
      sincronizado: map['sincronizado'] ?? 1,
    );
  }
}
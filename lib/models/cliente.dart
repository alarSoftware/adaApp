class Cliente {
  final int? id;
  final String nombre;
  final String telefono;
  final String direccion;
  final String rucCi;
  final String propietario;

  const Cliente({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.rucCi,
    required this.propietario,
  });

  // Factory constructor desde Map/JSON (API response)
  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as int?,
      nombre: _parseString(json['nombre']) ?? '',
      telefono: _parseString(json['telefono']) ?? '',
      direccion: _parseString(json['direccion']) ?? '',
      rucCi: _parseString(json['ruc_ci']) ?? '',
      propietario: _parseString(json['propietario']) ?? '',
    );
  }

  // Factory constructor desde Map (base de datos local)
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      telefono: map['telefono'] as String? ?? '',
      direccion: map['direccion'] as String? ?? '',
      rucCi: map['ruc_ci'] as String? ?? '',
      propietario: map['propietario'] as String? ?? '',
    );
  }

  // Convertir a Map para base de datos local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'ruc_ci': rucCi,
      'propietario': propietario,
    };
  }

  // Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'ruc_ci': rucCi,
      'propietario': propietario,
    };

    // Solo incluir ID si existe (para updates)
    if (id != null) json['id'] = id;

    return json;
  }

  // Método copyWith para crear copias con cambios
  Cliente copyWith({
    int? id,
    String? nombre,
    String? telefono,
    String? direccion,
    String? rucCi,
    String? propietario,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      rucCi: rucCi ?? this.rucCi,
      propietario: propietario ?? this.propietario,
    );
  }

  // Validación básica de campos requeridos
  bool get isValid =>
      nombre.isNotEmpty &&
          telefono.isNotEmpty &&
          direccion.isNotEmpty &&
          rucCi.isNotEmpty &&
          propietario.isNotEmpty;

  // Detectar tipo de documento de forma simple
  String get tipoDocumento {
    final clean = rucCi.replaceAll(RegExp(r'[\s\-]'), '');

    if (clean.startsWith('80') && clean.length == 10) {
      return 'RUC';
    } else if (RegExp(r'^\d+$').hasMatch(clean)) {
      return 'CI';
    } else {
      return 'Documento';
    }
  }

  // Getters simples sin formateo automático
  bool get esRuc => tipoDocumento == 'RUC';
  bool get esCi => tipoDocumento == 'CI';

  // Validación básica de teléfono paraguayo
  bool get hasValidPhone => _isValidParaguayanPhone(telefono);

  // Métodos de utilidad privados
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  bool _isValidParaguayanPhone(String phone) {
    // Formatos válidos: 0981-123456, 0981123456, +595981123456
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-+]'), '');

    if (cleanPhone.startsWith('595')) {
      return cleanPhone.length == 12 && cleanPhone.substring(3).startsWith('9');
    } else if (cleanPhone.startsWith('09')) {
      return cleanPhone.length == 10;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Cliente &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              nombre == other.nombre &&
              telefono == other.telefono &&
              direccion == other.direccion &&
              rucCi == other.rucCi &&
              propietario == other.propietario;

  @override
  int get hashCode =>
      id.hashCode ^
      nombre.hashCode ^
      telefono.hashCode ^
      direccion.hashCode ^
      rucCi.hashCode ^
      propietario.hashCode;

  @override
  String toString() {
    return 'Cliente{id: $id, nombre: $nombre, tipo: $tipoDocumento, ruc_ci: $rucCi}';
  }
}
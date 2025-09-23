class Cliente {
  final int? id;
  final String nombre;
  final int codigo;
  final String telefono;
  final String direccion;
  final String rucCi;
  final String propietario;

  const Cliente({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.telefono,
    required this.direccion,
    required this.rucCi,
    required this.propietario,
  });

  String get displayName {
    if (codigo > 0) {
      return '[$codigo] $nombre';
    }
    return nombre;
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as int?,
      nombre: _parseString(json['cliente']) ?? '',
      codigo: _parseIntFromString(json['clienteIdGc']) ?? 0, // ← clienteIdGc se carga en codigo
      telefono: _parseString(json['telefono']) ?? '',
      direccion: _parseString(json['direccion']) ?? '',
      rucCi: _parseString(json['ruc'] ?? json['cedula']) ?? '',
      propietario: _parseString(json['propietario']) ?? '',
    );
  }

  // Factory constructor desde Map (base de datos local)
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      codigo: map['codigo'] as int? ?? 0,
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
      'codigo': codigo,
      'telefono': telefono,
      'direccion': direccion,
      'ruc_ci': rucCi,
      'propietario': propietario,
    };
  }

  // Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'cliente': nombre,  // ← API usa 'cliente', no 'nombre'
      'clienteIdGc': codigo.toString(), // ← Enviar codigo como clienteIdGc
      'telefono': telefono,
      'direccion': direccion,
      'ruc': rucCi,
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
    int? codigo,
    String? telefono,
    String? direccion,
    String? rucCi,
    String? propietario,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      rucCi: rucCi ?? this.rucCi,
      propietario: propietario ?? this.propietario,
    );
  }

  // Validación básica de campos requeridos
  bool get isValid =>
      nombre.isNotEmpty &&
          direccion.isNotEmpty &&
          rucCi.isNotEmpty &&
          propietario.isNotEmpty;

  // Detectar tipo de documento de forma simple
  String get tipoDocumento {
    if (rucCi.isEmpty) return 'Documento';

    // Si contiene guión, es RUC
    if (rucCi.contains('-')) {
      return 'RUC';
    }

    // Si solo son números, es CI
    final clean = rucCi.replaceAll(RegExp(r'[\s]'), '');
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      return 'CI';
    }

    // Cualquier otro formato
    return 'Documento';
  }

  // Getters simples sin formateo automático
  bool get esRuc => tipoDocumento == 'RUC';
  bool get esCi => tipoDocumento == 'CI';

  // Validación básica de teléfono paraguayo
  bool get hasValidPhone => telefono.isNotEmpty && _isValidParaguayanPhone(telefono);

  // Métodos de utilidad privados
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static int _parseIntFromString(dynamic value) {
    if (value == null) return 0;
    final str = value.toString().trim();
    return int.tryParse(str) ?? 0;
  }

  bool _isValidParaguayanPhone(String phone) {
    if (phone.isEmpty) return false;

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
              codigo == other.codigo &&
              telefono == other.telefono &&
              direccion == other.direccion &&
              rucCi == other.rucCi &&
              propietario == other.propietario;

  @override
  int get hashCode =>
      id.hashCode ^
      nombre.hashCode ^
      codigo.hashCode ^
      telefono.hashCode ^
      direccion.hashCode ^
      rucCi.hashCode ^
      propietario.hashCode;

  @override
  String toString() {
    return 'Cliente{id: $id, nombre: $nombre, codigo: $codigo, tipo: $tipoDocumento, ruc_ci: $rucCi}';
  }
}
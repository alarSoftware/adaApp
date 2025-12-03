class Cliente {
  final int? id;
  final String nombre;
  final int codigo;
  final String telefono;
  final String direccion;
  final String rucCi;
  final String propietario;
  final String? rutaDia;

  // CAMPOS CALCULADOS - NO VAN A LA BASE DE DATOS
  // Solo se llenan cuando se obtienen desde queries con JOIN
  final bool tieneCensoHoy;
  final bool tieneFormularioCompleto;

  const Cliente({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.telefono,
    required this.direccion,
    required this.rucCi,
    required this.propietario,
    this.rutaDia,
    // Campos calculados con valores por defecto
    this.tieneCensoHoy = false,
    this.tieneFormularioCompleto = false,
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
      codigo: _parseIntFromString(json['clienteIdGc']),
      telefono: _parseString(json['telefono']) ?? '',
      direccion: _parseString(json['direccion']) ?? '',
      rucCi: _parseString(json['ruc'] ?? json['cedula']) ?? '',
      propietario: _parseString(json['propietario']) ?? '',
      rutaDia: _parseString(json['rutaDia'] ?? json['ruta_dia']),
      // Estados desde JSON (para futuras APIs) - opcional
      tieneCensoHoy: json['tiene_censo_hoy'] == 1 || json['tiene_censo_hoy'] == true,
      tieneFormularioCompleto: json['tiene_formulario_completo'] == 1 || json['tiene_formulario_completo'] == true,
    );
  }

  // FROMMAP - CARGA ESTADOS CALCULADOS DESDE QUERIES
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id']?.toString() ?? ''),

      nombre: map['nombre']?.toString() ?? '',

      codigo: map['codigo'] is int
          ? map['codigo'] ?? 0
          : int.tryParse(map['codigo']?.toString() ?? '') ?? 0,

      telefono: map['telefono']?.toString() ?? '',
      direccion: map['direccion']?.toString() ?? '',
      rucCi: map['ruc_ci']?.toString() ?? '',
      propietario: map['propietario']?.toString() ?? '',
      rutaDia: map['ruta_dia']?.toString(),

      // ESTADOS CALCULADOS DESDE QUERIES (1/0 o true/false)
      // Si el query no incluye estos campos, quedan en false por defecto
      tieneCensoHoy: map['tiene_censo_hoy'] == 1 || map['tiene_censo_hoy'] == true,
      tieneFormularioCompleto: map['tiene_formulario_completo'] == 1 || map['tiene_formulario_completo'] == true,
    );
  }

  // TOMAP - SOLO CAMPOS DE LA TABLA (SIN ESTADOS CALCULADOS)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'telefono': telefono,
      'direccion': direccion,
      'ruc_ci': rucCi,
      'propietario': propietario,
      'ruta_dia': rutaDia,
      // NO incluir los campos calculados aquí
      // porque no van a la tabla clientes
    };
  }

  // Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'cliente': nombre,
      'clienteIdGc': codigo.toString(),
      'telefono': telefono,
      'direccion': direccion,
      'ruc': rucCi,
      'propietario': propietario,
    };

    if (id != null) json['id'] = id;
    if (rutaDia != null) json['rutaDia'] = rutaDia;
    return json;
  }

  // COPYWITH - INCLUYE CAMPOS CALCULADOS
  Cliente copyWith({
    int? id,
    String? nombre,
    int? codigo,
    String? telefono,
    String? direccion,
    String? rucCi,
    String? propietario,
    String? rutaDia,
    bool? tieneCensoHoy,
    bool? tieneFormularioCompleto,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      rucCi: rucCi ?? this.rucCi,
      propietario: propietario ?? this.propietario,
      rutaDia: rutaDia ?? this.rutaDia,
      tieneCensoHoy: tieneCensoHoy ?? this.tieneCensoHoy,
      tieneFormularioCompleto: tieneFormularioCompleto ?? this.tieneFormularioCompleto,
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

    if (rucCi.contains('-')) {
      return 'RUC';
    }

    final clean = rucCi.replaceAll(RegExp(r'\s'), '');
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      return 'CI';
    }

    return 'Documento';
  }

  bool get esRuc => tipoDocumento == 'RUC';
  bool get esCi => tipoDocumento == 'CI';
  bool get hasValidPhone => telefono.isNotEmpty && _isValidParaguayanPhone(telefono);

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
              propietario == other.propietario &&
              rutaDia == other.rutaDia &&
              tieneCensoHoy == other.tieneCensoHoy &&
              tieneFormularioCompleto == other.tieneFormularioCompleto;

  @override
  int get hashCode =>
      id.hashCode ^
      nombre.hashCode ^
      codigo.hashCode ^
      telefono.hashCode ^
      direccion.hashCode ^
      rucCi.hashCode ^
      propietario.hashCode ^
      rutaDia.hashCode ^
      tieneCensoHoy.hashCode ^
      tieneFormularioCompleto.hashCode;

  @override
  String toString() {
    return 'Cliente{id: $id, nombre: $nombre, codigo: $codigo, tipo: $tipoDocumento, ruc_ci: $rucCi, ruta: $rutaDia, censo: $tieneCensoHoy, form: $tieneFormularioCompleto}';
  }
}
import 'dart:convert';

class Equipo {
  final String? id;
  final String? clienteId;
  final String codBarras;
  final int marcaId;
  final int modeloId;
  final String? numeroSerie;
  final int logoId;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;
  final int sincronizado;

  // Campos adicionales para JOIN (no se almacenan en DB)
  final String? marcaNombre;
  final String? modeloNombre;
  final String? logoNombre;

  Equipo({
    this.id,
    this.clienteId,
    required this.codBarras,
    required this.marcaId,
    required this.modeloId,
    this.numeroSerie,
    required this.logoId,
    DateTime? fechaCreacion,
    this.fechaActualizacion,
    this.sincronizado = 0,
    this.marcaNombre,
    this.modeloNombre,
    this.logoNombre,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'],
      clienteId: map['cliente_id']?.toString(),
      codBarras: map['cod_barras'] ?? '',
      marcaId: map['marca_id'] ?? 1,
      modeloId: map['modelo_id'] ?? 1,
      numeroSerie: map['numero_serie'],
      logoId: map['logo_id'] ?? 1,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: null,
      sincronizado: 0,
      marcaNombre: map['marca_nombre'],
      modeloNombre: map['modelo_nombre'],
      logoNombre: map['logo_nombre'],
    );
  }

  factory Equipo.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir a int de forma segura
    int _safeParseInt(dynamic value, {int defaultValue = 1}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    // Función auxiliar para limpiar strings
    String? _safeParseString(dynamic value) {
      if (value == null) return null;
      final stringValue = value.toString().trim();
      return stringValue.isEmpty ? null : stringValue;
    }

    DateTime fecha;
    DateTime? fechaAct;

    try {
      fecha = DateTime.parse(
          json['fecha_creacion'] ??
              json['fechaCreacion'] ??
              json['fecha'] ??
              DateTime.now().toIso8601String()
      );
    } catch (_) {
      fecha = DateTime.now();
    }

    try {
      if (json['fecha_actualizacion'] != null || json['fechaActualizacion'] != null) {
        fechaAct = DateTime.parse(
            json['fecha_actualizacion'] ?? json['fechaActualizacion']
        );
      }
    } catch (_) {
      fechaAct = null;
    }

    final clienteId = _safeParseString(json['clienteId']);

    return Equipo(
      id: _safeParseString(json['id']) ?? '',
      codBarras: _safeParseString(json['equipoId']) ?? '',
      marcaId: _safeParseInt(json['marcaId']),
      modeloId: _safeParseInt(json['edfModeloId']),
      numeroSerie: _safeParseString(json['numSerie']),
      logoId: _safeParseInt(json['edfLogoId']),
      clienteId: clienteId,
      fechaCreacion: fecha,
      fechaActualizacion: fechaAct,
      sincronizado: 0, // Siempre 0 para datos que vienen de API
      marcaNombre: null, // Se llenará con JOIN posteriormente
      modeloNombre: _safeParseString(json['equipo'])?.replaceAll('\n', ' '),
      logoNombre: null, // Se llenará con JOIN posteriormente
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'cod_barras': codBarras,
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'numero_serie': numeroSerie,
      'logo_id': logoId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clienteId': clienteId,
      'cod_barras': codBarras,
      'codBarras': codBarras,
      'marca_id': marcaId,
      'marcaId': marcaId,
      'modelo_id': modeloId,
      'modeloId': modeloId,
      'numero_serie': numeroSerie,
      'numeroSerie': numeroSerie,
      'logo_id': logoId,
      'logoId': logoId,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(), // Para compatibilidad
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(), // Para compatibilidad
      'sincronizado': sincronizado,
      'marca_nombre': marcaNombre, // Incluir para respuestas completas
      'modelo_nombre': modeloNombre,
      'logo_nombre': logoNombre,   // Incluir para respuestas completas
    };
  }

  Equipo copyWith({
    String? id,
    String? clienteId,
    String? codBarras,
    int? marcaId,
    int? modeloId,
    String? numeroSerie,
    int? logoId,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? sincronizado,
    String? marcaNombre,
    String? modeloNombre,
    String? logoNombre,
  }) {
    return Equipo(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      codBarras: codBarras ?? this.codBarras,
      marcaId: marcaId ?? this.marcaId,
      modeloId: modeloId ?? this.modeloId,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      logoId: logoId ?? this.logoId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      sincronizado: sincronizado ?? this.sincronizado,
      marcaNombre: marcaNombre ?? this.marcaNombre,
      modeloNombre: modeloNombre ?? this.modeloNombre,
      logoNombre: logoNombre ?? this.logoNombre,
    );
  }

  // Métodos de utilidad
  bool get estaSincronizado => sincronizado == 1;
  String get nombreCompleto => '$marcaNombre $modeloNombre';
  String get nombreCompletoFallback => 'MarcaID:$marcaId ModeloID:$modeloId';

  @override
  String toString() {
    return 'Equipo{id: $id, clienteId: $clienteId, codBarras: $codBarras, marcaId: $marcaId, modeloId: $modeloId, '
        'numeroSerie: $numeroSerie, logoId: $logoId, '
        'sincronizado: $sincronizado, marcaNombre: $marcaNombre, '
        'modeloNombre: $modeloNombre, logoNombre: $logoNombre}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Equipo &&
        other.id == id &&
        other.codBarras == codBarras;
  }

  @override
  int get hashCode => id.hashCode ^ codBarras.hashCode;
}

// ========================================
// FUNCIONES PARA PARSEAR LA RESPUESTA API
// ========================================

/// Parsea la respuesta completa del API que viene con estructura: {"data": "[{...}]"}
List<Equipo> parseEquiposFromApiResponse(String jsonResponse) {
  try {
    // 1. Primer parsing: obtener el objeto principal
    final Map<String, dynamic> mainJson = json.decode(jsonResponse);

    // 2. Verificar que existe el campo "data"
    if (!mainJson.containsKey('data') || mainJson['data'] == null) {
      print('No se encontró campo "data" en la respuesta');
      return [];
    }

    // 3. Segundo parsing: el campo "data" es un string que contiene JSON
    final String dataString = mainJson['data'].toString();
    final List<dynamic> equiposJson = json.decode(dataString);

    // 4. Convertir cada item a Equipo
    return equiposJson.map((item) {
      if (item is Map<String, dynamic>) {
        return Equipo.fromJson(item);
      } else {
        print('Item inválido en la lista: $item');
        return null;
      }
    }).where((equipo) => equipo != null).cast<Equipo>().toList();

  } catch (e, stackTrace) {
    print('Error parseando respuesta de API: $e');
    print('StackTrace: $stackTrace');
    return [];
  }
}

/// Si ya tienes el Map parseado (por ejemplo, de un HTTP response)
List<Equipo> parseEquiposFromMap(Map<String, dynamic> responseMap) {
  try {
    // 1. Verificar que existe el campo "data"
    if (!responseMap.containsKey('data') || responseMap['data'] == null) {
      print('No se encontró campo "data" en el Map');
      return [];
    }

    // 2. El campo "data" es un string que contiene JSON
    final String dataString = responseMap['data'].toString();
    final List<dynamic> equiposJson = json.decode(dataString);

    // 3. Convertir cada item a Equipo
    return equiposJson.map((item) {
      if (item is Map<String, dynamic>) {
        return Equipo.fromJson(item);
      } else {
        print('Item inválido en la lista: $item');
        return null;
      }
    }).where((equipo) => equipo != null).cast<Equipo>().toList();

  } catch (e, stackTrace) {
    print('Error parseando Map: $e');
    print('StackTrace: $stackTrace');
    return [];
  }
}

/// Para casos donde el array viene directamente (sin el wrapper "data")
List<Equipo> parseEquiposFromDirectArray(List<dynamic> equiposJson) {
  try {
    return equiposJson.map((item) {
      if (item is Map<String, dynamic>) {
        return Equipo.fromJson(item);
      } else {
        print('Item inválido en la lista: $item');
        return null;
      }
    }).where((equipo) => equipo != null).cast<Equipo>().toList();

  } catch (e, stackTrace) {
    print('Error parseando array directo: $e');
    print('StackTrace: $stackTrace');
    return [];
  }
}

// ========================================
// EJEMPLOS DE USO
// ========================================

/// Ejemplo de uso básico
void ejemploDeUso() {
  // Tu JSON de ejemplo
  String jsonResponse = '{"data":"[{\\"id\\":\\"09-00419\\",\\"equipoId\\":\\"09-00419\\",\\"fecVencGarantia\\":null,\\"clienteId\\":\\"193339\\",\\"marcaId\\":\\"101\\",\\"esAplicaCenso\\":false,\\"fechaBaja\\":null,\\"tipEquipoId\\":\\"100\\",\\"fecCompra\\":null,\\"edfLogoId\\":20,\\"facNumero\\":\\"2323\\",\\"costo\\":870.0,\\"esActivo\\":true,\\"esDisponible\\":true,\\"condicionId\\":\\"1\\",\\"monedaId\\":9,\\"fecFactura\\":null,\\"equipo\\":\\"BRIKET M5000 - PULP\\",\\"fecha\\":null,\\"observacion\\":null,\\"numSerie\\":\\"304271\\",\\"edfModeloId\\":102,\\"proveedorId\\":\\"101\\",\\"ubicacionInterna\\":\\"EN CLIENTE\\",\\"ubicacionId\\":\\"24\\"}]"}';

  // Parsear los equipos
  List<Equipo> equipos = parseEquiposFromApiResponse(jsonResponse);

  print('Equipos encontrados: ${equipos.length}');
  if (equipos.isNotEmpty) {
    print('Primer equipo:');
    print('- ID: ${equipos.first.id}');
    print('- Cliente ID: ${equipos.first.clienteId}');
    print('- Código de barras: ${equipos.first.codBarras}');
    print('- Marca ID: ${equipos.first.marcaId}');
    print('- Modelo ID: ${equipos.first.modeloId}');
    print('- Número serie: ${equipos.first.numeroSerie}');
  }
}

// ========================================
// MODELOS AUXILIARES CORREGIDOS
// ========================================

class Marca {
  final int? id;
  final String nombre;

  Marca({
    this.id,
    required this.nombre,
  });

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id'],
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}

class Modelo {
  final int? id;
  final String nombre;

  Modelo({
    this.id,
    required this.nombre,
  });

  factory Modelo.fromMap(Map<String, dynamic> map) {
    return Modelo(
      id: map['id'],
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}

class Logo {
  final int? id;
  final String nombre;

  Logo({
    this.id,
    required this.nombre,
  });

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: map['id'],
      nombre: map['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}
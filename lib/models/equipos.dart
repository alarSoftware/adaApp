import 'dart:convert';
import '../utils/logger.dart';
import 'package:ada_app/utils/parsing_helpers.dart';

// ============================================================================
// CLASE PRINCIPAL: EQUIPO
// ============================================================================

class Equipo {
  final String? id;
  final String? clienteId;
  final String codBarras;
  final int marcaId;
  final int modeloId;
  final String? numeroSerie;
  final int logoId;
  final bool nuevoEquipo;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  // Campos adicionales para JOIN (no se almacenan en DB)
  final String? marcaNombre;
  final String? modeloNombre;
  final String? logoNombre;

  const Equipo({
    this.id,
    this.clienteId,
    required this.codBarras,
    required this.marcaId,
    required this.modeloId,
    this.numeroSerie,
    required this.logoId,
    this.nuevoEquipo = false,
    required this.fechaCreacion,
    this.fechaActualizacion,
    this.marcaNombre,
    this.modeloNombre,
    this.logoNombre,
  });

  /// Constructor desde Map (base de datos local)
  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: ParsingHelpers.parseString(map['id']),
      clienteId: ParsingHelpers.parseString(map['cliente_id']),
      codBarras: ParsingHelpers.parseString(map['cod_barras']) ?? '',
      marcaId: ParsingHelpers.parseInt(map['marca_id'], defaultValue: 1),
      modeloId: ParsingHelpers.parseInt(map['modelo_id'], defaultValue: 1),
      numeroSerie: ParsingHelpers.parseString(map['numero_serie']),
      logoId: ParsingHelpers.parseInt(map['logo_id'], defaultValue: 1),
      nuevoEquipo: ParsingHelpers.intToBool(map['app_insert']),
      fechaCreacion: ParsingHelpers.parseDateTimeWithDefault(
        map['fecha_creacion'],
      ),
      fechaActualizacion: ParsingHelpers.parseDateTime(
        map['fecha_actualizacion'],
      ),
      marcaNombre: ParsingHelpers.parseString(map['marca_nombre']),
      modeloNombre: ParsingHelpers.parseString(map['modelo_nombre']),
      logoNombre: ParsingHelpers.parseString(map['logo_nombre']),
    );
  }

  /// Constructor desde JSON (API externa)
  factory Equipo.fromJson(Map<String, dynamic> json) {
    // Procesar nombre del modelo (eliminar saltos de línea)
    final modeloNombre = ParsingHelpers.parseString(json['equipo']);
    final modeloNombreLimpio = modeloNombre?.replaceAll('\n', ' ');

    return Equipo(
      id: ParsingHelpers.parseString(json['id']) ?? '',
      clienteId: ParsingHelpers.parseString(json['clienteId']),
      codBarras: ParsingHelpers.parseString(json['equipoId']) ?? '',
      marcaId: ParsingHelpers.parseInt(json['marcaId'], defaultValue: 1),
      modeloId: ParsingHelpers.parseInt(json['edfModeloId'], defaultValue: 1),
      numeroSerie: ParsingHelpers.parseString(json['numSerie']),
      logoId: ParsingHelpers.parseInt(json['edfLogoId'], defaultValue: 1),
      nuevoEquipo: ParsingHelpers.parseBool(
        json['appInsert'] ?? json['app_insert'],
      ),
      fechaCreacion: ParsingHelpers.parseDateTimeWithDefault(
        json['fecha_creacion'] ?? json['fechaCreacion'] ?? json['fecha'],
      ),
      fechaActualizacion: ParsingHelpers.parseDateTime(
        json['fecha_actualizacion'] ?? json['fechaActualizacion'],
      ),
      marcaNombre: null, // Se llenará con JOIN posteriormente
      modeloNombre: modeloNombreLimpio,
      logoNombre: null, // Se llenará con JOIN posteriormente
    );
  }

  // ==========================================================================
  // SERIALIZATION
  // ==========================================================================

  /// Convertir a Map para base de datos local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'cod_barras': codBarras,
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'numero_serie': numeroSerie,
      'logo_id': logoId,
      'app_insert': ParsingHelpers.boolToInt(nuevoEquipo),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
    };
  }

  /// Convertir a JSON para API externa
  Map<String, dynamic> toJson() {
    return {
      // IDs
      'id': id,
      'clienteId': clienteId,

      // Código de barras (snake_case y camelCase para compatibilidad)
      'cod_barras': codBarras,
      'codBarras': codBarras,

      // Marca (snake_case y camelCase)
      'marca_id': marcaId,
      'marcaId': marcaId,

      // Modelo (snake_case y camelCase)
      'modelo_id': modeloId,
      'modeloId': modeloId,

      // Número de serie (snake_case y camelCase)
      'numero_serie': numeroSerie,
      'numeroSerie': numeroSerie,

      // Logo (snake_case y camelCase)
      'logo_id': logoId,
      'logoId': logoId,

      // Nuevo equipo (múltiples formatos para compatibilidad)
      'app_insert': ParsingHelpers.boolToInt(nuevoEquipo), // int para BD
      'appInsert': nuevoEquipo, // bool para API
      // Fechas (snake_case y camelCase)
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(),

      // Nombres de relaciones (para JOINs)
      'marca_nombre': marcaNombre,
      'modelo_nombre': modeloNombre,
      'logo_nombre': logoNombre,
    };
  }

  // ==========================================================================
  // UTILITIES
  // ==========================================================================

  /// Crear copia con campos modificados
  Equipo copyWith({
    String? id,
    String? clienteId,
    String? codBarras,
    int? marcaId,
    int? modeloId,
    String? numeroSerie,
    int? logoId,
    bool? nuevoEquipo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
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
      nuevoEquipo: nuevoEquipo ?? this.nuevoEquipo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      marcaNombre: marcaNombre ?? this.marcaNombre,
      modeloNombre: modeloNombre ?? this.modeloNombre,
      logoNombre: logoNombre ?? this.logoNombre,
    );
  }

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  /// Obtener nombre completo (marca + modelo)
  String get nombreCompleto {
    if (marcaNombre != null && modeloNombre != null) {
      return '$marcaNombre $modeloNombre';
    }
    return nombreCompletoFallback;
  }

  /// Nombre fallback cuando no hay JOINs
  String get nombreCompletoFallback => 'MarcaID:$marcaId ModeloID:$modeloId';

  /// Verificar si el equipo es nuevo (creado desde la app)
  bool get esNuevo => nuevoEquipo;

  /// Verificar si el equipo está asignado a un cliente
  bool get estaAsignado => clienteId != null && clienteId!.isNotEmpty;

  /// Verificar si el equipo está disponible (sin cliente)
  bool get estaDisponible => !estaAsignado;

  // ==========================================================================
  // OBJECT OVERRIDES
  // ==========================================================================

  @override
  String toString() {
    return 'Equipo{id: $id, codBarras: $codBarras, clienteId: $clienteId, '
        'marca: $marcaId/$marcaNombre, modelo: $modeloId/$modeloNombre, '
        'logo: $logoId/$logoNombre, nuevo: $nuevoEquipo}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Equipo &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        codBarras == other.codBarras;
  }

  @override
  int get hashCode => id.hashCode ^ codBarras.hashCode;
}

// ============================================================================
// FUNCIONES DE PARSING DE RESPUESTA API
// ============================================================================

/// Parsear respuesta API con estructura: {"data": "[{...}]"}
List<Equipo> parseEquiposFromApiResponse(String jsonResponse) {
  try {
    // 1. Decodificar JSON principal
    final Map<String, dynamic> mainJson = json.decode(jsonResponse);

    // 2. Verificar campo "data"
    if (!mainJson.containsKey('data') || mainJson['data'] == null) {
      return [];
    }

    // 3. Decodificar el string JSON interno
    final String dataString = mainJson['data'].toString();
    final List<dynamic> equiposJson = json.decode(dataString);

    // 4. Convertir cada item a Equipo
    return equiposJson
        .whereType<Map<String, dynamic>>()
        .map((item) => Equipo.fromJson(item))
        .toList();
  } catch (e) { AppLogger.e("EQUIPOS: Error", e); return []; }
}

/// Parsear desde Map ya decodificado
List<Equipo> parseEquiposFromMap(Map<String, dynamic> responseMap) {
  try {
    // 1. Verificar campo "data"
    if (!responseMap.containsKey('data') || responseMap['data'] == null) {
      return [];
    }

    // 2. Decodificar el string JSON interno
    final String dataString = responseMap['data'].toString();
    final List<dynamic> equiposJson = json.decode(dataString);

    // 3. Convertir cada item a Equipo
    return equiposJson
        .whereType<Map<String, dynamic>>()
        .map((item) => Equipo.fromJson(item))
        .toList();
  } catch (e) { AppLogger.e("EQUIPOS: Error", e); return []; }
}

/// Parsear desde array directo (sin wrapper "data")
List<Equipo> parseEquiposFromDirectArray(List<dynamic> equiposJson) {
  try {
    return equiposJson
        .whereType<Map<String, dynamic>>()
        .map((item) => Equipo.fromJson(item))
        .toList();
  } catch (e) { AppLogger.e("EQUIPOS: Error", e); return []; }
}

// ============================================================================
// MODELOS AUXILIARES (Marca, Modelo, Logo)
// ============================================================================

class Marca {
  final int? id;
  final String nombre;

  const Marca({this.id, required this.nombre});

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: ParsingHelpers.parseInt(map['id']),
      nombre: ParsingHelpers.parseString(map['nombre']) ?? '',
    );
  }

  factory Marca.fromJson(Map<String, dynamic> json) => Marca.fromMap(json);

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nombre': nombre.trim()};
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => 'Marca(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marca &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}

class Modelo {
  final int? id;
  final String nombre;

  const Modelo({this.id, required this.nombre});

  factory Modelo.fromMap(Map<String, dynamic> map) {
    return Modelo(
      id: ParsingHelpers.parseInt(map['id']),
      nombre: ParsingHelpers.parseString(map['nombre']) ?? '',
    );
  }

  factory Modelo.fromJson(Map<String, dynamic> json) => Modelo.fromMap(json);

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nombre': nombre.trim()};
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => 'Modelo(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Modelo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}

class Logo {
  final int? id;
  final String nombre;

  const Logo({this.id, required this.nombre});

  factory Logo.fromMap(Map<String, dynamic> map) {
    return Logo(
      id: ParsingHelpers.parseInt(map['id']),
      nombre: ParsingHelpers.parseString(map['nombre']) ?? '',
    );
  }

  factory Logo.fromJson(Map<String, dynamic> json) => Logo.fromMap(json);

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nombre': nombre.trim()};
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => 'Logo(id: $id, nombre: $nombre)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Logo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}

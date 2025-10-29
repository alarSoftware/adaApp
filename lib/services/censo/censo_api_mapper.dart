// lib/services/censo/censo_api_mapper.dart

import 'package:uuid/uuid.dart';
import 'package:ada_app/models/cliente.dart';

class CensoApiMapper {
  static final Uuid _uuid = const Uuid();

  /// Prepara los datos completos del censo para guardar localmente
  static Map<String, dynamic> prepararDatosCompletos({
    required String estadoId,
    required String equipoId,
    required Cliente cliente,
    required int usuarioId,
    required Map<String, dynamic> datosOriginales,
    required Map<String, dynamic> equipoCompleto,
    required bool esCenso,
    required bool esNuevoEquipo,
    required bool yaAsignado,
    String? imagenId1,
    String? imagenId2,
  }) {
    final now = DateTime.now().toLocal();
    final timestampId = _uuid.v4();

    return {
      'id_local': estadoId,
      'timestamp_id': timestampId,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': _formatearFechaLocal(now),
      'equipo_id': equipoId,
      'cliente_id': cliente.id,
      'usuario_id': usuarioId,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil - ${datosOriginales['observaciones'] ?? 'Censo registrado'}',

      // Ubicación
      'latitud': datosOriginales['latitud'],
      'longitud': datosOriginales['longitud'],

      // Primera imagen
      'imagen_path': datosOriginales['imagen_path'],
      'imagen_base64': datosOriginales['imagen_base64'],
      'imagen_id_1': imagenId1,
      'tiene_imagen': datosOriginales['tiene_imagen'] ?? false,
      'imagen_tamano': datosOriginales['imagen_tamano'],

      // Segunda imagen
      'imagen_path2': datosOriginales['imagen_path2'],
      'imagen_base64_2': datosOriginales['imagen_base64_2'],
      'imagen_id_2': imagenId2,
      'tiene_imagen2': datosOriginales['tiene_imagen2'] ?? false,
      'imagen_tamano2': datosOriginales['imagen_tamano2'],

      // Información del equipo
      'codigo_barras': equipoCompleto['cod_barras'] ?? datosOriginales['codigo_barras'],
      'numero_serie': equipoCompleto['numero_serie'] ?? datosOriginales['numero_serie'],
      'modelo': equipoCompleto['modelo_nombre'] ?? datosOriginales['modelo'],
      'logo': equipoCompleto['logo_nombre'] ?? datosOriginales['logo'],
      'marca_nombre': equipoCompleto['marca_nombre'] ?? 'Sin marca',

      // Información del cliente
      'cliente_nombre': cliente.nombre,

      // Observaciones y fechas
      'observaciones': datosOriginales['observaciones'],
      'fecha_registro': datosOriginales['fecha_registro'],
      'timestamp_gps': datosOriginales['timestamp_gps'],

      // Flags
      'es_censo': esCenso,
      'es_nuevo_equipo': esNuevoEquipo,
      'ya_asignado': yaAsignado,

      // Metadata
      'version_app': '1.0.0',
      'dispositivo': datosOriginales['dispositivo'] ?? 'android',
      'fecha_revision': _formatearFechaLocal(now),
      'en_local': true,
    };
  }

  /// Prepara los datos para enviar a la API de estados (insertCensoActivo)
  static Map<String, dynamic> prepararDatosParaApi({
    required Map<String, dynamic> datosLocales,
    required int usuarioId,
    String? edfVendedorId,
  }) {
    final now = DateTime.now().toLocal();

    // Preparar array de fotos con IDs
    final fotos = <Map<String, dynamic>>[];

    //RECORRER LOS CENSO ACTIVO FOTO DEL CENSO ACTIVO A ENVIAR


    // Agregar primera imagen si existe
    if (datosLocales['tiene_imagen'] == true && datosLocales['imagen_base64'] != null) {
      fotos.add({
        'id': datosLocales['imagen_id_1'],
        'base64': datosLocales['imagen_base64'],
        'path': datosLocales['imagen_path'],
        'tamano': datosLocales['imagen_tamano'],
      });
    }

    // Agregar segunda imagen si existe
    if (datosLocales['tiene_imagen2'] == true && datosLocales['imagen_base64_2'] != null) {
      fotos.add({
        'id': datosLocales['imagen_id_2'],
        'base64': datosLocales['imagen_base64_2'],
        'path': datosLocales['imagen_path2'],
        'tamano': datosLocales['imagen_tamano2'],
      });
    }

    return {
      'id': datosLocales['timestamp_id']?.toString() ?? _uuid.v4(),
      'edfVendedorSucursalId': '$edfVendedorId',
      'edfEquipoId': (datosLocales['equipo_id'] ?? '').toString(),
      'usuarioId': usuarioId,
      'edfClienteId': datosLocales['cliente_id'] ?? 0,
      'fecha_revision': datosLocales['fecha_revision'] ?? _formatearFechaLocal(now),
      'latitud': datosLocales['latitud'] ?? 0.0,
      'longitud': datosLocales['longitud'] ?? 0.0,
      'enLocal': datosLocales['en_local'] ?? true,
      'fechaDeRevision': datosLocales['fecha_revision'] ?? _formatearFechaLocal(now),
      'estadoCenso': datosLocales['ya_asignado'] == true ? 'asignado' : 'pendiente',
      'esNuevoEquipo': datosLocales['es_nuevo_equipo'] ?? false,

      // Array de fotos con IDs
      'fotos': fotos,
      'total_imagenes': fotos.length,

      // Resto de campos del censo
      'observaciones': datosLocales['observaciones'] ?? '',
      'estado_general': datosLocales['estado_general'] ?? '',
      'usuario_id': usuarioId,
      'cliente_id': datosLocales['cliente_id'] ?? 0,
      'equipo_id': (datosLocales['equipo_id'] ?? '').toString(),
      'equipo_codigo_barras': datosLocales['codigo_barras'] ?? '',
      'equipo_numero_serie': datosLocales['numero_serie'] ?? '',
      'equipo_modelo': datosLocales['modelo'] ?? '',
      'equipo_marca': datosLocales['marca_nombre'] ?? '',
      'equipo_logo': datosLocales['logo'] ?? '',
      'cliente_nombre': datosLocales['cliente_nombre'] ?? '',
      'en_local': datosLocales['en_local'] ?? true,
      'dispositivo': datosLocales['dispositivo'] ?? 'android',
      'es_censo': datosLocales['es_censo'] ?? true,
      'version_app': datosLocales['version_app'] ?? '1.0.0',
    };
  }

  /// Prepara datos simplificados para envío directo
  static Map<String, dynamic> prepararDatosSimplificados({
    required Map<String, dynamic> datos,
    required Cliente cliente,
    Map<String, dynamic>? equipoCompleto,
  }) {
    final idLocal = _uuid.v4();
    final now = DateTime.now().toLocal();

    return {
      'id_local': idLocal,
      'timestamp_id': idLocal,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': _formatearFechaLocal(now),
      'equipo_id': equipoCompleto?['id'],
      'cliente_id': cliente.id,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Sin observaciones'}',
      'observaciones': datos['observaciones'],
      'latitud': datos['latitud'],
      'longitud': datos['longitud'],
      'codigo_barras': datos['codigo_barras'],
      'modelo': datos['modelo'],
      'logo': datos['logo'],
      'numero_serie': datos['numero_serie'],
      'imagen_path': datos['imagen_path'],
      'imagen_base64': datos['imagen_base64'],
      'tiene_imagen': datos['tiene_imagen'] ?? false,
      'imagen_tamano': datos['imagen_tamano'],
      'imagen_path2': datos['imagen_path2'],
      'imagen_base64_2': datos['imagen_base64_2'],
      'tiene_imagen2': datos['tiene_imagen2'] ?? false,
      'imagen_tamano2': datos['imagen_tamano2'],
      'version_app': '1.0.0',
      'dispositivo': datos['dispositivo'] ?? 'android',
    };
  }

  // Helper privado para formatear fechas
  static String _formatearFechaLocal(DateTime fecha) {
    final local = fecha.toLocal();
    return local.toIso8601String().replaceAll('Z', '');
  }
}
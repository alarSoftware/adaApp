// lib/services/censo/censo_api_mapper.dart

import 'package:uuid/uuid.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/config/app_config.dart';

class CensoApiMapper {
  static final Uuid _uuid = const Uuid();

  /// Prepara los datos completos del censo para guardar localmente
  static Map<String, dynamic> prepararDatosCompletos({
    required String estadoId,
    required String equipoId,
    required Cliente cliente,
    required int usuarioId, // ← Lo recibimos
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
      'id': estadoId,
      'timestamp_id': timestampId,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion': _formatearFechaLocal(now),
      'equipo_id': equipoId,
      'cliente_id': cliente.id,
      'usuario_id': usuarioId,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil',

      // Ubicación
      'latitud': datosOriginales['latitud'],
      'longitud': datosOriginales['longitud'],

      // Primera imagen - YA NO SE GUARDAN EN CENSO_ACTIVO
      // Se guardan en censo_activo_foto
      'tiene_imagen': datosOriginales['tiene_imagen'] ?? false,

      // Segunda imagen - YA NO SE GUARDAN EN CENSO_ACTIVO
      'tiene_imagen2': datosOriginales['tiene_imagen2'] ?? false,

      // Información del equipo
      'codigo_barras':
          equipoCompleto['cod_barras'] ?? datosOriginales['codigo_barras'],
      'numero_serie':
          equipoCompleto['numero_serie'] ?? datosOriginales['numero_serie'],
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
      'version_app': AppConfig.currentAppVersion,
      'dispositivo': datosOriginales['dispositivo'] ?? 'android',
      'fecha_revision': _formatearFechaLocal(now),
      'en_local': true,
      'sincronizado': 0,
      'estado_censo': 'creado',
    };
  }

  /// Prepara los datos para enviar a la API de estados CON BASE64

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
      'estado_general': 'Equipo registrado desde APP móvil',
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
      'version_app': AppConfig.currentAppVersion,
      'dispositivo': datos['dispositivo'] ?? 'android',
    };
  }

  // Helper privado para formatear fechas
  static String _formatearFechaLocal(DateTime fecha) {
    final local = fecha.toLocal();
    return local.toIso8601String().replaceAll('Z', '');
  }
}

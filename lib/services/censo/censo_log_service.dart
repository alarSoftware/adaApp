// lib/services/censo/censo_log_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';

class CensoLogService {
  final Logger _logger = Logger();
  final CensoActivoFotoRepository _fotoRepository = CensoActivoFotoRepository();

  /// Guarda un log detallado del POST request en un archivo de texto
  Future<void> guardarLogPost({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String timestamp,
    String? censoActivoId,
  }) async {
    try {
      final file = await _obtenerArchivoLog();
      if (file == null) return;

      final contenido = await _generarContenidoLog(
        url: url,
        headers: headers,
        body: body,
        timestamp: timestamp,
        censoActivoId: censoActivoId,
        filePath: file.path,
      );

      await file.writeAsString(contenido);

      _logger.i('📁 Log guardado: ${file.uri.pathSegments.last}');
    } catch (e) {
      _logger.w('Error guardando log: $e');
    }
  }

  /// Obtiene la lista de logs guardados (ordenados por fecha, más reciente primero)
  Future<List<String>> obtenerLogsGuardados() async {
    try {
      final downloadsDir = await _obtenerDirectorioDescargas();
      if (downloadsDir == null || !await downloadsDir.exists()) {
        return [];
      }

      final files = downloadsDir
          .listSync()
          .whereType<File>()
          .where((file) =>
      file.path.contains('post_nuevo_equipo_') ||
          file.path.contains('censo_activo_post_'))
          .map((file) => file.path)
          .toList();

      // Ordenar por fecha de modificación (más reciente primero)
      files.sort((a, b) {
        try {
          final statA = File(a).statSync();
          final statB = File(b).statSync();
          return statB.modified.compareTo(statA.modified);
        } catch (e) {
          return b.compareTo(a);
        }
      });

      _logger.i('📁 ${files.length} logs encontrados');
      return files;
    } catch (e) {
      _logger.e('Error listando logs: $e');
      return [];
    }
  }

  // ==================== MÉTODOS PRIVADOS ====================

  Future<File?> _obtenerArchivoLog() async {
    final downloadsDir = await _obtenerDirectorioDescargas();
    if (downloadsDir == null) return null;

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final fechaFormateada = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}_'
        '${now.second.toString().padLeft(2, '0')}';

    final fileName = 'censo_activo_post_$fechaFormateada.txt';
    return File('${downloadsDir.path}/$fileName');
  }

  Future<Directory?> _obtenerDirectorioDescargas() async {
    try {
      if (Platform.isAndroid) {
        var downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          downloadsDir = Directory('${externalDir?.path}/Download');
        }
        return downloadsDir;
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
      return null;
    } catch (e) {
      _logger.w('Error obteniendo directorio: $e');
      return null;
    }
  }

  Future<String> _generarContenidoLog({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String timestamp,
    required String filePath,
    String? censoActivoId,
  }) async {
    final buffer = StringBuffer();
    final separador = '=' * 80;
    final divisor = '-' * 40;

    // Encabezado
    buffer.writeln(separador);
    buffer.writeln('CENSO ACTIVO - POST REQUEST LOG');
    buffer.writeln(separador);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('URL: $url');
    buffer.writeln('Archivo: $filePath');
    buffer.writeln('');

    // Headers
    buffer.writeln(divisor);
    buffer.writeln('HEADERS:');
    buffer.writeln(divisor);
    headers.forEach((key, value) => buffer.writeln('$key: $value'));
    buffer.writeln('');

    // Resumen del censo
    buffer.writeln(divisor);
    buffer.writeln('RESUMEN DEL CENSO:');
    buffer.writeln(divisor);
    await _agregarResumenCenso(buffer, body, censoActivoId);
    buffer.writeln('');

    // JSON completo
    buffer.writeln(divisor);
    buffer.writeln('REQUEST BODY (JSON):');
    buffer.writeln(divisor);
    await _agregarBodyJson(buffer, body, censoActivoId);
    buffer.writeln('');

    // Pie
    buffer.writeln(separador);
    buffer.writeln('FIN DEL LOG - ${DateTime.now().toLocal()}');
    buffer.writeln(separador);

    return buffer.toString();
  }

  // ✅ MÉTODO CORREGIDO PARA RESUMEN DEL CENSO
  Future<void> _agregarResumenCenso(
      StringBuffer buffer,
      Map<String, dynamic> body,
      String? censoActivoId,
      ) async {
    buffer.writeln('Equipo ID: ${body['edfEquipoId'] ?? body['equipo_id'] ?? 'N/A'}');
    buffer.writeln('Cliente ID: ${body['edfClienteId'] ?? body['cliente_id'] ?? 'N/A'}');
    buffer.writeln('Usuario ID: ${body['usuarioId'] ?? body['usuario_id'] ?? 'N/A'}');
    buffer.writeln('Latitud: ${body['latitud'] ?? 'N/A'}');
    buffer.writeln('Longitud: ${body['longitud'] ?? 'N/A'}');
    buffer.writeln('Es nuevo equipo: ${body['esNuevoEquipo'] ?? false}');

    // ✅ DETECTAR FOTOS DINÁMICAMENTE
    bool fotosDetectadas = false;

    // Primero intentar obtener de la base de datos
    if (censoActivoId != null) {
      try {
        final fotos = await _fotoRepository.obtenerFotosPorCenso(censoActivoId);
        if (fotos.isNotEmpty) {
          for (var foto in fotos) {
            buffer.writeln('Tiene imagen ${foto.orden}: true');
          }
          fotosDetectadas = true;
        }
      } catch (e) {
        _logger.w('No se pudieron obtener fotos para resumen: $e');
      }
    }

    // Si no se detectaron fotos de la BD, intentar del array del body
    if (!fotosDetectadas) {
      final fotosArray = body['fotos_censo_activo_foto'] as List<dynamic>?;
      if (fotosArray != null && fotosArray.isNotEmpty) {
        for (var foto in fotosArray) {
          if (foto is Map<String, dynamic>) {
            final orden = foto['orden'] ?? '?';
            buffer.writeln('Tiene imagen $orden: true');
          }
        }
        fotosDetectadas = true;
      }
    }

    // Fallback al método anterior si no se detectaron fotos
    if (!fotosDetectadas) {
      buffer.writeln('Tiene imagen 1: ${body['tiene_imagen'] ?? false}');
      buffer.writeln('Tiene imagen 2: ${body['tiene_imagen2'] ?? false}');
    }

    // Tamaños de imágenes (mantener lógica existente)
    if (body['imageBase64_1'] != null) {
      final tamano = body['imageBase64_1'].toString().length;
      buffer.writeln('Tamaño imagen 1: ${(tamano / 1024).toStringAsFixed(1)} KB');
    }
    if (body['imageBase64_2'] != null) {
      final tamano = body['imageBase64_2'].toString().length;
      buffer.writeln('Tamaño imagen 2: ${(tamano / 1024).toStringAsFixed(1)} KB');
    }

    buffer.writeln('Observaciones: ${body['observaciones'] ?? 'N/A'}');
    buffer.writeln('Estado censo: ${body['estadoCenso'] ?? 'N/A'}');
    buffer.writeln('Fecha revisión: ${body['fecha_revision'] ?? 'N/A'}');
  }

  // ✅ MÉTODO CORREGIDO PARA BODY JSON
  Future<void> _agregarBodyJson(
      StringBuffer buffer,
      Map<String, dynamic> body,
      String? censoActivoId,
      ) async {
    // Crear versión simplificada (sin estructuras anidadas)
    final bodySimplificado = <String, dynamic>{};
    body.forEach((key, value) {
      if (key != 'equipo' && key != 'cliente' && key != 'imagenes' && key != 'metadata') {
        bodySimplificado[key] = value;
      }
    });

    // ✅ AGREGAR INFO DE FOTOS CON FORMATO CORRECTO
    if (censoActivoId != null) {
      try {
        final fotos = await _fotoRepository.obtenerFotosPorCenso(censoActivoId);
        if (fotos.isNotEmpty) {
          // ✅ FORMATO CORRECTO CON ORDEN
          bodySimplificado['fotos_censo_activo_foto'] = fotos.map((foto) => {
            'orden': foto.orden,              // ✅ Campo orden agregado
            'uuid': foto.id ?? 'N/A',
            'path': foto.imagenPath ?? '',
            'tamano': foto.imagenTamano ?? 0,
          }).toList();
        }
      } catch (e) {
        _logger.w('No se pudieron obtener fotos para el log: $e');

        // ✅ FALLBACK: Si no se pueden obtener de BD, mantener las que vengan en el body
        if (body.containsKey('fotos_censo_activo_foto')) {
          bodySimplificado['fotos_censo_activo_foto'] = body['fotos_censo_activo_foto'];
        }
      }
    } else {
      // ✅ Si no hay censoActivoId pero el body tiene fotos, mantenerlas
      if (body.containsKey('fotos_censo_activo_foto')) {
        bodySimplificado['fotos_censo_activo_foto'] = body['fotos_censo_activo_foto'];
      }
    }

    final prettyJson = JsonEncoder.withIndent('  ').convert(bodySimplificado);
    buffer.writeln(prettyJson);
  }
}
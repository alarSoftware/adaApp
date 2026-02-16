// lib/services/dynamic_form/dynamic_form_log_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../utils/logger.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

class DynamicFormLogService {
  /// Guarda un log detallado del POST request en un archivo de texto
  Future<void> guardarLogPost({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String timestamp,
    String? responseId,
  }) async {
    try {
      final file = await _obtenerArchivoLog();
      if (file == null) return;

      final contenido = await _generarContenidoLog(
        url: url,
        headers: headers,
        body: body,
        timestamp: timestamp,
        responseId: responseId,
        filePath: file.path,
      );

      await file.writeAsString(contenido);

      debugPrint('📁 Log guardado: ${file.uri.pathSegments.last}');
    } catch (e) {
      debugPrint('Error guardando log: $e');
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
          .where((file) => file.path.contains('dynamic_form_post_'))
          .map((file) => file.path)
          .toList();

      // Ordenar por fecha de modificación (más reciente primero)
      files.sort((a, b) {
        try {
          final statA = File(a).statSync();
          final statB = File(b).statSync();
          return statB.modified.compareTo(statA.modified);
        } catch (e) { AppLogger.e("DYNAMIC_FORM_LOG_SERVICE: Error", e); return b.compareTo(a); }
      });

      debugPrint('📁 ${files.length} logs encontrados');
      return files;
    } catch (e) {
      debugPrint('Error listando logs: $e');
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
    final fechaFormateada =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}_'
        '${now.second.toString().padLeft(2, '0')}';

    final fileName = 'dynamic_form_post_$fechaFormateada.txt';
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
      debugPrint('Error obteniendo directorio: $e');
      return null;
    }
  }

  Future<String> _generarContenidoLog({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String timestamp,
    required String filePath,
    String? responseId,
  }) async {
    final buffer = StringBuffer();
    final separador = '=' * 80;
    final divisor = '-' * 40;

    // Encabezado
    buffer.writeln(separador);
    buffer.writeln('DYNAMIC FORM - POST REQUEST LOG');
    buffer.writeln(separador);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('URL: $url');
    buffer.writeln('Archivo: $filePath');
    if (responseId != null) {
      buffer.writeln('Response ID: $responseId');
    }
    buffer.writeln('');

    // Headers
    buffer.writeln(divisor);
    buffer.writeln('HEADERS:');
    buffer.writeln(divisor);
    headers.forEach((key, value) => buffer.writeln('$key: $value'));
    buffer.writeln('');

    // Resumen del formulario
    buffer.writeln(divisor);
    buffer.writeln('RESUMEN DEL FORMULARIO:');
    buffer.writeln(divisor);
    _agregarResumenFormulario(buffer, body);
    buffer.writeln('');

    // JSON completo (con imágenes truncadas)
    buffer.writeln(divisor);
    buffer.writeln('REQUEST BODY (JSON - Imágenes truncadas):');
    buffer.writeln(divisor);
    _agregarBodyJson(buffer, body);
    buffer.writeln('');

    // Pie
    buffer.writeln(separador);
    buffer.writeln('FIN DEL LOG - ${DateTime.now().toLocal()}');
    buffer.writeln(separador);

    return buffer.toString();
  }

  void _agregarResumenFormulario(
    StringBuffer buffer,
    Map<String, dynamic> body,
  ) {
    buffer.writeln('Form ID: ${body['id'] ?? 'N/A'}');
    buffer.writeln('Template ID: ${body['dynamicFormId'] ?? 'N/A'}');
    buffer.writeln('Contacto ID: ${body['contactoId'] ?? 'N/A'}');
    buffer.writeln('Vendedor ID: ${body['employeeId'] ?? 'N/A'}');
    buffer.writeln('Usuario ID: ${body['usuarioId'] ?? 'N/A'}');
    buffer.writeln('Estado: ${body['estado'] ?? 'N/A'}');
    buffer.writeln('Fecha creación: ${body['creationDate'] ?? 'N/A'}');
    buffer.writeln('Fecha completado: ${body['completedDate'] ?? 'N/A'}');
    buffer.writeln('');

    // Detalles
    final details = body['details'] as List<dynamic>?;
    if (details != null && details.isNotEmpty) {
      buffer.writeln('Cantidad de detalles: ${details.length}');
      int imageDetails = details
          .where((d) => d['response'] == '[IMAGE]')
          .length;
      int textDetails = details.length - imageDetails;
      buffer.writeln('  - Campos de texto: $textDetails');
      buffer.writeln('  - Campos de imagen: $imageDetails');
    } else {
      buffer.writeln('Cantidad de detalles: 0');
    }
    buffer.writeln('');

    // Fotos
    final fotos = body['fotos'] as List<dynamic>?;
    if (fotos != null && fotos.isNotEmpty) {
      buffer.writeln('Cantidad de fotos: ${fotos.length}');
      for (var i = 0; i < fotos.length; i++) {
        final foto = fotos[i] as Map<String, dynamic>;
        final orden = foto['orden'] ?? (i + 1);
        final tamano = foto['imagenTamano'] ?? 0;
        final mimeType = foto['mimeType'] ?? 'N/A';
        final hasBase64 =
            foto['imageBase64'] != null &&
            foto['imageBase64'].toString().isNotEmpty;

        buffer.writeln('  Foto $orden:');
        buffer.writeln(
          '    - Tamaño: ${(tamano / 1024).toStringAsFixed(2)} KB',
        );
        buffer.writeln('    - Tipo: $mimeType');
        buffer.writeln('    - Tiene Base64: $hasBase64');
        buffer.writeln('    - Path: ${foto['imagePath'] ?? 'N/A'}');
      }
    } else {
      buffer.writeln('Cantidad de fotos: 0');
    }
  }

  void _agregarBodyJson(StringBuffer buffer, Map<String, dynamic> body) {
    // Crear copia del body con imágenes truncadas
    final bodyCopia = Map<String, dynamic>.from(body);

    // Truncar imágenes en el array de fotos
    if (bodyCopia.containsKey('fotos')) {
      final fotos = bodyCopia['fotos'] as List<dynamic>;
      bodyCopia['fotos'] = fotos.map((foto) {
        final fotoCopia = Map<String, dynamic>.from(
          foto as Map<String, dynamic>,
        );

        // Truncar imageBase64
        if (fotoCopia['imageBase64'] != null) {
          final base64 = fotoCopia['imageBase64'].toString();
          if (base64.length > 100) {
            fotoCopia['imageBase64'] =
                '${base64.substring(0, 100)}... [TRUNCADO - ${base64.length} caracteres totales]';
          }
        }

        return fotoCopia;
      }).toList();
    }

    final prettyJson = JsonEncoder.withIndent('  ').convert(bodyCopia);
    buffer.writeln(prettyJson);
  }
}

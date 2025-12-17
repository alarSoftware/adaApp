import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/config/app_config.dart';

import '../../config/constants/server_response.dart';
import '../censo/censo_upload_service.dart';

class CensoActivoPostService {
  static const String _tableName = 'censo_activo';
  static const String _endpoint = '/censoActivo/insertCensoActivo';
  static const Uuid _uuid = Uuid();

  static Future<void> enviarCensoActivo({
    String? censoId,
    String? equipoId,
    String? codigoBarras,
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    bool esNuevoEquipo = false,
    required int clienteId,
    required String edfVendedorId,
    bool crearPendiente = false,
    dynamic pendienteExistente,
    required int usuarioId,
    required double latitud,
    required double longitud,
    String? observaciones,
    bool enLocal = true,
    String? estadoCenso = 'pendiente',
    List<dynamic>? fotos,
    String? clienteNombre,
    String? marca,
    String? modelo,
    String? logo,
    int timeoutSegundos = 60,
    bool guardarLog = false,
    var equipoDataMap,
  }) async {
    String? fullUrl;

    try {
      final now = DateTime.now().toLocal();
      final censoIdFinal = censoId ?? now.millisecondsSinceEpoch.toString();

      if (censoId != null) {}

      final equipoIdFinal =
          equipoId ?? codigoBarras ?? 'EQUIPO_${censoIdFinal}';

      final payloadUnificado = _construirPayloadUnificado(
        equipoId: equipoIdFinal,
        codigoBarras: codigoBarras ?? equipoIdFinal,
        marcaId: marcaId,
        modeloId: modeloId,
        logoId: logoId,
        numeroSerie: numeroSerie,
        esNuevoEquipo: esNuevoEquipo,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        crearPendiente: crearPendiente,
        pendienteExistente: pendienteExistente,
        censoId: censoIdFinal,
        usuarioId: usuarioId,
        latitud: latitud,
        longitud: longitud,
        observaciones: observaciones,
        enLocal: enLocal,
        estadoCenso: estadoCenso,
        fotos: fotos,
        clienteNombre: clienteNombre,
        marca: marca,
        modelo: modelo,
        logo: logo,
        now: now,
        equipoDataMap: equipoDataMap,
      );

      final baseUrl = await ApiConfigService.getBaseUrl();
      fullUrl = '$baseUrl$_endpoint';

      if (guardarLog) {
        await _guardarLogSimple(
          url: fullUrl,
          payload: payloadUnificado,
          timestamp: now.toIso8601String(),
        );
      }

      final response = await http
          .post(
            Uri.parse(fullUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(payloadUnificado),
          )
          .timeout(Duration(seconds: timeoutSegundos));

      ServerResponse resultObject = ServerResponse.fromHttp(response);

      if (censoId == null) throw Exception("censoId es nulo");

      if (!resultObject.success) {
        if (!resultObject.isDuplicate && resultObject.message != '') {
          // final censoActivoRepository = CensoActivoRepository();
          // await censoActivoRepository.marcarComoError(censoId, resultObject.message);
          throw Exception(resultObject.message);
        }
      }
      if (resultObject.success || resultObject.isDuplicate) {
        final censoUploadService = CensoUploadService();
        final fotosSeguras = fotos ?? [];
        await censoUploadService.marcarComoSincronizadoCompleto(
          censoId: censoId,
          equipoId: equipoId,
          clienteId: clienteId,
          esNuevoEquipo: esNuevoEquipo,
          crearPendiente: crearPendiente,
          fotos: fotosSeguras,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _guardarLogSimple({
    required String url,
    required Map<String, dynamic> payload,
    required String timestamp,
  }) async {
    try {
      final file = await _obtenerArchivoLog();

      if (file == null) {
        return;
      }

      final contenido = _generarContenidoLogSimple(
        url: url,
        payload: payload,
        timestamp: timestamp,
        filePath: file.path,
      );

      await file.writeAsString(contenido);
    } catch (e) {
      rethrow;
    }
  }

  static String _generarContenidoLogSimple({
    required String url,
    required Map<String, dynamic> payload,
    required String timestamp,
    required String filePath,
  }) {
    final buffer = StringBuffer();
    final separador = '=' * 80;
    final divisor = '-' * 40;

    buffer.writeln(separador);
    buffer.writeln('CENSO ACTIVO - POST REQUEST LOG');
    buffer.writeln(separador);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('URL: $url');
    buffer.writeln('Archivo: $filePath');
    buffer.writeln('');

    buffer.writeln(divisor);
    buffer.writeln('HEADERS:');
    buffer.writeln(divisor);
    buffer.writeln('Content-Type: application/json');
    buffer.writeln('Accept: application/json');
    buffer.writeln('ngrok-skip-browser-warning: true');
    buffer.writeln('');

    buffer.writeln(divisor);
    buffer.writeln('RESUMEN DEL CENSO:');
    buffer.writeln(divisor);
    _agregarResumenSimple(buffer, payload);
    buffer.writeln('');

    buffer.writeln(divisor);
    buffer.writeln('REQUEST BODY (JSON):');
    buffer.writeln(divisor);
    _agregarBodyJson(buffer, payload);
    buffer.writeln('');

    buffer.writeln(separador);
    buffer.writeln('FIN DEL LOG - ${DateTime.now().toLocal()}');
    buffer.writeln(separador);

    return buffer.toString();
  }

  static void _agregarResumenSimple(
    StringBuffer buffer,
    Map<String, dynamic> payload,
  ) {
    final censo = payload['censo_activo'] != null
        ? Map<String, dynamic>.from(payload['censo_activo'] as Map)
        : null;
    final equipo = payload['equipo'] != null
        ? Map<String, dynamic>.from(payload['equipo'] as Map)
        : null;
    final pendiente = payload['equipo_pendiente'] != null
        ? Map<String, dynamic>.from(payload['equipo_pendiente'] as Map)
        : null;

    if (censo != null && censo.isNotEmpty) {
      buffer.writeln('Equipo ID: ${censo['edfEquipoId'] ?? 'N/A'}');
      buffer.writeln('Cliente ID: ${censo['edfClienteId'] ?? 'N/A'}');
      buffer.writeln('Usuario ID: ${censo['usuarioId'] ?? 'N/A'}');
      buffer.writeln('Latitud: ${censo['latitud'] ?? 'N/A'}');
      buffer.writeln('Longitud: ${censo['longitud'] ?? 'N/A'}');
    }

    final equipoCompleto = equipo != null && equipo.isNotEmpty;
    final pendienteCompleto = pendiente != null && pendiente.isNotEmpty;

    buffer.writeln(
      'Sección equipo: ${equipoCompleto ? 'COMPLETA (nuevo equipo)' : 'VACÍA (equipo existente)'}',
    );
    buffer.writeln(
      'Sección equipo_pendiente: ${pendienteCompleto ? 'COMPLETA (crear asignación)' : 'VACÍA (ya asignado)'}',
    );

    if (pendienteCompleto && pendiente != null) {
      buffer.writeln(
        'UUID Pendiente (BD): ${pendiente['uuid'] ?? 'NO DISPONIBLE'}',
      );
    }

    buffer.writeln('Sección censo_activo: COMPLETA (siempre)');

    if (censo != null && censo.isNotEmpty) {
      final fotosArray = censo['fotos'] as List<dynamic>?;
      final totalFotos = fotosArray?.length ?? 0;
      final tieneImagen1 = censo['tieneImagen'] == true;
      final tieneImagen2 = censo['tieneImagen2'] == true;

      buffer.writeln('Tiene imagen 1: $tieneImagen1');
      buffer.writeln('Tiene imagen 2: $tieneImagen2');
      buffer.writeln('Total fotos: $totalFotos');

      if (censo['imageBase64_1'] != null) {
        final tamano1 = censo['imageBase64_1'].toString().length;
        buffer.writeln(
          'Tamaño imagen 1: ${(tamano1 / 1024).toStringAsFixed(1)} KB',
        );
      }
      if (censo['imageBase64_2'] != null) {
        final tamano2 = censo['imageBase64_2'].toString().length;
        buffer.writeln(
          'Tamaño imagen 2: ${(tamano2 / 1024).toStringAsFixed(1)} KB',
        );
      }

      buffer.writeln('Observaciones: ${censo['observaciones'] ?? 'N/A'}');
      buffer.writeln('Estado censo: ${censo['estadoCenso'] ?? 'N/A'}');
      buffer.writeln('Fecha revisión: ${censo['fechaRevision'] ?? 'N/A'}');
    }
  }

  static void _agregarBodyJson(
    StringBuffer buffer,
    Map<String, dynamic> payload,
  ) {
    final payloadSimplificado = Map<String, dynamic>.from(payload);

    if (payloadSimplificado.containsKey('censo_activo')) {
      final censo = Map<String, dynamic>.from(
        payloadSimplificado['censo_activo'],
      );

      if (censo.containsKey('imageBase64_1')) {
        final tamano1 = censo['imageBase64_1']?.toString().length ?? 0;
        censo['imageBase64_1'] =
            '[BASE64 - ${(tamano1 / 1024).toStringAsFixed(1)} KB]';
      }
      if (censo.containsKey('imageBase64_2')) {
        final tamano2 = censo['imageBase64_2']?.toString().length ?? 0;
        censo['imageBase64_2'] =
            '[BASE64 - ${(tamano2 / 1024).toStringAsFixed(1)} KB]';
      }

      if (censo.containsKey('fotos') && censo['fotos'] is List) {
        final fotosCount = (censo['fotos'] as List).length;
        censo['fotos'] = '[${fotosCount} fotos - contenido omitido del log]';
      }

      payloadSimplificado['censo_activo'] = censo;
    }

    final prettyJson = JsonEncoder.withIndent(
      '  ',
    ).convert(payloadSimplificado);
    buffer.writeln(prettyJson);
  }

  static Future<File?> _obtenerArchivoLog() async {
    try {
      final downloadsDir = await _obtenerDirectorioDescargas();

      if (downloadsDir == null) {
        return null;
      }

      if (!await downloadsDir.exists()) {}

      final now = DateTime.now();
      final fechaFormateada =
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}_'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = 'censo_activo_post_$fechaFormateada.txt';
      final filePath = '${downloadsDir.path}/$fileName';

      return File(filePath);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Directory?> _obtenerDirectorioDescargas() async {
    try {
      if (Platform.isAndroid) {
        var downloadsDir = Directory('/storage/emulated/0/Download');

        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();

          downloadsDir = Directory('${externalDir?.path}/Download');
        } else {}

        return downloadsDir;
      } else if (Platform.isIOS) {
        final appDocDir = await getApplicationDocumentsDirectory();

        return appDocDir;
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Map<String, dynamic> _construirPayloadUnificado({
    required String equipoId,
    required String codigoBarras,
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    required bool esNuevoEquipo,
    required int clienteId,
    required String edfVendedorId,
    required bool crearPendiente,
    dynamic pendienteExistente,
    required String censoId,
    required int usuarioId,
    required double latitud,
    required double longitud,
    String? observaciones,
    required bool enLocal,
    String? estadoCenso,
    List<dynamic>? fotos,
    String? clienteNombre,
    String? marca,
    String? modelo,
    String? logo,
    required DateTime now,
    var equipoDataMap,
  }) {
    final Map<String, dynamic> payload = {};
    try {
      if (esNuevoEquipo &&
          marcaId != null &&
          modeloId != null &&
          logoId != null) {
        payload['equipo'] = _construirJsonEquipo(equipoDataMap);
      } else {
        payload['equipo'] = {};
      }

      if (pendienteExistente != null &&
          (pendienteExistente is List && pendienteExistente.isNotEmpty)) {
        payload['equipo_pendiente'] = _construirJsonEquipoPendiente(
          pendienteExistente,
        );
      } else {
        payload['equipo_pendiente'] = {};
      }

      payload['censo_activo'] = _construirJsonCensoActivo(
        censoId: censoId,
        equipoId: equipoId,
        clienteId: clienteId,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId,
        latitud: latitud,
        longitud: longitud,
        observaciones: observaciones,
        enLocal: enLocal,
        estadoCenso: estadoCenso ?? 'pendiente',
        fotos: fotos,
        codigoBarras: codigoBarras,
        numeroSerie: numeroSerie,
        marca: marca,
        modelo: modelo,
        logo: logo,
        clienteNombre: clienteNombre,
        now: now,
        esNuevoEquipo: esNuevoEquipo,
      );
    } catch (e) {
      rethrow;
    }
    return payload;
  }

  static Map<String, dynamic> _construirJsonEquipo(var equipoDataMap) {
    final now = DateTime.now().toIso8601String();
    var id = equipoDataMap['id'];
    var edfEquipoId = equipoDataMap['cod_barras'];
    var codigoBarras = equipoDataMap['cod_barras'];
    var modeloId = equipoDataMap['modelo_id'];
    var marcaId = equipoDataMap['marca_id'];
    var logoId = equipoDataMap['logo_id'];
    var numeroSerie = equipoDataMap['numero_serie'];

    return {
      'id': id,
      'edfEquipoId': edfEquipoId,
      'codigoBarras': codigoBarras,
      'edfModeloId': modeloId,
      'marcaId': marcaId.toString(),
      'logoId': logoId.toString(),
      'serie': numeroSerie ?? '',
      'fechaCreacion': now,
    };
  }

  static Map<String, dynamic> _construirJsonEquipoPendiente(
    dynamic pendienteExistenteList,
  ) {
    var pendienteExistente = pendienteExistenteList[0];
    String id = pendienteExistente['id'];
    var edfVendedorId = pendienteExistente['edf_vendedor_id'];
    var equipoId = pendienteExistente['equipo_id'];
    var codigoBarras = pendienteExistente['codigo_barras'];
    var clienteId = pendienteExistente['cliente_id'];
    var numeroSerie = pendienteExistente['numero_serie'];
    var estado = pendienteExistente['estado'];
    var marcaId = pendienteExistente['marca_id'];
    var modeloId = pendienteExistente['modelo_id'];
    var logoId = pendienteExistente['logo_id'];
    final partes = edfVendedorId.split('_');
    final vendedorIdValue = partes.isNotEmpty ? partes[0] : edfVendedorId;
    int? sucursalIdValue;
    if (partes.length > 1) {
      sucursalIdValue = int.tryParse(partes[1]);
    }

    final Map<String, dynamic> pendiente = {
      'edfEquipoId': equipoId,
      'edfCodigoBarras': codigoBarras,
      'edfClienteId': clienteId.toString(),
      'id': id,
      'estado': estado,
      'edfVendedorSucursalId': edfVendedorId,
      'edfVendedorId': vendedorIdValue,
      'edfSerie': numeroSerie,
      'edfMarcaId': marcaId?.toString(),
      'edfModeloId': modeloId,
      'edfLogoId': logoId,
    };

    if (sucursalIdValue != null) {
      pendiente['edfSucursalId'] = sucursalIdValue;
    }

    return pendiente;
  }

  static Map<String, dynamic> _construirJsonCensoActivo({
    required String censoId,
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required String edfVendedorId,
    required double latitud,
    required double longitud,
    String? observaciones,
    required bool enLocal,
    required String estadoCenso,
    List<dynamic>? fotos,
    String? codigoBarras,
    String? numeroSerie,
    String? marca,
    String? modelo,
    String? logo,
    String? clienteNombre,
    required DateTime now,
    required bool esNuevoEquipo,
  }) {
    String formatearFechaLocal(DateTime fecha) {
      final local = fecha.toLocal();
      return local.toIso8601String().replaceAll('Z', '');
    }

    final censo = {
      'id': censoId,
      'edfVendedorSucursalId': edfVendedorId,
      'edfEquipoId': equipoId,
      'usuarioId': usuarioId,
      'edfClienteId': clienteId,
      'fechaRevision': formatearFechaLocal(now),
      'latitud': latitud,
      'longitud': longitud,
      'enLocal': enLocal,
      'fechaDeRevision': formatearFechaLocal(now),
      'estadoCenso': estadoCenso,
      'esNuevoEquipo': esNuevoEquipo,
      'equipoCodigoBarras': codigoBarras,
      'equipoNumeroSerie': numeroSerie ?? '',
      'equipoModelo': modelo ?? '',
      'equipoMarca': marca ?? '',
      'equipoLogo': logo ?? '',
      'equipoId': equipoId,
      'clienteNombre': clienteNombre ?? '',
      'clienteId': clienteId,
      'usuarioId': usuarioId,
      'observaciones': observaciones ?? '',
      'estadoGeneral': observaciones ?? 'Registro desde APP móvil',
      'enLocal': enLocal,
      'dispositivo': 'android',
      'esCenso': true,
      'versionApp': AppConfig.currentAppVersion,
    };

    if (fotos != null && fotos.isNotEmpty) {
      censo['fotos'] = fotos;
      censo['totalImagenes'] = fotos.length;

      for (int i = 0; i < fotos.length && i < 2; i++) {
        final foto = fotos[i];
        if (foto is Map<String, dynamic>) {
          if (i == 0) {
            censo['imageBase64_1'] = foto['base64'];
            censo['tieneImagen'] = true;
          } else if (i == 1) {
            censo['imageBase64_2'] = foto['base64'];
            censo['tieneImagen2'] = true;
          }
        }
      }
    } else {
      censo['fotos'] = [];
      censo['totalImagenes'] = 0;
      censo['tieneImagen'] = false;
      censo['tieneImagen2'] = false;
    }

    return censo;
  }

  static Future<Map<String, dynamic>> enviarCambioEstado({
    required String codigoBarras,
    required int clienteId,
    required bool enLocal,
    required dynamic position, // Geolocator Position
    String? observaciones,
    required String equipoId,
    required String clienteNombre,
    required String numeroSerie,
    required String modelo,
    required String marca,
    required String logo,
    required int usuarioId,
    required String edfVendedorId,
  }) async {
    try {
      await enviarCensoActivo(
        censoId: DateTime.now().millisecondsSinceEpoch.toString(),
        equipoId: equipoId,
        codigoBarras: codigoBarras,
        clienteId: clienteId,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId,
        latitud: position.latitude,
        longitud: position.longitude,
        observaciones: observaciones,
        enLocal: enLocal,
        estadoCenso: 'migrado', // Se asume migrado si se envía directo
        esNuevoEquipo: false,
        crearPendiente: false,
        clienteNombre: clienteNombre,
        numeroSerie: numeroSerie,
        modelo: modelo,
        marca: marca,
        logo: logo,
        guardarLog: true,
      );

      return {'exito': true, 'mensaje': 'Estado actualizado correctamente'};
    } catch (e) {
      return {
        'exito': false,
        'mensaje': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

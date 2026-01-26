import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/config/app_config.dart';

import '../../config/constants/server_response.dart';
import '../censo/censo_upload_service.dart';
import 'package:ada_app/services/network/monitored_http_client.dart';

/// Formatea DateTime sin 'T' ni 'Z' para el backend
/// Formato: "yyyy-MM-dd HH:mm:ss.SSSSSS"
String _formatTimestampForBackend(DateTime dt) {
  String year = dt.year.toString().padLeft(4, '0');
  String month = dt.month.toString().padLeft(2, '0');
  String day = dt.day.toString().padLeft(2, '0');
  String hour = dt.hour.toString().padLeft(2, '0');
  String minute = dt.minute.toString().padLeft(2, '0');
  String second = dt.second.toString().padLeft(2, '0');
  String microsecond = dt.microsecond.toString().padLeft(6, '0');

  return '$year-$month-$day $hour:$minute:$second.$microsecond';
}

class CensoActivoPostService {
  static const String _endpoint = '/censoActivo/insertCensoActivo';

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
    required String employeeId,
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

    var equipoDataMap,
  }) async {
    String? fullUrl;

    try {
      final now = DateTime.now();
      final censoIdFinal = censoId.toString();

      if (censoId != null) {}

      final equipoIdFinal = equipoId ?? codigoBarras ?? 'EQUIPO_$censoIdFinal';

      final payloadUnificado = _construirPayloadUnificado(
        equipoId: equipoIdFinal,
        codigoBarras: codigoBarras ?? equipoIdFinal,
        marcaId: marcaId,
        modeloId: modeloId,
        logoId: logoId,
        numeroSerie: numeroSerie,
        esNuevoEquipo: esNuevoEquipo,
        clienteId: clienteId,
        employeeId: employeeId,
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

      final jsonBody = jsonEncode(payloadUnificado);
      debugPrint('DEBUG CENSO TIMESTAMP - Payload: $jsonBody');

      final response = await MonitoredHttpClient.post(
        url: Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonBody,
        timeout: Duration(seconds: timeoutSegundos),
      );

      ServerResponse resultObject = ServerResponse.fromHttp(response);

      if (censoId == null) throw Exception("censoId es nulo");

      if (!resultObject.success) {
        if (!resultObject.isDuplicate && resultObject.message != '') {
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

  static Map<String, dynamic> _construirPayloadUnificado({
    required String equipoId,
    required String codigoBarras,
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    required bool esNuevoEquipo,
    required int clienteId,
    required String employeeId,
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
        payload['equipo'] = _construirJsonEquipo(equipoDataMap, now);
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
        employeeId: employeeId,
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

  static Map<String, dynamic> _construirJsonEquipo(
    var equipoDataMap,
    DateTime now,
  ) {
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
      'fechaCreacion': _formatTimestampForBackend(now),
    };
  }

  static Map<String, dynamic> _construirJsonEquipoPendiente(
    dynamic pendienteExistenteList,
  ) {
    var pendienteExistente = pendienteExistenteList[0];
    String id = pendienteExistente['id'];
    var employeeId = pendienteExistente['employee_id'];
    var equipoId = pendienteExistente['equipo_id'];
    var codigoBarras = pendienteExistente['codigo_barras'];
    var clienteId = pendienteExistente['cliente_id'];
    var numeroSerie = pendienteExistente['numero_serie'];
    var estado = pendienteExistente['estado'];
    var marcaId = pendienteExistente['marca_id'];
    var modeloId = pendienteExistente['modelo_id'];
    var logoId = pendienteExistente['logo_id'];
    final partes = employeeId.split('_');
    final vendedorIdValue = partes.isNotEmpty ? partes[0] : employeeId;
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
      'edfVendedorSucursalId': employeeId,
      'employeeId': vendedorIdValue,
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
    required String employeeId,
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
    final censo = {
      'id': censoId,
      'edfVendedorSucursalId': employeeId,
      'employeeId': employeeId, // Añadido para consistencia
      'edfEquipoId': equipoId,
      'usuarioId': usuarioId,
      'fechaRevision': _formatTimestampForBackend(now),
      'latitud': latitud,
      'longitud': longitud,
      'enLocal': enLocal,
      'fechaDeRevision': _formatTimestampForBackend(now),
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
      'observaciones': observaciones ?? '',
      'estadoGeneral': observaciones ?? 'Registro desde APP móvil',
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
}

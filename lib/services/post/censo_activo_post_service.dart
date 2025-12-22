import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:uuid/uuid.dart';

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
      final now = DateTime.now().toLocal();
      final censoIdFinal = censoId.toString();

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
    String formatearFechaLocal(DateTime fecha) {
      final local = fecha.toLocal();
      return local.toIso8601String().replaceAll('Z', '');
    }

    final censo = {
      'id': censoId,
      'edfVendedorSucursalId': employeeId,
      'employeeId': employeeId, // Añadido para consistencia
      'edfEquipoId': equipoId,
      'usuarioId': usuarioId,
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
    required String employeeId,
    String? censoId, // Nuevo parámetro opcional
  }) async {
    try {
      await enviarCensoActivo(
        censoId:
            censoId ??
            DateTime.now().millisecondsSinceEpoch
                .toString(), // Usa el ID pasado o genera uno nuevo
        equipoId: equipoId,
        codigoBarras: codigoBarras,
        clienteId: clienteId,
        usuarioId: usuarioId,
        employeeId: employeeId,
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

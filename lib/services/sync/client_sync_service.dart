import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';
import 'package:ada_app/models/cliente.dart';

class ClientSyncService {
  static final _clienteRepo = ClienteRepository();

  static Future<SyncResult> sincronizarClientesDelUsuario() async {
    try {
      BaseSyncService.logger.i('Iniciando sincronización de clientes del usuario...');

      // Obtener el edf_vendedor_id del usuario actual
      final edfVendedorId = await UserSyncService.obtenerEdfVendedorIdUsuarioActual();

      if (edfVendedorId == null || edfVendedorId.trim().isEmpty) {
        BaseSyncService.logger.w('Usuario actual no tiene edf_vendedor_id - NO sincronizando clientes');
        return SyncResult(
          exito: true,
          mensaje: 'Usuario sin clientes asignados - omitiendo sincronización de clientes',
          itemsSincronizados: 0,
        );
      }

      BaseSyncService.logger.i('edf_vendedor_id obtenido: $edfVendedorId');

      // Llamar al método con el ID obtenido
      return await sincronizarClientesPorVendedor(edfVendedorId);

    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo datos del usuario: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error obteniendo datos del usuario: $e',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarClientesPorVendedor(String edfVendedorId) async {
    try {
      BaseSyncService.logger.i('Sincronizando clientes para vendedor: $edfVendedorId');

      final url = '${BaseSyncService.baseUrl}/api/getEdfClientes?edfvendedorId=$edfVendedorId';
      BaseSyncService.logger.i('URL completa: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('Respuesta del servidor: ${response.statusCode}');
      BaseSyncService.logger.i('Contenido respuesta: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesData = BaseSyncService.parseResponse(response.body);

        BaseSyncService.logger.i('Datos parseados: ${clientesData.length} clientes del servidor');

        if (clientesData.isEmpty) {
          BaseSyncService.logger.w('No se encontraron clientes para el vendedor $edfVendedorId');
          return SyncResult(
            exito: true,
            mensaje: 'No se encontraron clientes para este vendedor',
            itemsSincronizados: 0,
          );
        }

        final clientes = <Cliente>[];
        int procesados = 0;
        int fallidos = 0;

        for (var clienteJson in clientesData) {
          procesados++;
          final cliente = _crearClienteDesdeAPI(clienteJson);
          if (cliente != null) {
            clientes.add(cliente);
            BaseSyncService.logger.d('Cliente procesado: ${cliente.nombre}');
          } else {
            fallidos++;
            BaseSyncService.logger.w('Cliente fallido: $clienteJson');
          }
        }

        BaseSyncService.logger.i('Procesamiento: $procesados total, ${clientes.length} exitosos, $fallidos fallidos');

        if (clientes.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar los clientes del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('Guardando ${clientes.length} clientes en base de datos...');

        // CORREGIDO: Usar limpiarYSincronizar con los mapas directos de los clientes
        final clientesMapas = clientes.map((cliente) => cliente.toMap()).toList();
        await _clienteRepo.limpiarYSincronizar(clientesMapas);

        BaseSyncService.logger.i('Clientes sincronizados exitosamente');

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientes.length,
          totalEnAPI: clientes.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error en sincronización de clientes: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Cliente? _crearClienteDesdeAPI(dynamic clienteJson) {
    try {
      if (clienteJson is! Map<String, dynamic>) {
        return null;
      }

      final data = clienteJson;

      if (data['cliente'] == null || data['cliente'].toString().trim().isEmpty) {
        return null;
      }

      // Obtener RUC/CI (prioritario RUC, luego cedula)
      String rucCi = '';
      if (data['ruc'] != null && data['ruc'].toString().trim().isNotEmpty) {
        rucCi = data['ruc'].toString().trim();
      } else if (data['cedula'] != null && data['cedula'].toString().trim().isNotEmpty) {
        rucCi = data['cedula'].toString().trim();
      }

      // Convertir clienteIdGc a int para el campo codigo
      int codigo = 0;
      if (data['clienteIdGc'] != null) {
        final clienteIdGcStr = data['clienteIdGc'].toString().trim();
        codigo = int.tryParse(clienteIdGcStr) ?? 0;
      }

      return Cliente(
        id: data['id'] is int ? data['id'] : null,
        nombre: data['cliente'].toString().trim(),
        codigo: codigo, // ← Usar clienteIdGc convertido a int
        telefono: data['telefono']?.toString().trim() ?? '',
        direccion: data['direccion']?.toString().trim() ?? '',
        rucCi: rucCi,
        propietario: data['propietario']?.toString().trim() ?? '',
      );
    } catch (e) {
      BaseSyncService.logger.e('Error creando cliente desde API: $e');
      return null;
    }
  }

  // MÉTODO SIMPLIFICADO - Ya no usa sincronización de auditoría
  static Future<SyncResult> enviarClientesPendientes() async {
    try {
      BaseSyncService.logger.i('Verificando clientes pendientes por enviar...');

      // Como la tabla clientes no tiene columna sincronizado,
      // este método podría simplemente retornar que no hay pendientes
      // O implementar otra lógica según tus necesidades de negocio

      return SyncResult(
        exito: true,
        mensaje: 'Tabla clientes no maneja estado de sincronización - todos los clientes se consideran sincronizados',
        itemsSincronizados: 0,
      );

    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  // MÉTODO ALTERNATIVO: Si necesitas enviar clientes específicos
  static Future<SyncResult> enviarClienteEspecifico(Cliente cliente) async {
    try {
      final resultado = await _enviarClienteAAPI(cliente);

      if (resultado.exito) {
        return SyncResult(
          exito: true,
          mensaje: 'Cliente enviado correctamente',
          itemsSincronizados: 1,
        );
      } else {
        return SyncResult(
          exito: false,
          mensaje: resultado.mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error enviando cliente: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<ApiResponse> _enviarClienteAAPI(Cliente cliente) async {
    try {
      final clienteData = {
        'cliente': cliente.nombre,
        'telefono': cliente.telefono,
        'direccion': cliente.direccion,
        'ruc': cliente.rucCi,
        'propietario': cliente.propietario,
      };

      final response = await http.post(
        Uri.parse('${BaseSyncService.baseUrl}/api/getEdfClientes'),
        headers: BaseSyncService.headers,
        body: jsonEncode(clienteData),
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? parsedData;

        try {
          if (response.body.trim().isNotEmpty) {
            parsedData = jsonDecode(response.body);
          }
        } catch (e) {
          BaseSyncService.logger.w('No se pudo parsear la respuesta JSON: $e');
        }

        return ApiResponse(
          exito: true,
          mensaje: 'Cliente enviado correctamente al servidor',
          datos: parsedData,
          codigoEstado: response.statusCode,
        );
      } else {
        final mensajeError = BaseSyncService.extractErrorMessage(response);

        return ApiResponse(
          exito: false,
          mensaje: mensajeError,
          codigoEstado: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
      );
    }
  }
}
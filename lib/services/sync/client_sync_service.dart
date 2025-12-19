import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class ClientSyncService {
  static final _clienteRepo = ClienteRepository();

  static Future<String> _getClientesUrl(String employeeId) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    return '$baseUrl/api/getEdfClientes?employeeId=$employeeId';
  }

  static Future<SyncResult> sincronizarClientesDelUsuario() async {
    try {
      final employeeId = await UserSyncService.obtenerEmployeeIdUsuarioActual();

      if (employeeId == null || employeeId.trim().isEmpty) {
        return SyncResult(
          exito: true,
          mensaje:
              'Usuario sin clientes asignados - omitiendo sincronización de clientes',
          itemsSincronizados: 0,
        );
      }

      return await sincronizarClientesPorVendedor(employeeId);
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'clientes',
        operation: 'get_user_data',
        errorMessage: 'Error obteniendo datos del usuario: $e',
        errorType: 'validation',
      );

      return SyncResult(
        exito: false,
        mensaje: 'Error obteniendo datos del usuario: $e',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarClientesPorVendedor(
    String employeeId,
  ) async {
    String? currentEndpoint;

    try {
      final url = await _getClientesUrl(employeeId);
      currentEndpoint = url;

      final response = await http
          .get(Uri.parse(url), headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesData = BaseSyncService.parseResponse(
          response.body,
        );

        if (clientesData.isEmpty) {
          // CORRECCIÓN: Si el servidor devuelve una lista vacía, debemos limpiar la tabla local
          try {
            await _clienteRepo.limpiarYSincronizar([]);
          } catch (dbError) {
            print('Error al limpiar clientes: $dbError');
          }

          return SyncResult(
            exito: true,
            mensaje:
                'No se encontraron clientes para este vendedor (Tabla local limpiada)',
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
          } else {
            fallidos++;
          }
        }

        if (clientes.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar los clientes del servidor',
            itemsSincronizados: 0,
          );
        }

        try {
          final clientesMapas = clientes
              .map((cliente) => cliente.toMap())
              .toList();
          await _clienteRepo.limpiarYSincronizar(clientesMapas);
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'clientes',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando clientes en BD local: $dbError',
          );
        }

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientes.length,
          totalEnAPI: clientes.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } on TimeoutException catch (timeoutError) {
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
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

      if (data['cliente'] == null ||
          data['cliente'].toString().trim().isEmpty) {
        return null;
      }

      String rucCi = '';
      if (data['ruc'] != null && data['ruc'].toString().trim().isNotEmpty) {
        rucCi = data['ruc'].toString().trim();
      } else if (data['cedula'] != null &&
          data['cedula'].toString().trim().isNotEmpty) {
        rucCi = data['cedula'].toString().trim();
      }

      int codigo = 0;
      if (data['clienteIdGc'] != null) {
        final clienteIdGcStr = data['clienteIdGc'].toString().trim();
        codigo = int.tryParse(clienteIdGcStr) ?? 0;
      }

      return Cliente(
        id: data['id'] is int ? data['id'] : null,
        nombre: data['cliente'].toString().trim(),
        codigo: codigo,
        telefono: data['telefono']?.toString().trim() ?? '',
        direccion: data['direccion']?.toString().trim() ?? '',
        rucCi: rucCi,
        propietario: data['propietario']?.toString().trim() ?? '',
        condicionVenta: data['terminoPago']?.toString().trim(),
      );
    } catch (e) {
      return null;
    }
  }
}

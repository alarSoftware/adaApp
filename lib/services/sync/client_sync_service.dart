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

      // 🚨 LOG ERROR: Error obteniendo datos del usuario
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

  static Future<SyncResult> sincronizarClientesPorVendedor(String edfVendedorId) async {
    String? currentEndpoint;

    try {
      BaseSyncService.logger.i('Sincronizando clientes para vendedor: $edfVendedorId');

      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/api/getEdfClientes?edfvendedorId=$edfVendedorId';
      currentEndpoint = url;
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

            // 🚨 LOG ERROR: Cliente con datos inválidos
            // await ErrorLogService.logValidationError(
            //   tableName: 'clientes',
            //   operation: 'process_item',
            //   errorMessage: 'Cliente con datos inválidos o faltantes',
            //   userId: edfVendedorId,
            // );
          }
        }

        BaseSyncService.logger.i('Procesamiento: $procesados total, ${clientes.length} exitosos, $fallidos fallidos');

        if (clientes.isEmpty) {
          // 🚨 LOG ERROR: No se pudieron procesar clientes
          // await ErrorLogService.logError(
          //   tableName: 'clientes',
          //   operation: 'process_all',
          //   errorMessage: 'No se pudieron procesar los clientes del servidor',
          //   errorType: 'validation',
          //   userId: edfVendedorId,
          // );

          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar los clientes del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('Guardando ${clientes.length} clientes en base de datos...');

        try {
          final clientesMapas = clientes.map((cliente) => cliente.toMap()).toList();
          await _clienteRepo.limpiarYSincronizar(clientesMapas);
          BaseSyncService.logger.i('Clientes sincronizados exitosamente');
        } catch (dbError) {
          BaseSyncService.logger.e('Error guardando clientes en BD: $dbError');

          // 🚨 LOG ERROR: Error de base de datos
          await ErrorLogService.logDatabaseError(
            tableName: 'clientes',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando clientes en BD local: $dbError',
          );

          // No retornar error, los datos se obtuvieron correctamente
        }

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientes.length,
          totalEnAPI: clientes.length,
        );

      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('Error del servidor: $mensaje');

        // 🚨 LOG ERROR: Error del servidor
        // await ErrorLogService.logServerError(
        //   tableName: 'clientes',
        //   operation: 'sync_from_server',
        //   errorMessage: mensaje,
        //   errorCode: response.statusCode.toString(),
        //   endpoint: currentEndpoint,
        //   userId: edfVendedorId,
        // );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      BaseSyncService.logger.e('⏰ Timeout sincronizando clientes: $timeoutError');

      // 🚨 LOG ERROR: Timeout
      // await ErrorLogService.logNetworkError(
      //   tableName: 'clientes',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Timeout de conexión: $timeoutError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      BaseSyncService.logger.e('📡 Error de red: $socketError');

      // 🚨 LOG ERROR: Sin conexión de red
      // await ErrorLogService.logNetworkError(
      //   tableName: 'clientes',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Sin conexión de red: $socketError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronización de clientes: $e');

      // 🚨 LOG ERROR: Error general
      // await ErrorLogService.logError(
      //   tableName: 'clientes',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Error general: $e',
      //   errorType: 'unknown',
      //   errorCode: 'GENERAL_ERROR',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

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

      String rucCi = '';
      if (data['ruc'] != null && data['ruc'].toString().trim().isNotEmpty) {
        rucCi = data['ruc'].toString().trim();
      } else if (data['cedula'] != null && data['cedula'].toString().trim().isNotEmpty) {
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
      );
    } catch (e) {
      BaseSyncService.logger.e('Error creando cliente desde API: $e');
      return null;
    }
  }

  static Future<SyncResult> enviarClientesPendientes() async {
    try {
      BaseSyncService.logger.i('Verificando clientes pendientes por enviar...');

      return SyncResult(
        exito: true,
        mensaje: 'Tabla clientes no maneja estado de sincronización - todos los clientes se consideran sincronizados',
        itemsSincronizados: 0,
      );

    } catch (e) {
      // 🚨 LOG ERROR: Error en envío
      await ErrorLogService.logError(
        tableName: 'clientes',
        operation: 'enviar_pendientes',
        errorMessage: 'Error inesperado: $e',
        errorType: 'unknown',
      );

      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> enviarClienteEspecifico(Cliente cliente) async {
    String? currentEndpoint;

    try {
      final resultado = await _enviarClienteAAPI(cliente);

      if (resultado.exito) {
        return SyncResult(
          exito: true,
          mensaje: 'Cliente enviado correctamente',
          itemsSincronizados: 1,
        );
      } else {
        // 🚨 LOG ERROR: Error enviando cliente
        await ErrorLogService.logServerError(
          tableName: 'clientes',
          operation: 'enviar_cliente',
          errorMessage: resultado.mensaje,
          errorCode: resultado.codigoEstado?.toString() ?? 'UNKNOWN',
          registroFailId: cliente.id?.toString(),
        );

        return SyncResult(
          exito: false,
          mensaje: resultado.mensaje,
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'clientes',
        operation: 'enviar_cliente',
        errorMessage: 'Timeout: $timeoutError',
        registroFailId: cliente.id?.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'clientes',
        operation: 'enviar_cliente',
        errorMessage: 'Sin conexión: $socketError',
        registroFailId: cliente.id?.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'clientes',
        operation: 'enviar_cliente',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        registroFailId: cliente.id?.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: 'Error enviando cliente: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<ApiResponse> _enviarClienteAAPI(Cliente cliente) async {
    String? currentEndpoint;

    try {
      final clienteData = {
        'cliente': cliente.nombre,
        'telefono': cliente.telefono,
        'direccion': cliente.direccion,
        'ruc': cliente.rucCi,
        'propietario': cliente.propietario,
      };

      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getEdfClientes';

      final response = await http.post(
        Uri.parse(currentEndpoint),
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
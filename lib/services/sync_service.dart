import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/cliente.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'dart:async';
import 'package:logger/logger.dart';

var logger = Logger();

class SyncService {
  // ⚠️ ACTUALIZAr con la IP correcta del servidor.
  static const String baseUrl = 'http://192.168.100.128:3000';
  static const String clientesEndpoint = '$baseUrl/clientes';
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  // Sincronizar todos los datos desde la API a la base de datos local
  static Future<SyncResult> sincronizarConAPI() async {
    try {
      logger.i('🔄 Iniciando sincronización con API...');

      // Obtener todos los clientes de la API (sin límite)
      final response = await http.get(
        Uri.parse('$clientesEndpoint?limit=1000'), // Límite alto para obtener todos
        headers: _headers,
      ).timeout(timeout);

      logger.i('📡 Respuesta de API - Status: ${response.statusCode}');
      logger.i('📡 Respuesta de API - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseBody = response.body.trim();

          // Manejar diferentes formatos de respuesta del servidor Node.js
          List<Cliente> clientesAPI = [];

          if (responseBody.startsWith('[')) {
            // Si la respuesta es un array directo
            final List<dynamic> clientesJson = jsonDecode(responseBody);
            clientesAPI = clientesJson
                .map((clienteJson) => _crearClienteDesdeAPI(clienteJson))
                .where((cliente) => cliente != null)
                .cast<Cliente>()
                .toList();
          } else {
            // Si la respuesta es un objeto
            final Map<String, dynamic> responseData = jsonDecode(responseBody);

            if (responseData.containsKey('clientes') && responseData['clientes'] is List) {
              clientesAPI = (responseData['clientes'] as List)
                  .map((clienteJson) => _crearClienteDesdeAPI(clienteJson))
                  .where((cliente) => cliente != null)
                  .cast<Cliente>()
                  .toList();
            } else if (responseData.containsKey('data') && responseData['data'] is List) {
              clientesAPI = (responseData['data'] as List)
                  .map((clienteJson) => _crearClienteDesdeAPI(clienteJson))
                  .where((cliente) => cliente != null)
                  .cast<Cliente>()
                  .toList();
            }
          }

          logger.i('📥 Clientes obtenidos de API: ${clientesAPI.length}');

          if (clientesAPI.isEmpty) {
            return SyncResult(
              exito: false,
              mensaje: 'No se encontraron clientes en la API',
              clientesSincronizados: 0,
            );
          }

          // Limpiar base de datos local y insertar nuevos datos
          final dbHelper = DatabaseHelper();
          await dbHelper.limpiarYSincronizar(clientesAPI);

          int clientesInsertados = clientesAPI.length;

          logger.i('✅ Sincronización completada: $clientesInsertados clientes guardados');

          return SyncResult(
            exito: true,
            mensaje: 'Sincronización exitosa',
            clientesSincronizados: clientesInsertados,
            totalEnAPI: clientesAPI.length,
          );

        } catch (e) {
          logger.e('❌ Error procesando datos de API: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error procesando datos de la API: ${e.toString()}',
            clientesSincronizados: 0,
          );
        }
      } else {
        String mensajeError;
        try {
          Map<String, dynamic> errorData = jsonDecode(response.body);
          mensajeError = errorData['message'] ??
              errorData['error'] ??
              'Error del servidor (${response.statusCode})';
        } catch (e) {
          mensajeError = 'Error del servidor (${response.statusCode})';
        }

        return SyncResult(
          exito: false,
          mensaje: mensajeError,
          clientesSincronizados: 0,
        );
      }

    } on SocketException {
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión a internet o servidor no disponible',
        clientesSincronizados: 0,
      );
    } on TimeoutException {
      return SyncResult(
        exito: false,
        mensaje: 'Tiempo de espera agotado (30 segundos)',
        clientesSincronizados: 0,
      );
    } on HttpException {
      return SyncResult(
        exito: false,
        mensaje: 'Error en la comunicación con el servidor',
        clientesSincronizados: 0,
      );
    } catch (e) {
      logger.e('❌ Error inesperado en sincronización: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  // ⭐ MÉTODO PRINCIPAL PARA ENVIAR UN CLIENTE AL SERVIDOR NODE.JS
  static Future<ApiResponse> enviarClienteAAPI(Cliente cliente) async {
    try {
      logger.i('📤 Enviando cliente a API Node.js...');
      logger.i('📤 URL: $clientesEndpoint');
      logger.i('📤 Datos: ${cliente.toJson()}');

      final response = await http.post(
        Uri.parse(clientesEndpoint),
        headers: _headers,
        body: jsonEncode(cliente.toJson()),
      ).timeout(timeout);

      logger.i('📤 Respuesta envío - Status: ${response.statusCode}');
      logger.i('📤 Respuesta envío - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          // Intentar parsear la respuesta JSON
          final responseData = response.body.trim();
          Map<String, dynamic>? parsedData;

          if (responseData.isNotEmpty) {
            try {
              parsedData = jsonDecode(responseData);
            } catch (e) {
              logger.w('⚠️ No se pudo parsear la respuesta JSON: $e');
            }
          }

          return ApiResponse(
            exito: true,
            mensaje: 'Cliente enviado correctamente al servidor Node.js',
            datos: parsedData,
            codigoEstado: response.statusCode,
          );
        } catch (e) {
          return ApiResponse(
            exito: true,
            mensaje: 'Cliente enviado correctamente (respuesta no parseable)',
            codigoEstado: response.statusCode,
          );
        }
      } else {
        // Error del servidor
        String mensajeError;
        try {
          Map<String, dynamic> errorData = jsonDecode(response.body);
          mensajeError = errorData['message'] ??
              errorData['error'] ??
              errorData['mensaje'] ??
              'Error del servidor (${response.statusCode})';
        } catch (e) {
          mensajeError = 'Error del servidor (${response.statusCode}): ${response.body}';
        }

        logger.e('❌ Error en envío: $mensajeError');

        return ApiResponse(
          exito: false,
          mensaje: mensajeError,
          codigoEstado: response.statusCode,
        );
      }

    } on SocketException catch (e) {
      logger.e('❌ Error de conexión: $e');
      return ApiResponse(
        exito: false,
        mensaje: 'Sin conexión al servidor Node.js ($baseUrl)',
      );
    } on TimeoutException catch (e) {
      logger.e('❌ Timeout: $e');
      return ApiResponse(
        exito: false,
        mensaje: 'Tiempo de espera agotado al conectar con el servidor',
      );
    } on HttpException catch (e) {
      logger.e('❌ Error HTTP: $e');
      return ApiResponse(
        exito: false,
        mensaje: 'Error en la comunicación HTTP con el servidor',
      );
    } catch (e) {
      logger.e('❌ Error inesperado: $e');
      return ApiResponse(
        exito: false,
        mensaje: 'Error inesperado al enviar cliente: ${e.toString()}',
      );
    }
  }

  // Buscar clientes en la API (para el buscador)
  static Future<BusquedaResponse> buscarClientesEnAPI(String query, {int page = 1, int limit = 10}) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final url = '$clientesEndpoint/buscar?q=$encodedQuery&page=$page&limit=$limit';

      logger.i('🔍 Buscando en API: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      logger.i('🔍 Respuesta búsqueda - Status: ${response.statusCode}');
      logger.i('🔍 Respuesta búsqueda - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);

          List<Cliente> clientes = [];
          if (responseData.containsKey('clientes') && responseData['clientes'] is List) {
            clientes = (responseData['clientes'] as List)
                .map((clienteJson) => _crearClienteDesdeAPI(clienteJson))
                .where((cliente) => cliente != null)
                .cast<Cliente>()
                .toList();
          }

          return BusquedaResponse(
            exito: true,
            mensaje: 'Búsqueda completada - ${clientes.length} resultados encontrados',
            clientes: clientes,
            total: responseData['total'] ?? clientes.length,
            pagina: responseData['page'] ?? page,
            totalPaginas: ((responseData['total'] ?? 0) / limit).ceil(),
          );

        } catch (e) {
          logger.e('❌ Error parseando respuesta de búsqueda: $e');
          return BusquedaResponse(
            exito: false,
            mensaje: 'Error procesando los datos de búsqueda: ${e.toString()}',
            clientes: [],
          );
        }
      } else {
        return BusquedaResponse(
          exito: false,
          mensaje: 'Error del servidor (${response.statusCode})',
          clientes: [],
          codigoEstado: response.statusCode,
        );
      }

    } catch (e) {
      return BusquedaResponse(
        exito: false,
        mensaje: 'Error: ${e.toString()}',
        clientes: [],
      );
    }
  }

  // Método privado para crear Cliente desde datos de API
  static Cliente? _crearClienteDesdeAPI(dynamic clienteJson) {
    try {
      if (clienteJson is Map<String, dynamic>) {
        return Cliente(
          id: clienteJson['id'],
          nombre: clienteJson['nombre'] ?? clienteJson['name'] ?? '',
          email: clienteJson['email'] ?? '',
          telefono: clienteJson['telefono'] ?? clienteJson['phone'],
          direccion: clienteJson['direccion'] ?? clienteJson['address'],
          fechaCreacion: clienteJson['fecha_creacion'] != null
              ? DateTime.parse(clienteJson['fecha_creacion'])
              : (clienteJson['createdAt'] != null
              ? DateTime.parse(clienteJson['createdAt'])
              : DateTime.now()),
        );
      }
      return null;
    } catch (e) {
      logger.e('⚠️ Error creando cliente desde JSON: $e');
      logger.e('⚠️ JSON problemático: $clienteJson');
      return null;
    }
  }

  // Probar conexión con la API
  static Future<ApiResponse> probarConexion() async {
    try {
      logger.i('🏓 Probando conexión con: $baseUrl/ping');

      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      logger.i('🏓 Respuesta ping - Status: ${response.statusCode}');
      logger.i('🏓 Respuesta ping - Body: ${response.body}');

      if (response.statusCode == 200) {
        return ApiResponse(
          exito: true,
          mensaje: '✅ Conexión exitosa con el servidor Node.js ($baseUrl)',
        );
      } else {
        return ApiResponse(
          exito: false,
          mensaje: '❌ Servidor Node.js no disponible (${response.statusCode})',
        );
      }
    } on SocketException {
      return ApiResponse(
        exito: false,
        mensaje: '❌ No se pudo conectar al servidor Node.js: Sin conexión de red',
      );
    } on TimeoutException {
      return ApiResponse(
        exito: false,
        mensaje: '❌ Tiempo de espera agotado al conectar con el servidor',
      );
    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: '❌ Error al conectar con el servidor: ${e.toString()}',
      );
    }
  }
}

// Clase para el resultado de sincronización
class SyncResult {
  final bool exito;
  final String mensaje;
  final int clientesSincronizados;
  final int totalEnAPI;

  SyncResult({
    required this.exito,
    required this.mensaje,
    required this.clientesSincronizados,
    this.totalEnAPI = 0,
  });
}

// Clase para respuesta de búsqueda
class BusquedaResponse {
  final bool exito;
  final String mensaje;
  final List<Cliente> clientes;
  final int total;
  final int pagina;
  final int totalPaginas;
  final int? codigoEstado;

  BusquedaResponse({
    required this.exito,
    required this.mensaje,
    required this.clientes,
    this.total = 0,
    this.pagina = 1,
    this.totalPaginas = 1,
    this.codigoEstado,
  });

  @override
  String toString() {
    return 'BusquedaResponse(exito: $exito, mensaje: $mensaje, clientes: ${clientes.length}, total: $total, pagina: $pagina, totalPaginas: $totalPaginas)';
  }
}
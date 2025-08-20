import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/cliente.dart';
import '../models/equipos.dart';
import 'dart:async';
import 'package:logger/logger.dart';

var logger = Logger();

class ApiService {
  // Cambia esta URL por tu endpoint real
  static const String baseUrl = 'http://192.168.1.186:3000';
  static const String clientesEndpoint = '$baseUrl/clientes';
  static const String equiposEndpoint = '$baseUrl/equipos';

  // Timeout para las peticiones
  static const Duration timeout = Duration(seconds: 30);

  // Headers comunes
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
    // 'Authorization': 'Bearer $token',
  };

  // Buscar clientes por nombre o email - MEJORADO
  static Future<BusquedaResponse> buscarClientes(String query, {int page = 1, int limit = 10}) async {
    try {
      // Encoding de la query para manejar caracteres especiales
      final encodedQuery = Uri.encodeQueryComponent(query);
      final url = '$clientesEndpoint/buscar?q=$encodedQuery&page=$page&limit=$limit';

      logger.i('Buscando en URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      logger.i('Respuesta búsqueda - Status: ${response.statusCode}');
      logger.i('Respuesta búsqueda - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);

          // Procesar los clientes desde la respuesta
          List<Cliente> clientes = [];
          if (responseData.containsKey('clientes') && responseData['clientes'] is List) {
            clientes = (responseData['clientes'] as List)
                .map((clienteJson) => Cliente.fromJson(clienteJson))
                .toList();
          } else if (responseData.containsKey('data') && responseData['data'] is List) {
            // Por si el servidor retorna los datos en un campo 'data'
            clientes = (responseData['data'] as List)
                .map((clienteJson) => Cliente.fromJson(clienteJson))
                .toList();
          } else if (responseData is List) {
            // Por si el servidor retorna directamente un array
            clientes = (responseData as List)
                .map((clienteJson) => Cliente.fromJson(clienteJson))
                .toList();
          }

          return BusquedaResponse(
            exito: true,
            mensaje: 'Búsqueda completada - ${clientes.length} resultados encontrados',
            clientes: clientes,
            total: responseData['total'] ?? clientes.length,
            pagina: responseData['pagina'] ?? page,
            totalPaginas: responseData['totalPaginas'] ?? 1,
          );

        } catch (e) {
          logger.e('Error parseando respuesta: $e');
          return BusquedaResponse(
            exito: false,
            mensaje: 'Error procesando los datos de búsqueda: ${e.toString()}',
            clientes: [],
          );
        }
      } else {
        // Error del servidor
        String mensajeError;
        try {
          Map<String, dynamic> errorData = jsonDecode(response.body);
          mensajeError = errorData['message'] ??
              errorData['error'] ??
              'Error del servidor (${response.statusCode})';
        } catch (e) {
          mensajeError = 'Error del servidor (${response.statusCode})';
        }

        return BusquedaResponse(
          exito: false,
          mensaje: mensajeError,
          clientes: [],
          codigoEstado: response.statusCode,
        );
      }

    } on SocketException {
      return BusquedaResponse(
        exito: false,
        mensaje: 'Sin conexión a internet',
        clientes: [],
      );
    } on TimeoutException {
      return BusquedaResponse(
        exito: false,
        mensaje: 'Tiempo de espera agotado',
        clientes: [],
      );
    } on HttpException {
      return BusquedaResponse(
        exito: false,
        mensaje: 'Error en la comunicación con el servidor',
        clientes: [],
      );
    } catch (e) {
      logger.e('Error inesperado en búsqueda: $e');
      return BusquedaResponse(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        clientes: [],
      );
    }
  }

  // Método para obtener todos los clientes (útil para debug)
  static Future<BusquedaResponse> obtenerTodosLosClientes({int page = 1, int limit = 50}) async {
    try {
      final url = '$clientesEndpoint?page=$page&limit=$limit';

      logger.i('Obteniendo todos los clientes desde: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      logger.i('Respuesta obtener todos - Status: ${response.statusCode}');
      logger.i('Respuesta obtener todos - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);

          List<Cliente> clientes = [];
          if (responseData is Map<String, dynamic>) {
            if (responseData.containsKey('clientes') && responseData['clientes'] is List) {
              clientes = (responseData['clientes'] as List)
                  .map((clienteJson) => Cliente.fromJson(clienteJson))
                  .toList();
            } else if (responseData.containsKey('data') && responseData['data'] is List) {
              clientes = (responseData['data'] as List)
                  .map((clienteJson) => Cliente.fromJson(clienteJson))
                  .toList();
            }
          } else if (responseData is List) {
            clientes = (responseData)
                .map((clienteJson) => Cliente.fromJson(clienteJson))
                .toList();
          }

          return BusquedaResponse(
            exito: true,
            mensaje: 'Clientes obtenidos correctamente - ${clientes.length} resultados',
            clientes: clientes,
            total: clientes.length,
            pagina: page,
            totalPaginas: 1,
          );

        } catch (e) {
          logger.e('Error parseando respuesta: $e');
          return BusquedaResponse(
            exito: false,
            mensaje: 'Error procesando los datos: ${e.toString()}',
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

  // Enviar un cliente individual
  static Future<ApiResponse> enviarCliente(Cliente cliente) async {
    try {
      logger.e('Enviando cliente al EDP: ${cliente.toJson()}');

      final response = await http.post(
        Uri.parse(clientesEndpoint),
        headers: _headers,
        body: jsonEncode(cliente.toJson()),
      ).timeout(timeout);

      return _procesarRespuesta(response, 'Cliente enviado correctamente');

    } on SocketException {
      return ApiResponse(
          exito: false,
          mensaje: 'Sin conexión a internet'
      );
    } on HttpException {
      return ApiResponse(
          exito: false,
          mensaje: 'Error en la comunicación con el servidor'
      );
    } catch (e) {
      return ApiResponse(
          exito: false,
          mensaje: 'Error inesperado: ${e.toString()}'
      );
    }
  }

  // Enviar múltiples clientes
  static Future<ApiResponse> enviarMultiplesClientes(List<Cliente> clientes) async {
    try {
      List<Map<String, dynamic>> clientesJson = clientes.map((c) => c.toJson()).toList();

      Map<String, dynamic> payload = {
        'clientes': clientesJson,
        'total': clientes.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger.e('Enviando ${clientes.length} clientes al EDP');

      final response = await http.post(
        Uri.parse('$clientesEndpoint/multiples'),
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(timeout);

      return _procesarRespuesta(response, '${clientes.length} clientes enviados correctamente');

    } on SocketException {
      return ApiResponse(
          exito: false,
          mensaje: 'Sin conexión a internet'
      );
    } on HttpException {
      return ApiResponse(
          exito: false,
          mensaje: 'Error en la comunicación con el servidor'
      );
    } catch (e) {
      return ApiResponse(
          exito: false,
          mensaje: 'Error inesperado: ${e.toString()}'
      );
    }
  }

  // Obtener todos los equipos
  static Future<BusquedaResponseEquipos> obtenerTodosLosEquipos({int page = 1, int limit = 50}) async {
    try {
      final url = '$equiposEndpoint?page=$page&limit=$limit';

      logger.i('Obteniendo todos los equipos desde: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      logger.i('Respuesta equipos - Status: ${response.statusCode}');
      logger.i('Respuesta equipos - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);

          List<Equipo> equipos = [];
          if (responseData is Map<String, dynamic>) {
            if (responseData.containsKey('equipos') && responseData['equipos'] is List) {
              equipos = (responseData['equipos'] as List)
                  .map((equipoJson) => Equipo.fromJson(equipoJson))
                  .toList();
            } else if (responseData.containsKey('data') && responseData['data'] is List) {
              equipos = (responseData['data'] as List)
                  .map((equipoJson) => Equipo.fromJson(equipoJson))
                  .toList();
            }
          } else if (responseData is List) {
            equipos = (responseData)
                .map((equipoJson) => Equipo.fromJson(equipoJson))
                .toList();
          }

          return BusquedaResponseEquipos(
            exito: true,
            mensaje: 'Equipos obtenidos correctamente - ${equipos.length} resultados',
            equipos: equipos,
            total: equipos.length,
            pagina: page,
            totalPaginas: 1,
          );

        } catch (e) {
          logger.e('Error parseando respuesta equipos: $e');
          return BusquedaResponseEquipos(
            exito: false,
            mensaje: 'Error procesando los datos: ${e.toString()}',
            equipos: [],
          );
        }
      } else {
        return BusquedaResponseEquipos(
          exito: false,
          mensaje: 'Error del servidor (${response.statusCode})',
          equipos: [],
          codigoEstado: response.statusCode,
        );
      }

    } catch (e) {
      return BusquedaResponseEquipos(
        exito: false,
        mensaje: 'Error: ${e.toString()}',
        equipos: [],
      );
    }
  }

  // Procesar la respuesta del servidor
  static ApiResponse _procesarRespuesta(http.Response response, String mensajeExito) {
    logger.i('Respuesta del servidor - Status: ${response.statusCode}');
    logger.i('Respuesta del servidor - Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        return ApiResponse(
          exito: true,
          mensaje: mensajeExito,
          datos: responseData,
        );
      } catch (e) {
        return ApiResponse(
          exito: true,
          mensaje: mensajeExito,
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

      return ApiResponse(
        exito: false,
        mensaje: mensajeError,
        codigoEstado: response.statusCode,
      );
    }
  }

  // Método para probar la conexión
  static Future<ApiResponse> probarConexion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse(
          exito: true,
          mensaje: 'Conexión exitosa con el servidor',
        );
      } else {
        return ApiResponse(
          exito: false,
          mensaje: 'Servidor no disponible (${response.statusCode})',
        );
      }
    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: 'No se pudo conectar al servidor: ${e.toString()}',
      );
    }
  }
}

// Clase específica para manejar respuestas de búsqueda
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
    return 'BusquedaResponse{exito: $exito, mensaje: $mensaje, clientes: ${clientes.length}, total: $total}';
  }
}

// Clase específica para manejar respuestas de búsqueda de equipos
class BusquedaResponseEquipos {
  final bool exito;
  final String mensaje;
  final List<Equipo> equipos;
  final int total;
  final int pagina;
  final int totalPaginas;
  final int? codigoEstado;

  BusquedaResponseEquipos({
    required this.exito,
    required this.mensaje,
    required this.equipos,
    this.total = 0,
    this.pagina = 1,
    this.totalPaginas = 1,
    this.codigoEstado,
  });

  @override
  String toString() {
    return 'BusquedaResponseEquipos{exito: $exito, mensaje: $mensaje, equipos: ${equipos.length}, total: $total}';
  }
}

// Clase para manejar las respuestas generales de la API
class ApiResponse {
  final bool exito;
  final String mensaje;
  final Map<String, dynamic>? datos;
  final int? codigoEstado;

  ApiResponse({
    required this.exito,
    required this.mensaje,
    this.datos,
    this.codigoEstado,
  });

  @override
  String toString() {
    return 'ApiResponse{exito: $exito, mensaje: $mensaje, codigoEstado: $codigoEstado}';
  }
}
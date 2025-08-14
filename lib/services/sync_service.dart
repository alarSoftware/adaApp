import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/cliente.dart';
import 'database_helper.dart';
import 'dart:async';

class SyncService {
  static const String baseUrl = 'http://192.168.1.185:3000';
  static const String clientesEndpoint = '$baseUrl/clientes';
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  // Sincronizar todos los datos desde la API a la base de datos local
  static Future<SyncResult> sincronizarConAPI() async {
    try {
      print('🔄 Iniciando sincronización con API...');

      // Obtener todos los clientes de la API (sin límite)
      final response = await http.get(
        Uri.parse('$clientesEndpoint?limit=1000'), // Límite alto para obtener todos
        headers: _headers,
      ).timeout(timeout);

      print('📡 Respuesta de API - Status: ${response.statusCode}');
      print('📡 Respuesta de API - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);

          // Extraer la lista de clientes
          List<Cliente> clientesAPI = [];
          if (responseData.containsKey('clientes') && responseData['clientes'] is List) {
            clientesAPI = (responseData['clientes'] as List)
                .map((clienteJson) => _crearClienteDesdeAPI(clienteJson))
                .where((cliente) => cliente != null)
                .cast<Cliente>()
                .toList();
          }

          print('📥 Clientes obtenidos de API: ${clientesAPI.length}');

          if (clientesAPI.isEmpty) {
            return SyncResult(
              exito: false,
              mensaje: 'No se encontraron clientes en la API',
              clientesSincronizados: 0,
            );
          }

          // Limpiar base de datos local y insertar nuevos datos
          final dbHelper = DatabaseHelper();
          await dbHelper.limpiarYSincronizar(clientesAPI); // Método público que crearemos

          int clientesInsertados = clientesAPI.length;

          print('✅ Sincronización completada: $clientesInsertados clientes guardados');

          return SyncResult(
            exito: true,
            mensaje: 'Sincronización exitosa',
            clientesSincronizados: clientesInsertados,
            totalEnAPI: clientesAPI.length,
          );

        } catch (e) {
          print('❌ Error procesando datos de API: $e');
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
        mensaje: 'Sin conexión a internet',
        clientesSincronizados: 0,
      );
    } on TimeoutException {
      return SyncResult(
        exito: false,
        mensaje: 'Tiempo de espera agotado',
        clientesSincronizados: 0,
      );
    } on HttpException {
      return SyncResult(
        exito: false,
        mensaje: 'Error en la comunicación con el servidor',
        clientesSincronizados: 0,
      );
    } catch (e) {
      print('❌ Error inesperado en sincronización: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  // Buscar clientes en la API (para el buscador)
  static Future<BusquedaResponse> buscarClientesEnAPI(String query, {int page = 1, int limit = 10}) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final url = '$clientesEndpoint/buscar?q=$encodedQuery&page=$page&limit=$limit';

      print('🔍 Buscando en API: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      print('🔍 Respuesta búsqueda - Status: ${response.statusCode}');
      print('🔍 Respuesta búsqueda - Body: ${response.body}');

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
          print('❌ Error parseando respuesta de búsqueda: $e');
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
          nombre: clienteJson['nombre'] ?? '',
          email: clienteJson['email'] ?? '',
          telefono: clienteJson['telefono'],
          direccion: clienteJson['direccion'],
          fechaCreacion: clienteJson['fecha_creacion'] != null
              ? DateTime.parse(clienteJson['fecha_creacion'])
              : DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('⚠️ Error creando cliente desde JSON: $e');
      print('⚠️ JSON problemático: $clienteJson');
      return null;
    }
  }

  // Enviar un cliente a la API
  static Future<ApiResponse> enviarClienteAAPI(Cliente cliente) async {
    try {
      print('📤 Enviando cliente a API: ${cliente.toJson()}');

      final response = await http.post(
        Uri.parse(clientesEndpoint),
        headers: _headers,
        body: jsonEncode(cliente.toJson()),
      ).timeout(timeout);

      print('📤 Respuesta envío - Status: ${response.statusCode}');
      print('📤 Respuesta envío - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          Map<String, dynamic> responseData = jsonDecode(response.body);
          return ApiResponse(
            exito: true,
            mensaje: 'Cliente enviado correctamente',
            datos: responseData,
          );
        } catch (e) {
          return ApiResponse(
            exito: true,
            mensaje: 'Cliente enviado correctamente',
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

    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: 'Error enviando cliente: ${e.toString()}',
      );
    }
  }

  // Probar conexión con la API
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

  @override
  String toString() {
    return 'SyncResult{exito: $exito, mensaje: $mensaje, clientesSincronizados: $clientesSincronizados, totalEnAPI: $totalEnAPI}';
  }
}

// Clases de respuesta (mantener las existentes)
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
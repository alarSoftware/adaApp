import 'dart:convert';
import 'dart:io';
import 'package:cliente_app/repositories/cliente_repository.dart';
import 'package:cliente_app/repositories/equipo_repository.dart';
import 'package:cliente_app/repositories/equipo_cliente_repository.dart';
import 'package:http/http.dart' as http;
import 'package:cliente_app/models/cliente.dart';
import 'package:cliente_app/models/equipos_cliente.dart';
import 'package:cliente_app/services/api_service.dart';
import 'dart:async';
import 'package:logger/logger.dart';

var logger = Logger();

class SyncService {
  static const String baseUrl = 'http://192.168.1.185:3000';
  static const String clientesEndpoint = '$baseUrl/clientes';
  static const String pingEndpoint = '$baseUrl/ping';
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
    'User-Agent': 'Flutter-SyncService/1.0',
  };

  /// Sincronizar todos los datos: clientes, equipos y asignaciones
  static Future<SyncResultUnificado> sincronizarTodosLosDatos() async {
    logger.i('🔄 Iniciando sincronización unificada...');

    final resultado = SyncResultUnificado();

    try {
      // 1. Verificar conexión primero
      logger.i('📡 Verificando conexión...');
      final conexion = await probarConexion();
      if (!conexion.exito) {
        resultado.exito = false;
        resultado.mensaje = 'Sin conexión al servidor: ${conexion.mensaje}';
        return resultado;
      }

      resultado.conexionOK = true;
      logger.i('✅ Conexión verificada');

      // 2. Sincronizar clientes
      logger.i('👥 Sincronizando clientes...');
      resultado.estadoActual = 'Descargando clientes...';

      final resultadoClientes = await sincronizarConAPI();
      resultado.clientesSincronizados = resultadoClientes.clientesSincronizados;
      resultado.clientesExito = resultadoClientes.exito;

      if (resultadoClientes.exito) {
        logger.i('✅ Clientes sincronizados: ${resultadoClientes.clientesSincronizados}');
      } else {
        logger.w('⚠️ Error en clientes: ${resultadoClientes.mensaje}');
        resultado.erroresClientes = resultadoClientes.mensaje;
      }

      // 3. Sincronizar equipos
      logger.i('🔧 Sincronizando equipos...');
      resultado.estadoActual = 'Descargando equipos...';

      final resultadoEquipos = await sincronizarEquipos();
      resultado.equiposSincronizados = resultadoEquipos.clientesSincronizados; // Reutilizamos el campo
      resultado.equiposExito = resultadoEquipos.exito;

      if (resultadoEquipos.exito) {
        logger.i('✅ Equipos sincronizados: ${resultadoEquipos.clientesSincronizados}');
      } else {
        logger.w('⚠️ Error en equipos: ${resultadoEquipos.mensaje}');
        resultado.erroresEquipos = resultadoEquipos.mensaje;
      }

      // 3.1. Sincronizar asignaciones
      logger.i('🔗 Sincronizando asignaciones...');
      resultado.estadoActual = 'Descargando asignaciones...';

      final resultadoAsignaciones = await sincronizarAsignaciones();
      int asignacionesSincronizadas = 0;
      bool asignacionesExito = false;

      if (resultadoAsignaciones.exito) {
        logger.i('✅ Asignaciones sincronizadas: ${resultadoAsignaciones.clientesSincronizados}');
        asignacionesSincronizadas = resultadoAsignaciones.clientesSincronizados;
        asignacionesExito = true;
      } else {
        logger.w('⚠️ Error en asignaciones: ${resultadoAsignaciones.mensaje}');
      }

      // 4. Evaluar resultado final
      resultado.estadoActual = 'Finalizando...';

      if (resultado.clientesExito && resultado.equiposExito && asignacionesExito) {
        resultado.exito = true;
        resultado.mensaje = 'Sincronización completa: ${resultado.clientesSincronizados} clientes, ${resultado.equiposSincronizados} equipos y ${asignacionesSincronizadas} asignaciones';
      } else if (resultado.clientesExito || resultado.equiposExito || asignacionesExito) {
        resultado.exito = true; // Éxito parcial
        resultado.mensaje = 'Sincronización parcial: ';
        if (resultado.clientesExito) resultado.mensaje += '${resultado.clientesSincronizados} clientes ';
        if (resultado.equiposExito) resultado.mensaje += '${resultado.equiposSincronizados} equipos ';
        if (asignacionesExito) resultado.mensaje += '${asignacionesSincronizadas} asignaciones ';
        resultado.mensaje += 'descargados';
      } else {
        resultado.exito = false;
        resultado.mensaje = 'Error en sincronización';
      }

      logger.i('🏁 Sincronización unificada completada: ${resultado.mensaje}');
      return resultado;

    } catch (e, stack) {
      logger.e('❌ Error en sincronización unificada: $e');
      logger.e('🔍 Stack trace: $stack');

      resultado.exito = false;
      resultado.mensaje = 'Error inesperado: ${e.toString()}';
      return resultado;
    }
  }

  /// Sincronizar solo equipos
  static Future<SyncResult> sincronizarEquipos() async {
    try {
      logger.i('🔧 Iniciando sincronización de equipos...');

      final response = await ApiService.obtenerTodosLosEquipos();

      if (response.exito && response.equipos.isNotEmpty) {
        final equipoRepo = EquipoRepository();
        await equipoRepo.limpiarYSincronizar(response.equipos.cast<dynamic>());

        logger.i('✅ Equipos sincronizados: ${response.equipos.length}');

        return SyncResult(
          exito: true,
          mensaje: 'Equipos sincronizados correctamente',
          clientesSincronizados: response.equipos.length, // Reutilizamos el campo
          totalEnAPI: response.equipos.length,
        );
      } else {
        logger.w('⚠️ No se pudieron obtener equipos: ${response.mensaje}');
        return SyncResult(
          exito: false,
          mensaje: 'Error sincronizando equipos: ${response.mensaje}',
          clientesSincronizados: 0,
        );
      }
    } catch (e, stack) {
      logger.e('❌ Error sincronizando equipos: $e');
      logger.e('🔍 Stack trace: $stack');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado en equipos: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  /// Sincronizar solo asignaciones equipo-cliente
  static Future<SyncResult> sincronizarAsignaciones() async {
    try {
      logger.i('🔗 Iniciando sincronización de asignaciones...');

      final response = await ApiService.obtenerTodasLasAsignaciones();

      if (response.exito && response.asignaciones.isNotEmpty) {
        final equipoClienteRepo = EquipoClienteRepository();
        await equipoClienteRepo.limpiarYSincronizar(response.asignaciones.cast<dynamic>());

        logger.i('✅ Asignaciones sincronizadas: ${response.asignaciones.length}');

        return SyncResult(
          exito: true,
          mensaje: 'Asignaciones sincronizadas correctamente',
          clientesSincronizados: response.asignaciones.length, // Reutilizamos el campo
          totalEnAPI: response.asignaciones.length,
        );
      } else {
        logger.w('⚠️ No se pudieron obtener asignaciones: ${response.mensaje}');
        return SyncResult(
          exito: false,
          mensaje: 'Error sincronizando asignaciones: ${response.mensaje}',
          clientesSincronizados: 0,
        );
      }
    } catch (e, stack) {
      logger.e('❌ Error sincronizando asignaciones: $e');
      logger.e('🔍 Stack trace: $stack');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado en asignaciones: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  // SINCRONIZACIÓN DE CLIENTES
  static Future<SyncResult> sincronizarConAPI() async {
    try {
      logger.i('🔄 Iniciando sincronización con API...');

      final response = await http.get(
        Uri.parse(clientesEndpoint),
        headers: _headers,
      ).timeout(timeout);

      logger.i('📡 Respuesta de API - Status: ${response.statusCode}');
      logger.d('📄 Respuesta de API (primeros 300 chars): ${response.body.length > 300 ? '${response.body.substring(0, 300)}...' : response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseBody = response.body.trim();
          List<Cliente> clientesAPI = [];

          if (responseBody.startsWith('[')) {
            final List<dynamic> clientesJson = jsonDecode(responseBody);
            logger.i('✅ Array de clientes recibido: ${clientesJson.length} elementos');

            for (var i = 0; i < clientesJson.length; i++) {
              try {
                final clienteData = clientesJson[i];
                final cliente = _crearClienteDesdeAPI(clienteData);
                if (cliente != null) {
                  clientesAPI.add(cliente);
                  logger.d('✅ Cliente ${i + 1} parseado: ${cliente.nombre}');
                } else {
                  logger.w('⚠️ Cliente ${i + 1} ignorado por datos inválidos');
                }
              } catch (e) {
                logger.w('⚠️ Error parseando cliente ${i + 1}: $e');
              }
            }
          } else {
            logger.e('❌ Formato de respuesta inesperado. Se esperaba un array JSON.');
            return SyncResult(
              exito: false,
              mensaje: 'Formato de respuesta inesperado del servidor',
              clientesSincronizados: 0,
            );
          }

          logger.i('📥 Clientes procesados de API: ${clientesAPI.length}');

          if (clientesAPI.isEmpty) {
            return SyncResult(
              exito: false,
              mensaje: 'No se encontraron clientes válidos en la API',
              clientesSincronizados: 0,
            );
          }

          final clienteRepo = ClienteRepository();
          await clienteRepo.limpiarYSincronizar(clientesAPI.cast<dynamic>());

          logger.i('✅ Sincronización completada: ${clientesAPI.length} clientes');

          return SyncResult(
            exito: true,
            mensaje: 'Sincronización exitosa: ${clientesAPI.length} clientes descargados',
            clientesSincronizados: clientesAPI.length,
            totalEnAPI: clientesAPI.length,
          );

        } catch (e, stack) {
          logger.e('❌ Error procesando respuesta de sincronización: $e');
          logger.e('🔍 Stack trace: $stack');
          return SyncResult(
            exito: false,
            mensaje: 'Error procesando datos de la API: $e',
            clientesSincronizados: 0,
          );
        }
      } else {
        logger.e('❌ Error del servidor - Status: ${response.statusCode}');
        String mensajeError = _extraerMensajeError(response);
        return SyncResult(
          exito: false,
          mensaje: mensajeError,
          clientesSincronizados: 0,
        );
      }

    } on SocketException catch (e) {
      logger.e('❌ Sin conexión: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión a internet o servidor no disponible (192.168.1.186:3000)',
        clientesSincronizados: 0,
      );
    } on TimeoutException catch (e) {
      logger.e('❌ Timeout: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Tiempo de espera agotado (30 segundos)',
        clientesSincronizados: 0,
      );
    } on HttpException catch (e) {
      logger.e('❌ Error HTTP: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error en la comunicación con el servidor',
        clientesSincronizados: 0,
      );
    } catch (e, stack) {
      logger.e('❌ Error inesperado en sincronización: $e');
      logger.e('🔍 Stack trace: $stack');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // RESTO DEL CÓDIGO ORIGINAL (ENVÍO, CONEXIÓN, ETC.)
  // ═══════════════════════════════════════════════════════════════════════════════

  static Future<ApiResponse> enviarClienteAAPI(Cliente cliente) async {
    try {
      logger.i('📤 Enviando cliente: ${cliente.nombre}');

      Map<String, dynamic> clienteData = {
        'nombre': cliente.nombre,
        'email': cliente.email,
        'telefono': cliente.telefono ?? '',
        'direccion': cliente.direccion ?? '',
      };

      logger.d('📤 URL: $clientesEndpoint');
      logger.d('📤 Datos: ${jsonEncode(clienteData)}');

      final response = await http.post(
        Uri.parse(clientesEndpoint),
        headers: _headers,
        body: jsonEncode(clienteData),
      ).timeout(timeout);

      logger.i('📤 Respuesta envío - Status: ${response.statusCode}');
      logger.d('📤 Respuesta envío - Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? parsedData;

        try {
          if (response.body.trim().isNotEmpty) {
            parsedData = jsonDecode(response.body);
          }
        } catch (e) {
          logger.w('⚠️ No se pudo parsear la respuesta JSON: $e');
        }

        return ApiResponse(
          exito: true,
          mensaje: 'Cliente enviado correctamente al servidor',
          datos: parsedData,
          codigoEstado: response.statusCode,
        );
      } else {
        String mensajeError = _extraerMensajeError(response);
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
        mensaje: 'Sin conexión al servidor ($baseUrl)',
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
    } catch (e, stack) {
      logger.e('❌ Error inesperado: $e');
      logger.e('🔍 Stack trace: $stack');
      return ApiResponse(
        exito: false,
        mensaje: 'Error inesperado al enviar cliente: ${e.toString()}',
      );
    }
  }

  static Future<SyncResult> enviarClientesPendientes() async {
    try {
      final clienteRepo = ClienteRepository();
      final clientesPendientes = await clienteRepo.obtenerNoSincronizados();

      if (clientesPendientes.isEmpty) {
        return SyncResult(
          exito: true,
          mensaje: 'No hay clientes pendientes por sincronizar',
          clientesSincronizados: 0,
        );
      }

      logger.i('📤 Enviando ${clientesPendientes.length} clientes pendientes...');

      int exitosos = 0;
      int fallidos = 0;

      for (Cliente cliente in clientesPendientes) {
        try {
          final resultado = await enviarClienteAAPI(cliente);

          if (resultado.exito) {
            exitosos++;
            if (cliente.id != null) {
              await clienteRepo.marcarComoSincronizados([cliente.id!]);
            }
          } else {
            fallidos++;
            logger.w('❌ No se pudo enviar: ${cliente.nombre} - ${resultado.mensaje}');
          }

          await Future.delayed(Duration(milliseconds: 200));

        } catch (e, stack) {
          fallidos++;
          logger.e('💥 Error inesperado enviando cliente ${cliente.nombre}: $e');
          logger.e('🔍 Stack trace: $stack');
        }
      }

      if (fallidos == 0) {
        return SyncResult(
          exito: true,
          mensaje: 'Todos los clientes enviados correctamente ($exitosos/$exitosos)',
          clientesSincronizados: exitosos,
        );
      } else if (exitosos > 0) {
        return SyncResult(
          exito: true,
          mensaje: 'Envío parcial: $exitosos exitosos, $fallidos fallidos',
          clientesSincronizados: exitosos,
        );
      } else {
        return SyncResult(
          exito: false,
          mensaje: 'No se pudo enviar ningún cliente',
          clientesSincronizados: 0,
        );
      }

    } catch (e, stack) {
      logger.e('❌ Error enviando clientes pendientes: $e');
      logger.e('🔍 Stack trace: $stack');
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        clientesSincronizados: 0,
      );
    }
  }

  static Future<ApiResponse> probarConexion() async {
    try {
      logger.i('🏓 Probando conexión con: $pingEndpoint');

      final response = await http.get(
        Uri.parse(pingEndpoint),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      logger.i('🏓 Respuesta ping - Status: ${response.statusCode}');
      logger.d('🏓 Respuesta ping - Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic>? serverInfo;

        try {
          if (response.body.trim().isNotEmpty) {
            serverInfo = jsonDecode(response.body);
          }
        } catch (e) {
          logger.w('⚠️ No se pudo parsear info del servidor: $e');
        }

        return ApiResponse(
          exito: true,
          mensaje: '✅ Conexión exitosa con el servidor ($baseUrl)',
          datos: serverInfo,
        );
      } else {
        return ApiResponse(
          exito: false,
          mensaje: '❌ Servidor no disponible (${response.statusCode})',
          codigoEstado: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      logger.e('❌ Error de conexión: $e');
      return ApiResponse(
        exito: false,
        mensaje: '❌ No se pudo conectar al servidor: Verifica que estés en la misma red WiFi (192.168.1.x)',
      );
    } on TimeoutException catch (e) {
      logger.e('❌ Timeout: $e');
      return ApiResponse(
        exito: false,
        mensaje: '❌ Tiempo de espera agotado: Verifica que el servidor esté ejecutándose',
      );
    } catch (e, stack) {
      logger.e('❌ Error inesperado: $e');
      logger.e('🔍 Stack trace: $stack');
      return ApiResponse(
        exito: false,
        mensaje: '❌ Error al conectar con el servidor: ${e.toString()}',
      );
    }
  }

  // MÉTODOS AUXILIARES
  static Cliente? _crearClienteDesdeAPI(dynamic clienteJson) {
    try {
      if (clienteJson is! Map<String, dynamic>) {
        logger.w('⚠️ Datos de cliente no válidos: $clienteJson');
        return null;
      }

      final Map<String, dynamic> data = clienteJson;

      if (data['nombre'] == null || data['nombre'].toString().trim().isEmpty) {
        logger.w('⚠️ Cliente sin nombre válido: $data');
        return null;
      }

      if (data['email'] == null || data['email'].toString().trim().isEmpty) {
        logger.w('⚠️ Cliente sin email válido: $data');
        return null;
      }

      return Cliente(
        id: data['id'] is int ? data['id'] : null,
        nombre: data['nombre'].toString().trim(),
        email: data['email'].toString().trim(),
        telefono: data['telefono']?.toString().trim(),
        direccion: data['direccion']?.toString().trim(),
        fechaCreacion: _parsearFecha(data['fecha_creacion']) ?? DateTime.now(),
      );

    } catch (e, stack) {
      logger.e('⚠️ Error creando cliente desde JSON: $e');
      logger.e('⚠️ JSON problemático: $clienteJson');
      logger.e('🔍 Stack trace: $stack');
      return null;
    }
  }

  static DateTime? _parsearFecha(dynamic fechaString) {
    if (fechaString == null) return null;

    try {
      String fechaStr = fechaString.toString();

      if (fechaStr.contains('T') || fechaStr.contains('Z')) {
        return DateTime.parse(fechaStr);
      }

      if (fechaStr.contains('-')) {
        return DateTime.parse(fechaStr);
      }

      return null;
    } catch (e) {
      logger.w('⚠️ No se pudo parsear fecha: $fechaString - Error: $e');
      return null;
    }
  }

  static String _extraerMensajeError(http.Response response) {
    try {
      if (response.body.trim().isEmpty) {
        return 'Error del servidor (${response.statusCode})';
      }

      final Map<String, dynamic> errorData = jsonDecode(response.body);
      return errorData['message'] ??
          errorData['error'] ??
          errorData['mensaje'] ??
          'Error del servidor (${response.statusCode})';
    } catch (e) {
      return 'Error del servidor (${response.statusCode}): ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}';
    }
  }

  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final clienteRepo = ClienteRepository();
      final estadisticasDB = await clienteRepo.obtenerEstadisticas();
      final conexion = await probarConexion();

      return {
        ...estadisticasDB,
        'conexionServidor': conexion.exito,
        'mensajeConexion': conexion.mensaje,
        'ultimaVerificacion': DateTime.now().toIso8601String(),
        'servidorURL': baseUrl,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'conexionServidor': false,
        'servidorURL': baseUrl,
      };
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLASES DE RESULTADO
// ═══════════════════════════════════════════════════════════════════════════════

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
    return 'SyncResult(exito: $exito, mensaje: $mensaje, sincronizados: $clientesSincronizados, total: $totalEnAPI)';
  }
}

/// Resultado de sincronización unificada
class SyncResultUnificado {
  bool exito = false;
  String mensaje = '';
  String estadoActual = '';

  // Conexión
  bool conexionOK = false;

  // Clientes
  bool clientesExito = false;
  int clientesSincronizados = 0;
  String? erroresClientes;

  // Equipos
  bool equiposExito = false;
  int equiposSincronizados = 0;
  String? erroresEquipos;

  @override
  String toString() {
    return 'SyncResultUnificado(exito: $exito, clientes: $clientesSincronizados, equipos: $equiposSincronizados, mensaje: $mensaje)';
  }
}
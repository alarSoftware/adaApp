import 'dart:convert';
import 'dart:io';
import 'package:cliente_app/repositories/cliente_repository.dart';
import 'package:cliente_app/repositories/equipo_repository.dart';
import 'package:cliente_app/repositories/equipo_cliente_repository.dart';
import 'package:cliente_app/repositories/marca_repository.dart';
import 'package:cliente_app/repositories/logo_repository.dart';
import 'package:cliente_app/services/database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:cliente_app/models/cliente.dart';
import 'dart:async';
import 'package:logger/logger.dart';

final _logger = Logger();

class SyncService {
  static const String baseUrl = 'http://192.168.1.185:3000';
  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  static final _dbHelper = DatabaseHelper();
  static final _clienteRepo = ClienteRepository();
  static final _equipoRepo = EquipoRepository();
  static final _equipoClienteRepo = EquipoClienteRepository();
  static final _marcaRepo = MarcaRepository();
  static final _logoRepo = LogoRepository();

  static Future<SyncResultUnificado> sincronizarTodosLosDatos() async {
    final resultado = SyncResultUnificado();

    try {
      final conexion = await probarConexion();
      if (!conexion.exito) {
        resultado.exito = false;
        resultado.mensaje = 'Sin conexión al servidor: ${conexion.mensaje}';
        return resultado;
      }

      resultado.conexionOK = true;

      await _sincronizarMarcas();
      await _sincronizarModelos();
      await _sincronizarLogos();

      final resultadoClientes = await sincronizarClientes();
      resultado.clientesSincronizados = resultadoClientes.itemsSincronizados;
      resultado.clientesExito = resultadoClientes.exito;
      if (!resultadoClientes.exito) resultado.erroresClientes = resultadoClientes.mensaje;

      final resultadoEquipos = await sincronizarEquipos();
      resultado.equiposSincronizados = resultadoEquipos.itemsSincronizados;
      resultado.equiposExito = resultadoEquipos.exito;
      if (!resultadoEquipos.exito) resultado.erroresEquipos = resultadoEquipos.mensaje;

      final resultadoAsignaciones = await sincronizarAsignaciones();
      resultado.asignacionesSincronizadas = resultadoAsignaciones.itemsSincronizados;
      resultado.asignacionesExito = resultadoAsignaciones.exito;
      if (!resultadoAsignaciones.exito) resultado.erroresAsignaciones = resultadoAsignaciones.mensaje;

      final exitosos = [resultado.clientesExito, resultado.equiposExito, resultado.asignacionesExito];
      final totalExitosos = exitosos.where((e) => e).length;

      if (totalExitosos == 3) {
        resultado.exito = true;
        resultado.mensaje = 'Sincronización completa: ${resultado.clientesSincronizados} clientes, ${resultado.equiposSincronizados} equipos y ${resultado.asignacionesSincronizadas} asignaciones';
      } else if (totalExitosos > 0) {
        resultado.exito = true;
        final partes = <String>[];
        if (resultado.clientesExito) partes.add('${resultado.clientesSincronizados} clientes');
        if (resultado.equiposExito) partes.add('${resultado.equiposSincronizados} equipos');
        if (resultado.asignacionesExito) partes.add('${resultado.asignacionesSincronizadas} asignaciones');
        resultado.mensaje = 'Sincronización parcial: ${partes.join(', ')}';
      } else {
        resultado.exito = false;
        resultado.mensaje = 'Error: no se pudo sincronizar ningún dato';
      }

      return resultado;

    } catch (e) {
      _logger.e('Error en sincronización unificada: $e');
      resultado.exito = false;
      resultado.mensaje = 'Error inesperado: ${e.toString()}';
      return resultado;
    }
  }

  static Future<void> _sincronizarModelos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/modelos'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> modelosAPI = jsonDecode(response.body);

        // FILTRAR modelos con nombre válido (API usa 'modelo' no 'nombre')
        final modelosValidos = modelosAPI.where((modelo) {
          return modelo != null &&
              modelo['modelo'] != null &&
              modelo['modelo'].toString().trim().isNotEmpty;
        }).map((modelo) {
          return {
            'id': modelo['id'],
            'nombre': modelo['modelo'], // Mapear 'modelo' a 'nombre'
          };
        }).toList();

        if (modelosValidos.isNotEmpty) {
          await _dbHelper.sincronizarModelos(modelosValidos);
          _logger.i('Modelos sincronizados: ${modelosValidos.length} de ${modelosAPI.length}');
        } else {
          _logger.w('No hay modelos válidos para sincronizar');
        }
      }
    } catch (e) {
      _logger.e('Error sincronizando modelos: $e');
    }
  }

  static Future<SyncResult> sincronizarModelos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/modelos'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> modelosData = _parseResponse(response.body);

        if (modelosData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay modelos en el servidor',
            itemsSincronizados: 0,
          );
        }

        // FILTRAR modelos válidos (API usa 'modelo' no 'nombre')
        final modelosLimpios = modelosData.where((modelo) {
          return modelo != null &&
              modelo['id'] != null &&
              modelo['modelo'] != null &&
              modelo['modelo'].toString().trim().isNotEmpty;
        }).map((modelo) {
          return {
            'id': modelo['id'],
            'nombre': modelo['modelo'].toString().trim(), // Mapear 'modelo' a 'nombre'
          };
        }).toList();

        if (modelosLimpios.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se encontraron modelos válidos en el servidor',
            itemsSincronizados: 0,
          );
        }

        await _dbHelper.sincronizarModelos(modelosLimpios);

        return SyncResult(
          exito: true,
          mensaje: 'Modelos sincronizados correctamente',
          itemsSincronizados: modelosLimpios.length,
          totalEnAPI: modelosData.length,
        );
      } else {
        final mensaje = _extraerMensajeError(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: _getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<void> _sincronizarMarcas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/marcas'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> marcasAPI = jsonDecode(response.body);
        await _dbHelper.sincronizarMarcas(marcasAPI);
        _logger.i('Marcas sincronizadas: ${marcasAPI.length}');
      }
    } catch (e) {
      _logger.e('Error sincronizando marcas: $e');
    }
  }

  static Future<void> _sincronizarLogos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/logo'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> logosAPI = jsonDecode(response.body);
        await _dbHelper.sincronizarLogos(logosAPI);
        _logger.i('Logos sincronizados: ${logosAPI.length}');
      }
    } catch (e) {
      _logger.e('Error sincronizando logos: $e');
    }
  }

  static Future<SyncResult> sincronizarClientes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clientes'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesData = _parseResponse(response.body);

        if (clientesData.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se encontraron clientes en el servidor',
            itemsSincronizados: 0,
          );
        }

        final clientes = <Cliente>[];
        for (var clienteJson in clientesData) {
          final cliente = _crearClienteDesdeAPI(clienteJson);
          if (cliente != null) {
            clientes.add(cliente);
          }
        }

        if (clientes.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar los clientes del servidor',
            itemsSincronizados: 0,
          );
        }

        await _clienteRepo.limpiarYSincronizar(clientes.cast<dynamic>());

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientes.length,
          totalEnAPI: clientes.length,
        );
      } else {
        final mensaje = _extraerMensajeError(response);
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: _getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // ✅ MÉTODO CORREGIDO - Cambié 'modelo' por 'modelo_id'
  static Future<SyncResult> sincronizarEquipos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipos'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> equiposData = _parseResponse(response.body);

        if (equiposData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay equipos en el servidor',
            itemsSincronizados: 0,
          );
        }

        final equiposLimpios = equiposData.map((equipo) {
          return {
            'id': equipo['id'],
            'cod_barras': equipo['cod_barras'],
            'marca_id': equipo['marca_id'],
            'modelo_id': equipo['modelo_id'], // ✅ CORREGIDO: Era 'modelo', ahora es 'modelo_id'
            'numero_serie': equipo['numero_serie'],
            'logo_id': equipo['logo_id'],
            'estado_local': equipo['estado_local'] ?? 1,
            'fecha_creacion': equipo['fecha_creacion'],
          };
        }).toList();

        await _equipoRepo.sincronizarDesdeAPI(equiposLimpios);

        return SyncResult(
          exito: true,
          mensaje: 'Equipos sincronizados correctamente',
          itemsSincronizados: equiposLimpios.length,
          totalEnAPI: equiposLimpios.length,
        );
      } else {
        final mensaje = _extraerMensajeError(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: _getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarAsignaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/asignaciones'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> asignacionesData = _parseResponse(response.body);

        if (asignacionesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay asignaciones en el servidor',
            itemsSincronizados: 0,
          );
        }

        final asignacionesLimpias = asignacionesData.map((asignacion) {
          return {
            'id': asignacion['id'],
            'equipo_id': asignacion['equipo_id'],
            'cliente_id': asignacion['cliente_id'],
            'fecha_asignacion': asignacion['fecha_asignacion'],
            'fecha_retiro': asignacion['fecha_retiro'],
            'activo': asignacion['activo'] ?? 1,
          };
        }).toList();

        await _equipoClienteRepo.limpiarYSincronizar(asignacionesLimpias);

        return SyncResult(
          exito: true,
          mensaje: 'Asignaciones sincronizadas correctamente',
          itemsSincronizados: asignacionesLimpias.length,
          totalEnAPI: asignacionesLimpias.length,
        );
      } else {
        final mensaje = _extraerMensajeError(response);
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: _getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<int> subirRegistrosEquipos() async {
    try {
      final registrosPendientes = await _dbHelper.consultar(
        'registros_equipos',
        where: 'estado_sincronizacion = ?',
        whereArgs: ['pendiente'],
        orderBy: 'fecha_registro ASC',
        limit: 50,
      );

      if (registrosPendientes.isEmpty) return 0;

      int exitosos = 0;

      for (final registro in registrosPendientes) {
        try {
          final estadoData = {
            'equipo_id': registro['equipo_id'],
            'cliente_id': registro['cliente_id'],
            'usuario_id': 1,
            'funcionando': registro['funcionando'] ?? 1,
            'estado_general': registro['estado_general'] ?? 'Revisión móvil',
            'temperatura_actual': registro['temperatura_actual'],
            'temperatura_freezer': registro['temperatura_freezer'],
            'latitud': registro['latitud'],
            'longitud': registro['longitud'],
          };

          final response = await http.post(
            Uri.parse('$baseUrl/estados'),
            headers: _headers,
            body: jsonEncode(estadoData),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 201) {
            await _dbHelper.actualizar(
              'registros_equipos',
              {
                'estado_sincronizacion': 'sincronizado',
                'fecha_actualizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
            exitosos++;
          } else {
            await _dbHelper.actualizar(
              'registros_equipos',
              {
                'estado_sincronizacion': 'error',
                'fecha_actualizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
          }
        } catch (e) {
          _logger.w('Error subiendo registro ${registro['id']}: $e');
        }
      }

      return exitosos;
    } catch (e) {
      _logger.e('Error en subida de registros: $e');
      return 0;
    }
  }

  static Future<int> crearRegistroEquipo({
    required int clienteId,
    String? clienteNombre,
    String? clienteDireccion,
    String? clienteTelefono,
    int? equipoId,
    String? codigoBarras,
    String? modelo,
    int? marcaId,
    String? numeroSerie,
    int? logoId,
    String? observaciones,
    double? latitud,
    double? longitud,
    bool funcionando = true,
    String? estadoGeneral,
    double? temperaturaActual,
    double? temperaturaFreezer,
    String? versionApp,
    String? dispositivo,
  }) async {
    try {
      final now = DateTime.now();
      final idLocal = now.millisecondsSinceEpoch;

      final registroData = {
        'id_local': idLocal,
        'servidor_id': null,
        'estado_sincronizacion': 'pendiente',
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_direccion': clienteDireccion,
        'cliente_telefono': clienteTelefono,
        'equipo_id': equipoId,
        'codigo_barras': codigoBarras,
        'modelo': modelo,
        'marca_id': marcaId,
        'numero_serie': numeroSerie,
        'logo_id': logoId,
        'observaciones': observaciones,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_registro': now.toIso8601String(),
        'timestamp_gps': now.toIso8601String(),
        'funcionando': funcionando ? 1 : 0,
        'estado_general': estadoGeneral ?? 'Revisión desde móvil',
        'temperatura_actual': temperaturaActual,
        'temperatura_freezer': temperaturaFreezer,
        'version_app': versionApp,
        'dispositivo': dispositivo,
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
      };

      final id = await _dbHelper.insertar('registros_equipos', registroData);
      _logger.i('Registro de equipo creado con ID local: $idLocal');

      return id;
    } catch (e) {
      _logger.e('Error creando registro de equipo: $e');
      rethrow;
    }
  }

  static Future<ApiResponse> enviarClienteAAPI(Cliente cliente) async {
    try {
      final clienteData = {
        'nombre': cliente.nombre,
        'email': cliente.email,
        'telefono': cliente.telefono ?? '',
        'direccion': cliente.direccion ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/clientes'),
        headers: _headers,
        body: jsonEncode(clienteData),
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic>? parsedData;

        try {
          if (response.body.trim().isNotEmpty) {
            parsedData = jsonDecode(response.body);
          }
        } catch (e) {
          _logger.w('No se pudo parsear la respuesta JSON: $e');
        }

        return ApiResponse(
          exito: true,
          mensaje: 'Cliente enviado correctamente al servidor',
          datos: parsedData,
          codigoEstado: response.statusCode,
        );
      } else {
        final mensajeError = _extraerMensajeError(response);

        return ApiResponse(
          exito: false,
          mensaje: mensajeError,
          codigoEstado: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: _getErrorMessage(e),
      );
    }
  }

  static Future<SyncResult> enviarClientesPendientes() async {
    try {
      final clientesPendientes = await _clienteRepo.obtenerNoSincronizados();

      if (clientesPendientes.isEmpty) {
        return SyncResult(
          exito: true,
          mensaje: 'No hay clientes pendientes por sincronizar',
          itemsSincronizados: 0,
        );
      }

      int exitosos = 0;
      int fallidos = 0;

      for (final cliente in clientesPendientes) {
        try {
          final resultado = await enviarClienteAAPI(cliente);

          if (resultado.exito) {
            exitosos++;
            if (cliente.id != null) {
              await _clienteRepo.marcarComoSincronizados([cliente.id!]);
            }
          } else {
            fallidos++;
          }

          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          fallidos++;
        }
      }

      final mensaje = fallidos == 0
          ? 'Todos los clientes enviados correctamente ($exitosos/$exitosos)'
          : exitosos > 0
          ? 'Envío parcial: $exitosos exitosos, $fallidos fallidos'
          : 'No se pudo enviar ningún cliente';

      return SyncResult(
        exito: exitosos > 0,
        mensaje: mensaje,
        itemsSincronizados: exitosos,
      );
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error inesperado: ${e.toString()}',
        itemsSincronizados: 0,
      );
    }
  }

  static Future<ApiResponse> probarConexion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Map<String, dynamic>? serverInfo;

        try {
          if (response.body.trim().isNotEmpty) {
            serverInfo = jsonDecode(response.body);
          }
        } catch (e) {
          _logger.w('No se pudo parsear info del servidor: $e');
        }

        return ApiResponse(
          exito: true,
          mensaje: 'Conexión exitosa con el servidor ($baseUrl)',
          datos: serverInfo,
        );
      } else {
        return ApiResponse(
          exito: false,
          mensaje: 'Servidor no disponible (${response.statusCode})',
          codigoEstado: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        exito: false,
        mensaje: _getErrorMessage(e),
      );
    }
  }

  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final estadisticasDB = await _clienteRepo.obtenerEstadisticas();
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

  static List<dynamic> _parseResponse(String responseBody) {
    try {
      final responseData = jsonDecode(responseBody.trim());

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];

          if (data is List) {
            return data;
          }

          if (data is Map<String, dynamic>) {
            final knownFields = ['equipos', 'asignaciones', 'clientes', 'estados'];
            for (final field in knownFields) {
              if (data.containsKey(field) && data[field] is List) {
                return data[field] as List;
              }
            }

            for (final entry in data.entries) {
              if (entry.value is List) {
                return entry.value as List;
              }
            }
          }
        }
        return [];
      }

      if (responseData is List) {
        return responseData;
      }

      return [];
    } catch (e) {
      _logger.e('Error parseando respuesta JSON: $e');
      return [];
    }
  }

  static Cliente? _crearClienteDesdeAPI(dynamic clienteJson) {
    try {
      if (clienteJson is! Map<String, dynamic>) {
        return null;
      }

      final data = clienteJson;

      if (data['nombre'] == null || data['nombre'].toString().trim().isEmpty) {
        return null;
      }

      if (data['email'] == null || data['email'].toString().trim().isEmpty) {
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
    } catch (e) {
      return null;
    }
  }

  static DateTime? _parsearFecha(dynamic fechaString) {
    if (fechaString == null) return null;

    try {
      final fechaStr = fechaString.toString();

      if (fechaStr.contains('T') || fechaStr.contains('Z')) {
        return DateTime.parse(fechaStr);
      }

      if (fechaStr.contains('-')) {
        return DateTime.parse(fechaStr);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String _extraerMensajeError(http.Response response) {
    try {
      if (response.body.trim().isEmpty) {
        return 'Error del servidor (${response.statusCode})';
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      return errorData['message'] ??
          errorData['error'] ??
          errorData['mensaje'] ??
          'Error del servidor (${response.statusCode})';
    } catch (e) {
      return 'Error del servidor (${response.statusCode}): ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}';
    }
  }

  static String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Sin conexión al servidor. Verifica que estés en la misma red WiFi.';
    } else if (error is TimeoutException) {
      return 'Tiempo de espera agotado. Verifica que el servidor esté ejecutándose.';
    } else if (error is HttpException) {
      return 'Error en la comunicación con el servidor.';
    } else {
      return 'Error inesperado: ${error.toString()}';
    }
  }
}

class SyncResult {
  final bool exito;
  final String mensaje;
  final int itemsSincronizados;
  final int totalEnAPI;

  SyncResult({
    required this.exito,
    required this.mensaje,
    required this.itemsSincronizados,
    this.totalEnAPI = 0,
  });

  @override
  String toString() {
    return 'SyncResult(exito: $exito, mensaje: $mensaje, sincronizados: $itemsSincronizados, total: $totalEnAPI)';
  }
}

class SyncResultUnificado {
  bool exito = false;
  String mensaje = '';
  String estadoActual = '';

  bool conexionOK = false;

  bool clientesExito = false;
  int clientesSincronizados = 0;
  String? erroresClientes;

  bool equiposExito = false;
  int equiposSincronizados = 0;
  String? erroresEquipos;

  bool asignacionesExito = false;
  int asignacionesSincronizadas = 0;
  String? erroresAsignaciones;

  @override
  String toString() {
    return 'SyncResultUnificado(exito: $exito, clientes: $clientesSincronizados, equipos: $equiposSincronizados, asignaciones: $asignacionesSincronizadas, mensaje: $mensaje)';
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
    return 'ApiResponse(exito: $exito, mensaje: $mensaje, codigo: $codigoEstado)';
  }
}
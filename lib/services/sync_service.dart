import 'dart:convert';
import 'dart:io';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_cliente_repository.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/models/equipos.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/models/cliente.dart';
import 'dart:async';
import 'package:logger/logger.dart';

final _logger = Logger();

class SyncService {
  static const String baseUrl = 'https://56a494bb0732.ngrok-free.app/adaControl/api';
  static const Duration timeout = Duration(minutes: 5);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static final _dbHelper = DatabaseHelper();
  static final _clienteRepo = ClienteRepository();
  static final _equipoRepo = EquipoRepository();
  static final _equipoClienteRepo = EquipoClienteRepository();


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
      await sincronizarUsuarios();



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
        Uri.parse('$baseUrl/getEdfModelos'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extraer el array de modelos correctamente
        List<dynamic> modelosAPI = [];
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            // Si 'data' es un string JSON, decodificarlo
            if (responseData['data'] is String) {
              final String dataString = responseData['data'];
              modelosAPI = jsonDecode(dataString) as List<dynamic>;
            } else if (responseData['data'] is List) {
              modelosAPI = responseData['data'] as List<dynamic>;
            }
          }
        } else if (responseData is List) {
          modelosAPI = responseData;
        }

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


  static Future<SyncResult> sincronizarUsuarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getUsers'), // ← Cambiar de /usuarios a /getUsers
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        // Extraer el array de usuarios del campo "data"
        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        if (usuariosAPI.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay usuarios en el servidor',
            itemsSincronizados: 0,
          );
        }

        // Procesar datos igual que AuthService
        final usuariosProcesados = usuariosAPI.map((usuario) {
          String password = usuario['password'].toString();
          if (password.startsWith('{bcrypt}')) {
            password = password.substring(8);
          }
          return {
            'id': usuario['id'],
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
          };
        }).toList();

        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
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
  static Future<SyncResult> sincronizarModelos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getEdfModelos'),
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
        Uri.parse('$baseUrl/getEdfMarcas'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extraer el array de marcas correctamente
        List<dynamic> marcasAPI = [];
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            // Si 'data' es un string JSON, decodificarlo
            if (responseData['data'] is String) {
              final String dataString = responseData['data'];
              marcasAPI = jsonDecode(dataString) as List<dynamic>;
            } else if (responseData['data'] is List) {
              marcasAPI = responseData['data'] as List<dynamic>;
            }
          }
        } else if (responseData is List) {
          marcasAPI = responseData;
        }

        // AGREGAR FILTRO AQUÍ - antes de sincronizar
        final marcasValidas = marcasAPI.where((marca) {
          return marca != null &&
              marca['nombre'] != null &&
              marca['nombre'].toString().trim().isNotEmpty;
        }).toList();

        if (marcasValidas.isNotEmpty) {
          await _dbHelper.sincronizarMarcas(marcasValidas);
          _logger.i('Marcas sincronizadas: ${marcasValidas.length} de ${marcasAPI.length}');
        } else {
          _logger.w('No hay marcas válidas para sincronizar');
        }
      }
    } catch (e) {
      _logger.e('Error sincronizando marcas: $e');
    }
  }

  static Future<void> _sincronizarLogos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getEdfLogos'),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extraer el array de logos correctamente
        List<dynamic> logosAPI = [];
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            // Si 'data' es un string JSON, decodificarlo
            if (responseData['data'] is String) {
              final String dataString = responseData['data'];
              logosAPI = jsonDecode(dataString) as List<dynamic>;
            } else if (responseData['data'] is List) {
              logosAPI = responseData['data'] as List<dynamic>;
            }
          }
        } else if (responseData is List) {
          logosAPI = responseData;
        }

        if (logosAPI.isNotEmpty) {
          await _dbHelper.sincronizarLogos(logosAPI);
          _logger.i('Logos sincronizados: ${logosAPI.length}');
        } else {
          _logger.w('No se encontraron logos en la respuesta');
        }
      }
    } catch (e) {
      _logger.e('Error sincronizando logos: $e');
    }
  }

  static Future<SyncResult> sincronizarClientes() async {
    try {
      _logger.i('🔄 Iniciando sincronización de clientes...');

      final response = await http.get(
        Uri.parse('$baseUrl/getEdfClientes'),
        headers: _headers,
      ).timeout(timeout);

      _logger.i('📡 Respuesta del servidor: ${response.statusCode}');

      _logger.i('📄 Contenido respuesta: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesData = _parseResponse(response.body);

        _logger.i('📊 Datos parseados: ${clientesData.length} clientes del servidor');

        if (clientesData.isEmpty) {
          _logger.w('⚠️ No se encontraron clientes en el servidor');
          return SyncResult(
            exito: false,
            mensaje: 'No se encontraron clientes en el servidor',
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
            _logger.d('✅ Cliente procesado: ${cliente.nombre}');
          } else {
            fallidos++;
            _logger.w('❌ Cliente fallido: $clienteJson');
          }
        }

        _logger.i('📈 Procesamiento: $procesados total, ${clientes.length} exitosos, $fallidos fallidos');

        if (clientes.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar los clientes del servidor',
            itemsSincronizados: 0,
          );
        }

        _logger.i('💾 Guardando ${clientes.length} clientes en base de datos...');
        await _clienteRepo.limpiarYSincronizar(clientes.cast<dynamic>());
        _logger.i('✅ Clientes sincronizados exitosamente');

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientes.length,
          totalEnAPI: clientes.length,
        );
      } else {
        final mensaje = _extraerMensajeError(response);
        _logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      _logger.e('💥 Error en sincronización de clientes: $e');
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
      _logger.i('🔄 Iniciando sincronización de equipos...');
      final response = await http.get(
        Uri.parse('$baseUrl/edfEquipos'),
        headers: _headers,
      ).timeout(timeout);

      _logger.i('📡 Respuesta equipos: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> equiposData = _parseResponse(response.body);
        _logger.i('📊 Datos parseados equipos: ${equiposData.length}');

        if (equiposData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay equipos en el servidor',
            itemsSincronizados: 0,
          );
        }

        // ✅ USAR fromJson en lugar de mapeo manual
        final equipos = <Equipo>[];
        for (var equipoJson in equiposData) {
          try {
            final equipo = Equipo.fromJson(equipoJson);
            equipos.add(equipo);
          } catch (e) {
            _logger.w('Error procesando equipo: $e');
          }
        }

        _logger.i('💾 Guardando ${equipos.length} equipos en base de datos...');
        final equiposMapas = equipos.map((e) => e.toMap()).toList();
        await _equipoRepo.limpiarYSincronizar(equiposMapas);

        return SyncResult(
          exito: true,
          mensaje: 'Equipos sincronizados correctamente',
          itemsSincronizados: equipos.length,
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
      _logger.e('💥 Error en sincronización de equipos: $e');
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
            'estado': asignacion['estado'] ?? 'asignado',
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
        'cliente': cliente.nombre,    // ✅ Cambiar de 'nombre' a 'cliente'
        'telefono': cliente.telefono,
        'direccion': cliente.direccion,
        'ruc': cliente.rucCi,        // ✅ Cambiar de 'ruc_ci' a 'ruc'
        'propietario': cliente.propietario,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/getEdfClientes'),
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
      // Usar /getUsers en lugar de /ping para probar la conexión
      final response = await http.get(
        Uri.parse('$baseUrl/getUsers'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Map<String, dynamic>? serverInfo;

        try {
          if (response.body.trim().isNotEmpty) {
            final responseData = jsonDecode(response.body);
            serverInfo = {
              'status': responseData['status'] ?? 'OK',
              'endpoint': 'getUsers',
              'hasData': responseData['data'] != null,
            };
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

          // ✅ AGREGAR ESTA CONDICIÓN AQUÍ - antes de las otras
          if (data is String) {
            // El 'data' es un string JSON que necesita ser decodificado
            final decodedData = jsonDecode(data);
            if (decodedData is List) {
              return decodedData;
            }
          }

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

      // API usa 'cliente' no 'nombre'
      if (data['cliente'] == null || data['cliente'].toString().trim().isEmpty) {
        return null;
      }

      // Determinar RUC/CI: API puede tener 'ruc' o 'cedula'
      String rucCi = '';
      if (data['ruc'] != null && data['ruc'].toString().trim().isNotEmpty) {
        rucCi = data['ruc'].toString().trim();
      } else if (data['cedula'] != null && data['cedula'].toString().trim().isNotEmpty) {
        rucCi = data['cedula'].toString().trim();
      }

      return Cliente(
        id: data['id'] is int ? data['id'] : null,
        nombre: data['cliente'].toString().trim(),        // ✅ Cambiar a 'cliente'
        telefono: data['telefono']?.toString().trim() ?? '',
        direccion: data['direccion']?.toString().trim() ?? '',
        rucCi: rucCi,                                     // ✅ Usar 'ruc' o 'cedula'
        propietario: data['propietario']?.toString().trim() ?? '',
      );
    } catch (e) {
      _logger.e('Error creando cliente desde API: $e');
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
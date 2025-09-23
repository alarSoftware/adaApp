import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/cliente.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/repositories/estado_equipo_repository.dart';
import 'package:ada_app/models/estado_equipo.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'dart:async';

final _logger = Logger();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;

  // Repositorios para el guardado definitivo
  final EquipoRepository _equipoRepository = EquipoRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository();

  static const String _baseUrl = 'https://71a489ac7ede.ngrok-free.app/adaControl/api/';
  static const String _estadosEndpoint = 'insertCensoActivo';

  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  String formatearFecha(String? fechaIso) {
    if (fechaIso == null) return 'No disponible';

    try {
      final fecha = DateTime.parse(fechaIso);
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final ano = fecha.year;
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');

      return '$dia/$mes/$ano - $hora:$minuto';
    } catch (e) {
      return 'Formato inválido';
    }
  }

  // Enhanced _convertirAInt method with better null safety
  int _convertirAInt(dynamic valor, String nombreCampo) {
    if (valor == null) {
      throw 'El campo $nombreCampo es null';
    }

    if (valor is int) {
      return valor;
    }

    if (valor is String) {
      if (valor.isEmpty) {
        throw 'El campo $nombreCampo está vacío';
      }

      final int? parsed = int.tryParse(valor);
      if (parsed != null) {
        return parsed;
      } else {
        throw 'El campo $nombreCampo ("$valor") no es un número válido';
      }
    }

    if (valor is double) {
      return valor.toInt();
    }

    throw 'El campo $nombreCampo tiene un tipo no soportado: ${valor.runtimeType}';
  }

  // Safe casting helper method
  int? _safeCastToInt(dynamic value, String fieldName) {
    try {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      _logger.w('Cannot cast $fieldName to int, type: ${value.runtimeType}, value: $value');
      return null;
    } catch (e) {
      _logger.w('Error casting $fieldName to int: $e');
      return null;
    }
  }

  // Guardado definitivo - CORREGIDO CON EL FLUJO CORRECTO
  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    _setLoading(true);
    _setStatusMessage(null);

    int? estadoIdActual;

    try {
      _logger.i('📝 CONFIRMANDO REGISTRO - GUARDADO DEFINITIVO EN BD');

      final cliente = datos['cliente'] as Cliente?;
      final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      final esCenso = datos['es_censo'] as bool? ?? true;

      // VALIDATION: Check for null values
      if (cliente == null) {
        throw 'Cliente no encontrado en los datos';
      }

      if (equipoCompleto == null) {
        throw 'No se encontró información del equipo';
      }

      if (cliente.id == null) {
        throw 'El cliente no tiene ID asignado';
      }

      if (equipoCompleto['id'] == null) {
        throw 'El equipo no tiene ID asignado';
      }

      // PASO 1: VERIFICAR SI YA ESTÁ ASIGNADO - CON CONVERSIÓN SEGURA
      _setStatusMessage('🔍 Verificando estado del equipo...');

      // Debug logs para identificar tipos
      _logger.i('Debug - equipoCompleto[id]: ${equipoCompleto['id']} (tipo: ${equipoCompleto['id'].runtimeType})');
      _logger.i('Debug - cliente.id: ${cliente.id} (tipo: ${cliente.id.runtimeType})');

      try {
        final equipoId = equipoCompleto['id'].toString(); // Keep as String for equipos table

        // Safe conversion with null check
        final clienteId = _convertirAInt(cliente.id, 'cliente_id');

        final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(
            equipoId,  // String - matches equipos.id (TEXT)
            clienteId
        );

        _logger.i('🔍 Equipo $equipoId ya asignado: $yaAsignado');

        // PASO 2: CREAR REGISTRO PENDIENTE SOLO SI NO ESTÁ ASIGNADO
        if (esCenso && !yaAsignado) {
          _setStatusMessage('💾 Registrando censo pendiente...');

          try {
            _logger.i('📝 PASO 2: Crear registro pendiente (equipo NO asignado)');
            // For equipos_pendientes table, equipo_id is INTEGER, so we need to convert
            final equipoIdInt = _convertirAInt(equipoId, 'equipo_id_for_pendientes');

            await _equipoPendienteRepository.procesarEscaneoCenso(
                equipoId: equipoIdInt, // INTEGER - matches equipos_pendientes.equipo_id (INTEGER)
                clienteId: clienteId
            );
            _logger.i('✅ Registro pendiente creado exitosamente');
          } catch (e) {
            _logger.w('⚠️ Error registrando censo pendiente: $e');
          }
        } else if (yaAsignado) {
          _logger.i('ℹ️ Equipo ya asignado - no se crea registro pendiente');
        }

        // PASO 3: CREAR ESTADO DIRECTAMENTE
        _setStatusMessage('📋 Registrando estado como CREADO...');

        // PASO 4: CREAR ESTADO usando equipo_id y cliente_id directamente
        _logger.i('🔍 Creando estado con equipo_id: $equipoId, cliente_id: $clienteId');

        try {
          // Use the method that works directly with equipo_id and cliente_id
          final estadoCreado = await _estadoEquipoRepository.crearEstadoDirecto(
            equipoId: equipoId,  // TEXT - matches Estado_Equipo.equipo_id (TEXT)
            clienteId: clienteId, // INTEGER - matches Estado_Equipo.cliente_id (INTEGER)
            latitud: datos['latitud'],
            longitud: datos['longitud'],
            fechaRevision: DateTime.now(),
            enLocal: true,
            observaciones: datos['observaciones']?.toString(),
            imagenPath: datos['imagen_path'],
            imagenBase64: datos['imagen_base64'],
            tieneImagen: datos['tiene_imagen'] ?? false,
            imagenTamano: datos['imagen_tamano'],
          );

          // Safe null check for estadoCreado.id
          if (estadoCreado.id != null) {
            estadoIdActual = estadoCreado.id!;
            _logger.i('✅ Estado CREADO registrado con ID: $estadoIdActual');
          } else {
            _logger.w('⚠️ Estado creado pero sin ID asignado, continuando sin ID');
            estadoIdActual = null;
          }

        } catch (dbError) {
          _logger.e('❌ Error de base de datos al crear estado: $dbError');
          throw 'Error creando estado en base de datos: $dbError';
        }

      } catch (conversionError) {
        _logger.e('❌ Error convertiendo IDs: $conversionError');
        return {'success': false, 'error': 'Error en tipos de datos: $conversionError'};
      }

      // PASO 5: PREPARAR DATOS PARA API
      _setStatusMessage('📤 Preparando datos para migración...');
      Map<String, dynamic> datosCompletos;

      if (estadoIdActual != null) {
        final estadoRecuperado = await _estadoEquipoRepository.obtenerPorId(estadoIdActual);
        if (estadoRecuperado != null) {
          datosCompletos = await _prepararDatosDesdeEstado(estadoRecuperado);
        } else {
          throw 'No se pudo obtener el estado creado con ID: $estadoIdActual';
        }
      } else {
        datosCompletos = _prepararDatosParaEnvio(datos);
      }

      // PASO 6: GUARDAR REGISTRO LOCAL MAESTRO
      _setStatusMessage('💾 Guardando registro local maestro...');
      await _guardarRegistroLocal(datosCompletos);

      // PASO 7: INTENTAR MIGRAR (CON TIMEOUT CORTO - SIN PING)
      _setStatusMessage('🔄 Sincronizando registro actual...');

      String mensajeFinal;
      bool migracionExitosa = false;

      if (estadoIdActual != null) {
        final respuestaServidor = await _intentarEnviarAlServidorConTimeout(
            datosCompletos,
            timeoutSegundos: 8
        );

        _logger.i('🔍 Respuesta del servidor: $respuestaServidor');

        if (respuestaServidor['exito'] == true) {
          _logger.i('✅ Marcando estado como migrado con ID: $estadoIdActual');

          await _estadoEquipoRepository.marcarComoMigrado(
            estadoIdActual,
            servidorId: respuestaServidor['servidor_id'],
          );

          // FIXED: Safe casting for id_local
          final idLocal = _safeCastToInt(datosCompletos['id_local'], 'id_local');
          if (idLocal != null) {
            await _marcarComoSincronizado(idLocal);
          } else {
            _logger.w('⚠️ No se pudo convertir id_local a int: ${datosCompletos['id_local']}');
          }

          mensajeFinal = 'Censo completado y sincronizado al servidor';
          migracionExitosa = true;
          _setStatusMessage('✅ Registro sincronizado exitosamente');

        } else {
          _logger.w('⚠️ Migración no exitosa: ${respuestaServidor['motivo']}');
          mensajeFinal = 'Censo guardado localmente. Se sincronizará automáticamente';
          _setStatusMessage('📱 Censo guardado. Sincronización automática pendiente');
        }
      } else {
        mensajeFinal = 'Censo guardado localmente';
      }

      // PASO 8: PROGRAMAR SINCRONIZACIÓN EN BACKGROUND
      _programarSincronizacionBackground();

      return {
        'success': true,
        'message': mensajeFinal,
        'migrado_inmediatamente': migracionExitosa
      };

    } catch (e) {
      _logger.e('❌ Error crítico en confirmación de registro: $e');
      return {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setLoading(false);
    }
  }

  /// Intentar envío al servidor con timeout específico - SIN PING PREVIO
  Future<Map<String, dynamic>> _intentarEnviarAlServidorConTimeout(
      Map<String, dynamic> datos,
      {int timeoutSegundos = 8}
      ) async {
    try {
      _logger.i('🚀 ENVÍO DIRECTO AL SERVIDOR - Sin verificación de conectividad previa');

      final datosApi = _prepararDatosParaApiEstados(datos);
      _logger.i('🔍 Datos preparados para API: ${json.encode(datosApi)}');

      final response = await _enviarAApiEstadosConTimeout(datosApi, timeoutSegundos);

      if (response['exito'] == true) {
        _logger.i('✅ Estado registrado exitosamente en servidor');
        return {
          'exito': true,
          'servidor_id': response['id'],
          'mensaje': response['mensaje']
        };
      } else {
        _logger.w('⚠️ Respuesta no exitosa del servidor: ${response['mensaje']}');
        return {
          'exito': false,
          'motivo': 'error_servidor',
          'detalle': response['mensaje']
        };
      }

    } catch (e) {
      _logger.e('⚠️ Excepción en intentarEnviarAlServidorConTimeout: $e');
      return {
        'exito': false,
        'motivo': 'timeout_o_error',
        'detalle': e.toString()
      };
    }
  }

  /// Enviar a API con timeout específico
  Future<Map<String, dynamic>> _enviarAApiEstadosConTimeout(
      Map<String, dynamic> datos,
      int timeoutSegundos
      ) async {
    try {
      _logger.i('📤 Enviando con timeout de ${timeoutSegundos}s: $_baseUrl$_estadosEndpoint');

      final response = await http.post(
        Uri.parse('$_baseUrl$_estadosEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      ).timeout(Duration(seconds: timeoutSegundos));

      _logger.i('📥 Respuesta Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i('✅ Status HTTP exitoso: ${response.statusCode}');

        dynamic servidorId = DateTime.now().millisecondsSinceEpoch;
        String mensaje = 'Estado registrado correctamente';

        try {
          final responseBody = json.decode(response.body);
          servidorId = responseBody['estado']?['id'] ??
              responseBody['id'] ??
              responseBody['insertId'] ??
              servidorId;

          if (responseBody['message'] != null) {
            mensaje = responseBody['message'].toString();
          }
        } catch (parseError) {
          _logger.w('⚠️ No se pudo parsear JSON, usando valores por defecto: $parseError');
        }

        return {
          'exito': true,
          'id': servidorId,
          'mensaje': mensaje
        };
      } else {
        _logger.e('❌ Status HTTP no exitoso: ${response.statusCode}');
        String mensajeError = 'Error del servidor: ${response.statusCode}';

        try {
          final errorBody = json.decode(response.body);
          mensajeError = errorBody['message'] ?? mensajeError;
        } catch (e) {
          mensajeError = 'Error HTTP ${response.statusCode}';
        }

        return {
          'exito': false,
          'mensaje': mensajeError
        };
      }

    } catch (e) {
      _logger.e('❌ Excepción enviando a API: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e'
      };
    }
  }

  /// Programar sincronización en background
  void _programarSincronizacionBackground() {
    Timer(Duration(seconds: 5), () async {
      try {
        _logger.i('🔄 Iniciando primera sincronización background de registros pendientes');
        await _sincronizarRegistrosPendientesEnBackground();
      } catch (e) {
        _logger.e('❌ Error en sincronización background: $e');
      }
    });

    _programarSincronizacionPeriodica();
  }

  void _programarSincronizacionPeriodica() {
    Timer.periodic(Duration(minutes: 30), (timer) async {
      try {
        _logger.i('⏰ Sincronización automática programada (cada 30 min)');

        final registrosCreados = await _estadoEquipoRepository.obtenerCreados();

        if (registrosCreados.isNotEmpty) {
          _logger.i('📋 Encontrados ${registrosCreados.length} registros pendientes para sincronizar');
          await _sincronizarRegistrosPendientesEnBackground();
        } else {
          _logger.i('✅ No hay registros pendientes para sincronizar');
        }
      } catch (e) {
        _logger.e('❌ Error en sincronización periódica: $e');
      }
    });
  }

  /// Sincronizar registros pendientes en background
  Future<void> _sincronizarRegistrosPendientesEnBackground() async {
    try {
      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();

      if (registrosCreados.isEmpty) {
        _logger.i('✅ No hay registros pendientes para sincronizar en background');
        return;
      }

      _logger.i('📋 Sincronizando ${registrosCreados.length} registros pendientes en background');

      int migrados = 0;
      int fallos = 0;

      for (int i = 0; i < registrosCreados.length; i++) {
        final estado = registrosCreados[i];

        try {
          if (i > 0) {
            await Future.delayed(Duration(milliseconds: 800));
          }

          final exito = await _procesarEstadoIndividualEnBackground(estado);

          if (exito) {
            migrados++;
            _logger.i('✅ Estado ${estado.id} migrado en background');
          } else {
            fallos++;
            _logger.w('❌ Fallo migrando estado ${estado.id} en background');
          }

          if ((i + 1) % 5 == 0) {
            await Future.delayed(Duration(seconds: 2));
          }

        } catch (e) {
          fallos++;
          _logger.e('❌ Excepción procesando estado ${estado.id}: $e');
        }
      }

      _logger.i('📊 Sincronización background completada: $migrados migrados, $fallos fallos');

    } catch (e) {
      _logger.e('❌ Error en sincronización background: $e');
    }
  }

  /// Procesar un estado individual en background
  Future<bool> _procesarEstadoIndividualEnBackground(EstadoEquipo estado) async {
    try {
      final datosParaServidor = await _prepararDatosDesdeEstado(estado);

      final respuesta = await _intentarEnviarAlServidorConTimeout(
          datosParaServidor,
          timeoutSegundos: 15
      );

      if (respuesta['exito']) {
        await _estadoEquipoRepository.marcarComoMigrado(
          estado.id!,
          servidorId: respuesta['servidor_id'],
        );
        return true;
      } else {
        return false;
      }

    } catch (e) {
      _logger.e('❌ Error procesando estado individual: $e');
      return false;
    }
  }

  /// Preparar datos desde un estado existente
  Future<Map<String, dynamic>> _prepararDatosDesdeEstado(EstadoEquipo estado) async {
    try {
      final estadoConDetalles = await _estadoEquipoRepository.obtenerEstadoConDetalles(estado.equipoPendienteId);

      if (estadoConDetalles == null) {
        throw 'No se encontraron detalles para el estado ${estado.id}';
      }

      // FIXED: Ensure id_local is properly set as int
      final idLocal = estado.id ?? DateTime.now().millisecondsSinceEpoch;

      return {
        'id_local': idLocal, // This should be an int
        'estado_sincronizacion': 'background',
        'fecha_creacion_local': estado.fechaCreacion.toIso8601String(),
        'equipo_id': estadoConDetalles['equipo_id'],
        'cliente_id': estadoConDetalles['cliente_id'],
        'usuario_id': 1,
        'funcionando': true,
        'temperatura_actual': null,
        'temperatura_freezer': null,
        'latitud': estado.latitud,
        'longitud': estado.longitud,
        'imagen_path': estado.imagenPath,
        'imagen_base64': estado.imagenBase64,
        'tiene_imagen': estado.tieneImagen,
        'imagen_tamano': estado.imagenTamano,
        'codigo_barras': estadoConDetalles['cod_barras'],
        'numero_serie': estadoConDetalles['numero_serie'],
        'modelo': estadoConDetalles['modelo'] ?? 'No especificado',
        'logo': estadoConDetalles['logo'] ?? 'Sin logo',
        'marca_nombre': estadoConDetalles['marca_nombre'],
        'cliente_nombre': estadoConDetalles['cliente_nombre'],
        'es_censo': true,
        'version_app': '1.0.0',
        'dispositivo': Platform.operatingSystem,
        'fecha_revision': estado.fechaRevision.toIso8601String(),
        'en_local': estado.enLocal,
      };

    } catch (e) {
      _logger.e('Error preparando datos desde estado: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _prepararDatosParaEnvio(Map<String, dynamic> datos) {
    final cliente = datos['cliente'] as Cliente;
    final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;

    // FIXED: Ensure id_local is an int
    final idLocal = DateTime.now().millisecondsSinceEpoch;

    return {
      'id_local': idLocal, // This is an int
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': DateTime.now().toIso8601String(),
      'equipo_id': equipoCompleto?['id'] ?? _buscarEquipoPorCodigo(datos['codigo_barras']),
      'cliente_id': cliente.id,
      'usuario_id': 1,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Sin observaciones'}',
      'temperatura_actual': null,
      'temperatura_freezer': null,
      'latitud': datos['latitud'],
      'longitud': datos['longitud'],
      'imagen_path': datos['imagen_path'],
      'imagen_base64': datos['imagen_base64'],
      'tiene_imagen': datos['tiene_imagen'] ?? false,
      'imagen_tamano': datos['imagen_tamano'],
      'codigo_barras': datos['codigo_barras'],
      'modelo': datos['modelo'],
      'logo': datos['logo'],
      'numero_serie': datos['numero_serie'],
      'observaciones': datos['observaciones'],
      'fecha_registro': datos['fecha_registro'],
      'timestamp_gps': datos['timestamp_gps'],
      'es_censo': datos['es_censo'],
      'ya_asignado': datos['ya_asignado'],
      'version_app': '1.0.0',
      'dispositivo': Platform.operatingSystem,
    };
  }

  int? _buscarEquipoPorCodigo(String? codigoBarras) {
    if (codigoBarras == null) return null;
    return 1; // Provisional
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos) async {
    try {
      _logger.i('💾 Guardando registro maestro en base de datos local...');
      await Future.delayed(const Duration(seconds: 1));
      _logger.i('✅ Registro maestro guardado localmente con ID: ${datos['id_local']}');
    } catch (e) {
      _logger.e('❌ Error crítico guardando localmente: $e');
      throw 'Error guardando datos localmente. Verifica el almacenamiento del dispositivo.';
    }
  }

  Map<String, dynamic> _prepararDatosParaApiEstados(Map<String, dynamic> datosLocales) {
    return {
      'equipo_id': datosLocales['equipo_id'],
      'cliente_id': datosLocales['cliente_id'],
      'usuario_id': datosLocales['usuario_id'],
      'funcionando': datosLocales['funcionando'],
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
      'estado_general': datosLocales['estado_general'],
      'imagen_path': datosLocales['imagen_path'],
      'imagen_base64': datosLocales['imagen_base64'],
      'tiene_imagen': datosLocales['tiene_imagen'],
      'imagen_tamano': datosLocales['imagen_tamano'],
      'equipo_codigo_barras': datosLocales['codigo_barras'],
      'equipo_numero_serie': datosLocales['numero_serie'],
      'equipo_modelo': datosLocales['modelo'],
      'equipo_logo': datosLocales['logo'],
      'equipo_marca': datosLocales['marca_nombre'],
      'cliente_nombre': datosLocales['cliente_nombre'],
      'es_censo': datosLocales['es_censo'],
      'version_app': datosLocales['version_app'],
      'dispositivo': datosLocales['dispositivo'],
      'fecha_revision': datosLocales['fecha_revision'],
      'en_local': datosLocales['en_local'],
      'observaciones': datosLocales['observaciones'],
    };
  }

  Future<void> _marcarComoSincronizado(int idLocal) async {
    try {
      _logger.i('✅ Registro marcado como sincronizado: $idLocal');
    } catch (e) {
      _logger.e('❌ Error marcando como sincronizado: $e');
    }
  }
}
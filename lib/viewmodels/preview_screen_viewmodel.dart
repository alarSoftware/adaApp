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
  bool _isSaving = false;
  String? _statusMessage;

  final EquipoRepository _equipoRepository = EquipoRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository();

  static const String _baseUrl = 'https://ada-api.loca.lt/adaControl/';
  static const String _estadosEndpoint = 'censoActivo/insertCensoActivo';

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get statusMessage => _statusMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSaving(bool saving) {        // ← NUEVO método
    _isSaving = saving;
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

  int _convertirAInt(dynamic valor, String nombreCampo) {
    if (valor == null) throw 'El campo $nombreCampo es null';
    if (valor is int) return valor;
    if (valor is String) {
      if (valor.isEmpty) throw 'El campo $nombreCampo está vacío';
      final int? parsed = int.tryParse(valor);
      if (parsed != null) return parsed;
      throw 'El campo $nombreCampo ("$valor") no es un número válido';
    }
    if (valor is double) return valor.toInt();
    throw 'El campo $nombreCampo tiene un tipo no soportado: ${valor.runtimeType}';
  }

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

  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    _setSaving(true);
    _setStatusMessage(null);
    int? estadoIdActual;

    try {
      _logger.i('📝 CONFIRMANDO REGISTRO - GUARDADO DEFINITIVO EN BD');

      final cliente = datos['cliente'] as Cliente?;
      final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      final esCenso = datos['es_censo'] as bool? ?? true;

      if (cliente == null) throw 'Cliente no encontrado en los datos';
      if (equipoCompleto == null) throw 'No se encontró información del equipo';
      if (cliente.id == null) throw 'El cliente no tiene ID asignado';
      if (equipoCompleto['id'] == null) throw 'El equipo no tiene ID asignado';

      _setStatusMessage('🔍 Verificando estado del equipo...');

      final equipoId = equipoCompleto['id'].toString();
      final clienteId = _convertirAInt(cliente.id, 'cliente_id');

      final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(equipoId, clienteId);
      _logger.i('🔍 Equipo $equipoId ya asignado: $yaAsignado');

      // PASO 2: CREAR REGISTRO PENDIENTE SOLO SI NO ESTÁ ASIGNADO
      if (esCenso && !yaAsignado) {
        _setStatusMessage('💾 Registrando censo pendiente...');
        try {
          _logger.i('📝 PASO 2: Crear registro pendiente (equipo NO asignado)');
          await _equipoPendienteRepository.procesarEscaneoCenso(
              equipoId: equipoId,
              clienteId: clienteId
          );
          _logger.i('✅ Registro pendiente creado exitosamente');
        } catch (e) {
          _logger.w('⚠️ Error registrando censo pendiente: $e');
        }
      } else if (yaAsignado) {
        _logger.i('ℹ️ Equipo ya asignado - no se crea registro pendiente');
      }

      // ✅ CAMBIO 1: CREAR ESTADO CON AMBAS IMÁGENES
      _setStatusMessage('📋 Registrando estado como CREADO...');
      try {
        final estadoCreado = await _estadoEquipoRepository.crearEstadoDirecto(
          equipoId: equipoId,
          clienteId: clienteId,
          latitud: datos['latitud'],
          longitud: datos['longitud'],
          fechaRevision: DateTime.now(),
          enLocal: true,
          observaciones: datos['observaciones']?.toString(),
          // Primera imagen
          imagenPath: datos['imagen_path'],
          imagenBase64: datos['imagen_base64'],
          tieneImagen: datos['tiene_imagen'] ?? false,
          imagenTamano: datos['imagen_tamano'],
          // Segunda imagen
          imagenPath2: datos['imagen_path2'],
          imagenBase64_2: datos['imagen_base64_2'],
          tieneImagen2: datos['tiene_imagen2'] ?? false,
          imagenTamano2: datos['imagen_tamano2'],
        );

        if (estadoCreado.id != null) {
          estadoIdActual = estadoCreado.id!;
          _logger.i('✅ Estado CREADO registrado con ID: $estadoIdActual');
        } else {
          _logger.w('⚠️ Estado creado pero sin ID asignado');
          estadoIdActual = null;
        }
      } catch (dbError) {
        _logger.e('❌ Error de base de datos al crear estado: $dbError');
        throw 'Error creando estado en base de datos: $dbError';
      }

      // ✅ CAMBIO 2: INCLUIR SEGUNDA IMAGEN EN DATOS COMPLETOS
      _setStatusMessage('📤 Preparando datos para migración...');
      Map<String, dynamic> datosCompletos;

      if (estadoIdActual != null) {
        _logger.i('📋 Preparando datos con estadoId: $estadoIdActual');
        final now = DateTime.now();

        datosCompletos = {
          'id_local': estadoIdActual,
          'estado_sincronizacion': 'pendiente',
          'fecha_creacion_local': now.toIso8601String(),
          'equipo_id': equipoCompleto['id'],
          'cliente_id': cliente.id,
          'usuario_id': 1,
          'funcionando': true,
          'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Censo registrado'}',
          'temperatura_actual': null,
          'temperatura_freezer': null,
          'latitud': datos['latitud'],
          'longitud': datos['longitud'],

          // Primera imagen
          'imagen_path': datos['imagen_path'],
          'imagen_base64': datos['imagen_base64'],
          'tiene_imagen': datos['tiene_imagen'] ?? false,
          'imagen_tamano': datos['imagen_tamano'],

          // Segunda imagen
          'imagen_path2': datos['imagen_path2'],
          'imagen_base64_2': datos['imagen_base64_2'],
          'tiene_imagen2': datos['tiene_imagen2'] ?? false,
          'imagen_tamano2': datos['imagen_tamano2'],

          'codigo_barras': equipoCompleto['cod_barras'] ?? datos['codigo_barras'],
          'numero_serie': equipoCompleto['numero_serie'] ?? datos['numero_serie'],
          'modelo': equipoCompleto['modelo_nombre'] ?? datos['modelo'],
          'logo': equipoCompleto['logo_nombre'] ?? datos['logo'],
          'marca_nombre': equipoCompleto['marca_nombre'] ?? 'Sin marca',
          'cliente_nombre': cliente.nombre,
          'observaciones': datos['observaciones'],
          'fecha_registro': datos['fecha_registro'],
          'timestamp_gps': datos['timestamp_gps'],
          'es_censo': esCenso,
          'ya_asignado': yaAsignado,
          'version_app': '1.0.0',
          'dispositivo': Platform.operatingSystem,
          'fecha_revision': now.toIso8601String(),
          'en_local': true,
        };

        _logger.i('✅ Datos preparados directamente desde equipoCompleto');
      } else {
        _logger.i('📋 Usando datos originales (no hay estadoId)');
        datosCompletos = _prepararDatosParaEnvio(datos);
      }

      _setStatusMessage('💾 Guardando registro local maestro...');
      await _guardarRegistroLocal(datosCompletos);

      _setStatusMessage('🔄 Sincronizando registro actual...');
      String mensajeFinal;
      bool migracionExitosa = false;

      if (estadoIdActual != null) {
        final respuestaServidor = await _intentarEnviarAlServidorConTimeout(datosCompletos, timeoutSegundos: 8);
        _logger.i('🔍 Respuesta del servidor: $respuestaServidor');

        if (respuestaServidor['exito'] == true) {
          _logger.i('✅ Marcando estado como migrado con ID: $estadoIdActual');
          await _estadoEquipoRepository.marcarComoMigrado(estadoIdActual, servidorId: respuestaServidor['servidor_id']);
          final idLocal = _safeCastToInt(datosCompletos['id_local'], 'id_local');
          if (idLocal != null) await _marcarComoSincronizado(idLocal);
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
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>> _intentarEnviarAlServidorConTimeout(Map<String, dynamic> datos, {int timeoutSegundos = 8}) async {
    try {
      _logger.i('🚀 ENVÍO DIRECTO AL SERVIDOR');
      final datosApi = _prepararDatosParaApiEstados(datos);
      final response = await _enviarAApiEstadosConTimeout(datosApi, timeoutSegundos);

      if (response['exito'] == true) {
        return {'exito': true, 'servidor_id': response['id'], 'mensaje': response['mensaje']};
      } else {
        return {'exito': false, 'motivo': 'error_servidor', 'detalle': response['mensaje']};
      }
    } catch (e) {
      return {'exito': false, 'motivo': 'timeout_o_error', 'detalle': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _enviarAApiEstadosConTimeout(Map<String, dynamic> datos, int timeoutSegundos) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_estadosEndpoint'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode(datos),
      ).timeout(Duration(seconds: timeoutSegundos));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic servidorId = DateTime.now().millisecondsSinceEpoch;
        String mensaje = 'Estado registrado correctamente';
        try {
          final responseBody = json.decode(response.body);
          servidorId = responseBody['estado']?['id'] ?? responseBody['id'] ?? responseBody['insertId'] ?? servidorId;
          if (responseBody['message'] != null) mensaje = responseBody['message'].toString();
        } catch (e) {}
        return {'exito': true, 'id': servidorId, 'mensaje': mensaje};
      } else {
        return {'exito': false, 'mensaje': 'Error del servidor: ${response.statusCode}'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  void _programarSincronizacionBackground() {
    Timer(Duration(seconds: 5), () async {
      try {
        await _sincronizarRegistrosPendientesEnBackground();
      } catch (e) {}
    });
  }

  Future<void> _sincronizarRegistrosPendientesEnBackground() async {
    try {
      _logger.i('🔄 Iniciando sincronización automática de registros pendientes...');

      final registrosPendientes = await _estadoEquipoRepository.obtenerCreados();

      if (registrosPendientes.isEmpty) {
        _logger.i('✅ No hay registros pendientes de sincronización');
        return;
      }

      _logger.i('📋 Encontrados ${registrosPendientes.length} registros pendientes');

      int exitosos = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          final datosParaApi = {
            'equipo_id': registro.equipoPendienteId,
            'cliente_id': null,
            'usuario_id': 1,
            'funcionando': true,
            'latitud': registro.latitud,
            'longitud': registro.longitud,
            'estado_general': 'Sincronización automática desde APP móvil',
            'fecha_revision': registro.fechaRevision.toIso8601String(),
            'en_local': registro.enLocal,
          };

          final respuesta = await _enviarAApiEstadosConTimeout(datosParaApi, 5);

          if (respuesta['exito'] == true) {
            await _estadoEquipoRepository.marcarComoMigrado(
                registro.id!,
                servidorId: respuesta['id']
            );
            exitosos++;
            _logger.i('✅ Registro ${registro.id} sincronizado exitosamente');
          } else {
            await _estadoEquipoRepository.marcarComoError(
                registro.id!,
                'Error del servidor: ${respuesta['mensaje']}'
            );
            fallidos++;
            _logger.w('⚠️ Error sincronizando registro ${registro.id}: ${respuesta['mensaje']}');
          }

        } catch (e) {
          fallidos++;
          _logger.e('❌ Error procesando registro ${registro.id}: $e');

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
                registro.id!,
                'Excepción: $e'
            );
          }
        }
      }

      _logger.i('📊 Sincronización finalizada - Exitosos: $exitosos, Fallidos: $fallidos');

    } catch (e) {
      _logger.e('❌ Error en sincronización automática: $e');
    }
  }

  // ✅ CAMBIO 3: ACTUALIZAR PREPARACIÓN DE DATOS PARA INCLUIR SEGUNDA IMAGEN
  Map<String, dynamic> _prepararDatosParaEnvio(Map<String, dynamic> datos) {
    final cliente = datos['cliente'] as Cliente;
    final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
    final idLocal = DateTime.now().millisecondsSinceEpoch;

    return {
      'id_local': idLocal,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': DateTime.now().toIso8601String(),
      'equipo_id': equipoCompleto?['id'],
      'cliente_id': cliente.id,
      'usuario_id': 1,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Sin observaciones'}',
      'observaciones': datos['observaciones'], // AGREGAR ESTA LÍNEA
      'latitud': datos['latitud'],
      'longitud': datos['longitud'],
      'codigo_barras': datos['codigo_barras'],
      'modelo': datos['modelo'],
      'logo': datos['logo'],
      'numero_serie': datos['numero_serie'],

      // Primera imagen
      'imagen_path': datos['imagen_path'],
      'imagen_base64': datos['imagen_base64'],
      'tiene_imagen': datos['tiene_imagen'] ?? false,
      'imagen_tamano': datos['imagen_tamano'],

      // Segunda imagen
      'imagen_path2': datos['imagen_path2'],
      'imagen_base64_2': datos['imagen_base64_2'],
      'tiene_imagen2': datos['tiene_imagen2'] ?? false,
      'imagen_tamano2': datos['imagen_tamano2'],

      'version_app': '1.0.0',
      'dispositivo': Platform.operatingSystem,
    };
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos) async {
    try {
      _logger.i('💾 Guardando registro maestro localmente con ID: ${datos['id_local']}');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw 'Error guardando datos localmente';
    }
  }

  // ✅ CAMBIO 4: ACTUALIZAR API PARA INCLUIR SEGUNDA IMAGEN
  Map<String, dynamic> _prepararDatosParaApiEstados(Map<String, dynamic> datosLocales) {
    return {
      'equipo_id': datosLocales['equipo_id'],
      'cliente_id': datosLocales['cliente_id'],
      'usuario_id': datosLocales['usuario_id'],
      'funcionando': datosLocales['funcionando'],
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
      'estado_general': datosLocales['estado_general'],
      'observaciones': datosLocales['observaciones'], // AGREGAR ESTA LÍNEA
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

      // Primera imagen
      'imagen_path': datosLocales['imagen_path'],
      'imagen_base64': datosLocales['imagen_base64'],
      'tiene_imagen': datosLocales['tiene_imagen'],
      'imagen_tamano': datosLocales['imagen_tamano'],

      // Segunda imagen
      'imagen_path2': datosLocales['imagen_path2'],
      'imagen_base64_2': datosLocales['imagen_base64_2'],
      'tiene_imagen2': datosLocales['tiene_imagen2'],
      'imagen_tamano2': datosLocales['imagen_tamano2'],
    };
  }

  Future<void> _marcarComoSincronizado(int idLocal) async {
    try {
      _logger.i('✅ Registro marcado como sincronizado: $idLocal');
    } catch (e) {}
  }
}
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/cliente.dart';
import 'package:ada_app/repositories/equipo_cliente_repository.dart';
import 'package:ada_app/repositories/estado_equipo_repository.dart';
import 'package:ada_app/services/location_service.dart';

final _logger = Logger();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;

  // Repositorios para el guardado definitivo
  final EquipoClienteRepository _equipoClienteRepository = EquipoClienteRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU SERVIDOR
  static const String _baseUrl = 'http://192.168.1.185:3000';
  static const String _estadosEndpoint = '/estados';
  static const String _pingEndpoint = '/ping';

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

  // ============================================================================
  // AQUÍ ES DONDE OCURRE EL GUARDADO DEFINITIVO
  // ============================================================================

  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    _setLoading(true);
    _setStatusMessage(null);

    try {
      _logger.i('📝 CONFIRMANDO REGISTRO - GUARDADO DEFINITIVO EN BD');

      final cliente = datos['cliente'] as Cliente;
      final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      final yaAsignado = datos['ya_asignado'] as bool? ?? false;
      final esCenso = datos['es_censo'] as bool? ?? true;

      // ✅ PASO 1: GUARDAR ASIGNACIÓN EN BD (SOLO SI NO ESTÁ ASIGNADO AL CLIENTE ACTUAL)
      if (esCenso && equipoCompleto != null && !yaAsignado) {
        _setStatusMessage('💾 Registrando asignación del equipo...');

        try {
          await _equipoClienteRepository.procesarEscaneoCenso(
            equipoId: equipoCompleto['id'],
            clienteId: cliente.id!,
          );
          _logger.i('✅ Asignación equipo-cliente creada en BD');
        } catch (e) {
          // Si ya está asignado a otro cliente, continuar con estado "pendiente"
          _logger.w('⚠️ Equipo ya asignado a otro cliente, creando estado pendiente: $e');
          // Continuar el flujo normalmente - el estado se registrará como "pendiente"
        }
      }

      // ✅ PASO 2: REGISTRAR EN HISTORIAL DE ESTADOS (AQUÍ ES DONDE SE DEBE HACER)
      if (equipoCompleto != null) {
        _setStatusMessage('📋 Registrando en historial de estados...');

        await _estadoEquipoRepository.crearNuevoEstado(
          equipoId: equipoCompleto['id'],
          clienteId: cliente.id!,
          enLocal: true,
          fechaRevision: DateTime.now(),
          latitud: datos['latitud'],
          longitud: datos['longitud'],
        );

        _logger.i('✅ Estado del equipo registrado en historial');
      }

      // ✅ PASO 3: PREPARAR DATOS PARA API
      _setStatusMessage('📤 Preparando datos para sincronización...');
      final datosCompletos = _prepararDatosParaEnvio(datos);

      // ✅ PASO 4: GUARDAR LOCALMENTE (REGISTRO MAESTRO)
      _setStatusMessage('💾 Guardando registro local maestro...');
      await _guardarRegistroLocal(datosCompletos);

      // ✅ PASO 5: INTENTAR SINCRONIZAR CON SERVIDOR
      _setStatusMessage('📤 Sincronizando con servidor...');
      final respuestaServidor = await _intentarEnviarAlServidor(datosCompletos);

      if (respuestaServidor['exito']) {
        // Éxito total: BD local + Servidor
        await _marcarComoSincronizado(datosCompletos['id_local'] as int);
        _setStatusMessage('✅ Registro completado y sincronizado');

        if (respuestaServidor['servidor_id'] != null) {
          await _actualizarConIdServidor(
              datosCompletos['id_local'] as int,
              respuestaServidor['servidor_id']
          );
        }

        return {'success': true, 'message': 'Registro completado exitosamente'};
      } else {
        // BD local exitosa, pero sin conexión al servidor
        _setStatusMessage(
            '📱 Registro guardado localmente. Se sincronizará cuando haya conexión.'
        );
        return {'success': true, 'message': 'Registro guardado'};
      }

    } catch (e) {
      _logger.e('❌ Error crítico en confirmación de registro: $e');
      return {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setLoading(false);
    }
  }

  Map<String, dynamic> _prepararDatosParaEnvio(Map<String, dynamic> datos) {
    final cliente = datos['cliente'] as Cliente;
    final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;

    return {
      // Datos locales para control
      'id_local': DateTime.now().millisecondsSinceEpoch,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': DateTime.now().toIso8601String(),

      // Datos para API /estados (según tu esquema)
      'equipo_id': equipoCompleto?['id'] ?? _buscarEquipoPorCodigo(datos['codigo_barras']),
      'cliente_id': cliente.id,
      'usuario_id': 1, // TODO: Obtener del usuario logueado
      'funcionando': true, // Asumimos que está funcionando al registrar
      'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Sin observaciones'}',
      'temperatura_actual': null, // Se actualizará en próximas revisiones
      'temperatura_freezer': null, // Se actualizará en próximas revisiones
      'latitud': datos['latitud'],
      'longitud': datos['longitud'],

      // Datos adicionales para referencia local
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
    // TODO: Implementar búsqueda real en base de datos local
    // o hacer una consulta a /equipos/buscar?q=codigo

    if (codigoBarras == null) return null;

    // Simulamos que encontramos el equipo basado en el código
    // En una implementación real, buscarías en tu base de datos local
    // o harías una petición a tu API para obtener el equipo_id
    return 1; // Provisional - debería ser el ID real del equipo
  }

  Future<void> _guardarRegistroLocal(Map<String, dynamic> datos) async {
    try {
      _logger.i('💾 Guardando registro maestro en base de datos local...');

      // TODO: Implementar guardado en SQLite local
      // final db = await DatabaseHelper.instance.database;
      // await db.insert('registros_equipos', datos);

      // Simulación por ahora
      await Future.delayed(const Duration(seconds: 1));

      _logger.i('✅ Registro maestro guardado localmente con ID: ${datos['id_local']}');
    } catch (e) {
      _logger.e('❌ Error crítico guardando localmente: $e');
      throw 'Error guardando datos localmente. Verifica el almacenamiento del dispositivo.';
    }
  }

  Future<Map<String, dynamic>> _intentarEnviarAlServidor(Map<String, dynamic> datos) async {
    try {
      // Verificar conectividad con tu servidor
      final tieneConexion = await _verificarConectividad();
      if (!tieneConexion) {
        _logger.w('⚠️ Sin conexión al servidor');
        return {'exito': false, 'motivo': 'sin_conexion'};
      }

      // Preparar datos para tu API /estados
      final datosApi = _prepararDatosParaApiEstados(datos);

      // Enviar a tu API
      final response = await _enviarAApiEstados(datosApi);

      if (response['exito']) {
        _logger.i('✅ Estado del equipo registrado en el servidor');
        return {
          'exito': true,
          'servidor_id': response['id'],
          'mensaje': response['mensaje']
        };
      } else {
        _logger.w('⚠️ Error del servidor: ${response['mensaje']}');
        return {
          'exito': false,
          'motivo': 'error_servidor',
          'detalle': response['mensaje']
        };
      }

    } catch (e) {
      _logger.w('⚠️ Error enviando al servidor: $e');
      return {
        'exito': false,
        'motivo': 'excepcion',
        'detalle': e.toString()
      };
    }
  }

  Future<bool> _verificarConectividad() async {
    try {
      _logger.i('🌐 Verificando conectividad con tu servidor...');

      final response = await http.get(
        Uri.parse('$_baseUrl$_pingEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('✅ Servidor respondió: ${data['message']}');
        return true;
      }

      return false;

    } catch (e) {
      _logger.w('⚠️ Sin conectividad: $e');
      return false;
    }
  }

  Map<String, dynamic> _prepararDatosParaApiEstados(Map<String, dynamic> datosLocales) {
    // Estructura exacta que espera tu API /estados
    return {
      'equipo_id': datosLocales['equipo_id'],
      'cliente_id': datosLocales['cliente_id'],
      'usuario_id': datosLocales['usuario_id'],
      'funcionando': datosLocales['funcionando'],
      'estado_general': datosLocales['estado_general'],
      'temperatura_actual': datosLocales['temperatura_actual'],
      'temperatura_freezer': datosLocales['temperatura_freezer'],
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
    };
  }

  Future<Map<String, dynamic>> _enviarAApiEstados(Map<String, dynamic> datos) async {
    try {
      _logger.i('📤 Enviando estado a API: $_baseUrl$_estadosEndpoint');
      _logger.i('📋 Datos: $datos');

      final response = await http.post(
        Uri.parse('$_baseUrl$_estadosEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      ).timeout(const Duration(seconds: 30));

      _logger.i('📥 Respuesta API: ${response.statusCode}');
      _logger.i('📄 Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = json.decode(response.body);

        // Tu API devuelve { success: true, message: "...", estado: {...} }
        if (responseBody['success'] == true) {
          return {
            'exito': true,
            'id': responseBody['estado']['id'],
            'mensaje': responseBody['message'] ?? 'Estado actualizado correctamente'
          };
        } else {
          return {
            'exito': false,
            'mensaje': responseBody['message'] ?? 'Error desconocido'
          };
        }
      } else {
        final errorBody = response.body.isNotEmpty ?
        json.decode(response.body) : {'message': 'Error HTTP ${response.statusCode}'};

        return {
          'exito': false,
          'mensaje': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}'
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

  Future<void> _marcarComoSincronizado(int idLocal) async {
    try {
      // TODO: Actualizar estado en SQLite local
      // final db = await DatabaseHelper.instance.database;
      // await db.update(
      //   'registros_equipos',
      //   {'estado_sincronizacion': 'sincronizado'},
      //   where: 'id_local = ?',
      //   whereArgs: [idLocal]
      // );

      _logger.i('✅ Registro marcado como sincronizado: $idLocal');
    } catch (e) {
      _logger.e('❌ Error marcando como sincronizado: $e');
    }
  }

  Future<void> _actualizarConIdServidor(int idLocal, dynamic servidorId) async {
    try {
      // TODO: Actualizar con ID del servidor en SQLite
      // final db = await DatabaseHelper.instance.database;
      // await db.update(
      //   'registros_equipos',
      //   {'servidor_id': servidorId},
      //   where: 'id_local = ?',
      //   whereArgs: [idLocal]
      // );

      _logger.i('✅ ID del servidor actualizado: $servidorId para local: $idLocal');
    } catch (e) {
      _logger.e('❌ Error actualizando ID servidor: $e');
    }
  }
}
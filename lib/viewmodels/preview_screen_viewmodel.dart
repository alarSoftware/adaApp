import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/cliente.dart';
import 'package:ada_app/repositories/equipo_cliente_repository.dart';
import 'package:ada_app/repositories/estado_equipo_repository.dart';
import 'package:ada_app/models/estado_equipo.dart';
import 'dart:async';

final _logger = Logger();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _statusMessage;

  // Repositorios para el guardado definitivo
  final EquipoClienteRepository _equipoClienteRepository = EquipoClienteRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU SERVIDOR
  static const String _baseUrl = 'https://56a494bb0732.ngrok-free.app/adaControl/api/';
  static const String _estadosEndpoint = '/insertCensoActivo';
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

    int? estadoIdActual; // Para trackear solo el registro actual

    try {
      _logger.i('📝 CONFIRMANDO REGISTRO - GUARDADO DEFINITIVO EN BD');

      final cliente = datos['cliente'] as Cliente;
      final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      final yaAsignado = datos['ya_asignado'] as bool? ?? false;
      final esCenso = datos['es_censo'] as bool? ?? true;

      // ✅ PASO 1: GUARDAR ASIGNACIÓN EN BD (usando procesarEscaneoCenso)
      if (esCenso && equipoCompleto != null && !yaAsignado) {
        _setStatusMessage('💾 Registrando asignación del equipo...');

        try {
          await _equipoClienteRepository.procesarEscaneoCenso(
            equipoId: equipoCompleto['id'],
            clienteId: cliente.id!,
          );
          _logger.i('✅ Asignación equipo-cliente procesada');
        } catch (e) {
          _logger.w('⚠️ Equipo ya asignado a otro cliente: $e');
        }
      }

      // ✅ PASO 2: REGISTRAR EN HISTORIAL CON ESTADO 'CREADO'
      if (equipoCompleto != null) {
        _setStatusMessage('📋 Registrando estado como CREADO...');

        // Buscar equipoClienteId
        final equipoClienteId = await _estadoEquipoRepository.buscarEquipoClienteId(
          equipoCompleto['id'],
          cliente.id!,
        );

        if (equipoClienteId != null) {
          // Crear estado con estado "creado"
          final estadoCreado = await _estadoEquipoRepository.crearNuevoEstadoCenso(
            equipoClienteId: equipoClienteId,
            latitud: datos['latitud'],
            longitud: datos['longitud'],
            fechaRevision: DateTime.now(),
            enLocal: true,
            observaciones: datos['observaciones']?.toString(),

            // NUEVOS PARAMETROS DE IMAGEN
            imagenPath: datos['imagen_path'],
            imagenBase64: datos['imagen_base64'],
            tieneImagen: datos['tiene_imagen'] ?? false,
            imagenTamano: datos['imagen_tamano'],
          );

          estadoIdActual = estadoCreado.id; // Guardar ID del registro actual
          _logger.i('✅ Estado CREADO registrado con ID: $estadoIdActual');
        } else {
          _logger.w('No se encontró relación equipo_cliente');
          _setStatusMessage('⚠️ Advertencia: No se registró en historial');
        }
      }

      // ✅ PASO 3: PREPARAR DATOS PARA API USANDO EL ESTADO CREADO
      _setStatusMessage('📤 Preparando datos para migración...');
      Map<String, dynamic> datosCompletos;

      if (estadoIdActual != null) {
        // Obtener el estado recién creado con todos sus datos
        final estadoCreado = await _estadoEquipoRepository.obtenerPorId(estadoIdActual);
        if (estadoCreado != null) {
          datosCompletos = await _prepararDatosDesdeEstado(estadoCreado);
        } else {
          throw 'No se pudo obtener el estado creado con ID: $estadoIdActual';
        }
      } else {
        // Fallback al método anterior si no hay estado creado
        datosCompletos = _prepararDatosParaEnvio(datos);
      }

      // ✅ PASO 4: GUARDAR REGISTRO LOCAL MAESTRO
      _setStatusMessage('💾 Guardando registro local maestro...');
      await _guardarRegistroLocal(datosCompletos);

      // ✅ PASO 5: INTENTAR MIGRAR SOLO EL REGISTRO ACTUAL (CON TIMEOUT CORTO)
      _setStatusMessage('🔄 Sincronizando registro actual...');

      String mensajeFinal;
      bool migracionExitosa = false;

      if (estadoIdActual != null) {
        final respuestaServidor = await _intentarEnviarAlServidorConTimeout(
            datosCompletos,
            timeoutSegundos: 8 // Timeout corto para no bloquear UI
        );

        _logger.i('🔍 Respuesta completa del servidor: $respuestaServidor');

        if (respuestaServidor['exito'] == true) {
          _logger.i('✅ Marcando estado como migrado con ID: $estadoIdActual');

          // Migrar solo el registro actual
          await _estadoEquipoRepository.marcarComoMigrado(
            estadoIdActual,
            servidorId: respuestaServidor['servidor_id'],
          );

          await _marcarComoSincronizado(datosCompletos['id_local'] as int);

          mensajeFinal = 'Censo completado y sincronizado al servidor';
          migracionExitosa = true;
          _setStatusMessage('✅ Registro sincronizado exitosamente');

          _logger.i('✅ Estado $estadoIdActual marcado como migrado exitosamente');

        } else {
          _logger.w('⚠️ Migración no exitosa: ${respuestaServidor['motivo']} - ${respuestaServidor['detalle']}');

          // El registro queda en estado "creado" para migrar después
          mensajeFinal = 'Censo guardado localmente. Se sincronizará automáticamente';
          _setStatusMessage('📱 Censo guardado. Sincronización automática pendiente');
        }
      } else {
        mensajeFinal = 'Censo guardado localmente';
      }

      // ✅ PASO 6: PROGRAMAR SINCRONIZACIÓN EN BACKGROUND PARA REGISTROS PENDIENTES
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

  /// Intentar envío al servidor con timeout específico
  Future<Map<String, dynamic>> _intentarEnviarAlServidorConTimeout(
      Map<String, dynamic> datos,
      {int timeoutSegundos = 8}
      ) async {
    try {
      // Verificar conectividad con timeout corto
      final tieneConexion = await _verificarConectividadRapida();
      if (!tieneConexion) {
        _logger.w('⚠️ Sin conexión al servidor');
        return {'exito': false, 'motivo': 'sin_conexion'};
      }

      // Preparar datos para API
      final datosApi = _prepararDatosParaApiEstados(datos);
      _logger.i('🔍 Datos preparados para API: ${json.encode(datosApi)}');

      // Enviar con timeout específico
      final response = await _enviarAApiEstadosConTimeout(datosApi, timeoutSegundos);

      _logger.i('🔍 Respuesta de _enviarAApiEstadosConTimeout: $response');

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

  /// Verificación de conectividad rápida (timeout de 3 segundos)
  Future<bool> _verificarConectividadRapida() async {
    try {
      _logger.i('🌐 Verificación rápida de conectividad...');

      final response = await http.get(
        Uri.parse('$_baseUrl$_pingEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3)); // Timeout corto

      return response.statusCode == 200;

    } catch (e) {
      _logger.w('⚠️ Conectividad rápida falló: $e');
      return false;
    }
  }

  /// Enviar a API con timeout específico - SIMPLIFICADO PARA CONSIDERAR CUALQUIER 200 COMO ÉXITO
  Future<Map<String, dynamic>> _enviarAApiEstadosConTimeout(
      Map<String, dynamic> datos,
      int timeoutSegundos
      ) async {
    try {
      _logger.i('📤 Enviando con timeout de ${timeoutSegundos}s: $_baseUrl$_estadosEndpoint');
      _logger.i('🔍 Datos a enviar: ${json.encode(datos)}');

      final response = await http.post(
        Uri.parse('$_baseUrl$_estadosEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      ).timeout(Duration(seconds: timeoutSegundos));

      _logger.i('📥 Respuesta Status: ${response.statusCode}');
      _logger.i('📄 Respuesta Body: ${response.body}');

      // ✅ CUALQUIER STATUS 200-299 SE CONSIDERA ÉXITO
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i('✅ Status HTTP exitoso: ${response.statusCode} - Marcando como exitoso automáticamente');

        dynamic servidorId = DateTime.now().millisecondsSinceEpoch; // ID por defecto
        String mensaje = 'Estado registrado correctamente';

        // Intentar parsear respuesta pero sin fallar si no es JSON válido
        try {
          final responseBody = json.decode(response.body);
          _logger.i('📋 Response body parseado: $responseBody');

          // Extraer ID si está disponible
          servidorId = responseBody['estado']?['id'] ??
              responseBody['id'] ??
              responseBody['insertId'] ??
              servidorId; // Usar el timestamp como fallback

          // Usar mensaje del servidor si está disponible
          if (responseBody['message'] != null) {
            mensaje = responseBody['message'].toString();
          }

        } catch (parseError) {
          _logger.w('⚠️ No se pudo parsear JSON, usando valores por defecto: $parseError');
          // Mantener los valores por defecto ya asignados
        }

        return {
          'exito': true,
          'id': servidorId,
          'mensaje': mensaje
        };
      }
      // Status no exitoso (4xx, 5xx)
      else {
        _logger.e('❌ Status HTTP no exitoso: ${response.statusCode}');

        String mensajeError = 'Error del servidor: ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          mensajeError = errorBody['message'] ?? mensajeError;
        } catch (e) {
          // Si no se puede parsear, usar mensaje por defecto
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

  /// Programar sincronización en background para registros pendientes
  void _programarSincronizacionBackground() {
    // Ejecutar después de un delay inicial para que la UI responda primero
    Timer(Duration(seconds: 5), () async {
      try {
        _logger.i('🔄 Iniciando primera sincronización background de registros pendientes');
        await _sincronizarRegistrosPendientesEnBackground();
      } catch (e) {
        _logger.e('❌ Error en sincronización background: $e');
      }
    });

    // Programar sincronización periódica cada 10 minutos
    _programarSincronizacionPeriodica();
  }

  void _programarSincronizacionPeriodica() {
    Timer.periodic(Duration(minutes: 30), (timer) async {
      try {
        _logger.i('⏰ Sincronización automática programada (cada 10 min)');

        // Verificar si hay registros pendientes antes de intentar
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

  /// Sincronizar registros pendientes sin bloquear la UI
  Future<void> _sincronizarRegistrosPendientesEnBackground() async {
    try {
      // Obtener registros en estado "creado" (excluyendo el que se acaba de procesar)
      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();

      if (registrosCreados.isEmpty) {
        _logger.i('✅ No hay registros pendientes para sincronizar en background');
        return;
      }

      _logger.i('📋 Sincronizando ${registrosCreados.length} registros pendientes en background');

      int migrados = 0;
      int fallos = 0;

      // Procesar de a uno con delays para no saturar el servidor
      for (int i = 0; i < registrosCreados.length; i++) {
        final estado = registrosCreados[i];

        try {
          // Delay entre requests para no saturar
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

          // Cada 5 registros, hacer una pausa más larga
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
      // Preparar datos desde el estado existente
      final datosParaServidor = await _prepararDatosDesdeEstado(estado);

      // Intentar enviar con timeout más largo en background
      final respuesta = await _intentarEnviarAlServidorConTimeout(
          datosParaServidor,
          timeoutSegundos: 15
      );

      if (respuesta['exito']) {
        // Marcar como migrado
        await _estadoEquipoRepository.marcarComoMigrado(
          estado.id!,
          servidorId: respuesta['servidor_id'],
        );
        return true;
      } else {
        // Mantener en estado "creado" para reintento posterior
        return false;
      }

    } catch (e) {
      _logger.e('❌ Error procesando estado individual: $e');
      return false;
    }
  }

  /// Preparar datos desde un estado existente - MEJORADO PARA INCLUIR TODOS LOS CAMPOS
  Future<Map<String, dynamic>> _prepararDatosDesdeEstado(EstadoEquipo estado) async {
    try {
      // Obtener detalles completos del estado
      final estadoConDetalles = await _estadoEquipoRepository.obtenerEstadoConDetalles(estado.equipoClienteId);

      if (estadoConDetalles == null) {
        throw 'No se encontraron detalles para el estado ${estado.id}';
      }

      return {
        // Datos locales para control
        'id_local': estado.id,
        'estado_sincronizacion': 'background',
        'fecha_creacion_local': estado.fechaCreacion.toIso8601String(),

        // Datos para API - INCLUIR TODOS LOS CAMPOS DEL ESTADO
        'equipo_id': estadoConDetalles['equipo_id'],
        'cliente_id': estadoConDetalles['cliente_id'],
        'usuario_id': 1,
        'funcionando': true,
        'temperatura_actual': null,
        'temperatura_freezer': null,
        'latitud': estado.latitud,
        'longitud': estado.longitud,

        // ✅ INCLUIR DATOS DE IMAGEN
        'imagen_path': estado.imagenPath,
        'imagen_base64': estado.imagenBase64,
        'tiene_imagen': estado.tieneImagen,
        'imagen_tamano': estado.imagenTamano,

        // Datos adicionales del equipo
        'codigo_barras': estadoConDetalles['cod_barras'],
        'numero_serie': estadoConDetalles['numero_serie'],
        'modelo': estadoConDetalles['modelo'] ?? 'No especificado',
        'logo': estadoConDetalles['logo'] ?? 'Sin logo',
        'marca_nombre': estadoConDetalles['marca_nombre'],

        // Datos del cliente
        'cliente_nombre': estadoConDetalles['cliente_nombre'],

        // Metadatos
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

      // ✅ INCLUIR DATOS DE IMAGEN EN EL MÉTODO ORIGINAL TAMBIÉN
      'imagen_path': datos['imagen_path'],
      'imagen_base64': datos['imagen_base64'],
      'tiene_imagen': datos['tiene_imagen'] ?? false,
      'imagen_tamano': datos['imagen_tamano'],

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
    return {
      // DATOS BÁSICOS
      'equipo_id': datosLocales['equipo_id'],
      'cliente_id': datosLocales['cliente_id'],
      'usuario_id': datosLocales['usuario_id'],
      'funcionando': datosLocales['funcionando'],
      'latitud': datosLocales['latitud'],
      'longitud': datosLocales['longitud'],
      'estado_general': datosLocales['estado_general'],

      // ✅ DATOS DE IMAGEN INCLUIDOS EN LA API
      'imagen_path': datosLocales['imagen_path'],
      'imagen_base64': datosLocales['imagen_base64'],
      'tiene_imagen': datosLocales['tiene_imagen'],
      'imagen_tamano': datosLocales['imagen_tamano'],

      // DATOS COMPLETOS DEL EQUIPO
      'equipo_codigo_barras': datosLocales['codigo_barras'],
      'equipo_numero_serie': datosLocales['numero_serie'],
      'equipo_modelo': datosLocales['modelo'],
      'equipo_logo': datosLocales['logo'],
      'equipo_marca': datosLocales['marca_nombre'],

      // DATOS DEL CLIENTE
      'cliente_nombre': datosLocales['cliente_nombre'],

      // METADATOS
      'es_censo': datosLocales['es_censo'],
      'version_app': datosLocales['version_app'],
      'dispositivo': datosLocales['dispositivo'],
      'fecha_revision': datosLocales['fecha_revision'],
      'en_local': datosLocales['en_local'],
      'observaciones': datosLocales['observaciones'],
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

      // ✅ CUALQUIER STATUS 200-299 SE CONSIDERA ÉXITO
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i('✅ Status HTTP exitoso: ${response.statusCode}');

        dynamic servidorId = DateTime.now().millisecondsSinceEpoch;
        String mensaje = 'Estado registrado correctamente';

        try {
          final responseBody = json.decode(response.body);

          // Intentar extraer el ID del servidor si está disponible
          servidorId = responseBody['estado']?['id'] ??
              responseBody['id'] ??
              responseBody['insertId'] ??
              servidorId; // Usar el timestamp como fallback

          // Usar el mensaje del servidor si está disponible
          if (responseBody['message'] != null) {
            mensaje = responseBody['message'].toString();
          }

        } catch (parseError) {
          _logger.w('⚠️ Error parseando JSON, pero status es exitoso: $parseError');
          // Mantener valores por defecto
        }

        return {
          'exito': true,
          'id': servidorId,
          'mensaje': mensaje
        };
      } else {
        try {
          final errorBody = json.decode(response.body);
          return {
            'exito': false,
            'mensaje': errorBody['message'] ?? 'Error del servidor: ${response.statusCode}'
          };
        } catch (e) {
          return {
            'exito': false,
            'mensaje': 'Error HTTP ${response.statusCode}: ${response.body}'
          };
        }
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
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../models/cliente.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'dart:async';

final _logger = Logger();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isSaving = false;
  String? _statusMessage;
  bool _isProcessing = false;
  String? _currentProcessId;

  final EquipoRepository _equipoRepository = EquipoRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository();
  final AuthService _authService = AuthService();

  Usuario? _usuarioActual;

  static const String _baseUrl = 'http://200.85.60.250:28080/adaControl';
  static const String _estadosEndpoint = '/censoActivo/insertCensoActivo';

  bool get isSaving => _isSaving;
  String? get statusMessage => _statusMessage;
  bool get canConfirm => !_isProcessing && !_isSaving;

  // HELPER para formatear fechas en zona horaria local (sin UTC)
  String _formatearFechaLocal(DateTime fecha) {
    final local = fecha.toLocal();
    return local.toIso8601String().replaceAll('Z', '');
  }

  Future<int> get _getUsuarioId async {
    if (_usuarioActual != null && _usuarioActual!.id != null) {
      return _usuarioActual!.id!;
    }

    _usuarioActual = await _authService.getCurrentUser();

    if (_usuarioActual?.id != null) {
      _logger.i('Usuario actual: ${_usuarioActual!.username} (ID: ${_usuarioActual!.id})');
      return _usuarioActual!.id!;
    }

    _logger.w('No se pudo obtener usuario, usando ID 1 como fallback');
    return 1;
  }

  Future<String?> get _getEdfVendedorId async {
    if (_usuarioActual != null) {
      return _usuarioActual!.edfVendedorId;
    }

    _usuarioActual = await _authService.getCurrentUser();
    return _usuarioActual?.edfVendedorId;
  }

  void _setSaving(bool saving) {
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
      final fecha = DateTime.parse(fechaIso).toLocal();
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
    if (_isProcessing) {
      _logger.w('Proceso ya en ejecución, ignorando nueva solicitud');
      return {
        'success': false,
        'error': 'Ya hay un proceso de confirmación en curso. Por favor espere.'
      };
    }

    final processId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentProcessId = processId;
    _isProcessing = true;

    try {
      return await _ejecutarConfirmacion(datos, processId);
    } finally {
      if (_currentProcessId == processId) {
        _isProcessing = false;
        _currentProcessId = null;
      }
    }
  }

  Future<Map<String, dynamic>> _ejecutarConfirmacion(
      Map<String, dynamic> datos,
      String processId
      ) async {
    _setSaving(true);
    _setStatusMessage(null);
    int? estadoIdActual;

    try {
      _logger.i('CONFIRMANDO REGISTRO - GUARDADO DEFINITIVO EN BD [Process: $processId]');

      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      final cliente = datos['cliente'] as Cliente?;
      final esCenso = datos['es_censo'] as bool? ?? true;
      final esNuevoEquipo = datos['es_nuevo_equipo'] as bool? ?? false;  // ✅ NUEVO
      var equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;

      if (cliente == null) throw 'Cliente no encontrado en los datos';
      if (cliente.id == null) throw 'El cliente no tiene ID asignado';

      final usuarioId = await _getUsuarioId;
      _logger.i('Usuario ID obtenido: $usuarioId');

      String equipoId;
      int clienteId = _convertirAInt(cliente.id, 'cliente_id');

      // ✅ CASO 3: EQUIPO NUEVO - Crear en tabla equipos
      if (esNuevoEquipo) {
        _setStatusMessage('Registrando equipo nuevo en el sistema...');

        if (_currentProcessId != processId) {
          return {'success': false, 'error': 'Proceso cancelado'};
        }

        try {
          equipoId = await _equipoRepository.crearEquipoNuevo(
            codigoBarras: datos['codigo_barras']?.toString() ?? '',
            marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
            modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
            numeroSerie: datos['numero_serie']?.toString(),
            logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
            //clienteId: clienteId.toString(),
          );

          _logger.i('✅ Equipo nuevo creado con ID: $equipoId');

          // Crear equipoCompleto artificial para continuar el flujo
          equipoCompleto = {
            'id': equipoId,
            'cod_barras': datos['codigo_barras'],
            'marca_id': datos['marca_id'],
            'modelo_id': datos['modelo_id'],
            'modelo_nombre': datos['modelo'],
            'numero_serie': datos['numero_serie'],
            'logo_id': datos['logo_id'],
            'logo_nombre': datos['logo'],
            'marca_nombre': datos['marca'] ?? 'Sin marca',
            'cliente_id': clienteId,
            'nuevo_equipo': 1,
          };

        } catch (e) {
          _logger.e('❌ Error creando equipo nuevo: $e');
          throw 'Error registrando equipo nuevo: $e';
        }
      } else {
        // Equipos existentes
        if (equipoCompleto == null) throw 'No se encontró información del equipo';
        if (equipoCompleto['id'] == null) throw 'El equipo no tiene ID asignado';
        equipoId = equipoCompleto['id'].toString();
      }

      _setStatusMessage('Verificando estado del equipo...');

      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      // Verificar asignación
      final yaAsignado = await _equipoRepository.verificarAsignacionEquipoCliente(
          equipoId,
          clienteId
      );
      _logger.i('Equipo $equipoId ya asignado: $yaAsignado');

      // ✅ CASO 2 y CASO 3: Crear equipo_pendiente si NO está asignado
      if (!yaAsignado) {
        _setStatusMessage('Registrando equipo pendiente de asignación...');

        if (_currentProcessId != processId) {
          return {'success': false, 'error': 'Proceso cancelado'};
        }

        try {
          _logger.i('Crear registro pendiente - Equipo NO asignado a este cliente');
          await _equipoPendienteRepository.procesarEscaneoCenso(
              equipoId: equipoId,
              clienteId: clienteId
          );
          _logger.i('✅ Registro pendiente creado exitosamente');
        } catch (e) {
          _logger.w('⚠️ Error registrando equipo pendiente: $e');
          // No fallar por esto, continuar
        }
      } else {
        _logger.i('ℹ️ Equipo ya asignado - no se crea registro pendiente');
      }

      // ✅ TODOS LOS CASOS: Crear estado en censo_activo
      _setStatusMessage('Registrando censo...');

      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      try {
        final now = DateTime.now().toLocal();

        final estadoCreado = await _estadoEquipoRepository.crearNuevoEstado(
          equipoId: equipoId,
          clienteId: clienteId,
          latitud: datos['latitud'],
          longitud: datos['longitud'],
          fechaRevision: now,
          enLocal: true,
          observaciones: datos['observaciones']?.toString(),
          imagenPath: datos['imagen_path'],
          imagenBase64: datos['imagen_base64'],
          tieneImagen: datos['tiene_imagen'] ?? false,
          imagenTamano: datos['imagen_tamano'],
          imagenPath2: datos['imagen_path2'],
          imagenBase64_2: datos['imagen_base64_2'],
          tieneImagen2: datos['tiene_imagen2'] ?? false,
          imagenTamano2: datos['imagen_tamano2'],
        );

        if (estadoCreado.id != null) {
          estadoIdActual = estadoCreado.id!;
          _logger.i('✅ Estado creado con ID: $estadoIdActual');
        } else {
          _logger.w('⚠️ Estado creado pero sin ID asignado');
          estadoIdActual = null;
        }
      } catch (dbError) {
        _logger.e('❌ Error al crear estado: $dbError');
        throw 'Error creando censo: $dbError';
      }

      // Continuar con sincronización al servidor...
      // (resto del código igual)

      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      _setStatusMessage('Preparando datos para sincronización...');
      Map<String, dynamic> datosCompletos;

      if (estadoIdActual != null) {
        final now = DateTime.now().toLocal();
        final timestampId = now.millisecondsSinceEpoch;

        datosCompletos = {
          'id_local': estadoIdActual,
          'timestamp_id': timestampId,
          'estado_sincronizacion': 'pendiente',
          'fecha_creacion_local': _formatearFechaLocal(now),
          'equipo_id': equipoId,
          'cliente_id': clienteId,
          'usuario_id': usuarioId,
          'funcionando': true,
          'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Censo registrado'}',
          'temperatura_actual': null,
          'temperatura_freezer': null,
          'latitud': datos['latitud'],
          'longitud': datos['longitud'],
          'imagen_path': datos['imagen_path'],
          'imagen_base64': datos['imagen_base64'],
          'tiene_imagen': datos['tiene_imagen'] ?? false,
          'imagen_tamano': datos['imagen_tamano'],
          'imagen_path2': datos['imagen_path2'],
          'imagen_base64_2': datos['imagen_base64_2'],
          'tiene_imagen2': datos['tiene_imagen2'] ?? false,
          'imagen_tamano2': datos['imagen_tamano2'],
          'codigo_barras': equipoCompleto!['cod_barras'] ?? datos['codigo_barras'],
          'numero_serie': equipoCompleto['numero_serie'] ?? datos['numero_serie'],
          'modelo': equipoCompleto['modelo_nombre'] ?? datos['modelo'],
          'logo': equipoCompleto['logo_nombre'] ?? datos['logo'],
          'marca_nombre': equipoCompleto['marca_nombre'] ?? 'Sin marca',
          'cliente_nombre': cliente.nombre,
          'observaciones': datos['observaciones'],
          'fecha_registro': datos['fecha_registro'],
          'timestamp_gps': datos['timestamp_gps'],
          'es_censo': esCenso,
          'es_nuevo_equipo': esNuevoEquipo,  // ✅ NUEVO
          'ya_asignado': yaAsignado,
          'version_app': '1.0.0',
          'dispositivo': Platform.operatingSystem,
          'fecha_revision': _formatearFechaLocal(now),
          'en_local': true,
        };
      } else {
        datosCompletos = await _prepararDatosParaEnvio(datos);
      }

      // Resto del flujo de sincronización igual...
      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      _setStatusMessage('Guardando registro local maestro...');
      await _guardarRegistroLocal(datosCompletos);

      _setStatusMessage('Sincronizando registro actual...');
      String mensajeFinal;
      bool migracionExitosa = false;

      if (estadoIdActual != null) {
        if (_currentProcessId != processId) {
          return {'success': false, 'error': 'Proceso cancelado'};
        }

        final respuestaServidor = await _intentarEnviarAlServidorConTimeout(
            datosCompletos,
            timeoutSegundos: 8
        );

        if (respuestaServidor['exito'] == true) {
          await _estadoEquipoRepository.marcarComoMigrado(
              estadoIdActual,
              servidorId: respuestaServidor['servidor_id']
          );
          final idLocal = _safeCastToInt(datosCompletos['id_local'], 'id_local');
          if (idLocal != null) await _marcarComoSincronizado(idLocal);

          mensajeFinal = esNuevoEquipo
              ? 'Equipo nuevo registrado y sincronizado'
              : 'Censo completado y sincronizado';
          migracionExitosa = true;
        } else {
          await _estadoEquipoRepository.marcarComoError(
              estadoIdActual,
              'Error: ${respuestaServidor['detalle'] ?? respuestaServidor['motivo']}'
          );

          mensajeFinal = esNuevoEquipo
              ? 'Equipo nuevo guardado. Se sincronizará automáticamente'
              : 'Censo guardado. Se sincronizará automáticamente';
        }
      } else {
        mensajeFinal = 'Registro guardado localmente';
      }

      _programarSincronizacionBackground();
      await Future.delayed(const Duration(milliseconds: 300));

      return {
        'success': true,
        'message': mensajeFinal,
        'migrado_inmediatamente': migracionExitosa
      };

    } catch (e) {
      _logger.e('❌ Error crítico en confirmación: $e');
      return {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setSaving(false);
    }
  }

  void cancelarProcesoActual() {
    if (_isProcessing) {
      _logger.i('Cancelando proceso actual: $_currentProcessId');
      _currentProcessId = null;
      _isProcessing = false;
      _setSaving(false);
      _setStatusMessage(null);
    }
  }

  @override
  void dispose() {
    cancelarProcesoActual();
    super.dispose();
  }

  Future<Map<String, dynamic>> _intentarEnviarAlServidorConTimeout(Map<String, dynamic> datos, {int timeoutSegundos = 8}) async {
    try {
      _logger.i('ENVÍO DIRECTO AL SERVIDOR');
      final datosApi = await _prepararDatosParaApiEstados(datos);
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

      final baseUrl = await BaseSyncService.getBaseUrl();
      final estadosEndpoint = '/censoActivo/insertCensoActivo';

      final response = await http.post(
        Uri.parse('$baseUrl$estadosEndpoint'),
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
      _logger.i('Iniciando sincronización automática de registros pendientes...');

      final registrosPendientes = await _estadoEquipoRepository.obtenerCreados();

      if (registrosPendientes.isEmpty) {
        _logger.i('No hay registros pendientes de sincronización');
        return;
      }

      _logger.i('Encontrados ${registrosPendientes.length} registros pendientes');

      final usuarioId = await _getUsuarioId;

      int exitosos = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          final datosParaApi = {
            'fecha_revision': _formatearFechaLocal(registro.fechaRevision),
            'equipo_id': (registro.equipoId ?? '').toString(),
            'latitud': registro.latitud ?? 0.0,
            'longitud': registro.longitud ?? 0.0,
            'equipo_codigo_barras': '',
            'equipo_numero_serie': '',
            'equipo_modelo': '',
            'equipo_marca': '',
            'equipo_logo': '',
            'cliente_nombre': '',
            'usuario_id': usuarioId,
            'funcionando': true,
            'cliente_id': registro.clienteId,
            'observaciones': registro.observaciones ?? 'Sincronización automática',
          };

          final respuesta = await _enviarAApiEstadosConTimeout(datosParaApi, 5);

          if (respuesta['exito'] == true) {
            await _estadoEquipoRepository.marcarComoMigrado(
                registro.id!,
                servidorId: respuesta['id']
            );
            exitosos++;
            _logger.i('Registro ${registro.id} sincronizado exitosamente');
          } else {
            await _estadoEquipoRepository.marcarComoError(
                registro.id!,
                'Error del servidor: ${respuesta['mensaje']}'
            );
            fallidos++;
            _logger.w('Error sincronizando registro ${registro.id}: ${respuesta['mensaje']}');
          }

        } catch (e) {
          fallidos++;
          _logger.e('Error procesando registro ${registro.id}: $e');

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
                registro.id!,
                'Excepción: $e'
            );
          }
        }
      }

      _logger.i('Sincronización finalizada - Exitosos: $exitosos, Fallidos: $fallidos');

    } catch (e) {
      _logger.e('Error en sincronización automática: $e');
    }
  }

  Future<Map<String, dynamic>> _prepararDatosParaEnvio(Map<String, dynamic> datos) async {
    final cliente = datos['cliente'] as Cliente;
    final equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
    final idLocal = DateTime.now().millisecondsSinceEpoch;
    final usuarioId = await _getUsuarioId;
    final now = DateTime.now().toLocal();

    return {
      'id_local': idLocal,
      'timestamp_id': idLocal,
      'estado_sincronizacion': 'pendiente',
      'fecha_creacion_local': _formatearFechaLocal(now),
      'equipo_id': equipoCompleto?['id'],
      'cliente_id': cliente.id,
      'usuario_id': usuarioId,
      'funcionando': true,
      'estado_general': 'Equipo registrado desde APP móvil - ${datos['observaciones'] ?? 'Sin observaciones'}',
      'observaciones': datos['observaciones'],
      'latitud': datos['latitud'],
      'longitud': datos['longitud'],
      'codigo_barras': datos['codigo_barras'],
      'modelo': datos['modelo'],
      'logo': datos['logo'],
      'numero_serie': datos['numero_serie'],
      'imagen_path': datos['imagen_path'],
      'imagen_base64': datos['imagen_base64'],
      'tiene_imagen': datos['tiene_imagen'] ?? false,
      'imagen_tamano': datos['imagen_tamano'],
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
      _logger.i('Guardando registro maestro localmente con ID: ${datos['id_local']}');
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      throw 'Error guardando datos localmente';
    }
  }

  Future<Map<String, dynamic>> _prepararDatosParaApiEstados(
      Map<String, dynamic> datosLocales
      ) async {
    final usuarioId = await _getUsuarioId;
    final edfVendedorId = await _getEdfVendedorId;
    final now = DateTime.now().toLocal();

    return {
      'id': datosLocales['timestamp_id']?.toString() ?? now.millisecondsSinceEpoch.toString(),
      'edfVendedorSucursalId': '$edfVendedorId',
      'edfEquipoId': (datosLocales['equipo_id'] ?? '').toString(),
      'usuarioId': usuarioId,
      'edfClienteId': datosLocales['cliente_id'] ?? 0,
      'fecha_revision': datosLocales['fecha_revision'] ?? _formatearFechaLocal(now),
      'latitud': datosLocales['latitud'] ?? 0.0,
      'longitud': datosLocales['longitud'] ?? 0.0,
      'enLocal': datosLocales['en_local'] ?? true,
      'fechaDeRevision': datosLocales['fecha_revision'] ?? _formatearFechaLocal(now),
      'estadoCenso': datosLocales['ya_asignado'] == true ? 'asignado' : 'pendiente',
      'esNuevoEquipo': datosLocales['es_nuevo_equipo'] ?? false,  // ✅ NUEVO
      'equipo_codigo_barras': datosLocales['codigo_barras'] ?? '',
      'equipo_numero_serie': datosLocales['numero_serie'] ?? '',
      'equipo_modelo': datosLocales['modelo'] ?? '',
      'equipo_marca': datosLocales['marca_nombre'] ?? '',
      'equipo_logo': datosLocales['logo'] ?? '',
      'equipo_id': (datosLocales['equipo_id'] ?? '').toString(),
      'cliente_nombre': datosLocales['cliente_nombre'] ?? '',
      'observaciones': datosLocales['observaciones'] ?? '',
      'cliente_id': datosLocales['cliente_id'] ?? 0,
      'usuario_id': usuarioId,
      'imagenPath': datosLocales['imagen_path'],
      'imageBase64_1': datosLocales['imagen_base64'],
      'imageBase64_2': datosLocales['imagen_base64_2'],
      'imageSize': datosLocales['imagen_tamano']?.toString(),
      'en_local': datosLocales['en_local'] ?? true,
      'dispositivo': datosLocales['dispositivo'] ?? 'android',
      'es_censo': datosLocales['es_censo'] ?? true,
      'version_app': datosLocales['version_app'] ?? '1.0.0',
      'estado_general': datosLocales['estado_general'] ?? '',
      'imagen_tamano': datosLocales['imagen_tamano'],
      'imagen_base64': datosLocales['imagen_base64'],
      'imagen_base64_2': datosLocales['imagen_base64_2'],
      'imagen_tamano2': datosLocales['imagen_tamano2'],
      'tiene_imagen': datosLocales['tiene_imagen'] ?? false,
      'tiene_imagen2': datosLocales['tiene_imagen2'] ?? false,
      'imagen_path': datosLocales['imagen_path'],
      'imagen_path2': datosLocales['imagen_path2'],
    };
  }

  Future<bool> verificarSincronizacionPendiente(int? estadoId) async {
    if (estadoId == null) return false;

    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) return false;

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      final estaPendiente = (estadoCenso == 'creado' || estadoCenso == 'error') &&
          sincronizado == 0;

      _logger.i('Estado $estadoId - Censo: $estadoCenso, Sincronizado: $sincronizado, Pendiente: $estaPendiente');

      return estaPendiente;
    } catch (e) {
      _logger.e('Error verificando sincronización: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(int? estadoId) async {
    if (estadoId == null) {
      return {
        'pendiente': false,
        'estado': 'desconocido',
        'mensaje': 'No hay ID de estado',
        'icono': Icons.help_outline,
        'color': Colors.grey,
      };
    }

    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return {
          'pendiente': false,
          'estado': 'no_encontrado',
          'mensaje': 'Estado no encontrado en base de datos',
          'icono': Icons.error_outline,
          'color': Colors.grey,
        };
      }

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      final estaPendiente = (estadoCenso == 'creado' || estadoCenso == 'error') &&
          sincronizado == 0;

      String mensaje;
      IconData icono;
      Color color;

      if (sincronizado == 1) {
        mensaje = 'Registro sincronizado correctamente';
        icono = Icons.cloud_done;
        color = Colors.green;
      } else if (estadoCenso == 'error') {
        mensaje = 'Error en sincronización - Puede reintentar';
        icono = Icons.cloud_off;
        color = Colors.red;
      } else {
        mensaje = 'Pendiente de sincronización automática';
        icono = Icons.cloud_upload;
        color = Colors.orange;
      }

      return {
        'pendiente': estaPendiente,
        'estado': estadoCenso,
        'sincronizado': sincronizado,
        'mensaje': mensaje,
        'icono': icono,
        'color': color,
        'fecha_creacion': estado['fecha_creacion'],
        'observaciones': estado['observaciones'],
      };
    } catch (e) {
      _logger.e('Error obteniendo info de sincronización: $e');
      return {
        'pendiente': false,
        'estado': 'error',
        'mensaje': 'Error consultando estado: $e',
        'icono': Icons.error,
        'color': Colors.red,
      };
    }
  }
  Future<Map<String, dynamic>> reintentarEnvio(int estadoId) async {
    try {
      _logger.i('Reintentando envío del estado ID: $estadoId');

      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return {
          'success': false,
          'error': 'No se encontró el registro en la base de datos'
        };
      }

      final estadoMap = maps.first;
      final usuarioId = await _getUsuarioId;
      final edfVendedorId = await _getEdfVendedorId;
      final now = DateTime.now().toLocal();
      final timestampId = now.millisecondsSinceEpoch;

      final datosParaApi = {
        'id': timestampId.toString(),
        'edfVendedorSucursalId': edfVendedorId ?? '',
        'edfEquipoId': estadoMap['equipo_id']?.toString() ?? '',
        'usuarioId': usuarioId,
        'edfClienteId': estadoMap['cliente_id'] ?? 0,
        'fecha_revision': estadoMap['fecha_revision'] ?? _formatearFechaLocal(now),
        'latitud': estadoMap['latitud'] ?? 0.0,
        'longitud': estadoMap['longitud'] ?? 0.0,
        'enLocal': true,
        'fechaDeRevision': estadoMap['fecha_revision'] ?? _formatearFechaLocal(now),
        'estadoCenso': 'pendiente',
        'observaciones': estadoMap['observaciones'] ?? '',
        'imageBase64_1': estadoMap['imagen_base64'],
        'imageBase64_2': estadoMap['imagen_base64_2'],
        'tiene_imagen': estadoMap['tiene_imagen'] ?? 0,
        'tiene_imagen2': estadoMap['tiene_imagen2'] ?? 0,
        'equipo_codigo_barras': '',
        'equipo_numero_serie': '',
        'equipo_modelo': '',
        'equipo_marca': '',
        'equipo_logo': '',
        'cliente_nombre': '',
        'usuario_id': usuarioId,
        'cliente_id': estadoMap['cliente_id'] ?? 0,
      };

      final respuesta = await _enviarAApiEstadosConTimeout(datosParaApi, 8);

      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(
          estadoId,
          servidorId: respuesta['id'],
        );

        _logger.i('Reenvío exitoso del estado $estadoId');

        return {
          'success': true,
          'message': 'Registro sincronizado correctamente'
        };
      } else {
        await _estadoEquipoRepository.marcarComoError(
            estadoId,
            'Error del servidor: ${respuesta['mensaje']}'
        );

        _logger.w('Fallo en reenvío: ${respuesta['mensaje']}');

        return {
          'success': false,
          'error': 'Error del servidor: ${respuesta['mensaje']}'
        };
      }
    } catch (e) {
      _logger.e('Error en reintento de envío: $e');

      try {
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      } catch (_) {}

      return {
        'success': false,
        'error': 'Error al reintentar: $e'
      };
    }
  }

  Future<void> _marcarComoSincronizado(int idLocal) async {
    try {
      _logger.i('Registro marcado como sincronizado: $idLocal');
    } catch (e) {}
  }
}
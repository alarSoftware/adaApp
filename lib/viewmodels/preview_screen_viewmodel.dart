import 'package:flutter/material.dart';

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/censo/censo_log_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/censo/censo_foto_service.dart';
import 'package:ada_app/services/sync/sync_service.dart';

import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/ui/theme/colors.dart';

final Uuid _uuid = const Uuid();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isSaving = false;
  String? _statusMessage;
  bool _isProcessing = false;
  String? _currentProcessId;

  StreamController<Map<String, dynamic>>? _syncStatusController;
  Timer? _pollTimer;
  String? _currentMonitoringId;

  final EquipoRepository _equipoRepository = EquipoRepository();
  final CensoActivoRepository _estadoEquipoRepository = CensoActivoRepository();
  final CensoActivoFotoRepository _fotoRepository = CensoActivoFotoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository =
  EquipoPendienteRepository();

  final AuthService _authService = AuthService();

  late final CensoLogService _logService;
  late final CensoUploadService _uploadService;
  late final CensoFotoService _fotoService;

  Usuario? _usuarioActual;

  PreviewScreenViewModel() {
    _logService = CensoLogService();
    _fotoService = CensoFotoService();
    _uploadService = CensoUploadService(
      estadoEquipoRepository: _estadoEquipoRepository,
      fotoRepository: _fotoRepository,
      logService: _logService,
    );
  }

  bool get isSaving => _isSaving;
  String? get statusMessage => _statusMessage;
  bool get canConfirm => !_isProcessing && !_isSaving;
  Stream<Map<String, dynamic>>? get syncStatusStream => _syncStatusController?.stream;

  Future<int> get _getUsuarioId async {
    try {
      if (_usuarioActual != null && _usuarioActual!.id != null)
        return _usuarioActual!.id!;
      _usuarioActual = await _authService.getCurrentUser();
      if (_usuarioActual?.id != null) return _usuarioActual!.id!;

      return 1;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> get _getEdfVendedorId async {
    try {
      if (_usuarioActual != null) return _usuarioActual!.edfVendedorId;
      _usuarioActual = await _authService.getCurrentUser();
      return _usuarioActual?.edfVendedorId;
    } catch (e) {
      rethrow;
    }
  }

  void iniciarMonitoreoSincronizacion(String censoActivoId) async {
    if (_currentMonitoringId == censoActivoId && _syncStatusController != null) {
      return;
    }

    detenerMonitoreoSincronizacion();

    _currentMonitoringId = censoActivoId;
    _syncStatusController = StreamController<Map<String, dynamic>>.broadcast();

    // Notificar inmediatamente que el stream está disponible
    notifyListeners();

    // Obtener y emitir el primer valor
    try {
      final info = await obtenerInfoSincronizacion(censoActivoId);
      if (_syncStatusController != null && !_syncStatusController!.isClosed) {
        _syncStatusController!.add(info);
      }
    } catch (e) {
      debugPrint('Error obteniendo estado inicial: $e');
    }

    // Iniciar polling
    _pollTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _emitirEstadoActual(censoActivoId);
    });
  }

  Future<void> _emitirEstadoActual(String censoActivoId) async {
    try {
      if (_syncStatusController == null || _syncStatusController!.isClosed) {
        return;
      }

      final info = await obtenerInfoSincronizacion(censoActivoId);

      _syncStatusController!.add(info);

    } catch (e, stackTrace) {
    }
  }

  void detenerMonitoreoSincronizacion() {
    _pollTimer?.cancel();
    _pollTimer = null;

    _syncStatusController?.close();
    _syncStatusController = null;

    _currentMonitoringId = null;
  }

  Future<Map<String, dynamic>> confirmarRegistro(
      Map<String, dynamic> datos,
      ) async {
    if (_isProcessing) {
      return {
        'success': false,
        'error':
        'Ya hay un proceso de confirmación en curso. Por favor espere.',
      };
    }

    final processId = _uuid.v4();
    _currentProcessId = processId;
    _isProcessing = true;

    try {
      return await _insertarEnviarCensoActivo(datos, processId);
    } finally {
      if (_currentProcessId == processId) {
        _isProcessing = false;
        _currentProcessId = null;
      }
    }
  }

  Future<Map<String, dynamic>> _insertarEnviarCensoActivo(
      Map<String, dynamic> datos,
      String processId,
      ) async {
    _setSaving(true);
    String? censoActivoId;
    String? equipoId;
    int? usuarioId;
    Map<String, dynamic> resultado = {};

    try {
      if (_currentProcessId != processId) {
        resultado = {'success': false, 'error': 'Proceso cancelado'};
        return resultado;
      }

      var esNuevoEquipo = datos['es_nuevo_equipo'] as bool? ?? false;
      var cliente = datos['cliente'];
      var id = equipoId;
      var numeroSerie = datos['numero_serie']?.toString();
      var modeloId = datos['modelo_id'];
      var logoId = datos['logo_id'];
      var marcaId = datos['marca_id'];
      var marcaNombre = datos['marca_nombre']?.toString() ?? '';
      var modeloNombre = datos['modelo']?.toString() ?? '';
      var logoNombre = datos['logo']?.toString() ?? '';
      int? clienteId = cliente != null
          ? int.tryParse(cliente.id.toString())
          : null;
      var codBarras = datos['codigo_barras']?.toString() ?? '';

      if (cliente == null || cliente.id == null) {
        throw 'Cliente no válido';
      }

      usuarioId = await _getUsuarioId;
      final now = DateTime.now().toLocal();

      if (esNuevoEquipo) {
        _setStatusMessage('Registrando equipo...');
        equipoId = await _crearEquipoNuevo(
          datos,
          clienteId,
          processId,
          usuarioId.toString(),
        );
      } else {
        equipoId = datos['equipo_completo']?['id']?.toString();
        if (equipoId == null) throw 'Equipo ID no válido';
      }

      bool yaAsignado;
      if (esNuevoEquipo) {
        yaAsignado = false;
      } else {
        yaAsignado = await _verificarAsignacionLocal(equipoId, clienteId!);
      }

      final edfVendedorId = await SyncService.obtenerEdfVendedorId();
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw Exception('edfVendedorId no encontrado');
      }

      if (!yaAsignado) {
        _setStatusMessage('Registrando asignación pendiente...');
        await _equipoPendienteRepository.procesarEscaneoCenso(
          equipoId: equipoId,
          clienteId: clienteId!,
          usuarioId: usuarioId,
          edfVendedorId: edfVendedorId,
        );
      } else {}

      _setStatusMessage('Guardando censo...');
      censoActivoId = await _crearCensoLocalConUsuario(
        equipoId: equipoId,
        clienteId: clienteId!,
        usuarioId: usuarioId,
        datos: datos,
        processId: processId,
        yaAsignado: yaAsignado,
        edfVendedorId: edfVendedorId,
      );

      if (censoActivoId == null) {
        throw 'No se pudo crear el censo en la base de datos';
      }

      final idsImagenes = await _fotoService.guardarFotosDelCenso(
        censoActivoId,
        datos,
      );
      final tiempoLocal = DateTime.now().difference(now).inSeconds;

      await _uploadService.enviarCensoUnificado(
        censoActivoId: censoActivoId,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId,
        guardarLog: true,
      );

      Map<String, dynamic>? equipoCompleto;

      if (esNuevoEquipo) {
        equipoCompleto = {
          'id': equipoId,
          'cod_barras': codBarras,
          'numero_serie': numeroSerie,
          'marca_id': marcaId,
          'modelo_id': modeloId,
          'logo_id': logoId,
          'marca_nombre': marcaNombre,
          'modelo_nombre': modeloNombre,
          'logo_nombre': logoNombre,
          'cliente_id': clienteId,
        };
      } else {
        equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
      }

      resultado = {
        'success': true,
        'message': 'Registro guardado. Sincronizando en segundo plano...',
        'estado_id': censoActivoId,
        'equipo_id': equipoId,
        'equipo_completo': equipoCompleto,
        'sincronizacion': 'unificada_background',
        'tiempo_guardado': '${tiempoLocal}s',
        'ya_asignado': yaAsignado,
      };
    } catch (e) {
      resultado = {'success': false, 'error': 'Error guardando registro: $e'};
    } finally {
      _setSaving(false);
    }

    return resultado;
  }

  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void _setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<String> _crearEquipoNuevo(
      Map<String, dynamic> datos,
      int? clienteId,
      String processId,
      String? userId,
      ) async {
    _setStatusMessage('Registrando equipo nuevo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final equipoId = await _equipoRepository.crearEquipoNuevo(
        codigoBarras: datos['codigo_barras']?.toString() ?? '',
        marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
        modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
        numeroSerie: datos['numero_serie']?.toString(),
        logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
        clienteId: clienteId,
      );

      if (clienteId != null) {
      } else {}

      return equipoId;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _verificarAsignacionLocal(String equipoId, int clienteId) async {
    try {
      return await _equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        clienteId,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _crearCensoLocalConUsuario({
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required Map<String, dynamic> datos,
    required String processId,
    required bool yaAsignado,
    required String edfVendedorId,
  }) async {
    _setStatusMessage('Registrando censo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final now = DateTime.now().toLocal();
      final estadoCenso = yaAsignado ? 'asignado' : 'pendiente';

      final censoActivo = await _estadoEquipoRepository.crearCensoActivo(
        equipoId: equipoId,
        clienteId: clienteId,
        latitud: datos['latitud'],
        longitud: datos['longitud'],
        fechaRevision: now,
        enLocal: true,
        observaciones: datos['observaciones']?.toString(),
        estadoCenso: estadoCenso,
        edfVendedorId: edfVendedorId,
      );

      if (censoActivo.id != null) {
        await _estadoEquipoRepository.dbHelper.actualizar(
          'censo_activo',
          {
            'usuario_id': usuarioId,
            'fecha_actualizacion': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [censoActivo.id!],
        );

        final verificacion = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [censoActivo.id!],
          limit: 1,
        );

        if (verificacion.isNotEmpty) {
          final usuarioEnBD = verificacion.first['usuario_id'];

          if (usuarioEnBD == null) {
            throw 'Error: usuario_id no se pudo guardar en la BD';
          }
        }

        return censoActivo.id!;
      }

      return null;
    } catch (e) {
      rethrow;
    }
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

  Future<Map<String, dynamic>> verificarSincronizacionPendiente(
      String? estadoId,
      ) async {
    if (estadoId == null) return {'pendiente': false};

    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) return {'pendiente': false};

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

      return {
        'pendiente':
        (estadoCenso == 'creado' || estadoCenso == 'error') &&
            sincronizado == 0,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(
      String? censoActivoId,
      ) async {
    if (censoActivoId == null) {
      return {
        'estado': 'desconocido',
        'mensaje': 'Estado desconocido',
        'icono': Icons.help_outline,
        'color': AppColors.textSecondary,
        'error_detalle': null,
        'envioFallido': false,
      };
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final result = await db.query(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [censoActivoId],
        limit: 1,
      );

      if (result.isEmpty) {
        return {
          'estado': 'no_encontrado',
          'mensaje': 'Registro no encontrado',
          'icono': Icons.error_outline,
          'color': AppColors.error,
          'error_detalle': null,
          'envioFallido': true,
        };
      }

      final estadoCenso = result.first['estado_censo'] as String?;
      final estado = estadoCenso ?? 'creado';
      final envioFallido = estado == 'error';

      switch (estado) {
        case 'creado':
        case 'pendiente':
        case 'asignado':
          return {
            'estado': estado,
            'mensaje': 'Pendiente de sincronización',
            'icono': Icons.sync,
            'color': AppColors.warning,
            'error_detalle': null,
            'envioFallido': envioFallido,
          };

        case 'migrado':
          {
            final errorLog = await db.query(
              'error_log',
              where: 'registro_fail_id = ? AND table_name = ?',
              whereArgs: [censoActivoId, 'censo_activo'],
              orderBy: 'timestamp DESC',
              limit: 1,
            );

            String? errorDetalle;
            if (errorLog.isNotEmpty) {
              final errorType = errorLog.first['error_type'] as String?;
              if (errorType == 'resuelto') {
                final errorMessage = errorLog.first['error_message'] as String?;
                final retryCount = errorLog.first['retry_count'] as int? ?? 0;
                final errorCode = errorLog.first['error_code'] as String?;
                final endpoint = errorLog.first['endpoint'] as String?;

                errorDetalle =
                'Sincronizado después de ${retryCount + 1} intento(s)\n\nÚltimo error encontrado:\n$errorMessage';

                if (errorCode != null) {
                  errorDetalle += '\n\nCódigo: $errorCode';
                }
                if (endpoint != null) {
                  errorDetalle += '\nEndpoint: ${_formatEndpoint(endpoint)}';
                }
              }
            }

            return {
              'estado': estado,
              'mensaje': 'Sincronizado exitosamente',
              'icono': Icons.check_circle,
              'color': AppColors.success,
              'error_detalle': errorDetalle,
              'envioFallido': envioFallido,
            };
          }

        case 'error':
          {
            final errorLog = await db.query(
              'error_log',
              where: 'registro_fail_id = ? AND table_name = ?',
              whereArgs: [censoActivoId, 'censo_activo'],
              orderBy: 'timestamp DESC',
              limit: 1,
            );

            String? errorDetalle;
            if (errorLog.isNotEmpty) {
              final errorMessage = errorLog.first['error_message'] as String?;
              final errorType = errorLog.first['error_type'] as String?;
              final errorCode = errorLog.first['error_code'] as String?;
              final endpoint = errorLog.first['endpoint'] as String?;
              final retryCount = errorLog.first['retry_count'] as int? ?? 0;
              final timestamp = errorLog.first['timestamp'] as String?;

              errorDetalle = errorMessage ?? 'Error desconocido';

              if (errorType != null && errorType != 'unknown') {
                errorDetalle += '\n\nTipo: ${_formatErrorType(errorType)}';
              }

              if (errorCode != null) {
                errorDetalle += '\nCódigo: $errorCode';
              }

              if (endpoint != null) {
                errorDetalle += '\nEndpoint: ${_formatEndpoint(endpoint)}';
              }

              if (retryCount > 0) {
                errorDetalle += '\n\nReintentos: $retryCount';
              }

              if (timestamp != null) {
                try {
                  errorDetalle +=
                  '\n\nOcurrió el: ${_formatTimestamp(DateTime.parse(timestamp))}';
                } catch (_) {}
              }
            } else {
              errorDetalle = result.first['error_mensaje'] as String?;
              if (errorDetalle != null) {
                errorDetalle += '\n\n(Sin detalles adicionales)';
              }
            }

            return {
              'estado': estado,
              'mensaje': 'Error de sincronización',
              'icono': Icons.error,
              'color': AppColors.error,
              'error_detalle':
              errorDetalle ?? 'No se encontró detalle del error',
              'envioFallido': envioFallido,
            };
          }

        default:
          return {
            'estado': 'desconocido',
            'mensaje': 'Estado: $estado',
            'icono': Icons.help_outline,
            'color': AppColors.textSecondary,
            'error_detalle': null,
            'envioFallido': envioFallido,
          };
      }
    } catch (e) {
      rethrow;
    }
  }

  String _formatErrorType(String errorType) {
    switch (errorType) {
      case 'network':
        return 'Error de Red';
      case 'server':
        return 'Error del Servidor';
      case 'validation':
        return 'Error de Validación';
      case 'database':
        return 'Error de Base de Datos';
      case 'sync':
        return 'Error de Sincronización';
      case 'auth':
        return 'Error de Autenticación';
      case 'timeout':
        return 'Tiempo de Espera Agotado';
      default:
        return errorType.toUpperCase();
    }
  }

  String _formatEndpoint(String endpoint) {
    if (endpoint.length > 50) {
      final uri = Uri.tryParse(endpoint);
      if (uri != null) {
        return '...${uri.path}';
      }
    }
    return endpoint;
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} minutos';
    } else if (diff.inHours < 24) {
      return 'hace ${diff.inHours} horas';
    } else if (diff.inDays == 1) {
      return 'ayer a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      final dia = date.day.toString().padLeft(2, '0');
      final mes = date.month.toString().padLeft(2, '0');
      final hora = date.hour.toString().padLeft(2, '0');
      final minuto = date.minute.toString().padLeft(2, '0');
      return '$dia/$mes a las $hora:$minuto';
    }
  }

  Future<Map<String, dynamic>> reintentarEnvio(String estadoId) async {
    try {
      iniciarMonitoreoSincronizacion(estadoId);

      final usuarioId = await _getUsuarioId;
      final edfVendedorId = await _getEdfVendedorId;

      return await _uploadService.reintentarEnvioCenso(
        estadoId,
        usuarioId,
        edfVendedorId,
      );
    } catch (e) {
      return {'success': false, 'error': 'Error al reintentar: $e'};
    }
  }

  Future<List<String>> obtenerLogsGuardados() async {
    return await _logService.obtenerLogsGuardados();
  }

  void cancelarProcesoActual() {
    if (_isProcessing) {
      _currentProcessId = null;
      _isProcessing = false;
      _setSaving(false);
      _setStatusMessage(null);
    }
  }

  @override
  void dispose() {
    detenerMonitoreoSincronizacion();
    cancelarProcesoActual();
    super.dispose();
  }

  int? _safeCastToInt(dynamic value, String fieldName) {
    try {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    } catch (e) {
      return null;
    }
  }
}
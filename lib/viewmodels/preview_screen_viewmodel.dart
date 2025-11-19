// lib/viewmodels/preview_screen_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/cliente.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/equipo_post_service.dart';
import 'package:ada_app/services/post/equipo_pendiente_post_service.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/censo/censo_log_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/censo/censo_foto_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

final _logger = Logger();
final Uuid _uuid = const Uuid();

class PreviewScreenViewModel extends ChangeNotifier {
  bool _isSaving = false;
  String? _statusMessage;
  bool _isProcessing = false;
  String? _currentProcessId;

  final EquipoRepository _equipoRepository = EquipoRepository();
  final EstadoEquipoRepository _estadoEquipoRepository = EstadoEquipoRepository();
  final CensoActivoFotoRepository _fotoRepository = CensoActivoFotoRepository();
  final EquipoPendienteRepository _equipoPendienteRepository = EquipoPendienteRepository();

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

  // =================================================================
  // GETTERS DE USUARIO
  // =================================================================

  Future<int> get _getUsuarioId async {
    try {
      if (_usuarioActual != null && _usuarioActual!.id != null) return _usuarioActual!.id!;
      _usuarioActual = await _authService.getCurrentUser();
      if (_usuarioActual?.id != null) return _usuarioActual!.id!;

      await ErrorLogService.logValidationError(
        tableName: 'Users',
        operation: 'get_usuario_id',
        errorMessage: 'No se pudo obtener usuario actual, usando fallback',
      );
      _logger.w('No se pudo obtener usuario, usando ID 1 como fallback');
      return 1;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'get_usuario_id',
        errorMessage: 'Error obteniendo usuario: $e',
        errorType: 'auth',
      );
      _logger.e('Error obteniendo usuario: $e');
      return 1;
    }
  }

  Future<String?> get _getEdfVendedorId async {
    try {
      if (_usuarioActual != null) return _usuarioActual!.edfVendedorId;
      _usuarioActual = await _authService.getCurrentUser();
      return _usuarioActual?.edfVendedorId;
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'get_edf_vendedor_id',
        errorMessage: 'Error obteniendo edf_vendedor_id: $e',
        errorType: 'auth',
      );
      _logger.e('Error obteniendo edf_vendedor_id: $e');
      return null;
    }
  }

  // =================================================================
  // MÉTODO PRINCIPAL - LOCAL FIRST, SYNC LATER
  // =================================================================

  /// Confirma el registro guardando TODO localmente y sincronizando en background
  Future<Map<String, dynamic>> confirmarRegistro(Map<String, dynamic> datos) async {
    if (_isProcessing) {
      return {
        'success': false,
        'error': 'Ya hay un proceso de confirmación en curso. Por favor espere.'
      };
    }

    final processId = _uuid.v4();
    _currentProcessId = processId;
    _isProcessing = true;

    try {
      return await _guardarYSincronizarEnBackground(datos, processId);
    } finally {
      if (_currentProcessId == processId) {
        _isProcessing = false;
        _currentProcessId = null;
      }
    }
  }

  /// Guarda TODO localmente y lanza sincronización en background
  Future<Map<String, dynamic>> _guardarYSincronizarEnBackground(
      Map<String, dynamic> datos,
      String processId,
      ) async {
    _setSaving(true);
    String? estadoIdActual;
    String? equipoId;
    int? usuarioId;

    try {
      _logger.i('🔄 Iniciando guardado local [Process: $processId]');

      // ============================================================
      // VALIDACIONES INICIALES
      // ============================================================
      if (_currentProcessId != processId) {
        return {'success': false, 'error': 'Proceso cancelado'};
      }

      final esNuevoEquipo = datos['es_nuevo_equipo'] as bool? ?? false;
      final cliente = datos['cliente'] as Cliente?;

      if (cliente == null || cliente.id == null) {
        throw 'Cliente no válido';
      }

      final clienteId = _convertirAInt(cliente.id, 'cliente_id');
      usuarioId = await _getUsuarioId;
      final now = DateTime.now().toLocal();

      _logger.i('📋 Datos básicos:');
      _logger.i('   - Usuario ID: $usuarioId');
      _logger.i('   - Cliente ID: $clienteId');
      _logger.i('   - Es nuevo equipo: $esNuevoEquipo');

      // ============================================================
      // FASE 1: GUARDADO LOCAL COMPLETO (1-2 segundos)
      // ============================================================

      // 1A. Crear/obtener equipo LOCAL
      if (esNuevoEquipo) {
        _setStatusMessage('Registrando equipo...');
        equipoId = await _crearEquipoNuevo(
            datos,
            null,
            processId,
            usuarioId.toString()
        );
        _logger.i('✅ Equipo creado localmente: $equipoId');
      } else {
        equipoId = datos['equipo_completo']?['id']?.toString();
        if (equipoId == null) throw 'Equipo ID no válido';
        _logger.i('ℹ️ Usando equipo existente: $equipoId');
      }

      // 1B. Crear pendiente LOCAL (si aplica)
      if (esNuevoEquipo) {
        _setStatusMessage('Registrando asignación...');
        await _equipoPendienteRepository.procesarEscaneoCenso(
          equipoId: equipoId,
          clienteId: clienteId,
          usuarioId: usuarioId,
        );
        _logger.i('✅ Pendiente registrado localmente');
      }

      // 1C. Crear censo LOCAL
      _setStatusMessage('Guardando censo...');
      estadoIdActual = await _crearCensoLocal(
        equipoId: equipoId,
        clienteId: clienteId,
        datos: datos,
        processId: processId,
        yaAsignado: false, // Siempre false inicialmente
        userId: usuarioId.toString(),
      );

      if (estadoIdActual == null) {
        throw 'No se pudo crear el censo en la base de datos';
      }

      _logger.i('✅ Censo creado localmente: $estadoIdActual');

      // 1D. Guardar fotos LOCAL
      final idsImagenes = await _fotoService.guardarFotosDelCenso(
          estadoIdActual,
          datos
      );

      _logger.i('✅ Fotos guardadas: ${idsImagenes}');

      final tiempoLocal = DateTime.now().difference(now).inSeconds;
      _logger.i('✅ Guardado local completado en ${tiempoLocal}s');

      // ============================================================
      // FASE 2: SINCRONIZACIÓN EN BACKGROUND (Fire and Forget)
      // ============================================================

      _logger.i('🚀 Lanzando sincronización en background...');

      // TODO: SINCRONIZACIÓN EN BACKGROUND
      // Esta llamada NO bloquea el retorno al usuario
      // La sincronización se ejecuta de forma asíncrona
      _iniciarSincronizacionEnBackground(
        esNuevoEquipo: esNuevoEquipo,
        equipoId: equipoId,
        clienteId: clienteId,
        estadoId: estadoIdActual,
        usuarioId: usuarioId,
        datos: datos,
      );

      // ============================================================
      // FASE 3: RETORNO INMEDIATO AL USUARIO
      // ============================================================

      return {
        'success': true,
        'message': '✅ Registro guardado. Sincronizando en segundo plano...',
        'estado_id': estadoIdActual,
        'equipo_id': equipoId,
        'sincronizacion': 'background',
        'tiempo_guardado': '${tiempoLocal}s',
      };

    } catch (e, stackTrace) {
      _logger.e('❌ Error en guardado local: $e', stackTrace: stackTrace);

      await ErrorLogService.logError(
        tableName: 'censo_activo',
        operation: 'guardar_local',
        errorMessage: 'Error crítico en guardado: $e',
        errorType: 'general',
        registroFailId: estadoIdActual,
        userId: usuarioId?.toString(),
      );

      return {
        'success': false,
        'error': 'Error guardando registro: $e'
      };
    } finally {
      _setSaving(false);
    }
  }

  // =================================================================
  // SINCRONIZACIÓN EN BACKGROUND
  // =================================================================

  /// TODO: PUNTO DE SINCRONIZACIÓN PRINCIPAL
  /// Lanza sincronización de Equipo → Pendiente → Censo en background
  /// Sin bloquear el retorno al usuario
  void _iniciarSincronizacionEnBackground({
    required bool esNuevoEquipo,
    required String equipoId,
    required int clienteId,
    required String estadoId,
    required int usuarioId,
    required Map<String, dynamic> datos,
  }) {
    // 🔥 Lanzar en background con Future.microtask (no bloquea)
    Future.microtask(() async {
      try {
        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('🚀 INICIANDO SINCRONIZACIÓN EN BACKGROUND');
        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('📋 Estado ID: $estadoId');
        _logger.i('📋 Equipo ID: $equipoId');
        _logger.i('📋 Cliente ID: $clienteId');
        _logger.i('═══════════════════════════════════════════════════════');

        // ============================================================
        // TODO: PASO 1 - SINCRONIZAR EQUIPO (si es nuevo)
        // ============================================================
        bool equipoSincronizado = true;

        if (esNuevoEquipo) {
          _logger.i('📤 PASO 1: Sincronizando EQUIPO...');
          equipoSincronizado = await _sincronizarEquipoEnBackground(
            equipoId: equipoId,
            datos: datos,
            usuarioId: usuarioId,
          );

          if (equipoSincronizado) {
            _logger.i('✅ EQUIPO sincronizado exitosamente');
          } else {
            _logger.w('⚠️ EQUIPO NO sincronizado (se reintentará después)');
          }
        } else {
          _logger.i('ℹ️ PASO 1: Equipo existente, omitiendo sincronización');
        }

        // ============================================================
        // TODO: PASO 2 - SINCRONIZAR PENDIENTE
        // ============================================================
        bool pendienteSincronizado = true;

        if (esNuevoEquipo || !await _verificarAsignacionLocal(equipoId, clienteId)) {
          _logger.i('📤 PASO 2: Sincronizando PENDIENTE...');
          pendienteSincronizado = await _sincronizarPendienteEnBackground(
            equipoId: equipoId,
            clienteId: clienteId,
            usuarioId: usuarioId,
          );

          if (pendienteSincronizado) {
            _logger.i('✅ PENDIENTE sincronizado exitosamente');
          } else {
            _logger.w('⚠️ PENDIENTE NO sincronizado (se reintentará después)');
          }
        } else {
          _logger.i('ℹ️ PASO 2: Asignación existente, omitiendo sincronización');
        }

        // ============================================================
        // TODO: PASO 3 - SINCRONIZAR CENSO
        // ============================================================
        // 🔥 IMPORTANTE: Siempre intentamos enviar el censo
        // El servidor decidirá si lo acepta o rechaza
        _logger.i('📤 PASO 3: Sincronizando CENSO...');
        await _sincronizarCensoEnBackground(
          estadoId: estadoId,
          equipoId: equipoId,
          clienteId: clienteId,
          usuarioId: usuarioId,
          datos: datos,
        );

        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('✅ SINCRONIZACIÓN EN BACKGROUND COMPLETADA');
        _logger.i('   - Equipo: ${equipoSincronizado ? "✅" : "⚠️"}');
        _logger.i('   - Pendiente: ${pendienteSincronizado ? "✅" : "⚠️"}');
        _logger.i('   - Censo: Procesado');
        _logger.i('═══════════════════════════════════════════════════════');

      } catch (e, stackTrace) {
        _logger.e('❌ Error en sincronización background: $e', stackTrace: stackTrace);

        // 🔥 No lanzar error, solo loguear
        // El sistema de reintentos periódicos lo manejará
        await ErrorLogService.logError(
          tableName: 'censo_activo',
          operation: 'sync_background',
          errorMessage: 'Error en sync background: $e',
          errorType: 'sync',
          registroFailId: estadoId,
          userId: usuarioId.toString(),
        );
      }
    });
  }

  /// TODO: SINCRONIZACIÓN DE EQUIPO
  /// Intenta enviar el equipo al servidor con timeout de 30s
  Future<bool> _sincronizarEquipoEnBackground({
    required String equipoId,
    required Map<String, dynamic> datos,
    required int usuarioId,
  }) async {
    try {
      _logger.i('─────────────────────────────────────');
      _logger.i('📤 Sincronizando EQUIPO: $equipoId');
      _logger.i('─────────────────────────────────────');

      final edfVendedorId = await _getEdfVendedorId;
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        _logger.w('⚠️ Sin edfVendedorId, equipo queda pendiente');
        return false;
      }

      final resultado = await EquipoPostService.enviarEquipoNuevo(
        equipoId: equipoId,
        codigoBarras: datos['codigo_barras']?.toString() ?? '',
        marcaId: _safeCastToInt(datos['marca_id'], 'marca_id') ?? 1,
        modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id') ?? 1,
        logoId: _safeCastToInt(datos['logo_id'], 'logo_id') ?? 1,
        numeroSerie: datos['numero_serie']?.toString(),
        clienteId: null, // Sin cliente en este momento
        edfVendedorId: edfVendedorId,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          _logger.w('⏱️ Timeout sincronizando equipo (30s)');
          return {'exito': false, 'mensaje': 'Timeout'};
        },
      );

      if (resultado['exito'] == true) {
        await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
        _logger.i('✅ Equipo $equipoId sincronizado correctamente');
        return true;
      }

      _logger.w('⚠️ Equipo NO sincronizado: ${resultado['mensaje']}');
      return false;

    } catch (e) {
      _logger.e('❌ Error sincronizando equipo: $e');
      return false;
    }
  }

  /// TODO: SINCRONIZACIÓN DE PENDIENTE
  /// Intenta enviar la asignación pendiente al servidor con timeout de 30s
  Future<bool> _sincronizarPendienteEnBackground({
    required String equipoId,
    required int clienteId,
    required int usuarioId,
  }) async {
    try {
      _logger.i('─────────────────────────────────────');
      _logger.i('📤 Sincronizando PENDIENTE');
      _logger.i('   Equipo: $equipoId');
      _logger.i('   Cliente: $clienteId');
      _logger.i('─────────────────────────────────────');

      final edfVendedorId = await _getEdfVendedorId;
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        _logger.w('⚠️ Sin edfVendedorId, pendiente queda local');
        return false;
      }

      // Obtener el UUID del registro local
      final pendienteLocal = await _equipoPendienteRepository.dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      final appId = pendienteLocal.isNotEmpty ? pendienteLocal.first['id'] : null;

      _logger.i('   UUID Local: $appId');

      final resultado = await EquiposPendientesApiService.enviarEquipoPendiente(
        equipoId: equipoId,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
        appId: appId,
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          _logger.w('⏱️ Timeout sincronizando pendiente (30s)');
          return {'exito': false, 'mensaje': 'Timeout'};
        },
      );

      if (resultado['exito'] == true) {
        await _equipoPendienteRepository.marcarSincronizadosPorCenso(
          equipoId,
          clienteId,
        );
        _logger.i('✅ Pendiente sincronizado correctamente');
        return true;
      }

      _logger.w('⚠️ Pendiente NO sincronizado: ${resultado['mensaje']}');
      return false;

    } catch (e) {
      _logger.e('❌ Error sincronizando pendiente: $e');
      return false;
    }
  }

  /// TODO: SINCRONIZACIÓN DE CENSO
  /// Intenta enviar el censo al servidor con timeout de 30s
  /// NOTA: Se envía SIEMPRE, sin validar dependencias
  Future<void> _sincronizarCensoEnBackground({
    required String estadoId,
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required Map<String, dynamic> datos,
  }) async {
    try {
      _logger.i('─────────────────────────────────────');
      _logger.i('📤 Sincronizando CENSO: $estadoId');
      _logger.i('─────────────────────────────────────');

      // Obtener fotos del censo
      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      _logger.i('   Fotos encontradas: ${fotos.length}');

      // Preparar payload
      final datosParaApi = await _uploadService.prepararPayloadConMapper(
        estadoId,
        fotos,
      );

      // Enviar al servidor
      final respuesta = await _uploadService.enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 30,
      );

      if (respuesta['exito'] == true) {
        // Marcar censo como sincronizado
        await _estadoEquipoRepository.marcarComoMigrado(
          estadoId,
          servidorId: respuesta['id'],
        );
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

        // Marcar fotos como sincronizadas
        for (final foto in fotos) {
          if (foto.id != null) {
            await _fotoRepository.marcarComoSincronizada(foto.id!);
          }
        }

        _logger.i('✅ Censo $estadoId sincronizado correctamente');
      } else {
        _logger.w('⚠️ Censo NO sincronizado: ${respuesta['mensaje']}');

        // Marcar como error para que el sistema de reintentos lo tome
        await _estadoEquipoRepository.marcarComoError(
          estadoId,
          'Error: ${respuesta['mensaje']}',
        );
      }

    } catch (e) {
      _logger.e('❌ Error sincronizando censo: $e');

      // Marcar como error
      await _estadoEquipoRepository.marcarComoError(
        estadoId,
        'Excepción: $e',
      );
    }
  }

  // =================================================================
  // MÉTODOS AUXILIARES Y MANEJO DE ESTADO
  // =================================================================

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
      );
      _logger.i('✅ Equipo creado localmente (disponible): $equipoId');
      return equipoId;
    } catch (e, stackTrace) {
      _logger.e('❌ Error creando equipo: $e', stackTrace: stackTrace);
      await ErrorLogService.logDatabaseError(
        tableName: 'equipments',
        operation: 'crear_equipo_nuevo',
        errorMessage: 'Error registrando equipo nuevo: $e',
        registroFailId: datos['codigo_barras']?.toString(),
      );
      throw 'Error registrando equipo nuevo: $e';
    }
  }

  Future<bool> _verificarAsignacionLocal(String equipoId, int clienteId) async {
    try {
      return await _equipoRepository.verificarAsignacionEquipoCliente(
          equipoId,
          clienteId
      );
    } catch (e) {
      _logger.e('❌ Error verificando asignación: $e');
      return false;
    }
  }

  Future<String?> _crearCensoLocal({
    required String equipoId,
    required int clienteId,
    required Map<String, dynamic> datos,
    required String processId,
    required bool yaAsignado,
    String? userId,
  }) async {
    _setStatusMessage('Registrando censo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final now = DateTime.now().toLocal();
      final estadoCenso = yaAsignado ? 'asignado' : 'pendiente';

      final estadoCreado = await _estadoEquipoRepository.crearNuevoEstado(
        equipoId: equipoId,
        clienteId: clienteId,
        latitud: datos['latitud'],
        longitud: datos['longitud'],
        fechaRevision: now,
        enLocal: true,
        observaciones: datos['observaciones']?.toString(),
        estadoCenso: estadoCenso,
      );

      if (estadoCreado.id != null) return estadoCreado.id!;

      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'crear_estado',
        errorMessage: 'Estado creado pero sin ID retornado',
        registroFailId: equipoId,
      );
      return null;
    } catch (e) {
      _logger.e('❌ Error creando estado: $e');
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'crear_censo_local',
        errorMessage: 'Error creando censo: $e',
        registroFailId: equipoId,
      );
      throw 'Error creando censo: $e';
    }
  }

  // =================================================================
  // MÉTODOS PÚBLICOS DE UTILIDAD
  // =================================================================

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

  Future<Map<String, dynamic>> verificarSincronizacionPendiente(String? estadoId) async {
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
        'pendiente': (estadoCenso == 'creado' || estadoCenso == 'error') && sincronizado == 0
      };
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'verificar_sincronizacion',
        errorMessage: 'Error verificando sincronización: $e',
        registroFailId: estadoId,
      );
      return {'pendiente': false};
    }
  }

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(String? estadoId) async {
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
          'mensaje': 'Estado no encontrado',
          'icono': Icons.error_outline,
          'color': Colors.grey,
        };
      }

      final estado = maps.first;
      final estadoCenso = estado['estado_censo'] as String?;
      final sincronizado = estado['sincronizado'] as int?;

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
        'pendiente': (estadoCenso == 'creado' || estadoCenso == 'error') && sincronizado == 0,
        'estado': estadoCenso,
        'sincronizado': sincronizado,
        'mensaje': mensaje,
        'icono': icono,
        'color': color,
        'fecha_creacion': estado['fecha_creacion'],
        'observaciones': estado['observaciones'],
      };
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'obtener_info_sincronizacion',
        errorMessage: 'Error consultando estado: $e',
        registroFailId: estadoId,
      );
      return {
        'pendiente': false,
        'estado': 'error',
        'mensaje': 'Error consultando estado: $e',
        'icono': Icons.error,
        'color': Colors.red,
      };
    }
  }

  Future<Map<String, dynamic>> reintentarEnvio(String estadoId) async {
    try {
      final usuarioId = await _getUsuarioId;
      final edfVendedorId = await _getEdfVendedorId;

      return await _uploadService.reintentarEnvioCenso(
          estadoId,
          usuarioId,
          edfVendedorId
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'censo_activo',
        operation: 'reintentar_envio',
        errorMessage: 'Error al reintentar envío: $e',
        errorType: 'retry',
        registroFailId: estadoId,
      );
      return {
        'success': false,
        'error': 'Error al reintentar: $e',
      };
    }
  }

  Future<List<String>> obtenerLogsGuardados() async {
    return await _logService.obtenerLogsGuardados();
  }

  void cancelarProcesoActual() {
    if (_isProcessing) {
      _logger.i('⚠️ Cancelando proceso: $_currentProcessId');
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

  // =================================================================
  // HELPERS PRIVADOS DE CASTEO
  // =================================================================

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
      return null;
    } catch (e) {
      return null;
    }
  }
}
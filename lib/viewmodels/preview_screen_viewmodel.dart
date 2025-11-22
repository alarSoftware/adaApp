import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/cliente.dart';
import '../../models/usuario.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/censo/censo_log_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/censo/censo_foto_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/ui/theme/colors.dart';

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
  // MÉTODO PRINCIPAL - LOCAL FIRST, SYNC UNIFICADO
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
      return await _guardarYSincronizarUnificado(datos, processId);
    } finally {
      if (_currentProcessId == processId) {
        _isProcessing = false;
        _currentProcessId = null;
      }
    }
  }

  /// 🔥 GUARDADO LOCAL Y SINCRONIZACIÓN UNIFICADA (CORREGIDA)
  Future<Map<String, dynamic>> _guardarYSincronizarUnificado(
      Map<String, dynamic> datos,
      String processId,
      ) async {
    _setSaving(true);
    String? estadoIdActual;
    String? equipoId;
    int? usuarioId;

    try {
      _logger.i('🔄 Iniciando guardado local y sync unificado [Process: $processId]');

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
            clienteId,
            processId,
            usuarioId.toString()
        );
        _logger.i('✅ Equipo creado localmente: $equipoId');
      } else {
        equipoId = datos['equipo_completo']?['id']?.toString();
        if (equipoId == null) throw 'Equipo ID no válido';
        _logger.i('ℹ️ Usando equipo existente: $equipoId');
      }

      // 🔥 CORRECCIÓN: EQUIPOS NUEVOS SIEMPRE SON PENDIENTES
      bool yaAsignado;
      if (esNuevoEquipo) {
        // Equipos nuevos SIEMPRE son pendientes (necesitan aprobación del servidor)
        yaAsignado = false;
        _logger.i('📋 Equipo NUEVO - Marcando como pendiente automáticamente');
      } else {
        // Solo para equipos existentes verificar asignación real
        yaAsignado = await _verificarAsignacionLocal(equipoId, clienteId);
        _logger.i('📋 Equipo existente - Ya asignado: $yaAsignado');
      }

      // 1B. Crear pendiente LOCAL SOLO si NO está asignado
      if (!yaAsignado) {
        _setStatusMessage('Registrando asignación pendiente...');
        await _equipoPendienteRepository.procesarEscaneoCenso(
          equipoId: equipoId,
          clienteId: clienteId,
          usuarioId: usuarioId,
        );
        _logger.i('✅ Pendiente registrado localmente');
      } else {
        _logger.i('ℹ️ Equipo YA asignado - NO se crea pendiente');
      }

      // 1C. CREAR CENSO LOCAL CON USUARIO GARANTIZADO
      _setStatusMessage('Guardando censo...');
      estadoIdActual = await _crearCensoLocalConUsuario(
        equipoId: equipoId,
        clienteId: clienteId,
        usuarioId: usuarioId,
        datos: datos,
        processId: processId,
        yaAsignado: yaAsignado,
      );

      if (estadoIdActual == null) {
        throw 'No se pudo crear el censo en la base de datos';
      }

      _logger.i('✅ Censo creado localmente: $estadoIdActual (estado: ${yaAsignado ? "asignado" : "pendiente"})');

      // 1D. Guardar fotos LOCAL
      final idsImagenes = await _fotoService.guardarFotosDelCenso(
          estadoIdActual,
          datos
      );

      _logger.i('✅ Fotos guardadas: ${idsImagenes}');

      final tiempoLocal = DateTime.now().difference(now).inSeconds;
      _logger.i('✅ Guardado local completado en ${tiempoLocal}s');

      // ============================================================
      // FASE 2: SINCRONIZACIÓN UNIFICADA EN BACKGROUND
      // ============================================================

      _logger.i('🚀 Lanzando sincronización UNIFICADA en background...');

      // 🔥 NUEVA SINCRONIZACIÓN UNIFICADA - UNA SOLA LLAMADA AL SERVIDOR
      _iniciarSincronizacionUnificadaEnBackground(
        estadoId: estadoIdActual,
        equipoId: equipoId,
        clienteId: clienteId,
        usuarioId: usuarioId,
        esNuevoEquipo: esNuevoEquipo,
        yaAsignado: yaAsignado,
        datos: datos,
      );

      // ============================================================
      // FASE 3: RETORNO INMEDIATO AL USUARIO
      // ============================================================

      // 🔥 AGREGAR equipo_completo para navegación (especialmente equipos nuevos)
      Map<String, dynamic>? equipoCompleto;

      if (esNuevoEquipo) {
        // Para equipos nuevos, construir equipo_completo desde los datos del form
        equipoCompleto = {
          'id': equipoId,
          'cod_barras': datos['codigo_barras']?.toString() ?? '',
          'numero_serie': datos['numero_serie']?.toString(),
          'marca_id': datos['marca_id'],
          'modelo_id': datos['modelo_id'],
          'logo_id': datos['logo_id'],
          'marca_nombre': datos['marca_nombre']?.toString() ?? '',
          'modelo_nombre': datos['modelo']?.toString() ?? '',
          'logo_nombre': datos['logo']?.toString() ?? '',
          'cliente_id': clienteId,
        };
        _logger.i('✅ equipo_completo construido para equipo nuevo');
      } else {
        // Para equipos existentes, usar los datos originales
        equipoCompleto = datos['equipo_completo'] as Map<String, dynamic>?;
        _logger.i('✅ equipo_completo obtenido de datos existentes');
      }

      return {
        'success': true,
        'message': '✅ Registro guardado. Sincronizando unificado en segundo plano...',
        'estado_id': estadoIdActual,
        'equipo_id': equipoId,
        'equipo_completo': equipoCompleto,
        'sincronizacion': 'unificada_background',
        'tiempo_guardado': '${tiempoLocal}s',
        'ya_asignado': yaAsignado,
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
  // 🔥 SINCRONIZACIÓN UNIFICADA EN BACKGROUND (USANDO NUEVO SERVICIO)
  // =================================================================

  /// 🔥 SINCRONIZACIÓN UNIFICADA - UNA SOLA LLAMADA AL SERVIDOR
  void _iniciarSincronizacionUnificadaEnBackground({
    required String estadoId,
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required bool esNuevoEquipo,
    required bool yaAsignado,
    required Map<String, dynamic> datos,
  }) {
    // Lanzar en background con Future.microtask
    Future.microtask(() async {
      try {
        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('🚀 SINCRONIZACIÓN UNIFICADA EN BACKGROUND');
        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('📋 Estado ID: $estadoId');
        _logger.i('📋 Equipo ID: $equipoId');
        _logger.i('📋 Cliente ID: $clienteId');
        _logger.i('📋 Usuario ID: $usuarioId');
        _logger.i('📋 Es nuevo equipo: $esNuevoEquipo');
        _logger.i('📋 Ya asignado: $yaAsignado');
        _logger.i('═══════════════════════════════════════════════════════');

        // Obtener datos necesarios
        final edfVendedorId = await _getEdfVendedorId;
        if (edfVendedorId == null || edfVendedorId.isEmpty) {
          _logger.w('⚠️ Sin edfVendedorId, marcando como error');
          await _estadoEquipoRepository.marcarComoError(estadoId, 'Sin edfVendedorId');

          await ErrorLogService.logValidationError(
            tableName: 'censo_activo',
            operation: 'sync_unificado',
            errorMessage: 'Sin edfVendedorId para sincronizar',
            registroFailId: estadoId,
            userId: usuarioId.toString(),
          );
          return;
        }

        // Obtener fotos del censo
        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        // ✅ DETERMINAR SI CREAR PENDIENTE: Solo si NO está asignado
        final crearPendiente = !yaAsignado;
        _logger.i('📋 Crear pendiente en servidor: $crearPendiente');

        // 🔥 LLAMADA AL SERVICIO UNIFICADO
        final respuesta = await CensoActivoPostService.enviarCensoActivo(
          // Datos del equipo (si es nuevo)
          equipoId: equipoId,
          codigoBarras: datos['codigo_barras']?.toString(),
          marcaId: _safeCastToInt(datos['marca_id'], 'marca_id'),
          modeloId: _safeCastToInt(datos['modelo_id'], 'modelo_id'),
          logoId: _safeCastToInt(datos['logo_id'], 'logo_id'),
          numeroSerie: datos['numero_serie']?.toString(),
          esNuevoEquipo: esNuevoEquipo,

          // Datos del pendiente
          clienteId: clienteId,
          edfVendedorId: edfVendedorId,
          crearPendiente: crearPendiente,

          // Datos del censo activo
          usuarioId: usuarioId,
          latitud: datos['latitud']?.toDouble() ?? 0.0,
          longitud: datos['longitud']?.toDouble() ?? 0.0,
          observaciones: datos['observaciones']?.toString(),
          enLocal: true,
          estadoCenso: yaAsignado ? 'asignado' : 'pendiente',

          // Fotos
          fotos: fotos,

          // Datos adicionales del equipo
          clienteNombre: (datos['cliente'] as Cliente?)?.nombre,
          marca: datos['marca_nombre']?.toString(),
          modelo: datos['modelo']?.toString(),
          logo: datos['logo']?.toString(),

          // Control
          timeoutSegundos: 30,
          userId: usuarioId.toString(),
          guardarLog: true,
        );

        if (respuesta['exito'] == true) {
          // ✅ ÉXITO: Marcar todo como sincronizado
          _logger.i('✅ Sincronización unificada exitosa');

          await _estadoEquipoRepository.marcarComoMigrado(
            estadoId,
            servidorId: respuesta['servidor_id']?.toString(),
          );
          await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

          // Si era nuevo equipo, marcarlo como sincronizado
          if (esNuevoEquipo) {
            await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
          }

          // ✅ SOLO marcar pendientes como sincronizados si efectivamente se crearon
          if (crearPendiente) {
            await _equipoPendienteRepository.marcarSincronizadosPorCenso(equipoId, clienteId);
          }

          // Marcar fotos como sincronizadas
          for (final foto in fotos) {
            if (foto.id != null) {
              await _fotoRepository.marcarComoSincronizada(foto.id!);
            }
          }

          // Marcar errores previos como resueltos
          await ErrorLogService.marcarErroresComoResueltos(
            registroFailId: estadoId,
            tableName: 'censo_activo',
          );

          _logger.i('🎉 TODO sincronizado correctamente en una sola llamada');

        } else {
          // ❌ ERROR: Marcar como error para reintentos
          final errorMsg = respuesta['mensaje'] ?? 'Error desconocido en sincronización';
          _logger.e('❌ Error en sincronización unificada: $errorMsg');

          await _estadoEquipoRepository.marcarComoError(estadoId, errorMsg);

          await ErrorLogService.logError(
            tableName: 'censo_activo',
            operation: 'sync_unificado',
            errorMessage: errorMsg,
            errorType: 'sync',
            errorCode: respuesta['codigo_error']?.toString(),
            registroFailId: estadoId,
            userId: usuarioId.toString(),
          );
        }

        _logger.i('═══════════════════════════════════════════════════════');
        _logger.i('✅ SINCRONIZACIÓN UNIFICADA COMPLETADA');
        _logger.i('═══════════════════════════════════════════════════════');

      } catch (e, stackTrace) {
        _logger.e('❌ Error en sincronización unificada: $e', stackTrace: stackTrace);

        // Marcar como error para que el sistema de reintentos lo tome
        await _estadoEquipoRepository.marcarComoError(
          estadoId,
          'Excepción unificada: $e',
        );

        await ErrorLogService.logError(
          tableName: 'censo_activo',
          operation: 'sync_unificado_background',
          errorMessage: 'Error en sync unificado: $e',
          errorType: 'sync',
          registroFailId: estadoId,
          userId: usuarioId.toString(),
        );
      }
    });
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
        clienteId: clienteId,
      );
      if (clienteId != null) {
        _logger.i('✅ Equipo creado y PRE-ASIGNADO al cliente $clienteId: $equipoId');
      } else {
        _logger.i('✅ Equipo creado localmente (disponible): $equipoId');
      }
      return equipoId;
    } catch (e, stackTrace) {
      _logger.e('❌ Error creando equipo: $e', stackTrace: stackTrace);
      await ErrorLogService.logDatabaseError(
        tableName: 'equipos',
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

  /// 🔥 MÉTODO CORREGIDO PARA CREAR CENSO CON USUARIO GARANTIZADO
  Future<String?> _crearCensoLocalConUsuario({
    required String equipoId,
    required int clienteId,
    required int usuarioId,
    required Map<String, dynamic> datos,
    required String processId,
    required bool yaAsignado,
  }) async {
    _setStatusMessage('Registrando censo...');

    if (_currentProcessId != processId) throw 'Proceso cancelado';

    try {
      final now = DateTime.now().toLocal();
      final estadoCenso = yaAsignado ? 'asignado' : 'pendiente';

      // 🔥 USAR MÉTODO EXISTENTE
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

      if (estadoCreado.id != null) {
        // 🔥 INMEDIATAMENTE DESPUÉS ACTUALIZAR EL USUARIO_ID
        await _estadoEquipoRepository.dbHelper.actualizar(
          'censo_activo',
          {
            'usuario_id': usuarioId,
            'fecha_actualizacion': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [estadoCreado.id!],
        );

        _logger.i('✅ Censo creado y usuario_id actualizado: $usuarioId');

        // 🔥 VERIFICAR QUE SE GUARDÓ CORRECTAMENTE
        final verificacion = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoCreado.id!],
          limit: 1,
        );

        if (verificacion.isNotEmpty) {
          final usuarioEnBD = verificacion.first['usuario_id'];
          _logger.i('✅ Verificación - usuario_id en BD: $usuarioEnBD');

          if (usuarioEnBD == null) {
            _logger.e('❌ usuario_id sigue siendo NULL después de actualizar');
            throw 'Error: usuario_id no se pudo guardar en la BD';
          }
        }

        return estadoCreado.id!;
      }

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

  Future<Map<String, dynamic>> obtenerInfoSincronizacion(String? censoActivoId) async {
    if (censoActivoId == null) {
      return {
        'estado': 'desconocido',
        'mensaje': 'Estado desconocido',
        'icono': Icons.help_outline,
        'color': AppColors.textSecondary,
        'error_detalle': null,
      };
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // Consultar el estado del censo
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
        };
      }

      final estadoCenso = result.first['estado_censo'] as String?;
      final sincronizado = result.first['sincronizado'] as int?;

      // Determinar el estado real
      String estado;
      if (sincronizado == 1) {
        estado = 'sincronizado';
      } else if (estadoCenso == 'error') {
        estado = 'error';
      } else {
        estado = estadoCenso ?? 'creado';
      }

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
          };

        case 'sincronizado': {
          // Buscar si hubo errores previos (incluso resueltos)
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

              errorDetalle = 'Sincronizado después de ${retryCount + 1} intento(s)';
              errorDetalle += '\n\n📌 Último error encontrado:';
              errorDetalle += '\n$errorMessage';

              if (errorCode != null) {
                errorDetalle += '\n\n🔖 Código: $errorCode';
              }

              if (endpoint != null) {
                errorDetalle += '\n🌐 Endpoint: ${_formatEndpoint(endpoint)}';
              }
            }
          }

          return {
            'estado': estado,
            'mensaje': 'Sincronizado exitosamente',
            'icono': Icons.check_circle,
            'color': AppColors.success,
            'error_detalle': errorDetalle,
          };

        }
        case 'error': {
          // Buscar el error más reciente en error_log para este censo
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
            final nextRetryAt = errorLog.first['next_retry_at'] as String?;
            final timestamp = errorLog.first['timestamp'] as String?;

            // CONSTRUIR MENSAJE DETALLADO
            errorDetalle = errorMessage ?? 'Error desconocido';

            // Tipo de error
            if (errorType != null && errorType != 'unknown') {
              errorDetalle = '$errorDetalle\n\nTipo: ${_formatErrorType(errorType)}';
            }

            // Código de error
            if (errorCode != null) {
              errorDetalle = '$errorDetalle\nCódigo: $errorCode';
            }

            // Endpoint
            if (endpoint != null) {
              errorDetalle = '$errorDetalle\nEndpoint: ${_formatEndpoint(endpoint)}';
            }

            // Información de reintentos
            if (retryCount > 0) {
              errorDetalle = '$errorDetalle\n\nReintentos realizados: $retryCount';

              if (nextRetryAt != null) {
                try {
                  final nextRetry = DateTime.parse(nextRetryAt);
                  final now = DateTime.now();
                  if (nextRetry.isAfter(now)) {
                    final diff = nextRetry.difference(now);
                    final minutos = diff.inMinutes;
                    if (minutos > 60) {
                      final horas = (minutos / 60).floor();
                      errorDetalle = '$errorDetalle\nPróximo intento en: ${horas}h ${minutos % 60}min';
                    } else {
                      errorDetalle = '$errorDetalle\nPróximo intento en: ${minutos}min';
                    }
                  } else {
                    errorDetalle = '$errorDetalle\nListo para reintentar';
                  }
                } catch (e) {
                  // Ignorar error de parsing de fecha
                }
              }
            }

            // Timestamp del error
            if (timestamp != null) {
              try {
                final errorDate = DateTime.parse(timestamp);
                errorDetalle = '$errorDetalle\n\nOcurrió el: ${_formatTimestamp(errorDate)}';
              } catch (e) {
                // Ignorar error de parsing
              }
            }

          } else {
            // Si no hay error en error_log, buscar en el campo error_mensaje de censo_activo
            errorDetalle = result.first['error_mensaje'] as String?;
            if (errorDetalle != null) {
              errorDetalle = '$errorDetalle\n\n(Sin detalles adicionales registrados)';
            }
          }

          return {
            'estado': estado,
            'mensaje': 'Error de sincronización',
            'icono': Icons.error,
            'color': AppColors.error,
            'error_detalle': errorDetalle ?? 'No se encontró detalle del error',
          };

        }

        default:
          return {
            'estado': 'desconocido',
            'mensaje': 'Estado: $estado',
            'icono': Icons.help_outline,
            'color': AppColors.textSecondary,
            'error_detalle': null,
          };
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo info de sincronización: $e');
      return {
        'estado': 'error',
        'mensaje': 'Error consultando estado',
        'icono': Icons.error_outline,
        'color': AppColors.error,
        'error_detalle': e.toString(),
      };
    }
  }

  // Métodos helper para formatear información
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
    // Acortar URLs largas para mejor legibilidad
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
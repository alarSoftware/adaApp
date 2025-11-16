import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/services/database_validation_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/sync_service.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/post/dynamic_form_post_service.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/post/equipo_pendiente_post_service.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:convert';

// ========== MODELOS DE DATOS ==========
class PendingDataGroup {
  final String tableName;
  final String displayName;
  final int count;
  final PendingDataType type;
  final String description;

  PendingDataGroup({
    required this.tableName,
    required this.displayName,
    required this.count,
    required this.type,
    required this.description,
  });
}

enum PendingDataType {
  forms,
  census,
  images,
  equipment,
  logs,
}

class SendResult {
  final bool success;
  final String tableName;
  final int itemsSent;
  final String message;
  final String? error;

  SendResult({
    required this.success,
    required this.tableName,
    required this.itemsSent,
    required this.message,
    this.error,
  });
}

class BulkSendResult {
  final bool allSuccess;
  final int totalItemsSent;
  final List<SendResult> results;
  final String summary;

  BulkSendResult({
    required this.allSuccess,
    required this.totalItemsSent,
    required this.results,
    required this.summary,
  });
}

// ========== EVENTOS PARA LA UI ==========
abstract class PendingDataUIEvent {}

class ShowErrorEvent extends PendingDataUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class ShowSuccessEvent extends PendingDataUIEvent {
  final String message;
  ShowSuccessEvent(this.message);
}

class RequestBulkSendConfirmationEvent extends PendingDataUIEvent {
  final List<PendingDataGroup> groups;
  final int totalItems;
  RequestBulkSendConfirmationEvent(this.groups, this.totalItems);
}

class SendProgressEvent extends PendingDataUIEvent {
  final double progress;
  final String currentStep;
  final int completedCount;
  final int totalCount;

  SendProgressEvent({
    required this.progress,
    required this.currentStep,
    required this.completedCount,
    required this.totalCount,
  });
}

class SendCompletedEvent extends PendingDataUIEvent {
  final BulkSendResult result;
  SendCompletedEvent(this.result);
}

// ========== CONFIGURACIÓN DE ENVÍO ==========
class SendConfiguration {
  final int maxRetries;
  final Duration timeout;
  final Duration retryDelay;
  final int batchSize;
  final Duration autoSyncInterval;

  const SendConfiguration({
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 2),
    this.batchSize = 10,
    this.autoSyncInterval = const Duration(minutes: 15),
  });
}

// ========== VIEWMODEL ==========
class PendingDataViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SendConfiguration _config = const SendConfiguration();

  // ========== ESTADO INTERNO ==========
  bool _isLoading = false;
  bool _isSending = false;
  List<PendingDataGroup> _pendingGroups = [];
  int _totalPendingItems = 0;
  String _lastUpdateTime = '';
  bool _isConnected = true;

  // Estado de envío
  double _sendProgress = 0.0;
  String _sendCurrentStep = '';
  int _sendCompletedCount = 0;
  int _sendTotalCount = 0;

  // Control de cancelación
  bool _isCancelled = false;

  // 🆕 Auto-sincronización
  Timer? _autoSyncTimer;
  bool _autoSyncEnabled = false;

  // ========== STREAMS PARA COMUNICACIÓN ==========
  final StreamController<PendingDataUIEvent> _eventController =
  StreamController<PendingDataUIEvent>.broadcast();
  Stream<PendingDataUIEvent> get uiEvents => _eventController.stream;

  // ========== GETTERS PÚBLICOS ==========
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  List<PendingDataGroup> get pendingGroups => List.from(_pendingGroups);
  int get totalPendingItems => _totalPendingItems;
  String get lastUpdateTime => _lastUpdateTime;
  bool get hasPendingData => _totalPendingItems > 0;
  bool get isConnected => _isConnected;

  // Getters de progreso de envío
  double get sendProgress => _sendProgress;
  String get sendCurrentStep => _sendCurrentStep;
  int get sendCompletedCount => _sendCompletedCount;
  int get sendTotalCount => _sendTotalCount;

  // 🆕 Getters de auto-sync
  bool get autoSyncEnabled => _autoSyncEnabled;
  Duration get autoSyncInterval => _config.autoSyncInterval;

  // ========== CONSTRUCTOR ==========
  PendingDataViewModel() {
    loadPendingData();
    iniciarSincronizacionAutomatica();
  }

  @override
  void dispose() {
    detenerSincronizacionAutomatica();
    _eventController.close();
    super.dispose();
  }

  // ========== 🆕 MÉTODOS DE SINCRONIZACIÓN AUTOMÁTICA ==========

  /// Inicia la sincronización automática periódica
  void iniciarSincronizacionAutomatica() {
    if (_autoSyncEnabled) {
      _logger.i('⚠️ Sincronización automática ya está activa');
      return;
    }

    _autoSyncEnabled = true;
    _logger.i('🚀 Iniciando sincronización automática cada ${_config.autoSyncInterval.inMinutes} minutos');

    // Primera sincronización después de 2 minutos (para dar tiempo al inicio)
    Timer(const Duration(minutes: 2), () async {
      if (_autoSyncEnabled) {
        await _ejecutarAutoSync();
      }
    });

    // Sincronización periódica
    _autoSyncTimer = Timer.periodic(_config.autoSyncInterval, (timer) async {
      await _ejecutarAutoSync();
    });

    notifyListeners();
  }

  /// Detiene la sincronización automática
  void detenerSincronizacionAutomatica() {
    if (_autoSyncTimer != null) {
      _autoSyncTimer!.cancel();
      _autoSyncTimer = null;
      _autoSyncEnabled = false;
      _logger.i('⏹️ Sincronización automática detenida');
      notifyListeners();
    }
  }

  /// Toggle para activar/desactivar auto-sync manualmente
  void toggleAutoSync() {
    if (_autoSyncEnabled) {
      detenerSincronizacionAutomatica();
      _eventController.add(ShowSuccessEvent('Sincronización automática desactivada'));
    } else {
      iniciarSincronizacionAutomatica();
      _eventController.add(ShowSuccessEvent('Sincronización automática activada'));
    }
  }

  /// Ejecuta la sincronización automática en background
  Future<void> _ejecutarAutoSync() async {
    // No ejecutar si ya hay un envío en progreso
    if (_isSending) {
      _logger.i('⏭️ Auto-sync saltado: envío manual en progreso');
      return;
    }

    // No ejecutar si no hay conexión
    final connected = await _checkConnectivity();
    if (!connected) {
      _logger.i('⏭️ Auto-sync saltado: sin conexión');
      return;
    }

    // Recargar datos para ver si hay pendientes
    await loadPendingData();

    if (!hasPendingData) {
      _logger.i('✅ Auto-sync: No hay datos pendientes');
      return;
    }

    _logger.i('🔄 Ejecutando auto-sync: $_totalPendingItems elementos pendientes');

    try {
      await _executarAutoSyncSilencioso();
    } catch (e) {
      _logger.e('❌ Error en auto-sync: $e');
    }
  }

  /// Ejecuta el envío automático de forma silenciosa (sin mostrar todos los diálogos)
  Future<void> _executarAutoSyncSilencioso() async {
    _setSending(true);
    _resetSendProgress();
    _isCancelled = false;

    try {
      final results = <SendResult>[];
      int totalSent = 0;

      _sendTotalCount = _pendingGroups.length;
      _sendCompletedCount = 0;

      for (int i = 0; i < _pendingGroups.length; i++) {
        if (_isCancelled) break;

        final group = _pendingGroups[i];

        _updateSendProgress(
          progress: (i / _pendingGroups.length),
          currentStep: 'Auto-sync: ${group.displayName}...',
          completedCount: i,
        );

        try {
          // Solo intentar una vez (sin reintentos) en auto-sync
          final result = await _sendDataGroup(group);
          results.add(result);

          if (result.success) {
            totalSent += result.itemsSent;
            _logger.i('✅ Auto-sync ${group.displayName}: ${result.itemsSent} elementos');
          }
        } catch (e) {
          _logger.w('⚠️ Auto-sync error en ${group.displayName}: $e');
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      _updateSendProgress(
        progress: 1.0,
        currentStep: 'Auto-sync completado',
        completedCount: _pendingGroups.length,
      );

      // Recargar datos
      await loadPendingData();

      // Solo mostrar mensaje si se envió algo
      if (totalSent > 0) {
        final successCount = results.where((r) => r.success).length;
        _eventController.add(ShowSuccessEvent(
            '🔄 Auto-sync: $totalSent elementos enviados ($successCount/${results.length} categorías)'
        ));
      }

      _logger.i('✅ Auto-sync completado: $totalSent elementos enviados');

    } catch (e) {
      _logger.e('💥 Error en auto-sync: $e');
    } finally {
      _setSending(false);
      _resetSendProgress();
    }
  }

  // ========== MÉTODOS PÚBLICOS ==========

  /// Carga los datos pendientes desde la base de datos
  Future<void> loadPendingData() async {
    _setLoading(true);

    try {
      _logger.i('🔍 Cargando datos pendientes...');

      final db = await _dbHelper.database;
      final validationService = DatabaseValidationService(db);

      final summary = await validationService.getPendingSyncSummary();

      _totalPendingItems = summary['total_pending'] ?? 0;

      final pendingByTable = summary['pending_by_table'] as List<dynamic>? ?? [];

      _pendingGroups = pendingByTable.map((item) {
        final tableName = item['table'] as String;
        final displayName = item['display_name'] as String;
        final count = item['count'] as int;

        return PendingDataGroup(
          tableName: tableName,
          displayName: displayName,
          count: count,
          type: _getDataType(tableName),
          description: _getDescription(tableName),
        );
      }).toList();

      // Ordenar por tipo y luego por nombre
      _pendingGroups.sort((a, b) {
        final typeCompare = a.type.index.compareTo(b.type.index);
        if (typeCompare != 0) return typeCompare;
        return a.displayName.compareTo(b.displayName);
      });

      _lastUpdateTime = DateTime.now().toString().substring(0, 19);

      _logger.i('✅ Datos pendientes cargados: $_totalPendingItems items en ${_pendingGroups.length} grupos');

    } catch (e) {
      _logger.e('❌ Error cargando datos pendientes: $e');
      _eventController.add(ShowErrorEvent('Error cargando datos: $e'));
    } finally {
      _setLoading(false);
    }
  }

  /// Verifica la conectividad
  Future<bool> _checkConnectivity() async {
    try {
      final conexion = await SyncService.probarConexion();
      _isConnected = conexion.exito;
      notifyListeners();
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Solicita confirmación para envío masivo
  Future<void> requestBulkSend() async {
    if (_isSending || _pendingGroups.isEmpty) return;

    try {
      // Verificar conexión
      final connected = await _checkConnectivity();
      if (!connected) {
        _eventController.add(ShowErrorEvent('Sin conexión al servidor. Verifique su conexión a Internet.'));
        return;
      }

      // Solicitar confirmación
      _eventController.add(RequestBulkSendConfirmationEvent(_pendingGroups, _totalPendingItems));

    } catch (e) {
      _eventController.add(ShowErrorEvent('Error verificando conexión: $e'));
    }
  }

  /// Ejecuta el envío masivo de datos pendientes
  Future<void> executeBulkSend() async {
    if (_isSending) return;

    _setSending(true);
    _resetSendProgress();
    _isCancelled = false;

    try {
      _logger.i('🚀 Iniciando envío masivo de datos pendientes...');

      // Verificar conexión una vez más antes de empezar
      final connected = await _checkConnectivity();
      if (!connected) {
        _eventController.add(ShowErrorEvent('Conexión perdida. No se puede proceder con el envío.'));
        return;
      }

      final results = <SendResult>[];
      int totalSent = 0;

      // Configurar progreso
      _sendTotalCount = _pendingGroups.length;
      _sendCompletedCount = 0;

      for (int i = 0; i < _pendingGroups.length; i++) {
        // Verificar cancelación
        if (_isCancelled) {
          _logger.i('🛑 Envío cancelado por el usuario');
          _eventController.add(ShowErrorEvent('Envío cancelado por el usuario'));
          return;
        }

        final group = _pendingGroups[i];

        _updateSendProgress(
          progress: (i / _pendingGroups.length),
          currentStep: 'Enviando ${group.displayName}... (${group.count} elementos)',
          completedCount: i,
        );

        try {
          final result = await _sendDataGroupWithRetry(group);
          results.add(result);

          if (result.success) {
            totalSent += result.itemsSent;
            _logger.i('✅ ${group.displayName}: ${result.itemsSent} elementos enviados');
          } else {
            _logger.w('⚠️ ${group.displayName}: ${result.error}');
          }

        } catch (e) {
          _logger.e('❌ Error enviando ${group.displayName}: $e');
          results.add(SendResult(
            success: false,
            tableName: group.tableName,
            itemsSent: 0,
            message: 'Error en envío: $e',
            error: e.toString(),
          ));
        }

        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Completar progreso
      _updateSendProgress(
        progress: 1.0,
        currentStep: 'Envío completado',
        completedCount: _pendingGroups.length,
      );

      // Crear resultado final
      final allSuccess = results.every((r) => r.success);
      final successCount = results.where((r) => r.success).length;

      final summary = allSuccess
          ? 'Todos los datos enviados correctamente ($totalSent elementos)'
          : '$successCount de ${results.length} grupos enviados exitosamente ($totalSent elementos)';

      final bulkResult = BulkSendResult(
        allSuccess: allSuccess,
        totalItemsSent: totalSent,
        results: results,
        summary: summary,
      );

      _eventController.add(SendCompletedEvent(bulkResult));

      // Recargar datos para actualizar la vista
      await loadPendingData();

      if (allSuccess) {
        _eventController.add(ShowSuccessEvent('¡Envío completado exitosamente!'));
      }

      _logger.i('✅ Envío masivo completado: $summary');

    } catch (e) {
      _logger.e('💥 Error en envío masivo: $e');
      _eventController.add(ShowErrorEvent('Error en envío masivo: $e'));
    } finally {
      _setSending(false);
      _resetSendProgress();
    }
  }

  /// Cancela el envío en progreso
  void cancelSend() {
    if (_isSending) {
      _isCancelled = true;
      _logger.i('🛑 Cancelación solicitada...');
    }
  }

  /// Refresca los datos pendientes
  Future<void> refresh() async {
    await loadPendingData();
  }

  // ========== MÉTODOS PRIVADOS ==========

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSending(bool sending) {
    _isSending = sending;
    notifyListeners();
  }

  void _resetSendProgress() {
    _sendProgress = 0.0;
    _sendCurrentStep = '';
    _sendCompletedCount = 0;
    _sendTotalCount = 0;
    notifyListeners();
  }

  void _updateSendProgress({
    required double progress,
    required String currentStep,
    required int completedCount,
  }) {
    _sendProgress = progress;
    _sendCurrentStep = currentStep;
    _sendCompletedCount = completedCount;

    _eventController.add(SendProgressEvent(
      progress: progress,
      currentStep: currentStep,
      completedCount: completedCount,
      totalCount: _sendTotalCount,
    ));

    notifyListeners();
  }

  /// Envía un grupo de datos con reintentos
  Future<SendResult> _sendDataGroupWithRetry(PendingDataGroup group) async {
    for (int attempt = 0; attempt <= _config.maxRetries; attempt++) {
      try {
        final result = await _sendDataGroup(group);
        return await Future.any([
          Future.value(result),
          Future.delayed(_config.timeout).then((_) => throw TimeoutException('Timeout', _config.timeout)),
        ]);
      } catch (e) {
        if (attempt == _config.maxRetries) {
          return SendResult(
            success: false,
            tableName: group.tableName,
            itemsSent: 0,
            message: 'Falló después de ${_config.maxRetries + 1} intentos',
            error: e.toString(),
          );
        }

        _logger.w('🔄 Reintentando ${group.displayName} (intento ${attempt + 1}/${_config.maxRetries + 1})');
        await Future.delayed(_config.retryDelay);
      }
    }

    return SendResult(
      success: false,
      tableName: group.tableName,
      itemsSent: 0,
      message: 'Error inesperado en reintentos',
    );
  }

  PendingDataType _getDataType(String tableName) {
    switch (tableName) {
      case 'dynamic_form_response':
      case 'dynamic_form_response_detail':
      case 'dynamic_form_response_image':
        return PendingDataType.forms;
      case 'censo_activo':
      case 'censo_activo_foto':
        return PendingDataType.census;
      case 'equipos_pendientes':
        return PendingDataType.equipment;
      case 'device_log':
        return PendingDataType.logs;
      default:
        return PendingDataType.forms;
    }
  }

  String _getDescription(String tableName) {
    switch (tableName) {
      case 'dynamic_form_response':
        return 'Respuestas de formularios completados';
      case 'dynamic_form_response_detail':
        return 'Detalles de respuestas de formularios';
      case 'dynamic_form_response_image':
        return 'Imágenes adjuntas a formularios';
      case 'censo_activo':
        return 'Censos realizados pendientes de envío';
      case 'censo_activo_foto':
        return 'Fotos tomadas durante censos';
      case 'equipos_pendientes':
        return 'Equipos registrados localmente (simulación)';
      case 'device_log':
        return 'Registros de actividad del dispositivo';
      default:
        return 'Datos pendientes de sincronización';
    }
  }

  /// Envía un grupo específico de datos
  Future<SendResult> _sendDataGroup(PendingDataGroup group) async {
    try {
      _logger.i('📤 Enviando ${group.displayName} (${group.count} elementos)...');

      switch (group.type) {
        case PendingDataType.forms:
          return await _sendForms(group);
        case PendingDataType.census:
          return await _sendCensus(group);
        case PendingDataType.equipment:
          return await _sendEquipment(group);
        case PendingDataType.images:
          return await _sendImages(group);
        case PendingDataType.logs:
          return await _sendLogs(group);
      }

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío',
        error: e.toString(),
      );
    }
  }

  // ========== IMPLEMENTACIÓN USANDO TU ESQUEMA REAL ==========

  Future<SendResult> _sendForms(PendingDataGroup group) async {
    try {
      final db = await _dbHelper.database;

      // Usar sync_status como está en tu esquema
      final pendingForms = await db.query(
        'dynamic_form_response',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'creation_date ASC',
      );

      if (pendingForms.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay formularios pendientes',
        );
      }

      int sentCount = 0;
      final errors = <String>[];

      for (final form in pendingForms) {
        if (_isCancelled) break;

        try {
          // Preparar respuesta como lo espera el servicio existente
          final respuesta = await _prepareFormResponse(form);

          // Usar el servicio existente DynamicFormPostService
          final response = await DynamicFormPostService.enviarRespuestaFormulario(
            respuesta: respuesta,
            incluirLog: true,
          );

          if (response['exito'] == true) {
            // Marcar como enviado usando campos de tu esquema
            await db.update(
              'dynamic_form_response',
              {
                'sync_status': 'sent',
                'fecha_sincronizado': DateTime.now().toIso8601String(),
                'last_update_date': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [form['id']],
            );

            // Marcar detalles como enviados
            await db.update(
              'dynamic_form_response_detail',
              {'sync_status': 'sent'},
              where: 'dynamic_form_response_id = ?',
              whereArgs: [form['id']],
            );

            // Marcar imágenes como enviadas
            await db.execute('''
              UPDATE dynamic_form_response_image 
              SET sync_status = 'sent' 
              WHERE dynamic_form_response_detail_id IN (
                SELECT id FROM dynamic_form_response_detail 
                WHERE dynamic_form_response_id = ?
              )
            ''', [form['id']]);

            sentCount++;
          } else {
            // Incrementar intentos de sync
            await db.update(
              'dynamic_form_response',
              {
                'intentos_sync': (form['intentos_sync'] as int? ?? 0) + 1,
                'ultimo_intento_sync': DateTime.now().toIso8601String(),
                'mensaje_error_sync': response['mensaje'] ?? 'Error desconocido',
              },
              where: 'id = ?',
              whereArgs: [form['id']],
            );

            errors.add('Formulario ${form['id']}: ${response['mensaje'] ?? 'Error desconocido'}');
          }

        } catch (e) {
          errors.add('Formulario ${form['id']}: $e');
        }
      }

      final success = sentCount > 0;
      final message = success
          ? '$sentCount de ${pendingForms.length} formularios enviados'
          : 'No se pudieron enviar formularios: ${errors.join(', ')}';

      return SendResult(
        success: success,
        tableName: group.tableName,
        itemsSent: sentCount,
        message: message,
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío de formularios',
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _prepareFormResponse(Map<String, Object?> form) async {
    final db = await _dbHelper.database;

    // Obtener detalles del formulario
    final details = await db.query(
      'dynamic_form_response_detail',
      where: 'dynamic_form_response_id = ?',
      whereArgs: [form['id']],
    );

    // Obtener imágenes del formulario (relación a través de detail)
    final images = await db.rawQuery('''
      SELECT dri.* FROM dynamic_form_response_image dri
      INNER JOIN dynamic_form_response_detail drd ON dri.dynamic_form_response_detail_id = drd.id
      WHERE drd.dynamic_form_response_id = ?
    ''', [form['id']]);

    // Preparar la respuesta en el formato que espera tu servicio
    return {
      'id': form['id'],
      'dynamic_form_id': form['dynamic_form_id'],
      'usuario_id': form['usuario_id'],
      'contacto_id': form['contacto_id'],
      'edf_vendedor_id': form['edf_vendedor_id'],
      'creation_date': form['creation_date'],
      'last_update_date': form['last_update_date'],
      'estado': form['estado'],
      'details': details,
      'images': images,
    };
  }

  Future<SendResult> _sendCensus(PendingDataGroup group) async {
    try {
      final db = await _dbHelper.database;

      // Usar sincronizado = 0 para datos pendientes
      final pendingCensus = await db.query(
        'censo_activo',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_creacion ASC',
      );

      if (pendingCensus.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay censos pendientes',
        );
      }

      int sentCount = 0;
      final errors = <String>[];

      for (final censo in pendingCensus) {
        if (_isCancelled) break;

        try {
          // Preparar datos usando tu servicio existente
          final position = Position(
            latitude: (censo['latitud'] as num?)?.toDouble() ?? 0.0,
            longitude: (censo['longitud'] as num?)?.toDouble() ?? 0.0,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );

          // Obtener fotos del censo
          final fotos = await db.query(
            'censo_activo_foto',
            where: 'censo_activo_id = ? AND sincronizado = ?',
            whereArgs: [censo['id'], 0],
            orderBy: 'orden ASC',
          );

          String? imagenBase64;
          String? imagenBase64_2;

          if (fotos.isNotEmpty) {
            imagenBase64 = fotos.first['imagen_base64'] as String?;
            if (fotos.length > 1) {
              imagenBase64_2 = fotos[1]['imagen_base64'] as String?;
            }
          }

          // Usar tu servicio existente CensoActivoPostService
          final response = await CensoActivoPostService.enviarCambioEstado(
            codigoBarras: censo['equipo_id']?.toString() ?? '',
            clienteId: (censo['cliente_id'] as num?)?.toInt() ?? 0,
            enLocal: (censo['en_local'] as num?) == 1,
            position: position,
            observaciones: censo['observaciones']?.toString(),
            imagenBase64: imagenBase64,
            imagenBase64_2: imagenBase64_2,
            equipoId: censo['equipo_id']?.toString(),
          );

          if (response['exito'] == true) {
            // Marcar como enviado
            await db.update(
              'censo_activo',
              {
                'sincronizado': 1,
                'fecha_actualizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [censo['id']],
            );

            // Marcar fotos como enviadas
            await db.update(
              'censo_activo_foto',
              {'sincronizado': 1},
              where: 'censo_activo_id = ?',
              whereArgs: [censo['id']],
            );

            sentCount++;
          } else {
            errors.add('Censo ${censo['id']}: ${response['mensaje'] ?? 'Error desconocido'}');
          }

        } catch (e) {
          errors.add('Censo ${censo['id']}: $e');
        }
      }

      final success = sentCount > 0;
      final message = success
          ? '$sentCount de ${pendingCensus.length} censos enviados'
          : 'No se pudieron enviar censos: ${errors.join(', ')}';

      return SendResult(
        success: success,
        tableName: group.tableName,
        itemsSent: sentCount,
        message: message,
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío de censos',
        error: e.toString(),
      );
    }
  }

  Future<SendResult> _sendEquipment(PendingDataGroup group) async {
    try {
      final db = await _dbHelper.database;

      _logger.i('📤 Enviando equipos pendientes...');

      // Obtener equipos pendientes reales
      final pendingEquipment = await db.query(
        'equipos_pendientes',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_creacion ASC',
      );

      if (pendingEquipment.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay equipos pendientes',
        );
      }

      int sentCount = 0;
      final errors = <String>[];

      for (final equipo in pendingEquipment) {
        if (_isCancelled) break;

        try {
          _logger.i('📤 Enviando equipo: ${equipo['equipo_id']}');

          // ✅ USAR EL SERVICIO REAL
          final response = await EquiposPendientesApiService.enviarEquipoPendiente(
            equipoId: equipo['equipo_id'] as String,
            clienteId: int.parse(equipo['cliente_id'] as String),
            edfVendedorId: equipo['usuario_censo_id']?.toString() ?? '',
          );

          if (response['exito'] == true) {
            // Marcar como sincronizado
            await db.update(
              'equipos_pendientes',
              {
                'sincronizado': 1,
                'fecha_sincronizacion': DateTime.now().toIso8601String(),
                'fecha_actualizacion': DateTime.now().toIso8601String(),
                'error_mensaje': null, // Limpiar error previo
              },
              where: 'id = ?',
              whereArgs: [equipo['id']],
            );

            sentCount++;
            _logger.i('✅ Equipo ${equipo['equipo_id']} enviado exitosamente');
          } else {
            // Incrementar intentos y guardar error
            final intentosActuales = (equipo['intentos_sync'] as int? ?? 0);
            await db.update(
              'equipos_pendientes',
              {
                'intentos_sync': intentosActuales + 1,
                'ultimo_intento': DateTime.now().toIso8601String(),
                'error_mensaje': response['mensaje'] ?? 'Error desconocido',
              },
              where: 'id = ?',
              whereArgs: [equipo['id']],
            );

            errors.add('Equipo ${equipo['equipo_id']}: ${response['mensaje'] ?? 'Error desconocido'}');
            _logger.w('⚠️ Equipo ${equipo['equipo_id']} falló: ${response['mensaje']}');
          }

        } catch (e) {
          // Guardar error de excepción
          await db.update(
            'equipos_pendientes',
            {
              'intentos_sync': ((equipo['intentos_sync'] as int? ?? 0) + 1),
              'ultimo_intento': DateTime.now().toIso8601String(),
              'error_mensaje': e.toString(),
            },
            where: 'id = ?',
            whereArgs: [equipo['id']],
          );

          errors.add('Equipo ${equipo['equipo_id']}: $e');
          _logger.e('❌ Error enviando equipo ${equipo['equipo_id']}: $e');
        }
      }

      final success = sentCount > 0;
      final message = success
          ? '$sentCount de ${pendingEquipment.length} equipos enviados'
          : 'No se pudieron enviar equipos: ${errors.join(', ')}';

      _logger.i('📊 Equipos completados: $sentCount exitosos, ${errors.length} errores');

      return SendResult(
        success: success,
        tableName: group.tableName,
        itemsSent: sentCount,
        message: message,
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío de equipos',
        error: e.toString(),
      );
    }
  }

  Future<SendResult> _sendImages(PendingDataGroup group) async {
    try {
      final db = await _dbHelper.database;

      final pendingImages = await db.query(
        'dynamic_form_response_image',
        where: 'sync_status = ? AND imagen_base64 IS NOT NULL',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );

      if (pendingImages.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay imágenes pendientes',
        );
      }

      int sentCount = 0;
      final errors = <String>[];

      for (int i = 0; i < pendingImages.length; i += _config.batchSize) {
        if (_isCancelled) break;

        final batch = pendingImages.skip(i).take(_config.batchSize).toList();

        for (final image in batch) {
          try {
            final response = await BasePostService.post(
              endpoint: '/api/upload-image',
              body: {
                'image_id': image['id'],
                'dynamic_form_response_detail_id': image['dynamic_form_response_detail_id'],
                'imagen_base64': image['imagen_base64'],
                'mime_type': image['mime_type'],
                'orden': image['orden'],
              },
              timeout: const Duration(seconds: 60),
            );

            if (response['exito'] == true) {
              await db.update(
                'dynamic_form_response_image',
                {'sync_status': 'sent'},
                where: 'id = ?',
                whereArgs: [image['id']],
              );

              sentCount++;
            } else {
              errors.add('Imagen ${image['id']}: ${response['mensaje'] ?? 'Error desconocido'}');
            }

          } catch (e) {
            errors.add('Imagen ${image['id']}: $e');
          }
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }

      final success = sentCount > 0;
      final message = success
          ? '$sentCount de ${pendingImages.length} imágenes enviadas'
          : 'No se pudieron enviar imágenes: ${errors.join(', ')}';

      return SendResult(
        success: success,
        tableName: group.tableName,
        itemsSent: sentCount,
        message: message,
        error: errors.isNotEmpty ? errors.join('; ') : null,
      );

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío de imágenes',
        error: e.toString(),
      );
    }
  }

  Future<SendResult> _sendLogs(PendingDataGroup group) async {
    try {
      final db = await _dbHelper.database;

      final pendingLogsData = await db.query(
        'device_log',
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_registro DESC',
        limit: 1000,
      );

      if (pendingLogsData.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay logs pendientes',
        );
      }

      final pendingLogs = pendingLogsData.map((logData) => DeviceLog.fromMap(logData)).toList();

      final resultado = await DeviceLogPostService.enviarDeviceLogsBatch(pendingLogs);

      final sentCount = resultado['exitosos'] ?? 0;
      final failedCount = resultado['fallidos'] ?? 0;

      if (sentCount > 0) {
        if (sentCount > failedCount) {
          await db.update(
            'device_log',
            {'sincronizado': 1},
            where: 'sincronizado = ?',
            whereArgs: [0],
          );
        }
      }

      final success = sentCount > 0;
      final message = success
          ? '$sentCount de ${pendingLogs.length} logs enviados${failedCount > 0 ? ' ($failedCount fallaron)' : ''}'
          : 'No se pudieron enviar logs';

      return SendResult(
        success: success,
        tableName: group.tableName,
        itemsSent: sentCount,
        message: message,
        error: failedCount > 0 ? '$failedCount logs fallaron' : null,
      );

    } catch (e) {
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío de logs',
        error: e.toString(),
      );
    }
  }
}
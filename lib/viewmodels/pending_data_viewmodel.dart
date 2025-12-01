// lib/viewmodels/pending_data_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/sync_service.dart';
import 'package:ada_app/services/sync/sync_tables_config.dart';
import 'package:logger/logger.dart';
import 'dart:async';

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
  logs,
  operations, // 👈 Nuevo tipo para operaciones comerciales
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
    this.autoSyncInterval = const Duration(minutes: 1),
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

  // Auto-sincronización
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

  // Getters de auto-sync
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

  // ========== MÉTODOS DE SINCRONIZACIÓN AUTOMÁTICA ==========

  /// Inicia la sincronización automática periódica
  void iniciarSincronizacionAutomatica() {
    if (_autoSyncEnabled) {
      _logger.i('⚠️ Sincronización automática ya está activa');
      return;
    }

    _autoSyncEnabled = true;
    _logger.i('🚀 Iniciando sincronización automática cada ${_config.autoSyncInterval.inMinutes} minutos');

    // Primera sincronización después de 2 minutos
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

  /// Toggle para activar/desactivar auto-sync
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
    if (_isSending) {
      _logger.i('⏭️ Auto-sync saltado: envío manual en progreso');
      return;
    }

    final connected = await _checkConnectivity();
    if (!connected) {
      _logger.i('⏭️ Auto-sync saltado: sin conexión');
      return;
    }

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

  /// Ejecuta el envío automático silencioso
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

      await loadPendingData();

      if (totalSent > 0) {
        final successCount = results.where((r) => r.success).length;
        _eventController.add(ShowSuccessEvent(
          '🔄 Auto-sync: $totalSent elementos enviados ($successCount/${results.length} categorías)',
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

      // 🔥 USAR EL CONFIGURADOR CENTRALIZADO
      final counts = await SyncTablesConfig.getPendingCounts();
      final configs = SyncTablesConfig.getAllTableConfigs();

      final grupos = <PendingDataGroup>[];

      for (final config in configs) {
        final count = counts[config.tableName] ?? 0;

        if (count > 0) {
          grupos.add(PendingDataGroup(
            tableName: config.tableName,
            displayName: config.displayName,
            count: count,
            type: _getDataType(config.tableName),
            description: config.description,
          ));

          _logger.i('📋 ${config.displayName}: $count pendientes');
        }
      }

      // Ordenar por tipo y nombre
      grupos.sort((a, b) {
        final typeCompare = a.type.index.compareTo(b.type.index);
        if (typeCompare != 0) return typeCompare;
        return a.displayName.compareTo(b.displayName);
      });

      _pendingGroups = grupos;
      _totalPendingItems = grupos.fold(0, (sum, group) => sum + group.count);
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
      final connected = await _checkConnectivity();
      if (!connected) {
        _eventController.add(ShowErrorEvent(
          'Sin conexión al servidor. Verifique su conexión a Internet.',
        ));
        return;
      }

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

      final connected = await _checkConnectivity();
      if (!connected) {
        _eventController.add(ShowErrorEvent(
          'Conexión perdida. No se puede proceder con el envío.',
        ));
        return;
      }

      final results = <SendResult>[];
      int totalSent = 0;

      _sendTotalCount = _pendingGroups.length;
      _sendCompletedCount = 0;

      for (int i = 0; i < _pendingGroups.length; i++) {
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

        await Future.delayed(const Duration(milliseconds: 100));
      }

      _updateSendProgress(
        progress: 1.0,
        currentStep: 'Envío completado',
        completedCount: _pendingGroups.length,
      );

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

  /// Obtiene la lista de censos fallidos (con error de sincronización)
  Future<List<Map<String, dynamic>>> getCensosFallidos() async {
    try {
      _logger.i('🔍 Obteniendo censos fallidos...');

      final db = await _dbHelper.database;

      final censos = await db.rawQuery('''
        SELECT 
          ca.*,
          eq.cod_barras,
          eq.numero_serie,
          c.nombre as cliente_nombre,
          m.nombre as marca_nombre,
          mo.nombre as modelo_nombre
        FROM censo_activo ca
        LEFT JOIN equipos eq ON ca.equipo_id = eq.id
        LEFT JOIN clientes c ON ca.cliente_id = c.id
        LEFT JOIN marcas m ON eq.marca_id = m.id
        LEFT JOIN modelos mo ON eq.modelo_id = mo.id
        WHERE ca.estado_censo = 'error'
        ORDER BY ca.fecha_creacion DESC
      ''');

      _logger.i('✅ Censos fallidos obtenidos: ${censos.length}');
      return censos;

    } catch (e) {
      _logger.e('❌ Error obteniendo censos fallidos: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOperacionesFallidas() async {
    try {
      _logger.i('🔍 Obteniendo operaciones fallidas...');

      final db = await _dbHelper.database;

      final operaciones = await db.rawQuery('''
      SELECT 
        oc.*,
        c.nombre as cliente_nombre,
        c.telefono as cliente_telefono
      FROM operacion_comercial oc
      LEFT JOIN clientes c ON oc.cliente_id = c.id
      WHERE oc.sync_status = 'error'
      ORDER BY oc.fecha_creacion DESC
    ''');

      _logger.i('✅ Operaciones fallidas obtenidas: ${operaciones.length}');
      return operaciones;

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones fallidas: $e');
      rethrow;
    }
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
          Future.delayed(_config.timeout).then(
                (_) => throw TimeoutException('Timeout', _config.timeout),
          ),
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

  /// Envía un grupo específico de datos usando la configuración centralizada
  Future<SendResult> _sendDataGroup(PendingDataGroup group) async {
    try {
      _logger.i('📤 Enviando ${group.displayName} (${group.count} elementos)...');

      final db = await _dbHelper.database;

      // 🔥 BUSCAR LA CONFIGURACIÓN DE LA TABLA
      final config = SyncTablesConfig.getAllTableConfigs().firstWhere(
            (c) => c.tableName == group.tableName,
        orElse: () => throw Exception('Configuración no encontrada para ${group.tableName}'),
      );

      // Obtener items pendientes usando la configuración
      final items = await db.query(
        config.tableName,
        where: config.whereClause,
        whereArgs: config.whereArgs,
        orderBy: 'fecha_creacion ASC',
      );

      if (items.isEmpty) {
        return SendResult(
          success: true,
          tableName: group.tableName,
          itemsSent: 0,
          message: 'No hay elementos pendientes',
        );
      }

      // 🔥 EJECUTAR LA FUNCIÓN DE SINCRONIZACIÓN DESDE EL CONFIG
      final result = await config.syncFunction(items);

      return SendResult(
        success: result.success,
        tableName: group.tableName,
        itemsSent: result.itemsSent,
        message: result.message,
        error: result.error,
      );
    } catch (e) {
      _logger.e('❌ Error enviando ${group.tableName}: $e');
      return SendResult(
        success: false,
        tableName: group.tableName,
        itemsSent: 0,
        message: 'Error en envío',
        error: e.toString(),
      );
    }
  }

  /// Obtiene el tipo de dato según el nombre de la tabla
  PendingDataType _getDataType(String tableName) {
    switch (tableName) {
      case 'dynamic_form_response':
      case 'dynamic_form_response_detail':
      case 'dynamic_form_response_image':
        return PendingDataType.forms;
      case 'censo_activo':
      case 'censo_activo_foto':
        return PendingDataType.census;
      case 'operacion_comercial':
      case 'operacion_comercial_detalle':
        return PendingDataType.operations;
      case 'device_log':
        return PendingDataType.logs;
      default:
        return PendingDataType.forms;
    }
  }
}
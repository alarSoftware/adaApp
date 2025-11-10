import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/services/database_validation_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/sync_service.dart';
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

// ========== VIEWMODEL ==========
class PendingDataViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ========== ESTADO INTERNO ==========
  bool _isLoading = false;
  bool _isSending = false;
  List<PendingDataGroup> _pendingGroups = [];
  int _totalPendingItems = 0;
  String _lastUpdateTime = '';

  // Estado de envío
  double _sendProgress = 0.0;
  String _sendCurrentStep = '';
  int _sendCompletedCount = 0;
  int _sendTotalCount = 0;

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

  // Getters de progreso de envío
  double get sendProgress => _sendProgress;
  String get sendCurrentStep => _sendCurrentStep;
  int get sendCompletedCount => _sendCompletedCount;
  int get sendTotalCount => _sendTotalCount;

  // ========== CONSTRUCTOR ==========
  PendingDataViewModel() {
    loadPendingData();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
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

  /// Solicita confirmación para envío masivo
  Future<void> requestBulkSend() async {
    if (_isSending || _pendingGroups.isEmpty) return;

    try {
      // Verificar conexión
      final conexion = await SyncService.probarConexion();
      if (!conexion.exito) {
        _eventController.add(ShowErrorEvent('Sin conexión al servidor: ${conexion.mensaje}'));
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

    try {
      _logger.i('🚀 Iniciando envío masivo de datos pendientes...');

      final results = <SendResult>[];
      int totalSent = 0;

      // Configurar progreso
      _sendTotalCount = _pendingGroups.length;
      _sendCompletedCount = 0;

      for (int i = 0; i < _pendingGroups.length; i++) {
        final group = _pendingGroups[i];

        _updateSendProgress(
          progress: (i / _pendingGroups.length),
          currentStep: 'Enviando ${group.displayName}...',
          completedCount: i,
        );

        try {
          final result = await _sendDataGroup(group);
          results.add(result);

          if (result.success) {
            totalSent += result.itemsSent;
          }

        } catch (e) {
          _logger.e('❌ Error enviando ${group.displayName}: $e');
          results.add(SendResult(
            success: false,
            tableName: group.tableName,
            itemsSent: 0,
            message: 'Error en envío',
            error: e.toString(),
          ));
        }
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

      _logger.i('✅ Envío masivo completado: $summary');

    } catch (e) {
      _logger.e('💥 Error en envío masivo: $e');
      _eventController.add(ShowErrorEvent('Error en envío masivo: $e'));
    } finally {
      _setSending(false);
      _resetSendProgress();
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
        return 'Equipos registrados localmente';
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

      // TODO: Implementar el envío específico para cada tipo de dato
      // Por ahora simularemos el envío exitoso

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

  // Métodos específicos de envío (placeholder por ahora)
  Future<SendResult> _sendForms(PendingDataGroup group) async {
    // TODO: Implementar envío de formularios
    await Future.delayed(Duration(seconds: 1)); // Simular envío

    return SendResult(
      success: true,
      tableName: group.tableName,
      itemsSent: group.count,
      message: 'Formularios enviados correctamente',
    );
  }

  Future<SendResult> _sendCensus(PendingDataGroup group) async {
    // TODO: Implementar envío de censos
    await Future.delayed(Duration(seconds: 2)); // Simular envío

    return SendResult(
      success: true,
      tableName: group.tableName,
      itemsSent: group.count,
      message: 'Censos enviados correctamente',
    );
  }

  Future<SendResult> _sendEquipment(PendingDataGroup group) async {
    // TODO: Implementar envío de equipos
    await Future.delayed(Duration(seconds: 1)); // Simular envío

    return SendResult(
      success: true,
      tableName: group.tableName,
      itemsSent: group.count,
      message: 'Equipos enviados correctamente',
    );
  }

  Future<SendResult> _sendImages(PendingDataGroup group) async {
    // TODO: Implementar envío de imágenes
    await Future.delayed(Duration(seconds: 3)); // Simular envío más lento

    return SendResult(
      success: true,
      tableName: group.tableName,
      itemsSent: group.count,
      message: 'Imágenes enviadas correctamente',
    );
  }

  Future<SendResult> _sendLogs(PendingDataGroup group) async {
    // TODO: Implementar envío de logs
    await Future.delayed(Duration(milliseconds: 500)); // Simular envío rápido

    return SendResult(
      success: true,
      tableName: group.tableName,
      itemsSent: group.count,
      message: 'Logs enviados correctamente',
    );
  }
}
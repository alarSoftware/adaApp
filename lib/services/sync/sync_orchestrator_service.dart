import 'package:flutter/foundation.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/data/database_validation_service.dart';
import 'package:sqflite/sqflite.dart';

class SyncOrchestratorService {
  /// Sincronizar todos los datos con progreso
  static Future<SyncResult> executeFullSync({
    required String employeeId,
    required String displayName,
    String? previousVendedorId,
    required Function({
      required double progress,
      required String currentStep,
      required List<String> completedSteps,
    })
    onProgress,
  }) async {
    return await FullSyncService.syncAllDataWithProgress(
      employeeId: employeeId,
      edfVendedorNombre: displayName,
      previousVendedorId: previousVendedorId,
      onProgress: onProgress,
    );
  }

  /// Subir todos los datos locales que están pendientes de envío
  static Future<DatabaseValidationResult> uploadAllPendingData({
    required int userId,
    required Database database,
  }) async {
    // 1. Intentar subir censos
    try {
      final censoService = CensoUploadService();
      await censoService.sincronizarCensosNoMigrados(userId);
    } catch (e) {
      debugPrint('Error subiendo censos: $e');
    }

    // 2. Intentar subir formularios
    try {
      final formService = DynamicFormUploadService();
      await formService.sincronizarRespuestasPendientes(userId.toString());
    } catch (e) {
      debugPrint('Error subiendo formularios: $e');
    }

    // 3. Intentar subir logs
    try {
      await DeviceLogUploadService.sincronizarDeviceLogsPendientes();
    } catch (e) {
      debugPrint('Error subiendo logs: $e');
    }

    // 4. Re-verificar estado
    final validationService = DatabaseValidationService(database);
    return await validationService.canDeleteDatabase();
  }
}

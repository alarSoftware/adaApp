import 'package:flutter/material.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/sync/sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

/// Callback para reportar progreso de sincronización
typedef SyncProgressCallback =
    void Function({
      required double progress,
      required String currentStep,
      required List<String> completedSteps,
    });

/// Servicio centralizado para sincronización completa
class FullSyncService {
  /// Sincronizar todos los datos con reporte de progreso
  static Future<SyncResult> syncAllDataWithProgress({
    required String edfVendedorId,
    String? edfVendedorNombre,
    String? previousVendedorId,
    bool forceClear = false,
    required SyncProgressCallback onProgress,
  }) async {
    final completedSteps = <String>[];
    int totalItemsSincronizados = 0;

    try {
      // =================================================================
      // 1. Limpiar datos anteriores si es necesario
      // =================================================================
      if (forceClear ||
          (previousVendedorId != null && previousVendedorId != edfVendedorId)) {
        try {
          onProgress(
            progress: 0.05,
            currentStep: 'Limpiando datos anteriores...',
            completedSteps: completedSteps,
          );

          final authService = AuthService();
          await authService.clearSyncData();

          completedSteps.add('Datos anteriores limpiados');
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          throw Exception('Error limpiando datos anteriores: $e');
        }
      }

      // =================================================================
      // 2. Sincronizar usuarios
      // =================================================================
      try {
        onProgress(
          progress: 0.1,
          currentStep: 'Sincronizando usuarios...',
          completedSteps: completedSteps,
        );

        final userSyncResult = await AuthService.sincronizarSoloUsuarios();
        if (!userSyncResult.exito) {
          throw Exception(userSyncResult.mensaje);
        }

        completedSteps.add('${userSyncResult.itemsSincronizados} usuarios');
        totalItemsSincronizados += userSyncResult.itemsSincronizados;

        onProgress(
          progress: 0.15,
          currentStep: 'Usuarios sincronizados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        throw Exception('Error sincronizando usuarios: $e');
      }

      // =================================================================
      // 3. Sincronizar todos los datos (usa SyncResultUnificado dinámicamente)
      // =================================================================
      try {
        onProgress(
          progress: 0.2,
          currentStep: 'Descargando datos...',
          completedSteps: completedSteps,
        );

        final syncResult = await SyncService.sincronizarTodosLosDatos();

        if (!syncResult.exito) {
          throw Exception(syncResult.mensaje);
        }

        // ✅ Suma dinámica usando el getter
        totalItemsSincronizados += syncResult.totalItemsSincronizados;

        // ✅ Reporte dinámico de progreso
        double currentProgress = 0.25;
        final steps = syncResult.syncSteps;

        // Calcular el incremento de progreso por paso
        // Del 0.25 al 0.80 hay 0.55 de espacio para los pasos de datos
        final progressStep = steps.isEmpty ? 0 : 0.55 / steps.length;

        for (var step in steps) {
          completedSteps.add(step.summary);
          currentProgress += progressStep;
          onProgress(
            progress: currentProgress,
            currentStep: step.description,
            completedSteps: completedSteps,
          );
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Asegurar que llegamos al 0.80 después de todos los pasos
        if (currentProgress < 0.80) {
          currentProgress = 0.80;
        }
      } catch (e) {
        throw Exception('Error en descarga masiva: $e');
      }

      // =================================================================
      // 4. Sincronizar respuestas de formularios
      // =================================================================
      try {
        onProgress(
          progress: 0.80,
          currentStep: 'Descargando respuestas de formularios...',
          completedSteps: completedSteps,
        );

        final responsesResult =
            await AuthService.sincronizarRespuestasDelVendedor(edfVendedorId);

        if (responsesResult.exito) {
          if (responsesResult.itemsSincronizados > 0) {
            completedSteps.add(
              '${responsesResult.itemsSincronizados} respuestas',
            );
            totalItemsSincronizados += responsesResult.itemsSincronizados;
          }
          onProgress(
            progress: 0.90,
            currentStep: 'Respuestas descargadas',
            completedSteps: completedSteps,
          );
        } else {
          throw Exception(
            'Error sincronizando respuestas: ${responsesResult.mensaje}',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Excepción al descargar respuestas: $e');
        throw Exception('Error crítico descargando respuestas: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // =================================================================
      // 5. Marcar sincronización como completada
      // =================================================================
      try {
        onProgress(
          progress: 0.95,
          currentStep: 'Finalizando...',
          completedSteps: completedSteps,
        );

        final authService = AuthService();
        await authService.markSyncCompleted(
          edfVendedorId,
          edfVendedorNombre ?? 'Vendedor',
        );

        completedSteps.add('Sincronización registrada');
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        await ErrorLogService.logDatabaseError(
          tableName: 'N/A',
          operation: 'mark_sync_completed',
          errorMessage: 'Error finalizando sync: $e',
          registroFailId: edfVendedorId,
        );
        throw Exception('Error finalizando sync: $e');
      }

      // =================================================================
      // 6. Completado
      // =================================================================
      onProgress(
        progress: 1.0,
        currentStep: '¡Completado!',
        completedSteps: completedSteps,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      return SyncResult(
        exito: true,
        mensaje: 'Sincronización completada exitosamente',
        itemsSincronizados: totalItemsSincronizados,
      );
    } catch (e) {
      debugPrint('❌ Error en sincronización completa: $e');

      return SyncResult(
        exito: false,
        mensaje: 'Error en sincronización: $e',
        itemsSincronizados: 0,
      );
    }
  }
}

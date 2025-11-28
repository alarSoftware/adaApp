import 'package:flutter/material.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

/// Callback para reportar progreso de sincronización
typedef SyncProgressCallback = void Function({
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
    // ✅ VARIABLE EXTERNA PARA ACUMULAR EL TOTAL Y EVITAR EL ERROR 'Undefined name'
    int totalItemsSincronizados = 0;

    try {
      if (forceClear || (previousVendedorId != null && previousVendedorId != edfVendedorId)) {
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
          // await ErrorLogService.logError(
          //   tableName: 'N/A',
          //   operation: 'clear_sync_data',
          //   errorMessage: 'Error limpiando datos anteriores: $e',
          //   errorType: 'database',
          //   userId: edfVendedorNombre ?? edfVendedorId,
          // );
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

        // ➕ Sumamos al total general
        totalItemsSincronizados += userSyncResult.itemsSincronizados;

        onProgress(
          progress: 0.15,
          currentStep: 'Usuarios sincronizados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // await ErrorLogService.logServerError(
        //   tableName: 'Users',
        //   operation: 'sync_users',
        //   errorMessage: 'Error sincronizando usuarios: $e',
        //   errorCode: 'SYNC_ERROR',
        //   userId: edfVendedorNombre ?? edfVendedorId,
        // );
        throw Exception('Error sincronizando usuarios: $e');
      }

      // =================================================================
      // 3. Sincronizar todos los datos (Clientes, Equipos, etc.)
      // =================================================================
      try {
        onProgress(
          progress: 0.2,
          currentStep: 'Descargando datos...',
          completedSteps: completedSteps,
        );

        // ✅ Aquí definimos 'syncResult' localmente, pero sumamos sus valores a la variable externa
        final syncResult = await SyncService.sincronizarTodosLosDatos();

        if (!syncResult.exito) {
          throw Exception(syncResult.mensaje);
        }

        // ➕ Sumamos todos los datos al total general
        totalItemsSincronizados += syncResult.clientesSincronizados +
            syncResult.equiposSincronizados +
            syncResult.censosSincronizados +
            syncResult.imagenesCensosSincronizadas;

        // --- Reporte de progreso ---
        double currentProgress = 0.25;

        if (syncResult.clientesSincronizados > 0) {
          completedSteps.add('${syncResult.clientesSincronizados} clientes');
          currentProgress = 0.32;
          onProgress(progress: currentProgress, currentStep: 'Clientes descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (syncResult.equiposSincronizados > 0) {
          completedSteps.add('${syncResult.equiposSincronizados} equipos');
          currentProgress = 0.40;
          onProgress(progress: currentProgress, currentStep: 'Equipos descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (syncResult.censosSincronizados > 0) {
          completedSteps.add('${syncResult.censosSincronizados} censos');
          currentProgress = 0.50;
          onProgress(progress: currentProgress, currentStep: 'Censos descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (syncResult.imagenesCensosSincronizadas > 0) {
          completedSteps.add('${syncResult.imagenesCensosSincronizadas} imágenes de censos');
          currentProgress = 0.55;
          onProgress(progress: currentProgress, currentStep: 'Imágenes de censos descargadas', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        } else if (syncResult.censosSincronizados > 0) {
          completedSteps.add('Imágenes: no disponibles');
          currentProgress = 0.55;
          onProgress(progress: currentProgress, currentStep: 'Imágenes: no disponibles', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (syncResult.equiposPendientesSincronizados > 0) {
          completedSteps.add('${syncResult.equiposPendientesSincronizados} equipos pendientes');
          currentProgress = 0.62;
          onProgress(progress: currentProgress, currentStep: 'Equipos pendientes descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (syncResult.formulariosSincronizados > 0) {
          completedSteps.add('${syncResult.formulariosSincronizados} formularios');
          currentProgress = 0.70;
          onProgress(progress: currentProgress, currentStep: 'Formularios descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (syncResult.detallesFormulariosSincronizados > 0) {
          completedSteps.add('${syncResult.detallesFormulariosSincronizados} detalles');
          currentProgress = 0.80;
          onProgress(progress: currentProgress, currentStep: 'Detalles de formularios descargados', completedSteps: completedSteps);
          await Future.delayed(const Duration(milliseconds: 200));
        }

      } catch (e) {
        // await ErrorLogService.logServerError(
        //   tableName: 'ALL_DATA',
        //   operation: 'full_sync',
        //   errorMessage: 'Error en descarga masiva: $e',
        //   errorCode: 'SYNC_ERROR',
        //   userId: edfVendedorNombre ?? edfVendedorId,
        // );
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

        final responsesResult = await AuthService.sincronizarRespuestasDelVendedor(edfVendedorId);

        if (responsesResult.exito) {
          if (responsesResult.itemsSincronizados > 0) {
            completedSteps.add('${responsesResult.itemsSincronizados} respuestas');
            // ➕ Sumamos al total general
            totalItemsSincronizados += responsesResult.itemsSincronizados;
          }
          onProgress(
            progress: 0.90,
            currentStep: 'Respuestas descargadas',
            completedSteps: completedSteps,
          );
        } else {
          // ⛔ MODO ESTRICTO: Si falla, lanzamos excepción
          throw Exception('Error sincronizando respuestas: ${responsesResult.mensaje}');
        }
      } catch (e) {
        debugPrint('⚠️ Excepción al descargar respuestas: $e');

        // await ErrorLogService.logServerError(
        //   tableName: 'FormRespuestas',
        //   operation: 'sync_responses',
        //   errorMessage: 'Error crítico respuestas: $e',
        //   errorCode: 'SYNC_RESP_ERROR',
        //   userId: edfVendedorNombre ?? edfVendedorId,
        // );

        // ⛔ MODO ESTRICTO: Cancelamos todo
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
            edfVendedorNombre ?? 'Vendedor'
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

      // ✅ AQUÍ USAMOS LA VARIABLE EXTERNA (ya no hay error)
      return SyncResult(
        exito: true,
        mensaje: 'Sincronización completada exitosamente',
        itemsSincronizados: totalItemsSincronizados,
      );

    } catch (e) {
      debugPrint('❌ Error en sincronización completa: $e');

      // Log final general por si acaso
      // await ErrorLogService.logError(
      //   tableName: 'FULL_PROCESS',
      //   operation: 'sync_all_data',
      //   errorMessage: 'Fallo crítico en proceso completo: $e',
      //   errorType: 'critical',
      //   userId: edfVendedorNombre ?? edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: 'Error en sincronización: $e',
        itemsSincronizados: 0,
      );
    }
  }
}
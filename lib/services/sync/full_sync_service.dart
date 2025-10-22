import 'package:flutter/material.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';

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
    String? previousVendedorId,
    required SyncProgressCallback onProgress,
  }) async {
    final completedSteps = <String>[];

    try {
      // 1. Limpiar datos anteriores si es cambio de vendedor (0% -> 5%)
      if (previousVendedorId != null && previousVendedorId != edfVendedorId) {
        onProgress(
          progress: 0.05,
          currentStep: 'Limpiando datos anteriores...',
          completedSteps: completedSteps,
        );

        final authService = AuthService();
        await authService.clearSyncData();

        completedSteps.add('Datos anteriores limpiados');
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 2. Sincronizar usuarios (5% -> 15%)
      onProgress(
        progress: 0.1,
        currentStep: 'Sincronizando usuarios...',
        completedSteps: completedSteps,
      );

      final userSyncResult = await AuthService.sincronizarSoloUsuarios();
      if (!userSyncResult.exito) {
        throw Exception('Error sincronizando usuarios: ${userSyncResult.mensaje}');
      }

      completedSteps.add('${userSyncResult.itemsSincronizados} usuarios');
      onProgress(
        progress: 0.15,
        currentStep: 'Usuarios sincronizados',
        completedSteps: completedSteps,
      );
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. Sincronizar todos los datos (15% -> 82%)
      onProgress(
        progress: 0.2,
        currentStep: 'Descargando datos...',
        completedSteps: completedSteps,
      );

      final syncResult = await SyncService.sincronizarTodosLosDatos();

      if (!syncResult.exito) {
        throw Exception('Error en sincronización: ${syncResult.mensaje}');
      }

      // Reportar progreso por cada tipo de dato
      double currentProgress = 0.25;

      // Clientes (25% -> 35%)
      if (syncResult.clientesSincronizados > 0) {
        completedSteps.add('${syncResult.clientesSincronizados} clientes');
        currentProgress = 0.35;
        onProgress(
          progress: currentProgress,
          currentStep: 'Clientes descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Equipos (35% -> 45%)
      if (syncResult.equiposSincronizados > 0) {
        completedSteps.add('${syncResult.equiposSincronizados} equipos');
        currentProgress = 0.45;
        onProgress(
          progress: currentProgress,
          currentStep: 'Equipos descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Censos (45% -> 55%)
      if (syncResult.censosSincronizados > 0) {
        completedSteps.add('${syncResult.censosSincronizados} censos');
        currentProgress = 0.55;
        onProgress(
          progress: currentProgress,
          currentStep: 'Censos descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Equipos Pendientes (55% -> 65%)
      if (syncResult.equiposPendientesSincronizados > 0) {
        completedSteps.add('${syncResult.equiposPendientesSincronizados} equipos pendientes');
        currentProgress = 0.65;
        onProgress(
          progress: currentProgress,
          currentStep: 'Equipos pendientes descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Formularios (65% -> 75%)
      if (syncResult.formulariosSincronizados > 0) {
        completedSteps.add('${syncResult.formulariosSincronizados} formularios');
        currentProgress = 0.75;
        onProgress(
          progress: currentProgress,
          currentStep: 'Formularios descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Detalles de formularios (75% -> 82%)
      if (syncResult.detallesFormulariosSincronizados > 0) {
        completedSteps.add('${syncResult.detallesFormulariosSincronizados} detalles');
        currentProgress = 0.82;
        onProgress(
          progress: currentProgress,
          currentStep: 'Detalles de formularios descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 4. Sincronizar respuestas de formularios (82% -> 90%)
      onProgress(
        progress: 0.82,
        currentStep: 'Descargando respuestas de formularios...',
        completedSteps: completedSteps,
      );

      try {
        final responsesResult = await AuthService.sincronizarRespuestasDelVendedor(edfVendedorId);

        if (responsesResult.exito && responsesResult.itemsSincronizados > 0) {
          completedSteps.add('${responsesResult.itemsSincronizados} respuestas');
          onProgress(
            progress: 0.9,
            currentStep: 'Respuestas descargadas',
            completedSteps: completedSteps,
          );
        } else if (!responsesResult.exito) {
          debugPrint('⚠️ Error descargando respuestas: ${responsesResult.mensaje}');
          completedSteps.add('Respuestas: error (continuando)');
          onProgress(
            progress: 0.9,
            currentStep: 'Respuestas: error (continuando)',
            completedSteps: completedSteps,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Excepción al descargar respuestas: $e');
        completedSteps.add('Respuestas: error (continuando)');
        onProgress(
          progress: 0.9,
          currentStep: 'Respuestas: error (continuando)',
          completedSteps: completedSteps,
        );
      }
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. Marcar sincronización como completada (90% -> 95%)
      onProgress(
        progress: 0.95,
        currentStep: 'Finalizando...',
        completedSteps: completedSteps,
      );

      final authService = AuthService();
      await authService.markSyncCompleted(edfVendedorId);

      completedSteps.add('Sincronización registrada');
      await Future.delayed(const Duration(milliseconds: 300));

      // 6. Completado (100%)
      onProgress(
        progress: 1.0,
        currentStep: '¡Completado!',
        completedSteps: completedSteps,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      return SyncResult(
        exito: true,
        mensaje: 'Sincronización completada exitosamente',
        itemsSincronizados: syncResult.clientesSincronizados +
            syncResult.equiposSincronizados +
            syncResult.censosSincronizados,
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
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

      // 3. Sincronizar todos los datos (15% -> 80%)
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

      // Clientes (25% -> 32%)
      if (syncResult.clientesSincronizados > 0) {
        completedSteps.add('${syncResult.clientesSincronizados} clientes');
        currentProgress = 0.32;
        onProgress(
          progress: currentProgress,
          currentStep: 'Clientes descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Equipos (32% -> 40%)
      if (syncResult.equiposSincronizados > 0) {
        completedSteps.add('${syncResult.equiposSincronizados} equipos');
        currentProgress = 0.40;
        onProgress(
          progress: currentProgress,
          currentStep: 'Equipos descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Censos (40% -> 50%)
      if (syncResult.censosSincronizados > 0) {
        completedSteps.add('${syncResult.censosSincronizados} censos');
        currentProgress = 0.50;
        onProgress(
          progress: currentProgress,
          currentStep: 'Censos descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 🆕 Imágenes de censos (50% -> 55%) - SOLO SI HAY IMÁGENES
      if (syncResult.imagenesCensosSincronizadas > 0) {
        completedSteps.add('${syncResult.imagenesCensosSincronizadas} imágenes de censos');
        currentProgress = 0.55;
        onProgress(
          progress: currentProgress,
          currentStep: 'Imágenes de censos descargadas',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      } else if (syncResult.censosSincronizados > 0) {
        // Si hay censos pero no imágenes, mostrar mensaje informativo
        completedSteps.add('Imágenes: no disponibles');
        currentProgress = 0.55;
        onProgress(
          progress: currentProgress,
          currentStep: 'Imágenes: no disponibles',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Equipos Pendientes (55% -> 62%)
      if (syncResult.equiposPendientesSincronizados > 0) {
        completedSteps.add('${syncResult.equiposPendientesSincronizados} equipos pendientes');
        currentProgress = 0.62;
        onProgress(
          progress: currentProgress,
          currentStep: 'Equipos pendientes descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Formularios (62% -> 70%)
      if (syncResult.formulariosSincronizados > 0) {
        completedSteps.add('${syncResult.formulariosSincronizados} formularios');
        currentProgress = 0.70;
        onProgress(
          progress: currentProgress,
          currentStep: 'Formularios descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Detalles de formularios (70% -> 80%)
      if (syncResult.detallesFormulariosSincronizados > 0) {
        completedSteps.add('${syncResult.detallesFormulariosSincronizados} detalles');
        currentProgress = 0.80;
        onProgress(
          progress: currentProgress,
          currentStep: 'Detalles de formularios descargados',
          completedSteps: completedSteps,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 4. Sincronizar respuestas de formularios (80% -> 90%)
      onProgress(
        progress: 0.80,
        currentStep: 'Descargando respuestas de formularios...',
        completedSteps: completedSteps,
      );

      try {
        final responsesResult = await AuthService.sincronizarRespuestasDelVendedor(edfVendedorId);

        if (responsesResult.exito && responsesResult.itemsSincronizados > 0) {
          completedSteps.add('${responsesResult.itemsSincronizados} respuestas');
          onProgress(
            progress: 0.90,
            currentStep: 'Respuestas descargadas',
            completedSteps: completedSteps,
          );
        } else if (!responsesResult.exito) {
          debugPrint('⚠️ Error descargando respuestas: ${responsesResult.mensaje}');
          completedSteps.add('Respuestas: error (continuando)');
          onProgress(
            progress: 0.90,
            currentStep: 'Respuestas: error (continuando)',
            completedSteps: completedSteps,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Excepción al descargar respuestas: $e');
        completedSteps.add('Respuestas: error (continuando)');
        onProgress(
          progress: 0.90,
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
            syncResult.censosSincronizados +
            syncResult.imagenesCensosSincronizadas, // 🆕 Incluir imágenes si las hay
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
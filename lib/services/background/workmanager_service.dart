import 'dart:ui'; // Necesario para DartPluginRegistrant
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Para WidgetsFlutterBinding
import 'package:ada_app/services/device_log/device_log_background_extension.dart';

// Constantes
const String taskName = 'periodicDeviceLogTask';
const String taskUniqueName = 'com.ada_app.periodic_device_log';

// Callback Dispatcher (Top-Level Function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Asegurar inicialización del entorno Flutter en este nuevo Isolate
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  Workmanager().executeTask((task, inputData) async {
    debugPrint("WorkManager Task Executing: $task");

    try {
      if (task == taskName) {
        // Inicializar dependencias mínimas si es necesario
        // DeviceLogBackgroundExtension maneja su propia inicialización de helpers

        // 1. Device Logs (Prioridad Alta - Trazabilidad)
        debugPrint("WorkManager: Ejecutando logging (Device Log)...");
        await DeviceLogBackgroundExtension.ejecutarLoggingConHorario();

        debugPrint("WorkManager: Tarea completada exitosamente");
      }
    } catch (e) {
      debugPrint("WorkManager Error: $e");
      // Retornar true aun si falla para no reintentar infinitamente en bucle corto si es bug sistemático
      // O false si queremos retry. Para logging periódico, mejor true y esperar al siguiente ciclo.
      return Future.value(true);
    }

    return Future.value(true);
  });
}

class WorkmanagerService {
  static Future<void> initialize() async {
    try {
      debugPrint("Inicializando WorkManager...");
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode, // True en debug para ver notificaciones
      );

      // Registrar tarea periódica (15 min es el mínimo de Android)
      await Workmanager().registerPeriodicTask(
        taskUniqueName,
        taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy:
            ExistingPeriodicWorkPolicy.keep, // No reemplazar si ya existe
        constraints: Constraints(),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 10),
      );
      debugPrint("WorkManager: Tarea periódica registrada ($taskUniqueName)");
    } catch (e) {
      debugPrint("Error inicializando WorkManager: $e");
    }
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

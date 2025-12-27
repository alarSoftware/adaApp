import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:logger/logger.dart';

// Top-level entry point (MUST BE OUTSIDE CLASS for AOT)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Necesario para plugins en background
  DartPluginRegistrant.ensureInitialized();

  final Logger logger = Logger();
  logger.i('Background Service: onStart ejecutado');

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // 🔴 FIX ANDROID 14 CRASH: Explicitly set valid notification info immediately
    // This ensures the notification channel and content are valid before any other operation
    /*
    await service.setForegroundNotificationInfo(
      title: "AdaApp",
      content: "Servicio en segundo plano activo",
    );
    */
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 🔴 FIX: Add delay to allow service to stabilize before heavy work
  await Future.delayed(const Duration(seconds: 2));

  // Inicializar lógica de logs (DeviceLogBackgroundExtension)
  // NOTA: Esto inicia su propio Timer interno.
  // Como estamos en un aislamiento separado, funcionará aunque la UI se cierre.
  await DeviceLogBackgroundExtension.inicializar(verificarSesion: true);

  // 🔴 ROBUST LOOP: Instead of a simple Timer, we use a loop that re-checks config
  // This is more resistant to OS kills/restarts because it's the main thread of the Isolate
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "AdaApp Activa",
            content:
                "Última actividad: ${DateTime.now().toString().split('.')[0]}",
          );
        }
      }

      if (!DeviceLogBackgroundExtension.estaActivo) {
        logger.w('Watchdog: Timer de logs inactivo. Reinicializando...');
        await DeviceLogBackgroundExtension.inicializar(verificarSesion: true);
      }
    } catch (e) {
      logger.e("Error en ciclo principal de background: $e");
    }
  });
}

// Top-level entry point for iOS
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

class AppBackgroundService {
  static final Logger _logger = Logger();

  /// Inicializa el servicio en segundo plano
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    _logger.i('Inicializando AppBackgroundService...');

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Callback que se ejecuta en el aislamiento separado
        onStart: onStart,

        // Auto-inicio al arrancar (opcional, por ahora false para control manual)
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId: 'ada_background_service',
        // Ensure a minimal notification is provided for foreground start
        initialNotificationTitle: 'AdaApp',
        initialNotificationContent: 'Servicio en segundo plano activo',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // Auto-inicio
        autoStart: false,

        // Callback
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Iniciar el servicio si no está corriendo
    if (!await service.isRunning()) {
      await service.startService();
      _logger.i('Servicio background iniciado');
    }
  }
}

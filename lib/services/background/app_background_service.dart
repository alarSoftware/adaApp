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
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Inicializar lógica de logs (DeviceLogBackgroundExtension)
  // NOTA: Esto inicia su propio Timer interno.
  // Como estamos en un aislamiento separado, funcionará aunque la UI se cierre.
  await DeviceLogBackgroundExtension.inicializar(verificarSesion: true);

  // Timer para actualizar la notificación o verificar estado (opcional)
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "AdaApp Activa",
          content:
              "Última sincronización: ${DateTime.now().toString().split('.')[0]}",
        );
      }
    }

    // Heartbeat en el log
    logger.i('Background Service Heartbeat: ${DateTime.now()}');
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
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'ada_background_service',
        initialNotificationTitle: 'AdaApp en segundo plano',
        initialNotificationContent: 'Sincronizando datos y ubicación...',
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

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:logger/logger.dart';

// Top-level entry point (MUST BE OUTSIDE CLASS for AOT)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Necesario para plugins en background
  DartPluginRegistrant.ensureInitialized();

  final Logger logger = Logger();
  logger.i('Background Service: onStart ejecutado');

  // Configuración de Notificación Persistente (Custom)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Inicializar el plugin de notificaciones locales
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'ada_background_service', // id (must match internal config)
    'AdaApp Service', // title
    description: 'Servicio de monitoreo en segundo plano',
    importance: Importance.low, // Low para no molestar con sonido constante
    showBadge: false,
    playSound: false,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

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

  // Listen for config updates
  service.on('updateConfig').listen((event) async {
    logger.i('Recibida señal de actualización de configuración');
    await DeviceLogBackgroundExtension.cargarConfiguracionHorario();
  });

  await Future.delayed(const Duration(seconds: 2));

  // Inicializar lógica de logs
  await DeviceLogBackgroundExtension.inicializar(verificarSesion: true);

  // Watchdog & Notification Update Loop
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // UPDATE NOTIFICATION VIA LOCAL NOTIFICATIONS (Custom & Persistent)
          flutterLocalNotificationsPlugin.show(
            888, // Notification ID (Matches SDK config)
            'AdaApp Activa',
            'Última actividad: ${DateTime.now().toString().split('.')[0]}',
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher', // Icono de la app
                ongoing: true, // 🔒 FIJA (No swipeable en Android <14)
                autoCancel: false,
                onlyAlertOnce: true,
                importance: Importance.low,
                priority: Priority.low,
                showWhen: true,
              ),
            ),
          );
        }
      }

      // Check Watchdog
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
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'ada_background_service',
        initialNotificationTitle: 'AdaApp',
        initialNotificationContent: 'Servicio en segundo plano activo',
        foregroundServiceNotificationId: 888,
        // Match types declared in AndroidManifest.xml
        foregroundServiceTypes: [
          AndroidForegroundType.location,
          AndroidForegroundType.dataSync,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    if (!await service.isRunning()) {
      await service.startService();
      _logger.i('Servicio background iniciado');
    }
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }
}

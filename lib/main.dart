import 'package:flutter/material.dart';

import 'package:ada_app/services/app_services.dart';
import 'package:ada_app/services/api/auth_service.dart';
// import 'package:ada_app/ui/widgets/battery_optimization_dialog.dart';
import 'ui/screens/login/login_screen.dart';
import 'ui/screens/clientes/clients_screen.dart';
import 'ui/screens/menu_principal/select_screen.dart';
import 'ui/screens/menu_principal/equipos_screen.dart';
import 'ui/screens/clientes/cliente_detail_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/screens/api_settings_screen.dart';
import 'models/cliente.dart';
import 'package:ada_app/config/app_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ada_app/ui/widgets/debug_ribbon_wrapper.dart';
import 'package:ada_app/services/background/workmanager_service.dart';
import 'package:ada_app/utils/logger.dart';
//IMPORTS PARA EL RESET TEMPORAL - COMENTADOS PARA PRODUCCIÓN
// import 'package:ada_app/services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // RESET TEMPORAL - COMENTADO PARA PRODUCCIÓN
  // await _resetCompleteApp();

  runApp(const MyApp());
}

//  FUNCIÓN DE RESET TEMPORAL - COMENTADA PARA PRODUCCIÓN
/*
Future<void> _resetCompleteApp() async {

}
*/

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdaApp',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return DebugRibbonWrapper(child: child!);
      },
      home: const InitializationScreen(),
      navigatorObservers: [routeObserver],
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const SelectScreen(),
        '/clienteLista': (context) => const ClienteListScreen(),
        '/equiposLista': (context) => const EquipoListScreen(),
        '/api-settings': (context) => const ApiSettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detalleCliente') {
          final cliente = settings.arguments as Cliente;
          return MaterialPageRoute(
            builder: (context) => ClienteDetailScreen(cliente: cliente),
          );
        }
        return null;
      },
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool _isLoading = true;
  String _loadingMessage = 'Iniciando AdaApp...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Permitir que se dibuje el primer frame para evitar bloqueos (onPreDraw loop)
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      setState(() {
        _loadingMessage = 'Inicializando servicios...';
      });

      // 1. Verificar permisos (bloqueante si faltan)
      await _checkAndRequestPermissions();

      // 2. Iniciar servicios en SEGUNDO PLANO
      _iniciarServiciosBackground();

      // 3. Verificar estado de autenticación
      final authService = AuthService();
      final estaAutenticado = await authService.hasUserLoggedInBefore();

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          estaAutenticado ? '/home' : '/login',
        );
      }
    } catch (e) {
      AppLogger.e('Error al inicializar la aplicación', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Error al inicializar. Toca para reintentar.';
        });

        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error de Inicialización'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Hubo un problema al inicializar la aplicación:\n\n$error'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryInitialization();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Ir a Login'),
            ),
          ],
        );
      },
    );
  }

  void _retryInitialization() {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Reintentando...';
    });
    _initializeApp();
  }

  /// Validar y solicitar permisos críticos AL INICIO (Bloqueante)
  Future<void> _checkAndRequestPermissions() async {
    bool permissionsGranted = false;

    while (!permissionsGranted) {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Verificando permisos necesarios...';
        });
      }

      // 1. Verificar/Solicitar Ubicación
      var locStatus = await Permission.location.status;

      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
      }

      // 2. Verificar Ubicación Background (Solo si tenemos la básica)
      var locAlwaysStatus = await Permission.locationAlways.status;
      if (locStatus.isGranted && !locAlwaysStatus.isGranted) {
        // Intentar pedir background (en Android 11+ esto suele ir a settings o UI sistema)
        locAlwaysStatus = await Permission.locationAlways.request();
        // Re-verificar
        locAlwaysStatus = await Permission.locationAlways.status;
        locAlwaysStatus = await Permission.locationAlways.status;
      }

      // 3. Verificar Notificaciones (Android 13+)
      // Necesario para Foreground Service
      var notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        notifStatus = await Permission.notification.request();
      }

      // Validar ambos permisos estrictamente
      bool isLocationReady = locAlwaysStatus.isGranted || locStatus.isGranted;
      bool isNotificationReady =
          notifStatus.isGranted ||
          // Si el sistema no soporta notificacionesruntime (Android < 13), siempre es granted/restricted pero no negado
          ((await Permission.notification.status).isRestricted);

      // En Android <13, status suele ser granted. En 13+, si es denied, bloqueamos.
      if (notifStatus.isDenied || notifStatus.isPermanentlyDenied) {
        isNotificationReady = false;
      } else {
        isNotificationReady = true;
      }

      if (isLocationReady && isNotificationReady) {
        permissionsGranted = true;
      } else {
        if (mounted) {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Permisos Requeridos'),
              content: Text(
                'Esta aplicación requiere los siguientes permisos para funcionar:\n\n'
                '${!isLocationReady ? "- Ubicación (Permitir siempre)\n" : ""}'
                '${!isNotificationReady ? "- Notificaciones\n" : ""}\n'
                'Por favor, otorgue estos permisos en la configuración para que la app no se cierre en segundo plano.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    openAppSettings();
                  },
                  child: const Text('Ir a Configuración'),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(true); // Reintentar bucle -> .request()
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );

          if (result == false) {
            await Future.delayed(const Duration(seconds: 1));
          }
        } else {
          return;
        }
      }
    }
  }

  /// Inicia los servicios pesados en segundo plano sin bloquear la UI
  void _iniciarServiciosBackground() async {
    try {
      // Inicializar servicios principales
      await AppServices().inicializar();

      // Inicializar WorkManager
      await WorkmanagerService.initialize();
    } catch (e) {
      AppLogger.e('Error en _iniciarServiciosBackground', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.app_registration,
                size: 60,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),

            const Text(
              'AdaApp',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),

            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Icon(Icons.refresh, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _retryInitialization,
                child: Text(
                  _loadingMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 60),

            Text(
              'Versión ${AppConfig.currentAppVersion}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

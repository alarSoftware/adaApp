import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ada_app/services/app_services.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/ui/widgets/battery_optimization_dialog.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/clients_screen.dart';
import 'ui/screens/select_screen.dart';
import 'ui/screens/equipos_screen.dart';
import 'ui/screens/cliente_detail_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/screens/api_settings_screen.dart';
import 'models/cliente.dart';
//IMPORTS PARA EL RESET TEMPORAL - COMENTADOS PARA PRODUCCIÓN
// import 'package:ada_app/services/database_helper.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 ==================== APP INICIADA ====================');
  print('🚀 Timestamp: ${DateTime.now()}');

  // RESET TEMPORAL - COMENTADO PARA PRODUCCIÓN
  // await _resetCompleteApp();

  runApp(const MyApp());
}

//  FUNCIÓN DE RESET TEMPORAL - COMENTADA PARA PRODUCCIÓN
/*
Future<void> _resetCompleteApp() async {
  try {
    print(' === RESET TOTAL DE ADA APP ===');

    //  Usar el método específico del DatabaseHelper
    await DatabaseHelper.resetCompleteDatabase();

    //  Verificar estado después del reset (opcional)
    final estado = await DatabaseHelper.verificarEstadoPostReset();
    print('Estado después del reset: $estado');

    print(' RESET COMPLETO EXITOSO');

  } catch (e) {
    print(' Error durante reset total: $e');
  }
}
*/

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdaApp',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es'),
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
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
    try {
      setState(() {
        _loadingMessage = 'Inicializando servicios...';
      });

      await AppServices().inicializar();
      print('✅ AppServices inicializado correctamente');

      setState(() {
        _loadingMessage = 'Verificando autenticación...';
      });

      final authService = AuthService();
      final estaAutenticado = await authService.hasUserLoggedInBefore();

      print('🔐 ¿Está autenticado? $estaAutenticado');

      if (estaAutenticado) {
        setState(() {
          _loadingMessage = 'Preparando acceso...';
        });

        print('🔐 Sesión activa detectada - NO iniciando servicios automáticamente');
        print('📝 Los servicios se iniciarán después de la primera sincronización');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && estaAutenticado) {
        print('🔋 INICIANDO verificación de batería...');
        print('🔋 Usuario autenticado: $estaAutenticado, mounted: $mounted');

        try {
          setState(() {
            _loadingMessage = 'Verificando optimización de batería...';
          });

          await BatteryOptimizationDialog.checkAndRequestBatteryOptimization(context);
          print('🔋 ✅ COMPLETADO verificación de batería');
        } catch (e, stackTrace) {
          print('🔋 ❌ ERROR en batería: $e');
          print('🔋 ❌ StackTrace: $stackTrace');
        }
      } else {
        print('🔋 ⏭️ SALTANDO verificación de batería. Autenticado: $estaAutenticado, Mounted: $mounted');
      }

      if (mounted) {
        Navigator.pushReplacementNamed(
            context,
            estaAutenticado ? '/home' : '/login'
        );
      }

    } catch (e, stackTrace) {
      print('❌ Error inicializando la aplicación: $e');
      print('❌ Stack trace: $stackTrace');

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
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Icon(
                Icons.refresh,
                size: 48,
                color: Colors.grey[400],
              ),
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
              'Versión 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
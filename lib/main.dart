import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ada_app/services/app_services.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/clients_screen.dart';
import 'ui/screens/select_screen.dart';
import 'ui/screens/equipos_screen.dart';
import 'ui/screens/cliente_detail_screen.dart';
import 'ui/screens/api_settings_screen.dart';
import 'models/cliente.dart';

var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppServices().inicializar();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdaApp',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
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
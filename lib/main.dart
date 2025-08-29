import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/clients_screen.dart';
import 'ui/screens/select_screen.dart';
import 'ui/screens/equipos_screen.dart';
import 'ui/screens/cliente_detail_screen.dart';
import 'models/cliente.dart';  // ✅ AGREGA ESTA IMPORTACIÓN

var logger = Logger();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const SelectScreen(),
        '/clienteLista': (context) => const ClienteListScreen(),
        '/equiposLista': (context) => const EquipoListScreen(),
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
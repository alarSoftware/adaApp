class RouteConstants {
  // Server Routes (nombres que vienen en el JSON)
  static const String serverMenu = '/menu';
  static const String serverClientes = '/clientes';
  static const String serverFormularios = '/formularios';
  static const String serverOperaciones = '/operaciones';
  static const String serverCensos = '/censos';

  // Flutter Routes (nombres definidos en main.dart)
  static const String flutterLogin = '/login';
  static const String flutterHome = '/home'; // Equivale a Menu
  static const String flutterClientes = '/clienteLista';
  static const String flutterEquipos =
      '/equiposLista'; // A veces accesado desde clientes
  static const String flutterDynamicForms =
      '/dynamicForms'; // No definido en main routes map, pero usado

  static const Map<String, String> serverToFlutter = {
    serverMenu: flutterHome,
    serverClientes: flutterClientes,
  };

  // Mapa Reverso Flutter -> Servidor (para saber "donde estoy")
  static const Map<String, String> flutterToServer = {
    flutterHome: serverMenu,
    flutterClientes: serverClientes,
    flutterLogin: '/login',
  };
}

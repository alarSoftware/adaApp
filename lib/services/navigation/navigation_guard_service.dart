import 'package:flutter/foundation.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'route_constants.dart';

class NavigationGuardService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  /// Verifica si el usuario actual puede navegar entre dos pantallas.
  Future<bool> canNavigate({
    required String currentScreen,
    required String targetScreen,
  }) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        debugPrint('NavigationGuard: No user logged in');
        return false;
      }

      // Normalizar rutas a formato Server (e.g., '/menu', '/clientes')
      final from = _normalizeToAppRoute(currentScreen);
      final to = _normalizeToAppRoute(targetScreen);

      // Obtener raw permissions de la DB
      final db = await _dbHelper.database;
      final result = await db.query(
        'app_routes',
        columns: ['route_path', 'module_name'],
        where: 'user_id = ?',
        whereArgs: [user.id],
      );

      // Set de strings "Origen->Destino"
      final allowedTransitions = <String>{};

      for (final row in result) {
        final pathString = row['route_path'] as String? ?? '';

        if (pathString.isEmpty) continue;

        // Separar múltiples reglas ("/menu,/clientes; /clientes,/formularios")
        final rules = pathString.split(';');

        for (final rule in rules) {
          final cleanRule = rule.trim();
          if (cleanRule.isEmpty) continue;

          if (cleanRule.contains(',')) {
            // Regla Explícita: "Origen,Destino"
            final parts = cleanRule.split(',');
            if (parts.length >= 2) {
              final origin = parts[0].trim();
              final dest = parts[1].trim();
              allowedTransitions.add('$origin->$dest');
            }
          } else {
            // Asumimos que si solo dice el destino, es accesible desde el Menú Principal
            // si el módulo está activo.
            allowedTransitions.add('${RouteConstants.serverMenu}->$cleanRule');
          }
        }
      }

      // Validar
      final transitionKey = '$from->$to';
      final isAllowed = allowedTransitions.contains(transitionKey);

      return isAllowed;
    } catch (e) {
      debugPrint('NavigationGuard Error: $e');
      return false; // Fail safe
    }
  }

  /// Convierte rutas de Flutter ('/home') a rutas de Server ('/menu')
  String _normalizeToAppRoute(String route) {
    // Si ya es una ruta conocida de servidor, devolverla
    if (route.startsWith('/')) {
      // Check reverse map first if needed, but simplistic check roughly works
      if (RouteConstants.flutterToServer.containsKey(route)) {
        return RouteConstants.flutterToServer[route]!;
      }
    }
    return route;
  }
}

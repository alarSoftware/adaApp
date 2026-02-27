import 'package:flutter/foundation.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';

class PermissionsService {
  static final _dbHelper = DatabaseHelper();
  static final _authService = AuthService();

  /// Verifica si el usuario actual tiene permiso para un módulo específico
  static Future<bool> hasPermission(String moduleName) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        debugPrint('Verificación de permiso sin usuario logueado');
        return false;
      }

      final db = await _dbHelper.database;
      final result = await db.query(
        'app_routes',
        where: 'user_id = ? AND module_name = ?',
        whereArgs: [user.id, moduleName],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando permiso para $moduleName: $e');
      // En caso de error (ej: tabla no existe?), denegar por seguridad
      // O permitir si es el admin? Mejor denegar por defecto (fail-safe).
      return false;
    }
  }

  /// Verifica múltiples permisos y devuelve un mapa con los resultados
  static Future<Map<String, bool>> checkPermissions(
    List<String> modules,
  ) async {
    final Map<String, bool> results = {};
    for (final module in modules) {
      results[module] = await hasPermission(module);
    }
    return results;
  }

  /// Obtiene todos los módulos habilitados en una sola query desde app_routes.
  /// app_routes se llena desde ConfigEmpre.adaAppJsonPermission (global por empresa).
  /// El campo route_path puede tener múltiples rutas separadas por coma
  /// (ej: "/clientes,/formularios")
  ///
  /// Retorna:
  ///   - null  → app_routes vacío → empresa sin módulos configurados → sync completa
  ///   - Set   → solo sincronizar estos módulos
  static Future<Set<String>?> getAllowedModules() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        debugPrint('getAllowedModules: Sin usuario → sync completa');
        return null;
      }

      final db = await _dbHelper.database;
      final result = await db.query(
        'app_routes',
        columns: ['route_path'],
        where: 'user_id = ?',
        whereArgs: [user.id],
      );

      if (result.isEmpty) {
        debugPrint('getAllowedModules: Sin módulos en app_routes → sync completa');
        return null;
      }

      // route_path puede ser "/clientes,/formularios" → splitear y aplanar
      final modules = result
          .expand((row) {
            final path = row['route_path'] as String? ?? '';
            return path.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty);
          })
          .toSet();

      debugPrint('getAllowedModules: Rutas habilitadas → $modules');
      return modules;
    } catch (e) {
      debugPrint('Error leyendo módulos, sync completa como fallback: $e');
      return null;
    }
  }
}

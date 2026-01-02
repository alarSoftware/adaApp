import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:logger/logger.dart';

class PermissionsService {
  static final _logger = Logger();
  static final _dbHelper = DatabaseHelper();
  static final _authService = AuthService();

  /// Verifica si el usuario actual tiene permiso para un módulo específico
  static Future<bool> hasPermission(String moduleName) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.w('Verificación de permiso sin usuario logueado');
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
      _logger.e('Error verificando permiso para $moduleName: $e');
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
}

import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const String _endpointKey = 'api_base_url';
  static const String defaultBaseUrl = 'http://200.85.60.250:28080/adaControl';

  // Obtener la URL base configurada
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_endpointKey) ?? defaultBaseUrl;
  }

  // Guardar nueva URL base
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endpointKey, url);
    print('URL base actualizada: $url');
  }

  // Obtener URL completa para un endpoint
  static Future<String> getFullUrl(String endpoint) async {
    final base = await getBaseUrl();
    // Asegurarse de que no haya doble slash
    if (endpoint.startsWith('/')) {
      return '$base$endpoint';
    }
    return '$base/$endpoint';
  }
}

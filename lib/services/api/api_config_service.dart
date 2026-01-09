import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const String endpointKey = 'api_base_url';
  static const String defaultBaseUrl = 'http://200.85.60.250:28080/adaControl';

  static final ValueNotifier<String?> urlNotifier = ValueNotifier(null);

  // Obtener la URL base configurada
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(endpointKey) ?? defaultBaseUrl;
    if (urlNotifier.value != url) {
      urlNotifier.value = url;
    }
    return url;
  }

  // Guardar nueva URL base
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(endpointKey, url);
    urlNotifier.value = url;
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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const String endpointKey = 'api_base_url';
  static const String defaultBaseUrl = 'http://reposicion.pulp.com.py:8443/adaControl';

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
    debugPrint('URL base actualizada');
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

  static const String apkEndpoint = '/api/getApk';

  static Future<String> getApkUrl() => getFullUrl(apkEndpoint);

  static bool isApkUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.apk') || 
           lowerUrl.contains(apkEndpoint.toLowerCase());
  }
}

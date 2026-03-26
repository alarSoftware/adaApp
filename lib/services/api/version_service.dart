import 'dart:convert';
import 'package:ada_app/config/app_config.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/network/monitored_http_client.dart';
import 'package:ada_app/utils/logger.dart';

class VersionInfo {
  final String latestVersion;
  final bool isUpdateAvailable;

  VersionInfo({required this.latestVersion, required this.isUpdateAvailable});
}

class VersionService {
  static Future<VersionInfo> checkUpdate() async {
    try {
      final baseUrl = await ApiConfigService.getBaseUrl();
      final url = '$baseUrl/api/latest_version';

      AppLogger.i('VERSION_SERVICE: Comprobando versión en $url');

      final response = await MonitoredHttpClient.get(
        url: Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.i('VERSION_SERVICE: Respuesta recibida: ${response.body}');
        
        // El servidor devuelve {"version": "1.1.0", "build": 9, "url": "/api/get_apk", ...}
        String? serverVersion;
        
        if (data is Map<String, dynamic>) {
          serverVersion = data['version']?.toString();
        }

        if (serverVersion == null) {
          throw 'No se encontró el campo "version" en la respuesta del servidor';
        }

        final currentVersion = AppConfig.currentAppVersion;
        final isAvailable = _isVersionNewer(currentVersion, serverVersion);

        AppLogger.i('VERSION_SERVICE: Versión actual: $currentVersion, Versión servidor: $serverVersion');

        return VersionInfo(
          latestVersion: serverVersion,
          isUpdateAvailable: isAvailable,
        );
      } else {
        throw 'Error del servidor: ${response.statusCode}';
      }
    } catch (e) {
      AppLogger.e('VERSION_SERVICE: Error al comprobar actualización', e);
      rethrow;
    }
  }

  static bool _isVersionNewer(String current, String server) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final serverParts = server.split('.').map(int.parse).toList();

      for (var i = 0; i < serverParts.length; i++) {
        if (i >= currentParts.length) return true; // Server tiene más partes (e.g. 1.1.0.1 > 1.1.0)
        if (serverParts[i] > currentParts[i]) return true;
        if (serverParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      // Fallback simple si el parseo falla
      return current != server;
    }
  }
}

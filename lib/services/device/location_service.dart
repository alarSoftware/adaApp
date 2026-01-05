import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Excepción personalizada para errores de ubicación
class LocationException implements Exception {
  final String message;
  final LocationErrorType type;

  const LocationException(this.message, this.type);

  @override
  String toString() => 'LocationException: $message';
}

enum LocationErrorType { permissionDenied, serviceDisabled, timeout, unknown }

/// Servicio centralizado para manejo de ubicación GPS
class LocationService {
  static LocationService? _instance;
  final Logger _logger = Logger();

  LocationService._internal();

  /// Singleton - una sola instancia del servicio
  factory LocationService() {
    return _instance ??= LocationService._internal();
  }
  // Agregar este método a tu LocationService
  Future<Map<String, double>> getCurrentLocationAsMap({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final position = await getCurrentLocationRequired(
      accuracy: accuracy,
      timeout: timeout,
    );

    return {'latitud': position.latitude, 'longitud': position.longitude};
  }

  /// Verificar si los servicios de ubicación están habilitados en el dispositivo
  Future<bool> isLocationServiceEnabled() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      _logger.i('Servicios de ubicación habilitados: $isEnabled');
      return isEnabled;
    } catch (e) {
      _logger.e('Error verificando servicios de ubicación: $e');
      return false;
    }
  }

  /// Verificar permisos actuales de ubicación
  Future<LocationPermission> checkPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      _logger.i('Permisos actuales: $permission');
      return permission;
    } catch (e) {
      _logger.e('Error verificando permisos: $e');
      return LocationPermission.denied;
    }
  }

  /// Solicitar permisos de ubicación al usuario
  Future<LocationPermission> requestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      _logger.i('Permisos solicitados - resultado: $permission');
      return permission;
    } catch (e) {
      _logger.e('Error solicitando permisos: $e');
      return LocationPermission.denied;
    }
  }

  /// Verificar si tenemos permisos válidos para obtener ubicación
  Future<bool> hasValidPermissions() async {
    final permission = await checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Asegurar que tenemos permisos válidos (solicita si es necesario)
  Future<bool> ensurePermissions() async {
    // Verificar servicios habilitados
    if (!await isLocationServiceEnabled()) {
      // Intentar "despertar" el diálogo de resolución de Android pidiendo ubicación
      try {
        await Geolocator.getCurrentPosition();
      } catch (_) {}

      // Verificar de nuevo
      if (!await isLocationServiceEnabled()) {
        throw const LocationException(
          'Los servicios de ubicación están deshabilitados. Por favor, habilítalos en Configuración.',
          LocationErrorType.serviceDisabled,
        );
      }
    }

    // Verificar permisos actuales
    LocationPermission permission = await checkPermission();

    // Solicitar permisos si están denegados
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }

    // Verificar resultado final
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Los permisos de ubicación fueron denegados permanentemente. Por favor, habilítalos manualmente en Configuración de la app.',
        LocationErrorType.permissionDenied,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Se necesitan permisos de ubicación para continuar.',
        LocationErrorType.permissionDenied,
      );
    }

    return true;
  }

  /// Obtener ubicación actual (puede retornar null si hay error)
  Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      _logger.i('Obteniendo ubicación GPS...');

      // Verificar permisos primero
      if (!await hasValidPermissions()) {
        _logger.w('No hay permisos válidos para ubicación');
        return null;
      }

      // Obtener posición
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );

      _logger.i(
        'Ubicación obtenida: ${position.latitude}, ${position.longitude} (precisión: ${position.accuracy}m)',
      );
      return position;
    } catch (e) {
      _logger.w('No se pudo obtener ubicación: $e');
      return null;
    }
  }

  /// Obtener ubicación actual (OBLIGATORIO - lanza excepción si falla)
  Future<Position> getCurrentLocationRequired({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 30),
    bool autoRequestPermissions = true,
  }) async {
    try {
      _logger.i('Obteniendo ubicación GPS (obligatorio)...');

      // Asegurar permisos si está habilitado
      if (autoRequestPermissions) {
        await ensurePermissions();
      }

      // Verificar servicios habilitados
      if (!await isLocationServiceEnabled()) {
        throw const LocationException(
          'Los servicios de ubicación están deshabilitados',
          LocationErrorType.serviceDisabled,
        );
      }

      // Verificar permisos
      if (!await hasValidPermissions()) {
        throw const LocationException(
          'No hay permisos de ubicación válidos',
          LocationErrorType.permissionDenied,
        );
      }

      // Obtener posición
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
        forceAndroidLocationManager: true,
      );

      _logger.i(
        'Ubicación obtenida exitosamente: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } on TimeoutException {
      throw const LocationException(
        'Tiempo agotado obteniendo ubicación GPS. Intenta en un lugar con mejor señal.',
        LocationErrorType.timeout,
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Los servicios de ubicación están deshabilitados',
        LocationErrorType.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const LocationException(
        'Permisos de ubicación denegados',
        LocationErrorType.permissionDenied,
      );
    } catch (e) {
      _logger.e('Error obteniendo ubicación obligatoria: $e');
      throw LocationException(
        'Error inesperado obteniendo ubicación: $e',
        LocationErrorType.unknown,
      );
    }
  }

  /// Obtener múltiples lecturas de ubicación y promediarlas (mayor precisión)
  Future<Position?> getCurrentLocationAveraged({
    int samples = 3,
    Duration delayBetweenSamples = const Duration(seconds: 2),
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      _logger.i('Obteniendo ubicación promediada ($samples muestras)...');

      if (!await hasValidPermissions()) {
        return null;
      }

      List<Position> positions = [];

      for (int i = 0; i < samples; i++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: accuracy,
            timeLimit: timeout,
          );
          positions.add(position);

          _logger.i(
            'Muestra ${i + 1}/$samples: ${position.latitude}, ${position.longitude}',
          );

          if (i < samples - 1) {
            await Future.delayed(delayBetweenSamples);
          }
        } catch (e) {
          _logger.w('Error en muestra ${i + 1}: $e');
        }
      }

      if (positions.isEmpty) {
        _logger.w('No se pudieron obtener muestras de ubicación');
        return null;
      }

      // Calcular promedio
      final avgLat =
          positions.map((p) => p.latitude).reduce((a, b) => a + b) /
          positions.length;
      final avgLng =
          positions.map((p) => p.longitude).reduce((a, b) => a + b) /
          positions.length;
      final avgAccuracy =
          positions.map((p) => p.accuracy).reduce((a, b) => a + b) /
          positions.length;

      _logger.i(
        'Ubicación promediada: $avgLat, $avgLng (precisión promedio: ${avgAccuracy.toStringAsFixed(1)}m)',
      );

      // Retornar usando la primera posición como base pero con coordenadas promediadas
      return Position(
        longitude: avgLng,
        latitude: avgLat,
        timestamp: DateTime.now(),
        accuracy: avgAccuracy,
        altitude: positions.first.altitude,
        heading: positions.first.heading,
        speed: positions.first.speed,
        speedAccuracy: positions.first.speedAccuracy,
        altitudeAccuracy: positions.first.altitudeAccuracy,
        headingAccuracy: positions.first.headingAccuracy,
      );
    } catch (e) {
      _logger.e('Error obteniendo ubicación promediada: $e');
      return null;
    }
  }

  /// Abrir configuraciones de ubicación del sistema
  Future<bool> openLocationSettings() async {
    try {
      final result = await Geolocator.openLocationSettings();
      _logger.i('Configuraciones de ubicación abiertas: $result');
      return result;
    } catch (e) {
      _logger.e('Error abriendo configuraciones: $e');
      return false;
    }
  }

  /// Abrir configuraciones de la app
  Future<bool> openAppSettings() async {
    try {
      final result = await Geolocator.openAppSettings();
      _logger.i('Configuraciones de app abiertas: $result');
      return result;
    } catch (e) {
      _logger.e('Error abriendo configuraciones de app: $e');
      return false;
    }
  }

  /// Obtener información de estado del GPS
  Future<Map<String, dynamic>> getLocationStatus() async {
    return {
      'serviceEnabled': await isLocationServiceEnabled(),
      'permission': (await checkPermission()).toString(),
      'hasValidPermissions': await hasValidPermissions(),
    };
  }

  /// Formatear coordenadas para mostrar en UI
  String formatCoordinates(Position position, {int decimals = 4}) {
    return '${position.latitude.toStringAsFixed(decimals)}, ${position.longitude.toStringAsFixed(decimals)}';
  }

  /// Calcular distancia entre dos posiciones en metros
  double calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Verificar si una posición está dentro de un radio específico (en metros)
  bool isWithinRadius(Position center, Position target, double radiusMeters) {
    final distance = calculateDistance(center, target);
    return distance <= radiusMeters;
  }

  /// 🕵️‍♂️ Detectar si la ubicación es simulada (Fake GPS)
  Future<bool> checkForMockLocation() async {
    try {
      if (!await hasValidPermissions()) {
        return false; // Sin permisos no podemos saber
      }

      // Obtener última posición conocida o actual
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition();

      if (position.isMocked) {
        _logger.w('⚠️ ALERTA: Ubicación simulada detectada (Fake GPS)');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error verificando ubicación simulada: $e');
      return false;
    }
  }
}

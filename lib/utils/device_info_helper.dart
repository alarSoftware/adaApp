// lib/utils/device_info_helper.dart
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/data/database_helper.dart';

/// 🔧 Helper para obtener información del dispositivo
/// Centraliza toda la lógica de obtención de datos sin duplicación
class DeviceInfoHelper {
  /// 📍 Obtener ubicación actual
  static Future<Position?> obtenerUbicacion() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Servicios de ubicación desactivados');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
      return null;
    }
  }

  /// 🔋 Obtener nivel de batería
  static Future<int> obtenerNivelBateria() async {
    try {
      final battery = Battery();
      return await battery.batteryLevel;
    } catch (e) {
      print('❌ Error al obtener nivel de batería: $e');
      return 0;
    }
  }

  /// 📱 Obtener modelo del dispositivo
  static Future<String> obtenerModeloDispositivo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      }

      return 'Desconocido';
    } catch (e) {
      print('❌ Error al obtener modelo: $e');
      return 'Desconocido';
    }
  }

  /// 👤 Obtener ID del vendedor actual
  static Future<String?> obtenerEmployeeId() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'Users',
        columns: ['employee_id'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['employee_id'] as String?;
      }

      print('⚠️ No se encontró usuario en la base de datos');
      return null;
    } catch (e) {
      print('❌ Error al obtener employee_id: $e');
      return null;
    }
  }

  /// 📦 Crear DeviceLog completo (método todo-en-uno)
  /// Obtiene todos los datos necesarios y crea el objeto DeviceLog
  static Future<DeviceLog?> crearDeviceLog() async {
    try {
      print('📦 Creando device log...');

      // Obtener todos los datos necesarios en paralelo para mayor eficiencia
      final results = await Future.wait([
        obtenerUbicacion(),
        obtenerNivelBateria(),
        obtenerModeloDispositivo(),
        obtenerEmployeeId(),
      ]);

      final position = results[0] as Position?;
      final bateria = results[1] as int;
      final modelo = results[2] as String;
      final employeeId = results[3] as String?;

      // Validar que tenemos ubicación
      if (position == null) {
        print('⚠️ No se pudo obtener ubicación - log no creado');
        return null;
      }

      // Crear el log
      final log = DeviceLog(
        id: const Uuid().v4(),
        employeeId: employeeId,
        latitudLongitud: '${position.latitude},${position.longitude}',
        bateria: bateria,
        modelo: modelo,
        fechaRegistro: DateTime.now().toIso8601String(),
        sincronizado: 0,
      );

      print('✅ DeviceLog creado exitosamente');
      print('   📍 Ubicación: ${log.latitudLongitud}');
      print('   🔋 Batería: ${log.bateria}%');
      print('   📱 Modelo: ${log.modelo}');

      return log;
    } catch (e) {
      print('💥 Error creando DeviceLog: $e');
      return null;
    }
  }

  /// 🔍 Verificar disponibilidad de servicios necesarios
  static Future<Map<String, bool>> verificarDisponibilidad() async {
    final resultados = <String, bool>{};

    try {
      // Verificar servicios de ubicación
      resultados['ubicacion'] = await Geolocator.isLocationServiceEnabled();

      // Verificar batería
      try {
        final battery = Battery();
        await battery.batteryLevel;
        resultados['bateria'] = true;
      } catch (e) {
        resultados['bateria'] = false;
      }

      // Verificar info del dispositivo
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          await deviceInfo.androidInfo;
        } else if (Platform.isIOS) {
          await deviceInfo.iosInfo;
        }
        resultados['device_info'] = true;
      } catch (e) {
        resultados['device_info'] = false;
      }

      // Verificar usuario en BD
      try {
        final userId = await obtenerEmployeeId();
        resultados['usuario'] = userId != null;
      } catch (e) {
        resultados['usuario'] = false;
      }

      return resultados;
    } catch (e) {
      print('Error verificando disponibilidad: $e');
      return resultados;
    }
  }

  /// 📊 Mostrar estado de disponibilidad
  static Future<void> mostrarEstadoDisponibilidad() async {
    final disponibilidad = await verificarDisponibilidad();

    print('═══════════════════════════════════════');
    print('📊 DISPONIBILIDAD DE SERVICIOS');
    print('═══════════════════════════════════════');
    disponibilidad.forEach((servicio, disponible) {
      final icono = disponible ? '✅' : '❌';
      print('$icono $servicio: ${disponible ? "DISPONIBLE" : "NO DISPONIBLE"}');
    });
    print('═══════════════════════════════════════');
  }
}

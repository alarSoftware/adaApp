import 'dart:async';
import 'dart:convert'; // 🆕 AGREGADO
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:logger/logger.dart';

class DeviceLogService {
  final DeviceLogRepository repository;
  final _battery = Battery();
  final _deviceInfo = DeviceInfoPlugin();
  final _logger = Logger();
  final _uuid = const Uuid();

  Timer? _timer;
  String? _modeloDispositivo;
  String? _edfVendedorId;

  DeviceLogService(this.repository);

  // Inicializar el servicio
  Future<void> iniciar({Duration intervalo = const Duration(minutes: 5)}) async {
    _logger.i('Iniciando servicio de registro de dispositivo');

    // Obtener modelo del dispositivo una sola vez
    await _obtenerModeloDispositivo();

    // Obtener edf_vendedor_id del usuario actual
    await _obtenerEdfVendedorId();

    // Solicitar permisos
    final permisosOk = await _solicitarPermisos();
    if (!permisosOk) {
      _logger.w('Permisos no otorgados');
      return;
    }

    // Guardar inmediatamente el primer registro
    await registrarDatos();

    // Iniciar timer para registros periódicos
    _timer = Timer.periodic(intervalo, (timer) async {
      await registrarDatos();
    });

    _logger.i('Servicio iniciado con intervalo de ${intervalo.inMinutes} minutos');
  }

  // Detener el servicio
  void detener() {
    _timer?.cancel();
    _timer = null;
    _logger.i('Servicio de registro detenido');
  }

  // Registrar datos manualmente
  Future<String?> registrarDatos() async {
    try {
      _logger.i('Registrando datos del dispositivo...');

      // Obtener ubicación
      final position = await _obtenerUbicacion();
      if (position == null) {
        _logger.w('No se pudo obtener la ubicación');
        return null;
      }

      // Obtener nivel de batería
      final bateria = await _obtenerNivelBateria();

      // Crear el objeto DeviceLog
      final log = DeviceLog(
        id: _uuid.v4(),
        edfVendedorId: _edfVendedorId,
        latitudLongitud: '${position.latitude},${position.longitude}',
        bateria: bateria,
        modelo: _modeloDispositivo ?? 'Desconocido',
        fechaRegistro: DateTime.now().toIso8601String(),
      );

      // 📦 VER EL JSON GENERADO
      final jsonMap = log.toMap();
      _logger.i('═══════════════════════════════════════');
      _logger.i('📦 JSON GENERADO PARA BACKEND:');
      _logger.i(jsonEncode(jsonMap));
      _logger.i('═══════════════════════════════════════');

      // Guardar en base de datos
      final id = await repository.guardarLog(
        edfVendedorId: _edfVendedorId,
        latitud: position.latitude,
        longitud: position.longitude,
        bateria: bateria,
        modelo: _modeloDispositivo ?? 'Desconocido',
      );

      _logger.i('✅ Datos registrados exitosamente: $id');

      // 🔍 Ver todos los logs guardados
      await _verTodosLosLogs();

      return id;
    } catch (e) {
      _logger.e('Error al registrar datos: $e');
      return null;
    }
  }

  // 🔍 Ver todos los logs guardados (para debug)
  Future<void> _verTodosLosLogs() async {
    try {
      final logs = await repository.obtenerTodos();
      _logger.i('═══════════════════════════════════════');
      _logger.i('📋 TOTAL DE LOGS EN BD: ${logs.length}');
      _logger.i('═══════════════════════════════════════');

      for (var i = 0; i < logs.length; i++) {
        final log = logs[i];
        _logger.i('Log #${i + 1}: ${jsonEncode(log.toMap())}');
      }

      _logger.i('═══════════════════════════════════════');
    } catch (e) {
      _logger.e('Error viendo logs: $e');
    }
  }

  // Obtener edf_vendedor_id del usuario actual
  Future<void> _obtenerEdfVendedorId() async {
    try {
      final db = await DatabaseHelper().database;

      // Obtener el primer usuario de la tabla (usuario logueado)
      final result = await db.query(
        'Users',
        columns: ['edf_vendedor_id', 'username', 'fullname'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        _edfVendedorId = result.first['edf_vendedor_id'] as String?;
        final username = result.first['username'];
        _logger.i('✅ Usuario encontrado: $username');
        _logger.i('✅ EDF Vendedor ID: $_edfVendedorId');
      } else {
        _logger.w('⚠️ No se encontró usuario en la base de datos');
      }
    } catch (e) {
      _logger.e('💥 Error al obtener edf_vendedor_id: $e');
    }
  }

  // Solicitar permisos necesarios
  Future<bool> _solicitarPermisos() async {
    try {
      final locationStatus = await Permission.location.request();

      if (locationStatus.isGranted) {
        return true;
      } else if (locationStatus.isPermanentlyDenied) {
        _logger.w('Permisos de ubicación denegados permanentemente');
        await openAppSettings();
      }

      return false;
    } catch (e) {
      _logger.e('Error al solicitar permisos: $e');
      return false;
    }
  }

  // Obtener ubicación actual
  Future<Position?> _obtenerUbicacion() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Servicios de ubicación desactivados');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      _logger.e('Error al obtener ubicación: $e');
      return null;
    }
  }

  // Obtener nivel de batería
  Future<int> _obtenerNivelBateria() async {
    try {
      final nivel = await _battery.batteryLevel;
      return nivel;
    } catch (e) {
      _logger.e('Error al obtener nivel de batería: $e');
      return 0;
    }
  }

  // Obtener modelo del dispositivo
  Future<void> _obtenerModeloDispositivo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _modeloDispositivo = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _modeloDispositivo = '${iosInfo.name} ${iosInfo.model}';
      } else {
        _modeloDispositivo = 'Desconocido';
      }

      _logger.i('📱 Modelo del dispositivo: $_modeloDispositivo');
    } catch (e) {
      _logger.e('Error al obtener modelo: $e');
      _modeloDispositivo = 'Desconocido';
    }
  }

  // Verificar si está activo
  bool get estaActivo => _timer != null && _timer!.isActive;
}
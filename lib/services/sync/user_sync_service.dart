import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class UserSyncService {
  static final _dbHelper = DatabaseHelper();

  static Future<SyncResult> sincronizarUsuarios() async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getUsers';

      final response = await http
          .get(Uri.parse(currentEndpoint), headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        BaseSyncService.logger.i('=== DEBUG API RESPONSE ===');
        BaseSyncService.logger.i('Response status: ${response.statusCode}');
        BaseSyncService.logger.i('Response data: $responseData');

        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        BaseSyncService.logger.i('=== DEBUG PARSED DATA ===');
        BaseSyncService.logger.i('Usuarios API count: ${usuariosAPI.length}');

        if (usuariosAPI.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay usuarios en el servidor',
            itemsSincronizados: 0,
          );
        }

        // === AQUÍ ES DONDE SE AGREGA LA NUEVA COLUMNA ===
        final usuariosProcesados = usuariosAPI.map((usuario) {
          String password = usuario['password'].toString();
          if (password.startsWith('{bcrypt}')) {
            password = password.substring(8);
          }

          final now = DateTime.now().toIso8601String();
          final usuarioId = usuario['id'];

          if (usuarioId == null) {
            BaseSyncService.logger.w('Usuario con ID null: $usuario');
          }

          return {
            'employee_id': usuario['employeeId']?.toString(),
            // 👇 NUEVA LÍNEA AGREGADA:
            'edfVendedorNombre': usuario['edfVendedorNombre']?.toString(),
            'code': usuarioId,
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
            'sincronizado': 1,
            'fecha_creacion': usuario['fecha_creacion'] ?? now,
            'fecha_actualizacion': usuario['fecha_actualizacion'] ?? now,
          };
        }).toList();

        BaseSyncService.logger.i('=== DATOS PROCESADOS PARA DB ===');
        for (int i = 0; i < usuariosProcesados.length; i++) {
          BaseSyncService.logger.i(
            'Usuario ${i + 1}: ${usuariosProcesados[i]}',
          );
        }

        try {
          await _dbHelper.sincronizarUsuarios(usuariosProcesados);
        } catch (dbError) {
          BaseSyncService.logger.e('Error guardando usuarios en BD: $dbError');

          await ErrorLogService.logDatabaseError(
            tableName: 'Users',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando usuarios: $dbError',
          );

          // No fallar, los datos se descargaron correctamente pero hubo error local
        }

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logServerError(
          tableName: 'Users',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } on TimeoutException catch (timeoutError) {
      BaseSyncService.logger.e(
        '⏰ Timeout sincronizando usuarios: $timeoutError',
      );

      await ErrorLogService.logNetworkError(
        tableName: 'Users',
        operation: 'sync_from_server',
        errorMessage: 'Timeout de conexión: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      BaseSyncService.logger.e('📡 Error de red: $socketError');

      await ErrorLogService.logNetworkError(
        tableName: 'Users',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión de red: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronizarUsuarios: $e');

      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'sync_from_server',
        errorMessage: 'Error general: $e',
        errorType: 'unknown',
        errorCode: 'GENERAL_ERROR',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // ... (obtenerEdfVendedorIdUsuarioActual y obtenerEdfVendedorIdDirecto quedan igual) ...
  // ... A MENOS QUE QUIERAS AGREGAR UN MÉTODO NUEVO PARA LEER EL NOMBRE 👇 ...

  // Método opcional sugerido: Obtener NOMBRE del vendedor actual
  static Future<String?> obtenerNombreVendedorUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_user');
      if (username == null) return null;

      final db = await _dbHelper.database;
      final result = await db.query(
        'Users',
        columns: ['edfVendedorNombre'], // Nombre de la columna nueva
        where: 'LOWER(username) = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['edfVendedorNombre'] as String?;
      }
      return null;
    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo nombre vendedor: $e');
      return null;
    }
  }

  // MANTENEMOS TUS MÉTODOS EXISTENTES ABAJO
  static Future<String?> obtenerEmployeeIdUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_user');

      if (username == null) {
        BaseSyncService.logger.e('No hay usuario logueado');
        await ErrorLogService.logValidationError(
          tableName: 'Users',
          operation: 'get_employee_id',
          errorMessage: 'No hay usuario logueado',
        );
        return null;
      }

      BaseSyncService.logger.i(
        'Buscando employee_id para usuario: $username',
      );

      final db = await _dbHelper.database;
      final result = await db.query(
        'Users',
        columns: ['employee_id'],
        where: 'LOWER(username) = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1,
      );

      if (result.isEmpty) {
        BaseSyncService.logger.e(
          'Usuario $username no encontrado en base de datos local',
        );
        await ErrorLogService.logDatabaseError(
          tableName: 'Users',
          operation: 'query_user',
          errorMessage:
              'Usuario $username no encontrado en base de datos local',
        );
        return null;
      }

      final employeeId = result.first['employee_id'] as String?;

      BaseSyncService.logger.i('Usuario encontrado: $username');
      BaseSyncService.logger.i('employee_id: $employeeId');

      if (employeeId == null || employeeId.trim().isEmpty) {
        // await ErrorLogService.logValidationError(
        //   tableName: 'Users',
        //   operation: 'get_edf_vendedor_id',
        //   errorMessage: 'Usuario $username no tiene edf_vendedor_id configurado',
        //   userId: username,
        // );
      }

      return employeeId;
    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo employee_id: $e');
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'get_employee_id',
        errorMessage: 'Error obteniendo employee_id: $e',
        errorType: 'database',
      );
      return null;
    }
  }

  static Future<String?> obtenerEmployeeIdIdDirecto(String username) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT employee_id FROM Users WHERE LOWER(username) = ? LIMIT 1',
        [username.toLowerCase()],
      );

      if (result.isNotEmpty && result.first['employee_id'] != null) {
        return result.first['employee_id'].toString();
      }

      await ErrorLogService.logDatabaseError(
        tableName: 'Users',
        operation: 'query_user_direct',
        errorMessage: 'Usuario $username no encontrado o sin employee_id',
      );

      return null;
    } catch (e) {
      BaseSyncService.logger.e('Error en obtenerEmployeeIdDirecto: $e');
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'query_user_direct',
        errorMessage: 'Error: $e',
        errorType: 'database',
      );
      return null;
    }
  }
}

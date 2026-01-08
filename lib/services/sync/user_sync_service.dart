import 'dart:convert';
import 'package:flutter/foundation.dart';
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

        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        if (usuariosAPI.isEmpty) {
          // Si no hay usuarios en el servidor, limpiar la tabla local
          try {
            await _dbHelper.sincronizarUsuarios([]);
          } catch (dbError) {}

          return SyncResult(
            exito: true,
            mensaje: 'No hay usuarios en el servidor (Tabla limpiada)',
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

          // PROCESAR RUTAS
          var rutas = usuario['rutas'];

          // Soporte para adaAppJsonPermission (String JSON) si 'rutas' no viene
          if (rutas == null && usuario['adaAppJsonPermission'] != null) {
            try {
              final jsonPermission = usuario['adaAppJsonPermission'];
              if (jsonPermission is String && jsonPermission.isNotEmpty) {
                // Decodificar JSON String
                rutas = jsonDecode(jsonPermission);

                // FIX: Manejo de doble encoding (si el resultado sigue siendo String)
                if (rutas is String) {
                  rutas = jsonDecode(rutas);
                }
              }
            } catch (e) {
              // Fail silently or log error if strictly needed, but print removal requested.
            }
          }

          if (rutas != null && rutas is List && usuarioId != null) {
            debugPrint(
              'Intentando sincronizar rutas para usuario $usuarioId...',
            );
            _dbHelper
                .sincronizarRutas(usuarioId, rutas)
                .then((_) {
                  debugPrint(
                    'Rutas sincronizadas exitosamente para $usuarioId',
                  );
                })
                .catchError((e) {
                  debugPrint(
                    'Error sincronizando rutas para usuario $usuarioId: $e',
                  );
                });
          } else {
            debugPrint(
              'No se llamará a sincronizarRutas. Rutas: $rutas, UsuarioId: $usuarioId',
            );
          }

          return {
            'id': usuarioId, // FIX: Asignar ID explícitamente a la PK
            'employee_id': usuario['employeeId']?.toString(),
            'employeeName': usuario['employeeName']?.toString(),
            'code': usuarioId,
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
            'sincronizado': 1,
            'fecha_creacion': usuario['fecha_creacion'] ?? now,
            'fecha_actualizacion': usuario['fecha_actualizacion'] ?? now,
          };
        }).toList();

        try {
          await _dbHelper.sincronizarUsuarios(usuariosProcesados);
        } catch (dbError) {
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
        columns: ['employee_name'], // Nombre de la columna nueva
        where: 'LOWER(username) = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['employee_name'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> obtenerEmployeeIdUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_user');

      if (username == null) {
        throw Exception("NO HAY USUARIO LOGUEADO");
      }

      final db = await _dbHelper.database;
      final result = await db.query(
        'Users',
        columns: ['employee_id'],
        where: 'LOWER(username) = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1,
      );

      if (result.isEmpty) {
        throw Exception(
          'Usuario $username no encontrado en base de datos local',
        );
      }

      final employeeId = result.first['employee_id'] as String?;

      if (employeeId == null || employeeId.trim().isEmpty) {
        throw Exception(
          'Usuario $username no tiene edf_vendedor_id configurado',
        );
      }

      return employeeId;
    } catch (e) {
      rethrow;
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

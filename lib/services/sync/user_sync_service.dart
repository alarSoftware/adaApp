import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSyncService {
  static final _dbHelper = DatabaseHelper();

  static Future<SyncResult> sincronizarUsuarios() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getUsers'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

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
            'edf_vendedor_id': usuario['edfVendedorId']?.toString(),
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
          BaseSyncService.logger.i('Usuario ${i + 1}: ${usuariosProcesados[i]}');
        }

        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error en sincronizarUsuarios: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<String?> obtenerEdfVendedorIdUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('current_user');

      if (username == null) {
        BaseSyncService.logger.e('No hay usuario logueado');
        return null;
      }

      BaseSyncService.logger.i('Buscando edf_vendedor_id para usuario: $username');

      // Consulta directa a la base de datos por el campo edf_vendedor_id
      final db = await _dbHelper.database;
      final result = await db.query(
        'Users',
        columns: ['edf_vendedor_id'],
        where: 'LOWER(username) = ?',
        whereArgs: [username.toLowerCase()],
        limit: 1,
      );

      if (result.isEmpty) {
        BaseSyncService.logger.e('Usuario $username no encontrado en base de datos local');
        return null;
      }

      final edfVendedorId = result.first['edf_vendedor_id'] as String?;

      BaseSyncService.logger.i('Usuario encontrado: $username');
      BaseSyncService.logger.i('edf_vendedor_id: $edfVendedorId');

      return edfVendedorId;

    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo edf_vendedor_id: $e');
      return null;
    }
  }

  // Método alternativo más eficiente usando raw query
  static Future<String?> obtenerEdfVendedorIdDirecto(String username) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
          'SELECT edf_vendedor_id FROM Users WHERE LOWER(username) = ? LIMIT 1',
          [username.toLowerCase()]
      );

      if (result.isNotEmpty && result.first['edf_vendedor_id'] != null) {
        return result.first['edf_vendedor_id'].toString();
      }

      return null;
    } catch (e) {
      BaseSyncService.logger.e('Error en obtenerEdfVendedorIdDirecto: $e');
      return null;
    }
  }
}
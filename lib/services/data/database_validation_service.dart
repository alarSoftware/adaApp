import 'package:sqflite/sqflite.dart';

class PendingSyncInfo {
  final String tableName;
  final int count;
  final String displayName;

  PendingSyncInfo({
    required this.tableName,
    required this.count,
    required this.displayName,
  });
}

class DatabaseValidationResult {
  final bool canDelete;
  final List<PendingSyncInfo> pendingItems;
  final String message;

  DatabaseValidationResult({
    required this.canDelete,
    required this.pendingItems,
    required this.message,
  });

  factory DatabaseValidationResult.safe() {
    return DatabaseValidationResult(
      canDelete: true,
      pendingItems: [],
      message: 'Todos los datos están sincronizados',
    );
  }

  factory DatabaseValidationResult.unsafe(List<PendingSyncInfo> items) {
    final message = _buildMessage(items);
    return DatabaseValidationResult(
      canDelete: false,
      pendingItems: items,
      message: message,
    );
  }

  static String _buildMessage(List<PendingSyncInfo> items) {
    final buffer = StringBuffer('Hay datos pendientes de sincronizar:\n\n');

    for (final item in items) {
      buffer.writeln('• ${item.displayName}: ${item.count} registro(s)');
    }

    buffer.write(
      '\nPor favor, sincroniza estos datos antes de eliminar la base de datos.',
    );
    return buffer.toString();
  }
}

class DatabaseValidationService {
  final Database db;

  DatabaseValidationService(this.db);

  /// Verifica si la base de datos puede ser eliminada de forma segura
  Future<DatabaseValidationResult> canDeleteDatabase() async {
    final pendingItems = <PendingSyncInfo>[];

    // 1. Verificar tablas con sync_status
    await _checkSyncStatusTables(pendingItems);

    // 2. Verificar tablas con campo 'sincronizado'
    await _checkSincronizadoTables(pendingItems);

    // 3. Verificar estados específicos
    await _checkEstadoTables(pendingItems);

    if (pendingItems.isEmpty) {
      return DatabaseValidationResult.safe();
    }

    return DatabaseValidationResult.unsafe(pendingItems);
  }

  /// Verifica tablas que usan sync_status (pending, synced, draft, error)
  /// Solo cuenta registros con ERROR
  Future<void> _checkSyncStatusTables(
    List<PendingSyncInfo> pendingItems,
  ) async {
    final tables = {
      'dynamic_form_response': 'Respuestas de Formularios',
      'dynamic_form_response_detail': 'Detalles de Respuestas',
      'dynamic_form_response_image': 'Imágenes de Formularios',
      'operacion_comercial': 'Operaciones Comerciales',
    };

    for (var entry in tables.entries) {
      final tableName = entry.key;
      final displayName = entry.value;

      try {
        // Solo contar ERRORES, no pendientes
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE sync_status = ?',
          ['error'],
        );

        final count = Sqflite.firstIntValue(result) ?? 0;

        if (count > 0) {
          pendingItems.add(
            PendingSyncInfo(
              tableName: tableName,
              count: count,
              displayName: displayName,
            ),
          );
        }
      } catch (e) {
        // Si la tabla no existe o hay error, continuamos
      }
    }
  }

  /// Verifica tablas que usan el campo 'sincronizado' (0 o 1)
  /// Se ha eliminado la verificación de 'censo_activo' ya que se valida por estado
  Future<void> _checkSincronizadoTables(
    List<PendingSyncInfo> pendingItems,
  ) async {
    final tables = {
      'equipos_pendientes': 'Equipos Pendientes',
      'censo_activo_foto': 'Fotos de Censo',
      // 'device_log': 'Logs de Dispositivo',
    };

    for (var entry in tables.entries) {
      final tableName = entry.key;
      final displayName = entry.value;

      try {
        // Consultamos si hay registros con sincronizado = 0
        final result = await db.query(
          tableName,
          columns: ['COUNT(*) as count'],
          where: 'sincronizado = ?',
          whereArgs: [0],
        );

        final count = Sqflite.firstIntValue(result) ?? 0;

        if (count > 0) {
          pendingItems.add(
            PendingSyncInfo(
              tableName: tableName,
              count: count,
              displayName: displayName,
            ),
          );
        }
      } catch (e) {
        // Ignorar si la columna no existe
      }
    }
  }

  /// Verifica tablas con estados específicos que no deben eliminarse
  Future<void> _checkEstadoTables(List<PendingSyncInfo> pendingItems) async {
    // Verificar censo_activo - SOLO con ERROR
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM censo_activo WHERE estado_censo = ?',
        ['error'],
      );

      final count = Sqflite.firstIntValue(result) ?? 0;

      if (count > 0) {
        pendingItems.add(
          PendingSyncInfo(
            tableName: 'censo_activo',
            count: count,
            displayName: 'Censos con Error',
          ),
        );
      }
    } catch (e) {}
  }

  /// Obtiene un resumen detallado de todos los registros pendientes
  Future<Map<String, dynamic>> getPendingSyncSummary() async {
    final result = await canDeleteDatabase();

    return {
      'can_delete': result.canDelete,
      'total_pending': result.pendingItems.fold<int>(
        0,
        (sum, item) => sum + item.count,
      ),
      'pending_by_table': result.pendingItems
          .map(
            (item) => {
              'table': item.tableName,
              'display_name': item.displayName,
              'count': item.count,
            },
          )
          .toList(),
      'message': result.message,
    };
  }
}

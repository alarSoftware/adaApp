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

    buffer.write('\nPor favor, sincroniza estos datos antes de eliminar la base de datos.');
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
  /// Solo bloquea si hay registros con sync_status que NO sean 'synced' o 'draft'
  Future<void> _checkSyncStatusTables(List<PendingSyncInfo> pendingItems) async {
    final tables = {
      'dynamic_form_response': 'Respuestas de Formularios',
      'dynamic_form_response_detail': 'Detalles de Respuestas',
      'dynamic_form_response_image': 'Imágenes de Formularios',
    };

    for (var entry in tables.entries) {
      final tableName = entry.key;
      final displayName = entry.value;

      try {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE sync_status NOT IN (?, ?)',
          ['synced', 'draft'],
        );

        final count = Sqflite.firstIntValue(result) ?? 0;

        if (count > 0) {
          pendingItems.add(PendingSyncInfo(
            tableName: tableName,
            count: count,
            displayName: displayName,
          ));
        }
      } catch (e) {
        // Si la tabla no existe o hay error, continuamos
        print('Error verificando $tableName: $e');
      }
    }
  }

  /// Verifica tablas que usan el campo 'sincronizado' (0 o 1)
  Future<void> _checkSincronizadoTables(List<PendingSyncInfo> pendingItems) async {
    final tables = {
      'equipos_pendientes': 'Equipos Pendientes',
      'censo_activo': 'Censos Activos',
      'censo_activo_foto': 'Fotos de Censo',
      'device_log': 'Logs de Dispositivo',
    };

    for (var entry in tables.entries) {
      final tableName = entry.key;
      final displayName = entry.value;

      try {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $tableName WHERE sincronizado = 0',
        );

        final count = Sqflite.firstIntValue(result) ?? 0;

        if (count > 0) {
          pendingItems.add(PendingSyncInfo(
            tableName: tableName,
            count: count,
            displayName: displayName,
          ));
        }
      } catch (e) {
        print('Error verificando $tableName: $e');
      }
    }
  }

  /// Verifica tablas con estados específicos que no deben eliminarse
  Future<void> _checkEstadoTables(List<PendingSyncInfo> pendingItems) async {
    // Verificar censo_activo con estados pendientes o en error
    // Estados válidos: 'creado', 'error', etc. - solo permitir eliminar si está 'migrado' o 'completado'
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM censo_activo WHERE estado_censo NOT IN (?, ?)',
        ['migrado', 'completado'],
      );

      final count = Sqflite.firstIntValue(result) ?? 0;

      if (count > 0) {
        pendingItems.add(PendingSyncInfo(
          tableName: 'censo_activo',
          count: count,
          displayName: 'Censos Pendientes o con Error',
        ));
      }
    } catch (e) {
      print('Error verificando estados de censos: $e');
    }
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
      'pending_by_table': result.pendingItems.map((item) => {
        'table': item.tableName,
        'display_name': item.displayName,
        'count': item.count,
      }).toList(),
      'message': result.message,
    };
  }
}
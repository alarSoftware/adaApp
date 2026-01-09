import 'package:flutter/material.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:intl/intl.dart';

class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({Key? key}) : super(key: key);

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final logs = await db.query('error_log', orderBy: 'timestamp DESC');
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Sin fecha';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getErrorColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'sync':
        return Colors.blue;
      case 'database':
        return Colors.purple;
      case 'network':
        return Colors.orange;
      case 'validation':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  IconData _getErrorIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'sync':
        return Icons.sync_problem;
      case 'database':
        return Icons.storage;
      case 'network':
        return Icons.wifi_off;
      case 'validation':
        return Icons.rule;
      default:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Errores'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Limpiar Registros'),
                  content: const Text(
                    '¿Estás seguro de borrar todos los registros de error?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Borrar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ErrorLogService.limpiarLogsAntiguos(
                  diasAntiguedad: 0,
                ); // 0 = borrar todo
                _loadLogs();
              }
            },
            tooltip: 'Limpiar Todo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay errores registrados',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.green[700]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final type = log['error_type'] as String?;
                final message = log['error_message'] as String?;
                final date = log['timestamp'] as String?;
                final table = log['table_name'] as String?;
                final operation = log['operation'] as String?;
                final sincronizado = log['sincronizado'] as int? ?? 0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getErrorColor(type).withOpacity(0.2),
                      child: Icon(
                        _getErrorIcon(type),
                        color: _getErrorColor(type),
                      ),
                    ),
                    title: Text(
                      type?.toUpperCase() ?? 'ERROR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getErrorColor(type),
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          message ?? 'Sin mensaje',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Tooltip(
                      message: sincronizado == 1
                          ? 'Sincronizado con el servidor'
                          : 'Pendiente de envío',
                      child: Icon(
                        sincronizado == 1
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: sincronizado == 1
                            ? Colors.green
                            : Colors.red[300],
                        size: 24,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Tabla', table),
                            _buildDetailRow('Operación', operation),
                            _buildDetailRow(
                              'ID Registro',
                              log['registro_fail_id']?.toString(),
                            ),
                            _buildDetailRow(
                              'Estado Sync',
                              sincronizado == 1 ? 'Enviado' : 'Pendiente',
                            ),
                            if (sincronizado == 0 && log['retry_count'] != null)
                              _buildDetailRow(
                                'Reintentos',
                                log['retry_count'].toString(),
                              ),
                            const Divider(),
                            const Text(
                              'Detalle del Error:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              message ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            if (log['stack_trace'] != null) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Stack Trace:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.grey[100],
                                width: double.infinity,
                                child: SelectableText(
                                  log['stack_trace'],
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

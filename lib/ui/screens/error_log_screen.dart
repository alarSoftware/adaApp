import 'package:flutter/material.dart';
import '../../utils/logger.dart';
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
    } catch (e) { AppLogger.e("ERROR_LOG_SCREEN: Error", e); return dateStr; }
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

  int _countNoMigrados() {
    return _logs.where((log) => (log['sincronizado'] as int? ?? 0) == 0).length;
  }

  Future<void> _retryPendingLogs() async {
    final noMigrados = _countNoMigrados();

    if (noMigrados == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay error logs no migrados para enviar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reintentar Envío'),
        content: Text(
          '¿Deseas reintentar el envío de $noMigrados error log${noMigrados > 1 ? "s" : ""} no migrado${noMigrados > 1 ? "s" : ""} al servidor?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Enviando error logs...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resultado = await ErrorLogService.enviarErrorLogsAlServidor(
        force: true,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          backgroundColor: resultado.exito ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      if (resultado.logsEnviados > 0) {
        await _loadLogs();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reintentar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _retryIndividualLog(String id) async {
    setState(() => _isLoading = true);
    try {
      final success = await ErrorLogService.enviarErrorLogPorId(id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Log enviado exitosamente' : 'Error al enviar log',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      await _loadLogs();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noMigrados = _countNoMigrados();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Registro de Errores',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (noMigrados > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$noMigrados pend.',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          if (noMigrados > 0)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _retryPendingLogs,
              tooltip: 'Reintentar Envío',
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
                          ? 'Migrado al servidor'
                          : 'No migrado',
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
                              'Estado',
                              sincronizado == 1 ? 'Migrado' : 'No migrado',
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
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (sincronizado == 0)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _retryIndividualLog(log['id']),
                                    icon: const Icon(Icons.send),
                                    label: const Text('Reintentar'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                              ],
                            ),
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

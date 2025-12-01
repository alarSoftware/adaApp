// lib/ui/screens/operaciones_pendientes_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:intl/intl.dart';

class OperacionesPendientesDetailScreen extends StatefulWidget {
  final PendingDataViewModel viewModel;
  final PendingDataGroup group;

  const OperacionesPendientesDetailScreen({
    Key? key,
    required this.viewModel,
    required this.group,
  }) : super(key: key);

  @override
  State<OperacionesPendientesDetailScreen> createState() =>
      _OperacionesPendientesDetailScreenState();
}

class _OperacionesPendientesDetailScreenState
    extends State<OperacionesPendientesDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _operacionesFallidas = [];
  String? _error;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadOperacionesFallidas();
  }

  Future<void> _loadOperacionesFallidas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final operaciones = await widget.viewModel.getOperacionesFallidas();
      setState(() {
        _operacionesFallidas = operaciones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Operaciones Pendientes (${widget.group.count})'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_operacionesFallidas.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOperacionesFallidas,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando operaciones pendientes...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error cargando datos'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOperacionesFallidas,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_operacionesFallidas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              'Todas las operaciones sincronizadas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text('No hay operaciones pendientes'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOperacionesFallidas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _operacionesFallidas.length,
        itemBuilder: (context, index) {
          final operacion = _operacionesFallidas[index];
          return _buildOperacionCard(operacion);
        },
      ),
    );
  }

  Widget _buildOperacionCard(Map<String, dynamic> operacion) {
    final tipoOperacion = operacion['tipo_operacion']?.toString() ?? 'Sin tipo';
    final clienteNombre = operacion['cliente_nombre']?.toString() ?? 'Sin cliente';
    final fechaCreacion = operacion['fecha_creacion'] != null
        ? DateTime.parse(operacion['fecha_creacion'])
        : null;
    final mensajeError = operacion['sync_error']?.toString();
    final montoTotal = 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _mostrarDetalleOperacion(operacion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sync_problem,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tipoOperacion,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clienteNombre,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Información de la operación
              _buildInfoRow(
                Icons.business,
                'Estado',
                operacion['estado']?.toString() ?? 'N/A',
              ),
              _buildInfoRow(
                Icons.inventory_2,
                'Total Productos',
                '${operacion['total_productos'] ?? 0}',
              ),
              if (fechaCreacion != null)
                _buildInfoRow(
                  Icons.access_time,
                  'Fecha',
                  DateFormat('dd/MM/yyyy HH:mm').format(fechaCreacion),
                ),
              _buildInfoRow(
                Icons.sync,
                'Estado Sync',
                operacion['sync_status']?.toString() ?? 'N/A',
                valueColor: Colors.orange,
              ),

              // Mensaje de error
              if (mensajeError != null && mensajeError.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mensajeError,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Hint de tap para ver más
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 14,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Toca para ver detalles completos',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ??
                    Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleOperacion(Map<String, dynamic> operacion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalle de Operación'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', operacion['id']?.toString() ?? 'N/A'),
              _buildDetailRow('Tipo', operacion['tipo_operacion']?.toString() ?? 'N/A'),
              _buildDetailRow('Cliente', operacion['cliente_nombre']?.toString() ?? 'N/A'),
              _buildDetailRow('Estado', operacion['estado']?.toString() ?? 'N/A'),
              _buildDetailRow('Total Productos', operacion['total_productos']?.toString() ?? '0'),
              _buildDetailRow('Estado Sync', operacion['sync_status']?.toString() ?? 'N/A'),
              if (operacion['sync_error'] != null)
                _buildDetailRow('Error', operacion['sync_error']?.toString() ?? 'N/A'),
              if (operacion['observaciones'] != null && operacion['observaciones'].toString().isNotEmpty)
                _buildDetailRow('Observaciones', operacion['observaciones']?.toString() ?? 'N/A'),
              if (operacion['fecha_creacion'] != null)
                _buildDetailRow(
                  'Fecha Creación',
                  DateFormat('dd/MM/yyyy HH:mm:ss')
                      .format(DateTime.parse(operacion['fecha_creacion'])),
                ),
              if (operacion['synced_at'] != null)
                _buildDetailRow(
                  'Última Sync',
                  DateFormat('dd/MM/yyyy HH:mm:ss')
                      .format(DateTime.parse(operacion['synced_at'])),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
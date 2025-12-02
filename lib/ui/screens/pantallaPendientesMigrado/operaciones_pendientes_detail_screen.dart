// lib/ui/screens/operaciones_pendientes_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
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

  // 🆕 MÉTODO PARA NAVEGAR AL HISTORIAL DE LA OPERACIÓN
  Future<void> _navegarAHistorialOperacion(Map<String, dynamic> operacion) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Obtener datos completos de la operación
      final operacionCompleta = await _obtenerOperacionCompleta(operacion['id']);

      // Cerrar indicador de carga
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (operacionCompleta == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron cargar los datos de la operación'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 🔥 NAVEGAR A OperacionComercialFormScreen en modo historial
      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OperacionComercialFormScreen(
            cliente: operacionCompleta['cliente'],
            tipoOperacion: operacionCompleta['tipo_operacion'],
            operacionExistente: operacionCompleta['operacion'],
            isViewOnly: true, // Siempre en modo solo lectura
          ),
        ),
      );

      // Si se reintentó y tuvo éxito, recargar lista
      if (resultado == true && mounted) {
        await _loadOperacionesFallidas();
      }

    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      debugPrint('Error navegando al historial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 MÉTODO AUXILIAR - Obtener OperacionComercial completa
  Future<Map<String, dynamic>?> _obtenerOperacionCompleta(dynamic operacionId) async {
    try {
      final db = await _dbHelper.database;

      // Obtener operación base (SIN JOIN a clientes)
      final operaciones = await db.rawQuery('''
        SELECT oc.*
        FROM operacion_comercial oc
        WHERE oc.id = ?
      ''', [operacionId]);

      if (operaciones.isEmpty) return null;

      final operacionData = operaciones.first;

      // Obtener cliente completo desde el repository
      final clienteRepository = ClienteRepository();
      final clienteId = operacionData['cliente_id'];

      if (clienteId == null) {
        throw Exception('Cliente ID no encontrado');
      }

      final cliente = await clienteRepository.obtenerPorId(
          clienteId is int ? clienteId : int.parse(clienteId.toString())
      );

      if (cliente == null) {
        throw Exception('Cliente no encontrado en la base de datos');
      }

      // Obtener productos/detalles de la operación
      final productosRaw = await db.rawQuery('''
        SELECT 
          ocd.*,
          p.nombre as producto_nombre,
          p.codigo as producto_codigo,
          p.categoria as producto_categoria
        FROM operacion_comercial_detalle ocd
        LEFT JOIN productos p ON ocd.producto_id = p.id
        WHERE ocd.operacion_comercial_id = ?
        ORDER BY ocd.orden
      ''', [operacionId]);

      // Parsear tipo de operación
      final tipoOperacionStr = operacionData['tipo_operacion'] as String;
      final tipoOperacion = TipoOperacion.values.firstWhere(
            (t) => t.name == tipoOperacionStr,
        orElse: () => TipoOperacion.notaRetiroDiscontinuos,
      );

      // Construir OperacionComercial base usando fromMap
      final operacion = OperacionComercial.fromMap(operacionData);

      // Construir lista de detalles usando OperacionComercialDetalle.fromMap
      final detalles = productosRaw.map((prod) {
        // Construir un mapa compatible con OperacionComercialDetalle.fromMap
        final detalleMap = {
          'id': prod['id'],
          'operacion_comercial_id': prod['operacion_comercial_id'],
          'producto_id': prod['producto_id'],
          'producto_codigo': prod['producto_codigo'],
          'producto_descripcion': prod['producto_descripcion'],
          'producto_categoria': prod['producto_categoria'],
          'cantidad': prod['cantidad'],
          'unidad_medida': prod['unidad_medida'],
          'orden': prod['orden'],
          'producto_reemplazo_id': prod['producto_reemplazo_id'],
          'producto_reemplazo_codigo': prod['producto_reemplazo_codigo'],
          'producto_reemplazo_descripcion': prod['producto_reemplazo_descripcion'],
        };
        return OperacionComercialDetalle.fromMap(detalleMap);
      }).toList();

      // Usar copyWith para agregar los detalles
      final operacionConDetalles = operacion.copyWith(detalles: detalles);

      return {
        'cliente': cliente,
        'tipo_operacion': tipoOperacion,
        'operacion': operacionConDetalles,
      };

    } catch (e, stackTrace) {
      debugPrint('Error obteniendo operación completa: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navegarAHistorialOperacion(operacion), // 🆕 NAVEGAR AL HISTORIAL
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
                  // 🆕 Indicador de que es clickeable
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

              // 🆕 Hint de tap para ver más
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
                    'Toca para ver detalles completos y reintentar',
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
}
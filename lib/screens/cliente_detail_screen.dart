import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/equipos_cliente.dart';
import '../repositories/equipo_cliente_repository.dart';
import 'equipos_clientes_detail_screen.dart';
import 'forms_screen.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class ClienteDetailScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen> {
  List<EquipoCliente> _equiposAsignados = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarEquiposAsignados();
  }

  // ===============================
  // MÉTODOS DE DATOS
  // ===============================

  Future<void> _cargarEquiposAsignados() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.cliente.id == null) {
        _setEquiposVacios();
        return;
      }

      final equipoClienteRepo = EquipoClienteRepository();
      final equiposDelCliente = await equipoClienteRepo.obtenerPorCliente(
          widget.cliente.id!,
          soloActivos: true);

      if (mounted) {
        setState(() {
          _equiposAsignados = equiposDelCliente;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error cargando equipos del cliente', error: e, stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando equipos: ${e.toString()}';
        });
      }
    }
  }

  void _setEquiposVacios() {
    if (mounted) {
      setState(() {
        _equiposAsignados = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _cargarEquiposAsignados();
  }

  // ===============================
  // MÉTODOS DE NAVEGACIÓN
  // ===============================

  Future<void> _asignarNuevoEquipo() async {
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormsScreen(
          cliente: widget.cliente,
        ),
      ),
    );

    // Si se asignó un equipo exitosamente, recargar los datos
    if (result == true) {
      _cargarEquiposAsignados();
    }
  }

  void _navegarADetalleEquipo(EquipoCliente equipoCliente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquiposClientesDetailScreen(
          equipoCliente: equipoCliente,
        ),
      ),
    ).then((_) {
      // Recargar datos al volver de la pantalla de detalle
      _refreshData();
    });
  }

  // ===============================
  // MÉTODOS DE UI
  // ===============================

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  // ===============================
  // WIDGETS
  // ===============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _cargarEquiposAsignados,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClienteInfoCard(),
              const SizedBox(height: 24),
              _buildEquiposSection(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Detalle de Cliente'),
      backgroundColor: Colors.grey[800],
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        IconButton(
          onPressed: _asignarNuevoEquipo,
          icon: const Icon(Icons.add),
          tooltip: 'Realizar censo de equipo',
        ),
      ],
    );
  }

  Widget _buildClienteInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.cliente.nombre,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Información del cliente
            _buildInfoRow(Icons.email_outlined, 'Email', widget.cliente.email),

            if (widget.cliente.telefono?.isNotEmpty == true)
              _buildInfoRow(Icons.phone_outlined, 'Teléfono', widget.cliente.telefono!),

            if (widget.cliente.direccion?.isNotEmpty == true)
              _buildInfoRow(Icons.location_on_outlined, 'Dirección', widget.cliente.direccion!),

            _buildInfoRow(
                Icons.access_time_outlined,
                'Fecha de creación',
                _formatearFecha(widget.cliente.fechaCreacion)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquiposSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.kitchen_outlined,
                color: Colors.orange[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Equipos Asignados',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_equiposAsignados.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEquiposContent(),
      ],
    );
  }

  Widget _buildEquiposContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_equiposAsignados.isEmpty) {
      return _buildEmptyState();
    }

    return _buildEquiposList();
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Colors.orange[700],
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando equipos...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Error al cargar equipos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarEquiposAsignados,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin equipos censados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este cliente no tiene equipos censados actualmente',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _asignarNuevoEquipo,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Realizar Censo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange[700],
              side: BorderSide(color: Colors.orange[700]!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquiposList() {
    return Column(
      children: _equiposAsignados.map((equipoCliente) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _navegarADetalleEquipo(equipoCliente),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar del equipo
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.kitchen,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Información del equipo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            equipoCliente.equipoNombreCompleto,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          if (equipoCliente.equipoCodBarras?.isNotEmpty == true)
                            Text(
                              equipoCliente.equipoCodBarras!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Censado hace ${equipoCliente.diasDesdeAsignacion} días',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Flecha
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
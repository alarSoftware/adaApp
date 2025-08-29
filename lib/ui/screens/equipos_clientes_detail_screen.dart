// ui/screens/equipos_clientes_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/models/equipos_cliente.dart';
import 'package:ada_app/viewmodels/equipos_clientes_detail_screen_viewmodel.dart';
import 'dart:async';

class EquiposClientesDetailScreen extends StatefulWidget {
  final EquipoCliente equipoCliente;

  const EquiposClientesDetailScreen({
    Key? key,
    required this.equipoCliente,
  }) : super(key: key);

  @override
  State<EquiposClientesDetailScreen> createState() => _EquiposClientesDetailScreenState();
}

class _EquiposClientesDetailScreenState extends State<EquiposClientesDetailScreen> {
  late EquiposClienteDetailScreenViewModel _viewModel;
  late StreamSubscription<EquiposClienteDetailUIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = EquiposClienteDetailScreenViewModel(widget.equipoCliente);
    _setupEventListener();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowMessageEvent) {
        _showMessage(event.message, event.type);
      } else if (event is ShowRetireConfirmationDialogEvent) {
        _showRetireConfirmationDialog(event.equipoCliente);
      }
    });
  }

  void _showMessage(String message, MessageType type) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case MessageType.error:
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case MessageType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        break;
      case MessageType.warning:
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showRetireConfirmationDialog(EquipoCliente equipoCliente) async {
    final dialogData = _viewModel.getRetireDialogData();

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Retirar Equipo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Estás seguro de que quieres retirar este equipo?'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dialogData['equipoNombre']!),
                    if (dialogData['equipoCodigo']! != 'Sin código')
                      Text('Código: ${dialogData['equipoCodigo']}'),
                    Text('Cliente: ${dialogData['clienteNombre']}'),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Esta acción marcará el equipo como retirado y ya no estará asignado a este cliente.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Retirar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      _viewModel.confirmarRetiroEquipo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle del Equipo'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return IconButton(
                onPressed: _viewModel.isProcessing ? null : _viewModel.reportarEstado,
                icon: _viewModel.isProcessing
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.report),
                tooltip: 'Reportar estado',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                icon: Icons.kitchen,
                title: 'EQUIPO ASIGNADO',
                color: Colors.orange,
              ),
              SizedBox(height: 12),
              _buildEquipoInfo(),
              SizedBox(height: 32),
              _buildActionButtons(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipoInfo() {
    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.kitchen,
          title: 'Equipo',
          content: _viewModel.getNombreCompletoEquipo(),
          color: Colors.orange,
        ),

        if (_viewModel.shouldShowMarca())
          _buildInfoCard(
            icon: Icons.business,
            title: 'Marca',
            content: _viewModel.getMarcaText(),
            color: Colors.indigo,
          ),

        if (_viewModel.shouldShowModelo())
          _buildInfoCard(
            icon: Icons.category,
            title: 'Modelo',
            content: _viewModel.getModeloText(),
            color: Colors.teal,
          ),

        if (_viewModel.shouldShowCodBarras())
          _buildInfoCard(
            icon: Icons.qr_code,
            title: 'Código de Barras',
            content: _viewModel.getCodBarrasText(),
            color: Colors.purple,
          ),

        _buildInfoCard(
          icon: Icons.calendar_today,
          title: 'Fecha de Asignación',
          content: _viewModel.getFechaAsignacionText(),
          color: Colors.teal,
        ),

        _buildInfoCard(
          icon: Icons.access_time,
          title: 'Tiempo Asignado',
          content: _viewModel.getTiempoAsignadoText(),
          color: Colors.indigo,
        ),

        if (_viewModel.shouldShowFechaRetiro())
          _buildInfoCard(
            icon: Icons.event_busy,
            title: 'Fecha de Retiro',
            content: _viewModel.getFechaRetiroText(),
            color: Colors.red,
          ),

        _buildInfoCard(
          icon: _viewModel.equipoCliente.asignacionActiva ? Icons.check_circle : Icons.cancel,
          title: 'Estado',
          content: _viewModel.getEstadoText(),
          color: _viewModel.equipoCliente.colorEstado,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isEquipoActivo) {
          return Column(
            children: [
              _buildActionButton(
                onPressed: _viewModel.isProcessing ? null : _viewModel.verificarEquipo,
                icon: Icons.camera_alt,
                label: 'Verificar Este Equipo',
                backgroundColor: Colors.blue[700]!,
                isElevated: true,
              ),
              SizedBox(height: 12),
              _buildActionButton(
                onPressed: _viewModel.isProcessing ? null : _viewModel.reportarEstado,
                icon: Icons.report,
                label: 'Reportar Estado',
                backgroundColor: Colors.orange[700]!,
                isElevated: true,
              ),
              SizedBox(height: 12),
              _buildActionButton(
                onPressed: _viewModel.isProcessing ? null : _viewModel.cambiarCliente,
                icon: Icons.swap_horiz,
                label: 'Cambiar Cliente',
                foregroundColor: Colors.purple[700]!,
                isElevated: false,
              ),
              SizedBox(height: 12),
              _buildActionButton(
                onPressed: _viewModel.isProcessing ? null : _viewModel.solicitarRetiroEquipo,
                icon: Icons.remove_circle,
                label: 'Retirar Equipo',
                foregroundColor: Colors.red[700]!,
                isElevated: false,
              ),
            ],
          );
        } else {
          return _buildInactiveEquipoCard();
        }
      },
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
    required bool isElevated,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isElevated
          ? ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
          : OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: foregroundColor!),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveEquipoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 40, color: Colors.red[600]),
          SizedBox(height: 8),
          Text(
            _viewModel.getInactiveEquipoTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            _viewModel.getInactiveEquipoSubtitle(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
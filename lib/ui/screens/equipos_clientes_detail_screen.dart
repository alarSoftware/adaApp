// ui/screens/equipos_clientes_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/models/equipos_cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/equipos_clientes_detail_screen_viewmodel.dart';
import 'dart:async';

class EquiposClientesDetailScreen extends StatefulWidget {
  final EquipoCliente equipoCliente;

  const EquiposClientesDetailScreen({
    super.key,
    required this.equipoCliente,
  });

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Detalle del Equipo',
          style: TextStyle(color: AppColors.onPrimary),
        ),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
          actions: [
            TextButton.icon(
              onPressed: _handleSave,
              icon: Icon(
                Icons.save,
                color: AppColors.onPrimary,
                size: 20,
              ),
              label: Text(
                'Guardar',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 8),
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
              _buildClienteInfo(),
              SizedBox(height: 32),
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

  Widget _buildClienteInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipo asignado a: ${widget.equipoCliente.clienteNombreCompleto}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipoInfo() {
    return Card(
      elevation: 3,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del equipo
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.kitchen,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _viewModel.getNombreCompletoEquipo(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _viewModel.equipoCliente.asignacionActiva
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _viewModel.equipoCliente.asignacionActiva
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _viewModel.getEstadoText(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _viewModel.equipoCliente.asignacionActiva
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Información del equipo en grid
            _buildInfoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final infoItems = <Map<String, String>>[];

    // Agregar campos solo si tienen datos
    if (_viewModel.shouldShowMarca()) {
      infoItems.add({
        'label': 'Marca',
        'value': _viewModel.getMarcaText(),
      });
    }

    if (_viewModel.shouldShowModelo()) {
      infoItems.add({
        'label': 'Modelo',
        'value': _viewModel.getModeloText(),
      });
    }

    if (_viewModel.shouldShowCodBarras()) {
      infoItems.add({
        'label': 'Código de Barras',
        'value': _viewModel.getCodBarrasText(),
      });
    }

    infoItems.addAll([
      {
        'label': 'Fecha de Asignación',
        'value': _viewModel.getFechaAsignacionText(),
      },
    ]);

    if (_viewModel.shouldShowFechaRetiro()) {
      infoItems.add({
        'label': 'Fecha de Retiro',
        'value': _viewModel.getFechaRetiroText(),
      });
    }

    return Column(
      children: [
        // Construir filas de 2 elementos cada una
        for (int i = 0; i < infoItems.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCompactInfoItem(
                      label: infoItems[i]['label']!,
                      value: infoItems[i]['value']!,
                    ),
                  ),
                  if (i + 1 < infoItems.length) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInfoItem(
                        label: infoItems[i + 1]['label']!,
                        value: infoItems[i + 1]['value']!,
                      ),
                    ),
                  ] else
                    Expanded(child: SizedBox()), // Espacio vacío si es impar
                ],
              ),
            ),
          )],
    );
  }

  Widget _buildCompactInfoItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
              // Control de ubicación del equipo
              _buildLocationControlCard(),
            ],
          );
        } else {
          return _buildInactiveEquipoCard();
        }
      },
    );
  }

  Widget _buildLocationControlCard() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final isEnLocal = _viewModel.isEquipoEnLocal;
        final statusColor = isEnLocal ? AppColors.success : AppColors.neutral500;

        return Card(
          elevation: 3,
          color: AppColors.surface,
          shadowColor: AppColors.shadowLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.08),
                  statusColor.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Título de la sección
            Row(
            children: [
            Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.store,
              color: statusColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ubicación del Equipo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ],
        ),

        SizedBox(height: 16),

        // Control switch
        Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
        color: statusColor.withValues(alpha: 0.2),
        ),
        ),
        child: Row(
        children: [
        Icon(
        isEnLocal ? Icons.store : Icons.location_off,
        color: statusColor,
        size: 24,
        ),
        SizedBox(width: 12),
        Expanded(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
        'El equipo está en el local',
        style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        ),
        ),
        SizedBox(height: 4),
        Text(
        isEnLocal
        ? 'Físicamente presente en nuestras instalaciones'
            : 'No se encuentra en el local actualmente',
        style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        ),
        ),
        ],
        ),
        ),
        SizedBox(width: 12),
        Transform.scale(
        scale: 1.2,
        child: Switch(
        value: isEnLocal,
        onChanged: _viewModel.toggleEquipoEnLocal,
        activeThumbColor: AppColors.success,
        inactiveThumbColor: AppColors.neutral400,
        inactiveTrackColor: AppColors.neutral300,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        ),
        ],
        ),
        ),
        ],
        ),
        ),
        );
      },
    );
  }

  Widget _buildInactiveEquipoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderError),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 40, color: AppColors.error),
          SizedBox(height: 8),
          Text(
            _viewModel.getInactiveEquipoTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _viewModel.getInactiveEquipoSubtitle(),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    _viewModel.saveAllChanges();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cambios guardados correctamente'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
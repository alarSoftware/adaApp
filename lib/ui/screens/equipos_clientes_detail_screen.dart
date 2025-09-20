import 'package:flutter/material.dart';
import 'package:ada_app/models/equipos_cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/equipos_clientes_detail_screen_viewmodel.dart';
import 'package:ada_app/repositories/estado_equipo_repository.dart';
import 'package:ada_app/services/database_helper.dart';
import 'dart:async';
import '../widgets/gps_navigation_widget.dart';
import 'package:flutter/services.dart';
import 'package:ada_app/repositories/equipo_repository.dart';

class EquiposClientesDetailScreen extends StatefulWidget {
  final dynamic equipoCliente;  // Cambiar de EquipoCliente a dynamic

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
    _checkDatabase();
    _viewModel = EquiposClienteDetailScreenViewModel(
      widget.equipoCliente,
      EstadoEquipoRepository(),
      EquipoRepository(), // Agregar esta línea
    );
    _setupEventListener();
  }

  void _checkDatabase() async {
    final db = DatabaseHelper();
    try {
      final tablas = await db.obtenerNombresTablas();
      print('Tablas disponibles: $tablas');

      if (tablas.contains('Estado_Equipo')) {
        final esquema = await db.obtenerEsquemaTabla('Estado_Equipo');
        print('Esquema Estado_Equipo: $esquema');
      } else {
        print('Tabla Estado_Equipo NO existe');
      }
    } catch (e) {
      print('Error verificando DB: $e');
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message),
            backgroundColor: _getMessageColor(event.type),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    });
  }

  Color _getMessageColor(MessageType type) {
    switch (type) {
      case MessageType.success:
        return AppColors.success;
      case MessageType.error:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
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
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              final canSave = _viewModel.saveButtonEnabled;
              final buttonText = _viewModel.saveButtonText;

              return TextButton.icon(
                onPressed: canSave ? _showSaveConfirmation : null,
                icon: Icon(
                  Icons.save,
                  color: canSave ? AppColors.onPrimary : AppColors.onPrimary.withValues(alpha: 0.5),
                  size: 20,
                ),
                label: Text(
                  buttonText,
                  style: TextStyle(
                    color: canSave ? AppColors.onPrimary : AppColors.onPrimary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
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
                  'Equipo asignado a: ${widget.equipoCliente['cliente_nombre'] ?? 'Cliente'}',
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
                        decoration: BoxDecoration(
                          color: _viewModel.equipoCliente['activo'] == 1
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _viewModel.equipoCliente['activo'] == 1
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _viewModel.getEstadoText(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _viewModel.equipoCliente['activo'] == 1
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
        border: Border.all(color: AppColors.border, width: 1),
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

              // SECCIÓN DEL HISTORIAL
              SizedBox(height: 20),
              _buildHistorialCard(),
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
        final estadoUbicacion = _viewModel.estadoUbicacionEquipo;
        final hasChanges = _viewModel.hasUnsavedChanges;

        Color statusColor = AppColors.neutral500;
        if (estadoUbicacion == true) {
          statusColor = AppColors.success;
        } else if (estadoUbicacion == false) {
          statusColor = AppColors.warning;
        }

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
            width: double.infinity, // Asegurar ancho completo
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título con overflow protection
                Row(
                  children: [
                    Icon(Icons.store, color: statusColor, size: 20),
                    SizedBox(width: 12),
                    Expanded( // Prevenir overflow del título
                      child: Text(
                        'Ubicación del Equipo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasChanges) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'CAMBIOS PENDIENTES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 16),

                // Dropdown con constraints apropiados
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: double.infinity,
                  ),
                  child: DropdownButtonFormField<bool?>(
                    value: estadoUbicacion,
                    isExpanded: true, // IMPORTANTE: Previene overflow
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    hint: Row(
                      mainAxisSize: MainAxisSize.min, // Evitar expansion innecesaria
                      children: [
                        Icon(Icons.help_outline, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Flexible( // Permitir que el texto se ajuste
                          child: Text(
                            'Seleccione la ubicación del equipo',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    items: [
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store, color: AppColors.success, size: 20),
                            SizedBox(width: 12),
                            Flexible( // Prevenir overflow del texto
                              child: Text(
                                'En el local',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, color: AppColors.warning, size: 20),
                            SizedBox(width: 12),
                            Flexible( // Prevenir overflow del texto
                              child: Text(
                                'Fuera del local',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) => _viewModel.cambiarUbicacionEquipo(value),
                    validator: (value) => value == null ? 'Seleccione una opción' : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NUEVA SECCIÓN DEL HISTORIAL
  Widget _buildHistorialCard() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final historial = _viewModel.historialUltimos5;
        final totalCambios = _viewModel.totalCambios;

        return Card(
          elevation: 3,
          color: AppColors.surface,
          shadowColor: AppColors.shadowLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
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
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del historial
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de Cambios',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (totalCambios > 0)
                            Text(
                              '${totalCambios} cambio${totalCambios == 1 ? '' : 's'} en total',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (historial.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Últimos ${historial.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 16),

                // Lista del historial
                if (historial.isEmpty)
                  _buildEmptyHistorial()
                else
                  _buildHistorialList(historial),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistorial() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.neutral100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neutral300,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 40,
              color: AppColors.neutral400,
            ),
            SizedBox(height: 8),
            Text(
              'Sin cambios registrados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Los cambios de ubicación aparecerán aquí',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorialList(List<dynamic> historial) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: historial.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.border,
        ),
        itemBuilder: (context, index) {
          final cambio = historial[index];
          final isFirst = index == 0;

          return _buildHistorialItem(cambio, isFirst);
        },
      ),
    );
  }
  Widget _buildHistorialItem(dynamic cambio, bool isFirst) {
    final enLocal = cambio.enLocal;
    final fecha = cambio.fechaRevision;
    final statusColor = enLocal ? AppColors.success : AppColors.neutral500;
    final statusIcon = enLocal ? Icons.store : Icons.location_off;
    final statusText = enLocal ? 'EN LOCAL' : 'FUERA DEL LOCAL';

    // Información de ubicación GPS
    final tieneUbicacion = cambio.latitud != null && cambio.longitud != null;
    final latitud = cambio.latitud;
    final longitud = cambio.longitud;

    return GestureDetector(
      onTap: tieneUbicacion ? () => GPSNavigationWidget.abrirUbicacionEnMapa(context, latitud!, longitud!) : null,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFirst
              ? statusColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Indicador visual
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: isFirst
                    ? Border.all(color: statusColor, width: 2)
                    : null,
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),

            SizedBox(width: 12),

            // Información del cambio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFirst) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ACTUAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _viewModel.formatearFechaHistorial(fecha),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Indicador de ubicación clickeable
                  if (tieneUbicacion) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Toca para ver ubicación',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Indicadores en columna
            Column(
              children: [
                // Indicador de sincronización
                if (!cambio.estaSincronizado)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                // Indicador GPS mejorado
                if (tieneUbicacion) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.gps_fixed,
                      size: 12,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),

            // Flecha indicando que es clickeable
            if (tieneUbicacion) ...[
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
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

  void _showSaveConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar guardado'),
        content: Text('¿Estás seguro de que quieres guardar los cambios realizados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _viewModel.saveAllChanges();
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
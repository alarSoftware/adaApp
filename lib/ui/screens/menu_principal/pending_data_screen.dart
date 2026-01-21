import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';
import 'package:ada_app/ui/screens/pantallaPendientesMigrado/censos_pendientes_detail_screen.dart';
import 'package:ada_app/ui/screens/pantallaPendientesMigrado/operaciones_pendientes_detail_screen.dart';
import 'package:ada_app/ui/theme/colors.dart';

class PendingDataScreen extends StatefulWidget {
  static const String routeName = '/pending-data';

  const PendingDataScreen({super.key});

  @override
  State<PendingDataScreen> createState() => _PendingDataScreenState();
}

class _PendingDataScreenState extends State<PendingDataScreen> {
  late PendingDataViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PendingDataViewModel();
    _listenToEvents();
  }

  void _listenToEvents() {
    _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      switch (event) {
        case ShowErrorEvent errorEvent:
          _showErrorSnackBar(errorEvent.message);
          break;

        case ShowSuccessEvent successEvent:
          _showSuccessSnackBar(successEvent.message);
          break;

        case RequestBulkSendConfirmationEvent confirmEvent:
          _showBulkSendConfirmation(
            confirmEvent.groups,
            confirmEvent.totalItems,
          );
          break;

        case SendProgressEvent _:
          // El progreso se maneja automáticamente via notifyListeners
          break;
      }
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Datos Pendientes',
            style: TextStyle(color: AppColors.onPrimary),
          ),
          elevation: 0,
          backgroundColor: AppColors.appBarBackground,
          foregroundColor:
              AppColors.appBarForeground, // This handles icon colors
          actions: [
            Consumer<PendingDataViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading || viewModel.isSending) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.onPrimary,
                        ),
                      ),
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: viewModel.refresh,
                  tooltip: 'Actualizar',
                );
              },
            ),
          ],
        ),
        body: Consumer<PendingDataViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                _buildHeader(viewModel),
                if (viewModel.isSending) _buildSendingProgress(viewModel),
                Expanded(child: _buildContent(viewModel)),
                if (viewModel.hasPendingData) _buildActionButtons(viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(PendingDataViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                viewModel.hasPendingData
                    ? Icons.pending_actions
                    : Icons.check_circle,
                color: viewModel.hasPendingData
                    ? AppColors.warning
                    : AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.hasPendingData
                          ? '${viewModel.totalPendingItems} elementos pendientes'
                          : 'Todos los datos están sincronizados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (viewModel.lastUpdateTime.isNotEmpty)
                      Text(
                        'Última actualización: ${_formatTime(viewModel.lastUpdateTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendingProgress(PendingDataViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.sendCurrentStep,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${viewModel.sendCompletedCount} de ${viewModel.sendTotalCount} completados',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(viewModel.sendProgress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: viewModel.sendProgress,
            backgroundColor: AppColors.neutral300,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildContent(PendingDataViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Cargando datos pendientes...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (!viewModel.hasPendingData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.successLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Todo sincronizado',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay datos pendientes de envío',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: viewModel.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Nuevamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: viewModel.pendingGroups.length,
        itemBuilder: (context, index) {
          final group = viewModel.pendingGroups[index];
          return _buildPendingDataCard(group);
        },
      ),
    );
  }

  Widget _buildPendingDataCard(PendingDataGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (group.type == PendingDataType.census) {
            _navigateToCensosDetail(group);
          } else if (group.type == PendingDataType.operations) {
            _navigateToOperacionesDetail(group);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(group.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${group.count}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  if (group.type == PendingDataType.census ||
                      group.type == PendingDataType.operations) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Agregar este método al final de la clase _PendingDataScreenState
  void _navigateToCensosDetail(PendingDataGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CensosPendientesDetailScreen(viewModel: _viewModel, group: group),
      ),
    ).then((_) {
      // Recargar cuando regrese de la pantalla de detalle
      _viewModel.refresh();
    });
  }

  void _navigateToOperacionesDetail(PendingDataGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperacionesPendientesDetailScreen(
          viewModel: _viewModel,
          group: group,
        ),
      ),
    ).then((_) {
      // Recargar cuando regrese de la pantalla de detalle
      _viewModel.refresh();
    });
  }

  Widget _buildTypeIcon(PendingDataType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case PendingDataType.forms:
        iconData = Icons.assignment;
        color = AppColors.secondary;
        break;
      case PendingDataType.census:
        iconData = Icons.inventory;
        color = AppColors.success;
        break;
      case PendingDataType.images:
        iconData = Icons.photo_library;
        color = Color(
          0xFFE91E63,
        ); // Pink not in AppColors yet, keeping custom or mapping to closest
        break;
      case PendingDataType.logs:
        iconData = Icons.description;
        color = AppColors.warning;
        break;
      case PendingDataType.operations:
        iconData = Icons.business_center;
        color = Color(0xFF9C27B0); // Purple not in AppColors yet
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildActionButtons(PendingDataViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!viewModel.isConnected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderError),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión a Internet. Verifique su conectividad.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Add buttons here if needed, currently dynamic buttons seem missing or managed elsewhere?
            // Checking original code, action buttons logic was suspiciously empty except connectivity warning.
            // If bulk send button is intended, it should be here.
            // Assuming original logic was correct and buttons are added dynamically or missing in snippet.
            // Ah, I see "viewModel.hasPendingData" condition for building this section.
            // But inside, only the warning is shown. Check ViewFile output again.
            // Lines 483-528 of original: Just checks !viewModel.isConnected.
            // There seems to be NO "Send All" button in the original snippet provided!
            // Wait, looking closely at snippet Step 901...
            // It ends at line 677. Review lines 498-500.
            // It seems incomplete or the buttons are missing in the original file too?
            // "if (!viewModel.isConnected) ...["
            // Maybe it was truncated or logic is elsewhere?
            // Let's preserve what was there and style it.
          ],
        ),
      ),
    );
  }

  // ========== DIÁLOGOS ==========

  void _showBulkSendConfirmation(
    List<PendingDataGroup> groups,
    int totalItems,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.cloud_upload, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Confirmar Envío',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se enviarán $totalItems elementos en ${groups.length} categorías:',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: groups
                    .map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            _buildTypeIcon(group.type),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${group.count}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este proceso puede tardar varios minutos dependiendo de la cantidad de datos.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          /*
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // _viewModel.executeBulkSend(); // Deshabilitado temporalmente
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text('Enviar Todo'),
          ),
          */
          ElevatedButton(
            onPressed: null, // Deshabilitado
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neutral300,
              foregroundColor: AppColors.textDisabled,
            ),
            child: Text('Envío Temporalmente Desactivado'),
          ),
        ],
      ),
    );
  }

  // ========== HELPERS ==========

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.snackbarError,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.snackbarSuccess,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(String timeString) {
    try {
      final dateTime = DateTime.parse(timeString);
      return DateFormat('dd/MM HH:mm').format(dateTime);
    } catch (e) {
      return timeString;
    }
  }
}

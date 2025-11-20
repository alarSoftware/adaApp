import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/viewmodels/pending_data_viewmodel.dart';

class PendingDataScreen extends StatefulWidget {
  static const String routeName = '/pending-data';

  const PendingDataScreen({Key? key}) : super(key: key);

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

      switch (event.runtimeType) {
        case ShowErrorEvent _:
          final errorEvent = event as ShowErrorEvent;
          _showErrorSnackBar(errorEvent.message);
          break;

        case ShowSuccessEvent _:
          final successEvent = event as ShowSuccessEvent;
          _showSuccessSnackBar(successEvent.message);
          break;

        case RequestBulkSendConfirmationEvent:
          final confirmEvent = event as RequestBulkSendConfirmationEvent;
          _showBulkSendConfirmation(confirmEvent.groups, confirmEvent.totalItems);
          break;

        case SendProgressEvent:
        // El progreso se maneja automáticamente via notifyListeners
          break;

        case SendCompletedEvent:
          final completedEvent = event as SendCompletedEvent;
          _showSendCompletedDialog(completedEvent.result);
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
        appBar: AppBar(
          title: const Text('Datos Pendientes'),
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // 🆕 Indicador de auto-sync
            Consumer<PendingDataViewModel>(
              builder: (context, viewModel, child) {
                return IconButton(
                  icon: Icon(
                    viewModel.autoSyncEnabled
                        ? Icons.sync
                        : Icons.sync_disabled,
                  ),
                  onPressed: viewModel.toggleAutoSync,
                  tooltip: viewModel.autoSyncEnabled
                      ? 'Auto-sync activado (cada ${viewModel.autoSyncInterval.inMinutes} min)'
                      : 'Auto-sync desactivado - Toca para activar',
                );
              },
            ),
            Consumer<PendingDataViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading || viewModel.isSending) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
                // 🆕 Barra de estado de auto-sync
                if (viewModel.autoSyncEnabled)
                  _buildAutoSyncBanner(viewModel),
                if (viewModel.isSending) _buildSendingProgress(viewModel),
                Expanded(
                  child: _buildContent(viewModel),
                ),
                if (viewModel.hasPendingData) _buildActionButtons(viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🆕 Banner de auto-sync
  Widget _buildAutoSyncBanner(PendingDataViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync,
            size: 16,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sincronización automática activa (cada ${viewModel.autoSyncInterval.inMinutes} min)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PendingDataViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                viewModel.hasPendingData ? Icons.pending_actions : Icons.check_circle,
                color: viewModel.hasPendingData ? Colors.orange : Colors.green,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (viewModel.lastUpdateTime.isNotEmpty)
                      Text(
                        'Última actualización: ${_formatTime(viewModel.lastUpdateTime)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
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
        color: Colors.blue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${viewModel.sendCompletedCount} de ${viewModel.sendTotalCount} completados',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(viewModel.sendProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: viewModel.sendProgress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelConfirmation(),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Cancelar Envío'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PendingDataViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando datos pendientes...'),
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
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Todo sincronizado',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay datos pendientes de envío',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: viewModel.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Nuevamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[100],
                foregroundColor: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${group.count}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(PendingDataType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case PendingDataType.forms:
        iconData = Icons.assignment;
        color = Colors.blue;
        break;
      case PendingDataType.census:
        iconData = Icons.inventory;
        color = Colors.green;
        break;
        iconData = Icons.devices;
        color = Colors.purple;
        break;
      case PendingDataType.images:
        iconData = Icons.photo_library;
        color = Colors.pink;
        break;
      case PendingDataType.logs:
        iconData = Icons.description;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildActionButtons(PendingDataViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión a Internet. Verifique su conectividad.',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: viewModel.isSending || !viewModel.isConnected
                    ? null
                    : viewModel.requestBulkSend,
                icon: viewModel.isSending
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.cloud_upload),
                label: Text(viewModel.isSending
                    ? 'Enviando...'
                    : 'Enviar Todo (${viewModel.totalPendingItems})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isSending || !viewModel.isConnected
                      ? Colors.grey
                      : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== DIÁLOGOS ==========

  void _showBulkSendConfirmation(List<PendingDataGroup> groups, int totalItems) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_upload, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Confirmar Envío'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se enviarán $totalItems elementos en ${groups.length} categorías:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: groups.map((group) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      _buildTypeIcon(group.type),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.displayName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${group.count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este proceso puede tardar varios minutos dependiendo de la cantidad de datos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _viewModel.executeBulkSend();
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Cancelar Envío'),
          ],
        ),
        content: const Text(
          '¿Está seguro que desea cancelar el envío?\n\nLos datos ya enviados se mantendrán, pero el proceso se detendrá.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar Enviando'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _viewModel.cancelSend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar Envío'),
          ),
        ],
      ),
    );
  }

  void _showSendCompletedDialog(BulkSendResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.allSuccess ? Icons.check_circle : Icons.warning,
              color: result.allSuccess ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(result.allSuccess ? 'Envío Completado' : 'Envío Parcial'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result.allSuccess
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.summary,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (!result.allSuccess && result.results.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Detalles por categoría:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...result.results.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        r.success ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: r.success ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.message,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (r.error != null)
                              Text(
                                'Error: ${r.error}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          if (!result.allSuccess)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _viewModel.refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar Pendientes'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: result.allSuccess ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
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
        backgroundColor: Colors.red,
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
        backgroundColor: Colors.green,
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
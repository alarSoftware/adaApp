import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/data/database_validation_service.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/common/snackbar_helper.dart';

class SyncDialog {
  static Future<void> show({
    required BuildContext context,
    required LoginScreenViewModel viewModel,
    required SyncValidationResult validation,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) =>
          _SyncDialogContent(viewModel: viewModel, validation: validation),
    );
  }
}

class _SyncDialogContent extends StatefulWidget {
  final LoginScreenViewModel viewModel;
  final SyncValidationResult validation;

  const _SyncDialogContent({required this.viewModel, required this.validation});

  @override
  State<_SyncDialogContent> createState() => _SyncDialogContentState();
}

class _SyncDialogContentState extends State<_SyncDialogContent> {
  bool _isSyncing = false;
  double _progress = 0.0;
  String _currentStep = '';
  List<String> _completedSteps = [];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSyncing,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            Icon(Icons.sync_problem, color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sincronización Requerida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReasonContainer(),
              const SizedBox(height: 12),
              _buildVendorInfo(),
              const SizedBox(height: 12),
              _buildWarningContainer(),
              if (_isSyncing) ...[
                const SizedBox(height: 16),
                _buildSyncProgress(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSyncing ? null : () => _cancelSync(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: _isSyncing
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _startSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSyncing
                  ? AppColors.buttonDisabled
                  : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            icon: _isSyncing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync, size: 20),
            label: Text(
              _isSyncing ? 'Sincronizando...' : 'Sincronizar',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonContainer() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.validation.razon,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.validation.vendedorAnteriorId != null) ...[
          // Muestra nombre anterior o 'Desconocido'
          _buildInfoRow(
            'Anterior:',
            widget.validation.vendedorAnteriorNombre ?? 'Desconocido',
          ),
          const SizedBox(height: 6),
        ],
        // Muestra nombre actual
        _buildInfoRow('Actual:', widget.validation.vendedorActualNombre),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningContainer() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Debe sincronizar antes de continuar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncProgress() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          _currentStep,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (_completedSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  void _cancelSync(BuildContext context) {
    Navigator.of(context).pop();
    widget.viewModel.usernameController.clear();
    widget.viewModel.passwordController.clear();
  }

  Future<void> _startSync() async {
    try {
      final db = await DatabaseHelper().database;
      final validationService = DatabaseValidationService(db);
      final validationResult = await validationService.canDeleteDatabase();

      if (!validationResult.canDelete) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => _buildPendingRecordsDialog(validationResult),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Error validando datos: $e');
      return;
    }

    setState(() {
      _isSyncing = true;
      _progress = 0.0;
      _currentStep = 'Iniciando sincronización...';
      _completedSteps.clear();
    });

    try {
      // ✅ AQUÍ USAMOS LOS ID PARA LA LÓGICA DE SINCRONIZACIÓN (LA API PIDE IDs)
      final result = await FullSyncService.syncAllDataWithProgress(
        edfVendedorId: widget.validation.vendedorActualId, // Usamos ID
        previousVendedorId: widget.validation.vendedorAnteriorId, // Usamos ID
        onProgress:
            ({
              required double progress,
              required String currentStep,
              required List<String> completedSteps,
            }) {
              if (mounted) {
                setState(() {
                  _progress = progress;
                  _currentStep = currentStep;
                  _completedSteps = List.from(completedSteps);
                });
              }
            },
      );

      if (!result.exito) {
        throw Exception(result.mensaje);
      }

      // ✅ AQUÍ ESTÁ LA CORRECCIÓN CLAVE PARA EL ERROR DE "MARK SYNC"
      final authService = AuthService();
      await authService.markSyncCompleted(
        widget.validation.vendedorActualId, // ID
        widget
            .validation
            .vendedorActualNombre, // NOMBRE (Nuevo parámetro requerido)
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      SnackbarHelper.showSuccess(
        context,
        'Sincronización completada exitosamente',
        Icons.cloud_done,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _currentStep = '';
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      SnackbarHelper.showError(context, 'Error en sincronización: $e');
    }
  }

  // ... (El resto de los widgets _buildPendingRecordsDialog, _getIconForTable, etc. quedan igual)
  Widget _buildPendingRecordsDialog(DatabaseValidationResult validationResult) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Registros Pendientes', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hay registros que aún no han sido sincronizados con el servidor:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...validationResult.pendingItems.map(
              (item) => _buildPendingItem(
                _getIconForTable(item.tableName),
                item.displayName,
                item.count,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sincronice estos registros antes de continuar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  IconData _getIconForTable(String tableName) {
    if (tableName.contains('equipo')) return Icons.devices;
    if (tableName.contains('censo')) return Icons.assignment;
    if (tableName.contains('form') || tableName.contains('response')) {
      return Icons.description;
    }
    if (tableName.contains('foto') || tableName.contains('image')) {
      return Icons.photo;
    }
    if (tableName.contains('log')) return Icons.article;
    return Icons.info_outline;
  }

  Widget _buildPendingItem(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

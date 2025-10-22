import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/login/sync_progress_widget.dart';
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
      builder: (BuildContext dialogContext) => _SyncDialogContent(
        viewModel: viewModel,
        validation: validation,
      ),
    );
  }
}

class _SyncDialogContent extends StatefulWidget {
  final LoginScreenViewModel viewModel;
  final SyncValidationResult validation;

  const _SyncDialogContent({
    required this.viewModel,
    required this.validation,
  });

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
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            Icon(Icons.sync_problem, color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sincronización Obligatoria',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 16),
              _buildImportantInfo(),
              if (_isSyncing) ...[
                const SizedBox(height: 16),
                SyncProgressWidget(
                  progress: _progress,
                  currentStep: _currentStep,
                  completedSteps: _completedSteps,
                ),
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
                color: _isSyncing ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isSyncing ? null : _startSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSyncing ? AppColors.buttonDisabled : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: _isSyncing
                ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text('Sincronizar Ahora'),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.validation.razon,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'Importante',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Debes sincronizar para continuar. Esto descargará:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('Usuarios actualizados'),
          _buildBulletPoint('Clientes de tu zona'),
          _buildBulletPoint('Equipos y datos maestros'),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelSync(BuildContext context) {
    Navigator.of(context).pop();
    widget.viewModel.usernameController.clear();
    widget.viewModel.passwordController.clear();
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _progress = 0.0;
      _currentStep = 'Iniciando sincronización...';
      _completedSteps.clear();
    });

    try {
      // ✅ USAR SERVICIO CENTRALIZADO
      final result = await FullSyncService.syncAllDataWithProgress(
        edfVendedorId: widget.validation.vendedorActual,
        previousVendedorId: widget.validation.vendedorAnterior,
        onProgress: ({
          required double progress,
          required String currentStep,
          required List<String> completedSteps,
        }) {
          setState(() {
            _progress = progress;
            _currentStep = currentStep;
            _completedSteps = List.from(completedSteps);
          });
        },
      );

      if (!result.exito) {
        throw Exception(result.mensaje);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      SnackbarHelper.showSuccess(
        context,
        'Sincronización completada exitosamente',
        Icons.cloud_done,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).pushReplacementNamed('/home');

    } catch (e) {
      setState(() {
        _isSyncing = false;
        _currentStep = '';
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      SnackbarHelper.showError(context, 'Error en sincronización: $e');
    }
  }
}
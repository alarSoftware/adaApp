import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/sync_service.dart';
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
      // 1. Limpiar datos anteriores si es cambio de vendedor
      if (widget.validation.vendedorAnterior != null) {
        setState(() {
          _currentStep = 'Limpiando datos anteriores...';
          _progress = 0.05;
        });

        final authService = AuthService();
        await authService.clearSyncData();

        setState(() {
          _completedSteps.add('Datos anteriores limpiados');
        });
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 2. Sincronizar usuarios (10%)
      setState(() {
        _currentStep = 'Sincronizando usuarios...';
        _progress = 0.1;
      });

      final userSyncResult = await widget.viewModel.syncUsers();
      if (!userSyncResult.exito) {
        throw Exception('Error sincronizando usuarios: ${userSyncResult.mensaje}');
      }

      setState(() {
        _completedSteps.add('${userSyncResult.itemsSincronizados} usuarios');
        _progress = 0.15;
      });
      await Future.delayed(const Duration(milliseconds: 200));

      // 3. Sincronizar clientes (25%)
      setState(() {
        _currentStep = 'Descargando clientes...';
        _progress = 0.2;
      });

      // Llamar al método completo pero mostrar progreso incremental
      final syncService = await _sincronizarConProgreso();

      if (!syncService.exito) {
        throw Exception('Error en sincronización: ${syncService.mensaje}');
      }

      // 4. Marcar sincronización como completada (95%)
      setState(() {
        _currentStep = 'Finalizando...';
        _progress = 0.95;
      });

      await widget.viewModel.markSyncCompleted(widget.validation.vendedorActual);

      setState(() {
        _completedSteps.add('Sincronización registrada');
      });

      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Completado (100%)
      setState(() {
        _progress = 1.0;
        _currentStep = '¡Completado!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.of(context).pop();

      final parentContext = context;
      SnackbarHelper.showSuccess(
        parentContext,
        'Sincronización completada exitosamente',
        Icons.cloud_done,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(parentContext).pushReplacementNamed('/home');
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

  // Método auxiliar que sincroniza TODO y actualiza el progreso
  Future<SyncResultUnificado> _sincronizarConProgreso() async {
    // Clientes (20% -> 35%)
    setState(() {
      _currentStep = 'Descargando clientes...';
      _progress = 0.25;
    });

    final syncResult = await SyncService.sincronizarTodosLosDatos();

    // Simular progreso mientras se descargan los datos
    if (syncResult.clientesSincronizados > 0) {
      setState(() {
        _completedSteps.add('${syncResult.clientesSincronizados} clientes');
        _progress = 0.35;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Equipos (35% -> 50%)
    if (syncResult.equiposSincronizados > 0) {
      setState(() {
        _currentStep = 'Descargando equipos...';
        _completedSteps.add('${syncResult.equiposSincronizados} equipos');
        _progress = 0.5;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Censos (50% -> 65%)
    if (syncResult.censosSincronizados > 0) {
      setState(() {
        _currentStep = 'Descargando censos activos...';
        _completedSteps.add('${syncResult.censosSincronizados} censos');
        _progress = 0.65;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Equipos Pendientes (65% -> 75%)
    if (syncResult.equiposPendientesSincronizados > 0) {
      setState(() {
        _currentStep = 'Descargando equipos pendientes...';
        _completedSteps.add('${syncResult.equiposPendientesSincronizados} equipos pendientes');
        _progress = 0.75;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Formularios (75% -> 85%)
    if (syncResult.formulariosSincronizados > 0) {
      setState(() {
        _currentStep = 'Descargando formularios...';
        _completedSteps.add('${syncResult.formulariosSincronizados} formularios');
        _progress = 0.85;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Detalles de formularios (85% -> 90%)
    if (syncResult.detallesFormulariosSincronizados > 0) {
      setState(() {
        _currentStep = 'Descargando detalles de formularios...';
        _completedSteps.add('${syncResult.detallesFormulariosSincronizados} detalles');
        _progress = 0.9;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return syncResult;
  }

  Future<void> _cleanPreviousData() async {
    setState(() {
      _currentStep = 'Limpiando datos anteriores...';
      _progress = 0.1;
    });

    final authService = AuthService();
    await authService.clearSyncData();

    setState(() {
      _completedSteps.add('Datos anteriores limpiados');
    });

    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _syncUsers() async {
    setState(() {
      _currentStep = 'Sincronizando usuarios...';
      _progress = 0.3;
    });

    final userSyncResult = await widget.viewModel.syncUsers();

    if (!userSyncResult.exito) {
      throw Exception('Error sincronizando usuarios: ${userSyncResult.mensaje}');
    }

    setState(() {
      _completedSteps.add('${userSyncResult.itemsSincronizados} usuarios');
    });

    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _syncClients() async {
    setState(() {
      _currentStep = 'Sincronizando tus clientes...';
      _progress = 0.6;
    });

    final clientSyncResult = await widget.viewModel.syncClientsForVendor(
      widget.validation.vendedorActual,
    );

    if (!clientSyncResult.exito) {
      throw Exception('Error sincronizando clientes: ${clientSyncResult.mensaje}');
    }

    setState(() {
      _completedSteps.add('${clientSyncResult.itemsSincronizados} clientes');
    });
  }

  Future<void> _finishSync() async {
    setState(() {
      _progress = 0.9;
      _currentStep = 'Finalizando...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _progress = 1.0;
      _currentStep = '¡Completado!';
      _completedSteps.add('Sincronización registrada');
    });

    await Future.delayed(const Duration(milliseconds: 500));
  }
}
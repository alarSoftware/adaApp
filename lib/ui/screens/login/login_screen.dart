import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/login/login_header.dart';
import 'package:ada_app/ui/widgets/login/login_form.dart';
import 'package:ada_app/ui/widgets/login/biometric_button.dart';
import 'package:ada_app/ui/widgets/login/login_appbar.dart';
import 'package:ada_app/ui/widgets/login/delete_users_dialog.dart';
import 'package:ada_app/ui/widgets/login/sync_dialog.dart';
import 'package:ada_app/ui/common/snackbar_helper.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginScreenViewModel(),
      child: const _LoginScreenContent(),
    );
  }
}

class _LoginScreenContent extends StatefulWidget {
  const _LoginScreenContent();

  @override
  State<_LoginScreenContent> createState() => _LoginScreenContentState();
}

class _LoginScreenContentState extends State<_LoginScreenContent>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  StreamSubscription? _eventSubscription;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupEventListener();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupEventListener() {
    final viewModel = context.read<LoginScreenViewModel>();

    _eventSubscription?.cancel();
    _eventSubscription = viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowErrorEvent) {
        _handleShowError(event.message);
      } else if (event is ShowSuccessEvent) {
        _handleShowSuccess(event.message, event.icon);
      } else if (event is NavigateToHomeEvent) {
        _handleNavigateToHome();
      } else if (event is ShowSyncRequiredDialogEvent) {
        _handleShowSyncRequiredDialog(event);
      } else if (event is ShowPendingRecordsDialogEvent) {
        _handleShowPendingRecordsDialog(event);
      } else if (event is SyncProgressEvent) {
        _handleSyncProgress(event);
      } else if (event is SyncCompletedEvent) {
        _handleSyncCompleted(event);
      }
    });
  }

  // ========== MANEJADORES DE EVENTOS ==========

  void _handleShowError(String message) {
    SnackbarHelper.showError(context, message);
  }

  void _handleShowSuccess(String message, IconData? icon) {
    SnackbarHelper.showSuccess(context, message, icon ?? Icons.check);
  }

  void _handleNavigateToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _handleShowSyncRequiredDialog(ShowSyncRequiredDialogEvent event) {
    final viewModel = context.read<LoginScreenViewModel>();

    SyncDialog.show(
      context: context,
      viewModel: viewModel,
      validation: event.validation,
    );
  }

  void _handleShowPendingRecordsDialog(ShowPendingRecordsDialogEvent event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _buildPendingRecordsDialog(event.validationResult),
    );
  }

  void _handleSyncProgress(SyncProgressEvent event) {
    // El progreso ya se está mostrando en el diálogo de sincronización
    // Este método está disponible por si necesitas hacer algo adicional
  }

  void _handleSyncCompleted(SyncCompletedEvent event) {
    // El evento de completado se maneja en el ViewModel
    // Este método está disponible por si necesitas hacer algo adicional en la UI
  }

  // ========== ACCIONES DE UI ==========

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<LoginScreenViewModel>();
    await viewModel.handleLogin();
  }

  Future<void> _handleBiometricLogin() async {
    final viewModel = context.read<LoginScreenViewModel>();
    await viewModel.authenticateWithBiometric();
  }

  Future<void> _handleSync() async {
    final viewModel = context.read<LoginScreenViewModel>();
    await viewModel.syncUsers();
  }

  Future<void> _handleDeleteUsers() async {
    final confirmed = await DeleteUsersDialog.show(context);
    if (confirmed == true && mounted) {
      final viewModel = context.read<LoginScreenViewModel>();
      await viewModel.deleteUsersTable();
    }
  }

  // ========== DIÁLOGOS ==========

  Widget _buildPendingRecordsDialog(dynamic validationResult) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: AppColors.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Registros Pendientes',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hay registros que aún no han sido sincronizados con el servidor:',
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          if (validationResult.pendingEquipments > 0)
            _buildPendingItem(
              Icons.devices,
              'Equipos pendientes',
              validationResult.pendingEquipments,
            ),
          if (validationResult.pendingCensus > 0)
            _buildPendingItem(
              Icons.assignment,
              'Censos pendientes',
              validationResult.pendingCensus,
            ),
          if (validationResult.pendingForms > 0)
            _buildPendingItem(
              Icons.description,
              'Formularios pendientes',
              validationResult.pendingForms,
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronice estos registros antes de continuar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
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
          onPressed: () {
            Navigator.of(context).pop();
            final viewModel = Provider.of<LoginScreenViewModel>(
              context,
              listen: false,
            );
            viewModel.uploadPendingData();
          },
          child: Text(
            'Intentar Enviar Pendientes',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Entendido',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingItem(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: LoginAppBar(
        onSync: _handleSync,
        onDeleteUsers: _handleDeleteUsers,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<LoginScreenViewModel>(
                  builder: (context, viewModel, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        GestureDetector(
                          onLongPress: () {
                            if (!kReleaseMode) {
                              viewModel.performDebugAdminLogin();
                            }
                          },
                          child: const LoginHeader(),
                        ),
                        const SizedBox(height: 48),
                        LoginForm(
                          formKey: _formKey,
                          viewModel: viewModel,
                          onSubmit: _handleLogin,
                        ),
                        if (viewModel.biometricAvailable) ...[
                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 24),
                          BiometricButton(onPressed: _handleBiometricLogin),
                        ],
                        const SizedBox(height: 40),
                        // _buildFooter(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }

  // Widget _buildFooter() {
  //   return Column(
  //     children: [
  //       Text(
  //         '© 2025 Alarsoftware. Todos los derechos reservados.',
  //         style: TextStyle(
  //           color: AppColors.textSecondary,
  //           fontSize: 12,
  //           fontWeight: FontWeight.w400,
  //         ),
  //         textAlign: TextAlign.center,
  //       ),
  //     ],
  //   );
  // }
}

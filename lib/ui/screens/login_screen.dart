import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/login/login_header.dart';
import 'package:ada_app/ui/widgets/login/login_form.dart';
import 'package:ada_app/ui/widgets/login/biometric_button.dart';
import 'package:ada_app/ui/widgets/login/login_appbar.dart';
import 'package:ada_app/ui/widgets/login/sync_dialog.dart';
import 'package:ada_app/ui/widgets/login/delete_users_dialog.dart';
import 'package:ada_app/ui/common/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _handleLogin(LoginScreenViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await viewModel.handleLogin();

    if (mounted) {
      if (result.success) {
        if (result.requiresSync && result.syncValidation != null) {
          await SyncDialog.show(
            context: context,
            viewModel: viewModel,
            validation: result.syncValidation!,
          );
        } else {
          SnackbarHelper.showSuccess(
            context,
            result.message,
            result.icon ?? Icons.check,
          );
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  Future<void> _handleBiometricLogin(LoginScreenViewModel viewModel) async {
    final result = await viewModel.authenticateWithBiometric();

    if (mounted) {
      if (result.success) {
        if (result.requiresSync && result.syncValidation != null) {
          await SyncDialog.show(
            context: context,
            viewModel: viewModel,
            validation: result.syncValidation!,
          );
        } else {
          SnackbarHelper.showSuccess(
            context,
            result.message,
            result.icon ?? Icons.check,
          );
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        SnackbarHelper.showError(context, result.message);
      }
    }
  }

  Future<void> _handleSync(LoginScreenViewModel viewModel) async {
    try {
      final resultado = await viewModel.syncUsers();

      if (mounted) {
        if (resultado.exito) {
          SnackbarHelper.showSuccess(
            context,
            '${resultado.itemsSincronizados} usuarios sincronizados',
            Icons.cloud_done,
          );
        } else {
          SnackbarHelper.showError(context, resultado.mensaje);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error al sincronizar usuarios: $e');
      }
    }
  }

  Future<void> _handleDeleteUsers() async {
    final confirmed = await DeleteUsersDialog.show(context);
    if (confirmed == true && mounted) {
      await _deleteUsersTable();
    }
  }

  Future<void> _deleteUsersTable() async {
    try {
      final viewModel = context.read<LoginScreenViewModel>();
      final result = await viewModel.deleteUsersTable();

      if (mounted) {
        if (result.exito) {
          SnackbarHelper.showSuccess(
            context,
            result.mensaje,
            Icons.delete_sweep,
          );
        } else {
          SnackbarHelper.showError(context, result.mensaje);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error al eliminar usuarios: $e');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginScreenViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: LoginAppBar(
          onSync: (viewModel) => _handleSync(viewModel),
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
                          const LoginHeader(),
                          const SizedBox(height: 48),
                          LoginForm(
                            formKey: _formKey,
                            viewModel: viewModel,
                            onSubmit: () => _handleLogin(viewModel),
                          ),
                          if (viewModel.biometricAvailable) ...[
                            const SizedBox(height: 24),
                            _buildDivider(),
                            const SizedBox(height: 24),
                            BiometricButton(
                              onPressed: () => _handleBiometricLogin(viewModel),
                            ),
                          ],
                          const SizedBox(height: 40),
                          _buildFooter(),
                        ],
                      );
                    },
                  ),
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

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '© 2025 Alarsoftware. Todos los derechos reservados.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
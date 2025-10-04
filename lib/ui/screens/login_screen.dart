import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/database_helper.dart';

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

  Future<void> _syncUsers(LoginScreenViewModel viewModel) async {
    try {
      final resultado = await viewModel.syncUsers();

      if (mounted) {
        if (resultado.exito) {
          _showSuccessSnackBar(
            '${resultado.itemsSincronizados} usuarios sincronizados',
            Icons.cloud_done,
          );
        } else {
          _showErrorSnackBar(resultado.mensaje);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al sincronizar usuarios: $e');
      }
    }
  }

  Future<void> _showDeleteUsersConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.cardBackground,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¿Eliminar usuarios?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta acción eliminará TODOS los usuarios de la base de datos local.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Deberás sincronizar usuarios nuevamente para poder iniciar sesión',
                        style: TextStyle(
                          fontSize: 12,
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
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _deleteUsersTable();
    }
  }

  Future<void> _deleteUsersTable() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.eliminar('Users');

      if (mounted) {
        _showSuccessSnackBar(
          'Tabla de usuarios eliminada correctamente',
          Icons.delete_sweep,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al eliminar usuarios: $e');
      }
    }
  }

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

  void _showSuccessSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.onPrimary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _handleLogin(LoginScreenViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await viewModel.handleLogin();

    if (mounted) {
      if (result.success) {
        _showSuccessSnackBar(result.message, result.icon ?? Icons.check);
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _handleBiometricLogin(LoginScreenViewModel viewModel) async {
    final result = await viewModel.authenticateWithBiometric();

    if (mounted) {
      if (result.success) {
        _showSuccessSnackBar(result.message, result.icon ?? Icons.check);
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showErrorSnackBar(result.message);
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
      create: (context) => LoginScreenViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 24.0 : 32.0,
                vertical: 24.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        _buildHeader(),
                        const SizedBox(height: 48),
                        _buildLoginForm(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'Iniciar Sesión',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          hint: 'Descripción de la pantalla de login',
          child: Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Consumer<LoginScreenViewModel>(
      builder: (context, viewModel, child) {
        return Semantics(
          label: 'Formulario de inicio de sesión',
          child: Card(
            elevation: 8,
            shadowColor: AppColors.shadowLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: AppColors.cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUsernameField(viewModel),
                    const SizedBox(height: 24),
                    _buildPasswordField(viewModel),
                    const SizedBox(height: 32),
                    _buildErrorMessage(viewModel),
                    _buildLoginButton(viewModel),
                    if (viewModel.biometricAvailable) ...[
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildBiometricButton(viewModel),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsernameField(LoginScreenViewModel viewModel) {
    final hasContent = viewModel.usernameController.text.isNotEmpty;

    return TextFormField(
      controller: viewModel.usernameController,
      focusNode: viewModel.usernameFocusNode,
      decoration: InputDecoration(
        labelText: 'Usuario',
        prefixIcon: Icon(
          Icons.person_outline_rounded,
          color: AppColors.getValidationIconColor(viewModel.usernameValid, hasContent),
        ),
        suffixIcon: hasContent
            ? Icon(
          viewModel.usernameValid ? Icons.check_circle_outline : Icons.error_outline,
          color: AppColors.getValidationIconColor(viewModel.usernameValid, hasContent),
          size: 20,
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.getValidationBorderColor(viewModel.usernameValid, hasContent),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      validator: viewModel.validateUsername,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      onFieldSubmitted: (_) => viewModel.focusNextField(),
    );
  }

  Widget _buildPasswordField(LoginScreenViewModel viewModel) {
    final hasContent = viewModel.passwordController.text.isNotEmpty;

    return TextFormField(
      controller: viewModel.passwordController,
      focusNode: viewModel.passwordFocusNode,
      obscureText: viewModel.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        hintText: 'Ingresa tu contraseña',
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: AppColors.getValidationIconColor(viewModel.passwordValid, hasContent),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasContent)
              Icon(
                viewModel.passwordValid ? Icons.check_circle_outline : Icons.error_outline,
                color: AppColors.getValidationIconColor(viewModel.passwordValid, hasContent),
                size: 20,
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                viewModel.obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.neutral500,
              ),
              onPressed: viewModel.togglePasswordVisibility,
              tooltip: viewModel.obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.getValidationBorderColor(viewModel.passwordValid, hasContent),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      validator: viewModel.validatePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(viewModel),
    );
  }

  Widget _buildErrorMessage(LoginScreenViewModel viewModel) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: viewModel.errorMessage != null
          ? Container(
        key: ValueKey(viewModel.errorMessage),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderError, width: 1),
        ),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  viewModel.errorMessage!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLoginButton(LoginScreenViewModel viewModel) {
    return SizedBox(
      height: 54,
      child: Semantics(
        button: true,
        enabled: !viewModel.isLoading,
        child: ElevatedButton(
          onPressed: viewModel.isLoading ? null : () => _handleLogin(viewModel),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
            foregroundColor: AppColors.buttonTextPrimary,
            disabledBackgroundColor: AppColors.buttonDisabled,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
            shadowColor: AppColors.shadowLight,
          ),
          child: viewModel.isLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonTextPrimary),
            ),
          )
              : const Text(
            'Iniciar Sesión',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
          child: Text('o', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }

  Widget _buildBiometricButton(LoginScreenViewModel viewModel) {
    return Semantics(
      button: true,
      hint: 'Usar autenticación biométrica para iniciar sesión',
      child: OutlinedButton.icon(
        onPressed: () => _handleBiometricLogin(viewModel),
        icon: Icon(Icons.fingerprint, color: AppColors.secondary, size: 24),
        label: Text(
          'Acceder con Biometría',
          style: TextStyle(color: AppColors.secondary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.secondary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '© 2025 Alarsoftware. Todos los derechos reservados.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Consumer<LoginScreenViewModel>(
          builder: (context, viewModel, child) {
            return PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 24),
              tooltip: 'Más opciones',
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: AppColors.cardBackground,
              elevation: 8,
              shadowColor: AppColors.shadowLight,
              onSelected: (String value) {
                switch (value) {
                  case 'sync':
                    if (!viewModel.isSyncingUsers) {
                      _syncUsers(viewModel);
                    }
                    break;
                  case 'delete_users':
                    _showDeleteUsersConfirmation();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'sync',
                  enabled: !viewModel.isSyncingUsers,
                  child: Row(
                    children: [
                      viewModel.isSyncingUsers
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
                        ),
                      )
                          : Icon(Icons.sync, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Sincronizar usuarios',
                        style: TextStyle(
                          color: viewModel.isSyncingUsers
                              ? AppColors.textSecondary.withOpacity(0.5)
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete_users',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Eliminar usuarios',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
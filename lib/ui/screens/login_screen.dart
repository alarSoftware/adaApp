import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/auth_service.dart';

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

  Future<void> _showMandatorySyncDialog(
      LoginScreenViewModel viewModel,
      SyncValidationResult validation,
      ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool isSyncing = false;
        double progress = 0.0;
        String currentStep = '';
        List<String> completedSteps = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      // ✅ SOLO LA RAZÓN (sin mostrar vendedores)
                      Container(
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
                                validation.razon,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mensaje importante
                      Container(
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
                            _buildSyncBulletPoint('Usuarios actualizados'),
                            _buildSyncBulletPoint('Clientes de tu zona'),
                            _buildSyncBulletPoint('Equipos y datos maestros'),
                          ],
                        ),
                      ),

                      // Progreso de sincronización
                      if (isSyncing) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                        if (currentStep.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            currentStep,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (completedSteps.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: completedSteps.map((step) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        step,
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSyncing ? null : () {
                      Navigator.of(dialogContext).pop();
                      viewModel.usernameController.clear();
                      viewModel.passwordController.clear();
                    },
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: isSyncing ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isSyncing ? null : () async {
                      setDialogState(() {
                        isSyncing = true;
                        progress = 0.0;
                        currentStep = 'Iniciando sincronización...';
                        completedSteps.clear();
                      });

                      try {
                        if (validation.vendedorAnterior != null) {
                          setDialogState(() {
                            currentStep = 'Limpiando datos anteriores...';
                            progress = 0.1;
                          });

                          final authService = AuthService();
                          await authService.clearSyncData();

                          setDialogState(() {
                            completedSteps.add('Datos anteriores limpiados');
                          });

                          await Future.delayed(const Duration(milliseconds: 300));
                        }

                        setDialogState(() {
                          currentStep = 'Sincronizando usuarios...';
                          progress = 0.3;
                        });

                        final userSyncResult = await viewModel.syncUsers();

                        if (!userSyncResult.exito) {
                          throw Exception('Error sincronizando usuarios: ${userSyncResult.mensaje}');
                        }

                        setDialogState(() {
                          completedSteps.add('${userSyncResult.itemsSincronizados} usuarios');
                        });

                        await Future.delayed(const Duration(milliseconds: 300));

                        setDialogState(() {
                          currentStep = 'Sincronizando tus clientes...';
                          progress = 0.6;
                        });

                        final clientSyncResult = await viewModel.syncClientsForVendor(validation.vendedorActual);

                        if (!clientSyncResult.exito) {
                          throw Exception('Error sincronizando clientes: ${clientSyncResult.mensaje}');
                        }

                        setDialogState(() {
                          completedSteps.add('${clientSyncResult.itemsSincronizados} clientes');
                          progress = 0.9;
                          currentStep = 'Finalizando...';
                        });

                        await Future.delayed(const Duration(milliseconds: 500));

                        setDialogState(() {
                          progress = 1.0;
                          currentStep = '¡Completado!';
                          completedSteps.add('Sincronización registrada');
                        });

                        await Future.delayed(const Duration(milliseconds: 500));

                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();

                        _showSuccessSnackBar('Sincronización completada exitosamente', Icons.cloud_done);

                        await Future.delayed(const Duration(milliseconds: 300));
                        Navigator.of(context).pushReplacementNamed('/home');
                      } catch (e) {
                        setDialogState(() {
                          isSyncing = false;
                          currentStep = '';
                        });

                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();
                        _showErrorSnackBar('Error en sincronización: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSyncing ? AppColors.buttonDisabled : AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                    child: isSyncing
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
          },
        );
      },
    );
  }


  Widget _buildSyncBulletPoint(String text) {
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

  // ✅ MODIFICADO: Ahora valida sincronización
  Future<void> _handleLogin(LoginScreenViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await viewModel.handleLogin();

    if (mounted) {
      if (result.success) {
        if (result.requiresSync && result.syncValidation != null) {
          await _showMandatorySyncDialog(viewModel, result.syncValidation!);
        } else {
          _showSuccessSnackBar(result.message, result.icon ?? Icons.check);
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  // ✅ MODIFICADO: Ahora valida sincronización
  Future<void> _handleBiometricLogin(LoginScreenViewModel viewModel) async {
    final result = await viewModel.authenticateWithBiometric();

    if (mounted) {
      if (result.success) {
        if (result.requiresSync && result.syncValidation != null) {
          await _showMandatorySyncDialog(viewModel, result.syncValidation!);
        } else {
          _showSuccessSnackBar(result.message, result.icon ?? Icons.check);
          Navigator.of(context).pushReplacementNamed('/home');
        }
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
      create: (_) => LoginScreenViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
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
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            _buildLogo(),
                            const SizedBox(height: 48),
                            _buildUsernameField(viewModel),
                            const SizedBox(height: 16),
                            _buildPasswordField(viewModel),
                            const SizedBox(height: 24),
                            _buildErrorMessage(viewModel),
                            _buildLoginButton(viewModel),
                            if (viewModel.biometricAvailable) ...[
                              const SizedBox(height: 24),
                              _buildDivider(),
                              const SizedBox(height: 24),
                              _buildBiometricButton(viewModel),
                            ],
                            const SizedBox(height: 40),
                            _buildFooter(),
                          ],
                        ),
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

  Widget _buildLogo() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          'Bienvenido',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tus credenciales para continuar',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUsernameField(LoginScreenViewModel viewModel) {
    return TextFormField(
      controller: viewModel.usernameController,
      focusNode: viewModel.usernameFocusNode,
      enabled: !viewModel.isLoading,
      decoration: InputDecoration(
        labelText: 'Usuario',
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintText: 'Ingresa tu usuario',
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
        prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
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
      onFieldSubmitted: (_) => viewModel.focusNextField(),
    );
  }

  Widget _buildPasswordField(LoginScreenViewModel viewModel) {
    return TextFormField(
      controller: viewModel.passwordController,
      focusNode: viewModel.passwordFocusNode,
      enabled: !viewModel.isLoading,
      obscureText: viewModel.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintText: 'Ingresa tu contraseña',
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            viewModel.obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: viewModel.togglePasswordVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
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
                  case 'api_settings':
                    Navigator.of(context).pushNamed('/api-settings');
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
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'api_settings',
                  child: Row(
                    children: [
                      Icon(Icons.dns, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Configurar servidor',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
import 'package:flutter/material.dart';
import 'package:ada_app/viewmodels/login_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:showcaseview/showcaseview.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final LoginScreenViewModel viewModel;
  final VoidCallback onSubmit;
  final GlobalKey loginButtonKey;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    required this.onSubmit,
    required this.loginButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _buildUsernameField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 16), // ✅ ESPACIO DESPUÉS DEL BOTÓN
          _buildErrorMessage(), // ✅ ERROR ABAJO, NO EMPUJA EL BOTÓN
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: viewModel.usernameController,
      focusNode: viewModel.usernameFocusNode,
      enabled: !viewModel.isLoading,
      decoration: InputDecoration(
        labelText: 'Usuario',
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintText: 'Ingresa tu usuario',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      validator: viewModel.validateUsername,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => viewModel.focusNextField(),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: viewModel.passwordController,
      focusNode: viewModel.passwordFocusNode,
      enabled: !viewModel.isLoading,
      obscureText: viewModel.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintText: 'Ingresa tu contraseña',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      validator: viewModel.validatePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
    );
  }

  Widget _buildErrorMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: viewModel.errorMessage != null
          ? Container(
              key: ValueKey(viewModel.errorMessage),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(
                top: 8,
              ), // ✅ CAMBIO: top en lugar de bottom
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderError, width: 1),
              ),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
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

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: Showcase(
        key: loginButtonKey,
        title: 'Iniciar Sesión',
        description:
            'Una vez que los usuarios estén sincronizados, ingresa tus credenciales aquí para entrar.',
        child: Semantics(
          button: true,
          enabled: !viewModel.isLoading,
          child: ElevatedButton(
            onPressed: viewModel.isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              foregroundColor: AppColors.buttonTextPrimary,
              disabledBackgroundColor: AppColors.buttonDisabled,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
              shadowColor: AppColors.shadowLight,
            ),
            child: viewModel.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.buttonTextPrimary,
                      ),
                    ),
                  )
                : const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

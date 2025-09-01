import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ==================== COLORES PRIMARIOS ====================
  static const Color primary = Color(0xFF2C3E50);
  static const Color primaryLight = Color(0xFF34495E);
  static const Color primaryDark = Color(0xFF1A252F);

  // ==================== COLORES SECUNDARIOS ====================
  static const Color secondary = Color(0xFF3498DB);
  static const Color secondaryLight = Color(0xFF5DADE2);
  static const Color secondaryDark = Color(0xFF2874A6);

  // ==================== COLORES DE SUPERFICIE ====================
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color surfaceContainer = Color(0xFFECF0F1);
  static const Color surfaceContainerHigh = Color(0xFFD5DBDB);

  // ==================== COLORES DE FONDO ====================
  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundSecondary = Color(0xFFECF0F1);

  // ==================== COLORES DE TEXTO ====================
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF2C3E50);
  static const Color onSurfaceVariant = Color(0xFF7F8C8D);
  static const Color onBackground = Color(0xFF2C3E50);

  // Variantes de texto
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textTertiary = Color(0xFFBDC3C7);
  static const Color textDisabled = Color(0xFFD5DBDB);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ==================== COLORES DE ESTADO ====================
  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFF58D68D);
  static const Color successDark = Color(0xFF1E8449);

  static const Color warning = Color(0xFFE67E22);
  static const Color warningLight = Color(0xFFF39C12);
  static const Color warningDark = Color(0xFFCA6F1E);

  static const Color error = Color(0xFFE74C3C);
  static const Color errorLight = Color(0xFFEC7063);
  static const Color errorDark = Color(0xFFCB4335);

  static const Color info = Color(0xFF3498DB);
  static const Color infoLight = Color(0xFF5DADE2);
  static const Color infoDark = Color(0xFF2874A6);

  // ==================== COLORES NEUTROS ====================
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFEEEEEE);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF95A5A6);
  static const Color neutral600 = Color(0xFF7F8C8D);
  static const Color neutral700 = Color(0xFF5D6D7E);
  static const Color neutral800 = Color(0xFF34495E);
  static const Color neutral900 = Color(0xFF2C3E50);

  // ==================== COLORES FUNCIONALES ====================
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF5F5F5);
  static const Color borderDark = Color(0xFFBDBDBD);

  static const Color shadow = Color(0xFF000000);
  static const Color overlay = Color(0xFF000000);

  static const Color focus = Color(0xFF3498DB);
  static const Color hover = Color(0xFFF8F9FA);
  static const Color pressed = Color(0xFFECF0F1);

  // ==================== COLORES CON OPACIDAD ====================
  // Shadows
  static Color shadowLight = shadow.withValues(alpha: 0.1);
  static Color shadowMedium = shadow.withValues(alpha: 0.15);
  static Color shadowHeavy = shadow.withValues(alpha: 0.25);

  // Overlays
  static Color overlayLight = overlay.withValues(alpha: 0.2);
  static Color overlayMedium = overlay.withValues(alpha: 0.5);
  static Color overlayHeavy = overlay.withValues(alpha: 0.8);

  // Estados con opacidad
  static Color successContainer = success.withValues(alpha: 0.1);
  static Color warningContainer = warning.withValues(alpha: 0.1);
  static Color errorContainer = error.withValues(alpha: 0.1);
  static Color infoContainer = info.withValues(alpha: 0.1);

  // Bordes con opacidad
  static Color borderSuccess = success.withValues(alpha: 0.3);
  static Color borderWarning = warning.withValues(alpha: 0.3);
  static Color borderError = error.withValues(alpha: 0.3);
  static Color borderInfo = info.withValues(alpha: 0.3);
  static Color borderNeutral = neutral500.withValues(alpha: 0.3);

  // ==================== MÉTODOS HELPER ====================

  /// Obtiene el color apropiado para iconos según el estado de validación
  static Color getValidationIconColor(bool isValid, bool hasContent) {
    if (!hasContent) return neutral500;
    return isValid ? success : error;
  }

  /// Obtiene el color de borde según el estado de validación
  static Color getValidationBorderColor(bool isValid, bool hasContent) {
    if (!hasContent) return borderNeutral;
    return isValid ? borderSuccess : borderError;
  }

  /// Obtiene el color de texto según el contexto
  static Color getTextColor(String context) {
    switch (context) {
      case 'primary':
        return textPrimary;
      case 'secondary':
        return textSecondary;
      case 'tertiary':
        return textTertiary;
      case 'disabled':
        return textDisabled;
      case 'on_dark':
        return textOnDark;
      default:
        return textPrimary;
    }
  }

  /// Obtiene el color de estado según el tipo
  static Color getStateColor(String state) {
    switch (state) {
      case 'success':
        return success;
      case 'warning':
        return warning;
      case 'error':
        return error;
      case 'info':
        return info;
      default:
        return primary;
    }
  }

  /// Obtiene el color de contenedor según el tipo
  static Color getContainerColor(String type) {
    switch (type) {
      case 'success':
        return successContainer;
      case 'warning':
        return warningContainer;
      case 'error':
        return errorContainer;
      case 'info':
        return infoContainer;
      case 'neutral':
        return surfaceContainer;
      default:
        return surface;
    }
  }

  // ==================== GRADIENTES ====================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successLight, success],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warningLight, warning],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [errorLight, error],
  );

  // ==================== COLORES ESPECÍFICOS PARA COMPONENTES ====================

  // Botones
  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = secondary;
  static Color buttonDisabled = neutral400;

  // Campos de texto
  static const Color inputBorder = border;
  static const Color inputFocused = focus;
  static Color inputFill = surfaceVariant;

  // Cards y contenedores
  static const Color cardBackground = surface;
  static Color cardShadow = shadowLight;

  // Dividers
  static Color divider = neutral300.withValues(alpha: 0.4);

  // AppBar
  static const Color appBarBackground = primary;
  static const Color appBarForeground = onPrimary;

  // Bottom Navigation
  static const Color bottomNavBackground = surface;
  static const Color bottomNavSelected = primary;
  static const Color bottomNavUnselected = neutral600;
}
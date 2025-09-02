import 'package:flutter/material.dart';

/// Sistema de colores centralizado para la aplicación Ada
///
/// Proporciona una paleta coherente de colores organizados por categorías:
/// - Colores primarios y secundarios
/// - Estados (success, error, warning, info)
/// - Superficies y fondos
/// - Texto y neutros
/// - Funcionales (bordes, sombras, etc.)
class AppColors {
  AppColors._();

  // ==================== COLORES PRIMARIOS ====================
  /// Color principal de la marca - Azul oscuro corporativo
  static const Color primary = Color(0xFF2C3E50);
  /// Variación más clara del color primario
  static const Color primaryLight = Color(0xFF34495E);
  /// Variación más oscura del color primario
  static const Color primaryDark = Color(0xFF1A252F);

  // ==================== COLORES SECUNDARIOS ====================
  /// Color secundario - Azul brillante para acentos
  static const Color secondary = Color(0xFF3498DB);
  /// Variación más clara del color secundario
  static const Color secondaryLight = Color(0xFF5DADE2);
  /// Variación más oscura del color secundario
  static const Color secondaryDark = Color(0xFF2874A6);

  // ==================== SUPERFICIES Y FONDOS ====================
  /// Superficie principal - Blanco puro para cards y contenedores
  static const Color surface = Color(0xFFFFFFFF);
  /// Variante de superficie para elementos sutiles
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  /// Contenedor de superficie para agrupaciones
  static const Color surfaceContainer = Color(0xFFECF0F1);

  /// Fondo principal de la aplicación
  static const Color background = Color(0xFFF8F9FA);

  // ==================== COLORES DE TEXTO ====================
  /// Texto sobre superficies primarias
  static const Color onPrimary = Color(0xFFFFFFFF);
  /// Texto sobre superficies secundarias
  static const Color onSecondary = Color(0xFFFFFFFF);
  /// Texto sobre superficies normales
  static const Color onSurface = Color(0xFF2C3E50);

  /// Texto principal - Máximo contraste y legibilidad
  static const Color textPrimary = Color(0xFF2C3E50);
  /// Texto secundario - Para información complementaria
  static const Color textSecondary = Color(0xFF7F8C8D);
  /// Texto terciario - Para elementos menos importantes
  static const Color textTertiary = Color(0xFFBDC3C7);
  /// Texto deshabilitado - Para elementos no interactivos
  static const Color textDisabled = Color(0xFFD5DBDB);

  // ==================== COLORES DE ESTADO ====================
  /// Estado exitoso - Verde para confirmaciones
  static const Color success = Color(0xFF27AE60);
  /// Variación clara del estado exitoso
  static const Color successLight = Color(0xFF58D68D);

  /// Estado de advertencia - Naranja para alertas
  static const Color warning = Color(0xFFE67E22);
  /// Variación clara del estado de advertencia
  static const Color warningLight = Color(0xFFF39C12);

  /// Estado de error - Rojo para errores críticos
  static const Color error = Color(0xFFE74C3C);
  /// Variación clara del estado de error
  static const Color errorLight = Color(0xFFEC7063);

  /// Estado informativo - Azul para información general
  static const Color info = Color(0xFF3498DB);
  /// Variación clara del estado informativo
  static const Color infoLight = Color(0xFF5DADE2);

  // ==================== ESCALA DE GRISES NEUTROS ====================
  /// Gris más claro - Casi blanco
  static const Color neutral50 = Color(0xFFFAFAFA);
  /// Gris muy claro - Para fondos sutiles
  static const Color neutral100 = Color(0xFFF5F5F5);
  /// Gris claro - Para divisores suaves
  static const Color neutral200 = Color(0xFFEEEEEE);
  /// Gris medio-claro - Para bordes
  static const Color neutral300 = Color(0xFFE0E0E0);
  /// Gris medio - Para elementos deshabilitados
  static const Color neutral400 = Color(0xFFBDBDBD);
  /// Gris central - Para texto secundario
  static const Color neutral500 = Color(0xFF95A5A6);
  /// Gris medio-oscuro - Para texto menos importante
  static const Color neutral600 = Color(0xFF7F8C8D);
  /// Gris oscuro - Para elementos de contraste
  static const Color neutral700 = Color(0xFF5D6D7E);
  /// Gris muy oscuro - Para texto principal alternativo
  static const Color neutral800 = Color(0xFF34495E);
  /// Gris más oscuro - Casi negro
  static const Color neutral900 = Color(0xFF2C3E50);

  // ==================== ELEMENTOS FUNCIONALES ====================
  /// Borde estándar para elementos de UI
  static const Color border = Color(0xFFE0E0E0);
  /// Color base para sombras (se usa con opacidad)
  static const Color shadow = Color(0xFF000000);
  /// Color para elementos en foco
  static const Color focus = Color(0xFF3498DB);

  /// Obtiene el color apropiado para iconos según el estado de validación
  static Color getValidationIconColor(bool isValid, bool hasContent) {
    if (!hasContent) return neutral500;
    return isValid ? success : error;
  }

  /// Obtiene el color de borde según el estado de validación
  static Color getValidationBorderColor(bool isValid, bool hasContent) {
    if (!hasContent) return border;
    return isValid ? borderSuccess : borderError;
  }

  // ==================== COLORES CON TRANSPARENCIA PREDEFINIDA ====================
  /// Sombra ligera para elevación sutil
  static Color shadowLight = shadow.withValues(alpha: 0.1);
  /// Sombra media para elevación estándar
  static Color shadowMedium = shadow.withValues(alpha: 0.15);

  /// Contenedor de estado exitoso con fondo translúcido
  static Color successContainer = success.withValues(alpha: 0.1);
  /// Contenedor de advertencia con fondo translúcido
  static Color warningContainer = warning.withValues(alpha: 0.1);
  /// Contenedor de error con fondo translúcido
  static Color errorContainer = error.withValues(alpha: 0.1);
  /// Contenedor informativo con fondo translúcido
  static Color infoContainer = info.withValues(alpha: 0.1);

  /// Borde para elementos en estado exitoso
  static Color borderSuccess = success.withValues(alpha: 0.3);
  /// Borde para elementos en estado de advertencia
  static Color borderWarning = warning.withValues(alpha: 0.3);
  /// Borde para elementos en estado de error
  static Color borderError = error.withValues(alpha: 0.3);

  // ==================== COLORES POR COMPONENTE ====================

  // BOTONES
  /// Color de fondo para botones primarios
  static const Color buttonPrimary = primary;
  /// Color de fondo para botones secundarios
  static const Color buttonSecondary = secondary;
  /// Color para botones deshabilitados
  static const Color buttonDisabled = neutral400;
  /// Color de texto en botones primarios
  static const Color buttonTextPrimary = onPrimary;
  /// Color de texto en botones secundarios
  static const Color buttonTextSecondary = onSecondary;

  // APPBAR
  /// Color de fondo del AppBar
  static const Color appBarBackground = primary;
  /// Color de texto e iconos en el AppBar
  static const Color appBarForeground = onPrimary;

  // CARDS Y CONTENEDORES
  /// Color de fondo para cards
  static const Color cardBackground = surface;
  /// Color de fondo para contenedores principales
  static const Color containerBackground = surfaceContainer;
  /// Color de sombra para cards
  static Color cardShadow = shadowLight;

  // CAMPOS DE ENTRADA
  /// Color de borde para inputs en estado normal
  static const Color inputBorder = border;
  /// Color de borde para inputs enfocados
  static const Color inputFocused = focus;
  /// Color de fondo para inputs
  static const Color inputBackground = surfaceVariant;

  // NAVEGACIÓN
  /// Color de fondo para bottom navigation
  static const Color bottomNavBackground = surface;
  /// Color para items seleccionados en navegación
  static const Color bottomNavSelected = primary;
  /// Color para items no seleccionados en navegación
  static const Color bottomNavUnselected = neutral600;

  // DIVISORES Y SEPARADORES
  /// Color para líneas divisoras
  static Color divider = neutral300.withValues(alpha: 0.4);

  // ==================== MÉTODOS HELPER ====================

  /// Obtiene el color de estado según el tipo
  ///
  /// Parámetros:
  /// - [state]: 'success', 'warning', 'error', 'info'
  ///
  /// Retorna el color correspondiente o [primary] como fallback
  static Color getStateColor(String state) {
    switch (state) {
      case 'success': return success;
      case 'warning': return warning;
      case 'error': return error;
      case 'info': return info;
      default: return primary;
    }
  }

  /// Obtiene el color de contenedor según el tipo de estado
  ///
  /// Parámetros:
  /// - [type]: 'success', 'warning', 'error', 'info', 'neutral'
  ///
  /// Retorna el color de contenedor correspondiente
  static Color getContainerColor(String type) {
    switch (type) {
      case 'success': return successContainer;
      case 'warning': return warningContainer;
      case 'error': return errorContainer;
      case 'info': return infoContainer;
      case 'neutral': return surfaceContainer;
      default: return surface;
    }
  }



  // ==================== GRADIENTES PREDEFINIDOS ====================

  /// Gradiente principal para elementos destacados
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// Gradiente secundario para elementos de acento
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );
}
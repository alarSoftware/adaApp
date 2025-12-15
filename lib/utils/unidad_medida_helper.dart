class UnidadMedidaHelper {
  /// Normaliza la unidad que viene de la API
  /// "Units" → "UN"
  /// "X 6" o "X6" → "X 6" (normalizado con espacio)
  static String normalizarDesdeAPI(String? unidadAPI) {
    if (unidadAPI == null || unidadAPI.isEmpty) return 'UN';

    final limpia = unidadAPI.trim().toUpperCase();

    // Si es "Units" o variaciones → unidades simples
    if (limpia == 'UNITS' ||
        limpia == 'UN' ||
        limpia == 'UNIDAD' ||
        limpia == 'UNIDADES') {
      return 'UN';
    }

    // Detectar patrón de pack: empieza con X seguido de número (con o sin espacio)
    // Ejemplo: X6, X 6, x12, X  24
    final packRegex = RegExp(r'^X\s*(\d+)$');
    final match = packRegex.firstMatch(limpia);

    if (match != null) {
      final cantidad = match.group(1);
      return 'X $cantidad'; // Normalizar siempre con un espacio: "X 6"
    }

    // Mantener compatibilidad con startWith si no machea regex estricta pero parece pack
    if (limpia.startsWith('X')) {
      return limpia;
    }

    // Por defecto, retornar unidades
    return 'UN';
  }

  /// Verifica si la unidad es "unidades simples"
  static bool esUnidadSimple(String unidad) {
    final normalizada = unidad.trim().toUpperCase();
    return normalizada == 'UN' ||
        normalizada == 'UNITS' ||
        normalizada == 'UNIDAD';
  }

  /// Verifica si es un pack/caja (X 6, X 12, etc)
  static bool esPack(String unidad) {
    final normalizada = unidad.trim().toUpperCase();
    return normalizada.startsWith('X');
  }

  /// Obtiene el nombre para mostrar al usuario
  static String obtenerNombreDisplay(String unidad) {
    if (esUnidadSimple(unidad)) return 'Unidades';

    if (esPack(unidad)) {
      // "X 6" → "Pack x 6"
      // "X 12" → "Pack x 12"
      final numero = unidad.replaceAll(RegExp(r'[Xx]\s*'), '').trim();
      return 'Pack x $numero';
    }

    return unidad;
  }
}

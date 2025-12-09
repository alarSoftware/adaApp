class UnidadMedidaHelper {
  /// Normaliza la unidad que viene de la API
  /// "Units" → "UN"
  /// "X 6" → "X 6" (sin cambios)
  static String normalizarDesdeAPI(String? unidadAPI) {
    if (unidadAPI == null || unidadAPI.isEmpty) return 'UN';

    final limpia = unidadAPI.trim();

    // Si es "Units" → unidades simples
    if (limpia.toLowerCase() == 'units') return 'UN';

    // Si empieza con "X " es un pack/caja, lo dejamos tal cual pero en mayúsculas
    if (limpia.toUpperCase().startsWith('X ')) {
      return limpia.toUpperCase();
    }

    // Por defecto, retornar unidades
    return 'UN';
  }

  /// Verifica si la unidad es "unidades simples"
  static bool esUnidadSimple(String unidad) {
    final normalizada = unidad.trim().toUpperCase();
    return normalizada == 'UN' || normalizada == 'UNITS';
  }

  /// Verifica si es un pack/caja (X 6, X 12, etc)
  static bool esPack(String unidad) {
    return unidad.trim().toUpperCase().startsWith('X ');
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
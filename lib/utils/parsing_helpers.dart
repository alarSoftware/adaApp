class ParsingHelpers {
  /// Parsear string de forma segura
  static String? parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  /// Parsear int de forma segura
  static int parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Parsear boolean de forma segura
  static bool parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return defaultValue;
  }

  /// Parsear DateTime de forma segura
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  /// Parsear DateTime con valor por defecto (ahora)
  static DateTime parseDateTimeWithDefault(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Convertir int a bool (1 = true, 0 o cualquier otro = false)
  static bool intToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1';
    return false;
  }

  /// Convertir bool a int (true = 1, false = 0)
  static int boolToInt(bool? value) {
    return (value == true) ? 1 : 0;
  }
}
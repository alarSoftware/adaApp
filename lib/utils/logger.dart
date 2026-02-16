import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void i(String message) {
    if (kDebugMode) {
      debugPrint('INFO: $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      debugPrint('WARNING: $message');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) {
        debugPrint('Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace:\n$stackTrace');
      }
    }
  }
}

import 'package:flutter/foundation.dart';

/// Structured logging utility for Focus Guard.
///
/// Debug builds: detailed logs.
/// Release builds: minimal logs (errors only).
/// Never logs passwords or sensitive information.
class AppLogger {
  AppLogger._();

  static const String _tag = 'FocusGuard';

  /// Log a debug message. Only visible in debug builds.
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _tag}] $message');
    }
  }

  /// Log an informational message.
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _tag}] ℹ️ $message');
    }
  }

  /// Log a warning message.
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? _tag}] ⚠️ $message');
    }
  }

  /// Log an error message. Visible in both debug and release builds.
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    debugPrint('[${tag ?? _tag}] ❌ $message');
    if (error != null && kDebugMode) {
      debugPrint('[${tag ?? _tag}] Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('[${tag ?? _tag}] StackTrace: $stackTrace');
    }
  }
}

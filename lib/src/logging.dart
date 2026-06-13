import 'package:flutter/foundation.dart';

/// Logs an internal failure in debug builds only; never throws.
void logFirebenchError(String message, Object error) {
  if (kDebugMode) debugPrint('firebench: $message: $error');
}

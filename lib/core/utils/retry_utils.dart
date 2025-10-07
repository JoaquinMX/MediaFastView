import 'dart:async';

import '../error/app_error.dart';

/// Utility class for implementing retry mechanisms for operations that may fail transiently.
class RetryUtils {
  const RetryUtils._();

  /// Retries an operation with exponential backoff.
  ///
  /// [operation] - The async operation to retry
  /// [maxAttempts] - Maximum number of attempts (default: 3)
  /// [initialDelay] - Initial delay between retries in milliseconds (default: 100)
  /// [maxDelay] - Maximum delay between retries in milliseconds (default: 2000)
  /// [backoffMultiplier] - Multiplier for exponential backoff (default: 2.0)
  /// [shouldRetry] - Optional function to determine if an error should be retried
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    int initialDelay = 100,
    int maxDelay = 2000,
    double backoffMultiplier = 2.0,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    int delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // If this was the last attempt, rethrow
        if (attempt >= maxAttempts) {
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: delay));

        // Calculate next delay with exponential backoff
        delay = (delay * backoffMultiplier).toInt();
        if (delay > maxDelay) {
          delay = maxDelay;
        }
      }
    }

    // This should never be reached, but just in case
    throw UnexpectedError('Retry logic failed unexpectedly');
  }

  /// Default retry condition for file system operations.
  /// Retries on permission errors and some transient failures.
  static bool shouldRetryFileOperation(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission denied') ||
           errorString.contains('operation not permitted') ||
           errorString.contains('errno = 1') ||
           errorString.contains('temporarily unavailable') ||
           errorString.contains('resource busy');
  }

  /// Default retry condition for network operations.
  static bool shouldRetryNetworkOperation(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
           errorString.contains('timeout') ||
           errorString.contains('network') ||
           errorString.contains('unreachable');
  }
}
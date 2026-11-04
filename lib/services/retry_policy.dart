// Shared retry rules for the offline scan queue and the fraud-flag queue.

/// Whether a failed request is worth retrying. A null [statusCode] means the
/// server could not be reached at all. Other 4xx answers are permanent
/// rejections, so retrying them can never succeed.
bool isRetryableStatus(int? statusCode) {
  if (statusCode == null) return true;
  if (statusCode == 401 || statusCode == 408 || statusCode == 429) return true;
  return statusCode >= 500;
}

/// How long a failed item waits before the periodic timer tries it again:
/// 30 s after the first failure, doubling each time, capped at 15 minutes.
Duration retryDelay(int attempts) {
  if (attempts <= 0) return Duration.zero;
  final exponent = (attempts - 1).clamp(0, 5);
  final seconds = (30 * (1 << exponent)).clamp(30, 900);
  return Duration(seconds: seconds);
}

/// True when an item may be tried now. [force] is used when connectivity is
/// restored, so the wait is skipped.
bool isRetryDue({
  required int attempts,
  required int? lastAttemptMs,
  required int nowMs,
  bool force = false,
}) {
  if (force || attempts <= 0 || lastAttemptMs == null) return true;
  return nowMs - lastAttemptMs >= retryDelay(attempts).inMilliseconds;
}

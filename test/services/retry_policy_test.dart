import 'package:flutter_test/flutter_test.dart';
import 'package:idetect/services/retry_policy.dart';

void main() {
  group('isRetryableStatus', () {
    test('retries when the server could not be reached', () {
      expect(isRetryableStatus(null), isTrue);
    });

    test('retries temporary answers', () {
      for (final code in [401, 408, 429, 500, 502, 503]) {
        expect(isRetryableStatus(code), isTrue, reason: '$code');
      }
    });

    test('does not retry permanent rejections', () {
      for (final code in [400, 403, 404, 409, 422]) {
        expect(isRetryableStatus(code), isFalse, reason: '$code');
      }
    });
  });

  group('retryDelay', () {
    test('is zero before any failure', () {
      expect(retryDelay(0), Duration.zero);
    });

    test('doubles from 30 seconds and caps at 15 minutes', () {
      expect(retryDelay(1), const Duration(seconds: 30));
      expect(retryDelay(2), const Duration(seconds: 60));
      expect(retryDelay(3), const Duration(seconds: 120));
      expect(retryDelay(6), const Duration(seconds: 900));
      expect(retryDelay(50), const Duration(seconds: 900));
    });
  });

  group('isRetryDue', () {
    test('is due for a new item', () {
      expect(
        isRetryDue(attempts: 0, lastAttemptMs: null, nowMs: 1000),
        isTrue,
      );
    });

    test('waits until the delay has passed', () {
      expect(
        isRetryDue(attempts: 1, lastAttemptMs: 1000, nowMs: 20000),
        isFalse,
      );
      expect(
        isRetryDue(attempts: 1, lastAttemptMs: 1000, nowMs: 31000),
        isTrue,
      );
    });

    test('force skips the wait', () {
      expect(
        isRetryDue(
            attempts: 5, lastAttemptMs: 1000, nowMs: 1001, force: true),
        isTrue,
      );
    });
  });
}

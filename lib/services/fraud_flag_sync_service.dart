import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';
import 'retry_policy.dart';
import 'sync_notifier.dart';

/// REQ-2.6.4: Offline queue and auto-sync for fraud flags.
///
/// A flag that fails for a temporary reason (no connection, server error,
/// rate limit, expired login) stays queued and is retried with a growing wait
/// until it is sent. A flag the server permanently rejects is removed and staff
/// are told, because retrying it can never succeed.
class FraudFlagSyncService {
  static const String _pendingFlagsBox = 'pending_fraud_flags';
  static const Duration _retryTick = Duration(seconds: 30);
  static const int _alertAfterAttempts = 5;
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  static Timer? _retryTimer;
  static bool _isSyncing = false;
  // Token the server refused (401). Retries wait until a new login replaces it.
  static String? _rejectedToken;

  /// Initialize the service, flush anything left from the last session, and
  /// keep retrying on a timer as well as on connectivity changes.
  static Future<void> init() async {
    await Hive.openBox(_pendingFlagsBox);
    _startConnectivityListener();
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryTick, (_) => syncPendingFlags());
    unawaited(syncPendingFlags(force: true));
  }

  /// Queue a fraud flag for later submission (when offline or as backup)
  static Future<String> queueFraudFlag({
    required String verificationLogId,
    required String idNumberFlagged,
    required String beneficiaryType,
    String? notes,
  }) async {
    final box = await Hive.openBox(_pendingFlagsBox);

    final queuedFlag = {
      'verification_log_id': verificationLogId,
      'id_number_flagged': idNumberFlagged,
      'beneficiary_type': beneficiaryType,
      'establishment_notes': notes,
      // Lets a different account on the same phone skip this flag.
      'establishment_id': ApiService.currentUser?['id']?.toString(),
      'queued_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
    };

    await box.add(queuedFlag);

    // Generate a temporary local reference ID (first 8 chars of a simple hash)
    final tempId =
        '${idNumberFlagged.hashCode.abs().toRadixString(16).padLeft(8, '0').substring(0, 8)}'
            .toUpperCase();

    return tempId;
  }

  /// Try to submit a queued flag immediately
  static Future<Map<String, dynamic>> submitFlagNow({
    required String verificationLogId,
    required String idNumberFlagged,
    required String beneficiaryType,
    String? notes,
  }) async {
    final result = await ApiService.reportFraudFlag(
      verificationLogId: verificationLogId,
      idNumberFlagged: idNumberFlagged,
      beneficiaryType: beneficiaryType,
      notes: notes,
    );

    // Queue only temporary failures. A permanent rejection (for example invalid
    // input) is returned to the caller, because retrying it can never succeed.
    if (result['error'] != null) {
      if (!isRetryableStatus(result['status_code'] as int?)) return result;
      final tempRef = await queueFraudFlag(
        verificationLogId: verificationLogId,
        idNumberFlagged: idNumberFlagged,
        beneficiaryType: beneficiaryType,
        notes: notes,
      );
      return {
        'queued': true,
        'reference': tempRef,
        'message': 'Flag queued offline. Will auto-submit when connected.',
      };
    }

    return result;
  }

  /// Sends queued flags. [force] skips the retry wait (used when connectivity
  /// returns); the periodic timer respects it.
  static Future<void> syncPendingFlags({bool force = false}) async {
    if (_isSyncing) return; // Prevent concurrent syncs
    final token = ApiService.token;
    if (token == null || token == _rejectedToken) return;
    final accountId = ApiService.currentUser?['id']?.toString();

    _isSyncing = true;
    try {
      final box = await Hive.openBox(_pendingFlagsBox);
      final indicesToDelete = <int>[];

      for (var i = 0; i < box.length; i++) {
        final flag = box.getAt(i);
        if (flag is! Map) {
          // Unreadable entry cannot be sent, so remove it and tell staff.
          indicesToDelete.add(i);
          SyncNotifier.show(
              'An unreadable fraud flag was removed from the sync queue.');
          continue;
        }

        // A flag queued by another account stays queued for that account.
        final owner = flag['establishment_id']?.toString();
        if (owner != null && accountId != null && owner != accountId) continue;

        final attempts = (flag['attempts'] as int?) ?? 0;
        final due = isRetryDue(
          attempts: attempts,
          lastAttemptMs: flag['last_attempt'] as int?,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          force: force,
        );
        if (!due) continue;

        try {
          final result = await ApiService.reportFraudFlag(
            verificationLogId: flag['verification_log_id'] as String,
            idNumberFlagged: flag['id_number_flagged'] as String,
            beneficiaryType: flag['beneficiary_type'] as String,
            notes: flag['establishment_notes'] as String?,
          );

          if (result['error'] == null) {
            indicesToDelete.add(i);
            continue;
          }

          final code = result['status_code'] as int?;
          if (code == 401) {
            // Login expired. Wait for a new login instead of retrying.
            _rejectedToken = token;
            break;
          }
          if (code == 429) break; // Rate limited. Try again on a later tick.
          if (!isRetryableStatus(code)) {
            indicesToDelete.add(i);
            SyncNotifier.show(
                'A queued fraud flag was rejected by the server and removed: '
                '${result['error']}');
            continue;
          }
          await _recordFailure(box, i, flag, attempts);
        } catch (_) {
          await _recordFailure(box, i, flag, attempts);
        }
      }

      // Delete sent or removed flags in reverse to preserve indices
      for (final idx in indicesToDelete.reversed) {
        await box.deleteAt(idx);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Keeps a failed flag queued. Flags are never dropped for temporary
  /// failures; staff are alerted once the failure count reaches
  /// [_alertAfterAttempts].
  static Future<void> _recordFailure(
    Box box,
    int index,
    Map flag,
    int attempts,
  ) async {
    final nextAttempts = attempts + 1;
    final updated = Map<String, dynamic>.from(flag);
    updated['attempts'] = nextAttempts;
    updated['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
    await box.putAt(index, updated);

    if (nextAttempts == _alertAfterAttempts) {
      SyncNotifier.show(
        'A fraud flag has failed $_alertAfterAttempts times and is still '
        'queued. It will keep retrying. Check the connection or sign in again.',
      );
    }
  }

  /// Get count of pending flags
  static Future<int> getPendingCount() async {
    final box = await Hive.openBox(_pendingFlagsBox);
    return box.length;
  }

  /// Start listening for connectivity changes and auto-sync
  static void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // If we have any form of connectivity, try to sync
      if (result != ConnectivityResult.none) {
        syncPendingFlags(force: true);
      }
    });
  }

  /// Stop the connectivity listener and retry timer (call on app shutdown)
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';

/// REQ-2.6.4: Offline queue and auto-sync for fraud flags
class FraudFlagSyncService {
  static const String _pendingFlagsBox = 'pending_fraud_flags';
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  static bool _isSyncing = false;

  /// Initialize the service and start listening for connectivity changes
  static Future<void> init() async {
    await Hive.openBox(_pendingFlagsBox);
    _startConnectivityListener();
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

    // If submission fails, queue it for later
    if (result['error'] != null) {
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

  /// Sync all pending flags (called when connectivity is restored)
  static Future<void> syncPendingFlags() async {
    if (_isSyncing) return; // Prevent concurrent syncs
    _isSyncing = true;

    try {
      final box = await Hive.openBox(_pendingFlagsBox);
      final keysToDelete = <dynamic>[];

      for (var i = 0; i < box.length; i++) {
        final flag = box.getAt(i);
        if (flag is! Map) continue;

        final attempts = (flag['attempts'] as int?) ?? 0;

        // Skip if too many failed attempts (>5)
        if (attempts >= 5) continue;

        try {
          final result = await ApiService.reportFraudFlag(
            verificationLogId: flag['verification_log_id'] as String,
            idNumberFlagged: flag['id_number_flagged'] as String,
            beneficiaryType: flag['beneficiary_type'] as String,
            notes: flag['establishment_notes'] as String?,
          );

          if (result['error'] == null) {
            // Success - mark for deletion
            keysToDelete.add(i);
          } else {
            // Increment attempt counter
            final updatedFlag = Map<String, dynamic>.from(flag);
            updatedFlag['attempts'] = attempts + 1;
            updatedFlag['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
            await box.putAt(i, updatedFlag);
          }
        } catch (e) {
          // Network error - increment attempts
          final updatedFlag = Map<String, dynamic>.from(flag);
          updatedFlag['attempts'] = attempts + 1;
          updatedFlag['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
          await box.putAt(i, updatedFlag);
        }
      }

      // Delete successfully synced flags (in reverse to preserve indices)
      for (final key in keysToDelete.reversed) {
        await box.deleteAt(key);
      }
    } finally {
      _isSyncing = false;
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
        syncPendingFlags();
      }
    });
  }

  /// Stop the connectivity listener (call on app shutdown)
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}

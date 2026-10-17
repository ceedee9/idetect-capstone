// lib/services/offline_scan_sync_service.dart
//
// When the API is unreachable, the cashier sees a MANUAL REVIEW result (never a
// cached VALID). The scan is queued here and replayed to POST /verification/scan
// when connectivity returns, so every scan reaches verification_logs. Failed
// replays stay queued and are retried; staff are alerted after repeated failures.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as dart_io;
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class OfflineScanSyncService {
  static const String _queueBoxName = 'pending_offline_scans_v2';
  static const String _legacyQueueBoxName = 'pending_offline_scans';
  static const String _queueKeyName = 'offline_queue_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<Box>? _queueBoxFuture;
  static const int _alertAfterAttempts = 5;

  /// Lives on the root MaterialApp so alerts show on any screen.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static StreamSubscription<ConnectivityResult>? _connectivitySub;
  static bool _isSyncing = false;

  /// Call once from main() after LocalDatabase.init().
  static Future<void> init() async {
    await _openQueueBox();

    // Attempt an immediate flush in case scans were queued in a previous session
    await syncPendingScans();

    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        debugPrint(
            '📶 OfflineScanSync: connectivity restored — flushing queue');
        await syncPendingScans();
      }
    });
  }

  /// Stop the connectivity listener (call on logout).
  static void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Queue a confirmed offline scan so it is later replayed to the API.
  /// Call this from ResultScreen when the user saves an offline verification result.
  static Future<void> queueOfflineScan({
    required String idNumber,
    required String beneficiaryType,
    required String? extractedName,
    required String? extractedDob,
    required double? ocrConfidence,
    required String? imagePath,
    required int scannedAt,
  }) async {
    final box = await _openQueueBox();
    await box.add({
      'client_scan_id': _newClientScanId(),
      'id_number': idNumber,
      'beneficiary_type': beneficiaryType,
      'extracted_name': extractedName,
      'extracted_dob': extractedDob,
      'ocr_confidence': ocrConfidence,
      'image_path': imagePath,
      'scanned_at': scannedAt,
      'queued_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
    });
    debugPrint('📥 OfflineScanSync: queued scan for $idNumber');

    // Attempt immediate flush (may succeed if device is back online by save time)
    await syncPendingScans();
  }

  /// Opens the encrypted queue box once. Scans queued by an older app version
  /// (unencrypted box) are moved into it, and the old box is then deleted.
  static Future<Box> _openQueueBox() {
    return _queueBoxFuture ??= _openAndMigrateQueue().catchError((Object e) {
      _queueBoxFuture = null;
      throw e;
    });
  }

  static Future<Box> _openAndMigrateQueue() async {
    final box = await Hive.openBox(
      _queueBoxName,
      encryptionCipher: HiveAesCipher(await _queueKey()),
    );
    if (await Hive.boxExists(_legacyQueueBoxName)) {
      final legacy = await Hive.openBox(_legacyQueueBoxName);
      for (final entry in legacy.values) {
        await box.add(entry);
      }
      await legacy.deleteFromDisk();
    }
    return box;
  }

  /// The 256-bit key is kept in secure storage, not beside the queue file.
  static Future<List<int>> _queueKey() async {
    final stored = await _secureStorage.read(key: _queueKeyName);
    if (stored != null) return base64Decode(stored);
    final key = Hive.generateSecureKey();
    await _secureStorage.write(key: _queueKeyName, value: base64Encode(key));
    return key;
  }

  /// Random ID for one queued scan, so the server can ignore repeat replays.
  static String _newClientScanId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Replay all queued offline scans to the API.
  static Future<void> syncPendingScans() async {
    if (_isSyncing) return;
    final token = ApiService.token;
    if (token == null) return;

    _isSyncing = true;
    try {
      final box = await _openQueueBox();
      if (box.isEmpty) return;

      final indicesToDelete = <int>[];

      for (var i = 0; i < box.length; i++) {
        final entry = box.getAt(i);
        if (entry is! Map) {
          // Unreadable entry cannot be replayed, so remove it and tell staff.
          indicesToDelete.add(i);
          _alert('An unreadable offline scan was removed from the sync queue.');
          continue;
        }

        final data = Map<String, dynamic>.from(entry);
        final attempts = (data['attempts'] as int?) ?? 0;

        try {
          final idNumber = data['id_number'] as String;
          final beneficiaryType = data['beneficiary_type'] as String;
          final extractedName = data['extracted_name'] as String?;
          final extractedDob = data['extracted_dob'] as String?;
          final ocrConfidence = (data['ocr_confidence'] as num?)?.toDouble();
          final imagePath = data['image_path'] as String?;
          final clientScanId = data['client_scan_id'] as String?;
          final scannedAtMs = data['scanned_at'] as int?;

          final normalizedId =
              idNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final normalizedConfidence = ocrConfidence == null
              ? null
              : ApiService.normalizeConfidenceScore(ocrConfidence);

          String? imageData;
          if (imagePath != null) {
            try {
              final bytes = await dart_io.File(imagePath).readAsBytes();
              imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            } catch (_) {
              // Non-fatal: proceed without image attachment
            }
          }

          final response = await http
              .post(
                Uri.parse('${ApiService.baseUrl}/verification/scan'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'id_number': normalizedId,
                  'beneficiary_type': beneficiaryType,
                  'ocr_confidence_score': normalizedConfidence,
                  'manually_entered': false,
                  // Flag so the API can distinguish replayed offline scans in logs
                  'offline_queued': true,
                  if (clientScanId != null) 'client_scan_id': clientScanId,
                  if (scannedAtMs != null)
                    'scanned_at': DateTime.fromMillisecondsSinceEpoch(
                      scannedAtMs,
                      isUtc: true,
                    ).toIso8601String(),
                  if (imageData != null) 'image_data': imageData,
                  if (extractedName != null && extractedName.isNotEmpty)
                    'extracted_name': extractedName,
                  if (extractedDob != null && extractedDob.isNotEmpty)
                    'extracted_dob': extractedDob,
                }),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            indicesToDelete.add(i);
            debugPrint('✅ OfflineScanSync: flushed scan $idNumber');
            _showReplayResult(response.body);
          } else if (response.statusCode == 401) {
            // Token expired — stop trying until re-login
            stop();
            break;
          } else {
            // Server error — keep the scan and retry next time
            await _recordFailure(box, i, data, attempts);
          }
        } catch (_) {
          // Network error — keep the scan and retry next time
          await _recordFailure(box, i, data, attempts);
        }
      }

      // Delete synced/dropped entries in reverse order to preserve indices
      for (final idx in indicesToDelete.reversed) {
        await box.deleteAt(idx);
      }

      if (indicesToDelete.isNotEmpty) {
        debugPrint(
            '✅ OfflineScanSync: removed ${indicesToDelete.length} entry(s) from queue');
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Keeps a failed scan queued for the next attempt. Scans are never dropped;
  /// staff are alerted once the failure count reaches [_alertAfterAttempts].
  static Future<void> _recordFailure(
    Box box,
    int index,
    Map<String, dynamic> data,
    int attempts,
  ) async {
    final nextAttempts = attempts + 1;
    final updated = Map<String, dynamic>.from(data);
    updated['attempts'] = nextAttempts;
    updated['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
    await box.putAt(index, updated);

    if (nextAttempts == _alertAfterAttempts) {
      _alert(
        'An offline scan has failed $_alertAfterAttempts times and is still '
        'queued. It will keep retrying. Check the connection or sign in again.',
      );
    }
  }

  /// Shows the server result for a replayed scan so staff see the final outcome.
  static void _showReplayResult(String responseBody) {
    final String? result;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return;
      result = decoded['result']?.toString();
    } catch (_) {
      return;
    }
    if (result == null) return;
    _alert(
      'Offline scan synced. Server result: '
      '${result.replaceAll('_', ' ').toUpperCase()}.',
    );
  }

  static void _alert(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  /// Returns how many scans are still pending sync.
  static Future<int> getPendingCount() async {
    final box = await _openQueueBox();
    return box.length;
  }
}

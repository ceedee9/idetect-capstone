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
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'fraud_flag_sync_service.dart';
import 'retry_policy.dart';
import 'sync_notifier.dart';

class OfflineScanSyncService {
  static const String _queueBoxName = 'pending_offline_scans_v2';
  static const String _legacyQueueBoxName = 'pending_offline_scans';
  static const String _queueKeyName = 'offline_queue_key';
  static const String _imageDirName = 'offline_scan_images';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<Box>? _queueBoxFuture;
  static const int _alertAfterAttempts = 5;
  static const Duration _retryTick = Duration(seconds: 30);

  /// Lives on the root MaterialApp so alerts show on any screen.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      SyncNotifier.messengerKey;

  static StreamSubscription<ConnectivityResult>? _connectivitySub;
  static Timer? _retryTimer;
  static bool _isSyncing = false;
  // Token the server refused (401). Retries wait until a new login replaces it.
  static String? _rejectedToken;

  /// Call once from main() after LocalDatabase.init().
  static Future<void> init() async {
    await _openQueueBox();

    // Attempt an immediate flush in case scans were queued in a previous session
    await syncPendingScans(force: true);

    // Retry on a timer too, so a scan queued while the server was down (but the
    // phone still had signal) is not left waiting for a connectivity change.
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryTick, (_) => syncPendingScans());

    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        debugPrint(
            '📶 OfflineScanSync: connectivity restored — flushing queue');
        await syncPendingScans(force: true);
      }
    });
  }

  /// Stop the connectivity listener and retry timer (call on app shutdown).
  static void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Queue a confirmed offline scan so it is later replayed to the API.
  /// Call this from ResultScreen when the user saves an offline verification result.
  ///
  /// [pendingFlag] ({'beneficiary_type', 'notes'}) holds a fraud report the
  /// cashier made while offline. It is sent once the scan is recorded, because
  /// a flag needs the server's verification record.
  static Future<void> queueOfflineScan({
    required String idNumber,
    required String beneficiaryType,
    required String? extractedName,
    required String? extractedDob,
    required double? ocrConfidence,
    required String? imagePath,
    required int scannedAt,
    String? ocrHeaderText,
    Map<String, String?>? pendingFlag,
  }) async {
    final box = await _openQueueBox();
    final clientScanId = _newClientScanId();
    await box.add({
      'client_scan_id': clientScanId,
      'id_number': idNumber,
      'beneficiary_type': beneficiaryType,
      'extracted_name': extractedName,
      'extracted_dob': extractedDob,
      'ocr_confidence': ocrConfidence,
      'ocr_header_text': ocrHeaderText,
      'image_path': await _keepImage(imagePath, clientScanId),
      'scanned_at': scannedAt,
      'queued_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
      // Lets a different account on the same phone skip this scan.
      'establishment_id': ApiService.currentUser?['id']?.toString(),
      if (pendingFlag != null) 'pending_flag': pendingFlag,
    });
    debugPrint('📥 OfflineScanSync: queued scan for $idNumber');

    // Attempt immediate flush (may succeed if device is back online by save time)
    await syncPendingScans();
  }

  /// The result screen deletes its temporary photo after saving, but a queued
  /// scan still needs the photo for the later upload. Copy it to private app
  /// storage; it is deleted once the scan is sent.
  static Future<String?> _keepImage(String? imagePath, String scanId) async {
    if (imagePath == null) return null;
    try {
      final source = dart_io.File(imagePath);
      if (!await source.exists()) return null;
      final root = await getApplicationSupportDirectory();
      final dir = dart_io.Directory('${root.path}/$_imageDirName');
      await dir.create(recursive: true);
      final copy = await source.copy('${dir.path}/$scanId.jpg');
      return copy.path;
    } catch (_) {
      return imagePath;
    }
  }

  static Future<void> _deleteKeptImage(String? imagePath) async {
    if (imagePath == null || !imagePath.contains(_imageDirName)) return;
    try {
      final file = dart_io.File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
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

  /// Replay all queued offline scans to the API. [force] skips the retry wait
  /// (used when connectivity returns); the periodic timer respects it.
  static Future<void> syncPendingScans({bool force = false}) async {
    if (_isSyncing) return;
    final token = ApiService.token;
    if (token == null || token == _rejectedToken) return;
    final accountId = ApiService.currentUser?['id']?.toString();

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

        // A scan queued by another account stays queued for that account.
        final owner = data['establishment_id']?.toString();
        if (owner != null && accountId != null && owner != accountId) continue;

        final attempts = (data['attempts'] as int?) ?? 0;
        final due = isRetryDue(
          attempts: attempts,
          lastAttemptMs: data['last_attempt'] as int?,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          force: force,
        );
        if (!due) continue;

        try {
          final idNumber = data['id_number'] as String;
          final beneficiaryType = data['beneficiary_type'] as String;
          final extractedName = data['extracted_name'] as String?;
          final extractedDob = data['extracted_dob'] as String?;
          final ocrConfidence = (data['ocr_confidence'] as num?)?.toDouble();
          final ocrHeaderText = data['ocr_header_text'] as String?;
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
                  if (ocrHeaderText != null && ocrHeaderText.isNotEmpty)
                    'ocr_raw_text': ocrHeaderText,
                }),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            indicesToDelete.add(i);
            debugPrint('✅ OfflineScanSync: flushed scan $idNumber');
            await _deleteKeptImage(imagePath);
            _showReplayResult(response.body);
            await _sendPendingFlag(data, idNumber, response.body);
          } else if (response.statusCode == 401) {
            // Login expired. Wait for a new login instead of retrying.
            _rejectedToken = token;
            break;
          } else if (response.statusCode == 429) {
            // Rate limited. Not a failed attempt; try again on a later tick.
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

  /// Sends the fraud report the cashier made while offline, now that the
  /// server has a verification record for the scan. A temporary failure is
  /// queued by the flag service; a permanent one is reported to staff.
  static Future<void> _sendPendingFlag(
    Map<String, dynamic> data,
    String idNumber,
    String responseBody,
  ) async {
    final pending = data['pending_flag'];
    if (pending is! Map) return;
    try {
      final decoded = jsonDecode(responseBody);
      final verificationId =
          decoded is Map ? decoded['verification_id']?.toString() : null;
      final beneficiaryType = pending['beneficiary_type']?.toString();
      if (verificationId == null || beneficiaryType == null) {
        _alert('The fraud report for a synced offline scan could not be sent. '
            'Please flag the ID again.');
        return;
      }
      final result = await FraudFlagSyncService.submitFlagNow(
        verificationLogId: verificationId,
        idNumberFlagged: idNumber,
        beneficiaryType: beneficiaryType,
        notes: pending['notes']?.toString(),
      );
      if (result['error'] != null) {
        _alert('The fraud report for a synced offline scan was rejected: '
            '${result['error']}');
      }
    } catch (_) {
      _alert('The fraud report for a synced offline scan could not be sent. '
          'Please flag the ID again.');
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

  static void _alert(String message) => SyncNotifier.show(message);

  /// Returns how many scans are still pending sync.
  static Future<int> getPendingCount() async {
    final box = await _openQueueBox();
    return box.length;
  }
}

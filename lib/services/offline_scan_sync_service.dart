// lib/services/offline_scan_sync_service.dart
//
// Problem A fix: Two Parallel and Inconsistent Data Stores
//
// When the cashier performs a scan but the API is unreachable, the verification
// result is served from the local Hive cache. The scan event is saved to the
// local Hive DB but never reaches PostgreSQL verification_logs. This service
// queues those offline scans and replays them to POST /api/verification/scan
// when connectivity is restored, ensuring every confirmed scan appears in the
// central database and web-portal analytics.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as dart_io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class OfflineScanSyncService {
  static const String _pendingScansBox = 'pending_offline_scans';
  static const int _maxAttempts = 5;

  static StreamSubscription<ConnectivityResult>? _connectivitySub;
  static bool _isSyncing = false;

  /// Call once from main() after LocalDatabase.init().
  static Future<void> init() async {
    await Hive.openBox(_pendingScansBox);

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
    final box = await Hive.openBox(_pendingScansBox);
    await box.add({
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

  /// Replay all queued offline scans to the API.
  static Future<void> syncPendingScans() async {
    if (_isSyncing) return;
    final token = ApiService.token;
    if (token == null) return;

    _isSyncing = true;
    try {
      final box = await Hive.openBox(_pendingScansBox);
      if (box.isEmpty) return;

      final indicesToDelete = <int>[];

      for (var i = 0; i < box.length; i++) {
        final entry = box.getAt(i);
        if (entry is! Map) {
          indicesToDelete.add(i); // corrupted entry — discard
          continue;
        }

        final data = Map<String, dynamic>.from(entry);
        final attempts = (data['attempts'] as int?) ?? 0;

        // Give up after too many failures (e.g. token permanently revoked)
        if (attempts >= _maxAttempts) {
          indicesToDelete.add(i);
          debugPrint(
              '⚠️ OfflineScanSync: dropped scan after $_maxAttempts failed attempts');
          continue;
        }

        try {
          final idNumber = data['id_number'] as String;
          final beneficiaryType = data['beneficiary_type'] as String;
          final extractedName = data['extracted_name'] as String?;
          final extractedDob = data['extracted_dob'] as String?;
          final ocrConfidence = (data['ocr_confidence'] as num?)?.toDouble();
          final imagePath = data['image_path'] as String?;

          final normalizedId =
              idNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final normalizedConfidence = ocrConfidence == null
              ? null
              : (ocrConfidence <= 1.0 ? ocrConfidence * 100.0 : ocrConfidence)
                  .clamp(0.0, 100.0);

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
          } else if (response.statusCode == 401) {
            // Token expired — stop trying until re-login
            stop();
            break;
          } else {
            // Server error — increment attempt counter and retry next time
            final updated = Map<String, dynamic>.from(data);
            updated['attempts'] = attempts + 1;
            updated['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
            await box.putAt(i, updated);
          }
        } catch (_) {
          // Network error — increment attempt counter
          final updated = Map<String, dynamic>.from(data);
          updated['attempts'] = ((data['attempts'] as int?) ?? 0) + 1;
          updated['last_attempt'] = DateTime.now().millisecondsSinceEpoch;
          await box.putAt(i, updated);
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

  /// Returns how many scans are still pending sync.
  static Future<int> getPendingCount() async {
    final box = await Hive.openBox(_pendingScansBox);
    return box.length;
  }
}

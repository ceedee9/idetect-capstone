// lib/services/status_sync_service.dart
//
// REQ-2.9.1: Propagate credential status changes to all connected Client Portal
//            instances within seconds of the database update.
// REQ-2.9.3: Synchronize pending status updates to offline Client Portals
//            automatically upon connectivity restoration.
//
// Strategy: Poll GET /verification/status-updates?since=<ms> every 8 seconds
// while connected. On connectivity restoration, immediately sync (REQ-2.9.3).
// Results are stored in the local blocked_ids Hive box so that verifyId() can
// return INVALID instantly even before reaching the server.

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/datasources/local/local_database.dart';
import 'api_service.dart';

class StatusSyncService {
  static const Duration _pollInterval = Duration(seconds: 8);

  static Timer? _pollTimer;
  static StreamSubscription<ConnectivityResult>? _connectivitySub;
  static int _lastSyncMs = 0; // Unix ms of the last successful sync
  static bool _isSyncing = false;

  /// Call once from main() after LocalDatabase.init() and ApiService.loadToken().
  static Future<void> init() async {
    // Clear the blocked-ID cache once if its key format changed, then restore
    // the sync cursor so we don't re-request all updates after every cold start.
    await LocalDatabase.migrateBlockedIdKeysIfNeeded();
    _lastSyncMs = await LocalDatabase.loadLastSyncMs();

    // Attempt an immediate sync on startup (catches any changes while offline)
    await _sync();

    // Poll every 8 seconds (propagation within seconds — REQ-2.9.1)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _sync());

    // REQ-2.9.3: sync immediately whenever connectivity is restored
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        debugPrint('📶 Connectivity restored — syncing status updates...');
        await _sync();
      }
    });
  }

  /// Stop polling (call on logout).
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _lastSyncMs = 0;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<void> _sync() async {
    if (_isSyncing) return;
    final token = ApiService.token;
    if (token == null) return; // Not logged in yet

    _isSyncing = true;
    try {
      var hasMore = true;
      while (hasMore) {
        final uri = Uri.parse(
          '${ApiService.baseUrl}/verification/status-updates?since=$_lastSyncMs',
        );

        final response = await http.get(uri, headers: {
          'Authorization': 'Bearer $token'
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 401) {
          // Token expired — stop polling until re-login
          stop();
          return;
        }
        if (response.statusCode != 200) return;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updates = (data['updates'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (updates != null && updates.isNotEmpty) {
          await LocalDatabase.applyStatusUpdates(updates);
          debugPrint(
              '✅ StatusSync: applied ${updates.length} status update(s)');
        }

        // Advance the cursor and persist it so it survives app restarts. While
        // has_more is true, next_since is the last row's timestamp, so the next
        // request continues from there instead of skipping rows past the page.
        final nextSince = data['next_since'];
        if (nextSince is! int || nextSince <= _lastSyncMs) return;
        _lastSyncMs = nextSince;
        await LocalDatabase.saveLastSyncMs(_lastSyncMs);
        hasMore = data['has_more'] == true;
      }
    } catch (e) {
      // Network errors are expected when offline — silently ignore
      debugPrint('⚠️ StatusSync: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const String _scannedIDsBox = 'scanned_ids';
  // REQ-2.9.1 / REQ-2.9.3: local cache of revoked/suspended beneficiary IDs
  static const String _blockedIDsBox = 'blocked_ids';

  static Future init() async {
    await Hive.initFlutter();
    await Hive.openBox(_scannedIDsBox);
    await Hive.openBox(_blockedIDsBox);
  }

  static Future openBox(String boxName) async {
    return await Hive.openBox(boxName);
  }

  /// Insert a scanned ID into the local database.
  ///
  /// [verificationStatus] maps directly to the VerificationStatus enum name:
  ///   'valid' | 'invalid' | 'suspicious' | 'manualReview' | 'error'
  /// Defaults to 'manualReview' for records saved before this field existed.
  Future<void> insertScannedID({
    required String fullName,
    required String idNumber,
    required int? age,
    required String sex,
    required String dateIssued,
    required String controlNumber,
    required String imagePath,
    required String idType,
    required int timestamp,
    String verificationStatus = 'manualReview', // ── Priority 3 / 6 ──
    String? establishmentId,
  }) async {
    final box = await Hive.openBox(_scannedIDsBox);

    final data = {
      'fullName': fullName,
      'idNumber': idNumber,
      'age': age,
      'sex': sex,
      'dateIssued': dateIssued,
      'controlNumber': controlNumber,
      'imagePath': imagePath,
      'idType': idType,
      'timestamp': timestamp,
      'verificationStatus': verificationStatus, // ── Priority 3 / 6 ──
      if (establishmentId != null) 'establishmentId': establishmentId,
    };

    await box.add(data);
  }

  /// Get all scanned IDs from the local database, newest first.
  /// If [establishmentId] is provided, only returns records for that establishment.
  Future<List<Map<String, dynamic>>> getAllScannedIDs(
      {String? establishmentId}) async {
    final box = await Hive.openBox(_scannedIDsBox);

    final List<Map<String, dynamic>> records = [];

    for (var i = 0; i < box.length; i++) {
      final data = box.getAt(i);
      if (data is Map) {
        final record = Map<String, dynamic>.from(data);
        // Filter by establishment if specified.
        // Records without establishmentId (legacy) are excluded when filtering.
        if (establishmentId != null) {
          if (record['establishmentId']?.toString() == establishmentId) {
            records.add(record);
          }
        } else {
          records.add(record);
        }
      }
    }

    // Sort by timestamp (newest first)
    records.sort((a, b) {
      final aTime = a['timestamp'] as int? ?? 0;
      final bTime = b['timestamp'] as int? ?? 0;
      return bTime.compareTo(aTime);
    });

    return records;
  }

  /// Delete a scanned ID from the database by its Hive index.
  Future<void> deleteScannedID(int index) async {
    final box = await Hive.openBox(_scannedIDsBox);
    await box.deleteAt(index);
  }

  /// Clear all scanned IDs from the database.
  Future<void> clearAllScannedIDs() async {
    final box = await Hive.openBox(_scannedIDsBox);
    await box.clear();
  }

  /// REQ-2.5.6: Find the most recent cached verification for a given ID number.
  /// Returns null if no matching record exists in cache.
  Future<Map<String, dynamic>?> findCachedVerification(String idNumber) async {
    final normalized =
        idNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.isEmpty) return null;

    final box = await Hive.openBox(_scannedIDsBox);
    Map<String, dynamic>? best;
    int bestTime = 0;

    for (var i = 0; i < box.length; i++) {
      final data = box.getAt(i);
      if (data is Map) {
        final stored = (data['idNumber'] ?? '')
            .toString()
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (stored == normalized) {
          final ts = (data['timestamp'] as int?) ?? 0;
          if (ts > bestTime) {
            bestTime = ts;
            best = Map<String, dynamic>.from(data);
          }
        }
      }
    }
    return best;
  }

  // ── Blocked IDs cache (REQ-2.9.1 / REQ-2.9.3) ────────────────────────────

  /// Upsert a batch of status updates received from the server.
  /// [updates] is a list of maps: { 'id_number': String, 'status': String }
  static Future<void> applyStatusUpdates(
      List<Map<String, dynamic>> updates) async {
    final box = await Hive.openBox(_blockedIDsBox);
    for (final update in updates) {
      final raw = (update['id_number'] ?? '').toString();
      final normalized = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (normalized.isEmpty) continue;
      final status = (update['status'] ?? '').toString();
      // Store all statuses so we can also clear a previously-blocked ID
      // that has been restored to 'active'.
      await box.put(normalized, status);
    }
  }

  /// Check whether an ID number is locally known to be blocked (revoked or suspended).
  /// Returns the cached status string, or null if not in cache.
  static Future<String?> getCachedStatus(String idNumber) async {
    final normalized =
        idNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.isEmpty) return null;
    final box = await Hive.openBox(_blockedIDsBox);
    final status = box.get(normalized);
    return status?.toString();
  }
}

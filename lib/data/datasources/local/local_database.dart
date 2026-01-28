import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const String _scannedIDsBox = 'scanned_ids';

  static Future init() async {
    await Hive.initFlutter();
    // Open the scanned IDs box
    await Hive.openBox(_scannedIDsBox);
  }

  static Future openBox(String boxName) async {
    return await Hive.openBox(boxName);
  }

  /// Insert a scanned ID into the database
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
    };

    await box.add(data);
  }

  /// Get all scanned IDs from the database
  Future<List<Map<String, dynamic>>> getAllScannedIDs() async {
    final box = await Hive.openBox(_scannedIDsBox);

    final List<Map<String, dynamic>> records = [];

    for (var i = 0; i < box.length; i++) {
      final data = box.getAt(i);
      if (data is Map) {
        records.add(Map<String, dynamic>.from(data));
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

  /// Delete a scanned ID from the database
  Future<void> deleteScannedID(int index) async {
    final box = await Hive.openBox(_scannedIDsBox);
    await box.deleteAt(index);
  }

  /// Clear all scanned IDs from the database
  Future<void> clearAllScannedIDs() async {
    final box = await Hive.openBox(_scannedIDsBox);
    await box.clear();
  }
}

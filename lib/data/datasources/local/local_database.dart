import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static Future init() async {
    await Hive.initFlutter();
    // Register adapters here later
  }

  static Future openBox(String boxName) async {
    return await Hive.openBox(boxName);
  }
}

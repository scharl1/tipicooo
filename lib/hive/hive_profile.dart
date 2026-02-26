import 'package:hive_flutter/hive_flutter.dart';

class HiveProfile {
  static const String boxName = 'profile';

  static Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  static String? loadField(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    return Hive.box(boxName).get(key)?.toString();
  }

  static dynamic loadDynamicField(String key) {
    if (!Hive.isBoxOpen(boxName)) return null;
    return Hive.box(boxName).get(key);
  }

  static Future<void> saveField(String key, dynamic value) async {
    await ensureOpen();
    await Hive.box(boxName).put(key, value);
  }

  static Future<void> deleteField(String key) async {
    await ensureOpen();
    await Hive.box(boxName).delete(key);
  }
}

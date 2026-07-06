import 'package:hive_flutter/hive_flutter.dart';

class HiveStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  static Future<Box<dynamic>> openBox(String boxName) async {
    return await Hive.openBox(boxName);
  }

  static Future<void> put(String boxName, String key, dynamic value) async {
    final box = await openBox(boxName);
    await box.put(key, value);
  }

  static Future<dynamic> get(String boxName, String key) async {
    final box = await openBox(boxName);
    return box.get(key);
  }

  static Future<bool> containsKey(String boxName, String key) async {
    final box = await openBox(boxName);
    return box.containsKey(key);
  }

  static Future<void> delete(String boxName, String key) async {
    final box = await openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clear(String boxName) async {
    final box = await openBox(boxName);
    await box.clear();
  }

  static Future<List<dynamic>> getAll(String boxName) async {
    final box = await openBox(boxName);
    return box.values.toList();
  }

  static Future<void> putAll(String boxName, Map<dynamic, dynamic> entries) async {
    final box = await openBox(boxName);
    await box.putAll(entries);
  }

  static Future<void> closeBox(String boxName) async {
    final box = await openBox(boxName);
    await box.close();
  }

  static Future<void> closeAllBoxes() async {
    await Hive.close();
  }
}

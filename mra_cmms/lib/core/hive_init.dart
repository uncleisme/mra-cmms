import 'package:hive_flutter/hive_flutter.dart';

class HiveInit {
  static Future<void> openCoreBoxes() async {
    await Future.wait([
      Hive.openBox<Map>('profiles_box'),
      Hive.openBox<Map>('leaves_box'),
      Hive.openBox<Map>('work_orders_box'),
      Hive.openBox<Map>('assets_box'),
      Hive.openBox<Map>('locations_box'),
      Hive.openBox('settings_box'),
    ]);
  }
}

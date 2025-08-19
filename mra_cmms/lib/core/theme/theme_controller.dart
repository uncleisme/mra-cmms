import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(_loadInitial());

  static const _boxName = 'settings_box';
  static const _key = 'themeMode';

  static ThemeMode _loadInitial() {
    final box = Hive.box(_boxName);
    final value = box.get(_key) as String?;
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    final box = Hive.box(_boxName);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    box.put(_key, str);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

import 'package:flutter/material.dart';

class AppColors {
  static const seed = Color(0xFF3F51B5); // Indigo 500

  static ColorScheme lightScheme() => ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  static ColorScheme darkScheme() => ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
}

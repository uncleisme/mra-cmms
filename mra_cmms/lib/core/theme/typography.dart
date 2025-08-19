import 'package:flutter/material.dart';

class AppTypography {
  static TextTheme textTheme(TextTheme base) => base.copyWith(
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.3),
      );
}

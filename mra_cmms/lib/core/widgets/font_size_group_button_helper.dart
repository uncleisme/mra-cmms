// Helper for GroupButton font size selection
import 'package:flutter/material.dart';
import '../../main.dart' show AppFontSize;

List<String> fontSizeLabels = ['Small', 'Medium', 'Large'];

AppFontSize fontSizeFromIndex(int index) => AppFontSize.values[index];
int indexFromFontSize(AppFontSize size) => AppFontSize.values.indexOf(size);

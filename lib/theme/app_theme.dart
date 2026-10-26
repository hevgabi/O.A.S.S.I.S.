// Shared app theme: define the common styles for colors, text, and controls.
import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.text,
    ),
  );
}
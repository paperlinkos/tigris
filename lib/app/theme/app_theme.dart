import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surface,
        primary: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
        outline: AppColors.border,
      ),
      dividerColor: AppColors.borderSubtle,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1.0,
        space: 1.0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 20.0,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 20.0,
      ),
      splashColor: Colors.transparent,
      highlightColor: AppColors.surfaceSubtle,
    );
  }
}

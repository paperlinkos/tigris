import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppContextColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBg => isDarkMode ? AppColors.darkBackground : AppColors.background;
  Color get appSurface => isDarkMode ? AppColors.darkSurface : AppColors.surface;
  Color get appSurfaceSubtle => isDarkMode ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle;
  Color get appTextPrimary => isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get appTextSecondary => isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get appTextTertiary => isDarkMode ? AppColors.darkTextTertiary : AppColors.textTertiary;
  Color get appBorder => isDarkMode ? AppColors.darkBorder : AppColors.border;
  Color get appBorderSubtle => isDarkMode ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
  Color get appSidebar => isDarkMode ? AppColors.darkSidebar : AppColors.sidebar;
  Color get appRaised => isDarkMode ? AppColors.darkRaised : AppColors.raised;
  Color get appRowHover => isDarkMode ? AppColors.darkRowHover : AppColors.rowHover;
  Color get appRowSelected => isDarkMode ? AppColors.darkRowSelected : AppColors.rowSelected;
  Color get appLineStrong => isDarkMode ? AppColors.darkLineStrong : AppColors.lineStrong;
}

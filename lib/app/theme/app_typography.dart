import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle display({
    Color color = AppColors.textPrimary,
    double fontSize = 32.0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.25,
      letterSpacing: -0.5,
    );
  }

  static TextStyle title({
    Color color = AppColors.textPrimary,
    double fontSize = 22.0,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
      letterSpacing: -0.2,
    );
  }

  static TextStyle subtitle({
    Color color = AppColors.textSecondary,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
      letterSpacing: -0.1,
    );
  }

  static TextStyle body({
    Color color = AppColors.textPrimary,
    double fontSize = 17.0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.7,
      letterSpacing: 0.1,
    );
  }

  static TextStyle uiLabel({
    Color color = AppColors.textSecondary,
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  static TextStyle uiHeadline({
    Color color = AppColors.textPrimary,
    double fontSize = 15.0,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.1,
    );
  }
}

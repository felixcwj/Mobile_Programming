import 'package:flutter/material.dart';

/// UI 스타일을 한곳에서 관리합니다.
class AppColors {
  static const primary = Color(0xFF555CE8);
  static const primarySoft = Color(0xFFEEF0FF);
  static const dark = Color(0xFF1B2340);
  static const background = Color(0xFFF7F8FC);
  static const border = Color(0xFFE9EBF3);
  static const muted = Color(0xFF798198);
  static const success = Color(0xFF209B74);
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.dark),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.dark),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.dark, height: 1.5),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.dark,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: AppColors.primarySoft,
    side: BorderSide(color: AppColors.border),
    labelStyle: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600),
    showCheckmark: false,
  ),
  dividerColor: AppColors.border,
);

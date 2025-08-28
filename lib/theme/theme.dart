import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryLightColor = Color(0xFF5C6BC0); // Indigo shade
  static const Color _primaryDarkColor = Color(0xFF7986CB); // Lighter indigo for dark theme
  static const Color _secondaryLightColor = Color(0xFF9575CD); // Purple shade
  static const Color _secondaryDarkColor = Color(0xFFB39DDB); // Lighter purple for dark theme

  // Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true, // Use Material 3
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primaryLightColor,
      secondary: _secondaryLightColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      // Create a soft blue/purple gradient feel with these colors
      surface: Colors.white,
      background: Colors.grey.shade50,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _primaryLightColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryLightColor,
        foregroundColor: Colors.white,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: _primaryLightColor,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: _primaryLightColor,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true, // Use Material 3
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primaryDarkColor,
      secondary: _secondaryDarkColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      // Create a soft blue/purple gradient feel with these colors
      surface: const Color(0xFF121212),
      background: const Color(0xFF1E1E1E),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: _primaryDarkColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryDarkColor,
        foregroundColor: Colors.black,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: _primaryDarkColor,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: _primaryDarkColor,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

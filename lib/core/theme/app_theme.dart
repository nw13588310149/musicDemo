import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF00C9A4);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Harmony',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Color(0xFF171A20),
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Color(0xFF171A20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(45)),
          backgroundColor: const WidgetStatePropertyAll(_primaryColor),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

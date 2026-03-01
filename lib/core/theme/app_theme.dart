import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF2BEE79); // From Stitch MCP: #2bee79
  static const Color primaryDark = Color(0xFF1EBB5D); // Slightly darker for hover/pressed states
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color secondaryBg = Color(0xFFF3F4F6);
  
  // Cards
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1F2937);
  
  // Text
  static const Color textLight = Color(0xFF1F2937);
  static const Color textDark = Color(0xFFF9FAFB);
  static const Color mutedLight = Color(0xFF6B7280);
  static const Color mutedDark = Color(0xFF9CA3AF);
  
  // Accents
  static const Color accentYellow = Color(0xFFFEF3C7);
  static const Color accentYellowText = Color(0xFF92400E);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        surface: backgroundLight,
        onSurface: textLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardColor: cardLight,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardLight,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: primary,
        unselectedItemColor: mutedLight,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: backgroundDark,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: cardDark,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primary,
        unselectedItemColor: mutedDark,
      ),
    );
  }
}

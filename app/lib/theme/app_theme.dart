import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🎨 Brand Colors (Agricultural Professional)
  static const Color primaryGreen = Color(0xFF1B5E20); // Deep Forest Green
  static const Color leafGreen = Color(0xFF388E3C);    // Vibrant Leaf Green
  static const Color earthBeige = Color(0xFFF1F8E9);    // Soft Background Green
  static const Color accentSage = Color(0xFF81C784);    // Sage Accent
  
  // Light Mode Colors
  static const Color surfaceWhite = Color(0xFFFCFCFC);

  // Dark Mode Colors
  static const Color surfaceDark = Color(0xFF0F140F);
  static const Color cardDark = Color(0xFF1A1F1A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: leafGreen,
        surface: surfaceWhite,
        onSurface: const Color(0xFF1A1C19),
        primaryContainer: earthBeige,
        onPrimaryContainer: primaryGreen,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryGreen),
        headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryGreen),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.08)),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryGreen,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryGreen,
        primary: accentSage,
        secondary: leafGreen,
        surface: surfaceDark,
        onSurface: Colors.white,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: accentSage),
        headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: accentSage),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        color: cardDark,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      scaffoldBackgroundColor: surfaceDark,
    );
  }

  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      shadowColor: primaryGreen.withValues(alpha: 0.3),
      textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
}

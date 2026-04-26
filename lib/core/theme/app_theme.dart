import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color primaryText = Color(0xFF000000);
  static const Color secondaryText = Color(0xFF615D59);
  static const Color mutedText = Color(0xFF9E9E9E);
  static const Color notionBlue = Color(0xFF0075DE);
  static const Color activeBlue = Color(0xFF005BAB);
  static const Color primaryBlue = Color(0xFF0075DE);
  static const Color warmWhite = Color(0xFFF6F5F4);
  static final Color whisperBorder = Colors.black.withValues(alpha: 0.1);

  static final List<BoxShadow> softCardShadow = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 4)),
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.027),
        blurRadius: 7.85,
        offset: const Offset(0, 2.025)),
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        blurRadius: 2.93,
        offset: const Offset(0, 0.8)),
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.01),
        blurRadius: 1.04,
        offset: const Offset(0, 0.175)),
  ];

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: primaryText,
      colorScheme: const ColorScheme.light(
        primary: notionBlue,
        secondary: notionBlue,
        surface: surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: primaryText),
        titleTextStyle: GoogleFonts.urbanist(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: primaryText,
        ),
        toolbarTextStyle: GoogleFonts.urbanist(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: notionBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          textStyle:
              GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: () {
        final base = GoogleFonts.urbanistTextTheme()
            .apply(bodyColor: primaryText, displayColor: primaryText);
        return base.copyWith(
          displayLarge: base.displayLarge?.copyWith(letterSpacing: -1),
          displayMedium: base.displayMedium?.copyWith(letterSpacing: -1),
          displaySmall: base.displaySmall?.copyWith(letterSpacing: -1),
          headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -1),
          headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -1),
          headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -1),
          titleLarge: base.titleLarge?.copyWith(letterSpacing: -1),
        );
      }(),
    );
  }
}

class AppThemeDark {
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B0);
  static const Color mutedText = Color(0xFF808080);
  static const Color notionBlue = Color(0xFF3B82F6);
  static const Color activeBlue = Color(0xFF097FE8);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color warmWhite = Color(0xFF2A2A2A);
  static final Color whisperBorder = Colors.white.withValues(alpha: 0.1);

  static final List<BoxShadow> softCardShadow = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 18,
        offset: const Offset(0, 4)),
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 7.85,
        offset: const Offset(0, 2.025)),
  ];

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: primaryText,
      colorScheme: const ColorScheme.dark(
        primary: notionBlue,
        secondary: notionBlue,
        surface: surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: primaryText),
        titleTextStyle: GoogleFonts.urbanist(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: primaryText,
        ),
        toolbarTextStyle: GoogleFonts.urbanist(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: notionBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          textStyle:
              GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: () {
        final base = GoogleFonts.urbanistTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: primaryText, displayColor: primaryText);
        return base.copyWith(
          displayLarge: base.displayLarge?.copyWith(letterSpacing: -1),
          displayMedium: base.displayMedium?.copyWith(letterSpacing: -1),
          displaySmall: base.displaySmall?.copyWith(letterSpacing: -1),
          headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -1),
          headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -1),
          headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -1),
          titleLarge: base.titleLarge?.copyWith(letterSpacing: -1),
        );
      }(),
    );
  }
}

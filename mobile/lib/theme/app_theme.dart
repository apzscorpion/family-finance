import 'package:flutter/material.dart';

/// Nocturne Design System Theme Tokens & Styles
class AppTheme {
  // Brand & Background Colors
  static const Color bg = Color(0xFF161826);
  static const Color surface = Color(0xFF232532);
  static const Color text = Color(0xFFE9E9ED);
  static const Color textMuted = Color(0xFF9397AB);
  static const Color textSubtle = Color(0xFF75798C);
  static const Color divider = Color(0x29E9E9ED); // ~16% opacity

  // Accent Blurple Ramps (Hue 289)
  static const Color accent = Color(0xFF9184D9);
  static const Color accent100 = Color(0xFFF5F4FF);
  static const Color accent200 = Color(0xFFE7E5FE);
  static const Color accent300 = Color(0xFFD2CEFD);
  static const Color accent400 = Color(0xFFB5ABFC);
  static const Color accent500 = Color(0xFF968AE0);
  static const Color accent600 = Color(0xFF796CBF);
  static const Color accent700 = Color(0xFF5D5294);
  static const Color accent800 = Color(0xFF423A6A);
  static const Color accent900 = Color(0xFF2B2741);

  // Status & Financial Indicator Colors
  static const Color green = Color(0xFF34D399); // Income / Success (OKLCH green)
  static const Color greenBg = Color(0x2834D399);
  static const Color red = Color(0xFFF87171); // Expense / Danger
  static const Color redBg = Color(0x28F87171);
  static const Color amber = Color(0xFFFBBF24); // Warning / Review
  static const Color amberBg = Color(0x28FBBF24);

  // Elevation & Shadows
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0xFF3F424D),
    spreadRadius: 1,
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x8C000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  );

  // Gradient Backgrounds
  static const RadialGradient bgRadial = RadialGradient(
    center: Alignment(0, -0.6),
    radius: 0.8,
    colors: [Color(0xFF20233A), Color(0xFF161826)],
  );

  static const LinearGradient balanceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2B2D44), Color(0xFF232532)],
  );

  static const LinearGradient accentButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF796CBF), Color(0xFF423A6A)],
  );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        onPrimary: bg,
        onSurface: text,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text, fontSize: 15),
        bodyMedium: TextStyle(color: text, fontSize: 13),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
        titleLarge: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF3F424D), width: 1),
        ),
      ),
    );
  }
}

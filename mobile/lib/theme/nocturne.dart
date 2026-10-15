import 'package:flutter/material.dart';
import 'nocturne_palette.dart';

/// Nocturne design-system tokens, transcribed from `_ds/nocturne-*/styles.css`.
///
/// Default constants remain `const` to preserve compile-time evaluation across
/// the codebase, while [NocturnePalette.current] provides runtime theme access.
class Nocturne {
  Nocturne._();

  static NocturnePalette get palette => NocturnePalette.current;

  // ── Core roles (Default Nocturne Dark constants) ─────────────────────────
  static const Color bg = Color(0xFF161826);
  static const Color surface = Color(0xFF232532);
  static const Color text = Color(0xFFE9E9ED);
  static const Color accent = Color(0xFF9184D9);
  static const Color accent2 = Color(0xFFA7A1DB);

  /// `color-mix(in srgb, #e9e9ed 16%, transparent)`
  static const Color divider = Color(0x29E9E9ED);

  // ── Neutral ramp ────────────────────────────────────────────────────────
  static const Color neutral100 = Color(0xFFF3F5FE);
  static const Color neutral200 = Color(0xFFE4E7F5);
  static const Color neutral300 = Color(0xFFCFD3E5);
  static const Color neutral400 = Color(0xFFB2B6CA);
  static const Color neutral500 = Color(0xFF9397AB);
  static const Color neutral600 = Color(0xFF75798C);
  static const Color neutral700 = Color(0xFF595D6C);
  static const Color neutral800 = Color(0xFF3F424D);
  static const Color neutral900 = Color(0xFF292B31);

  // ── Accent ramp ─────────────────────────────────────────────────────────
  static const Color accent100 = Color(0xFFF5F4FF);
  static const Color accent200 = Color(0xFFE7E5FE);
  static const Color accent300 = Color(0xFFD2CEFD);
  static const Color accent400 = Color(0xFFB5ABFC);
  static const Color accent500 = Color(0xFF968AE0);
  static const Color accent600 = Color(0xFF796CBF);
  static const Color accent700 = Color(0xFF5D5294);
  static const Color accent800 = Color(0xFF423A6A);
  static const Color accent900 = Color(0xFF2B2741);

  // ── Secondary accent ramp ───────────────────────────────────────────────
  static const Color accent2100 = Color(0xFFF5F4FF);
  static const Color accent2200 = Color(0xFFE7E5FE);
  static const Color accent2300 = Color(0xFFD2CEFD);
  static const Color accent2400 = Color(0xFFB5AFE8);
  static const Color accent2500 = Color(0xFF9690C9);
  static const Color accent2600 = Color(0xFF7972A9);
  static const Color accent2700 = Color(0xFF5C5783);
  static const Color accent2800 = Color(0xFF423E5D);
  static const Color accent2900 = Color(0xFF2B293A);

  // ── Deck section grounds ────────────────────────────────────────────────
  static const Color section = Color(0xFF262A60);
  static const Color sectionGlow = Color(0xFF353B80);
  static const Color sectionGhost = Color(0xFF4C5397);

  // ── Type ────────────────────────────────────────────────────────────────
  static const String fontFamily = 'Inter';
  static const FontWeight headingWeight = FontWeight.w500;

  // ── Spacing ─────────────────────────────────────────────────────────────
  static const double space1 = 2.8;
  static const double space2 = 5.6;
  static const double space3 = 8.4;
  static const double space4 = 11.2;
  static const double space6 = 16.8;
  static const double space8 = 22.4;

  // ── Radii ───────────────────────────────────────────────────────────────
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 14;

  // ── Elevation ───────────────────────────────────────────────────────────
  static const Border edgeSm = Border.fromBorderSide(
    BorderSide(color: neutral800, width: 1),
  );

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const Border edgeMd = Border.fromBorderSide(
    BorderSide(color: neutral700, width: 1),
  );

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const Border edgeLg = Border.fromBorderSide(
    BorderSide(color: neutral500, width: 1),
  );

  // ── Helpers ─────────────────────────────────────────────────────────────
  static Color mix(Color c, double percent) =>
      c.withValues(alpha: (c.a) * (percent / 100));
}

/// Colours the v3 screens use that are not Nocturne roles.
class NocturneSemantic {
  NocturneSemantic._();

  static const Color income = Color(0xFF6CD79D);
  static const Color expense = Color(0xFFF08A8A);
  static const Color danger = expense;
  static const Color warning = Color(0xFFE8B45E);
  static const Color budgetOk = accentFill;
  static const Color accentFill = Nocturne.accent500;

  static Color tint(Color hue) => Nocturne.mix(hue, 22);
}

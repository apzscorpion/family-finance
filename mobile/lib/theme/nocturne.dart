import 'package:flutter/material.dart';

/// Nocturne design-system tokens, transcribed exactly from the handoff's
/// `_ds/nocturne-*/styles.css`. That file is the source of truth for the
/// system's look; values here must match it literally.
///
/// Anything the v3 screens need that is *not* a Nocturne token (per-screen
/// colours such as the income green, category hues, origin tints) lives in
/// [NocturneSemantic] below so the two stay distinguishable.
class Nocturne {
  Nocturne._();

  // ── Core roles ──────────────────────────────────────────────────────────
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

  // ── Deck section grounds (deck-scale fills, not interface colours) ──────
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
  /// `0 0 0 1px #3f424d` — a hairline edge, drawn as a border rather than a
  /// shadow because Flutter has no spread-only inset equivalent.
  static const Border edgeSm = Border.fromBorderSide(
    BorderSide(color: neutral800, width: 1),
  );

  /// `0 0 0 1px #595d6c, 0 6px 18px rgba(0,0,0,0.55)`
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const Border edgeMd = Border.fromBorderSide(
    BorderSide(color: neutral700, width: 1),
  );

  /// `0 0 0 1px #9397ab, 0 16px 40px rgba(0,0,0,0.65)`
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const Border edgeLg = Border.fromBorderSide(
    BorderSide(color: neutral500, width: 1),
  );

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// CSS `color-mix(in srgb|oklch, <color> <pct>%, transparent)`.
  /// Mixing toward transparent is just an alpha scale on the source colour.
  static Color mix(Color c, double percent) =>
      c.withValues(alpha: (c.a) * (percent / 100));
}

/// Colours the v3 screens use that are not Nocturne roles. The design states
/// these inline (e.g. `oklch(0.80 0.13 158)` for received amounts); they are
/// converted to sRGB here once so the screens stay declarative.
class NocturneSemantic {
  NocturneSemantic._();

  /// `oklch(0.80 0.13 158)` — the "Received" / income green used in Activity,
  /// the toast tick and every income category. Converted from OKLCH, not eyeballed.
  static const Color income = Color(0xFF6CD79D);

  /// Expense / negative delta / delete actions.
  static const Color expense = Color(0xFFF08A8A);
  static const Color danger = expense;

  /// Warning, over-threshold budget bars, "due soon".
  static const Color warning = Color(0xFFE8B45E);

  /// Budget bar fills by state.
  static const Color budgetOk = accentFill;
  static const Color accentFill = Nocturne.accent500;

  /// Tint backgrounds: the design draws category chips as a ~22% wash of the
  /// category hue over the surface.
  static Color tint(Color hue) => Nocturne.mix(hue, 22);
}

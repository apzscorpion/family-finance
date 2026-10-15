import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum KpThemeId {
  dark('dark', 'Dark', 'Nocturne default'),
  light('light', 'Light', 'Bright & clean'),
  blue('blue', 'Blue', 'Deep harbour'),
  maroon('maroon', 'Maroon', 'Rich wine'),
  golden('golden', 'Golden', 'Warm brass'),
  yellow('yellow', 'Yellow', 'Sunny paper');

  final String id;
  final String name;
  final String sub;

  const KpThemeId(this.id, this.name, this.sub);
}

class NocturnePalette {
  final KpThemeId id;
  final String name;
  final String sub;
  final Color bg;
  final Color surface;
  final Color raised;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color faint;
  final Color line;
  final Color edge;
  final Color accent;
  final Color accentLight;
  final Color accentMuted;
  final Color tint;
  final Color tintEdge;
  final Color switchOn;
  final Color switchOnEdge;
  final Color switchKnob;
  final Color fab;
  final Color fabEdge;
  final Color fabIcon;
  final Color glow;
  final Color expense;
  final Color income;
  final Color warning;
  final Color accent500;
  final Color accent800;
  final Color headerBorder;
  final Color neutral300;
  final bool isDark;
  final double ck;

  const NocturnePalette({
    required this.id,
    required this.name,
    required this.sub,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.faint,
    required this.line,
    required this.edge,
    required this.accent,
    required this.accentLight,
    required this.accentMuted,
    required this.tint,
    required this.tintEdge,
    required this.switchOn,
    required this.switchOnEdge,
    required this.switchKnob,
    required this.fab,
    required this.fabEdge,
    required this.fabIcon,
    required this.glow,
    required this.expense,
    required this.income,
    required this.warning,
    required this.accent500,
    required this.accent800,
    required this.headerBorder,
    required this.neutral300,
    required this.isDark,
    required this.ck,
  });

  static const NocturnePalette dark = NocturnePalette(
    id: KpThemeId.dark,
    name: 'Dark',
    sub: 'Nocturne default',
    bg: Color(0xFF161826),
    surface: Color(0xFF232532),
    raised: Color(0xFF161826),
    text: Color(0xFFE9E9ED),
    muted: Color(0xFF9397AB),
    subtle: Color(0xFFB2B6CA),
    faint: Color(0xFF75798C),
    line: Color(0xFF292B31),
    edge: Color(0xFF3F424D),
    accent: Color(0xFF9184D9),
    accentLight: Color(0xFFE7E5FE),
    accentMuted: Color(0xFFD2CEFD),
    tint: Color(0xFF2B2741),
    tintEdge: Color(0xFF796CBF),
    switchOn: Color(0xFF5D5294),
    switchOnEdge: Color(0xFF968AE0),
    switchKnob: Color(0xFFF5F4FF),
    fab: Color(0xFF5D5294),
    fabEdge: Color(0xFFB5ABFC),
    fabIcon: Color(0xFFF5F4FF),
    glow: Color(0x739184D9),
    expense: Color(0xFFF08A8A),
    income: Color(0xFF6CD79D),
    warning: Color(0xFFE8B45E),
    accent500: Color(0xFF968AE0),
    accent800: Color(0xFF423A6A),
    headerBorder: Color(0xFF423A6A),
    neutral300: Color(0xFFCFD3E5),
    isDark: true,
    ck: 1.0,
  );

  static const NocturnePalette light = NocturnePalette(
    id: KpThemeId.light,
    name: 'Light',
    sub: 'Bright & clean',
    bg: Color(0xFFF3F3F7),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECECF2),
    text: Color(0xFF1D1E2B),
    muted: Color(0xFF6B6F82),
    subtle: Color(0xFF4F5263),
    faint: Color(0xFF8A8EA0),
    line: Color(0xFFECECF2),
    edge: Color(0xFFDCDDE6),
    accent: Color(0xFF6A5CC4),
    accentLight: Color(0xFF4A3FA0),
    accentMuted: Color(0xFF5D5294),
    tint: Color(0xFFECEBFB),
    tintEdge: Color(0xFF9184D9),
    switchOn: Color(0xFF6A5CC4),
    switchOnEdge: Color(0xFF5A4DB3),
    switchKnob: Color(0xFFFFFFFF),
    fab: Color(0xFF6A5CC4),
    fabEdge: Color(0xFF8476D8),
    fabIcon: Color(0xFFFFFFFF),
    glow: Color(0x526A5CC4),
    expense: Color(0xFFC94848),
    income: Color(0xFF1F8A55),
    warning: Color(0xFFA8700F),
    accent500: Color(0xFF6A5CC4),
    accent800: Color(0xFFD6D1F5),
    headerBorder: Color(0xFFDCD8F6),
    neutral300: Color(0xFF3A3D4C),
    isDark: false,
    ck: 0.70,
  );

  static const NocturnePalette blue = NocturnePalette(
    id: KpThemeId.blue,
    name: 'Blue',
    sub: 'Deep harbour',
    bg: Color(0xFF0F1A2B),
    surface: Color(0xFF18263B),
    raised: Color(0xFF0B1422),
    text: Color(0xFFE6EDF7),
    muted: Color(0xFF8B9BB3),
    subtle: Color(0xFFA9B7CC),
    faint: Color(0xFF6D7D95),
    line: Color(0xFF1F2E44),
    edge: Color(0xFF2C3D57),
    accent: Color(0xFF5B9CF0),
    accentLight: Color(0xFFCFE2FD),
    accentMuted: Color(0xFFA9CBF8),
    tint: Color(0xFF15304F),
    tintEdge: Color(0xFF3A74C0),
    switchOn: Color(0xFF2D5C99),
    switchOnEdge: Color(0xFF5B9CF0),
    switchKnob: Color(0xFFEAF3FF),
    fab: Color(0xFF2D5C99),
    fabEdge: Color(0xFF7FB2F5),
    fabIcon: Color(0xFFEAF3FF),
    glow: Color(0x665B9CF0),
    expense: Color(0xFFF08A8A),
    income: Color(0xFF6CD79D),
    warning: Color(0xFFE8B45E),
    accent500: Color(0xFF5B9CF0),
    accent800: Color(0xFF1F3E66),
    headerBorder: Color(0xFF24446C),
    neutral300: Color(0xFFC9D4E4),
    isDark: true,
    ck: 1.0,
  );

  static const NocturnePalette maroon = NocturnePalette(
    id: KpThemeId.maroon,
    name: 'Maroon',
    sub: 'Rich wine',
    bg: Color(0xFF1E1215),
    surface: Color(0xFF2B1A1F),
    raised: Color(0xFF170D10),
    text: Color(0xFFF1E6E8),
    muted: Color(0xFFA38F94),
    subtle: Color(0xFFC2AEB3),
    faint: Color(0xFF7F6A70),
    line: Color(0xFF3A252B),
    edge: Color(0xFF4C333A),
    accent: Color(0xFFC4566F),
    accentLight: Color(0xFFF6D3DB),
    accentMuted: Color(0xFFEAB0BD),
    tint: Color(0xFF4A1F2A),
    tintEdge: Color(0xFF9C3F55),
    switchOn: Color(0xFF7A2E40),
    switchOnEdge: Color(0xFFC4566F),
    switchKnob: Color(0xFFFDEEF1),
    fab: Color(0xFF7A2E40),
    fabEdge: Color(0xFFD97A90),
    fabIcon: Color(0xFFFDEEF1),
    glow: Color(0x66C4566F),
    expense: Color(0xFFF39A8A),
    income: Color(0xFF7FD6A2),
    warning: Color(0xFFE8B45E),
    accent500: Color(0xFFC4566F),
    accent800: Color(0xFF5A2533),
    headerBorder: Color(0xFF5A2533),
    neutral300: Color(0xFFDCCBCF),
    isDark: true,
    ck: 1.0,
  );

  static const NocturnePalette golden = NocturnePalette(
    id: KpThemeId.golden,
    name: 'Golden',
    sub: 'Warm brass',
    bg: Color(0xFF17140E),
    surface: Color(0xFF231F17),
    raised: Color(0xFF110F0A),
    text: Color(0xFFF2EBDC),
    muted: Color(0xFFA39A87),
    subtle: Color(0xFFC4BBA6),
    faint: Color(0xFF7D7563),
    line: Color(0xFF302A1F),
    edge: Color(0xFF433B2C),
    accent: Color(0xFFD4A84B),
    accentLight: Color(0xFFF5E3B8),
    accentMuted: Color(0xFFE8CD8C),
    tint: Color(0xFF3D321A),
    tintEdge: Color(0xFFA8833A),
    switchOn: Color(0xFF7A5F26),
    switchOnEdge: Color(0xFFD4A84B),
    switchKnob: Color(0xFFFFF6E0),
    fab: Color(0xFF7A5F26),
    fabEdge: Color(0xFFE0BC6A),
    fabIcon: Color(0xFFFFF6E0),
    glow: Color(0x61D4A84B),
    expense: Color(0xFFF08A8A),
    income: Color(0xFF7FD6A2),
    warning: Color(0xFFE8B45E),
    accent500: Color(0xFFD4A84B),
    accent800: Color(0xFF4D3F1E),
    headerBorder: Color(0xFF4D3F1E),
    neutral300: Color(0xFFDDD5C3),
    isDark: true,
    ck: 1.0,
  );

  static const NocturnePalette yellow = NocturnePalette(
    id: KpThemeId.yellow,
    name: 'Yellow',
    sub: 'Sunny paper',
    bg: Color(0xFFFBF8EC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF3EEDB),
    text: Color(0xFF26220F),
    muted: Color(0xFF6F6849),
    subtle: Color(0xFF4F4930),
    faint: Color(0xFF8E8763),
    line: Color(0xFFEFE9D4),
    edge: Color(0xFFE0D8B8),
    accent: Color(0xFFD9AD00),
    accentLight: Color(0xFF5E4A00),
    accentMuted: Color(0xFF7A6200),
    tint: Color(0xFFFDF1BF),
    tintEdge: Color(0xFFD9AD00),
    switchOn: Color(0xFFF2C513),
    switchOnEdge: Color(0xFFC99F00),
    switchKnob: Color(0xFF3A3200),
    fab: Color(0xFFF2C513),
    fabEdge: Color(0xFFC99F00),
    fabIcon: Color(0xFF26220F),
    glow: Color(0x59E6B800),
    expense: Color(0xFFC24A3A),
    income: Color(0xFF2A8A52),
    warning: Color(0xFFA86A00),
    accent500: Color(0xFFD9AD00),
    accent800: Color(0xFFF3E3A0),
    headerBorder: Color(0xFFEFE0A3),
    neutral300: Color(0xFF3F3A22),
    isDark: false,
    ck: 0.68,
  );

  static NocturnePalette forTheme(KpThemeId id) {
    switch (id) {
      case KpThemeId.dark:
        return dark;
      case KpThemeId.light:
        return light;
      case KpThemeId.blue:
        return blue;
      case KpThemeId.maroon:
        return maroon;
      case KpThemeId.golden:
        return golden;
      case KpThemeId.yellow:
        return yellow;
    }
  }

  static NocturnePalette current = dark;
}

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  KpThemeId _themeId = KpThemeId.dark;
  bool _matchDevice = false;
  bool _reduceMotion = false;

  KpThemeId get themeId => _themeId;
  NocturnePalette get palette => NocturnePalette.forTheme(_themeId);
  bool get matchDevice => _matchDevice;
  bool get reduceMotion => _reduceMotion;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('kp_theme_id') ?? 'dark';
      _matchDevice = prefs.getBool('kp_match_device') ?? false;
      _reduceMotion = prefs.getBool('kp_reduce_motion') ?? false;
      _themeId = KpThemeId.values.firstWhere(
        (t) => t.id == id,
        orElse: () => KpThemeId.dark,
      );
      NocturnePalette.current = palette;
      notifyListeners();
    } catch (_) {}
  }

  void setTheme(KpThemeId theme) {
    _themeId = theme;
    if (_matchDevice && theme != KpThemeId.dark && theme != KpThemeId.light) {
      _matchDevice = false;
    }
    NocturnePalette.current = palette;
    notifyListeners();
    _save();
  }

  void setMatchDevice(bool match, [Brightness? brightness]) {
    _matchDevice = match;
    if (match && brightness != null) {
      _themeId = brightness == Brightness.dark ? KpThemeId.dark : KpThemeId.light;
      NocturnePalette.current = palette;
    }
    notifyListeners();
    _save();
  }

  void updatePlatformBrightness(Brightness brightness) {
    if (!_matchDevice) return;
    final target = brightness == Brightness.dark ? KpThemeId.dark : KpThemeId.light;
    if (_themeId != target) {
      _themeId = target;
      NocturnePalette.current = palette;
      notifyListeners();
    }
  }

  void setReduceMotion(bool reduce) {
    _reduceMotion = reduce;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kp_theme_id', _themeId.id);
      await prefs.setBool('kp_match_device', _matchDevice);
      await prefs.setBool('kp_reduce_motion', _reduceMotion);
    } catch (_) {}
  }
}


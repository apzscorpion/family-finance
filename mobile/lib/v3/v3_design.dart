import 'package:flutter/material.dart';
import 'phosphor_icons.dart';

/// Design constants taken from `Family Spend Tracker v3.dc.html`.
///
/// Every colour the design states in OKLCH is converted to sRGB here rather
/// than approximated, so what renders matches the prototype exactly.

class V3Cat {
  final String key;
  final String name;

  /// Shorter label the design uses in tight chips; falls back to [name].
  final String short;
  final IconData icon;
  final Color color;

  const V3Cat(this.key, this.name, String? short, this.icon, this.color)
      : short = short ?? name;
}

class V3Member {
  final String id;
  final String name;

  /// "You", "Wife", "Brother" … shown next to the name in Who spent.
  final String rel;
  final String role;
  final double opening;
  final int hue;
  final double budget;
  final bool allowance;

  const V3Member({
    required this.id,
    required this.name,
    required this.rel,
    required this.role,
    required this.opening,
    required this.hue,
    required this.budget,
    this.allowance = false,
  });

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
  Color get color => V3Design.hue(hue);
}

class V3Source {
  final String id;
  final String name;
  final IconData icon;
  final int hue;

  const V3Source(this.id, this.name, this.icon, this.hue);

  Color get color => V3Design.hue(hue);
}

class V3Design {
  V3Design._();

  /// Avatar/source hues at the lightness the design uses, `oklch(0.64 0.11 H)`.
  static const Map<int, Color> _hues = {
    289: Color(0xFF8A80CB),
    345: Color(0xFFBB709B),
    200: Color(0xFF00A0A6),
    85: Color(0xFFAB8632),
    158: Color(0xFF49A072),
    50: Color(0xFFC1774C),
  };

  static Color hue(int h) => _hues[h] ?? const Color(0xFF8A80CB);

  /// The darker stop of the avatar gradient, `oklch(0.42 0.08 289)`.
  static const Color avatarDeep = Color(0xFF4C4576);

  static const Map<String, V3Cat> cats = {
    'groceries': V3Cat('groceries', 'Groceries', 'Grocery',
        PhRegular.basket, Color(0xFF64C897)),
    'dining': V3Cat('dining', 'Dining', null,
        PhRegular.forkKnife, Color(0xFFEE9A69)),
    'transport': V3Cat('transport', 'Transport', 'Travel',
        PhRegular.taxi, Color(0xFFA297EB)),
    'fuel': V3Cat('fuel', 'Fuel', null,
        PhRegular.gasPump, Color(0xFFE2C06D)),
    'shopping': V3Cat('shopping', 'Shopping', 'Shop',
        PhRegular.shoppingBag, Color(0xFFDE82B7)),
    'bills': V3Cat('bills', 'Bills', null,
        PhRegular.lightning, Color(0xFF67B5E1)),
    'home': V3Cat('home', 'Rent', null,
        PhRegular.houseLine, Color(0xFF839ED7)),
    'subs': V3Cat('subs', 'Subscriptions', 'Subs',
        PhRegular.playCircle, Color(0xFFBC8FDD)),
    'health': V3Cat('health', 'Health', null,
        PhRegular.firstAid, Color(0xFFEB8186)),
    'education': V3Cat('education', 'Education', 'School',
        PhRegular.graduationCap, Color(0xFF6BCAC9)),
    // Income categories all share oklch(0.80 0.13 158).
    'salary': V3Cat('salary', 'Salary', 'Salary',
        PhRegular.briefcase, Color(0xFF6CD79D)),
    'business': V3Cat('business', 'Business', 'Business',
        PhRegular.storefront, Color(0xFF6CD79D)),
    'gift': V3Cat('gift', 'Gift', null,
        PhRegular.gift, Color(0xFF6CD79D)),
    'pension': V3Cat('pension', 'Pension', null,
        PhRegular.bank, Color(0xFF6CD79D)),
    'rentin': V3Cat('rentin', 'Rental income', 'Rental',
        PhRegular.buildings, Color(0xFF6CD79D)),
    'loan': V3Cat('loan', 'Loan received', 'Loan',
        PhRegular.handCoins, Color(0xFF6CD79D)),
    'refund': V3Cat('refund', 'Refund', null,
        PhRegular.arrowCounterClockwise, Color(0xFF6CD79D)),
  };

  static const List<String> expenseCats = [
    'groceries', 'dining', 'transport', 'fuel', 'shopping',
    'bills', 'home', 'subs', 'health', 'education',
  ];

  static const List<String> incomeCats = [
    'salary', 'business', 'rentin', 'loan', 'pension', 'gift', 'refund',
  ];

  static const List<V3Source> sources = [
    V3Source('salary', 'Salary', PhRegular.briefcase, 289),
    V3Source('side', 'Side business', PhRegular.storefront, 200),
    V3Source('rental', 'Rental homes', PhRegular.buildings, 158),
    V3Source('loan', 'Loan', PhRegular.handCoins, 50),
    V3Source('other', 'Pension & other', PhRegular.coins, 85),
  ];

  /// MEMBERS from the design, with their opening balances and personal budgets.
  static const List<V3Member> members = [
    V3Member(id: 'asif',  name: 'Asif',  rel: 'You',      role: 'Owner',  opening: 62000, hue: 289, budget: 45000),
    V3Member(id: 'sara',  name: 'Sara',  rel: 'Wife',     role: 'Admin',  opening: 41000, hue: 345, budget: 20000),
    V3Member(id: 'imran', name: 'Imran', rel: 'Brother',  role: 'Member', opening: 18500, hue: 200, budget: 10000),
    V3Member(id: 'yusuf', name: 'Yusuf', rel: 'Father',   role: 'Member', opening: 55000, hue: 85,  budget: 8000),
    V3Member(id: 'zara',  name: 'Zara',  rel: 'Daughter', role: 'Member', opening: 6200,  hue: 158, budget: 3000, allowance: true),
  ];

  /// FAM_BUDGET — the whole household's monthly ceiling.
  static const double familyBudget = 86000;

  /// Per-category budgets: family limit and personal limit.
  static const Map<String, ({double fam, double me})> budgets = {
    'groceries': (fam: 12000, me: 5000),
    'dining':    (fam: 4000,  me: 2000),
    'shopping':  (fam: 6000,  me: 3000),
    'fuel':      (fam: 4000,  me: 2500),
    'bills':     (fam: 7000,  me: 4500),
  };

  /// Which money source an income category feeds, per the design's CAT_SRC.
  static const Map<String, String> catSource = {
    'salary': 'salary',
    'business': 'side',
    'rentin': 'rental',
    'loan': 'loan',
    'pension': 'other',
    'gift': 'other',
    'refund': 'other',
  };

  static const Map<String, IconData> categoryIconRegistry = {
    'fork-knife': PhRegular.forkKnife,
    'basket': PhRegular.basket,
    'shopping-bag': PhRegular.shoppingBag,
    'shopping-cart': PhRegular.shoppingCart,
    'taxi': PhRegular.taxi,
    'gas-pump': PhRegular.gasPump,
    'lightning': PhRegular.lightning,
    'house-line': PhRegular.houseLine,
    'play-circle': PhRegular.playCircle,
    'first-aid': PhRegular.firstAid,
    'graduation-cap': PhRegular.graduationCap,
    'briefcase': PhRegular.briefcase,
    'storefront': PhRegular.storefront,
    'gift': PhRegular.gift,
    'bank': PhRegular.bank,
    'buildings': PhRegular.buildings,
    'hand-coins': PhRegular.handCoins,
    'coins': PhRegular.coins,
    'credit-card': PhRegular.creditCard,
    'wallet': PhRegular.wallet,
    'map-pin': PhRegular.mapPin,
    'compass': PhRegular.compass,
    'camera': PhRegular.camera,
    'sparkle': PhRegular.sparkle,
    'star': PhRegular.star,
    'sun': PhRegular.sun,
    'calendar': PhRegular.calendar,
    'target': PhRegular.target,
    'circle': PhRegular.circle,
  };

  static const List<String> customCategoryColors = [
    '#64C897', // Sage green
    '#EE9A69', // Coral / Peach
    '#A297EB', // Purple / Lavender
    '#E2C06D', // Amber / Gold
    '#DE82B7', // Rose / Pink
    '#67B5E1', // Sky blue
    '#839ED7', // Periwinkle
    '#BC8FDD', // Lilac
    '#EB8186', // Salmon
    '#6BCAC9', // Teal
    '#6CD79D', // Mint green
    '#FBBF24', // Warm amber
    '#F472B6', // Bright pink
    '#38BDF8', // Cyan
  ];

  static IconData iconFromName(String? iconName) {
    if (iconName == null || iconName.isEmpty) return PhRegular.circle;
    return categoryIconRegistry[iconName.trim()] ?? PhRegular.circle;
  }

  static String iconNameFromData(IconData icon) {
    for (final entry in categoryIconRegistry.entries) {
      if (entry.value == icon) return entry.key;
    }
    return 'circle';
  }

  static V3Cat cat(String key) =>
      cats[key] ??
      const V3Cat('other', 'Other', null,
          PhRegular.circle, Color(0xFF9397AB));

  /// Parses a stored `#RRGGBB` category colour; null when absent or malformed.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  static V3Source? source(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  /// Indian digit grouping: 1,23,456 rather than 123,456 — the design uses
  /// `toLocaleString('en-IN')`.
  static String groupInr(num value) {
    final digits = value.abs().round().toString();
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  /// `INR(n)` in the design. Note the leading character for negatives is the
  /// typographic minus U+2212, not a hyphen.
  static String inr(num value) =>
      '${value < 0 ? '\u2212' : ''}\u20B9${groupInr(value)}';

  /// `H(n)` — amounts respect the global hide toggle.
  static String inrHidden(num value, bool hidden) =>
      hidden ? '\u20B9 ••••' : inr(value);

  /// `K(n)` — the compact form in hero stats and the doughnut centre.
  /// Lakhs take two decimals and thousands one, exactly as the design does.
  static String inrShort(num value, {bool hidden = false}) {
    if (hidden) return '••••';
    final v = value.abs();
    if (v >= 100000) {
      return '${value < 0 ? '\u2212' : ''}\u20B9${(v / 100000).toStringAsFixed(2)}L';
    }
    if (v >= 1000) {
      return '${value < 0 ? '\u2212' : ''}\u20B9${(v / 1000).toStringAsFixed(1)}k';
    }
    return inr(value);
  }
}

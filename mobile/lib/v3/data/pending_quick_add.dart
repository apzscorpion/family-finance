import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// An expense typed into the lock-screen notification but not yet written to
/// Supabase.
class PendingQuickAdd {
  final double amount;

  /// A category key from `V3Design.cats`, or null when nothing matched.
  final String? categoryKey;

  /// What the user typed, minus the amount. Becomes the transaction title.
  final String title;
  final DateTime capturedAt;

  const PendingQuickAdd({
    required this.amount,
    required this.categoryKey,
    required this.title,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'category': categoryKey,
        'title': title,
        'at': capturedAt.toIso8601String(),
      };

  static PendingQuickAdd? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final amount = raw['amount'];
    if (amount is! num) return null;
    final at = DateTime.tryParse(raw['at']?.toString() ?? '');
    return PendingQuickAdd(
      amount: amount.toDouble(),
      categoryKey: raw['category'] is String ? raw['category'] as String : null,
      title: raw['title']?.toString() ?? '',
      capturedAt: at ?? DateTime.now(),
    );
  }
}

/// Turns free text typed into a notification into an amount and a category.
///
/// Deliberately forgiving: someone typing on a lock screen is not going to
/// produce clean input, and rejecting "250 groceries" over a stray rupee sign
/// would make the feature useless.
class QuickAddParser {
  QuickAddParser._();

  /// Keywords mapped onto the category keys in `V3Design.cats`. Ordered
  /// longest-first at match time so "petrol pump" beats "pump".
  static const Map<String, String> _keywords = {
    'grocery': 'groceries',
    'groceries': 'groceries',
    'supermarket': 'groceries',
    'vegetables': 'groceries',
    'milk': 'groceries',
    'food': 'dining',
    'dining': 'dining',
    'restaurant': 'dining',
    'lunch': 'dining',
    'dinner': 'dining',
    'breakfast': 'dining',
    'tea': 'dining',
    'coffee': 'dining',
    'snacks': 'dining',
    'hotel': 'dining',
    'transport': 'transport',
    'taxi': 'transport',
    'cab': 'transport',
    'uber': 'transport',
    'ola': 'transport',
    'bus': 'transport',
    'train': 'transport',
    'auto': 'transport',
    'metro': 'transport',
    'fuel': 'fuel',
    'petrol': 'fuel',
    'diesel': 'fuel',
    'gas': 'fuel',
    'shopping': 'shopping',
    'clothes': 'shopping',
    'amazon': 'shopping',
    'flipkart': 'shopping',
    'bill': 'bills',
    'bills': 'bills',
    'electricity': 'bills',
    'water': 'bills',
    'internet': 'bills',
    'mobile': 'bills',
    'recharge': 'bills',
    'rent': 'home',
    'home': 'home',
    'maintenance': 'home',
    'subscription': 'subs',
    'netflix': 'subs',
    'spotify': 'subs',
    'prime': 'subs',
    'health': 'health',
    'medicine': 'health',
    'pharmacy': 'health',
    'doctor': 'health',
    'hospital': 'health',
    'clinic': 'health',
    'school': 'education',
    'fees': 'education',
    'tuition': 'education',
    'books': 'education',
    'education': 'education',
  };

  /// Matches the first number in the string, tolerating a currency symbol,
  /// thousands separators and a decimal part.
  static final RegExp _amount =
      RegExp(r'(?:₹|rs\.?|inr)?\s*(\d[\d,]*(?:\.\d+)?)', caseSensitive: false);

  /// Returns null when there is no number to spend.
  static PendingQuickAdd? parse(String input, {DateTime? now}) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final match = _amount.firstMatch(text);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;

    // Everything either side of the number is the description.
    final rest = (text.substring(0, match.start) + text.substring(match.end))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return PendingQuickAdd(
      amount: amount,
      categoryKey: categoryFor(rest),
      title: rest.isEmpty ? 'Quick add' : _capitalise(rest),
      capturedAt: now ?? DateTime.now(),
    );
  }

  /// First keyword found in [text], preferring the longest keyword so that a
  /// more specific word wins over a substring of it.
  static String? categoryFor(String text) {
    final lower = text.toLowerCase();
    final keys = _keywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(lower)) {
        return _keywords[k];
      }
    }
    return null;
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// A SharedPreferences-backed queue of quick adds captured while the app was
/// not running.
///
/// The background notification isolate has no Provider, no Supabase session
/// handling and no widget tree, so it cannot reliably write a transaction
/// itself. It drops the entry here instead and the app drains the queue on
/// next launch. Everything is static and touches only SharedPreferences so it
/// is safe to call from that isolate.
class PendingQuickAddQueue {
  PendingQuickAddQueue._();

  static const _key = 'ff_pending_quick_add';

  /// Caps the queue so a stuck device cannot grow it without bound.
  static const _max = 50;

  static Future<void> add(PendingQuickAdd entry) async {
    final prefs = await SharedPreferences.getInstance();
    // Reload rather than trusting a cached copy: the app isolate may have
    // written here since this isolate started.
    await prefs.reload();
    final list = _decode(prefs.getString(_key))..add(entry);
    while (list.length > _max) {
      list.removeAt(0);
    }
    await prefs.setString(
      _key,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }

  static Future<List<PendingQuickAdd>> peek() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decode(prefs.getString(_key));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static List<PendingQuickAdd> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded) ?PendingQuickAdd.fromJson(item),
      ];
    } catch (_) {
      // A corrupt queue is dropped rather than blocking every future capture.
      return [];
    }
  }
}

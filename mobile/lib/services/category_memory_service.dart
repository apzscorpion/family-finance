import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-learns merchant-to-category associations locally on the device.
/// Whenever a user categorizes an expense (e.g., "Swiggy" -> "food", "Shell" -> "fuel"),
/// future entries with that merchant automatically default to that category.
class CategoryMemoryService {
  CategoryMemoryService._();

  static const String _prefKey = 'kinpurse_merchant_category_memory_v1';
  static Map<String, String>? _cache;

  /// Loads learned memory into memory cache.
  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cache = decoded.map((k, v) => MapEntry(k.toString().toLowerCase().trim(), v.toString()));
          return;
        }
      }
    } catch (_) {}
    _cache = {};
  }

  /// Normalizes a merchant / note string for robust matching.
  static String normalize(String text) {
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Predicts the category key based on learned merchant memory.
  /// Returns null if no match found.
  static Future<String?> predictCategory(String merchantOrNote) async {
    final query = normalize(merchantOrNote);
    if (query.isEmpty) return null;
    await _ensureLoaded();
    if (_cache == null || _cache!.isEmpty) return null;

    // 1. Exact match
    if (_cache!.containsKey(query)) {
      return _cache![query];
    }

    // 2. Substring matching: e.g. "Swiggy Instamart #428" matches "swiggy"
    for (final entry in _cache!.entries) {
      if (entry.key.length >= 3 && query.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Synchronous fast lookup if cache is already warm.
  static String? predictCategorySync(String merchantOrNote) {
    final query = normalize(merchantOrNote);
    if (query.isEmpty || _cache == null) return null;

    if (_cache!.containsKey(query)) return _cache![query];
    for (final entry in _cache!.entries) {
      if (entry.key.length >= 3 && query.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Learns or updates the mapping for a merchant to a category key.
  static Future<void> remember(String merchantOrNote, String categoryKey) async {
    final merchant = normalize(merchantOrNote);
    if (merchant.isEmpty || categoryKey.isEmpty) return;

    await _ensureLoaded();
    _cache ??= {};
    _cache![merchant] = categoryKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_cache));
    } catch (_) {}
  }
}


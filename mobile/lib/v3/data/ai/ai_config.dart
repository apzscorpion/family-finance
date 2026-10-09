import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_log.dart';

/// Which service the "Restructure with AI" action talks to.
///
/// The key always belongs to the person using the app — nothing is proxied
/// through a server of ours, and no key ships inside the APK.
enum AiProvider {
  gemini,
  claude,
  openai,

  /// Any OpenAI-compatible endpoint: OpenRouter, Groq, Together, a local
  /// Ollama, LM Studio, and so on. Covers "configure whatever you like".
  compatible,
}

extension AiProviderInfo on AiProvider {
  String get label => switch (this) {
    AiProvider.gemini => 'Google Gemini',
    AiProvider.claude => 'Anthropic Claude',
    AiProvider.openai => 'OpenAI',
    AiProvider.compatible => 'Other (OpenAI-compatible)',
  };

  /// A sensible current model per provider. Always editable.
  String get defaultModel => switch (this) {
    AiProvider.gemini => 'gemini-2.5-flash',
    AiProvider.claude => 'claude-opus-5-5',
    AiProvider.openai => 'gpt-4o-mini',
    AiProvider.compatible => 'llama3.1',
  };

  /// Where to get a key, shown under the key field.
  String get keyHint => switch (this) {
    AiProvider.gemini => 'aistudio.google.com/apikey',
    AiProvider.claude => 'console.anthropic.com',
    AiProvider.openai => 'platform.openai.com/api-keys',
    AiProvider.compatible => 'Whatever your endpoint expects',
  };

  /// Only the compatible provider needs a base URL from the user.
  bool get needsBaseUrl => this == AiProvider.compatible;
}

/// One saved API key. [alias] is unique per provider so a key that expires
/// can be swapped for another with a tap.
class AiKey {
  final AiProvider provider;
  final String alias;
  final String key;

  /// Result of the last connection test: true working, false failed,
  /// null never tested.
  final bool? ok;

  const AiKey({
    required this.provider,
    required this.alias,
    required this.key,
    this.ok,
  });

  /// `••••abcd`, enough to tell keys apart without showing them.
  String get masked =>
      key.length <= 4 ? '••••' : '••••${key.substring(key.length - 4)}';

  AiKey withStatus(bool? next) =>
      AiKey(provider: provider, alias: alias, key: key, ok: next);

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'alias': alias,
    'key': key,
    'ok': ok,
  };

  static AiKey? fromJson(Object? j) {
    if (j is! Map) return null;
    final provider = AiProvider.values.where((p) => p.name == j['provider']);
    final alias = j['alias'], key = j['key'];
    if (provider.isEmpty || alias is! String || key is! String) return null;
    return AiKey(
      provider: provider.first,
      alias: alias,
      key: key,
      ok: j['ok'] is bool ? j['ok'] as bool : null,
    );
  }
}

/// Device-local AI settings.
///
/// Stored next to the prayer config rather than in Supabase: an API key is
/// personal, is billed to one person, and has no business syncing to every
/// family member's phone.
class AiConfig {
  final AiProvider provider;
  final String model;

  /// Base URL for [AiProvider.compatible], e.g. `http://192.168.1.4:11434/v1`.
  final String baseUrl;

  /// Every saved key, across all providers.
  final List<AiKey> keys;

  /// Alias of the key in use, per provider name.
  final Map<String, String> active;

  const AiConfig({
    this.provider = AiProvider.gemini,
    this.model = '',
    this.baseUrl = '',
    this.keys = const [],
    this.active = const {},
  });

  List<AiKey> keysFor(AiProvider p) => [
    for (final k in keys)
      if (k.provider == p) k,
  ];

  /// The key in use for the current provider: the chosen one, else the first.
  AiKey? get activeKey {
    final saved = keysFor(provider);
    if (saved.isEmpty) return null;
    return saved.firstWhere(
      (k) => k.alias == active[provider.name],
      orElse: () => saved.first,
    );
  }

  String get apiKey => activeKey?.key ?? '';

  /// The model to actually send, falling back to the provider default when the
  /// user has not overridden it.
  String get effectiveModel =>
      model.trim().isEmpty ? provider.defaultModel : model.trim();

  /// AI actions are only offered when there is something to call.
  bool get isConfigured {
    if (apiKey.trim().isEmpty) return false;
    if (provider.needsBaseUrl && baseUrl.trim().isEmpty) return false;
    return true;
  }

  AiConfig copyWith({
    AiProvider? provider,
    String? model,
    String? baseUrl,
    List<AiKey>? keys,
    Map<String, String>? active,
  }) => AiConfig(
    provider: provider ?? this.provider,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
    keys: keys ?? this.keys,
    active: active ?? this.active,
  );

  /// Switching provider clears the model so the new provider's default
  /// applies — a Gemini model name is meaningless to Claude.
  AiConfig withProvider(AiProvider next) => copyWith(provider: next, model: '');

  /// Adds a key for the current provider (replacing one with the same alias)
  /// and makes it the active one.
  AiConfig withKey(String alias, String key) => copyWith(
    keys: [
      for (final k in keys)
        if (!(k.provider == provider && k.alias == alias)) k,
      AiKey(provider: provider, alias: alias, key: key),
    ],
    active: {...active, provider.name: alias},
  );

  AiConfig withoutKey(AiKey key) => copyWith(
    keys: [
      for (final k in keys)
        if (!(k.provider == key.provider && k.alias == key.alias)) k,
    ],
  );

  AiConfig withActive(AiKey key) =>
      copyWith(active: {...active, key.provider.name: key.alias});

  AiConfig withStatus(AiKey key, bool? ok) => copyWith(
    keys: [
      for (final k in keys)
        k.provider == key.provider && k.alias == key.alias
            ? k.withStatus(ok)
            : k,
    ],
  );

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'model': model,
    'base_url': baseUrl,
    'keys': [for (final k in keys) k.toJson()],
    'active': active,
  };

  factory AiConfig.fromJson(Map<String, dynamic> j) {
    var provider = AiProvider.gemini;
    for (final p in AiProvider.values) {
      if (p.name == j['provider']) provider = p;
    }
    final keys = <AiKey>[
      if (j['keys'] is List)
        for (final raw in j['keys'] as List) ?AiKey.fromJson(raw),
    ];
    // Before named keys there was a single `api_key`; keep it as "Default".
    final legacy = j['api_key'];
    if (keys.isEmpty && legacy is String && legacy.trim().isNotEmpty) {
      keys.add(AiKey(provider: provider, alias: 'Default', key: legacy.trim()));
    }
    final active = <String, String>{
      if (j['active'] is Map)
        for (final e in (j['active'] as Map).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
    return AiConfig(
      provider: provider,
      model: j['model'] is String ? j['model'] as String : '',
      baseUrl: j['base_url'] is String ? j['base_url'] as String : '',
      keys: keys,
      active: active,
    );
  }
}

class AiConfigStore {
  AiConfigStore._();

  static const _key = 'ff_ai_config';

  static Future<AiConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const AiConfig();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AiConfig();
      return AiConfig.fromJson(decoded);
    } catch (err, stack) {
      AppLog.error('AiConfigStore.load', err, stack);
      return const AiConfig();
    }
  }

  static Future<void> save(AiConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(config.toJson()));
    } catch (err, stack) {
      AppLog.error('AiConfigStore.save', err, stack);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

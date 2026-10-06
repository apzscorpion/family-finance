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

/// Device-local AI settings.
///
/// Stored next to the prayer config rather than in Supabase: an API key is
/// personal, is billed to one person, and has no business syncing to every
/// family member's phone.
class AiConfig {
  final AiProvider provider;
  final String apiKey;
  final String model;

  /// Base URL for [AiProvider.compatible], e.g. `http://192.168.1.4:11434/v1`.
  final String baseUrl;

  const AiConfig({
    this.provider = AiProvider.gemini,
    this.apiKey = '',
    this.model = '',
    this.baseUrl = '',
  });

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
    String? apiKey,
    String? model,
    String? baseUrl,
  }) =>
      AiConfig(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        baseUrl: baseUrl ?? this.baseUrl,
      );

  /// Switching provider clears the model so the new provider's default
  /// applies — a Gemini model name is meaningless to Claude.
  AiConfig withProvider(AiProvider next) =>
      copyWith(provider: next, model: '');

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'api_key': apiKey,
        'model': model,
        'base_url': baseUrl,
      };

  factory AiConfig.fromJson(Map<String, dynamic> j) {
    var provider = AiProvider.gemini;
    for (final p in AiProvider.values) {
      if (p.name == j['provider']) provider = p;
    }
    return AiConfig(
      provider: provider,
      apiKey: j['api_key'] is String ? j['api_key'] as String : '',
      model: j['model'] is String ? j['model'] as String : '',
      baseUrl: j['base_url'] is String ? j['base_url'] as String : '',
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

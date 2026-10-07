import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';
import '../data/ai/ai_config.dart';
import '../data/ai/ai_structurer.dart';
import '../phosphor_icons.dart';

/// Device-local AI settings screen for "Restructure with AI" in Notes.
///
/// Reached from Settings → Personal. Never syncs to Supabase because API keys
/// are personal and billed to one person.
class AiSettingsV3 extends StatefulWidget {
  const AiSettingsV3({super.key});

  @override
  State<AiSettingsV3> createState() => _AiSettingsV3State();
}

class _AiSettingsV3State extends State<AiSettingsV3> {
  AiConfig _config = const AiConfig();
  late final TextEditingController _apiKey = TextEditingController();
  late final TextEditingController _model = TextEditingController();
  late final TextEditingController _baseUrl = TextEditingController();

  bool _loading = true;
  bool _showKey = false;
  bool _testing = false;
  String? _testMessage;
  bool? _testOk;

  static const _sampleInput = 'Groceries\nMilk\nEggs\nBread';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await AiConfigStore.load();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _apiKey.text = cfg.apiKey;
      _model.text = cfg.model;
      _baseUrl.text = cfg.baseUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _persist(AiConfig next) async {
    setState(() {
      _config = next;
      _testMessage = null;
      _testOk = null;
    });
    await AiConfigStore.save(next);
  }

  void _selectProvider(AiProvider p) {
    final next = _config.withProvider(p).copyWith(
          apiKey: _apiKey.text.trim(),
          baseUrl: _baseUrl.text.trim(),
        );
    _model.clear();
    _persist(next);
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final current = _config.copyWith(
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim(),
      baseUrl: _baseUrl.text.trim(),
    );
    await AiConfigStore.save(current);

    if (!current.isConfigured) {
      setState(() {
        _testOk = false;
        _testMessage = current.provider.needsBaseUrl
            ? 'Enter both an API key and base URL first'
            : 'Enter an API key first';
      });
      return;
    }

    setState(() {
      _config = current;
      _testing = true;
      _testMessage = null;
      _testOk = null;
    });

    final res = await AiStructurer.structure(_sampleInput, current);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = res.ok;
      _testMessage = res.ok
          ? 'Connected to ${current.provider.label} (${current.effectiveModel}) — structured ${res.blocks!.length} block${res.blocks!.length == 1 ? '' : 's'}.'
          : (res.error ?? 'Connection test failed');
    });
  }

  Future<void> _clearKey() async {
    await AiConfigStore.clear();
    if (!mounted) return;
    setState(() {
      _config = const AiConfig();
      _apiKey.clear();
      _model.clear();
      _baseUrl.clear();
      _testMessage = 'Cleared AI configuration from this device';
      _testOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Nocturne.accent300),
      );
    }

    final provider = _config.provider;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const _Kicker('Provider'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                for (var i = 0; i < AiProvider.values.length; i++) ...[
                  _ProviderRow(
                    provider: AiProvider.values[i],
                    selected: AiProvider.values[i] == provider,
                    onTap: () => _selectProvider(AiProvider.values[i]),
                  ),
                  if (i < AiProvider.values.length - 1)
                    const Divider(color: Nocturne.neutral900, height: 1),
                ],
              ],
            ),
          ),
        ),
        const _Kicker('Credentials & model'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API KEY',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                    color: Nocturne.neutral500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 44,
                  padding: const EdgeInsets.only(left: 12, right: 6),
                  decoration: BoxDecoration(
                    color: Nocturne.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Nocturne.neutral800, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKey,
                          obscureText: !_showKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (v) =>
                              _persist(_config.copyWith(apiKey: v.trim())),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Nocturne.text,
                          ),
                          cursorColor: Nocturne.accent,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Paste your API key…',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Nocturne.neutral600,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showKey = !_showKey),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            _showKey ? PhRegular.eyeSlash : PhRegular.eye,
                            size: 17,
                            color: Nocturne.neutral400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Key source: ${provider.keyHint}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Nocturne.neutral500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MODEL',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                    color: Nocturne.neutral500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Nocturne.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Nocturne.neutral800, width: 1),
                  ),
                  child: TextField(
                    controller: _model,
                    autocorrect: false,
                    onChanged: (v) =>
                        _persist(_config.copyWith(model: v.trim())),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Nocturne.text,
                    ),
                    cursorColor: Nocturne.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: provider.defaultModel,
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: Nocturne.neutral600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Leave blank to use ${provider.defaultModel}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Nocturne.neutral500,
                  ),
                ),
                if (provider.needsBaseUrl) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'BASE URL',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.7,
                      color: Nocturne.neutral500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Nocturne.bg,
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: TextField(
                      controller: _baseUrl,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      onChanged: (v) =>
                          _persist(_config.copyWith(baseUrl: v.trim())),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Nocturne.text,
                      ),
                      cursorColor: Nocturne.accent,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'https://openrouter.ai/api/v1',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: Nocturne.neutral600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'OpenAI-compatible base URL (OpenRouter, Groq, Ollama, LM Studio)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Nocturne.neutral500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _testing ? null : _testConnection,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Nocturne.accent600,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Nocturne.text,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(PhRegular.sparkle,
                                        size: 16, color: Nocturne.text),
                                    SizedBox(width: 7),
                                    Text(
                                      'Test connection',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Nocturne.text,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    if (_config.apiKey.isNotEmpty ||
                        _config.baseUrl.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _clearKey,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Nocturne.bg,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Nocturne.neutral800, width: 1),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 13,
                              color: Nocturne.neutral400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Nocturne.mix(
                        _testOk == true
                            ? NocturneSemantic.income
                            : NocturneSemantic.expense,
                        12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Nocturne.mix(
                          _testOk == true
                              ? NocturneSemantic.income
                              : NocturneSemantic.expense,
                          35,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testOk == true
                              ? PhFill.checkCircle
                              : PhRegular.warning,
                          size: 16,
                          color: _testOk == true
                              ? NocturneSemantic.income
                              : NocturneSemantic.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Nocturne.neutral200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            'Your API key stays on this device and is never shared with your '
            'family or synced to Supabase. Note restructuring runs on-device '
            'by default and only calls your provider when you tap '
            '"Restructure with AI".',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: Nocturne.neutral600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderRow({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: Nocturne.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Default: ${provider.defaultModel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Nocturne.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Nocturne.accent600 : Colors.transparent,
                  border: Border.all(
                    color: selected ? Nocturne.accent500 : Nocturne.neutral700,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(PhBold.check, size: 11, color: Nocturne.text)
                    : null,
              ),
            ],
          ),
        ),
      );
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 0.77,
            color: Nocturne.neutral500,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );
}
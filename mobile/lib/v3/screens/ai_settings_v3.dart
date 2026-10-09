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
  late final TextEditingController _alias = TextEditingController();
  late final TextEditingController _apiKey = TextEditingController();
  late final TextEditingController _model = TextEditingController();
  late final TextEditingController _baseUrl = TextEditingController();

  bool _loading = true;
  bool _showKey = false;
  bool _testing = false;
  String? _testingAlias;
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
      _model.text = cfg.model;
      _baseUrl.text = cfg.baseUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _alias.dispose();
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
    final next = _config.withProvider(p).copyWith(baseUrl: _baseUrl.text.trim());
    _model.clear();
    _persist(next);
  }

  /// Saves the key typed into the add form, then tests it.
  Future<void> _addKey() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) return;
    var alias = _alias.text.trim();
    if (alias.isEmpty) {
      alias = 'Key ${_config.keysFor(_config.provider).length + 1}';
    }
    _alias.clear();
    _apiKey.clear();
    await _persist(_config.withKey(alias, key));
    await _testKey(_config.activeKey!);
  }

  Future<void> _testConnection() async {
    if (_apiKey.text.trim().isNotEmpty) return _addKey();
    final key = _config.activeKey;
    if (key == null) {
      setState(() {
        _testOk = false;
        _testMessage = 'Enter an API key first';
      });
      return;
    }
    await _testKey(key);
  }

  Future<void> _testKey(AiKey key) async {
    if (_testing) return;
    final current = _config.withActive(key).copyWith(
          model: _model.text.trim(),
          baseUrl: _baseUrl.text.trim(),
        );
    await AiConfigStore.save(current);

    if (!current.isConfigured) {
      setState(() {
        _testOk = false;
        _testMessage = 'Enter both an API key and base URL first';
      });
      return;
    }

    setState(() {
      _config = current;
      _testing = true;
      _testingAlias = key.alias;
      _testMessage = null;
      _testOk = null;
    });

    final res = await AiStructurer.structure(_sampleInput, current);
    if (!mounted) return;
    final next = _config.withStatus(key, res.ok);
    await AiConfigStore.save(next);
    setState(() {
      _config = next;
      _testing = false;
      _testingAlias = null;
      _testOk = res.ok;
      _testMessage = res.ok
          ? '"${key.alias}" works with ${current.provider.label} (${current.effectiveModel}).'
          : '"${key.alias}": ${res.error ?? 'Connection test failed'}';
    });
  }

  Future<void> _deleteKey(AiKey key) =>
      _persist(_config.withoutKey(key));

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
                const _Label('SAVED KEYS'),
                const SizedBox(height: 6),
                if (_config.keysFor(provider).isEmpty)
                  const Text(
                    'No keys saved for this provider yet.',
                    style: TextStyle(fontSize: 12.5, color: Nocturne.neutral500),
                  ),
                for (final key in _config.keysFor(provider))
                  _KeyRow(
                    keyInfo: key,
                    active: key.alias == _config.activeKey?.alias,
                    testing: _testingAlias == key.alias,
                    onSelect: () => _persist(_config.withActive(key)),
                    onTest: () => _testKey(key),
                    onDelete: () => _deleteKey(key),
                  ),
                const SizedBox(height: 14),
                const _Label('ADD A KEY'),
                const SizedBox(height: 6),
                _Field(
                  child: TextField(
                    controller: _alias,
                    autocorrect: false,
                    style: const TextStyle(fontSize: 13.5, color: Nocturne.text),
                    cursorColor: Nocturne.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Name, e.g. Personal or Work',
                      hintStyle:
                          TextStyle(fontSize: 13.5, color: Nocturne.neutral600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Field(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKey,
                          obscureText: !_showKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          onSubmitted: (_) => _addKey(),
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
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.7,
          color: Nocturne.neutral500,
        ),
      );
}

class _Field extends StatelessWidget {
  final Widget child;
  const _Field({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Nocturne.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Nocturne.neutral800, width: 1),
        ),
        child: child,
      );
}

/// A saved key: tap to make it the one in use, test it, or delete it.
class _KeyRow extends StatelessWidget {
  final AiKey keyInfo;
  final bool active;
  final bool testing;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _KeyRow({
    required this.keyInfo,
    required this.active,
    required this.testing,
    required this.onSelect,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (keyInfo.ok) {
      true => ('Working', NocturneSemantic.income),
      false => ('Failed', NocturneSemantic.expense),
      null => ('Not tested', Nocturne.neutral500),
    };
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              active ? PhFill.checkCircle : PhRegular.circle,
              size: 18,
              color: active ? Nocturne.accent400 : Nocturne.neutral600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyInfo.alias,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: Nocturne.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${keyInfo.masked} · $label',
                    style: TextStyle(fontSize: 11.5, color: color),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Test ${keyInfo.alias}',
              onPressed: testing ? null : onTest,
              icon: testing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Nocturne.accent300,
                      ),
                    )
                  : const Icon(PhRegular.sparkle,
                      size: 17, color: Nocturne.neutral400),
            ),
            IconButton(
              tooltip: 'Delete ${keyInfo.alias}',
              onPressed: onDelete,
              icon: const Icon(PhRegular.trash,
                  size: 17, color: Nocturne.neutral400),
            ),
          ],
        ),
      ),
    );
  }
}

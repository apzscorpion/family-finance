import 'package:family_finance/v3/data/ai/ai_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy single key migrates to a "Default" alias', () {
    final c = AiConfig.fromJson({'provider': 'gemini', 'api_key': 'abc123'});
    expect(c.activeKey?.alias, 'Default');
    expect(c.apiKey, 'abc123');
  });

  test('keys are per provider, switchable, and survive a round trip', () {
    var c = const AiConfig()
        .withKey('Personal', 'g-1')
        .withKey('Work', 'g-2')
        .withProvider(AiProvider.openai)
        .withKey('Main', 'o-1');
    expect(c.keysFor(AiProvider.gemini).map((k) => k.alias),
        ['Personal', 'Work']);
    expect(c.apiKey, 'o-1');

    c = c.withProvider(AiProvider.gemini);
    expect(c.apiKey, 'g-2'); // last added is active
    c = c.withActive(c.keysFor(AiProvider.gemini).first);
    c = c.withStatus(c.activeKey!, false);
    expect(c.apiKey, 'g-1');

    final back = AiConfig.fromJson(c.toJson());
    expect(back.apiKey, 'g-1');
    expect(back.activeKey?.ok, false);

    expect(back.withoutKey(back.activeKey!).apiKey, 'g-2');
  });
}

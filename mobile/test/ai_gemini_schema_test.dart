import 'package:family_finance/v3/data/ai/ai_structurer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemini gets one type plus nullable, never a type list', () {
    final out = AiStructurer.forGemini({
      'type': 'object',
      'properties': {
        'category': {'type': ['string', 'null']},
        'intent': {'type': 'string'},
        'list': {
          'type': 'array',
          'items': {'type': ['number', 'null']},
        },
      },
    }) as Map;
    final props = out['properties'] as Map;
    expect(props['category'], {'type': 'string', 'nullable': true});
    expect(props['intent'], {'type': 'string'});
    expect((props['list'] as Map)['items'], {'type': 'number', 'nullable': true});
  });
}

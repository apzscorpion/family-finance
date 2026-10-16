import 'package:family_finance/v3/data/ai/voice_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Malayalam and Manglish yes / no / stop', () {
    expect(VoiceAssistant.isYes('ശരി'), isTrue);
    expect(VoiceAssistant.isYes('sheri'), isTrue);
    expect(VoiceAssistant.isYes('അതെ ചെയ്യൂ'), isTrue);
    expect(VoiceAssistant.isNo('വേണ്ട'), isTrue);
    expect(VoiceAssistant.isNo('athu venda'), isTrue);
    expect(VoiceAssistant.isStop('മതി'), isTrue);
    expect(VoiceAssistant.isStop('mathi'), isTrue);
    // English still works.
    expect(VoiceAssistant.isYes('yes please'), isTrue);
    expect(VoiceAssistant.isNo('no thanks'), isTrue);
  });

  test('picks the Malayalam voice for Malayalam replies', () {
    expect(VoiceAssistant.isMalayalam('₹450 പെട്രോൾ ചേർക്കട്ടെ?'), isTrue);
    expect(VoiceAssistant.isMalayalam('Add ₹450 petrol?'), isFalse);
  });
}

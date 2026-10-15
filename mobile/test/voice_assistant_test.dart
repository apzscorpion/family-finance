import 'package:family_finance/v3/data/ai/ai_structurer.dart';
import 'package:family_finance/v3/data/ai/voice_assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceTurn.fromJson', () {
    test('plain reply has no action', () {
      final t = VoiceTurn.fromJson({'reply': 'I am good!', 'action': null})!;
      expect(t.reply, 'I am good!');
      expect(t.action, isNull);
    });

    test('add_expense keeps its fields', () {
      final t = VoiceTurn.fromJson({
        'reply': 'Add 450 for petrol?',
        'action': {
          'type': 'add_expense',
          'amount': 450,
          'title': 'Petrol',
          'category': 'Fuel',
          'account': 'HDFC',
          'question': null,
        },
      })!;
      final a = t.action!;
      expect(a.isAdd, isTrue);
      expect(a.isIncome, isFalse);
      expect(a.amount, 450);
      expect(a.title, 'Petrol');
      expect(a.account, 'HDFC');
    });

    test('amount as a string is read; missing amount drops the add', () {
      final ok = VoiceAction.fromJson(
          {'type': 'add_income', 'amount': '₹5,000', 'title': 'Salary'});
      expect(ok!.amount, 5000);
      expect(ok.isIncome, isTrue);
      expect(VoiceAction.fromJson({'type': 'add_expense', 'amount': null}),
          isNull);
      expect(VoiceAction.fromJson({'type': 'add_expense', 'amount': 0}),
          isNull);
    });

    test('ask needs a question; unknown types are dropped', () {
      expect(
          VoiceAction.fromJson({'type': 'ask', 'question': 'Food this month?'})!
              .question,
          'Food this month?');
      expect(VoiceAction.fromJson({'type': 'ask', 'question': ''}), isNull);
      expect(VoiceAction.fromJson({'type': 'delete_all'}), isNull);
      expect(VoiceAction.fromJson('nonsense'), isNull);
    });

    test('empty reply and no action is unusable', () {
      expect(VoiceTurn.fromJson({'reply': '', 'action': null}), isNull);
    });
  });

  test('schema is valid for Gemini conversion', () {
    // The nullable object type must collapse to a single type for Gemini.
    final g = AiStructurer.forGemini({
      'type': ['object', 'null'],
    }) as Map;
    expect(g['type'], 'object');
    expect(g['nullable'], isTrue);
  });

  group('yes / no / stop', () {
    test('yes', () {
      for (final s in ['Yes', 'yeah sure', 'OK', 'go ahead', 'Yes please.']) {
        expect(VoiceAssistant.isYes(s), isTrue, reason: s);
      }
      expect(VoiceAssistant.isYes('how are you'), isFalse);
    });

    test('no wins anywhere in the sentence', () {
      for (final s in ['No', 'nope', 'okay cancel it', "don't add it"]) {
        expect(VoiceAssistant.isNo(s), isTrue, reason: s);
      }
      expect(VoiceAssistant.isNo('yes'), isFalse);
      expect(VoiceAssistant.isNo('add a note'), isFalse);
    });

    test('stop', () {
      for (final s in ['stop', 'Bye!', 'goodbye', "ok that's all", 'bye thanks']) {
        expect(VoiceAssistant.isStop(s), isTrue, reason: s);
      }
      expect(VoiceAssistant.isStop('stop paying netflix'), isFalse);
      expect(VoiceAssistant.isStop('450 bus'), isFalse);
    });
  });

  group('quick expense path', () {
    test('bare amount + merchant is handled on device', () {
      final q = VoiceAssistant.quickExpense('450 petrol HDFC')!;
      expect(q.amount, 450);
      expect(q.categoryKey, 'fuel');
    });

    test('questions and small talk go to the model', () {
      expect(VoiceAssistant.quickExpense('how are you doing'), isNull);
      expect(VoiceAssistant.quickExpense('how much did I spend in 2025'),
          isNull);
      expect(VoiceAssistant.quickExpense('what about 300?'), isNull);
    });

    test('account match', () {
      expect(VoiceAssistant.matchAccount('450 petrol hdfc', ['HDFC', 'Cash']),
          'HDFC');
      expect(VoiceAssistant.matchAccount('450 petrol', ['HDFC']), isNull);
    });
  });

  test('rupee amounts are spoken as words', () {
    expect(VoiceAssistant.forSpeech('Add ₹1,200 petrol?'),
        'Add 1200 rupees petrol?');
  });
}

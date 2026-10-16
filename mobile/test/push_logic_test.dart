import 'package:family_finance/v3/data/push_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushData.parse', () {
    test('call', () {
      final p = PushData.parse({
        'type': 'call',
        'call_id': 'c1',
        'caller_id': 'u1',
        'caller_name': 'Asif',
        'kind': 'video',
        'sent_at': '1000',
      })!;
      expect(p.isCall, isTrue);
      expect(p.id, 'c1');
      expect(p.title, 'Asif');
      expect(p.video, isTrue);
      expect(p.sentAt, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('call without a name or kind', () {
      final p = PushData.parse({'type': 'call', 'call_id': 'c1'})!;
      expect(p.title, 'Family member');
      expect(p.video, isFalse);
      expect(p.sentAt, isNull);
      expect(p.isStale(DateTime.now(), const Duration(seconds: 40)), isFalse);
    });

    test('call_cancel', () {
      final p = PushData.parse({'type': 'call_cancel', 'call_id': 'c1'})!;
      expect(p.isCallCancel, isTrue);
      expect(p.isCall, isFalse);
    });

    test('dm and poke', () {
      final dm = PushData.parse({
        'type': 'dm',
        'message_id': 'm1',
        'sender_id': 'u1',
        'title': 'Sinana',
        'body': 'hi',
        'poke': '0',
      })!;
      expect(dm.isDm, isTrue);
      expect(dm.body, 'hi');
      expect(dm.poke, isFalse);
      final poke = PushData.parse({
        'type': 'dm',
        'message_id': 'm2',
        'body': '👋 Poked you!',
        'poke': '1',
      })!;
      expect(poke.poke, isTrue);
      expect(poke.title, 'Family member');
    });

    test('rejects unknown or incomplete messages', () {
      expect(PushData.parse({}), isNull);
      expect(PushData.parse({'type': 'other', 'call_id': 'c1'}), isNull);
      expect(PushData.parse({'type': 'call'}), isNull);
      expect(PushData.parse({'type': 'dm', 'message_id': 'm1'}), isNull);
    });
  });

  test('a ring older than the ring timeout is stale', () {
    final p = PushData.parse({'type': 'call', 'call_id': 'c', 'sent_at': '0'})!;
    const ring = Duration(seconds: 40);
    expect(p.isStale(DateTime.fromMillisecondsSinceEpoch(39000), ring), isFalse);
    expect(p.isStale(DateTime.fromMillisecondsSinceEpoch(41000), ring), isTrue);
  });

  test('call payload round trip', () {
    expect(callIdFromPayload(callPayload('abc')), 'abc');
    expect(callIdFromPayload('call:'), isNull);
    expect(callIdFromPayload('dm:abc'), isNull);
    expect(callIdFromPayload(null), isNull);
  });

  test('stableHash is fixed and non-negative', () {
    // FNV-1a (31-bit): must never change, or the app and the push handler
    // would post the same call to two different notification ids.
    expect(stableHash(''), 0x811c9dc5 & 0x7fffffff);
    expect(stableHash('abc'), stableHash('abc'));
    expect(stableHash('abc'), isNot(stableHash('abd')));
    expect(stableHash('a-very-long-uuid-0000-1111-2222') >= 0, isTrue);
  });
}

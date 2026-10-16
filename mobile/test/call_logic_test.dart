import 'package:family_finance/v3/data/call_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextPhase', () {
    test('caller: ringing -> connecting -> connected -> ended', () {
      var p = CallPhase.ringing;
      p = nextPhase(p, CallEvent.accepted);
      expect(p, CallPhase.connecting);
      p = nextPhase(p, CallEvent.connected);
      expect(p, CallPhase.connected);
      p = nextPhase(p, CallEvent.hangup);
      expect(p, CallPhase.ended);
    });

    test('callee: incoming -> connecting', () {
      expect(nextPhase(CallPhase.incoming, CallEvent.accepted),
          CallPhase.connecting);
    });

    test('connected only from connecting', () {
      expect(nextPhase(CallPhase.ringing, CallEvent.connected),
          CallPhase.ringing);
      expect(nextPhase(CallPhase.incoming, CallEvent.connected),
          CallPhase.incoming);
    });

    test('ended is final', () {
      for (final e in CallEvent.values) {
        expect(nextPhase(CallPhase.ended, e), CallPhase.ended);
      }
    });

    test('decline, timeout and failure end the call from any phase', () {
      for (final p in CallPhase.values) {
        for (final e in [CallEvent.declined, CallEvent.timeout, CallEvent.failed]) {
          expect(nextPhase(p, e), CallPhase.ended);
        }
      }
    });
  });

  test('finalStatus', () {
    expect(finalStatus(wasConnected: false, reason: CallEvent.declined),
        'declined');
    expect(finalStatus(wasConnected: false, reason: CallEvent.timeout),
        'missed');
    expect(finalStatus(wasConnected: false, reason: CallEvent.hangup),
        'missed');
    expect(finalStatus(wasConnected: true, reason: CallEvent.hangup), 'ended');
    expect(finalStatus(wasConnected: true, reason: CallEvent.failed), 'ended');
  });

  test('formatCallDuration', () {
    expect(formatCallDuration(Duration.zero), '0:00');
    expect(formatCallDuration(const Duration(seconds: 7)), '0:07');
    expect(formatCallDuration(const Duration(minutes: 2, seconds: 31)), '2:31');
    expect(formatCallDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03');
    expect(formatCallDuration(const Duration(seconds: -5)), '0:00');
  });

  test('callLogLabel and callLogForViewer', () {
    final talked = const Duration(minutes: 2, seconds: 31);
    expect(callLogLabel(CallKind.audio, 'ended', talked), 'Voice call · 2:31');
    expect(callLogLabel(CallKind.video, 'missed', Duration.zero),
        'Missed video call');
    expect(callLogLabel(CallKind.audio, 'declined', Duration.zero),
        'Declined voice call');

    expect(callLogForViewer('Missed video call', isCaller: false),
        'Missed video call');
    expect(callLogForViewer('Missed video call', isCaller: true),
        'Video call · No answer');
    expect(callLogForViewer('Declined voice call', isCaller: true),
        'Voice call · Declined');
    expect(callLogForViewer('Voice call · 2:31', isCaller: true),
        'Voice call · 2:31');
    expect(callLogForViewer('Missed ', isCaller: true), 'Missed ');
  });

  test('audioConstraints keep echo cancellation, toggle noise suppression', () {
    final web = audioConstraints(noiseSuppression: false, web: true);
    expect(web['echoCancellation'], true);
    expect(web['autoGainControl'], true);
    expect(web['noiseSuppression'], false);

    final on = audioConstraints(noiseSuppression: true, web: false)['mandatory']
        as Map;
    expect(on['googEchoCancellation'], 'true');
    expect(on['googNoiseSuppression'], 'true');
    final off = audioConstraints(noiseSuppression: false, web: false)['mandatory']
        as Map;
    expect(off['googEchoCancellation'], 'true');
    expect(off['googAutoGainControl'], 'true');
    expect(off['googNoiseSuppression'], 'false');
  });

  test('iceServers: STUN by default, TURN when configured', () {
    expect(iceServers(null), hasLength(1));
    expect(iceServers(null).first['urls'], contains('stun:stun.l.google.com:19302'));

    final withTurn = iceServers({
      'urls': ['turn:t.example.com:3478', 'turns:t.example.com:5349', 'http://bad'],
      'username': 'u',
      'credential': 'c',
    });
    expect(withTurn, hasLength(2));
    expect(withTurn[1]['urls'],
        ['turn:t.example.com:3478', 'turns:t.example.com:5349']);
    expect(withTurn[1]['username'], 'u');

    expect(iceServers({'urls': 'turn:one.example.com'})[1]['urls'],
        ['turn:one.example.com']);
    expect(iceServers({'urls': <String>[]}), hasLength(1));
  });
}

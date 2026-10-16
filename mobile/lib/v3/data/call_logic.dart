/// Pure call rules: phases, final status, chat log text, media constraints
/// and ICE servers. No plugins here, so it is unit-tested directly.
library;

enum CallKind { audio, video }

/// What the call screen shows. `ringing` is the caller waiting; `incoming`
/// is the callee deciding.
enum CallPhase { ringing, incoming, connecting, connected, ended }

enum CallEvent {
  accepted, // callee answered
  connected, // media is flowing
  hangup, // either side ended it
  declined, // callee said no
  timeout, // nobody answered, or media never connected
  failed, // the connection dropped for good
}

CallPhase nextPhase(CallPhase p, CallEvent e) {
  if (p == CallPhase.ended) return p;
  switch (e) {
    case CallEvent.accepted:
      return p == CallPhase.ringing || p == CallPhase.incoming
          ? CallPhase.connecting
          : p;
    case CallEvent.connected:
      return p == CallPhase.connecting ? CallPhase.connected : p;
    case CallEvent.hangup:
    case CallEvent.declined:
    case CallEvent.timeout:
    case CallEvent.failed:
      return CallPhase.ended;
  }
}

/// The `calls.status` a finished call is stored with.
String finalStatus({required bool wasConnected, required CallEvent reason}) {
  if (reason == CallEvent.declined) return 'declined';
  return wasConnected ? 'ended' : 'missed';
}

/// "0:07", "2:31", "1:02:03".
String formatCallDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// The chat entry left after a call: "Voice call · 2:31", "Missed video call".
String callLogLabel(CallKind kind, String status, Duration talked) {
  final what = kind == CallKind.video ? 'video call' : 'voice call';
  switch (status) {
    case 'ended':
      return '${what[0].toUpperCase()}${what.substring(1)} · ${formatCallDuration(talked)}';
    case 'declined':
      return 'Declined $what';
    default:
      return 'Missed $what';
  }
}

/// The log is written from the callee's side ("Missed voice call"); the
/// caller reads it as "Voice call · No answer".
String callLogForViewer(String body, {required bool isCaller}) {
  if (!isCaller) return body;
  for (final (prefix, outcome) in [('Missed ', 'No answer'), ('Declined ', 'Declined')]) {
    if (body.startsWith(prefix) && body.length > prefix.length) {
      final what = body.substring(prefix.length);
      return '${what[0].toUpperCase()}${what.substring(1)} · $outcome';
    }
  }
  return body;
}

/// Mic constraints. Echo cancellation and gain control stay on; the
/// "Noise cancellation" switch only toggles noise suppression. Browsers take
/// the W3C keys; the Android/iOS plugin only reads goog* constraints.
Map<String, dynamic> audioConstraints({
  required bool noiseSuppression,
  required bool web,
}) {
  if (web) {
    return {
      'echoCancellation': true,
      'autoGainControl': true,
      'noiseSuppression': noiseSuppression,
    };
  }
  return {
    'mandatory': {
      'googEchoCancellation': 'true',
      'googAutoGainControl': 'true',
      'googNoiseSuppression': '$noiseSuppression',
      'googHighpassFilter': '$noiseSuppression',
    },
    'optional': <Map<String, dynamic>>[],
  };
}

const _googleStun = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];

/// Google public STUN, plus the TURN relay from the turn-credentials
/// function when one is configured ({urls, username, credential}).
List<Map<String, dynamic>> iceServers(Object? turn) {
  final out = <Map<String, dynamic>>[
    {'urls': _googleStun},
  ];
  if (turn is Map) {
    final raw = turn['urls'];
    final urls = (raw is List ? raw : [raw])
        .map((u) => u?.toString().trim() ?? '')
        .where((u) => u.startsWith('turn:') || u.startsWith('turns:'))
        .toList();
    if (urls.isNotEmpty) {
      out.add({
        'urls': urls,
        'username': turn['username']?.toString() ?? '',
        'credential': turn['credential']?.toString() ?? '',
      });
    }
  }
  return out;
}

/// How long the caller rings before it counts as missed.
const ringTimeout = Duration(seconds: 40);

/// How long an answered call may take to get media flowing. Past this the
/// network is blocking peer-to-peer (usually: no TURN relay).
const connectTimeout = Duration(seconds: 30);

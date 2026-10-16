/// Pure push rules: what an FCM data message means, and stable ids. No
/// plugins here, so it is unit-tested directly.
library;

/// One FCM data message from the `push` Edge Function. Null fields are
/// simply absent for that type.
class PushData {
  final String type; // call | call_cancel | dm
  final String id; // call_id or message_id
  final String title; // caller or sender name
  final String body;
  final String senderId;
  final bool video;
  final bool poke;
  final DateTime? sentAt;

  const PushData._({
    required this.type,
    required this.id,
    this.title = '',
    this.body = '',
    this.senderId = '',
    this.video = false,
    this.poke = false,
    this.sentAt,
  });

  bool get isCall => type == 'call';
  bool get isCallCancel => type == 'call_cancel';
  bool get isDm => type == 'dm';

  /// Null for anything this app version does not understand.
  static PushData? parse(Map<String, dynamic> d) {
    final type = d['type']?.toString();
    String s(String k) => d[k]?.toString().trim() ?? '';
    switch (type) {
      case 'call':
      case 'call_cancel':
        final id = s('call_id');
        if (id.isEmpty) return null;
        final ms = int.tryParse(s('sent_at'));
        return PushData._(
          type: type!,
          id: id,
          title: s('caller_name').isEmpty ? 'Family member' : s('caller_name'),
          senderId: s('caller_id'),
          video: s('kind') == 'video',
          sentAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
        );
      case 'dm':
        final id = s('message_id');
        if (id.isEmpty || s('body').isEmpty) return null;
        return PushData._(
          type: 'dm',
          id: id,
          title: s('title').isEmpty ? 'Family member' : s('title'),
          body: s('body'),
          senderId: s('sender_id'),
          poke: s('poke') == '1',
        );
    }
    return null;
  }

  /// A ring that arrives after the caller has given up must not ring.
  /// [ringFor] matches the caller's ring timeout.
  bool isStale(DateTime now, Duration ringFor) {
    final at = sentAt;
    return at != null && now.difference(at) > ringFor;
  }
}

/// Notification payload of the incoming-call notification.
String callPayload(String callId) => 'call:$callId';

/// The call id in a [callPayload], or null.
String? callIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('call:')) return null;
  final id = payload.substring(5);
  return id.isEmpty ? null : id;
}

/// A hash that is the same in every isolate and every run (FNV-1a), so the
/// app and the push handler post to the same notification id and replace
/// rather than duplicate each other.
int stableHash(String s) {
  var h = 0x811c9dc5 & 0x7fffffff;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';

/// Someone else currently in the notes area.
class NotePresence {
  final String userId;
  final String name;

  /// The note they have open, or null if they are on the list.
  final String? noteId;

  /// True while they are actively typing (decays after a few seconds).
  final bool typing;

  /// Title of the note they are in, so the list banner can name it.
  final String? noteTitle;

  const NotePresence({
    required this.userId,
    required this.name,
    this.noteId,
    this.typing = false,
    this.noteTitle,
  });

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

/// Live collaboration for Family Notes, over one Supabase Realtime channel per
/// family.
///
/// Presence carries who is here and which note they have open. Typing is sent
/// as a broadcast rather than a presence update, because it changes far more
/// often than membership and does not need to be replayed to late joiners.
class NotesPresenceService extends ChangeNotifier {
  NotesPresenceService(this._db);

  final SupabaseClient _db;
  RealtimeChannel? _channel;
  String? _familyId;
  String? _selfName;

  final Map<String, NotePresence> _others = {};
  final Map<String, Timer> _typingTimers = {};

  /// Everyone except me.
  List<NotePresence> get others => _others.values.toList();

  /// Anyone currently editing a note, for the list banner.
  NotePresence? get activeEditor {
    for (final p in _others.values) {
      if (p.noteId != null) return p;
    }
    return null;
  }

  /// Who else has this specific note open.
  List<NotePresence> viewersOf(String noteId) =>
      _others.values.where((p) => p.noteId == noteId).toList();

  bool isLive(String noteId) => viewersOf(noteId).isNotEmpty;

  String? get _uid => _db.auth.currentUser?.id;

  /// Joins the family's notes channel. Safe to call repeatedly.
  Future<void> connect({
    required String familyId,
    required String selfName,
  }) async {
    if (_familyId == familyId && _channel != null) return;
    await disconnect();
    if (_uid == null) return;

    _familyId = familyId;
    _selfName = selfName;

    try {
      final ch = _db.channel(
        'notes:$familyId',
        opts: const RealtimeChannelConfig(self: false),
      );

      ch.onPresenceSync((_) => _syncPresence(ch));
      ch.onPresenceJoin((_) => _syncPresence(ch));
      ch.onPresenceLeave((_) => _syncPresence(ch));

      ch.onBroadcast(
        event: 'typing',
        callback: (payload) => _onTyping(payload),
      );

      ch.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await ch.track({
            'user_id': _uid,
            'name': _selfName,
            'note_id': null,
            'note_title': null,
          });
        } else if (error != null) {
          AppLog.error('NotesPresence.subscribe', error);
        }
      });

      _channel = ch;
    } catch (err, stack) {
      AppLog.error('NotesPresence.connect', err, stack);
    }
  }

  /// Announces which note this device has open (null when back on the list).
  Future<void> setActiveNote(String? noteId, {String? title}) async {
    final ch = _channel;
    if (ch == null || _uid == null) return;
    try {
      await ch.track({
        'user_id': _uid,
        'name': _selfName,
        'note_id': noteId,
        'note_title': title,
      });
    } catch (err, stack) {
      AppLog.error('NotesPresence.setActiveNote', err, stack);
    }
  }

  /// Tells everyone else this device is typing in [noteId].
  void sendTyping(String noteId) {
    final ch = _channel;
    if (ch == null || _uid == null) return;
    try {
      ch.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': _uid, 'name': _selfName, 'note_id': noteId},
      );
    } catch (err, stack) {
      AppLog.error('NotesPresence.sendTyping', err, stack);
    }
  }

  void _syncPresence(RealtimeChannel ch) {
    try {
      final state = ch.presenceState();
      final next = <String, NotePresence>{};

      for (final entry in state) {
        for (final p in entry.presences) {
          final raw = p.payload;
          final id = raw['user_id']?.toString();
          if (id == null || id == _uid) continue;
          next[id] = NotePresence(
            userId: id,
            name: raw['name']?.toString() ?? 'Someone',
            noteId: raw['note_id']?.toString(),
            noteTitle: raw['note_title']?.toString(),
            // Keep any in-flight typing flag; presence sync does not carry it.
            typing: _others[id]?.typing ?? false,
          );
        }
      }

      _others
        ..clear()
        ..addAll(next);
      notifyListeners();
    } catch (err, stack) {
      AppLog.error('NotesPresence.sync', err, stack);
    }
  }

  void _onTyping(Map<String, dynamic> payload) {
    final id = payload['user_id']?.toString();
    if (id == null || id == _uid) return;

    final existing = _others[id];
    _others[id] = NotePresence(
      userId: id,
      name: payload['name']?.toString() ?? existing?.name ?? 'Someone',
      noteId: payload['note_id']?.toString() ?? existing?.noteId,
      noteTitle: existing?.noteTitle,
      typing: true,
    );
    notifyListeners();

    // Typing decays on its own; there is no "stopped typing" event to rely on.
    _typingTimers[id]?.cancel();
    _typingTimers[id] = Timer(const Duration(seconds: 3), () {
      final cur = _others[id];
      if (cur == null) return;
      _others[id] = NotePresence(
        userId: cur.userId,
        name: cur.name,
        noteId: cur.noteId,
        noteTitle: cur.noteTitle,
        typing: false,
      );
      notifyListeners();
    });
  }

  Future<void> disconnect() async {
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    _others.clear();

    final ch = _channel;
    _channel = null;
    _familyId = null;
    if (ch != null) {
      try {
        await _db.removeChannel(ch);
      } catch (err, stack) {
        AppLog.error('NotesPresence.disconnect', err, stack);
      }
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

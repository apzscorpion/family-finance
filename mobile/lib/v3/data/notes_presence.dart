import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import 'note_blocks.dart';
import 'v3_models.dart';

/// Someone else (or another device of yours) currently in the notes area.
class NotePresence {
  final String userId;
  final String sessionKey;
  final String name;

  /// The note they have open, or null if they are on the list.
  final String? noteId;

  /// The specific block they have focused inside [noteId], if any.
  final String? blockId;

  /// True while they are actively typing (decays after a few seconds).
  final bool typing;

  /// Title of the note they are in, so the list banner can name it.
  final String? noteTitle;

  const NotePresence({
    required this.userId,
    this.sessionKey = '',
    required this.name,
    this.noteId,
    this.blockId,
    this.typing = false,
    this.noteTitle,
  });

  String get key => sessionKey.isEmpty ? userId : sessionKey;
  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  NotePresence copyWith({
    String? name,
    String? noteId,
    String? blockId,
    bool? typing,
    String? noteTitle,
  }) =>
      NotePresence(
        userId: userId,
        sessionKey: sessionKey,
        name: name ?? this.name,
        noteId: noteId ?? this.noteId,
        blockId: blockId ?? this.blockId,
        typing: typing ?? this.typing,
        noteTitle: noteTitle ?? this.noteTitle,
      );
}

/// A real-time block delta broadcast by another editor before or alongside
/// full-row persistence.
class NoteBlockDelta {
  final String noteId;
  final String blockId;
  final NoteBlock? block;
  final bool deleted;
  final String? title;
  final String fromUser;
  final String fromName;
  final String sessionId;
  final int seq;

  const NoteBlockDelta({
    required this.noteId,
    required this.blockId,
    this.block,
    this.deleted = false,
    this.title,
    required this.fromUser,
    required this.fromName,
    required this.sessionId,
    required this.seq,
  });
}

/// Live collaboration for Family Notes, over one Supabase Realtime channel per
/// family.
///
/// Combines:
/// 1. Presence (`user_id`, `session_id`, `note_id`, `block_id`, `note_title`)
/// 2. Broadcast (`typing` and `block_delta` for low-latency block-level sync)
/// 3. `postgres_changes` on `public.notes` for authoritative row state
class NotesPresenceService extends ChangeNotifier {
  NotesPresenceService(this._db) : sessionId = _makeSessionId();

  final SupabaseClient _db;
  final String sessionId;

  RealtimeChannel? _channel;
  String? _familyId;
  String? _selfName;
  String? _activeNoteId;
  String? _activeNoteTitle;
  String? _activeBlockId;
  int _seq = 0;

  final Map<String, NotePresence> _others = {};
  final Map<String, Timer> _typingTimers = {};

  final StreamController<NoteBlockDelta> _deltaController =
      StreamController<NoteBlockDelta>.broadcast();
  final StreamController<NoteRow> _rowController =
      StreamController<NoteRow>.broadcast();
  final StreamController<String> _deleteController =
      StreamController<String>.broadcast();

  /// Stream of low-latency block deltas from other sessions.
  Stream<NoteBlockDelta> get blockDeltas => _deltaController.stream;

  /// Stream of authoritative `notes` row inserts/updates from `postgres_changes`.
  Stream<NoteRow> get remoteNoteRows => _rowController.stream;

  /// Stream of deleted note IDs from `postgres_changes`.
  Stream<String> get remoteNoteDeletes => _deleteController.stream;

  /// Everyone except this session.
  List<NotePresence> get others => _others.values.toList();

  /// Anyone currently editing a note, for the list banner.
  NotePresence? get activeEditor {
    for (final p in _others.values) {
      if (p.noteId != null && p.noteId != 'new') return p;
    }
    for (final p in _others.values) {
      if (p.noteId != null) return p;
    }
    return null;
  }

  /// Who else has this specific note open.
  List<NotePresence> viewersOf(String noteId) =>
      _others.values.where((p) => p.noteId == noteId).toList();

  /// Who else currently has [blockId] focused in [noteId].
  List<NotePresence> editorsOfBlock(String noteId, String blockId) => _others
      .values
      .where((p) => p.noteId == noteId && p.blockId == blockId)
      .toList();

  bool isLive(String noteId) => viewersOf(noteId).isNotEmpty;

  String? get _uid => _db.auth.currentUser?.id;

  static String _makeSessionId() {
    final r = Random();
    final bits = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$bits';
  }

  /// Alias for [connect].
  Future<void> ensureChannel({
    required String familyId,
    required String selfName,
  }) => connect(familyId: familyId, selfName: selfName);

  /// Joins the family's notes channel. Safe to call repeatedly.
  Future<void> connect({
    required String familyId,
    required String selfName,
  }) async {
    if (_familyId == familyId && _channel != null) {
      _selfName = selfName;
      return;
    }
    await disconnect();
    if (_uid == null || familyId.isEmpty) return;

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

      ch.onBroadcast(
        event: 'block_delta',
        callback: (payload) => _onBlockDelta(payload),
      );

      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: familyId,
        ),
        callback: _onPostgresChange,
      );

      ch.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _trackCurrent(ch);
        } else if (error != null) {
          AppLog.error('NotesPresence.subscribe', error);
        }
      });

      _channel = ch;
    } catch (err, stack) {
      AppLog.error('NotesPresence.connect', err, stack);
    }
  }

  Future<void> _trackCurrent([RealtimeChannel? ch]) async {
    final target = ch ?? _channel;
    if (target == null || _uid == null) return;
    try {
      await target.track({
        'user_id': _uid,
        'session_id': sessionId,
        'name': _selfName,
        'note_id': _activeNoteId,
        'note_title': _activeNoteTitle,
        'block_id': _activeBlockId,
      });
    } catch (err, stack) {
      AppLog.error('NotesPresence.track', err, stack);
    }
  }

  /// Announces which note (and optionally which block) this device has open.
  Future<void> setActiveNote(
    String? noteId, {
    String? title,
    String? blockId,
  }) async {
    _activeNoteId = noteId;
    _activeNoteTitle = noteId == null ? null : (title ?? _activeNoteTitle);
    _activeBlockId = noteId == null ? null : blockId;
    await _trackCurrent();
  }

  /// Updates the focused block within the active note so followers and
  /// conflict indicators know which block this editor is on.
  Future<void> setFocusedBlock(String? blockId) async {
    if (_activeBlockId == blockId) return;
    _activeBlockId = blockId;
    await _trackCurrent();
  }

  /// Tells everyone else this device is typing in [noteId] (and [blockId]).
  void sendTyping(String noteId, {String? blockId}) {
    final ch = _channel;
    if (ch == null || _uid == null) return;
    try {
      ch.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': _uid,
          'session_id': sessionId,
          'name': _selfName,
          'note_id': noteId,
          'block_id': ?blockId,
        },
      );
    } catch (err, stack) {
      AppLog.error('NotesPresence.sendTyping', err, stack);
    }
  }

  /// Broadcasts a block delta for [noteId] so other open editors see changes
  /// within ~300ms without waiting for the full-row autosave.
  void sendBlockDelta({
    required String noteId,
    required String blockId,
    NoteBlock? block,
    bool deleted = false,
    String? title,
  }) {
    final ch = _channel;
    if (ch == null || _uid == null) return;
    try {
      ch.sendBroadcastMessage(
        event: 'block_delta',
        payload: {
          'note_id': noteId,
          'block_id': blockId,
          if (block != null) 'block': block.toJson(),
          if (deleted) 'deleted': true,
          'title': ?title,
          'from_user': _uid,
          'from_name': _selfName ?? 'Someone',
          'session_id': sessionId,
          'seq': ++_seq,
        },
      );
    } catch (err, stack) {
      AppLog.error('NotesPresence.sendBlockDelta', err, stack);
    }
  }

  void _syncPresence(RealtimeChannel ch) {
    try {
      final state = ch.presenceState();
      final next = <String, NotePresence>{};

      for (final entry in state) {
        for (final p in entry.presences) {
          final raw = p.payload;
          final uid = raw['user_id']?.toString();
          if (uid == null) continue;
          final sid = raw['session_id']?.toString() ?? uid;
          // Ignore our own session, but allow another device of the same user
          // if it has a different session_id.
          if (sid == sessionId || (raw['session_id'] == null && uid == _uid)) {
            continue;
          }
          final key = '$uid:$sid';
          next[key] = NotePresence(
            userId: uid,
            sessionKey: key,
            name: raw['name']?.toString() ?? 'Someone',
            noteId: raw['note_id']?.toString(),
            blockId: raw['block_id']?.toString(),
            noteTitle: raw['note_title']?.toString(),
            typing: _others[key]?.typing ?? false,
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
    final uid = payload['user_id']?.toString();
    if (uid == null) return;
    final sid = payload['session_id']?.toString() ?? uid;
    if (sid == sessionId || (payload['session_id'] == null && uid == _uid)) {
      return;
    }
    final key = '$uid:$sid';

    final existing = _others[key];
    _others[key] = NotePresence(
      userId: uid,
      sessionKey: key,
      name: payload['name']?.toString() ?? existing?.name ?? 'Someone',
      noteId: payload['note_id']?.toString() ?? existing?.noteId,
      blockId: payload['block_id']?.toString() ?? existing?.blockId,
      noteTitle: existing?.noteTitle,
      typing: true,
    );
    notifyListeners();

    _typingTimers[key]?.cancel();
    _typingTimers[key] = Timer(const Duration(seconds: 5), () {
      final cur = _others[key];
      if (cur == null) return;
      _others[key] = cur.copyWith(typing: false);
      notifyListeners();
    });
  }

  void _onBlockDelta(Map<String, dynamic> payload) {
    final fromUser = payload['from_user']?.toString();
    final sid = payload['session_id']?.toString() ?? '';
    if (fromUser == null || sid == sessionId) return;
    if (sid.isEmpty && fromUser == _uid) return;

    final noteId = payload['note_id']?.toString();
    final blockId = payload['block_id']?.toString();
    if (noteId == null || blockId == null) return;

    final rawBlock = payload['block'];
    final block = rawBlock is Map
        ? NoteBlock.fromJson(Map<String, dynamic>.from(rawBlock))
        : null;
    final deleted = (payload['deleted'] as bool?) ?? false;
    final fromName = payload['from_name']?.toString() ?? 'Someone';

    // Also update presence blockId and typing state for this session.
    final key = '$fromUser:${sid.isEmpty ? fromUser : sid}';
    final existing = _others[key];
    _others[key] = NotePresence(
      userId: fromUser,
      sessionKey: key,
      name: existing?.name ?? fromName,
      noteId: noteId,
      blockId: blockId,
      noteTitle: existing?.noteTitle,
      typing: true,
    );
    _typingTimers[key]?.cancel();
    _typingTimers[key] = Timer(const Duration(seconds: 5), () {
      final cur = _others[key];
      if (cur == null) return;
      _others[key] = cur.copyWith(typing: false);
      notifyListeners();
    });
    notifyListeners();

    _deltaController.add(
      NoteBlockDelta(
        noteId: noteId,
        blockId: blockId,
        block: block,
        deleted: deleted,
        title: payload['title']?.toString(),
        fromUser: fromUser,
        fromName: fromName,
        sessionId: sid,
        seq: (payload['seq'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  void _onPostgresChange(PostgresChangePayload payload) {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final rec = payload.newRecord;
          if (rec.isNotEmpty) {
            final row = NoteRow.fromJson(Map<String, dynamic>.from(rec));
            _rowController.add(row);
          }
        case PostgresChangeEvent.delete:
          final old = payload.oldRecord;
          final id = old['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _deleteController.add(id);
          }
        case PostgresChangeEvent.all:
          break;
      }
    } catch (err, stack) {
      AppLog.error('NotesPresence.postgresChange', err, stack);
    }
  }

  /// Injects a simulated presence state for unit/widget testing.
  @visibleForTesting
  void debugSetOthers(List<NotePresence> list) {
    _others
      ..clear()
      ..addEntries(list.map((p) => MapEntry(p.key, p)));
    notifyListeners();
  }

  /// Emits a simulated block delta for unit/widget testing.
  @visibleForTesting
  void debugEmitBlockDelta(NoteBlockDelta delta) {
    _onBlockDelta({
      'note_id': delta.noteId,
      'block_id': delta.blockId,
      if (delta.block != null) 'block': delta.block!.toJson(),
      if (delta.deleted) 'deleted': true,
      if (delta.title != null) 'title': delta.title,
      'from_user': delta.fromUser,
      'from_name': delta.fromName,
      'session_id': delta.sessionId,
      'seq': delta.seq,
    });
  }

  /// Emits a simulated postgres_changes NoteRow update for unit/widget testing.
  @visibleForTesting
  void debugEmitRemoteRow(NoteRow row) {
    _rowController.add(row);
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
    _deltaController.close();
    _rowController.close();
    _deleteController.close();
    super.dispose();
  }
}

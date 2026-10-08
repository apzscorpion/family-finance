import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'v3_models.dart';
import 'v3_repository.dart';

/// Summary of a 1:1 conversation thread with a family member.
class ChatThreadSummary {
  final MemberRow partner;
  final DirectMessageRow? lastMessage;
  final int unreadCount;

  const ChatThreadSummary({
    required this.partner,
    required this.lastMessage,
    required this.unreadCount,
  });
}

/// Manages direct messages between family members, backed by `direct_messages`
/// and a single family-scoped `postgres_changes` channel while active.
class ChatController extends ChangeNotifier {
  final V3Repository repo;
  final SupabaseClient? _db;

  String? _familyId;
  String? _myId;
  String? _activePartnerId;
  RealtimeChannel? _channel;
  bool _loading = false;
  String? _error;

  final List<DirectMessageRow> _messages = [];

  ChatController(this.repo, [this._db]);

  bool get loading => _loading;
  String? get error => _error;
  String? get activePartnerId => _activePartnerId;
  List<DirectMessageRow> get allMessages => List.unmodifiable(_messages);

  /// Total unread messages addressed to the signed-in member.
  int get totalUnread {
    final me = _myId;
    if (me == null || me.isEmpty) return 0;
    var count = 0;
    for (final m in _messages) {
      if (m.recipientId == me && !m.isRead) count++;
    }
    return count;
  }

  /// Unread messages from a specific family member.
  int unreadFrom(String partnerId) {
    final me = _myId;
    if (me == null || me.isEmpty) return 0;
    var count = 0;
    for (final m in _messages) {
      if (m.senderId == partnerId && m.recipientId == me && !m.isRead) {
        count++;
      }
    }
    return count;
  }

  /// Chronological messages (oldest first) between the signed-in user and
  /// [partnerId].
  List<DirectMessageRow> threadWith(String partnerId) {
    final me = _myId;
    if (me == null || me.isEmpty) return const [];
    final list = _messages
        .where(
          (m) =>
              (m.senderId == me && m.recipientId == partnerId) ||
              (m.senderId == partnerId && m.recipientId == me),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Most recent message between the signed-in user and [partnerId], if any.
  DirectMessageRow? lastMessageWith(String partnerId) {
    final thread = threadWith(partnerId);
    return thread.isEmpty ? null : thread.last;
  }

  /// Builds thread summaries for all other members in the family, ordered by
  /// most recent message first, then alphabetically by member name.
  List<ChatThreadSummary> threadsForMembers(List<MemberRow> members) {
    final me = _myId;
    final others = members
        .where((m) => m.isActive && m.userId != me)
        .map(
          (m) => ChatThreadSummary(
            partner: m,
            lastMessage: lastMessageWith(m.userId),
            unreadCount: unreadFrom(m.userId),
          ),
        )
        .toList();

    others.sort((a, b) {
      final aTime = a.lastMessage?.createdAt;
      final bTime = b.lastMessage?.createdAt;
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.partner.name.toLowerCase().compareTo(
            b.partner.name.toLowerCase(),
          );
    });
    return others;
  }

  /// Connects to the family's DM stream and loads message history.
  Future<void> ensureJoined({
    required String familyId,
    required String? myId,
  }) async {
    if (familyId.isEmpty || myId == null || myId.isEmpty) return;
    if (_familyId == familyId && _myId == myId && _channel != null) return;

    await leave();
    _familyId = familyId;
    _myId = myId;

    await refresh();
    _subscribe(familyId);
  }

  /// Reloads messages from the repository.
  Future<void> refresh() async {
    final fid = _familyId;
    if (fid == null || fid.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final list = await V3Repository.guard(
      'directMessages',
      () => repo.directMessages(fid),
    );
    _loading = false;
    if (list != null) {
      _messages
        ..clear()
        ..addAll(list);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      _error = 'Could not load messages';
    }
    notifyListeners();
  }

  void _subscribe(String familyId) {
    final db = _db;
    if (db == null) return;

    final ch = db.channel('dm:$familyId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: familyId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isEmpty) return;
            _upsertMessage(DirectMessageRow.fromJson(rec));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: familyId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isEmpty) return;
            _upsertMessage(DirectMessageRow.fromJson(rec));
          },
        )
        .subscribe();

    _channel = ch;
  }

  void _upsertMessage(DirectMessageRow row) {
    final me = _myId;
    if (me != null && row.senderId != me && row.recipientId != me) {
      return;
    }
    final idx = _messages.indexWhere((m) => m.id == row.id);
    if (idx >= 0) {
      _messages[idx] = row;
    } else {
      _messages.add(row);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // If the user is actively viewing the thread with the sender, mark it read.
    if (me != null &&
        row.recipientId == me &&
        !row.isRead &&
        _activePartnerId == row.senderId) {
      openThread(row.senderId);
      return;
    }
    notifyListeners();
  }

  /// Opens a 1:1 thread with [partnerId] and marks any unread messages from
  /// them as read.
  Future<void> openThread(String partnerId) async {
    _activePartnerId = partnerId;
    final me = _myId;
    final fid = _familyId;
    var changed = false;
    final now = DateTime.now();

    if (me != null) {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.senderId == partnerId && m.recipientId == me && !m.isRead) {
          _messages[i] = m.copyWith(readAt: now);
          changed = true;
        }
      }
    }
    notifyListeners();

    if (changed && fid != null && fid.isNotEmpty) {
      await V3Repository.guard(
        'markDirectMessagesRead',
        () => repo.markDirectMessagesRead(familyId: fid, senderId: partnerId),
      );
    }
  }

  void closeThread() {
    if (_activePartnerId == null) return;
    _activePartnerId = null;
    notifyListeners();
  }

  /// Sends a direct message to [recipientId]. Returns true if stored.
  Future<bool> sendMessage({
    required String recipientId,
    required String body,
  }) async {
    final fid = _familyId;
    final trimmed = body.trim();
    if (fid == null || fid.isEmpty || trimmed.isEmpty) return false;

    final sent = await V3Repository.guard(
      'sendDirectMessage',
      () => repo.sendDirectMessage(
        familyId: fid,
        recipientId: recipientId,
        body: trimmed,
      ),
    );
    if (sent != null) {
      _upsertMessage(sent);
      return true;
    }
    _error = 'Could not send message';
    notifyListeners();
    return false;
  }

  Future<void> leave() async {
    final ch = _channel;
    _channel = null;
    _activePartnerId = null;
    if (ch != null && _db != null) {
      await _db.removeChannel(ch);
    }
  }

  @visibleForTesting
  void seedForTest({
    required String familyId,
    required String myId,
    List<DirectMessageRow> messages = const [],
  }) {
    _familyId = familyId;
    _myId = myId;
    _messages
      ..clear()
      ..addAll(messages);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  @visibleForTesting
  void injectMessageForTest(DirectMessageRow row) {
    _upsertMessage(row);
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null && _db != null) {
      _db.removeChannel(ch);
    }
    super.dispose();
  }
}

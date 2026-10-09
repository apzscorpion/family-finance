import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import 'chat_platform_io.dart'
    if (dart.library.js_interop) 'chat_platform_web.dart';
import 'v3_models.dart';
import 'v3_repository.dart';

/// Summary of a 1:1 conversation thread with a family member.
class ChatThreadSummary {
  final MemberRow partner;
  final DirectMessageRow? lastMessage;
  final int unreadCount;
  final bool isOnline;
  final bool isTyping;

  const ChatThreadSummary({
    required this.partner,
    required this.lastMessage,
    required this.unreadCount,
    this.isOnline = false,
    this.isTyping = false,
  });
}

/// Manages direct messages between family members, backed by `direct_messages`,
/// low-latency Realtime WebSocket broadcast events (`dm_fast`, `dm_read`,
/// `dm_typing`, `dm_hello`, `dm_heartbeat`, `dm_delete`, `dm_clear`),
/// Realtime Presence (`online` dots), `postgres_changes`, and system/browser
/// notifications.
class ChatController extends ChangeNotifier with WidgetsBindingObserver {
  final V3Repository repo;
  final SupabaseClient? _db;
  final String sessionId = _makeSessionId();

  String? _familyId;
  String? _myId;
  String? _activePartnerId;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _wsConnected = false;
  bool _loading = false;
  bool _refreshInFlight = false;
  bool _initialLoadDone = false;
  bool _appInForeground = true;
  String? _error;
  DateTime? _lastTypingSentAt;

  final List<DirectMessageRow> _messages = [];
  final Set<String> _notifiedIds = <String>{};
  final Map<String, String> _memberNames = <String, String>{};
  final Set<String> _presenceOnlineUsers = <String>{};
  final Set<String> _debugOnlineUsers = <String>{};
  final Map<String, DateTime> _lastSeenAt = <String, DateTime>{};
  final Map<String, Timer> _typingTimers = <String, Timer>{};
  final Set<String> _typingUsers = <String>{};

  final StreamController<DirectMessageRow> _incomingAlertController =
      StreamController<DirectMessageRow>.broadcast();

  void Function(String senderId)? onTapNotification;

  ChatController(this.repo, [this._db]) {
    if (_db != null) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  static String _makeSessionId() {
    final r = Random();
    final bits =
        List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$bits';
  }

  bool get loading => _loading;
  bool get isRealtimeConnected => _wsConnected;
  String? get error => _error;
  String? get activePartnerId => _activePartnerId;
  List<DirectMessageRow> get allMessages => List.unmodifiable(_messages);

  /// Stream of newly arrived incoming DMs/pokes for showing in-app banners.
  Stream<DirectMessageRow> get incomingAlerts =>
      _incomingAlertController.stream;

  String get notificationPermissionStatus => chatNotificationPermissionStatus;

  Future<bool> requestNotificationsPermission() async {
    final granted = await requestChatNotificationPermission(
      onTapSender: (senderId) => onTapNotification?.call(senderId),
    );
    notifyListeners();
    return granted;
  }

  String memberNameOf(String userId) =>
      _memberNames[userId] ?? 'Family member';

  /// Whether [userId] is currently online via WebSocket Presence or heartbeat.
  bool isUserOnline(String userId) {
    if (userId.isEmpty) return false;
    if (userId == _myId && _wsConnected) return true;
    if (_debugOnlineUsers.contains(userId)) return true;
    if (_presenceOnlineUsers.contains(userId)) return true;
    final last = _lastSeenAt[userId];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 45)) {
      return true;
    }
    return false;
  }

  /// Last time [userId] was observed active in chat.
  DateTime? lastSeenOf(String userId) => _lastSeenAt[userId];

  /// Whether [userId] is currently typing a message to the signed-in user.
  bool isPartnerTyping(String userId) => _typingUsers.contains(userId);

  /// Number of other active family members currently online.
  int onlinePeersCount(List<MemberRow> members) {
    final me = _myId;
    var count = 0;
    for (final m in members) {
      if (m.isActive && m.userId != me && isUserOnline(m.userId)) {
        count++;
      }
    }
    return count;
  }

  /// Updates member directory and auto-joins the family's DM channel as soon as
  /// the workspace is loaded, so incoming messages trigger notifications even
  /// before the user opens the Chat screen.
  void syncContext({
    required String familyId,
    required String? myId,
    required List<MemberRow> members,
    void Function(String senderId)? onTapSender,
  }) {
    for (final m in members) {
      _memberNames[m.userId] = m.name;
    }
    if (onTapSender != null) {
      onTapNotification = onTapSender;
    }
    if (familyId.isNotEmpty && myId != null && myId.isNotEmpty) {
      ensureJoined(familyId: familyId, myId: myId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground && _familyId != null && _familyId!.isNotEmpty) {
      refresh(notifyNew: true);
      _sendHelloOrHeartbeat(event: 'dm_hello');
      _trackPresence();
    }
  }

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
  /// most recent message first, then online status, then alphabetically.
  List<ChatThreadSummary> threadsForMembers(List<MemberRow> members) {
    for (final m in members) {
      _memberNames[m.userId] = m.name;
    }
    final me = _myId;
    final others = members
        .where((m) => m.isActive && m.userId != me)
        .map(
          (m) => ChatThreadSummary(
            partner: m,
            lastMessage: lastMessageWith(m.userId),
            unreadCount: unreadFrom(m.userId),
            isOnline: isUserOnline(m.userId),
            isTyping: isPartnerTyping(m.userId),
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
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
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
    if (_familyId == familyId &&
        _myId == myId &&
        (_channel != null || _initialLoadDone)) {
      return;
    }

    await leave();
    _familyId = familyId;
    _myId = myId;
    _initialLoadDone = false;

    if (_db != null) {
      unawaited(
        initChatNotifications(
          onTapSender: (senderId) => onTapNotification?.call(senderId),
        ),
      );
    }

    // Subscribe to WebSocket channel immediately so live broadcasts and
    // presence connect in parallel with the initial history load.
    _subscribe(familyId);

    await refresh(notifyNew: false);
    _initialLoadDone = true;
    _syncUnreadBadge();

    if (_db != null) {
      unawaited(startChatBackgroundLink());
      var tick = 0;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        // Minimised, the socket carries the alerts; polling is only a backstop.
        if (!_appInForeground && ++tick % 10 != 0) return;
        refresh(notifyNew: true);
      });
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 18), (_) {
        if (_appInForeground) {
          _sendHelloOrHeartbeat(event: 'dm_heartbeat');
          _trackPresence();
        }
      });
    }
  }

  void _syncUnreadBadge({String? latestSender}) {
    if (_db == null) return;
    updateChatUnreadBadge(totalUnread, latestSender: latestSender);
  }

  /// Reloads messages from the repository.
  Future<void> refresh({bool notifyNew = false}) async {
    final fid = _familyId;
    if (fid == null || fid.isEmpty || _refreshInFlight) return;
    _refreshInFlight = true;
    if (!_initialLoadDone) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final list = await V3Repository.guard(
        'directMessages',
        () => repo.directMessages(fid),
      );
      _loading = false;
      if (list != null) {
        final me = _myId;
        if (!notifyNew || !_initialLoadDone) {
          for (final m in list) {
            _notifiedIds.add(m.id);
          }
        } else if (me != null) {
          for (final m in list) {
            if (m.recipientId == me &&
                !m.isRead &&
                !_notifiedIds.contains(m.id)) {
              _notifiedIds.add(m.id);
              _maybeNotifyIncoming(m);
            }
          }
        }

        // Preserve any in-flight optimistic messages not yet confirmed.
        final optimistic =
            _messages.where((m) => m.id.startsWith('temp_')).toList();
        _messages
          ..clear()
          ..addAll(list);
        for (final opt in optimistic) {
          final alreadySaved = list.any(
            (r) =>
                r.senderId == opt.senderId &&
                r.recipientId == opt.recipientId &&
                r.body == opt.body &&
                r.createdAt.difference(opt.createdAt).inSeconds.abs() < 15,
          );
          if (!alreadySaved) {
            _messages.add(opt);
          }
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (_activePartnerId != null && _appInForeground) {
          final changed = _markActivePartnerReadLocally(_activePartnerId!);
          if (changed) {
            _broadcastReadReceipt(_activePartnerId!);
            unawaited(
              V3Repository.guard(
                'markDirectMessagesRead',
                () => repo.markDirectMessagesRead(
                  familyId: fid,
                  senderId: _activePartnerId!,
                ),
              ),
            );
          }
        }
        _syncUnreadBadge();
      } else if (!_initialLoadDone) {
        _error = 'Could not load messages';
      }
      notifyListeners();
    } finally {
      _refreshInFlight = false;
    }
  }

  void _subscribe(String familyId) {
    final db = _db;
    if (db == null) return;

    final ch = db.channel(
      'dm:$familyId',
      opts: const RealtimeChannelConfig(self: false, ack: true),
    );

    ch
        .onPresenceSync((_) => _syncPresence(ch))
        .onPresenceJoin((_) => _syncPresence(ch))
        .onPresenceLeave((_) => _syncPresence(ch))
        .onBroadcast(
          event: 'dm_hello',
          callback: (payload) {
            _recordPeerPresencePayload(payload);
            // Reply immediately so the newly joined peer sees us online in <50ms.
            _sendHelloOrHeartbeat(event: 'dm_heartbeat');
          },
        )
        .onBroadcast(
          event: 'dm_heartbeat',
          callback: _recordPeerPresencePayload,
        )
        .onBroadcast(
          event: 'dm_typing',
          callback: _onTypingBroadcast,
        )
        .onBroadcast(
          event: 'dm_read',
          callback: _onReadBroadcast,
        )
        .onBroadcast(
          event: 'dm_fast',
          callback: (payload) {
            final rowMap = payload['row'];
            if (rowMap is Map) {
              final row = DirectMessageRow.fromJson(
                Map<String, dynamic>.from(rowMap),
              );
              _markUserSeen(row.senderId);
              _clearTypingFor(row.senderId);
              final tempId = payload['temp_id']?.toString();
              if (tempId != null && tempId.isNotEmpty) {
                _messages.removeWhere((m) => m.id == tempId);
              }
              _upsertMessage(row);
            }
          },
        )
        .onBroadcast(
          event: 'dm_delete',
          callback: (payload) {
            final id = payload['id']?.toString();
            if (id == null || id.isEmpty) return;
            final before = _messages.length;
            _messages.removeWhere((m) => m.id == id);
            if (_messages.length != before) {
              _syncUnreadBadge();
              notifyListeners();
            }
          },
        )
        .onBroadcast(
          event: 'dm_clear',
          callback: (payload) {
            final a = payload['a']?.toString();
            final b = payload['b']?.toString();
            if (a == null || b == null) return;
            final before = _messages.length;
            _messages.removeWhere(
              (m) =>
                  (m.senderId == a && m.recipientId == b) ||
                  (m.senderId == b && m.recipientId == a),
            );
            if (_messages.length != before) {
              _syncUnreadBadge();
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
              case PostgresChangeEvent.update:
                final rec = payload.newRecord;
                if (rec.isEmpty) return;
                final row = DirectMessageRow.fromJson(
                  Map<String, dynamic>.from(rec),
                );
                if (row.familyId.isNotEmpty && row.familyId != familyId) {
                  return;
                }
                _markUserSeen(row.senderId);
                if (payload.eventType == PostgresChangeEvent.insert) {
                  _clearTypingFor(row.senderId);
                }
                _upsertMessage(row);
              case PostgresChangeEvent.delete:
                final oldRec = payload.oldRecord;
                final id = oldRec['id']?.toString();
                if (id == null || id.isEmpty) return;
                final before = _messages.length;
                _messages.removeWhere((m) => m.id == id);
                if (_messages.length != before) {
                  _syncUnreadBadge();
                  notifyListeners();
                }
              case PostgresChangeEvent.all:
                break;
            }
          },
        )
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _wsConnected = true;
            _reconnectTimer?.cancel();
            notifyListeners();
            await _trackPresence(ch);
            _sendHelloOrHeartbeat(event: 'dm_hello', channel: ch);
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            final wasConnected = _wsConnected;
            _wsConnected = false;
            if (wasConnected) notifyListeners();
            if (error != null) {
              AppLog.error('ChatController.subscribe', error);
            }
            _scheduleReconnect(familyId);
          }
        });

    _channel = ch;
  }

  void _scheduleReconnect(String familyId) {
    if (_db == null || _familyId != familyId) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_familyId != familyId || _wsConnected) return;
      final old = _channel;
      _channel = null;
      if (old != null) {
        try {
          await _db.removeChannel(old);
        } catch (_) {}
      }
      if (_familyId == familyId) {
        _subscribe(familyId);
        unawaited(refresh(notifyNew: true));
      }
    });
  }

  Future<void> _trackPresence([RealtimeChannel? ch]) async {
    final target = ch ?? _channel;
    final me = _myId;
    if (target == null || me == null || me.isEmpty || !_wsConnected) return;
    try {
      await target.track({
        'user_id': me,
        'session_id': sessionId,
        'name': _memberNames[me] ?? 'Me',
        'active_partner_id': _activePartnerId,
        'online_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void _sendHelloOrHeartbeat({
    required String event,
    RealtimeChannel? channel,
  }) {
    final target = channel ?? _channel;
    final me = _myId;
    if (target == null || me == null || me.isEmpty || !_wsConnected) return;
    try {
      unawaited(
        target.sendBroadcastMessage(
          event: event,
          payload: {
            'user_id': me,
            'session_id': sessionId,
            'name': _memberNames[me] ?? '',
            'ts': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
    } catch (_) {}
  }

  void _syncPresence(RealtimeChannel ch) {
    try {
      final state = ch.presenceState();
      final nextOnline = <String>{};
      final now = DateTime.now();
      for (final entry in state) {
        for (final p in entry.presences) {
          final uid = p.payload['user_id']?.toString();
          if (uid != null && uid.isNotEmpty) {
            nextOnline.add(uid);
            _lastSeenAt[uid] = now;
          }
        }
      }
      _presenceOnlineUsers
        ..clear()
        ..addAll(nextOnline);
      notifyListeners();
    } catch (_) {}
  }

  void _recordPeerPresencePayload(Map<String, dynamic> payload) {
    final uid = payload['user_id']?.toString();
    if (uid == null || uid.isEmpty || uid == _myId) return;
    final name = payload['name']?.toString();
    if (name != null && name.isNotEmpty) {
      _memberNames[uid] = name;
    }
    _markUserSeen(uid);
  }

  void _markUserSeen(String userId) {
    if (userId.isEmpty) return;
    final wasOnline = isUserOnline(userId);
    _lastSeenAt[userId] = DateTime.now();
    if (!wasOnline) {
      notifyListeners();
    }
  }

  void _onTypingBroadcast(Map<String, dynamic> payload) {
    final senderId = payload['sender_id']?.toString();
    final recipientId = payload['recipient_id']?.toString();
    if (senderId == null ||
        senderId.isEmpty ||
        senderId == _myId ||
        recipientId != _myId) {
      return;
    }
    _markUserSeen(senderId);
    final added = _typingUsers.add(senderId);
    if (added) {
      notifyListeners();
    }
    _typingTimers[senderId]?.cancel();
    _typingTimers[senderId] = Timer(const Duration(seconds: 4), () {
      if (_typingUsers.remove(senderId)) {
        notifyListeners();
      }
    });
  }

  void _clearTypingFor(String senderId) {
    _typingTimers[senderId]?.cancel();
    _typingTimers.remove(senderId);
    _typingUsers.remove(senderId);
  }

  /// Broadcasts a throttled typing indicator to [recipientId].
  void sendTyping(String recipientId) {
    final ch = _channel;
    final me = _myId;
    if (ch == null || me == null || me.isEmpty || recipientId.isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSentAt != null &&
        now.difference(_lastTypingSentAt!) <
            const Duration(milliseconds: 1100)) {
      return;
    }
    _lastTypingSentAt = now;
    try {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'dm_typing',
          payload: {
            'sender_id': me,
            'recipient_id': recipientId,
            'ts': now.toUtc().toIso8601String(),
          },
        ),
      );
    } catch (_) {}
  }

  void _broadcastReadReceipt(String partnerId) {
    final ch = _channel;
    final me = _myId;
    if (ch == null || me == null || me.isEmpty) return;
    try {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'dm_read',
          payload: {
            'reader_id': me,
            'sender_id': partnerId,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          },
        ),
      );
    } catch (_) {}
  }

  void _onReadBroadcast(Map<String, dynamic> payload) {
    final readerId = payload['reader_id']?.toString();
    final senderId = payload['sender_id']?.toString();
    if (readerId == null || senderId == null || senderId != _myId) return;
    _markUserSeen(readerId);
    final readAtRaw = payload['read_at']?.toString();
    final readAt =
        (readAtRaw != null ? DateTime.tryParse(readAtRaw) : null) ??
            DateTime.now();
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.senderId == _myId && m.recipientId == readerId && !m.isRead) {
        _messages[i] = m.copyWith(readAt: readAt);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _maybeNotifyIncoming(DirectMessageRow row) {
    final me = _myId;
    if (me == null || row.recipientId != me || row.senderId == me) return;

    final senderName = _memberNames[row.senderId] ?? 'Family member';
    final isViewingThreadInForeground =
        _activePartnerId == row.senderId && _appInForeground;

    final previewBody = row.isImage
        ? (row.body.isNotEmpty && row.body != '📷 Photo'
            ? '📷 ${row.body}'
            : '📷 Sent a photo')
        : row.body;

    if (row.isPoke || !isViewingThreadInForeground) {
      _incomingAlertController.add(row);
    }

    if (_db == null) return;

    _syncUnreadBadge(latestSender: senderName);

    // Pokes always buzz and post a system/browser notification; regular
    // messages post a notification whenever the user isn't actively looking at
    // that open thread.
    unawaited(
      notifyIncomingChat(
        messageId: row.id,
        senderId: row.senderId,
        senderName: senderName,
        body: previewBody,
        isPoke: row.isPoke,
        showSystemNotification: row.isPoke || !isViewingThreadInForeground,
      ),
    );
  }

  void _upsertMessage(DirectMessageRow row) {
    final me = _myId;
    if (me != null && row.senderId != me && row.recipientId != me) {
      return;
    }

    // Remove matching optimistic placeholder if present.
    if (!row.id.startsWith('temp_')) {
      _messages.removeWhere(
        (m) =>
            m.id.startsWith('temp_') &&
            m.senderId == row.senderId &&
            m.recipientId == row.recipientId &&
            m.body == row.body,
      );
    }

    final idx = _messages.indexWhere((m) => m.id == row.id);
    final isNew = idx < 0;
    if (idx >= 0) {
      final prev = _messages[idx];
      // Preserve local readAt if already marked read locally.
      _messages[idx] =
          row.readAt == null && prev.readAt != null
              ? row.copyWith(readAt: prev.readAt)
              : row;
    } else {
      _messages.add(row);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final isTemp = row.id.startsWith('temp_');
    if (isNew &&
        !isTemp &&
        me != null &&
        row.recipientId == me &&
        !_notifiedIds.contains(row.id)) {
      _notifiedIds.add(row.id);
      _maybeNotifyIncoming(row);
    }

    // If the user is actively viewing the thread with the sender, mark it read.
    if (me != null &&
        row.recipientId == me &&
        !row.isRead &&
        _activePartnerId == row.senderId &&
        _appInForeground) {
      if (isTemp) {
        _markActivePartnerReadLocally(row.senderId);
        notifyListeners();
      } else {
        openThread(row.senderId);
      }
      return;
    }
    _syncUnreadBadge();
    notifyListeners();
  }

  bool _markActivePartnerReadLocally(String partnerId) {
    final me = _myId;
    if (me == null) return false;
    var changed = false;
    final now = DateTime.now();
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.senderId == partnerId && m.recipientId == me && !m.isRead) {
        _messages[i] = m.copyWith(readAt: now);
        changed = true;
      }
    }
    return changed;
  }

  /// Opens a 1:1 thread with [partnerId] and marks any unread messages from
  /// them as read.
  Future<void> openThread(String partnerId) async {
    _activePartnerId = partnerId;
    final fid = _familyId;
    final changed = _markActivePartnerReadLocally(partnerId);
    _syncUnreadBadge();
    notifyListeners();
    unawaited(_trackPresence());

    if (changed && fid != null && fid.isNotEmpty) {
      _broadcastReadReceipt(partnerId);
      await V3Repository.guard(
        'markDirectMessagesRead',
        () => repo.markDirectMessagesRead(familyId: fid, senderId: partnerId),
      );
    }
  }

  /// Clears the active partner pointer. Does NOT call [notifyListeners]
  /// synchronously so calling this from `State.dispose()` never locks or
  /// corrupts the widget tree during navigation.
  void closeThread() {
    _activePartnerId = null;
  }

  /// Sends a direct message (text, image, or poke) to [recipientId] with
  /// instant optimistic UI and low-latency Realtime broadcast.
  Future<bool> sendMessage({
    required String recipientId,
    required String body,
    String kind = 'text',
    String? imageData,
  }) async {
    final fid = _familyId;
    final me = _myId;
    final trimmed = body.trim().isEmpty && imageData != null
        ? '📷 Photo'
        : body.trim();
    if (fid == null || fid.isEmpty || trimmed.isEmpty) return false;

    final tempId =
        'temp_${DateTime.now().microsecondsSinceEpoch}_${_messages.length}';
    if (me != null && me.isNotEmpty) {
      final optimistic = DirectMessageRow(
        id: tempId,
        familyId: fid,
        senderId: me,
        recipientId: recipientId,
        body: trimmed,
        kind: kind,
        imageData: imageData,
        createdAt: DateTime.now(),
      );
      _messages.add(optimistic);
      notifyListeners();

      // Broadcast immediately over WebSocket for sub-100ms delivery to online peers.
      final ch = _channel;
      if (ch != null) {
        unawaited(
          ch.sendBroadcastMessage(
            event: 'dm_fast',
            payload: {'row': optimistic.toJson(), 'temp_id': tempId},
          ),
        );
      }
    }

    final sent = await V3Repository.guard(
      'sendDirectMessage',
      () => repo.sendDirectMessage(
        familyId: fid,
        recipientId: recipientId,
        body: trimmed,
        kind: kind,
        imageData: imageData,
      ),
    );
    if (sent != null) {
      _notifiedIds.add(sent.id);
      _messages.removeWhere((m) => m.id == tempId);
      _upsertMessage(sent);
      final ch = _channel;
      if (ch != null) {
        unawaited(
          ch.sendBroadcastMessage(
            event: 'dm_fast',
            payload: {'row': sent.toJson(), 'temp_id': tempId},
          ),
        );
      }
      return true;
    }
    _messages.removeWhere((m) => m.id == tempId);
    _error = 'Could not send message';
    notifyListeners();
    return false;
  }

  /// Sends a base64-encoded image message with an optional [caption].
  Future<bool> sendImage({
    required String recipientId,
    required String base64Data,
    String caption = '',
  }) {
    return sendMessage(
      recipientId: recipientId,
      body: caption.trim().isEmpty ? '📷 Photo' : caption.trim(),
      kind: 'image',
      imageData: base64Data,
    );
  }

  /// Sends a quick poke ("👋 Poked you!") that vibrates and notifies the
  /// recipient's device immediately.
  Future<bool> pokeMember(String recipientId) {
    return sendMessage(
      recipientId: recipientId,
      body: '👋 Poked you!',
      kind: 'poke',
    );
  }

  /// Deletes a single message for both sender and receiver.
  Future<bool> deleteMessage(String messageId) async {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    DirectMessageRow? removed;
    if (idx >= 0) {
      removed = _messages.removeAt(idx);
      _syncUnreadBadge();
      notifyListeners();
    }

    final ch = _channel;
    if (ch != null) {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'dm_delete',
          payload: {'id': messageId},
        ),
      );
    }

    if (messageId.startsWith('temp_')) return true;

    var ok = true;
    try {
      await repo.deleteDirectMessage(messageId);
    } catch (_) {
      ok = false;
    }
    if (!ok && removed != null) {
      _messages.add(removed);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _syncUnreadBadge();
      notifyListeners();
    }
    return ok;
  }

  /// Clears all messages in the 1:1 thread with [partnerId] for both sender
  /// and receiver.
  Future<bool> clearThread(String partnerId) async {
    final fid = _familyId;
    final me = _myId;
    if (fid == null || fid.isEmpty || me == null || me.isEmpty) return false;

    final backup = _messages
        .where(
          (m) =>
              (m.senderId == me && m.recipientId == partnerId) ||
              (m.senderId == partnerId && m.recipientId == me),
        )
        .toList();
    if (backup.isEmpty) return true;

    _messages.removeWhere(
      (m) =>
          (m.senderId == me && m.recipientId == partnerId) ||
          (m.senderId == partnerId && m.recipientId == me),
    );
    _syncUnreadBadge();
    notifyListeners();

    final ch = _channel;
    if (ch != null) {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'dm_clear',
          payload: {'a': me, 'b': partnerId},
        ),
      );
    }

    var ok = true;
    try {
      await repo.clearDirectThread(familyId: fid, partnerId: partnerId);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      _messages.addAll(backup);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _syncUnreadBadge();
      notifyListeners();
    }
    return ok;
  }

  Future<void> leave() async {
    if (_db != null) unawaited(stopChatBackgroundLink());
    _pollTimer?.cancel();
    _pollTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    _typingUsers.clear();
    _presenceOnlineUsers.clear();
    _wsConnected = false;

    final ch = _channel;
    _channel = null;
    _activePartnerId = null;
    if (ch != null && _db != null) {
      try {
        await _db.removeChannel(ch);
      } catch (_) {}
    }
  }

  @visibleForTesting
  void seedForTest({
    required String familyId,
    required String myId,
    List<DirectMessageRow> messages = const [],
    Iterable<String> onlineUserIds = const [],
  }) {
    _familyId = familyId;
    _myId = myId;
    _initialLoadDone = true;
    _wsConnected = true;
    _debugOnlineUsers
      ..clear()
      ..addAll(onlineUserIds);
    _messages
      ..clear()
      ..addAll(messages);
    for (final m in messages) {
      _notifiedIds.add(m.id);
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  @visibleForTesting
  void debugSetOnlineUsers(Iterable<String> userIds) {
    _debugOnlineUsers
      ..clear()
      ..addAll(userIds);
    notifyListeners();
  }

  @visibleForTesting
  void debugSetPartnerTyping(String userId, bool isTyping) {
    if (isTyping) {
      _typingUsers.add(userId);
    } else {
      _typingUsers.remove(userId);
    }
    notifyListeners();
  }

  @visibleForTesting
  void injectMessageForTest(DirectMessageRow row) {
    _upsertMessage(row);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    if (_db != null) {
      WidgetsBinding.instance.removeObserver(this);
    }
    final ch = _channel;
    if (ch != null && _db != null) {
      _db.removeChannel(ch);
    }
    _incomingAlertController.close();
    super.dispose();
  }
}
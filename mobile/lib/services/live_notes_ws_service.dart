import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance_models.dart';
import 'supabase_service.dart';

class LiveNotesWsService {
  RealtimeChannel? _channel;
  String _activeRoomCode = '';
  String _currentUserName = '';
  bool _isConnected = false;

  final List<String> _onlinePeers = [];
  final Map<String, String> _activeEditorsByNote = {};
  final Map<String, Timer> _typingExpiryTimers = {};

  final void Function(SharedNote note, String sender)? onRemoteNoteUpdated;
  final void Function(String noteId, String sender)? onRemoteNoteDeleted;
  final void Function(List<SharedNote> notes, String sender)? onRemoteFullSync;
  final List<SharedNote> Function()? getLocalNotes;
  final void Function()? onStateChanged;

  LiveNotesWsService({
    this.onRemoteNoteUpdated,
    this.onRemoteNoteDeleted,
    this.onRemoteFullSync,
    this.getLocalNotes,
    this.onStateChanged,
  });

  bool get isConnected => _isConnected;
  String get activeRoomCode => _activeRoomCode;
  List<String> get onlinePeers => List.unmodifiable(_onlinePeers);
  Map<String, String> get activeEditorsByNote => Map.unmodifiable(_activeEditorsByNote);

  String? activeEditorForNote(String noteId) => _activeEditorsByNote[noteId];

  Future<void> connect({
    required String familyCode,
    required String userName,
  }) async {
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanUser = userName.trim().isNotEmpty ? userName.trim() : 'Member';

    if (!SupabaseService.isConfigured || cleanCode.isEmpty || cleanCode == '--------') {
      return;
    }

    if (_channel != null && _activeRoomCode == cleanCode && _isConnected) {
      _currentUserName = cleanUser;
      return;
    }

    await disconnect();

    _activeRoomCode = cleanCode;
    _currentUserName = cleanUser;

    final channelName = 'family_notes_$cleanCode';
    final channel = SupabaseService.client.channel(
      channelName,
      opts: const RealtimeChannelConfig(self: false),
    );

    channel
        .onBroadcast(
          event: 'note_live_edit',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? 'Family Member';
            if (sender == _currentUserName) return;
            final noteMap = payload['note'];
            if (noteMap is Map) {
              final incoming = SharedNote.fromJson(Map<String, dynamic>.from(noteMap));
              _markPeerOnline(sender);
              _setNoteTyping(incoming.id, sender);
              onRemoteNoteUpdated?.call(incoming, sender);
            }
          },
        )
        .onBroadcast(
          event: 'note_typing',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? 'Family Member';
            final noteId = payload['noteId']?.toString() ?? '';
            if (sender == _currentUserName || noteId.isEmpty) return;
            _markPeerOnline(sender);
            _setNoteTyping(noteId, sender);
          },
        )
        .onBroadcast(
          event: 'note_delete',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? 'Family Member';
            final noteId = payload['noteId']?.toString() ?? '';
            if (sender == _currentUserName || noteId.isEmpty) return;
            _markPeerOnline(sender);
            onRemoteNoteDeleted?.call(noteId, sender);
          },
        )
        .onBroadcast(
          event: 'notes_request_sync',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? '';
            if (sender == _currentUserName) return;
            if (sender.isNotEmpty) _markPeerOnline(sender);
            final currentNotes = getLocalNotes?.call() ?? [];
            if (currentNotes.isNotEmpty) {
              broadcastFullSync(currentNotes);
            } else {
              _broadcastHello();
            }
          },
        )
        .onBroadcast(
          event: 'notes_full_sync',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? 'Family Member';
            if (sender == _currentUserName) return;
            _markPeerOnline(sender);
            final listRaw = payload['notes'];
            if (listRaw is List) {
              final incoming = listRaw
                  .whereType<Map>()
                  .map((m) => SharedNote.fromJson(Map<String, dynamic>.from(m)))
                  .toList();
              if (incoming.isNotEmpty) {
                onRemoteFullSync?.call(incoming, sender);
              }
            }
          },
        )
        .onBroadcast(
          event: 'peer_hello',
          callback: (Map<String, dynamic> payload) {
            final sender = payload['sender']?.toString() ?? '';
            if (sender.isNotEmpty && sender != _currentUserName) {
              _markPeerOnline(sender);
            }
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          _isConnected = status == RealtimeSubscribeStatus.subscribed;
          onStateChanged?.call();
          if (_isConnected) {
            requestRoomSync();
          }
        });

    _channel = channel;
  }

  void _markPeerOnline(String peerName) {
    if (peerName.isEmpty || peerName == _currentUserName) return;
    if (!_onlinePeers.contains(peerName)) {
      _onlinePeers.add(peerName);
      onStateChanged?.call();
    }
  }

  void _setNoteTyping(String noteId, String peerName) {
    _activeEditorsByNote[noteId] = peerName;
    _typingExpiryTimers[noteId]?.cancel();
    onStateChanged?.call();
    _typingExpiryTimers[noteId] = Timer(const Duration(seconds: 3), () {
      _activeEditorsByNote.remove(noteId);
      onStateChanged?.call();
    });
  }

  Future<void> _broadcastHello() async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'peer_hello',
        payload: {
          'sender': _currentUserName,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> requestRoomSync() async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'notes_request_sync',
        payload: {
          'sender': _currentUserName,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> broadcastNoteEdit(SharedNote note) async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'note_live_edit',
        payload: {
          'sender': _currentUserName,
          'note': note.toJson(),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> broadcastTyping(String noteId) async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'note_typing',
        payload: {
          'sender': _currentUserName,
          'noteId': noteId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> broadcastNoteDelete(String noteId) async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'note_delete',
        payload: {
          'sender': _currentUserName,
          'noteId': noteId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> broadcastFullSync(List<SharedNote> notes) async {
    final ch = _channel;
    if (ch == null || !_isConnected) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'notes_full_sync',
        payload: {
          'sender': _currentUserName,
          'notes': notes.map((n) => n.toJson()).toList(),
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {}
  }

  Future<void> disconnect() async {
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
    _activeEditorsByNote.clear();
    _onlinePeers.clear();
    _isConnected = false;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await SupabaseService.client.removeChannel(ch);
      } catch (_) {}
    }
    onStateChanged?.call();
  }
}

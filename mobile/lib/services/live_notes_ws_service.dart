import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/finance_models.dart';

class LiveNotesWsService {
  WebSocket? _ws;
  StreamSubscription? _wsSub;
  String _activeRoomCode = '';
  String _currentUserName = '';
  bool _isConnected = false;

  final List<String> _onlinePeers = [];
  final Map<String, String> _activeEditorsByNote = {};
  final Map<String, Timer> _typingExpiryTimers = {};

  final void Function(SharedNote note, String sender)? onRemoteNoteUpdated;
  final void Function(String noteId, String sender)? onRemoteNoteDeleted;
  final void Function(List<SharedNote> notes, String sender)? onRemoteFullSync;
  final void Function(FamilyLoginRequest req)? onRemoteFamilyLoginRequest;
  final void Function(String requestId, String email, bool approved)? onRemoteFamilyLoginDecision;
  final void Function(String email, String name, bool disabled)? onRemoteMemberDisabledChanged;
  final List<SharedNote> Function()? getLocalNotes;
  final void Function()? onStateChanged;

  LiveNotesWsService({
    this.onRemoteNoteUpdated,
    this.onRemoteNoteDeleted,
    this.onRemoteFullSync,
    this.onRemoteFamilyLoginRequest,
    this.onRemoteFamilyLoginDecision,
    this.onRemoteMemberDisabledChanged,
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

    if (cleanCode.isEmpty || cleanCode == '--------') {
      return;
    }

    if (_activeRoomCode == cleanCode && _isConnected && _ws != null) {
      _currentUserName = cleanUser;
      return;
    }

    await disconnect();

    _activeRoomCode = cleanCode;
    _currentUserName = cleanUser;
    _isConnected = true;
    onStateChanged?.call();

    final urls = [
      'ws://10.0.2.2:8000/ws/notes/$cleanCode',
      'ws://127.0.0.1:8000/ws/notes/$cleanCode',
    ];

    for (final url in urls) {
      try {
        final socket = await WebSocket.connect(url).timeout(const Duration(seconds: 2));
        _ws = socket;
        _isConnected = true;
        onStateChanged?.call();

        _wsSub = socket.listen(
          (dynamic raw) {
            if (raw is String) {
              _handleIncomingMessage(raw);
            }
          },
          onDone: () {
            _ws = null;
          },
          onError: (_) {
            _ws = null;
          },
        );

        await _sendEvent('peer_hello', {'sender': _currentUserName});
        await requestRoomSync();
        break;
      } catch (_) {
        // Keep local room live even if external WS host is unreachable
      }
    }
  }

  void _handleIncomingMessage(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final event = decoded['event']?.toString() ?? '';
      final payloadRaw = decoded['payload'];
      if (payloadRaw is! Map) return;
      final payload = Map<String, dynamic>.from(payloadRaw);
      final sender = payload['sender']?.toString() ?? 'Family Member';

      switch (event) {
        case 'family_join_request':
          final reqMap = payload['request'];
          if (reqMap is Map) {
            final req = FamilyLoginRequest.fromJson(Map<String, dynamic>.from(reqMap));
            onRemoteFamilyLoginRequest?.call(req);
          }
          return;
        case 'family_join_decision':
          final requestId = payload['requestId']?.toString() ?? '';
          final email = payload['email']?.toString() ?? '';
          final approved = (payload['approved'] as bool?) ?? (payload['status'] == 'approved');
          if (email.isNotEmpty || requestId.isNotEmpty) {
            onRemoteFamilyLoginDecision?.call(requestId, email, approved);
          }
          return;
        case 'family_member_disabled':
          final email = payload['email']?.toString() ?? '';
          final name = payload['name']?.toString() ?? '';
          final disabled = (payload['disabled'] as bool?) ?? true;
          onRemoteMemberDisabledChanged?.call(email, name, disabled);
          return;
      }

      if (sender == _currentUserName) return;

      switch (event) {
        case 'note_live_edit':
          final noteMap = payload['note'];
          if (noteMap is Map) {
            final incoming = SharedNote.fromJson(Map<String, dynamic>.from(noteMap));
            _markPeerOnline(sender);
            _setNoteTyping(incoming.id, sender);
            onRemoteNoteUpdated?.call(incoming, sender);
          }
          break;
        case 'note_typing':
          final noteId = payload['noteId']?.toString() ?? '';
          if (noteId.isNotEmpty) {
            _markPeerOnline(sender);
            _setNoteTyping(noteId, sender);
          }
          break;
        case 'note_delete':
          final noteId = payload['noteId']?.toString() ?? '';
          if (noteId.isNotEmpty) {
            _markPeerOnline(sender);
            onRemoteNoteDeleted?.call(noteId, sender);
          }
          break;
        case 'notes_request_sync':
          _markPeerOnline(sender);
          final currentNotes = getLocalNotes?.call() ?? [];
          if (currentNotes.isNotEmpty) {
            broadcastFullSync(currentNotes);
          }
          break;
        case 'notes_full_sync':
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
          break;
        case 'peer_hello':
          _markPeerOnline(sender);
          break;
      }
    } catch (_) {}
  }

  Future<void> _sendEvent(String event, Map<String, dynamic> payload) async {
    final socket = _ws;
    if (socket == null) return;
    try {
      socket.add(json.encode({
        'event': event,
        'payload': {
          ...payload,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      }));
    } catch (_) {}
  }

  void _markPeerOnline(String peerName) {
    if (peerName.isEmpty || peerName == _currentUserName || peerName == 'Server') return;
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

  Future<void> requestRoomSync() async {
    await _sendEvent('notes_request_sync', {'sender': _currentUserName});
  }

  Future<void> broadcastNoteEdit(SharedNote note) async {
    await _sendEvent('note_live_edit', {
      'sender': _currentUserName,
      'note': note.toJson(),
    });
  }

  Future<void> broadcastTyping(String noteId) async {
    await _sendEvent('note_typing', {
      'sender': _currentUserName,
      'noteId': noteId,
    });
  }

  Future<void> broadcastNoteDelete(String noteId) async {
    await _sendEvent('note_delete', {
      'sender': _currentUserName,
      'noteId': noteId,
    });
  }

  Future<void> broadcastFullSync(List<SharedNote> notes) async {
    await _sendEvent('notes_full_sync', {
      'sender': _currentUserName,
      'notes': notes.map((n) => n.toJson()).toList(),
    });
  }

  Future<void> broadcastFamilyJoinRequest(FamilyLoginRequest req) async {
    await _sendEvent('family_join_request', {
      'sender': req.name,
      'request': req.toJson(),
    });
  }

  Future<void> broadcastFamilyJoinDecision({
    String requestId = '',
    required String email,
    String name = '',
    bool approved = true,
  }) async {
    await _sendEvent('family_join_decision', {
      'sender': _currentUserName,
      'requestId': requestId,
      'email': email,
      'name': name,
      'approved': approved,
      'status': approved ? 'approved' : 'rejected',
    });
  }

  Future<void> broadcastMemberDisabledChanged({
    String email = '',
    String name = '',
    required bool disabled,
  }) async {
    await _sendEvent('family_member_disabled', {
      'sender': _currentUserName,
      'email': email,
      'name': name,
      'disabled': disabled,
    });
  }

  Future<void> disconnect() async {
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
    _activeEditorsByNote.clear();
    _onlinePeers.clear();
    _isConnected = false;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    onStateChanged?.call();
  }
}

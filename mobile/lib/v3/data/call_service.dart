import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/app_log.dart';
import 'call_logic.dart';
import 'chat_controller.dart';
import 'chat_platform_io.dart'
    if (dart.library.js_interop) 'chat_platform_web.dart';
import 'notifications_core.dart';
import 'push_service.dart';
import 'v3_models.dart';

/// Rings family members and runs the one active call.
///
/// Ringing: the caller inserts a `calls` row; the callee's open app sees the
/// insert over Realtime (postgres_changes) and shows the incoming screen.
/// Signaling: both sides join the broadcast channel `call:<id>`. The callee
/// says `ready` once it has answered and opened its mic, the caller then
/// sends the `offer`, the callee the `answer`, and both trickle `ice`
/// candidates. `bye` ends it from either side. Media is peer to peer.
class CallService extends ChangeNotifier {
  final SupabaseClient _db;
  final ChatController _chat;

  CallService(this._db, this._chat);

  String? _familyId;
  String? _myId;
  RealtimeChannel? _ringChannel;
  CallSession? _current;

  /// Pushes the call screen; set by the app shell.
  void Function(CallSession session)? present;

  CallSession? get current => _current;
  String? _lastIceError;

  /// Listens for calls ringing this member. Safe to call on every build.
  void bind({required String familyId, required String? myId}) {
    if (myId == null || myId.isEmpty || familyId.isEmpty) return;
    if (_familyId == familyId && _myId == myId && _ringChannel != null) return;
    final old = _ringChannel;
    if (old != null) unawaited(_db.removeChannel(old));
    _familyId = familyId;
    _myId = myId;
    _ringChannel = _db
        .channel('calls:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee',
            value: myId,
          ),
          callback: (p) {
            trace(p.newRecord['id'].toString(), 'ring_realtime');
            _onRing(p.newRecord);
          },
        )
        // Status changes made outside the call channel (Decline on the
        // notification, answered on another phone) end the call here too.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee',
            value: myId,
          ),
          callback: (p) => _onUpdate(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'caller',
            value: myId,
          ),
          callback: (p) => _onUpdate(p.newRecord),
        )
        .subscribe();
    final pending = _pendingOpen;
    _pendingOpen = null;
    if (pending != null) unawaited(openFromPush(pending.$1, answer: pending.$2));
  }

  (String, bool)? _pendingOpen;

  /// A ringing call reached this phone by push (notification tap, Answer,
  /// full-screen launch, or FCM while open). Rings in-app unless it already
  /// is; [answer] picks it up straight away.
  Future<void> openFromPush(String callId, {bool answer = false}) async {
    final me = _myId;
    if (me == null) {
      _pendingOpen = (callId, answer);
      return;
    }
    if (_current?.id != callId) {
      try {
        final row = await _db.from('calls').select().eq('id', callId).maybeSingle();
        if (row == null || row['callee'] != me) return;
        trace(callId, 'push_open', 'answer=$answer status=${row['status']}');
        if (row['status'] != 'ringing') {
          unawaited(AppNotifications.cancelCall(callId));
          return;
        }
        _onRing(row);
      } catch (e) {
        AppLog.error('CallService.openFromPush', e);
        return;
      }
    }
    final s = _current;
    if (answer && s != null && s.id == callId) unawaited(s.accept());
  }

  void _onUpdate(Map<String, dynamic> row) {
    final s = _current;
    if (s == null || row['id']?.toString() != s.id) return;
    final status = row['status'];
    if (status == 'declined') {
      unawaited(s._end(CallEvent.declined, send: false, store: false));
    } else if (status == 'accepted' && !s.isCaller && s.phase == CallPhase.incoming) {
      s.endReason = 'Answered on another device';
      unawaited(s._end(CallEvent.hangup, send: false, store: false));
    } else if (status == 'missed' || status == 'ended') {
      unawaited(s._end(CallEvent.hangup, send: false, store: false));
    }
  }

  void _onRing(Map<String, dynamic> row) {
    if (row['status'] != 'ringing' || row['family_id'] != _familyId) return;
    final id = row['id'].toString();
    if (_current?.id == id) return; // already ringing (Realtime and push both)
    final kind = row['kind'] == 'video' ? CallKind.video : CallKind.audio;
    final caller = row['caller'].toString();
    if (_current != null) {
      // Already on a call: turn this one away.
      unawaited(_setStatus(id, 'declined'));
      return;
    }
    final s = CallSession._(
      service: this,
      id: id,
      kind: kind,
      peerId: caller,
      peerName: _chat.memberNameOf(caller),
      isCaller: false,
    );
    _current = s;
    notifyListeners();
    unawaited(s._joinSignaling());
    present?.call(s);
  }

  /// Calls [partner]. Returns null when a call is already running.
  Future<CallSession?> start(MemberRow partner, CallKind kind) async {
    final fid = _familyId, me = _myId;
    if (_current != null || fid == null || me == null) return null;
    final s = CallSession._(
      service: this,
      id: const Uuid().v4(),
      kind: kind,
      peerId: partner.userId,
      peerName: partner.name,
      isCaller: true,
    );
    _current = s;
    notifyListeners();
    present?.call(s);
    unawaited(s._dial(fid, me));
    return s;
  }

  void _finished(CallSession s) {
    if (_current == s) {
      _current = null;
      notifyListeners();
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await _db.from('calls').update({
        'status': status,
        if (status != 'accepted')
          'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      AppLog.error('CallService.setStatus', e);
    }
  }

  /// One step of a call into `call_debug`, read server-side to diagnose a
  /// call that failed on someone's phone. Never throws, never waits.
  void trace(String callId, String event, [String? detail]) {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    unawaited(_db.from('call_debug').insert({
      'call_id': callId,
      'user_id': uid,
      'event': event,
      'detail': ?(detail == null
          ? null
          : detail.length > 500 ? detail.substring(0, 500) : detail),
    }).then((_) {}, onError: (_) {}));
  }

  /// Google STUN plus the TURN relay from the turn-credentials function, if
  /// it is deployed and configured. Never blocks a call for long.
  Future<List<Map<String, dynamic>>> _iceServers() async {
    try {
      final res = await _db.functions
          .invoke('turn-credentials')
          .timeout(const Duration(seconds: 4));
      final data = res.data;
      return iceServers(data is Map ? data['turn'] : null);
    } catch (e) {
      _lastIceError = e.toString();
      return iceServers(null);
    }
  }

  @override
  void dispose() {
    final ch = _ringChannel;
    if (ch != null) unawaited(_db.removeChannel(ch));
    unawaited(_current?.hangUp());
    super.dispose();
  }
}

/// One call, from ringing to hang-up. The call screen listens to it.
class CallSession extends ChangeNotifier {
  final CallService service;
  final String id;
  final CallKind kind;
  final String peerId;
  final String peerName;
  final bool isCaller;

  CallSession._({
    required this.service,
    required this.id,
    required this.kind,
    required this.peerId,
    required this.peerName,
    required this.isCaller,
  }) : phase = isCaller ? CallPhase.ringing : CallPhase.incoming;

  CallPhase phase;
  DateTime? connectedAt;
  String? endReason;
  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = false;
  bool noiseCancellation = true;
  bool reconnecting = false;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool get isVideo => kind == CallKind.video;

  RealtimeChannel? _ch;
  final _subscribed = Completer<void>();
  RTCPeerConnection? _pc;
  MediaStream? _stream; // the stream both local tracks are sent under
  MediaStreamTrack? _mic;
  MediaStreamTrack? _cam;
  RTCRtpSender? _micSender;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteSet = false;
  Timer? _timeout;
  Timer? _ringBuzz;
  bool _closing = false;

  void _t(String event, [String? detail]) => service.trace(id, event, detail);
  final _candTypes = <String>{};
  int _iceIn = 0;

  // ---- signaling ---------------------------------------------------------

  Future<void> _joinSignaling() async {
    final ch = service._db.channel(
      'call:$id',
      opts: const RealtimeChannelConfig(self: false, ack: true),
    );
    _ch = ch;
    ch.onBroadcast(event: 'sig', callback: _onSignal).subscribe((status, err) {
      _t('channel', '${status.name} ${err ?? ''}');
      if (status == RealtimeSubscribeStatus.subscribed &&
          !_subscribed.isCompleted) {
        _subscribed.complete();
      }
    });
    if (!isCaller) {
      _timeout = Timer(ringTimeout, () => _end(CallEvent.timeout, send: false));
      _buzz();
    }
  }

  Future<void> _send(String type, [Map<String, dynamic>? data]) async {
    try {
      await _ch?.sendBroadcastMessage(
        event: 'sig',
        // Not 'type': the realtime client overwrites payload['type'] with
        // 'broadcast' (and 'event' with the event name) on every send.
        payload: {'sig': type, ...?data},
      );
    } catch (e) {
      AppLog.error('CallSession.send', e);
    }
  }

  Future<void> _onSignal(Map<String, dynamic> m) async {
    if (m['sig'] == 'ice') {
      if (++_iceIn == 1) _t('rx_ice_first');
    } else {
      _t('rx_${m['sig']}', 'pc=${_pc != null}');
    }
    try {
      switch (m['sig']) {
        case 'ready': // callee answered: caller makes the offer
          if (!isCaller || _pc == null) return;
          _stopRingPush(); // the callee's other phones stop ringing
          _advance(CallEvent.accepted);
          _timeout?.cancel();
          _timeout = Timer(connectTimeout, () => _end(CallEvent.timeout));
          final offer = await _pc!.createOffer();
          await _pc!.setLocalDescription(offer);
          await _send('offer', {'sdp': offer.sdp, 'sdp_type': offer.type});
          _t('tx_offer');
        case 'offer':
          if (isCaller || _pc == null) return;
          await _pc!.setRemoteDescription(
            RTCSessionDescription(m['sdp'] as String?, m['sdp_type'] as String?),
          );
          await _flushIce();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await _send('answer', {'sdp': answer.sdp, 'sdp_type': answer.type});
          _t('tx_answer');
        case 'answer':
          if (!isCaller || _pc == null) return;
          await _pc!.setRemoteDescription(
            RTCSessionDescription(m['sdp'] as String?, m['sdp_type'] as String?),
          );
          await _flushIce();
        case 'ice':
          final c = RTCIceCandidate(
            m['candidate'] as String?,
            m['sdp_mid'] as String?,
            (m['sdp_mline_index'] as num?)?.toInt(),
          );
          if (_remoteSet && _pc != null) {
            await _pc!.addCandidate(c);
          } else {
            _pendingIce.add(c);
          }
        case 'bye':
          await _end(
            m['reason'] == 'declined' ? CallEvent.declined : CallEvent.hangup,
            send: false,
          );
      }
    } catch (e) {
      _t('signal_error', '${m['sig']}: $e');
      AppLog.error('CallSession.onSignal', e);
    }
  }

  Future<void> _flushIce() async {
    _remoteSet = true;
    for (final c in _pendingIce) {
      await _pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  // ---- caller / callee ---------------------------------------------------

  Future<void> _dial(String familyId, String myId) async {
    try {
      await _joinSignaling();
      await _openMedia();
      if (_closing) return;
      await _subscribed.future.timeout(const Duration(seconds: 10));
      await service._db.from('calls').insert({
        'id': id,
        'family_id': familyId,
        'caller': myId,
        'callee': peerId,
        'kind': kind.name,
      });
      _t('dial_inserted', kind.name);
      // Rings the callee's phone even when their app is closed.
      PushService.send(service._db, {'type': 'call', 'call_id': id});
      _ringPushed = true;
      _timeout = Timer(ringTimeout, () => _end(CallEvent.timeout));
    } catch (e) {
      _t('dial_error', e.toString());
      AppLog.error('CallSession.dial', e);
      endReason = _mediaError(e) ?? 'Could not place the call';
      await _end(CallEvent.failed);
    }
  }

  /// Callee: answer.
  Future<void> accept() async {
    if (phase != CallPhase.incoming) return;
    _t('accept');
    unawaited(AppNotifications.cancelCall(id));
    _ringBuzz?.cancel();
    _timeout?.cancel();
    _advance(CallEvent.accepted);
    try {
      await _openMedia();
      if (_closing) return;
      await service._setStatus(id, 'accepted');
      await _subscribed.future.timeout(const Duration(seconds: 10));
      await _send('ready');
      _t('tx_ready');
      _timeout = Timer(connectTimeout, () => _end(CallEvent.timeout));
    } catch (e) {
      _t('accept_error', e.toString());
      AppLog.error('CallSession.accept', e);
      endReason = _mediaError(e) ?? 'Could not answer';
      await _end(CallEvent.failed);
    }
  }

  /// Callee: refuse.
  Future<void> decline() => _end(CallEvent.declined);

  /// Either side: end, or cancel while ringing.
  Future<void> hangUp() => _end(CallEvent.hangup);

  // ---- media ---------------------------------------------------------------

  Future<MediaStreamTrack> _openMic() async {
    final s = await navigator.mediaDevices.getUserMedia({
      'audio': audioConstraints(noiseSuppression: noiseCancellation, web: kIsWeb),
      'video': false,
    });
    return s.getAudioTracks().first;
  }

  Future<void> _openMedia() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    // Mic first, then camera: Android asks for each at call time.
    final audio = await navigator.mediaDevices.getUserMedia({
      'audio': audioConstraints(noiseSuppression: noiseCancellation, web: kIsWeb),
      'video': false,
    });
    _stream = audio;
    _mic = audio.getAudioTracks().first;
    if (isVideo) {
      final video = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {'facingMode': 'user', 'width': 1280, 'height': 720},
      });
      _cam = video.getVideoTracks().first;
      localRenderer.srcObject = video;
    }
    if (_closing) return;
    speakerOn = isVideo;
    await _route();

    final servers = await service._iceServers();
    _t('ice_servers',
        '${servers.length} turn=${servers.any((x) => x.containsKey('username'))} ${service._lastIceError ?? ''}');
    final pc = await createPeerConnection({
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      final typ = RegExp(r' typ (\w+)').firstMatch(c.candidate!)?.group(1) ?? '?';
      if (_candTypes.add(typ)) _t('local_cand', typ);
      unawaited(_send('ice', {
        'candidate': c.candidate,
        'sdp_mid': c.sdpMid,
        'sdp_mline_index': c.sdpMLineIndex,
      }));
    };
    pc.onIceConnectionState = (st) => _t('ice_state', st.name);
    pc.onTrack = (e) {
      _t('track', '${e.track.kind} streams=${e.streams.length}');
      if (e.streams.isNotEmpty) {
        remoteRenderer.srcObject = e.streams.first;
        notifyListeners();
      }
    };
    pc.onConnectionState = (s) {
      _t('pc_state', s.name);
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _timeout?.cancel();
          reconnecting = false;
          if (phase == CallPhase.connecting) {
            connectedAt = DateTime.now();
            _advance(CallEvent.connected);
          } else {
            notifyListeners();
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          reconnecting = true;
          notifyListeners();
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          endReason = 'Connection lost';
          unawaited(_end(CallEvent.failed));
        default:
          break;
      }
    };
    // Both tracks go under one stream so the far side gets one stream that
    // plays the audio and shows the video.
    _micSender = await pc.addTrack(_mic!, audio);
    if (_cam != null) await pc.addTrack(_cam!, audio);
    notifyListeners();
  }

  String? _mediaError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('permission') || s.contains('notallowed') || s.contains('denied')) {
      return isVideo
          ? 'Allow microphone and camera to call'
          : 'Allow the microphone to call';
    }
    return null;
  }

  Future<void> _route() async {
    if (kIsWeb) return; // browsers pick the output device themselves
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
  }

  void toggleMute() {
    muted = !muted;
    _mic?.enabled = !muted;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    notifyListeners();
    await _route();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    _cam?.enabled = !cameraOff;
    notifyListeners();
  }

  Future<void> setZoom(double level) async {
    final cam = _cam;
    if (cam == null || kIsWeb) return;
    try {
      await Helper.setZoom(cam, level);
    } catch (_) {} // camera without zoom
  }

  Future<void> switchCamera() async {
    final cam = _cam;
    if (cam != null) await Helper.switchCamera(cam);
  }

  /// Re-opens the mic with noise suppression on or off (echo cancellation
  /// stays on) and swaps it into the call without renegotiating.
  Future<void> toggleNoiseCancellation() async {
    noiseCancellation = !noiseCancellation;
    notifyListeners();
    final old = _mic;
    if (old == null) return;
    try {
      final fresh = await _openMic();
      fresh.enabled = !muted;
      await _micSender?.replaceTrack(fresh);
      _mic = fresh;
      await old.stop();
    } catch (e) {
      AppLog.error('CallSession.noiseCancellation', e);
      noiseCancellation = !noiseCancellation;
      notifyListeners();
    }
  }

  // ---- ending --------------------------------------------------------------

  void _advance(CallEvent e) {
    phase = nextPhase(phase, e);
    notifyListeners();
  }

  /// Seconds talked so far; zero until media connects.
  Duration get talked => connectedAt == null
      ? Duration.zero
      : DateTime.now().difference(connectedAt!);

  bool _ringPushed = false;

  /// Caller: the call left ringing, so clear the callee's ring notification.
  void _stopRingPush() {
    if (!_ringPushed) return;
    _ringPushed = false;
    PushService.send(service._db, {'type': 'call_cancel', 'call_id': id});
  }

  /// Incoming ring: buzz plus one notification, so a minimised app that is
  /// still connected also alerts. In the background that is the same
  /// full-screen ring the push posts (same id), so the two never double up.
  void _buzz() {
    var first = true;
    final background =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (background) {
      unawaited(AppNotifications.showIncomingCall(
          callId: id, callerName: peerName, video: isVideo));
    }
    void ring() => unawaited(notifyIncomingChat(
          messageId: 'call_$id',
          senderId: peerId,
          senderName: peerName,
          body: isVideo ? 'Incoming video call' : 'Incoming voice call',
          isPoke: true,
          showSystemNotification: first && !background,
        ).whenComplete(() => first = false));
    ring();
    _ringBuzz = Timer.periodic(const Duration(seconds: 3), (_) => ring());
  }

  /// [store] false: the row already holds the outcome (changed elsewhere).
  Future<void> _end(CallEvent reason, {bool send = true, bool store = true}) async {
    if (_closing) return;
    _closing = true;
    final wasConnected = connectedAt != null;
    final talkedFor = talked;
    _timeout?.cancel();
    _ringBuzz?.cancel();
    if (isCaller) {
      _stopRingPush();
    } else {
      unawaited(AppNotifications.cancelCall(id));
    }
    _t('end', '${reason.name} phase=${phase.name}');
    endReason ??= switch (reason) {
      CallEvent.declined => isCaller ? '$peerName declined' : 'Declined',
      CallEvent.timeout => wasConnected || phase == CallPhase.connecting
          ? "Couldn't connect. The network may be blocking calls."
          : 'No answer',
      _ => 'Call ended',
    };
    _advance(reason);

    if (send) {
      await _send('bye', {if (reason == CallEvent.declined) 'reason': 'declined'});
    }
    final status = finalStatus(wasConnected: wasConnected, reason: reason);
    if (store) await service._setStatus(id, status);
    // The caller leaves the chat entry, so it is written once.
    if (isCaller) {
      unawaited(service._chat.sendMessage(
        recipientId: peerId,
        body: callLogLabel(kind, status, talkedFor),
        kind: 'call',
      ));
    }

    try {
      await _mic?.stop();
      await _cam?.stop();
      await _stream?.dispose();
      final local = localRenderer.srcObject;
      localRenderer.srcObject = null;
      await local?.dispose();
      remoteRenderer.srcObject = null;
      await _pc?.close();
      if (!kIsWeb) await Helper.setSpeakerphoneOn(false);
      // Hand audio routing back so media volume behaves normally again.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Helper.clearAndroidCommunicationDevice();
      }
    } catch (_) {}
    final ch = _ch;
    if (ch != null) unawaited(service._db.removeChannel(ch));
    service._finished(this);
  }

  /// Called by the call screen once it has closed.
  Future<void> release() async {
    try {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (_) {} // never initialised: declined before media opened
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../theme/nocturne.dart';
import '../../theme/nocturne_palette.dart';
import '../data/call_logic.dart';
import '../data/call_service.dart';
import '../phosphor_catalog.dart';

IconData _icon(String name) => phosphorCatalog[name]!;

/// Full-screen call: incoming (accept/decline), ringing, connecting and the
/// live voice or video call. Closes itself shortly after the call ends.
class CallScreenV3 extends StatefulWidget {
  final CallSession session;
  const CallScreenV3({super.key, required this.session});

  static Route<void> route(CallSession s) => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CallScreenV3(session: s),
      );

  @override
  State<CallScreenV3> createState() => _CallScreenV3State();
}

class _CallScreenV3State extends State<CallScreenV3> {
  Timer? _tick;
  bool _closing = false;

  CallSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (s.phase == CallPhase.connected && mounted) setState(() {});
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (s.phase == CallPhase.ended && !_closing) {
      _closing = true;
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    s.removeListener(_changed);
    // Leaving the screen (e.g. system back) never leaves a call running.
    unawaited(s.hangUp().whenComplete(s.release));
    super.dispose();
  }

  String get _status {
    if (s.phase == CallPhase.ended) return s.endReason ?? 'Call ended';
    if (s.reconnecting) return 'Reconnecting…';
    return switch (s.phase) {
      CallPhase.incoming =>
        s.isVideo ? 'Incoming video call' : 'Incoming voice call',
      CallPhase.ringing => 'Ringing…',
      CallPhase.connecting => 'Connecting…',
      CallPhase.connected => formatCallDuration(s.talked),
      CallPhase.ended => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final live = s.phase == CallPhase.connected;
    final showVideo = s.isVideo && s.phase != CallPhase.incoming;
    final hasLocal = s.localRenderer.srcObject != null && !s.cameraOff;
    final hasRemote = s.remoteRenderer.srcObject != null;
    return PopScope(
      // Back must not silently drop a ringing call; the buttons decide.
      canPop: s.phase == CallPhase.ended,
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(
          children: [
            if (showVideo && live && hasRemote)
              Positioned.fill(
                child: RTCVideoView(
                  s.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else if (showVideo && !live && hasLocal)
              // Before the other side connects, your own camera fills the
              // screen, as on a phone's own video call.
              Positioned.fill(
                child: RTCVideoView(
                  s.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            if (showVideo)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.bg.withValues(alpha: 0.55),
                        p.bg.withValues(alpha: 0),
                        p.bg.withValues(alpha: 0),
                        p.bg.withValues(alpha: 0.7),
                      ],
                      stops: const [0, 0.25, 0.7, 1],
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: showVideo ? 16 : 72),
                  if (!showVideo) ...[
                    _Avatar(name: s.peerName, ringing: !live),
                    const SizedBox(height: 22),
                  ],
                  Text(
                    s.peerName,
                    style: TextStyle(
                      fontSize: showVideo ? 20 : 26,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _status,
                    key: const ValueKey('call_status'),
                    style: TextStyle(
                      fontSize: 14,
                      color: s.phase == CallPhase.ended ? p.expense : p.subtle,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (s.phase == CallPhase.incoming)
                    _incomingButtons(p)
                  else
                    _controls(p),
                  const SizedBox(height: 28),
                ],
              ),
            ),
            if (showVideo && live)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 12,
                width: 108,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border.all(color: p.edge),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: !hasLocal
                        ? Icon(_icon('video-camera-slash'), color: p.muted)
                        : RTCVideoView(
                            s.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _incomingButtons(NocturnePalette p) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            key: const ValueKey('call_decline'),
            icon: _icon('phone-x'),
            label: 'Decline',
            background: p.expense,
            foreground: p.bg,
            big: true,
            onTap: s.decline,
          ),
          _RoundButton(
            key: const ValueKey('call_accept'),
            icon: _icon(s.isVideo ? 'video-camera' : 'phone'),
            label: 'Accept',
            background: p.income,
            foreground: p.bg,
            big: true,
            onTap: s.accept,
          ),
        ],
      );

  Widget _controls(NocturnePalette p) {
    final ended = s.phase == CallPhase.ended;
    Widget toggle(String key, String icon, String label, bool on,
            VoidCallback onTap) =>
        _RoundButton(
          key: ValueKey(key),
          icon: _icon(icon),
          label: label,
          background: on ? p.text : p.surface,
          foreground: on ? p.bg : p.text,
          onTap: ended ? null : onTap,
        );
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 16,
          children: [
            toggle('call_mute', s.muted ? 'microphone-slash' : 'microphone',
                s.muted ? 'Unmute' : 'Mute', s.muted, s.toggleMute),
            if (!kIsWeb)
              toggle('call_speaker', 'speaker-high', 'Speaker', s.speakerOn,
                  s.toggleSpeaker),
            toggle('call_noise', 'waveform', 'Noise cancel',
                s.noiseCancellation, s.toggleNoiseCancellation),
            if (s.isVideo) ...[
              toggle(
                  'call_camera',
                  s.cameraOff ? 'video-camera-slash' : 'video-camera',
                  s.cameraOff ? 'Camera on' : 'Camera off',
                  s.cameraOff,
                  s.toggleCamera),
              toggle('call_flip', 'camera-rotate', 'Flip', false,
                  s.switchCamera),
            ],
          ],
        ),
        const SizedBox(height: 26),
        _RoundButton(
          key: const ValueKey('call_end'),
          icon: _icon('phone-disconnect'),
          label: s.phase == CallPhase.ringing ? 'Cancel' : 'End',
          background: p.expense,
          foreground: p.bg,
          big: true,
          onTap: ended ? null : s.hangUp,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool ringing;
  const _Avatar({required this.name, required this.ringing});

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(color: ringing ? p.accent : p.edge, width: 2),
        boxShadow: [BoxShadow(color: p.glow, blurRadius: ringing ? 40 : 0)],
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w600,
          color: p.accentLight,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool big;
  final VoidCallback? onTap;

  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.big = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 70.0 : 58.0;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(color: Nocturne.palette.edge),
                ),
                child: Icon(icon, size: big ? 30 : 24, color: foreground),
              ),
            ),
          ),
          const SizedBox(height: 7),
          ExcludeSemantics(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: Nocturne.palette.subtle),
            ),
          ),
        ],
      ),
    );
  }
}

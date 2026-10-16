import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/nocturne.dart';
import '../data/call_logic.dart';
import '../data/call_service.dart';
import '../data/chat_controller.dart';
import '../data/chat_media.dart';
import '../data/chat_media_io.dart'
    if (dart.library.js_interop) '../data/chat_media_web.dart';
import '../data/v3_models.dart';
import '../data/v3_repository.dart';
import '../phosphor_catalog.dart';
import '../phosphor_icons.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import 'chat_list_v3.dart' show AvatarWithOnlineDot;

/// 1:1 Direct Message conversation screen between the signed-in user and
/// [partner], with live online dot, typing indicator, read receipts, poke,
/// photo/file/voice sharing, view-once photos, single-message delete, and
/// thread clear.
class ChatThreadV3 extends StatefulWidget {
  final MemberRow partner;
  final VoidCallback? onBack;

  const ChatThreadV3({
    super.key,
    required this.partner,
    this.onBack,
  });

  @override
  State<ChatThreadV3> createState() => _ChatThreadV3State();
}

class _ChatThreadV3State extends State<ChatThreadV3> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  ChatController? _chat;
  bool _sending = false;

  // Voice note recording; created on first use so tests never touch it.
  AudioRecorder? _recorder;
  DateTime? _recStart;
  Duration _recElapsed = Duration.zero;
  Timer? _recTimer;
  bool _recAac = true;
  bool get _recording => _recStart != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<V3State>();
      final chat = context.read<ChatController>();
      _chat = chat;
      chat.syncContext(
        familyId: s.familyId,
        myId: s.myId,
        members: s.members,
      );
      chat.openThread(widget.partner.userId);
      final nav = context.read<V3Nav?>();
      final prefill = nav?.consumePrefilledChatText();
      if (prefill != null && prefill.isNotEmpty) {
        _ctrl.text = prefill;
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatThreadV3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partner.userId != widget.partner.userId) {
      _chat?.openThread(widget.partner.userId);
    }
  }

  @override
  void dispose() {
    _chat?.closeThread();
    _recTimer?.cancel();
    _recorder?.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    final nav = context.read<V3Nav?>();
    if (nav != null && nav.chatPartnerId != null) {
      nav.closeChatThread();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final chat = context.read<ChatController>();
    setState(() => _sending = true);
    _ctrl.clear();
    final ok = await chat.sendMessage(
      recipientId: widget.partner.userId,
      body: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      _ctrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message')),
      );
    }
  }

  Future<void> _poke() async {
    final chat = context.read<ChatController>();
    final ok = await chat.pokeMember(widget.partner.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '👋 Poked ${widget.partner.name}!'
              : 'Could not send poke',
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showAttachMenu() async {
    if (_sending || _recording) return;
    final p = Nocturne.palette;
    var viewOnce = false;
    Widget tile(BuildContext ctx, String id, IconData icon, String label) =>
        ListTile(
          key: ValueKey('chat_attach_$id'),
          leading: Icon(icon, color: p.text),
          title: Text(
            label,
            style: TextStyle(
              color: p.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () => Navigator.of(ctx).pop(id),
        );
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(ctx, 'photo', PhRegular.image, 'Photo'),
                tile(ctx, 'camera', PhRegular.camera, 'Camera'),
                tile(ctx, 'file', PhRegular.file, 'File (PDF, docs, any)'),
                SwitchListTile(
                  key: const ValueKey('chat_attach_view_once'),
                  value: viewOnce,
                  onChanged: (v) => setSheet(() => viewOnce = v),
                  activeThumbColor: p.accentLight,
                  activeTrackColor: p.switchOn,
                  secondary: Icon(PhRegular.eye, color: p.text),
                  title: Text(
                    'View once',
                    style: TextStyle(color: p.text, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Photos only. Opens once, then it is deleted.',
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'file') {
      await _pickAndSendFile();
    } else {
      final hd = await _askPhotoQuality();
      if (!mounted || hd == null) return;
      await _pickAndSendImage(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        viewOnce: viewOnce,
        hd: hd,
      );
    }
  }

  /// true = HD, false = Standard, null = cancelled.
  Future<bool?> _askPhotoQuality() {
    final p = Nocturne.palette;
    Widget option(bool hd, String title, String sub) => ListTile(
          key: ValueKey(hd ? 'photo_quality_hd' : 'photo_quality_standard'),
          leading: Icon(hd ? PhRegular.sparkle : PhRegular.lightning,
              color: p.accent),
          title: Text(title, style: TextStyle(color: p.text, fontSize: 14)),
          subtitle: Text(sub, style: TextStyle(color: p.muted, fontSize: 12)),
          onTap: () => Navigator.pop(context, hd),
        );
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: p.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(false, 'Standard', 'Smaller and faster to send and open'),
            option(true, 'HD', 'Full detail, larger file'),
          ],
        ),
      ),
    );
  }

  Future<void> _call(CallKind kind) async {
    final calls = context.read<CallService?>();
    final started = await calls?.start(widget.partner, kind);
    if (started == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the current call first')),
      );
    }
  }

  Widget _headerButton({
    required Key key,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          key: key,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Nocturne.palette.edge, width: 1),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );

  Future<void> _pickAndSendImage(
    ImageSource source, {
    bool viewOnce = false,
    bool hd = false,
  }) async {
    try {
      // Standard is ~150-300 KB, HD ~1-2 MB.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: hd ? 2560 : 1280,
        maxHeight: hd ? 2560 : 1280,
        imageQuality: hd ? 90 : 70,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      await _sendMedia(
        bytes: bytes,
        name: file.name,
        mime: chatMimeFor(file.name, file.mimeType),
        kind: 'image',
        viewOnce: viewOnce,
      );
    } catch (_) {
      _snack('Could not attach photo');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final file = await pickChatFile();
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        _snack(
          'Files must be smaller than ${formatChatBytes(kChatMediaMaxBytes)}',
        );
        return;
      }
      const shown = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};
      await _sendMedia(
        bytes: bytes,
        name: file.name,
        mime: file.mime,
        kind: shown.contains(file.mime) ? 'image' : 'file',
      );
    } catch (_) {
      _snack('Could not attach file');
    }
  }

  /// Uploads and sends; any text in the field goes along as the caption.
  Future<void> _sendMedia({
    required Uint8List bytes,
    required String name,
    required String mime,
    required String kind,
    bool viewOnce = false,
    int? durationMs,
  }) async {
    if (!mounted) return;
    if (bytes.length > kChatMediaMaxBytes) {
      _snack(
        'Files must be smaller than ${formatChatBytes(kChatMediaMaxBytes)}',
      );
      return;
    }
    final caption = kind == 'voice' || viewOnce ? '' : _ctrl.text.trim();
    if (caption.isNotEmpty) _ctrl.clear();
    setState(() => _sending = true);
    final ok = await context.read<ChatController>().sendMedia(
          recipientId: widget.partner.userId,
          bytes: bytes,
          name: name,
          mime: mime,
          kind: kind,
          viewOnce: viewOnce,
          durationMs: durationMs,
          caption: caption,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      if (caption.isNotEmpty) _ctrl.text = caption;
      _snack('Could not send');
    }
  }

  Future<void> _startRecording() async {
    if (_sending || _recording) return;
    final rec = _recorder ??= AudioRecorder();
    try {
      if (!await rec.hasPermission()) {
        _snack('Allow microphone access to record a voice message');
        return;
      }
      // Browsers without AAC MediaRecorder support get Opus in WebM.
      _recAac = !kIsWeb || await rec.isEncoderSupported(AudioEncoder.aacLc);
      await rec.start(
        RecordConfig(
          encoder: _recAac ? AudioEncoder.aacLc : AudioEncoder.opus,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: await voiceRecordingPath(),
      );
      if (!mounted) return;
      final start = DateTime.now();
      setState(() {
        _recStart = start;
        _recElapsed = Duration.zero;
      });
      _recTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) {
          setState(() => _recElapsed = DateTime.now().difference(start));
        }
      });
    } catch (_) {
      _snack('Could not start recording');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    final rec = _recorder;
    final start = _recStart;
    _recTimer?.cancel();
    setState(() => _recStart = null);
    if (rec == null || start == null) return;
    try {
      if (!send) {
        await rec.cancel();
        return;
      }
      final out = await rec.stop();
      final length = DateTime.now().difference(start);
      if (out == null) return;
      final bytes = await readVoiceRecording(out);
      if (length < const Duration(seconds: 1) || bytes.isEmpty) {
        _snack('Too short. Record for at least a second.');
        return;
      }
      final ext = _recAac ? 'm4a' : 'webm';
      await _sendMedia(
        bytes: bytes,
        name: 'voice_${start.millisecondsSinceEpoch}.$ext',
        mime: _recAac ? 'audio/mp4' : 'audio/webm',
        kind: 'voice',
        durationMs: length.inMilliseconds,
      );
    } catch (_) {
      _snack('Could not send voice message');
    }
  }

  Future<void> _openStoredImage(DirectMessageRow msg) async {
    final repo = context.read<ChatController>().repo;
    final bytes = await V3Repository.guard(
      'downloadChatMedia',
      () => _storedImageBytes(repo, msg.mediaPath!),
    );
    if (!mounted) return;
    if (bytes == null) {
      _snack('Could not open photo');
      return;
    }
    _openImage(msg, bytes);
  }

  Future<void> _openViewOnce(DirectMessageRow msg) async {
    final bytes = await context.read<ChatController>().openViewOnce(msg);
    if (!mounted) return;
    if (bytes == null) {
      _snack('This photo is no longer available');
      return;
    }
    _openImage(msg, bytes, allowSave: false);
  }

  Future<void> _downloadMedia(DirectMessageRow msg) async {
    final repo = context.read<ChatController>().repo;
    final name = msg.mediaName ?? 'kinpurse_file';
    var ok = false;
    try {
      final url = await _signedChatUrl(repo, msg.mediaPath!);
      ok = await saveChatDownload(url, name, msg.mediaMime ?? chatMimeFor(name));
    } catch (_) {}
    _snack(ok ? 'Saved $name' : 'Could not download');
  }

  Future<void> _confirmClearThread() async {
    final chat = context.read<ChatController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text(
          'Clear conversation?',
          style: TextStyle(color: Nocturne.palette.text, fontSize: 16),
        ),
        content: Text(
          'This removes all messages between you and ${widget.partner.name} for both of you.',
          style: TextStyle(color: Nocturne.palette.neutral300, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Nocturne.palette.subtle),
            ),
          ),
          TextButton(
            key: const ValueKey('chat_confirm_clear_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear chat',
              style: TextStyle(color: Nocturne.palette.expense),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await chat.clearThread(widget.partner.userId);
    }
  }

  Future<void> _showMessageOptions(DirectMessageRow msg) async {
    final chat = context.read<ChatController>();
    final imgBytes = _chatImageBytes(msg);
    final canDownload = msg.hasMedia && !msg.viewOnce;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Nocturne.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imgBytes != null || canDownload)
                ListTile(
                  key: const ValueKey('chat_download_image_action'),
                  leading: Icon(
                    PhRegular.downloadSimple,
                    color: Nocturne.palette.text,
                  ),
                  title: Text(
                    switch (msg.mediaKind) {
                      'file' => 'Download file',
                      'voice' => 'Download voice message',
                      _ => 'Download photo',
                    },
                    style: TextStyle(
                      color: Nocturne.palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('download'),
                ),
              ListTile(
                key: const ValueKey('chat_delete_message_action'),
                leading: Icon(
                  PhRegular.trash,
                  color: Nocturne.palette.expense,
                ),
                title: Text(
                  'Delete message for everyone',
                  style: TextStyle(
                    color: Nocturne.palette.expense,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') await chat.deleteMessage(msg.id);
    if (action == 'download' && mounted) {
      if (canDownload) {
        await _downloadMedia(msg);
      } else if (imgBytes != null) {
        await _downloadChatImage(context, imgBytes, msg);
      }
    }
  }

  void _openImage(
    DirectMessageRow msg,
    Uint8List bytes, {
    bool allowSave = true,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ChatImageViewer(
          message: msg,
          bytes: bytes,
          allowSave: allowSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final chat = context.watch<ChatController>();
    final messages = chat.threadWith(widget.partner.userId);
    final isOnline = chat.isUserOnline(widget.partner.userId);
    final isTyping = chat.isPartnerTyping(widget.partner.userId);
    final roleLabel = widget.partner.relationship.isNotEmpty
        ? widget.partner.relationship
        : widget.partner.role;

    final String statusText;
    final Color statusColor;
    if (isTyping) {
      statusText = 'typing…';
      statusColor = Nocturne.palette.accentMuted;
    } else if (isOnline) {
      statusText = 'Online now · Live';
      statusColor = Nocturne.palette.income;
    } else {
      statusText =
          chat.isRealtimeConnected ? '$roleLabel · Live sync' : roleLabel;
      statusColor = Nocturne.palette.muted;
    }

    return Scaffold(
      backgroundColor: Nocturne.palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Thread header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
              decoration: BoxDecoration(
                color: Nocturne.palette.bg,
                border: Border(
                  bottom: BorderSide(color: Nocturne.palette.line, width: 1),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBack,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        PhRegular.arrowLeft,
                        size: 20,
                        color: Nocturne.palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AvatarWithOnlineDot(
                    imageUrl: widget.partner.avatarUrl,
                    initial: widget.partner.initial,
                    color: widget.partner.color,
                    size: 36,
                    fontSize: 13,
                    isOnline: isOnline,
                    dotKey: ValueKey(
                      'chat_header_online_dot_${widget.partner.userId}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.partner.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.palette.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.partner.about != null)
                          Text(
                            widget.partner.about!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Nocturne.palette.subtle,
                            ),
                          ),
                        const SizedBox(height: 1),
                        Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isOnline || isTyping
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (context.read<CallService?>() != null) ...[
                    _headerButton(
                      key: const ValueKey('chat_voice_call_button'),
                      icon: phosphorCatalog['phone']!,
                      color: Nocturne.palette.income,
                      tooltip: 'Voice call',
                      onTap: () => _call(CallKind.audio),
                    ),
                    const SizedBox(width: 6),
                    _headerButton(
                      key: const ValueKey('chat_video_call_button'),
                      icon: phosphorCatalog['video-camera']!,
                      color: Nocturne.palette.accentLight,
                      tooltip: 'Video call',
                      onTap: () => _call(CallKind.video),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    key: const ValueKey('chat_poke_button'),
                    onTap: _poke,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.palette.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Nocturne.palette.edge, width: 1),
                      ),
                      child: Icon(
                        PhRegular.bellRinging,
                        size: 17,
                        color: Nocturne.palette.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: const ValueKey('chat_clear_button'),
                    onTap: _confirmClearThread,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.palette.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Nocturne.palette.edge, width: 1),
                      ),
                      child: Icon(
                        PhRegular.trash,
                        size: 17,
                        color: Nocturne.palette.subtle,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Message list (reversed so newest stays anchored at bottom)
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarWithOnlineDot(
                              imageUrl: widget.partner.avatarUrl,
                              initial: widget.partner.initial,
                              color: widget.partner.color,
                              size: 52,
                              fontSize: 18,
                              isOnline: isOnline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Message ${widget.partner.name}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.palette.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Direct messages sync instantly over WebSockets and notify across web and phone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Nocturne.palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, revIdx) {
                        final idx = messages.length - 1 - revIdx;
                        final msg = messages[idx];
                        final isMine = msg.senderId == s.myId;
                        return _MessageBubble(
                          message: msg,
                          isMine: isMine,
                          onShowOptions: () => _showMessageOptions(msg),
                          onOpenImage: (bytes) => _openImage(msg, bytes),
                          onOpenMedia: () {
                            if (msg.viewOnce) {
                              if (!isMine && msg.viewedAt == null) {
                                _openViewOnce(msg);
                              }
                            } else if (msg.mediaKind == 'image') {
                              _openStoredImage(msg);
                            } else {
                              _downloadMedia(msg);
                            }
                          },
                        );
                      },
                    ),
            ),

            // Composer: three 48px controls, bottom-aligned so the buttons
            // stay level with the last line as the field grows.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: Nocturne.palette.surface,
                border: Border(
                  top: BorderSide(color: Nocturne.palette.edge, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _recording
                      ? _ComposerButton(
                          key: const ValueKey('chat_record_cancel'),
                          tooltip: 'Discard recording',
                          icon: PhRegular.trash,
                          onTap: () => _stopRecording(send: false),
                        )
                      : _ComposerButton(
                          key: const ValueKey('chat_attach_image_button'),
                          tooltip: 'Attach',
                          icon: PhRegular.paperclip,
                          onTap: _showAttachMenu,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: _kComposerHeight,
                        maxHeight: 120,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Nocturne.palette.bg,
                        borderRadius:
                            BorderRadius.circular(_kComposerHeight / 2),
                        border: Border.all(
                          color: Nocturne.palette.edge,
                          width: 1,
                        ),
                      ),
                      // heightFactor keeps the box at its content height;
                      // a plain alignment would stretch it to maxHeight.
                      child: Align(
                        alignment: Alignment.centerLeft,
                        heightFactor: 1,
                        child: _recording
                          ? Row(
                              key: const ValueKey('chat_recording_indicator'),
                              children: [
                                Icon(
                                  PhFill.microphone,
                                  size: 16,
                                  color: Nocturne.palette.expense,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatChatDuration(_recElapsed),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Nocturne.palette.text,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Recording… tap send when done',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Nocturne.palette.muted,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : TextField(
                              key: const ValueKey('chat_composer_field'),
                              controller: _ctrl,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onChanged: (val) {
                                if (val.trim().isNotEmpty) {
                                  chat.sendTyping(widget.partner.userId);
                                }
                              },
                              onSubmitted: (_) => _send(),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: Nocturne.palette.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message ${widget.partner.name}…',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Nocturne.palette.muted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ctrl,
                    builder: (context, value, _) {
                      if (!_recording &&
                          !_sending &&
                          value.text.trim().isEmpty) {
                        return _ComposerButton(
                          key: const ValueKey('chat_mic_button'),
                          tooltip: 'Record voice message',
                          icon: PhRegular.microphone,
                          primary: true,
                          onTap: _startRecording,
                        );
                      }
                      return _ComposerButton(
                        key: const ValueKey('chat_send_button'),
                        tooltip: 'Send',
                        icon: PhBold.caretRight,
                        primary: true,
                        onTap: _recording
                            ? () => _stopRecording(send: true)
                            : _send,
                        child: _sending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Nocturne.palette.accentLight,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DirectMessageRow message;
  final bool isMine;
  final VoidCallback onShowOptions;
  final ValueChanged<Uint8List> onOpenImage;
  final VoidCallback onOpenMedia;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onShowOptions,
    required this.onOpenImage,
    required this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt.toLocal());
    final isTemp = message.id.startsWith('temp_');
    final imgBytes = _chatImageBytes(message);
    final hasMedia = message.hasMedia;
    // The body is only a caption when it differs from the auto label.
    final showBody = hasMedia
        ? message.body !=
            chatMediaBody(
              kind: message.mediaKind ?? 'file',
              name: message.mediaName ?? '',
              viewOnce: message.viewOnce,
            )
        : (!message.isImage ||
            (message.body.isNotEmpty && message.body != '📷 Photo'));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onShowOptions,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          decoration: BoxDecoration(
            color: message.isPoke
                ? Nocturne.mix(Nocturne.palette.warning, 18)
                : (isMine ? Nocturne.palette.accent800 : Nocturne.palette.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: Border.all(
              color: message.isPoke
                  ? Nocturne.palette.warning
                  : (isMine ? Nocturne.palette.tintEdge : Nocturne.palette.edge),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imgBytes != null) ...[
                GestureDetector(
                  key: ValueKey('chat_image_${message.id}'),
                  onTap: () => onOpenImage(imgBytes),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imgBytes,
                      width: 220,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                if (showBody) const SizedBox(height: 6),
              ],
              if (hasMedia) ...[
                _MediaContent(
                  key: ValueKey('chat_media_${message.id}'),
                  message: message,
                  isMine: isMine,
                  onOpen: onOpenMedia,
                ),
                if (showBody) const SizedBox(height: 6),
              ],
              if (showBody)
                if (message.isCall)
                  _CallLogLine(message: message, isMine: isMine)
                else
                Text(
                  message.body,
                  style: TextStyle(
                    fontSize: message.isPoke ? 14 : 13.5,
                    fontWeight:
                        message.isPoke ? FontWeight.w600 : FontWeight.w400,
                    height: 1.35,
                    color: message.isPoke
                        ? Nocturne.palette.warning
                        : (isMine ? Nocturne.palette.accentLight : Nocturne.palette.text),
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Nocturne.palette.accentMuted : Nocturne.palette.muted,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isTemp
                          ? PhRegular.clock
                          // ✓ sent, ✓✓ grey reached their phone, ✓✓ green read.
                          : (message.isDelivered
                              ? PhBold.checks
                              : PhRegular.check),
                      size: 13,
                      color: isTemp
                          ? Nocturne.palette.subtle
                          : (message.isRead
                              ? Nocturne.palette.income
                              : Nocturne.palette.subtle),
                    ),
                  ],
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: ValueKey('chat_msg_options_${message.id}'),
                    onTap: onShowOptions,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      PhRegular.dotsThree,
                      size: 13,
                      color: isMine ? Nocturne.palette.accentMuted : Nocturne.palette.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

/// "Voice call · 2:31" / "Missed video call" with a phone or camera icon.
class _CallLogLine extends StatelessWidget {
  final DirectMessageRow message;
  final bool isMine;
  const _CallLogLine({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final missed = !isMine && message.body.startsWith('Missed');
    final video = message.body.contains('video');
    final color = missed ? p.expense : (isMine ? p.accentLight : p.text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          phosphorCatalog[missed
              ? 'phone-x'
              : (video ? 'video-camera' : (isMine ? 'phone-outgoing' : 'phone-incoming'))]!,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            callLogForViewer(message.body, isCaller: isMine),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chat photos travel as base64 (optionally a data URL) in the message row.
Uint8List? _chatImageBytes(DirectMessageRow message) {
  final raw = message.imageData;
  if (!message.isImage || raw == null || raw.isEmpty) return null;
  try {
    final cleaned = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(cleaned);
  } catch (_) {
    return null;
  }
}

/// Extension sniffed from the bytes, so the saved file opens correctly.
String _chatImageExt(Uint8List b) {
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'png';
  if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return 'gif';
  if (b.length > 11 && b[8] == 0x57 && b[9] == 0x45) return 'webp';
  return 'jpg';
}

String _chatImageName(Uint8List bytes, DirectMessageRow message) =>
    'kinpurse_${message.createdAt.millisecondsSinceEpoch}.'
    '${_chatImageExt(bytes)}';

Future<void> _downloadChatImage(
  BuildContext context,
  Uint8List bytes,
  DirectMessageRow message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await saveChatImage(bytes, _chatImageName(bytes, message));
  messenger.showSnackBar(
    SnackBar(content: Text(ok ? 'Photo saved' : 'Could not save photo')),
  );
}

/// Full-screen chat photo with pinch zoom, Download and Share. A view-once
/// photo ([allowSave] false) gets neither.
class _ChatImageViewer extends StatelessWidget {
  final DirectMessageRow message;
  final Uint8List bytes;
  final bool allowSave;

  const _ChatImageViewer({
    required this.message,
    required this.bytes,
    this.allowSave = true,
  });

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ext = _chatImageExt(bytes);
    try {
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: _chatImageName(bytes, message),
          mimeType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
        ),
      ]);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not share photo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        title: allowSave
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OnceBadge(color: p.text, size: 22),
                  const SizedBox(width: 8),
                  Text('View once',
                      style: TextStyle(fontSize: 15, color: p.text)),
                ],
              ),
        actions: [
          if (allowSave) ...[
            IconButton(
              key: const ValueKey('chat_image_share'),
              tooltip: 'Share',
              icon: Icon(PhRegular.shareNetwork, color: p.text),
              onPressed: () => _share(context),
            ),
            IconButton(
              key: const ValueKey('chat_image_download'),
              tooltip: 'Download',
              icon: Icon(PhRegular.downloadSimple, color: p.text),
              onPressed: () => _downloadChatImage(context, bytes, message),
            ),
          ],
        ],
      ),
      body: GestureDetector(
        onLongPress: allowSave
            ? () => _downloadChatImage(context, bytes, message)
            : null,
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(bytes, gaplessPlayback: true)),
        ),
      ),
    );
  }
}

const double _kComposerHeight = 48;

/// Attach, mic and send share one shape so the composer row lines up.
class _ComposerButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final Widget? child;

  const _ComposerButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: _kComposerHeight,
            height: _kComposerHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? p.switchOn : p.bg,
              borderRadius: BorderRadius.circular(_kComposerHeight / 2),
              border: Border.all(
                color: primary ? p.fabEdge : p.edge,
                width: 1,
              ),
            ),
            child: child ??
                Icon(
                  icon,
                  size: 20,
                  color: primary ? p.accentLight : p.neutral300,
                ),
          ),
        ),
      ),
    );
  }
}

/// Signed URLs are reused for 50 minutes of their hour so scrolling the
/// thread does not re-sign every photo and voice note.
final _signedUrls = <String, (DateTime, Future<String>)>{};

Future<String> _signedChatUrl(V3Repository repo, String path) {
  final hit = _signedUrls[path];
  if (hit != null && DateTime.now().isBefore(hit.$1)) return hit.$2;
  final url = repo.chatMediaUrl(path);
  _signedUrls[path] =
      (DateTime.now().add(const Duration(minutes: 50)), url);
  url.then((_) {}, onError: (_) {
    _signedUrls.remove(path);
  });
  return url;
}

/// Photo bytes shared by the bubble and the full-screen viewer, so opening a
/// photo needs no second download.
final _imageBytes = <String, Future<Uint8List>>{};

Future<Uint8List> _storedImageBytes(V3Repository repo, String path) {
  final hit = _imageBytes.remove(path);
  if (hit != null) return _imageBytes[path] = hit; // re-insert: most recent
  // shortcut: keeps the 40 latest photos in memory, enough for one thread.
  if (_imageBytes.length >= 40) _imageBytes.remove(_imageBytes.keys.first);
  final bytes = repo.downloadChatMedia(path);
  _imageBytes[path] = bytes;
  bytes.then((_) {}, onError: (_) {
    _imageBytes.remove(path);
  });
  return bytes;
}

/// Photo thumbnail, file card, voice player or view-once card for a
/// message whose media lives in Storage.
class _MediaContent extends StatelessWidget {
  final DirectMessageRow message;
  final bool isMine;
  final VoidCallback onOpen;

  const _MediaContent({
    super.key,
    required this.message,
    required this.isMine,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final fg = isMine ? p.accentLight : p.text;
    final sub = isMine ? p.accentMuted : p.muted;
    final repo = context.read<ChatController>().repo;
    final path = message.mediaPath!;
    final pending = message.id.startsWith('temp_');

    if (message.viewOnce) {
      final opened = message.viewedAt != null;
      return _ViewOnceChip(
        key: ValueKey('chat_view_once_${message.id}'),
        opened: opened,
        hint: opened
            ? null
            : isMine
                ? 'Not opened yet'
                : 'Tap to view',
        fg: fg,
        sub: sub,
        onTap: opened || isMine || pending ? null : onOpen,
      );
    }

    if (message.mediaKind == 'voice') {
      return _VoiceNote(
        repo: repo,
        path: path,
        duration: Duration(milliseconds: message.mediaDurationMs ?? 0),
        fg: fg,
        sub: sub,
        enabled: !pending,
      );
    }

    if (message.mediaKind == 'image') {
      return GestureDetector(
        key: ValueKey('chat_image_${message.id}'),
        onTap: pending ? null : onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 220,
            child: pending
                ? _mediaPlaceholder(p.bg, sub, PhRegular.image)
                : FutureBuilder<Uint8List>(
                    future: _storedImageBytes(repo, path),
                    builder: (context, snap) => snap.hasData
                        ? Image.memory(
                            snap.data!,
                            width: 220,
                            // Decode at bubble size, not full resolution.
                            cacheWidth: (220 *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                _mediaPlaceholder(p.bg, sub, PhRegular.image),
                          )
                        : _mediaPlaceholder(p.bg, sub, PhRegular.image),
                  ),
          ),
        ),
      );
    }

    final size = message.mediaSize;
    return _MediaCard(
      icon: PhRegular.file,
      title: message.mediaName ?? 'File',
      subtitle: [
        if (size != null) formatChatBytes(size),
        pending ? 'Uploading…' : 'Tap to download',
      ].join(' · '),
      fg: fg,
      sub: sub,
      onTap: pending ? null : onOpen,
    );
  }

  static Widget _mediaPlaceholder(Color bg, Color fg, IconData icon) =>
      Container(
        height: 160,
        color: bg,
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: fg),
      );
}

/// WhatsApp-style view-once bubble: a "1" badge and one short line.
class _ViewOnceChip extends StatelessWidget {
  final bool opened;
  final String? hint;
  final Color fg;
  final Color sub;
  final VoidCallback? onTap;

  const _ViewOnceChip({
    super.key,
    required this.opened,
    required this.hint,
    required this.fg,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = opened ? sub : fg;
    return Semantics(
      button: onTap != null,
      label: opened ? 'View once photo, opened' : 'View once photo',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OnceBadge(color: color, size: 26, dim: opened),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opened ? 'Opened' : 'Photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: opened ? FontWeight.w400 : FontWeight.w600,
                      fontStyle: opened ? FontStyle.italic : FontStyle.normal,
                      color: color,
                    ),
                  ),
                  if (hint != null)
                    Text(hint!, style: TextStyle(fontSize: 11.5, color: sub)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circled "1", the view-once mark.
class _OnceBadge extends StatelessWidget {
  final Color color;
  final double size;
  final bool dim;

  const _OnceBadge({required this.color, required this.size, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: dim ? 0.5 : 1), width: 1.6),
      ),
      child: Text(
        '1',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.5,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: dim ? 0.5 : 1),
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color fg;
  final Color sub;
  final VoidCallback? onTap;

  const _MediaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fg,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Nocturne.palette.bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline voice note: play/pause, progress and time. The player is made on
/// first play, so a thread full of voice notes costs nothing until used.
class _VoiceNote extends StatefulWidget {
  final V3Repository repo;
  final String path;
  final Duration duration;
  final Color fg;
  final Color sub;
  final bool enabled;

  const _VoiceNote({
    required this.repo,
    required this.path,
    required this.duration,
    required this.fg,
    required this.sub,
    required this.enabled,
  });

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];
  Duration _pos = Duration.zero;
  Duration? _len;
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    var player = _player;
    if (player == null) {
      setState(() => _loading = true);
      try {
        player = AudioPlayer();
        _player = player;
        _subs.add(player.positionStream.listen((d) {
          if (mounted) setState(() => _pos = d);
        }));
        _subs.add(player.playerStateStream.listen((st) {
          if (!mounted) return;
          if (st.processingState == ProcessingState.completed) {
            player!.pause();
            player.seek(Duration.zero);
          }
          setState(() => _playing = st.playing &&
              st.processingState != ProcessingState.completed);
        }));
        _len = await player.setUrl(await _signedChatUrl(widget.repo, widget.path));
      } catch (_) {
        _player = null;
        await player?.dispose();
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not play voice message')),
          );
        }
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Nocturne.palette;
    final len = (_len == null || _len == Duration.zero) ? widget.duration : _len!;
    final progress = len.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / len.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Pause voice message' : 'Play voice message',
            child: GestureDetector(
              onTap: widget.enabled && !_loading ? _toggle : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.fg,
                        ),
                      )
                    : Icon(
                        _playing ? PhFill.pause : PhFill.play,
                        size: 18,
                        color: widget.fg,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: widget.fg,
                    backgroundColor: p.line,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _playing || _pos > Duration.zero
                      ? '${formatChatDuration(_pos)} / ${formatChatDuration(len)}'
                      : formatChatDuration(len),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: widget.sub,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

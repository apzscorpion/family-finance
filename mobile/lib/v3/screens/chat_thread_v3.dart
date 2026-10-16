import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/nocturne.dart';
import '../data/call_logic.dart';
import '../data/call_service.dart';
import '../data/chat_controller.dart';
import '../data/chat_media_io.dart'
    if (dart.library.js_interop) '../data/chat_media_web.dart';
import '../data/v3_models.dart';
import '../phosphor_catalog.dart';
import '../phosphor_icons.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import 'chat_list_v3.dart' show AvatarWithOnlineDot;

/// 1:1 Direct Message conversation screen between the signed-in user and
/// [partner], with live online dot, typing indicator, read receipts, poke,
/// photo sharing, single-message delete, and thread clear.
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

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 72,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !mounted) return;
      final b64 = base64Encode(bytes);
      final caption = _ctrl.text.trim();
      _ctrl.clear();
      setState(() => _sending = true);
      final chat = context.read<ChatController>();
      final ok = await chat.sendImage(
        recipientId: widget.partner.userId,
        base64Data: b64,
        caption: caption,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send photo')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not attach photo')),
      );
    }
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
              if (imgBytes != null)
                ListTile(
                  key: const ValueKey('chat_download_image_action'),
                  leading: Icon(
                    PhRegular.downloadSimple,
                    color: Nocturne.palette.text,
                  ),
                  title: Text(
                    'Download photo',
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
    if (action == 'download' && imgBytes != null && mounted) {
      await _downloadChatImage(context, imgBytes, msg);
    }
  }

  void _openImage(DirectMessageRow msg, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ChatImageViewer(message: msg, bytes: bytes),
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
                        );
                      },
                    ),
            ),

            // Composer
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
                  GestureDetector(
                    key: const ValueKey('chat_attach_image_button'),
                    onTap: _pickAndSendImage,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.palette.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Nocturne.palette.edge,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        PhRegular.image,
                        size: 18,
                        color: Nocturne.palette.neutral300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Nocturne.palette.bg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Nocturne.palette.edge,
                          width: 1,
                        ),
                      ),
                      child: TextField(
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
                          color: Nocturne.palette.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message ${widget.partner.name}…',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: Nocturne.palette.muted,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const ValueKey('chat_send_button'),
                    onTap: _send,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.palette.switchOn,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Nocturne.palette.fabEdge,
                          width: 1,
                        ),
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Nocturne.palette.accentLight,
                              ),
                            )
                          : Icon(
                              PhBold.caretRight,
                              size: 18,
                              color: Nocturne.palette.accentLight,
                            ),
                    ),
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onShowOptions,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt.toLocal());
    final isTemp = message.id.startsWith('temp_');
    final imgBytes = _chatImageBytes(message);

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
                if (message.body.isNotEmpty && message.body != '📷 Photo')
                  const SizedBox(height: 6),
              ],
              if (!message.isImage ||
                  (message.body.isNotEmpty && message.body != '📷 Photo'))
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
                          : (message.isRead
                              ? PhBold.checks
                              : PhRegular.check),
                      size: 12,
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

/// Full-screen chat photo with pinch zoom, Download and Share.
class _ChatImageViewer extends StatelessWidget {
  final DirectMessageRow message;
  final Uint8List bytes;

  const _ChatImageViewer({required this.message, required this.bytes});

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
        actions: [
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
      ),
      body: GestureDetector(
        onLongPress: () => _downloadChatImage(context, bytes, message),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(bytes, gaplessPlayback: true)),
        ),
      ),
    );
  }
}

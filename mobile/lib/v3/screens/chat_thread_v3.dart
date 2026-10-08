import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
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
        backgroundColor: Nocturne.surface,
        title: const Text(
          'Clear conversation?',
          style: TextStyle(color: Nocturne.text, fontSize: 16),
        ),
        content: Text(
          'This removes all messages between you and ${widget.partner.name} for both of you.',
          style: const TextStyle(color: Nocturne.neutral300, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Nocturne.neutral400),
            ),
          ),
          TextButton(
            key: const ValueKey('chat_confirm_clear_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear chat',
              style: TextStyle(color: NocturneSemantic.expense),
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
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('chat_delete_message_action'),
                leading: const Icon(
                  PhRegular.trash,
                  color: NocturneSemantic.expense,
                ),
                title: const Text(
                  'Delete message for everyone',
                  style: TextStyle(
                    color: NocturneSemantic.expense,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete == true && mounted) {
      await chat.deleteMessage(msg.id);
    }
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
      statusColor = Nocturne.accent300;
    } else if (isOnline) {
      statusText = 'Online now · Live';
      statusColor = NocturneSemantic.income;
    } else {
      statusText =
          chat.isRealtimeConnected ? '$roleLabel · Live sync' : roleLabel;
      statusColor = Nocturne.neutral500;
    }

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Thread header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Nocturne.bg,
                border: Border(
                  bottom: BorderSide(color: Nocturne.neutral900, width: 1),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBack,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        PhRegular.arrowLeft,
                        size: 20,
                        color: Nocturne.text,
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.text,
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
                  GestureDetector(
                    key: const ValueKey('chat_poke_button'),
                    onTap: _poke,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Nocturne.neutral800, width: 1),
                      ),
                      child: const Icon(
                        PhRegular.bellRinging,
                        size: 17,
                        color: NocturneSemantic.warning,
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
                        color: Nocturne.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Nocturne.neutral800, width: 1),
                      ),
                      child: const Icon(
                        PhRegular.trash,
                        size: 17,
                        color: Nocturne.neutral400,
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Direct messages sync instantly over WebSockets and notify across web and phone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Nocturne.neutral500,
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
                        );
                      },
                    ),
            ),

            // Composer
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Nocturne.surface,
                border: Border(
                  top: BorderSide(color: Nocturne.neutral800, width: 1),
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
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Nocturne.neutral800,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        PhRegular.image,
                        size: 18,
                        color: Nocturne.neutral300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Nocturne.neutral800,
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Nocturne.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message ${widget.partner.name}…',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Nocturne.neutral500,
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
                        color: Nocturne.accent700,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Nocturne.accent400,
                          width: 1,
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Nocturne.accent100,
                              ),
                            )
                          : const Icon(
                              PhBold.caretRight,
                              size: 18,
                              color: Nocturne.accent100,
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onShowOptions,
  });

  Uint8List? _decodeImage() {
    final raw = message.imageData;
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt.toLocal());
    final isTemp = message.id.startsWith('temp_');
    final imgBytes = message.isImage ? _decodeImage() : null;

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
                ? Nocturne.mix(NocturneSemantic.warning, 18)
                : (isMine ? Nocturne.accent800 : Nocturne.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: Border.all(
              color: message.isPoke
                  ? NocturneSemantic.warning
                  : (isMine ? Nocturne.accent600 : Nocturne.neutral800),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imgBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    imgBytes,
                    width: 220,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                if (message.body.isNotEmpty && message.body != '📷 Photo')
                  const SizedBox(height: 6),
              ],
              if (!message.isImage ||
                  (message.body.isNotEmpty && message.body != '📷 Photo'))
                Text(
                  message.body,
                  style: TextStyle(
                    fontSize: message.isPoke ? 14 : 13.5,
                    fontWeight:
                        message.isPoke ? FontWeight.w600 : FontWeight.w400,
                    height: 1.35,
                    color: message.isPoke
                        ? NocturneSemantic.warning
                        : (isMine ? Nocturne.accent100 : Nocturne.text),
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
                      color: isMine ? Nocturne.accent300 : Nocturne.neutral500,
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
                          ? Nocturne.neutral400
                          : (message.isRead
                              ? NocturneSemantic.income
                              : Nocturne.neutral400),
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
                      color: isMine ? Nocturne.accent300 : Nocturne.neutral500,
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
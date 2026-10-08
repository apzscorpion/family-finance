import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// 1:1 Direct Message conversation screen between the signed-in user and
/// [partner].
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
      chat.ensureJoined(familyId: s.familyId, myId: s.myId);
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final chat = context.watch<ChatController>();
    final messages = chat.threadWith(widget.partner.userId);

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Thread header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 10),
              decoration: const BoxDecoration(
                color: Nocturne.bg,
                border: Border(
                  bottom: BorderSide(color: Nocturne.neutral900, width: 1),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack ?? () => Navigator.of(context).pop(),
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
                  V3Avatar(
                    initial: widget.partner.initial,
                    color: widget.partner.color,
                    size: 34,
                    fontSize: 13,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.partner.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text,
                          ),
                        ),
                        Text(
                          widget.partner.relationship.isNotEmpty
                              ? widget.partner.relationship
                              : widget.partner.role,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Nocturne.neutral500,
                          ),
                        ),
                      ],
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
                            V3Avatar(
                              initial: widget.partner.initial,
                              color: widget.partner.color,
                              size: 48,
                              fontSize: 18,
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
                              'Direct messages are private between the two of you.',
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isMine ? Nocturne.accent800 : Nocturne.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: Border.all(
            color: isMine ? Nocturne.accent600 : Nocturne.neutral800,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: isMine ? Nocturne.accent100 : Nocturne.text,
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
                    message.isRead ? PhRegular.checks : PhRegular.check,
                    size: 12,
                    color: message.isRead
                        ? Nocturne.accent200
                        : Nocturne.neutral400,
                  ),
                ],
              ],
            ),
          ],
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

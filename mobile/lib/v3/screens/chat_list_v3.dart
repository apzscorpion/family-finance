import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'chat_thread_v3.dart';

/// Lists 1:1 Direct Message conversations with every active family member.
class ChatListV3 extends StatefulWidget {
  final String? initialPartnerId;

  const ChatListV3({super.key, this.initialPartnerId});

  @override
  State<ChatListV3> createState() => _ChatListV3State();
}

class _ChatListV3State extends State<ChatListV3> {
  MemberRow? _selectedPartner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<V3State>();
      final chat = context.read<ChatController>();
      chat.ensureJoined(familyId: s.familyId, myId: s.myId);
      if (widget.initialPartnerId != null) {
        final m = s.memberById(widget.initialPartnerId!);
        if (m != null) {
          setState(() => _selectedPartner = m);
        }
      }
    });
  }

  void _openThread(MemberRow partner) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadV3(partner: partner),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final chat = context.watch<ChatController>();
    final threads = chat.threadsForMembers(s.members);

    if (_selectedPartner != null) {
      return ChatThreadV3(
        partner: _selectedPartner!,
        onBack: () => setState(() => _selectedPartner = null),
      );
    }

    return RefreshIndicator(
      onRefresh: chat.refresh,
      color: Nocturne.accent300,
      backgroundColor: Nocturne.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (threads.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 36),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhRegular.envelopeSimple,
                    size: 32,
                    color: Nocturne.neutral500,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No other family members yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.text,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Invite family members from the More tab to start direct messaging.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Nocturne.neutral500,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < threads.length; i++) ...[
                    _ThreadTile(
                      summary: threads[i],
                      myId: s.myId ?? '',
                      onTap: () => _openThread(threads[i].partner),
                    ),
                    if (i < threads.length - 1) const V3RowDivider(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThreadSummary summary;
  final String myId;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.summary,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final partner = summary.partner;
    final last = summary.lastMessage;
    final unread = summary.unreadCount;

    final preview = last == null
        ? 'Tap to start a conversation'
        : (last.senderId == myId ? 'You: ${last.body}' : last.body);

    return GestureDetector(
      key: ValueKey('chat_thread_tile_${partner.userId}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            V3Avatar(
              initial: partner.initial,
              color: partner.color,
              size: 42,
              fontSize: 15,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: Nocturne.text,
                          ),
                        ),
                      ),
                      if (last != null)
                        Text(
                          _relativeTime(last.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: unread > 0
                                ? Nocturne.accent300
                                : Nocturne.neutral500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: unread > 0
                                ? Nocturne.neutral200
                                : Nocturne.neutral500,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Nocturne.accent600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Nocturne.accent100,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final l = dt.toLocal();
    return '${l.day}/${l.month}';
  }
}

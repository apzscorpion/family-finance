import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'chat_thread_v3.dart';

/// Lists 1:1 Direct Message conversations with every active family member,
/// including live WebSocket status, online dots, typing indicators, and
/// browser notification controls.
class ChatListV3 extends StatefulWidget {
  final String? initialPartnerId;

  const ChatListV3({super.key, this.initialPartnerId});

  @override
  State<ChatListV3> createState() => _ChatListV3State();
}

class _ChatListV3State extends State<ChatListV3> {
  String? _localPartnerId;

  @override
  void initState() {
    super.initState();
    _localPartnerId = widget.initialPartnerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<V3State>();
      final chat = context.read<ChatController>();
      final nav = context.read<V3Nav?>();
      chat.syncContext(
        familyId: s.familyId,
        myId: s.myId,
        members: s.members,
        onTapSender: (senderId) {
          if (nav != null) {
            nav.openChat(senderId);
          } else if (mounted) {
            setState(() => _localPartnerId = senderId);
          }
        },
      );
    });
  }

  void _openThread(MemberRow partner) {
    final nav = context.read<V3Nav?>();
    setState(() => _localPartnerId = partner.userId);
    nav?.openChat(partner.userId);
  }

  void _closeThread() {
    final nav = context.read<V3Nav?>();
    setState(() => _localPartnerId = null);
    if (nav != null && nav.chatPartnerId != null) {
      nav.closeChatThread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final chat = context.watch<ChatController>();
    final nav = context.watch<V3Nav?>();

    final activePartnerId = nav?.chatPartnerId ?? _localPartnerId;
    if (activePartnerId != null) {
      final partner = s.memberById(activePartnerId);
      if (partner != null) {
        return ChatThreadV3(
          key: ValueKey('chat_thread_${partner.userId}'),
          partner: partner,
          onBack: _closeThread,
        );
      }
    }

    final threads = chat.threadsForMembers(s.members);
    final onlineCount = chat.onlinePeersCount(s.members);
    final wsLive = chat.isRealtimeConnected;
    final showWebNotifPrompt =
        kIsWeb && chat.notificationPermissionStatus == 'default';

    return RefreshIndicator(
      onRefresh: () => chat.refresh(notifyNew: true),
      color: Nocturne.accent300,
      backgroundColor: Nocturne.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Live WebSocket & Online Status bar
          _LiveStatusHeader(
            wsLive: wsLive,
            onlineCount: onlineCount,
            showWebNotifPrompt: showWebNotifPrompt,
            onEnableNotifications: () async {
              final ok = await chat.requestNotificationsPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '🔔 Browser notifications & sound enabled!'
                          : 'Allow notifications in your browser address bar to receive background alerts.',
                    ),
                  ),
                );
              }
            },
            onRefresh: () => chat.refresh(notifyNew: true),
          ),

          if (threads.isNotEmpty) ...[
            const SizedBox(height: 12),
            _OnlineMembersStrip(
              threads: threads,
              onSelect: _openThread,
            ),
            const SizedBox(height: 12),
          ],

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
                    PhRegular.chatCircleDots,
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
                      onPoke: () async {
                        await chat.pokeMember(threads[i].partner.userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '👋 Poked ${threads[i].partner.name}!',
                              ),
                            ),
                          );
                        }
                      },
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

class _LiveStatusHeader extends StatelessWidget {
  final bool wsLive;
  final int onlineCount;
  final bool showWebNotifPrompt;
  final VoidCallback onEnableNotifications;
  final VoidCallback onRefresh;

  const _LiveStatusHeader({
    required this.wsLive,
    required this.onlineCount,
    required this.showWebNotifPrompt,
    required this.onEnableNotifications,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor =
        wsLive ? NocturneSemantic.income : NocturneSemantic.warning;
    final statusLabel = wsLive ? 'Live WebSocket' : 'Syncing…';
    final onlineLabel =
        onlineCount > 0 ? '$onlineCount online now' : 'Real-time active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nocturne.neutral800, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Nocturne.mix(dotColor, 55),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$statusLabel · $onlineLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Nocturne.neutral300,
              ),
            ),
          ),
          if (showWebNotifPrompt) ...[
            GestureDetector(
              key: const ValueKey('chat_enable_notifications_button'),
              onTap: onEnableNotifications,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Nocturne.accent900,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Nocturne.accent600, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhRegular.bellRinging,
                      size: 13,
                      color: Nocturne.accent200,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Enable alerts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.accent100,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: onRefresh,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                PhRegular.arrowsClockwise,
                size: 15,
                color: Nocturne.neutral400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineMembersStrip extends StatelessWidget {
  final List<ChatThreadSummary> threads;
  final ValueChanged<MemberRow> onSelect;

  const _OnlineMembersStrip({
    required this.threads,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: threads.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = threads[i];
          final partner = item.partner;
          final online = item.isOnline;
          return GestureDetector(
            onTap: () => onSelect(partner),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWithOnlineDot(
                  initial: partner.initial,
                  color: partner.color,
                  size: 46,
                  fontSize: 16,
                  isOnline: online,
                  dotKey: ValueKey('chat_strip_online_dot_${partner.userId}'),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${partner.name.split(' ').first} · ${online ? 'Live' : 'Offline'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: online ? FontWeight.w600 : FontWeight.w400,
                        color: online ? Nocturne.text : Nocturne.neutral400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reusable avatar with a live online/offline status dot at the bottom-right.
class AvatarWithOnlineDot extends StatelessWidget {
  final String initial;
  final Color color;
  final double size;
  final double fontSize;
  final bool isOnline;
  final bool showOfflineDot;
  final Key? dotKey;

  const AvatarWithOnlineDot({
    super.key,
    required this.initial,
    required this.color,
    this.size = 42,
    this.fontSize = 15,
    required this.isOnline,
    this.showOfflineDot = true,
    this.dotKey,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = (size * 0.29).clamp(10.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        V3Avatar(
          initial: initial,
          color: color,
          size: size,
          fontSize: fontSize,
        ),
        if (isOnline || showOfflineDot)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              key: dotKey,
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: isOnline ? NocturneSemantic.income : Nocturne.neutral600,
                shape: BoxShape.circle,
                border: Border.all(color: Nocturne.surface, width: 2),
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: Nocturne.mix(NocturneSemantic.income, 55),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThreadSummary summary;
  final String myId;
  final VoidCallback onTap;
  final VoidCallback onPoke;

  const _ThreadTile({
    required this.summary,
    required this.myId,
    required this.onTap,
    required this.onPoke,
  });

  @override
  Widget build(BuildContext context) {
    final partner = summary.partner;
    final last = summary.lastMessage;
    final unread = summary.unreadCount;
    final online = summary.isOnline;
    final typing = summary.isTyping;

    final String preview;
    if (typing) {
      preview = 'typing…';
    } else if (last == null) {
      preview = online ? 'Online · Tap to say hi' : 'Tap to start a conversation';
    } else {
      final bodyText = last.isImage
          ? (last.body.isNotEmpty && last.body != '📷 Photo'
              ? '📷 ${last.body}'
              : '📷 Photo')
          : last.body;
      preview = last.senderId == myId ? 'You: $bodyText' : bodyText;
    }

    return GestureDetector(
      key: ValueKey('chat_thread_tile_${partner.userId}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            AvatarWithOnlineDot(
              initial: partner.initial,
              color: partner.color,
              size: 42,
              fontSize: 15,
              isOnline: online,
              dotKey: ValueKey('chat_online_dot_${partner.userId}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
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
                      if (online) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Nocturne.mix(NocturneSemantic.income, 18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: NocturneSemantic.income,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
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
                      if (!typing && last != null && last.senderId == myId) ...[
                        Icon(
                          last.isRead ? PhBold.checks : PhRegular.check,
                          size: 13,
                          color: last.isRead
                              ? NocturneSemantic.income
                              : Nocturne.neutral500,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle:
                                typing ? FontStyle.italic : FontStyle.normal,
                            fontWeight: typing || unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: typing
                                ? Nocturne.accent300
                                : (unread > 0
                                    ? Nocturne.neutral200
                                    : Nocturne.neutral500),
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
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPoke,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nocturne.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Nocturne.neutral800, width: 1),
                ),
                child: const Icon(
                  PhRegular.bellRinging,
                  size: 16,
                  color: NocturneSemantic.warning,
                ),
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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/nocturne.dart';
import '../v3/data/chat_controller.dart';
import '../v3/data/notes_presence.dart';
import '../v3/data/v3_models.dart';
import '../v3/data/v3_repository.dart';
import '../v3/phosphor_icons.dart';
import '../v3/screens/activity_v3.dart';
import '../v3/screens/auth_v3.dart';
import '../v3/screens/chat_list_v3.dart';
import '../v3/screens/home_v3.dart';
import '../v3/screens/insights_v3.dart';
import '../v3/screens/notes_v3.dart';
import '../v3/screens/onboarding_v3.dart';
import '../v3/sheets/v3_sheets.dart';
import '../v3/v3_app.dart' show v3Theme;
import '../v3/v3_nav.dart';
import '../v3/v3_state.dart';

/// Web-only entry widget composing only web-safe providers (`V3State`, `V3Nav`,
/// `NotesPresenceService`, `ChatController`) and never constructing
/// `PrayerController`.
///
/// Money screens (`HomeV3`, `ActivityV3`, `InsightsV3`) run in read-only mode,
/// while `NotesV3` and `ChatListV3` are fully editable with live WebSockets.
class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    V3Sheets.readOnly = true;
    final db = Supabase.instance.client;
    final repo = V3Repository(db);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => V3State(repo)..bootstrap(),
        ),
        ChangeNotifierProvider(create: (_) => V3Nav()),
        ChangeNotifierProvider(
          create: (_) => NotesPresenceService(db),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatController(repo, db),
        ),
      ],
      child: MaterialApp(
        title: 'Family Spend Tracker — Web',
        debugShowCheckedModeBanner: false,
        theme: v3Theme,
        home: const WebRoot(),
      ),
    );
  }
}

class WebRoot extends StatelessWidget {
  const WebRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    if (Supabase.instance.client.auth.currentUser == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AuthV3(onSignedIn: s.bootstrap),
        ),
      );
    }

    if (s.loading && s.family == null) {
      return const Scaffold(
        backgroundColor: Nocturne.bg,
        body: Center(
          child: CircularProgressIndicator(color: Nocturne.accent300),
        ),
      );
    }

    if (s.loadError != null && s.family == null) {
      return Scaffold(
        backgroundColor: Nocturne.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhRegular.warning,
                  size: 36,
                  color: Nocturne.neutral500,
                ),
                const SizedBox(height: 12),
                Text(
                  s.loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Nocturne.neutral300,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: s.bootstrap,
                  child: const Text(
                    'Try again',
                    style: TextStyle(color: Nocturne.accent300),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (s.family == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const OnboardingV3(),
        ),
      );
    }

    return const WebShell();
  }
}

/// Responsive web shell with a side navigation rail on desktop/tablet and a
/// max-width content column, plus live incoming DM toast alerts.
///
/// Tabs:
/// - 0: Overview (`HomeV3`, read-only)
/// - 1: Activity (`ActivityV3`, read-only)
/// - 2: Insights (`InsightsV3`, read-only)
/// - 3: Notes (`NotesV3`, editable + live collaborative sync)
/// - 4: Messages (`ChatListV3`, editable + live DMs)
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  StreamSubscription<DirectMessageRow>? _alertSub;
  DirectMessageRow? _activeToast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    V3Sheets.readOnly = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRealtimeControllers();
      final chat = context.read<ChatController?>();
      if (chat != null) {
        _alertSub = chat.incomingAlerts.listen(_onIncomingAlert);
      }
    });
  }

  void _syncRealtimeControllers() {
    if (!mounted) return;
    final s = context.read<V3State>();
    final nav = context.read<V3Nav>();
    final chat = context.read<ChatController?>();
    final presence = context.read<NotesPresenceService?>();
    if (s.familyId.isNotEmpty && (s.myId?.isNotEmpty ?? false)) {
      chat?.syncContext(
        familyId: s.familyId,
        myId: s.myId,
        members: s.members,
        onTapSender: (senderId) => nav.openChat(senderId),
      );
      presence?.connect(
        familyId: s.familyId,
        selfName: s.me?.name ?? 'Member',
      );
    }
  }

  void _onIncomingAlert(DirectMessageRow row) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _activeToast = row);
    _toastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _activeToast = null);
      }
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  int _effectiveTab(V3Nav nav) {
    if (nav.page == V3Page.notes) return 3;
    if (nav.page == V3Page.chat) return 4;
    return nav.tab.clamp(0, 4);
  }

  void _selectSection(V3Nav nav, int index) {
    nav.closePage();
    nav.goTab(index);
  }

  @override
  Widget build(BuildContext context) {
    V3Sheets.readOnly = true;
    final nav = context.watch<V3Nav>();
    final s = context.watch<V3State>();
    final chat = context.watch<ChatController?>();
    final unreadDm = chat?.totalUnread ?? 0;
    final wsConnected = chat?.isRealtimeConnected ?? false;
    final onlinePeers = chat?.onlinePeersCount(s.members) ?? 0;
    final activeIdx = _effectiveTab(nav);
    final isMoneyTab = activeIdx <= 2;

    if (s.family != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncRealtimeControllers();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        final content = Stack(
          children: [
            Column(
              children: [
                if (isMoneyTab) const _ReadOnlyMoneyBanner(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: IndexedStack(
                        index: activeIdx,
                        children: const [
                          HomeV3(),
                          ActivityV3(),
                          InsightsV3(),
                          NotesV3(),
                          ChatListV3(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_activeToast != null)
              Positioned(
                top: 12,
                right: 16,
                left: wide ? null : 16,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _IncomingMessageToast(
                    message: _activeToast!,
                    sender: s.memberById(_activeToast!.senderId),
                    onOpen: () {
                      final senderId = _activeToast!.senderId;
                      setState(() => _activeToast = null);
                      nav.openChat(senderId);
                    },
                    onDismiss: () => setState(() => _activeToast = null),
                  ),
                ),
              ),
          ],
        );

        if (wide) {
          return Scaffold(
            backgroundColor: Nocturne.bg,
            body: Row(
              children: [
                _WebSideNav(
                  familyName: s.family?.name ?? 'Workspace',
                  memberName: s.me?.name ?? '',
                  activeIdx: activeIdx,
                  unreadDm: unreadDm,
                  wsConnected: wsConnected,
                  onlinePeers: onlinePeers,
                  members: s.members,
                  myId: s.myId ?? '',
                  chat: chat,
                  onSelect: (i) => _selectSection(nav, i),
                  onQuickChat: (partnerId) => nav.openChat(partnerId),
                ),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Nocturne.bg,
          body: SafeArea(child: content),
          bottomNavigationBar: _WebBottomBar(
            activeIdx: activeIdx,
            unreadDm: unreadDm,
            onSelect: (i) => _selectSection(nav, i),
          ),
        );
      },
    );
  }
}

class _IncomingMessageToast extends StatelessWidget {
  final DirectMessageRow message;
  final MemberRow? sender;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _IncomingMessageToast({
    required this.message,
    required this.sender,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = sender?.name ?? 'Family member';
    final initial =
        sender?.initial ?? (senderName.isEmpty ? '?' : senderName[0]);
    final avatarColor = sender?.color ?? Nocturne.accent600;
    final preview = message.isPoke
        ? '👋 Poked you!'
        : (message.isImage ? '📷 Sent a photo' : message.body);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: message.isPoke
                  ? NocturneSemantic.warning
                  : Nocturne.accent500,
              width: 1,
            ),
            boxShadow: Nocturne.shadowMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWithOnlineDot(
                initial: initial,
                color: avatarColor,
                size: 36,
                fontSize: 13,
                isOnline: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.isPoke
                          ? '$senderName poked you!'
                          : 'New message · $senderName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Nocturne.neutral300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Nocturne.accent700,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.accent100,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    PhRegular.x,
                    size: 14,
                    color: Nocturne.neutral400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyMoneyBanner extends StatelessWidget {
  const _ReadOnlyMoneyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('web_readonly_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        border: Border(
          bottom: BorderSide(color: Nocturne.neutral800, width: 1),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhRegular.eye, size: 14, color: Nocturne.accent300),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Expenses are read-only on web · Notes and Direct Messages are live & editable',
              style: TextStyle(fontSize: 12, color: Nocturne.neutral300),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSideNav extends StatelessWidget {
  final String familyName;
  final String memberName;
  final int activeIdx;
  final int unreadDm;
  final bool wsConnected;
  final int onlinePeers;
  final List<MemberRow> members;
  final String myId;
  final ChatController? chat;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onQuickChat;

  const _WebSideNav({
    required this.familyName,
    required this.memberName,
    required this.activeIdx,
    required this.unreadDm,
    required this.wsConnected,
    required this.onlinePeers,
    required this.members,
    required this.myId,
    required this.chat,
    required this.onSelect,
    required this.onQuickChat,
  });

  @override
  Widget build(BuildContext context) {
    final peers = members.where((m) => m.isActive && m.userId != myId).toList();

    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        border: Border(
          right: BorderSide(color: Nocturne.neutral800, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  familyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: wsConnected
                            ? NocturneSemantic.income
                            : NocturneSemantic.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        memberName.isNotEmpty
                            ? '$memberName · ${wsConnected ? 'Live' : 'Syncing'}'
                            : (wsConnected ? 'Live connected' : 'Syncing'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Nocturne.neutral400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'FINANCE (READ-ONLY)',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: Nocturne.neutral500,
              ),
            ),
          ),
          _NavTile(
            key: const ValueKey('web_nav_home'),
            icon: PhRegular.house,
            label: 'Overview',
            active: activeIdx == 0,
            onTap: () => onSelect(0),
          ),
          _NavTile(
            key: const ValueKey('web_nav_activity'),
            icon: PhRegular.listBullets,
            label: 'Activity',
            active: activeIdx == 1,
            onTap: () => onSelect(1),
          ),
          _NavTile(
            key: const ValueKey('web_nav_insights'),
            icon: PhRegular.chartDonut,
            label: 'Insights',
            active: activeIdx == 2,
            onTap: () => onSelect(2),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'COLLABORATION (LIVE)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.accent300,
                    ),
                  ),
                ),
                if (onlinePeers > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Nocturne.mix(NocturneSemantic.income, 18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$onlinePeers online',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: NocturneSemantic.income,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _NavTile(
            key: const ValueKey('web_nav_notes'),
            icon: PhRegular.notePencil,
            label: 'Family notes',
            active: activeIdx == 3,
            onTap: () => onSelect(3),
          ),
          _NavTile(
            key: const ValueKey('web_nav_chat'),
            icon: PhRegular.envelopeSimple,
            label: 'Direct messages',
            active: activeIdx == 4,
            badgeCount: unreadDm,
            onTap: () => onSelect(4),
          ),
          if (peers.isNotEmpty) ...[
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                'FAMILY MEMBERS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.neutral500,
                ),
              ),
            ),
            for (final m in peers.take(5))
              _SidebarMemberRow(
                member: m,
                isOnline: chat?.isUserOnline(m.userId) ?? false,
                unread: chat?.unreadFrom(m.userId) ?? 0,
                onTap: () => onQuickChat(m.userId),
              ),
          ],
        ],
      ),
    );
  }
}

class _SidebarMemberRow extends StatelessWidget {
  final MemberRow member;
  final bool isOnline;
  final int unread;
  final VoidCallback onTap;

  const _SidebarMemberRow({
    required this.member,
    required this.isOnline,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            AvatarWithOnlineDot(
              initial: member.initial,
              color: member.color,
              size: 26,
              fontSize: 10.5,
              isOnline: isOnline,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isOnline ? FontWeight.w500 : FontWeight.w400,
                  color: isOnline ? Nocturne.text : Nocturne.neutral400,
                ),
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                decoration: BoxDecoration(
                  color: Nocturne.accent600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.accent100,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? Nocturne.accent900 : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: active
                ? Border.all(color: Nocturne.accent700, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Nocturne.accent200 : Nocturne.neutral400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? Nocturne.text : Nocturne.neutral300,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Nocturne.accent600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.accent100,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebBottomBar extends StatelessWidget {
  final int activeIdx;
  final int unreadDm;
  final ValueChanged<int> onSelect;

  const _WebBottomBar({
    required this.activeIdx,
    required this.unreadDm,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (PhRegular.house, 'Home'),
      (PhRegular.listBullets, 'Activity'),
      (PhRegular.chartDonut, 'Insights'),
      (PhRegular.notePencil, 'Notes'),
      (PhRegular.envelopeSimple, 'Chat'),
    ];

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Nocturne.bg,
        border: Border(top: BorderSide(color: Nocturne.neutral900, width: 1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          items[i].$1,
                          size: 20,
                          color: activeIdx == i
                              ? Nocturne.accent300
                              : Nocturne.neutral600,
                        ),
                        if (i == 4 && unreadDm > 0)
                          Positioned(
                            right: -7,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Nocturne.accent600,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Nocturne.bg,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                unreadDm > 9 ? '9+' : '$unreadDm',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.accent100,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: activeIdx == i
                            ? Nocturne.accent200
                            : Nocturne.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

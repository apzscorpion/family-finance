import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/nocturne.dart';
import '../theme/nocturne_palette.dart';
import 'data/bill_scan.dart';
import 'data/call_service.dart';
import 'data/card_scan.dart';
import 'data/chat_controller.dart';
import 'data/notes_presence.dart';
import 'data/prayer/prayer_controller.dart';
import 'data/v3_repository.dart';
import '../services/widget_service.dart';
import '../services/biometric_service.dart';
import 'v3_design.dart';
import 'phosphor_icons.dart';
import 'screens/activity_v3.dart';
import 'screens/ai_settings_v3.dart';
import 'screens/ask_kinpurse_v3.dart';
import 'screens/auth_v3.dart';
import 'screens/call_v3.dart';
import 'screens/cards_v3.dart';
import 'screens/chat_list_v3.dart';
import 'screens/detected_v3.dart';
import 'screens/family_v3.dart';
import 'screens/home_v3.dart';
import 'screens/insights_v3.dart';
import 'screens/monthly_recap_v3.dart';
import 'screens/notes_v3.dart';
import 'screens/notifications_v3.dart';
import 'data/prayer/prayer_platform_io.dart'
    if (dart.library.js_interop) 'data/prayer/prayer_platform_web.dart'
    as prayer_platform;
import 'screens/onboarding_v3.dart';
import 'screens/prayer_alert_v3.dart';
import 'screens/prayer_settings_v3.dart';
import 'screens/prayer_v3.dart';
import 'screens/settings_v3.dart';
import 'sheets/update_sheet_v3.dart';
import 'sheets/v3_sheets.dart';
import 'v3_nav.dart';
import 'v3_state.dart';
import 'widgets/v3_motion.dart';

/// Entry point for the v3 shell.
class V3App extends StatelessWidget {
  const V3App({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool _prayerAlertsWired = false;
  static KpThemeId? _builtTheme;

  /// Widgets read [Nocturne.palette] statically, so const subtrees would keep
  /// the old colours; force every element to rebuild once after a switch.
  static void _repaintAll(Element root) {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
  }

  static void _showPrayerAlert(String slot) =>
      navigatorKey.currentState?.push(PrayerAlertV3.route(slot));

  @override
  Widget build(BuildContext context) {
    final db = Supabase.instance.client;
    final repo = V3Repository(db);
    if (!_prayerAlertsWired) {
      _prayerAlertsWired = true;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => prayer_platform.listenForPrayerAlerts(_showPrayerAlert));
    }
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
        ChangeNotifierProvider(
          create: (ctx) => CallService(db, ctx.read<ChatController>())
            ..present = (session) =>
                navigatorKey.currentState?.push(CallScreenV3.route(session)),
        ),
        // Loads its own device-local config. Builds nothing and runs no timer
        // until the feature is switched on.
        ChangeNotifierProvider(create: (_) => PrayerController()..load()),
        ChangeNotifierProvider.value(value: ThemeController.instance..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeCtrl, _) {
          final id = themeCtrl.themeId;
          if (_builtTheme != null && _builtTheme != id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _repaintAll(context as Element);
            });
          }
          _builtTheme = id;
          return MaterialApp(
          title: 'KinPurse',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: getV3Theme(themeCtrl.palette),
          home: const V3Root(),
        );
        },
      ),
    );
  }
}

ThemeData get v3Theme => getV3Theme(ThemeController.instance.palette);

ThemeData getV3Theme(NocturnePalette p) => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: p.bg,
      fontFamily: Nocturne.fontFamily,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: p.isDark
          ? ColorScheme.dark(
              surface: p.surface,
              primary: p.accent,
              onPrimary: p.bg,
              onSurface: p.text,
            )
          : ColorScheme.light(
              surface: p.surface,
              primary: p.accent,
              onPrimary: Colors.white,
              onSurface: p.text,
            ),
      textTheme: const TextTheme().apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.edge,
        contentTextStyle: TextStyle(color: p.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );

/// Decides between loading, onboarding and the tab shell.
class V3Root extends StatelessWidget {
  const V3Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    // Nothing below can run without a session: the repository dereferences
    // currentUserId, and RLS would refuse every query anyway.
    if (Supabase.instance.client.auth.currentUser == null) {
      return AuthV3(onSignedIn: s.bootstrap);
    }

    if (s.loading && s.family == null) {
      return Scaffold(
        backgroundColor: Nocturne.palette.bg,
        body: Center(child: CircularProgressIndicator(color: Nocturne.palette.accentMuted)),
      );
    }

    if (s.loadError != null && s.family == null) {
      return Scaffold(
        backgroundColor: Nocturne.palette.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhRegular.warning,
                    size: 36, color: Nocturne.palette.muted),
                const SizedBox(height: 12),
                Text(s.loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Nocturne.palette.neutral300)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: s.bootstrap,
                  child: Text('Try again',
                      style: TextStyle(color: Nocturne.palette.accentMuted)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (s.family == null) return const OnboardingV3();

    return const V3Shell();
  }
}

class V3Shell extends StatefulWidget {
  const V3Shell({super.key});

  @override
  State<V3Shell> createState() => _V3ShellState();
}

class _V3ShellState extends State<V3Shell> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_unlocked && !_authenticating) {
      _checkBiometricAuth();
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    ThemeController.instance.updatePlatformBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  Future<void> _checkBiometricAuth() async {
    final s = context.read<V3State>();
    final lockEnabled = s.prefs.lockApp;

    if (!lockEnabled) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }

    if (kIsWeb) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }

    setState(() => _authenticating = true);
    final ok = await BiometricService.authenticate();
    if (mounted) {
      setState(() {
        _authenticating = false;
        _unlocked = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<V3Nav>();
    final s = context.watch<V3State>();
    final chat = context.read<ChatController?>();
    final calls = context.read<CallService?>();
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;

    if (!_unlocked && s.prefs.lockApp && !kIsWeb) {
      return Scaffold(
        backgroundColor: palette.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.switchOn, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: palette.glow,
                        blurRadius: 36,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    PhBold.lock,
                    size: 36,
                    color: palette.accentMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'KinPurse is locked',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock with fingerprint or device screen lock',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: palette.subtle),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _checkBiometricAuth,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.accent, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhRegular.lockKey,
                            size: 18, color: palette.accentLight),
                        const SizedBox(width: 8),
                        Text(
                          'Unlock',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chat != null && s.family != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chat.syncContext(
          familyId: s.familyId,
          myId: s.myId,
          members: s.members,
          onTapSender: (senderId) => nav.openChat(senderId),
        );
        // Incoming calls ring while the app is open.
        calls?.bind(familyId: s.familyId, myId: s.myId);
      });
    }

    WidgetsBinding.instance
        .addPostFrameCallback((_) => UpdateSheetV3.checkOnLaunch(context));

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          palette.isDark ? Brightness.light : Brightness.dark,
    ));

    return _SharedBillListener(
      child: PopScope(
      canPop: !nav.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          nav.handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: nav.tab,
                children: const [
                  HomeV3(),
                  ActivityV3(),
                  InsightsV3(),
                  FamilyV3(),
                ],
              ),
            ),
            if (nav.page != null)
              Positioned.fill(child: _PageOverlay(page: nav.page!)),
            const _OfflineBanner(),
          ],
        ),
        bottomNavigationBar: const _V3BottomBar(),
      ),
    ),
    );
  }
}

/// Opens a pre-filled expense when a payment screenshot is shared into the
/// app. Checked on launch and on resume, which is when a share arrives.
class _SharedBillListener extends StatefulWidget {
  final Widget child;
  const _SharedBillListener({required this.child});

  @override
  State<_SharedBillListener> createState() => _SharedBillListenerState();
}

class _SharedBillListenerState extends State<_SharedBillListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    // Load the text reader now so a receipt shared later reads instantly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(warmUpTextReader());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final s = context.read<V3State>();
    final messenger = ScaffoldMessenger.of(context);
    final shared = await consumeSharedBill(
      categories: [
        for (final kind in const ['expense', 'income'])
          for (final c in s.topCategories(kind))
            (key: c.key, name: c.name, income: kind == 'income'),
      ],
      onStatus: (msg) {
        if (!mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 20), content: Text(msg)));
      },
    );
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (shared != null) {
      final bill = shared.bill;
      if (bill.amount == null && bill.payee == null && shared.refined == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't read a payment from that image. "
                'Fill in the details below.')));
      }
      await V3Sheets.openAdd(context, prefill: bill, refine: shared.refined);
    }

    // Keep home-screen widget updated with today's spend & next prayer time
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && mounted) {
      try {
        final prayerCtrl = context.read<PrayerController?>();
        final nextP = prayerCtrl?.next;
        final prayerName = nextP?.next.label ?? 'Prayer';
        final prayerTime = nextP != null
            ? '${nextP.next.time.hour.toString().padLeft(2, '0')}:${nextP.next.time.minute.toString().padLeft(2, '0')}'
            : '--:--';
        await KinPurseWidgetService.updateWidget(
          todaySpent: V3Design.inr(s.todaySpent),
          prayerName: prayerName,
          prayerTime: prayerTime,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PageOverlay extends StatelessWidget {
  final V3Page page;
  const _PageOverlay({required this.page});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<V3Nav>();
    final hideOuterBar =
        (page == V3Page.chat && nav.chatPartnerId != null) ||
            page == V3Page.settings;

    // The design slides pages in over the tab content rather than pushing a
    // route: `animation:ftIn .24s cubic-bezier(.2,.8,.2,1)`.
    return TweenAnimationBuilder<double>(
      key: ValueKey(page),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: const Cubic(.2, .8, .2, 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset(28 * (1 - t), 0), child: child),
      ),
      child: Builder(builder: (context) {
        final palette =
            context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
        return ColoredBox(
          color: palette.bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (!hideOuterBar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: nav.closePage,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(PhRegular.arrowLeft,
                                size: 22, color: palette.text),
                          ),
                        ),
                        Expanded(
                          child: Text(nav.titleFor(page),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: palette.text)),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _pageBody(page)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _pageBody(V3Page p) => switch (p) {
        V3Page.detected => const DetectedV3(),
        V3Page.cards => const CardsV3(),
        V3Page.notifications => const NotificationsV3(),
        V3Page.settings => const SettingsV3(),
        V3Page.notes => const NotesV3(),
        V3Page.prayer => const PrayerV3(),
        V3Page.prayerSettings => const PrayerSettingsV3(),
        V3Page.aiSettings => const AiSettingsV3(),
        V3Page.chat => const ChatListV3(),
        V3Page.askKinPurse => const AskKinPurseScreen(),
        V3Page.monthlyRecap => const MonthlyRecapScreen(),
      };
}

class _V3BottomBar extends StatelessWidget {
  const _V3BottomBar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<V3Nav>();
    final unreadDm = context.watch<ChatController?>()?.totalUnread ?? 0;
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    const items = [
      (PhRegular.house, 'Home'),
      (PhRegular.listBullets, 'Activity'),
      (PhRegular.chartDonut, 'Insights'),
      // The tab holds the member list and settings, so "Family" both repeated
      // the section heading inside it and undersold what it contains.
      (PhRegular.dotsThree, 'More'),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(top: BorderSide(color: palette.line, width: 1)),
      ),
      // The row must be height-bounded. _AddButton centres its button, and an
      // unbounded Center inside a Row's Expanded grows to the full available
      // cross-axis height — which let the bar claim the whole screen and left
      // the Scaffold body with h=0, rendering Home blank.
      child: SizedBox(
        height: 58,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _tab(nav, items[0], 0, palette),
            _tab(nav, items[1], 1, palette),
            const _AddButton(),
            _tab(nav, items[2], 2, palette),
            _tab(nav, items[3], 3, palette, badgeCount: unreadDm),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    V3Nav nav,
    (IconData, String) item,
    int i,
    NocturnePalette palette, {
    int badgeCount = 0,
  }) {
    final active = nav.tab == i && nav.page == null;
    return Expanded(
      child: GestureDetector(
        onTap: () => nav.goTab(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.$1,
                    size: 22,
                    color: active ? palette.accent : palette.muted),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.bg, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.$2,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? palette.accent : palette.muted)),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return Expanded(
      child: Center(
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.heavyImpact();
            V3Sheets.openVoiceAdd(context);
          },
          child: V3Press(
            onTap: () => V3Sheets.openAdd(context),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.fab,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.fabEdge, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: palette.glow, blurRadius: 22),
                ],
              ),
              child: Icon(PhBold.plus, size: 24, color: palette.fabIcon),
            ),
          ),
        ),
      ),
    );
  }
}


/// Says why a save did not go through, instead of leaving taps looking dead.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: V3Repository.offline,
        builder: (context, offline, _) => !offline
            ? const SizedBox.shrink()
            : Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).padding.top + 4,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      key: const ValueKey('offline_banner'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Nocturne.palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Nocturne.palette.faint),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhRegular.wifiHigh,
                              size: 14, color: Nocturne.palette.subtle),
                          SizedBox(width: 6),
                          Text("You're offline — changes can't be saved right now",
                              style: TextStyle(
                                  fontSize: 12, color: Nocturne.palette.neutral300)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
}

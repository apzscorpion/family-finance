import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/nocturne.dart';
import 'data/chat_controller.dart';
import 'data/notes_presence.dart';
import 'data/prayer/prayer_controller.dart';
import 'data/v3_repository.dart';
import 'phosphor_icons.dart';
import 'screens/activity_v3.dart';
import 'screens/ai_settings_v3.dart';
import 'screens/auth_v3.dart';
import 'screens/cards_v3.dart';
import 'screens/chat_list_v3.dart';
import 'screens/detected_v3.dart';
import 'screens/family_v3.dart';
import 'screens/home_v3.dart';
import 'screens/insights_v3.dart';
import 'screens/notes_v3.dart';
import 'screens/notifications_v3.dart';
import 'screens/onboarding_v3.dart';
import 'screens/prayer_settings_v3.dart';
import 'screens/prayer_v3.dart';
import 'screens/settings_v3.dart';
import 'sheets/v3_sheets.dart';
import 'v3_nav.dart';
import 'v3_state.dart';
import 'widgets/v3_motion.dart';

/// Entry point for the v3 shell.
class V3App extends StatelessWidget {
  const V3App({super.key});

  @override
  Widget build(BuildContext context) {
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
        // Loads its own device-local config. Builds nothing and runs no timer
        // until the feature is switched on.
        ChangeNotifierProvider(create: (_) => PrayerController()..load()),
      ],
      child: MaterialApp(
        title: 'Family Spend Tracker',
        debugShowCheckedModeBanner: false,
        theme: v3Theme,
        home: const V3Root(),
      ),
    );
  }
}

ThemeData get v3Theme => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Nocturne.bg,
      fontFamily: Nocturne.fontFamily,
      colorScheme: const ColorScheme.dark(
        surface: Nocturne.surface,
        primary: Nocturne.accent,
        onPrimary: Nocturne.bg,
        onSurface: Nocturne.text,
      ),
      textTheme: const TextTheme().apply(
        bodyColor: Nocturne.text,
        displayColor: Nocturne.text,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Nocturne.neutral800,
        contentTextStyle: TextStyle(color: Nocturne.text, fontSize: 13),
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
      return const Scaffold(
        backgroundColor: Nocturne.bg,
        body: Center(child: CircularProgressIndicator(color: Nocturne.accent300)),
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
                const Icon(PhRegular.warning,
                    size: 36, color: Nocturne.neutral500),
                const SizedBox(height: 12),
                Text(s.loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: Nocturne.neutral300)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: s.bootstrap,
                  child: const Text('Try again',
                      style: TextStyle(color: Nocturne.accent300)),
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

class V3Shell extends StatelessWidget {
  const V3Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<V3Nav>();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: !nav.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          nav.handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Nocturne.bg,
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
          ],
        ),
        bottomNavigationBar: const _V3BottomBar(),
      ),
    );
  }
}

class _PageOverlay extends StatelessWidget {
  final V3Page page;
  const _PageOverlay({required this.page});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<V3Nav>();

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
      child: ColoredBox(
        color: Nocturne.bg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: nav.closePage,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(PhRegular.arrowLeft,
                            size: 22, color: Nocturne.text),
                      ),
                    ),
                    Expanded(
                      child: Text(nav.titleFor(page),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text)),
                    ),
                  ],
                ),
              ),
              Expanded(child: _pageBody(page)),
            ],
          ),
        ),
      ),
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
      };
}

class _V3BottomBar extends StatelessWidget {
  const _V3BottomBar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<V3Nav>();
    final unreadDm = context.watch<ChatController?>()?.totalUnread ?? 0;
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
      decoration: const BoxDecoration(
        color: Nocturne.bg,
        border: Border(top: BorderSide(color: Nocturne.neutral900, width: 1)),
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
            _tab(nav, items[0], 0),
            _tab(nav, items[1], 1),
            const _AddButton(),
            _tab(nav, items[2], 2),
            _tab(nav, items[3], 3, badgeCount: unreadDm),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    V3Nav nav,
    (IconData, String) item,
    int i, {
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
                    color: active ? Nocturne.accent300 : Nocturne.neutral600),
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
                        color: Nocturne.accent600,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Nocturne.bg, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
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
            const SizedBox(height: 4),
            Text(item.$2,
                style: TextStyle(
                    fontSize: 11,
                    color: active ? Nocturne.accent200 : Nocturne.neutral600)),
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
    return Expanded(
      child: Center(
        child: V3Press(
          onTap: () => V3Sheets.openAdd(context),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Nocturne.accent700,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Nocturne.accent400, width: 1),
              boxShadow: [
                BoxShadow(
                    color: Nocturne.mix(Nocturne.accent, 45), blurRadius: 22),
              ],
            ),
            child: const Icon(PhBold.plus, size: 24, color: Nocturne.accent100),
          ),
        ),
      ),
    );
  }
}

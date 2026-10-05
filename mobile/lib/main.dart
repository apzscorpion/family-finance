import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/finance_provider.dart';
import 'screens/home_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/family_screen.dart';
import 'screens/sms_inbox_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifs_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/auth_screen.dart';
import 'services/supabase_service.dart';
import 'widgets/quick_add_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Deliberately not awaited: Supabase.initialize() performs network I/O, and
  // blocking runApp() on it delayed the first frame by ~14s on a cold start
  // (and produced an ANR when the network was slow). Anything that needs the
  // client awaits SupabaseService.ready instead.
  SupabaseService.ready;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => FinanceProvider(),
      child: const FamilyFinanceApp(),
    ),
  );
}

class FamilyFinanceApp extends StatelessWidget {
  const FamilyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    if (!provider.isLoggedIn) {
      return const AuthScreen();
    }

    Widget activeBody;
    switch (provider.activeTab) {
      case 0:
        activeBody = const HomeScreen();
        break;
      case 1:
        activeBody = const ActivityScreen();
        break;
      case 2:
        activeBody = const InsightsScreen();
        break;
      case 3:
        activeBody = const FamilyScreen();
        break;
      default:
        activeBody = const HomeScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.bgRadial,
            ),
          ),

          // Main App Content Container
          SafeArea(
            bottom: false,
            child: activeBody,
          ),

          // Sub-page Overlays (SMS Inbox, Settings, Notifications)
          if (provider.subPage != null)
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildSubPageWidget(provider.subPage!),
              ),
            ),

          // Toast Banner Overlay
          if (provider.toastMessage != null)
            Positioned(
              left: 18,
              right: 18,
              bottom: 100,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F424D),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [AppTheme.shadowMd],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.toastMessage!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // Let Scaffold reserve space for navigation. Keeping this bar in the
      // body Stack made every page render underneath it on shorter phones.
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomBar(context, provider),
      ),
    );
  }

  Widget _buildSubPageWidget(String pageName) {
    switch (pageName) {
      case 'sms':
      case 'sms_inbox':
        return const SmsInboxScreen();
      case 'settings':
        return const SettingsScreen();
      case 'notifs':
        return const NotifsScreen();
      case 'notes':
        return const NotesScreen();
      case 'cards':
        return const CardsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar(BuildContext context, FinanceProvider provider) {
    return Container(
      height: 84,
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg.withOpacity(0.88),
        border: const Border(top: BorderSide(color: Color(0xFF292B31), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(provider, index: 0, label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
          _buildNavItem(provider, index: 1, label: 'Activity', icon: Icons.format_list_bulleted_outlined, activeIcon: Icons.format_list_bulleted),

          // Center Blurple Plus FAB Button
          GestureDetector(
            onTap: () => QuickAddSheet.show(context, type: 'expense'),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.accent600, AppTheme.accent800],
                ),
                border: Border.all(color: AppTheme.accent400, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 28, color: AppTheme.accent100),
            ),
          ),

          _buildNavItem(provider, index: 2, label: 'Insights', icon: Icons.donut_large_outlined, activeIcon: Icons.donut_large),
          _buildNavItem(provider, index: 3, label: 'Family', icon: Icons.people_outline, activeIcon: Icons.people),
        ],
      ),
    );
  }

  Widget _buildNavItem(FinanceProvider provider, {required int index, required String label, required IconData icon, required IconData activeIcon}) {
    final isSelected = provider.activeTab == index;
    return GestureDetector(
      onTap: () => provider.setTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 23,
              color: isSelected ? AppTheme.accent300 : AppTheme.textSubtle,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? AppTheme.accent300 : AppTheme.textSubtle,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import '../../services/update_service.dart';
import '../../theme/nocturne_palette.dart';
import '../data/data_export.dart';
import '../data/prayer/prayer_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/update_sheet_v3.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import 'categories_manager_v3.dart';
import 'import_v3.dart';
import 'sources_manager_v3.dart';

enum _SettingsSubscreen {
  hub,
  appearance,
  notif,
  display,
  detected,
}

/// Redesigned KinPurse Settings Experience.
///
/// Implements the exact handoff specifications from `KinPurse Final.dc.html`:
/// - Interactive Hub with real-time settings search
/// - Profile card with edit name trigger
/// - 4 Quick-action switch tiles (App lock, Hide amounts, Read payments, Prayer times)
/// - 6 structured groups (General, Workspace, Automation, Data, About, Account)
/// - Dedicated drill-in subpages:
///   1. Appearance (6 themes with live preview mockups, Match device, Reduce motion)
///   2. Notifications (Budget alerts, Family activity, Approvals, Daily digest, 70/80/90% threshold)
///   3. Home & charts (Donut vs Bars selector, Spent vs Balance headline preview)
///   4. Detected payments (Master switch, Category guessing, Review-first, Promo skipping, Privacy callout)
/// - Preserves every single existing feature, dialog, export, and functionality.
class SettingsV3 extends StatefulWidget {
  const SettingsV3({super.key});

  @override
  State<SettingsV3> createState() => _SettingsV3State();
}

class _SettingsV3State extends State<SettingsV3> {
  _SettingsSubscreen _subscreen = _SettingsSubscreen.hub;
  final TextEditingController _searchCtrl = TextEditingController();
  String _sq = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<V3Nav>().registerBackHandler(_handleBack);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    try {
      context.read<V3Nav>().unregisterBackHandler(_handleBack);
    } catch (_) {}
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _sq = _searchCtrl.text.trim().toLowerCase();
    });
  }

  bool _handleBack() {
    if (_subscreen != _SettingsSubscreen.hub) {
      setState(() {
        _subscreen = _SettingsSubscreen.hub;
      });
      return true;
    }
    return false;
  }

  void _goToSubscreen(_SettingsSubscreen target) {
    setState(() {
      _subscreen = target;
      _searchCtrl.clear();
      _sq = '';
    });
  }

  void _goBack() {
    if (_subscreen != _SettingsSubscreen.hub) {
      setState(() {
        _subscreen = _SettingsSubscreen.hub;
      });
    } else {
      context.read<V3Nav>().closePage();
    }
  }

  String _titleForSubscreen(_SettingsSubscreen s) {
    switch (s) {
      case _SettingsSubscreen.hub:
        return 'Settings';
      case _SettingsSubscreen.appearance:
        return 'Appearance';
      case _SettingsSubscreen.notif:
        return 'Notifications';
      case _SettingsSubscreen.display:
        return 'Home & charts';
      case _SettingsSubscreen.detected:
        return 'Detected payments';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final themeCtrl = context.watch<ThemeController>();
    final palette = themeCtrl.palette;
    final nav = context.watch<V3Nav>();

    return Column(
      children: [
        // Top Navigation Header
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
          color: palette.bg,
          child: Row(
            children: [
              GestureDetector(
                onTap: _goBack,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Icon(PhRegular.arrowLeft,
                        size: 22, color: palette.text),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _titleForSubscreen(_subscreen),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildSubscreenContent(context, s, themeCtrl, palette, nav),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscreenContent(
    BuildContext context,
    V3State s,
    ThemeController themeCtrl,
    NocturnePalette palette,
    V3Nav nav,
  ) {
    switch (_subscreen) {
      case _SettingsSubscreen.hub:
        return _buildHub(context, s, themeCtrl, palette, nav);
      case _SettingsSubscreen.appearance:
        return _buildAppearance(context, themeCtrl, palette);
      case _SettingsSubscreen.notif:
        return _buildNotifications(context, s, palette);
      case _SettingsSubscreen.display:
        return _buildDisplay(context, s, palette);
      case _SettingsSubscreen.detected:
        return _buildDetected(context, s, palette);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. SETTINGS HUB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHub(
    BuildContext context,
    V3State s,
    ThemeController themeCtrl,
    NocturnePalette palette,
    V3Nav nav,
  ) {
    final p = s.prefs;
    final me = s.me;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final prayerCtrl = context.watch<PrayerController>();

    final notifOnCount = [
      p.budgetAlerts,
      p.familyAlerts,
      p.approvalAlerts,
      p.dailyDigest,
    ].where((x) => x).length;

    // Define all hub items with search keywords
    final groups = <_SettingsGroup>[
      _SettingsGroup(
        title: 'General',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.palette,
            label: 'Appearance',
            value: themeCtrl.palette.name,
            keywords: 'theme dark light blue maroon golden yellow colour color',
            onTap: () => _goToSubscreen(_SettingsSubscreen.appearance),
          ),
          _SettingsRowDef(
            icon: PhRegular.bell,
            label: 'Notifications',
            value: '$notifOnCount of 4 on',
            keywords: 'alerts budget digest approvals threshold notify',
            onTap: () => _goToSubscreen(_SettingsSubscreen.notif),
          ),
          _SettingsRowDef(
            icon: PhRegular.chartDonut,
            label: 'Home & charts',
            value:
                '${p.chartStyle == 'donut' ? 'Donut' : 'Bars'} · ${p.heroMetric == 'spent' ? 'Spent' : 'Balance'}',
            keywords: 'display headline chart donut bars spend balance hero',
            onTap: () => _goToSubscreen(_SettingsSubscreen.display),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Workspace',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.wallet,
            label: 'Money sources',
            value: '${s.manageableSources.length}',
            keywords: 'accounts bank cash wallet money sources',
            onTap: () => SourcesManagerV3.open(context),
          ),
          _SettingsRowDef(
            icon: PhRegular.users,
            label: 'Joint accounts',
            value: '',
            badge: 'Coming soon',
            keywords: 'joint shared account together',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Joint accounts are coming soon: one account shared by two or more people.'))),
          ),
          _SettingsRowDef(
            icon: PhRegular.listBullets,
            label: 'Categories',
            value: '${s.categories.length}',
            keywords: 'categories tags manage',
            onTap: () => CategoriesManagerV3.open(context),
          ),
          _SettingsRowDef(
            icon: PhRegular.arrowsClockwise,
            label: 'Recurring rules',
            value: '${s.recurring.length}',
            keywords: 'recurring subscriptions bills rules repeat',
            onTap: () => V3Sheets.openRecurring(context),
          ),
          _SettingsRowDef(
            icon: PhRegular.houseLine,
            label: 'Workspace name',
            value: s.family?.name ?? 'Family',
            keywords: 'rename family workspace household',
            onTap: () => _showRenameFamilyDialog(context, s),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Automation',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.bellSimpleRinging,
            label: 'Detected payments',
            value: p.smsAuto
                ? (p.smsReview ? 'Review first' : 'Auto-add')
                : 'Off',
            keywords: 'sms notification bank parse auto detected payments',
            onTap: () => _goToSubscreen(_SettingsSubscreen.detected),
          ),
          _SettingsRowDef(
            icon: PhRegular.sparkle,
            label: 'AI restructuring',
            value: '',
            keywords: 'magic ai restructuring clean parse gemini',
            onTap: () => nav.goPage(V3Page.aiSettings),
          ),
          _SettingsRowDef(
            icon: PhRegular.mosque,
            label: 'Prayer times',
            value: prayerCtrl.enabled ? 'On' : 'Off',
            keywords: 'salah namaz prayer times azan islamic faith',
            onTap: () => nav.goPage(V3Page.prayerSettings),
          ),
          _SettingsRowDef(
            icon: PhRegular.currencyInr,
            label: 'UPI ID',
            value: me?.upiId != null && me!.upiId!.isNotEmpty
                ? me.upiId!
                : 'Set up',
            keywords: 'gpay phonepe paytm settle upi vpa payments',
            onTap: () => _showUpiIdDialog(context, s),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Data',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.downloadSimple,
            label: 'Import expenses',
            value: 'CSV · Excel · MD',
            keywords: 'import xlsx csv excel markdown backup',
            onTap: () => ImportV3.open(context),
          ),
          _SettingsRowDef(
            icon: PhRegular.shareNetwork,
            label: 'Export',
            value: 'CSV · Markdown',
            keywords: 'export csv markdown notes transactions backup share',
            onTap: () => _showExportSheet(context, s),
          ),
          _SettingsRowDef(
            icon: PhRegular.database,
            label: 'Imported data',
            value: '${s.importedTxns.length} entries',
            keywords: 'delete imported data remove batch',
            danger: s.importedTxns.isNotEmpty,
            onTap: () {
              if (s.importedTxns.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No imported transactions to manage'),
                  ),
                );
                return;
              }
              ImportV3.openManageImported(context);
            },
          ),
          _SettingsRowDef(
            icon: PhRegular.arrowsClockwise,
            label: 'Refresh workspace',
            value: 'Sync',
            keywords: 'refresh sync reload workspace update',
            onTap: () async {
              await s.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workspace refreshed')),
                );
              }
            },
          ),
        ],
      ),
      _SettingsGroup(
        title: 'About',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.appUpdates,
            label: 'App updates',
            value: 'v${UpdateService.currentVersion}',
            badge: 'Latest',
            keywords: 'version release updates github check upgrade',
            onTap: () => UpdateSheetV3.check(context),
          ),
          _SettingsRowDef(
            icon: PhRegular.chatCircleText,
            label: 'Support & feedback',
            value: 'Logs attached',
            keywords: 'bug error report developer support feedback contact',
            onTap: () => _showDeveloperSupport(context),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'Account',
        rows: [
          _SettingsRowDef(
            icon: PhRegular.signOut,
            label: 'Sign out',
            value: '',
            danger: true,
            keywords: 'sign out logout exit session',
            onTap: () => _confirmSignOut(context, s),
          ),
          _SettingsRowDef(
            icon: PhRegular.trash,
            label: 'Delete account',
            value: '',
            danger: true,
            keywords: 'delete account terminate remove user',
            onTap: () => _showDeleteAccountDialog(context, s),
          ),
        ],
      ),
    ];

    // Filter groups when search text is active
    final filteredGroups = groups.map((g) {
      final matchedRows = g.rows.where((r) {
        if (_sq.isEmpty) return true;
        final hay = '${r.label} ${r.keywords} ${g.title}'.toLowerCase();
        return hay.contains(_sq);
      }).toList();
      return _SettingsGroup(title: g.title, rows: matchedRows);
    }).where((g) => g.rows.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Row(
            children: [
              Icon(PhRegular.magnifyingGlass, size: 16, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontFamily: 'Inter',
                    color: palette.text,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search settings',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      fontFamily: 'Inter',
                      color: palette.muted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_sq.isNotEmpty)
                GestureDetector(
                  onTap: () => _searchCtrl.clear(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(PhRegular.xCircle,
                        size: 16, color: palette.muted),
                  ),
                ),
            ],
          ),
        ),

        // Profile card and Quick Switches (hidden when searching)
        if (_sq.isEmpty) ...[
          // Profile card
          GestureDetector(
            onTap: () => _showEditNameDialog(context, s),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          me?.color ?? palette.accent,
                          V3Design.avatarDeep,
                        ],
                      ),
                    ),
                    child: Text(
                      me?.initial ?? '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE9E9ED),
                      ),
                    ),
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
                                me?.name ?? 'You',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: palette.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.tint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _capitalize(me?.role ?? 'Owner'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: palette.accentLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            s.family?.name ?? '',
                            currentUser?.email ?? '',
                          ].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditNameDialog(context, s),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(PhRegular.pencilSimple,
                          size: 15, color: palette.subtle),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick tiles in 2x2 grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    icon: PhRegular.lockKey,
                    label: 'App lock',
                    isOn: p.lockApp,
                    palette: palette,
                    onToggle: () => s.savePrefs(p.copyWith(lockApp: !p.lockApp)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickTile(
                    icon: PhRegular.eyeSlash,
                    label: 'Hide amounts',
                    isOn: p.hideOnOpen,
                    palette: palette,
                    onToggle: () =>
                        s.savePrefs(p.copyWith(hideOnOpen: !p.hideOnOpen)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    icon: PhRegular.bellSimpleRinging,
                    label: 'Read payments',
                    isOn: p.smsAuto,
                    palette: palette,
                    onToggle: () => s.savePrefs(p.copyWith(smsAuto: !p.smsAuto)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickTile(
                    icon: PhRegular.mosque,
                    label: 'Prayer times',
                    isOn: prayerCtrl.enabled,
                    palette: palette,
                    onToggle: () => prayerCtrl.setEnabled(!prayerCtrl.enabled),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Group rows or search empty state
        if (filteredGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Icon(PhRegular.magnifyingGlass,
                    size: 28, color: palette.faint),
                const SizedBox(height: 8),
                Text(
                  'No settings match "$_sq"',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ],
            ),
          )
        else
          for (final g in filteredGroups) ...[
            _Kicker(g.title, palette: palette),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < g.rows.length; i++) ...[
                    _SettingRowWidget(
                      def: g.rows[i],
                      palette: palette,
                    ),
                    if (i < g.rows.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 52,
                        color: palette.line,
                      ),
                  ],
                ],
              ),
            ),
          ],

        if (_sq.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'Detected payments stay in your family workspace. Notification text '
              'never leaves this phone, and SMS are never read.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: palette.muted,
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. APPEARANCE SUB-PAGE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAppearance(
    BuildContext context,
    ThemeController themeCtrl,
    NocturnePalette palette,
  ) {
    const allThemes = [
      NocturnePalette.dark,
      NocturnePalette.light,
      NocturnePalette.blue,
      NocturnePalette.maroon,
      NocturnePalette.golden,
      NocturnePalette.yellow,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Kicker('THEME', palette: palette),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.98,
            children: [
              for (final t in allThemes)
                _ThemeCard(
                  theme: t,
                  isSelected: themeCtrl.themeId == t.id,
                  palette: palette,
                  onTap: () => themeCtrl.setTheme(t.id),
                ),
            ],
          ),
        ),
        _Kicker('BEHAVIOUR', palette: palette),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Match device',
                            style: TextStyle(fontSize: 14, color: palette.text),
                          ),
                          Text(
                            'Switch between Light and Dark with your phone',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Switch(
                      value: themeCtrl.matchDevice,
                      palette: palette,
                      onChanged: (v) => themeCtrl.setMatchDevice(
                        v,
                        MediaQuery.platformBrightnessOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: palette.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reduce motion',
                            style: TextStyle(fontSize: 14, color: palette.text),
                          ),
                          Text(
                            'Skip slide and glow animations',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Switch(
                      value: themeCtrl.reduceMotion,
                      palette: palette,
                      onChanged: (v) => themeCtrl.setReduceMotion(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            'Themes are saved to this phone only — each family member picks their own.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. NOTIFICATIONS SUB-PAGE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildNotifications(
    BuildContext context,
    V3State s,
    NocturnePalette palette,
  ) {
    final p = s.prefs;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Kicker('TELL ME ABOUT', palette: palette),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _NotificationToggleRow(
                icon: PhRegular.chartPieSlice,
                label: 'Budget alerts',
                desc: 'When a category passes its threshold',
                value: p.budgetAlerts,
                palette: palette,
                onChanged: (v) => s.savePrefs(p.copyWith(budgetAlerts: v)),
              ),
              Divider(height: 1, thickness: 1, indent: 44, color: palette.line),
              _NotificationToggleRow(
                icon: PhRegular.users,
                label: 'Family activity',
                desc: 'When someone adds or edits an entry',
                value: p.familyAlerts,
                palette: palette,
                onChanged: (v) => s.savePrefs(p.copyWith(familyAlerts: v)),
              ),
              Divider(height: 1, thickness: 1, indent: 44, color: palette.line),
              _NotificationToggleRow(
                icon: PhRegular.checkCircle,
                label: 'Approvals',
                desc: 'Requests waiting on your decision',
                value: p.approvalAlerts,
                palette: palette,
                onChanged: (v) => s.savePrefs(p.copyWith(approvalAlerts: v)),
              ),
              Divider(height: 1, thickness: 1, indent: 44, color: palette.line),
              _NotificationToggleRow(
                icon: PhRegular.sun,
                label: 'Daily digest',
                desc: 'A short summary each evening',
                value: p.dailyDigest,
                palette: palette,
                onChanged: (v) => s.savePrefs(p.copyWith(dailyDigest: v)),
              ),
            ],
          ),
        ),

        _Kicker('BUDGET THRESHOLD', palette: palette),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: p.budgetAlerts ? 1.0 : 0.45,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Seg(
                  options: const ['70%', '80%', '90%'],
                  selected: switch (p.alertThreshold) {
                    70 => 0,
                    90 => 2,
                    _ => 1,
                  },
                  palette: palette,
                  onChanged: (i) {
                    if (!p.budgetAlerts) return;
                    s.savePrefs(p.copyWith(
                        alertThreshold: switch (i) { 0 => 70, 2 => 90, _ => 80 }));
                  },
                ),
                const SizedBox(height: 14),
                // Visual animated progress bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 250),
                      widthFactor: p.alertThreshold / 100.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You’ll hear about a category once it reaches ${p.alertThreshold}% of its limit.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. HOME & CHARTS (DISPLAY) SUB-PAGE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDisplay(
    BuildContext context,
    V3State s,
    NocturnePalette palette,
  ) {
    final p = s.prefs;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Kicker('SPENDING CHART', palette: palette),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ChartChoiceCard(
                  icon: PhRegular.chartDonut,
                  label: 'Donut',
                  desc: 'Share of each category',
                  isSelected: p.chartStyle == 'donut',
                  palette: palette,
                  onTap: () => s.savePrefs(p.copyWith(chartStyle: 'donut')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChartChoiceCard(
                  icon: PhRegular.chartBar,
                  label: 'Bars',
                  desc: 'Compare amounts side by side',
                  isSelected: p.chartStyle == 'bars',
                  palette: palette,
                  onTap: () => s.savePrefs(p.copyWith(chartStyle: 'bars')),
                ),
              ),
            ],
          ),
        ),

        _Kicker('HEADLINE FIGURE', palette: palette),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Seg(
                options: const ['Spent', 'Balance'],
                selected: p.heroMetric == 'spent' ? 0 : 1,
                palette: palette,
                onChanged: (i) => s.savePrefs(
                    p.copyWith(heroMetric: i == 0 ? 'spent' : 'balance')),
              ),
              const SizedBox(height: 14),
              // Live headline preview box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.heroMetric == 'spent'
                          ? 'Spent this month'
                          : 'Family balance',
                      style: TextStyle(fontSize: 11.5, color: palette.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.heroMetric == 'spent'
                          ? V3Design.inr(s.totalSpent)
                          : V3Design.inr(s.balance),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. DETECTED PAYMENTS SUB-PAGE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDetected(
    BuildContext context,
    V3State s,
    NocturnePalette palette,
  ) {
    final p = s.prefs;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Master switch card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: p.smsAuto ? palette.tintEdge : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhRegular.bellSimpleRinging,
                    size: 20, color: palette.accentLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read payment notifications',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      'Parsed on this phone; SMS is never accessed',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Switch(
                value: p.smsAuto,
                palette: palette,
                onChanged: (v) => s.savePrefs(p.copyWith(smsAuto: v)),
              ),
            ],
          ),
        ),

        _Kicker('WHEN A PAYMENT IS DETECTED', palette: palette),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: p.smsAuto ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !p.smsAuto,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _ToggleRowItem(
                    label: 'Guess the category',
                    desc: 'Pick a likely category from the merchant',
                    value: p.smsCategorize,
                    palette: palette,
                    onChanged: (v) =>
                        s.savePrefs(p.copyWith(smsCategorize: v)),
                  ),
                  Divider(height: 1, thickness: 1, color: palette.line),
                  _ToggleRowItem(
                    label: 'Review before adding',
                    desc: 'Nothing is added without your confirmation',
                    value: p.smsReview,
                    palette: palette,
                    onChanged: (v) => s.savePrefs(p.copyWith(smsReview: v)),
                  ),
                  Divider(height: 1, thickness: 1, color: palette.line),
                  _ToggleRowItem(
                    label: 'Skip promotional messages',
                    desc: 'Ignore offers and marketing alerts',
                    value: p.smsPromo,
                    palette: palette,
                    onChanged: (v) => s.savePrefs(p.copyWith(smsPromo: v)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Privacy info callout
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhRegular.shieldCheck, size: 18, color: palette.income),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Detected payments stay in your family workspace. '
                  'Notification text never leaves this phone, and SMS are never read.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIALOGS & ACTION HANDLERS (PRESERVING 100% EXISTING CODEBASE FEATURES)
  // ════════════════════════════════════════════════════════════════════════════

  static void _showEditNameDialog(BuildContext context, V3State s) {
    final ctrl = TextEditingController(text: s.me?.name ?? '');
    final palette = NocturnePalette.current;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.edge, width: 1),
        ),
        title: Text('Edit Your Name',
            style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: palette.text),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: palette.muted),
            filled: true,
            fillColor: palette.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.tint,
              foregroundColor: palette.accentLight,
              side: BorderSide(color: palette.tintEdge, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                await s.renameMe(val);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void _showUpiIdDialog(BuildContext context, V3State s) {
    final me = s.me;
    final ctrl = TextEditingController(text: me?.upiId ?? '');
    final palette = NocturnePalette.current;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.edge, width: 1),
        ),
        title: Text('Your UPI ID',
            style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family members can settle debts directly to your UPI ID using GPay, PhonePe, or Paytm.',
              style: TextStyle(fontSize: 12.5, color: palette.subtle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: palette.text),
              decoration: InputDecoration(
                hintText: 'e.g. yourname@okhdfcbank',
                hintStyle: TextStyle(color: palette.muted),
                filled: true,
                fillColor: palette.raised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.line),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.tint,
              foregroundColor: palette.accentLight,
              side: BorderSide(color: palette.tintEdge, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              Navigator.pop(ctx);
              await s.setMyUpiId(val);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void _showRenameFamilyDialog(BuildContext context, V3State s) {
    final ctrl = TextEditingController(text: s.family?.name ?? '');
    final palette = NocturnePalette.current;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.edge, width: 1),
        ),
        title: Text('Rename Workspace',
            style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: palette.text),
          decoration: InputDecoration(
            hintText: 'Workspace name',
            hintStyle: TextStyle(color: palette.muted),
            filled: true,
            fillColor: palette.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.tint,
              foregroundColor: palette.accentLight,
              side: BorderSide(color: palette.tintEdge, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                await s.renameFamily(val);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void _confirmSignOut(BuildContext context, V3State s) {
    final palette = NocturnePalette.current;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.edge, width: 1),
        ),
        title: Text('Sign out?',
            style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: Text(
          'You will be returned to the sign-in screen.',
          style: TextStyle(color: palette.subtle, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.expense.withValues(alpha: 0.15),
              foregroundColor: palette.expense,
              side: BorderSide(color: palette.expense, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              await s.bootstrap();
            },
            child: const Text('Sign out',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context, V3State s) {
    final palette = NocturnePalette.current;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.edge, width: 1),
        ),
        title: Text('Delete Account?',
            style: TextStyle(
                color: palette.expense,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete your account. If other members are in your workspace, '
          'the workspace will be preserved and ownership handed on.',
          style: TextStyle(color: palette.subtle, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.expense.withValues(alpha: 0.15),
              foregroundColor: palette.expense,
              side: BorderSide(color: palette.expense, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await s.deleteMyAccount();
            },
            child: const Text('Delete Account',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static void _showExportSheet(BuildContext context, V3State s) {
    final palette = NocturnePalette.current;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export Data',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.text)),
              const SizedBox(height: 6),
              Text(
                'Choose what to export to your device or share sheet.',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhRegular.shareNetwork,
                      size: 18, color: palette.accentLight),
                ),
                title: Text('Export transactions (CSV)',
                    style: TextStyle(fontSize: 14, color: palette.text)),
                subtitle: Text('All recorded transactions in CSV format',
                    style: TextStyle(fontSize: 12, color: palette.muted)),
                trailing: Icon(PhRegular.caretRight,
                    size: 14, color: palette.faint),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final csv = DataExport.transactionsCsv(
                    s.txns,
                    nameOf: s.memberName,
                  );
                  final ok = await DataExport.share(
                    csv,
                    'transactions-${_stamp()}.csv',
                    subject: 'KinPurse transactions',
                  );
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not export the file')));
                  }
                },
              ),
              Divider(height: 1, thickness: 1, color: palette.line),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(PhRegular.note,
                      size: 18, color: palette.accentLight),
                ),
                title: Text('Export notes (Markdown)',
                    style: TextStyle(fontSize: 14, color: palette.text)),
                subtitle: Text('All financial notes & checklists in Markdown',
                    style: TextStyle(fontSize: 12, color: palette.muted)),
                trailing: Icon(PhRegular.caretRight,
                    size: 14, color: palette.faint),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  if (s.notes.isEmpty) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('You have no notes to export')));
                    return;
                  }
                  final ok = await DataExport.share(
                    DataExport.notesMarkdown(s.notes),
                    'notes-${_stamp()}.md',
                    subject: 'KinPurse notes',
                  );
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not export the file')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showDeveloperSupport(BuildContext context) {
    final reportCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final palette = NocturnePalette.current;
    String? screenshot;
    var sending = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> attach() async {
            try {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1280,
                maxHeight: 1280,
                imageQuality: 72,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              setSheet(() => screenshot = base64Encode(bytes));
            } catch (err, stack) {
              AppLog.error('DeveloperSupport.attach', err, stack);
            }
          }

          Future<void> send() async {
            final msg = reportCtrl.text.trim();
            if (msg.isEmpty || sending) return;
            setSheet(() => sending = true);
            try {
              final client = Supabase.instance.client;
              await client.from('support_requests').insert({
                'email': client.auth.currentUser?.email,
                'message': msg,
                'screenshot': screenshot,
                'error_log': AppLog.hasEntries ? AppLog.dump() : null,
                'app_version': UpdateService.currentVersion,
                'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Thanks! Your report was sent.')));
            } catch (err, stack) {
              AppLog.error('DeveloperSupport.send', err, stack);
              setSheet(() => sending = false);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Could not send — check your connection.')));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhRegular.info, color: palette.accentLight, size: 22),
                    const SizedBox(width: 8),
                    Text('Developer Support',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: palette.text)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Describe what went wrong or suggest a feature. '
                  'Recent error logs are attached automatically.',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reportCtrl,
                  maxLines: 4,
                  maxLength: 5000,
                  style: TextStyle(fontSize: 13.5, color: palette.text),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue or feedback...',
                    hintStyle: TextStyle(color: palette.faint),
                    filled: true,
                    fillColor: palette.raised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: screenshot == null
                      ? attach
                      : () => setSheet(() => screenshot = null),
                  icon: Icon(
                    screenshot == null ? PhRegular.image : PhRegular.x,
                    size: 16,
                  ),
                  label: Text(screenshot == null
                      ? 'Attach screenshot'
                      : 'Screenshot attached — remove'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: sending ? null : send,
                    icon: sending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.bg,
                            ),
                          )
                        : const Icon(PhRegular.shareNetwork, size: 16),
                    label: const Text('Send',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES & HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SettingsGroup {
  final String title;
  final List<_SettingsRowDef> rows;
  const _SettingsGroup({required this.title, required this.rows});
}

class _SettingsRowDef {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final String keywords;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsRowDef({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.keywords = '',
    this.danger = false,
    required this.onTap,
  });
}

class _SettingRowWidget extends StatelessWidget {
  final _SettingsRowDef def;
  final NocturnePalette palette;

  const _SettingRowWidget({
    required this.def,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: def.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: def.danger
                    ? palette.expense.withValues(alpha: 0.14)
                    : palette.tint,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(
                def.icon,
                size: 16,
                color: def.danger ? palette.expense : palette.accentLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                def.label,
                style: TextStyle(
                  fontSize: 14,
                  color: def.danger ? palette.expense : palette.text,
                ),
              ),
            ),
            if (def.value.isNotEmpty)
              Text(
                def.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
            if (def.badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.income.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  def.badge!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: palette.income,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(PhRegular.caretRight, size: 14, color: palette.faint),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOn;
  final NocturnePalette palette;
  final VoidCallback onToggle;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.palette,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isOn ? palette.tint : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOn ? palette.tintEdge : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isOn ? palette.accentLight : palette.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    isOn ? 'On' : 'Off',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOn ? palette.accentLight : palette.muted,
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

class _ThemeCard extends StatelessWidget {
  final NocturnePalette theme;
  final bool isSelected;
  final NocturnePalette palette;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature phone screen mockup (84px height)
            Container(
              height: 84,
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.all(9),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top header mockup line
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini card mockup
                      Container(
                        height: 28,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 32,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.text.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Mini FAB in corner
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.fab,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: theme.glow,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Mini dots on bottom left
                  Positioned(
                    left: 0,
                    bottom: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.text.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.text.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Title and selection tick
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 3),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          theme.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? palette.accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? palette.accent : palette.edge,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Icon(PhBold.check, size: 11, color: palette.bg)
                        : null,
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

class _ChartChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool isSelected;
  final NocturnePalette palette;
  final VoidCallback onTap;

  const _ChartChoiceCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? palette.tint : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.tintEdge : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 30,
              color: isSelected ? palette.accentLight : palette.muted,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool value;
  final NocturnePalette palette;
  final ValueChanged<bool> onChanged;

  const _NotificationToggleRow({
    required this.icon,
    required this.label,
    required this.desc,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: palette.tint,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: palette.accentLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 14, color: palette.text)),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: palette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Switch(value: value, palette: palette, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ToggleRowItem extends StatelessWidget {
  final String label;
  final String desc;
  final bool value;
  final NocturnePalette palette;
  final ValueChanged<bool> onChanged;

  const _ToggleRowItem({
    required this.label,
    required this.desc,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 14, color: palette.text)),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: palette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Switch(value: value, palette: palette, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  final String text;
  final NocturnePalette palette;
  const _Kicker(this.text, {required this.palette});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.72,
            fontWeight: FontWeight.w500,
            color: palette.accentMuted,
          ),
        ),
      );
}

/// Nocturne's signature toggle switch (width: 44, height: 26, radius: 13).
class _Switch extends StatelessWidget {
  final bool value;
  final NocturnePalette? palette;
  final ValueChanged<bool> onChanged;

  const _Switch({
    required this.value,
    this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette ?? NocturnePalette.current;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? p.switchOn : p.line,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: value ? p.switchOnEdge : p.edge,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: value ? p.switchKnob : p.faint,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final List<String> options;
  final int selected;
  final NocturnePalette palette;
  final ValueChanged<int> onChanged;

  const _Seg({
    required this.options,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? palette.tint : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == selected
                            ? palette.tintEdge
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            i == selected ? FontWeight.w500 : FontWeight.w400,
                        color: i == selected
                            ? palette.accentLight
                            : palette.subtle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Exposed so other screens can reuse the same switch styling.
typedef V3SettingsSwitch = _Switch;

/// Keeps the import of PrefsRow meaningful to readers of this file.
typedef V3Prefs = PrefsRow;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import 'sources_manager_v3.dart';
import '../widgets/v3_primitives.dart';

/// Settings: the profile card, grouped toggles, display segments and data rows.
/// Every toggle writes straight through to `user_preferences`.
class SettingsV3 extends StatelessWidget {
  const SettingsV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final p = s.prefs;
    final me = s.me;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Profile
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      me?.color ?? Nocturne.accent600,
                      V3Design.avatarDeep,
                    ],
                  ),
                ),
                child: Text(me?.initial ?? '?',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(me?.name ?? 'You',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, color: Nocturne.text)),
                    Text(
                      [
                        _t(me?.role ?? 'member'),
                        s.family?.name ?? '',
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Nocturne.neutral500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const _Kicker('Workspace'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _DataRow(
            icon: PhRegular.wallet,
            label: 'Money sources (${s.sources.length})',
            onTap: () => SourcesManagerV3.open(context),
          ),
        ),

        const _Kicker('Alerts'),
        _ToggleGroup(rows: [
          _ToggleRow(
            label: 'Budget alerts',
            desc: 'Tell me when a category passes its threshold',
            value: p.budgetAlerts,
            onChanged: (v) => s.savePrefs(p.copyWith(budgetAlerts: v)),
          ),
          _ToggleRow(
            label: 'Family activity',
            desc: 'When someone adds or edits an entry',
            value: p.familyAlerts,
            onChanged: (v) => s.savePrefs(p.copyWith(familyAlerts: v)),
          ),
          _ToggleRow(
            label: 'Approvals',
            desc: 'Requests waiting on your decision',
            value: p.approvalAlerts,
            onChanged: (v) => s.savePrefs(p.copyWith(approvalAlerts: v)),
          ),
          _ToggleRow(
            label: 'Daily digest',
            desc: 'A short summary each evening',
            value: p.dailyDigest,
            onChanged: (v) => s.savePrefs(p.copyWith(dailyDigest: v)),
          ),
        ]),

        const _Kicker('Detected payments'),
        _ToggleGroup(rows: [
          _ToggleRow(
            label: 'Read payment notifications',
            desc: 'Parsed on this phone; SMS is never accessed',
            value: p.smsAuto,
            onChanged: (v) => s.savePrefs(p.copyWith(smsAuto: v)),
          ),
          _ToggleRow(
            label: 'Guess the category',
            desc: 'Pick a likely category from the merchant',
            value: p.smsCategorize,
            onChanged: (v) => s.savePrefs(p.copyWith(smsCategorize: v)),
          ),
          _ToggleRow(
            label: 'Review before adding',
            desc: 'Nothing is added without your confirmation',
            value: p.smsReview,
            onChanged: (v) => s.savePrefs(p.copyWith(smsReview: v)),
          ),
          _ToggleRow(
            label: 'Skip promotional messages',
            desc: 'Ignore offers and marketing alerts',
            value: p.smsPromo,
            onChanged: (v) => s.savePrefs(p.copyWith(smsPromo: v)),
          ),
        ]),

        const _Kicker('Privacy'),
        _ToggleGroup(rows: [
          _ToggleRow(
            label: 'Lock the app',
            desc: 'Require device unlock on open',
            value: p.lockApp,
            onChanged: (v) => s.savePrefs(p.copyWith(lockApp: v)),
          ),
          _ToggleRow(
            label: 'Hide amounts on open',
            desc: 'Start with balances masked',
            value: p.hideOnOpen,
            onChanged: (v) => s.savePrefs(p.copyWith(hideOnOpen: v)),
          ),
        ]),

        const _Kicker('Display & alerts'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('Spending chart',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              const SizedBox(height: 8),
              _Seg(
                options: const ['Donut', 'Bars'],
                selected: p.chartStyle == 'donut' ? 0 : 1,
                onChanged: (i) => s.savePrefs(
                    p.copyWith(chartStyle: i == 0 ? 'donut' : 'bars')),
              ),
              const SizedBox(height: 14),
              const Text('Alert me at',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              const SizedBox(height: 8),
              _Seg(
                options: const ['70%', '80%', '90%'],
                selected: switch (p.alertThreshold) {
                  70 => 0,
                  90 => 2,
                  _ => 1,
                },
                onChanged: (i) => s.savePrefs(p.copyWith(
                    alertThreshold: switch (i) { 0 => 70, 2 => 90, _ => 80 })),
              ),
              const SizedBox(height: 14),
              const Text('Headline figure',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              const SizedBox(height: 8),
              _Seg(
                options: const ['Spent', 'Balance'],
                selected: p.heroMetric == 'spent' ? 0 : 1,
                onChanged: (i) => s.savePrefs(
                    p.copyWith(heroMetric: i == 0 ? 'spent' : 'balance')),
              ),
            ],
          ),
        ),

        const _Kicker('Data'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _DataRow(
                icon: PhRegular.arrowsClockwise,
                label: 'Refresh workspace',
                onTap: s.refresh,
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.signOut,
                label: 'Sign out',
                color: NocturneSemantic.expense,
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  await s.bootstrap();
                },
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            'Detected payments stay in your family workspace. Notification text '
            'never leaves this phone, and SMS are never read.',
            style: TextStyle(
                fontSize: 11.5, height: 1.5, color: Nocturne.neutral500),
          ),
        ),
      ],
    );
  }

  static String _t(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.72,
                color: Nocturne.accent300)),
      );
}

class _ToggleRow {
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });
}

class _ToggleGroup extends StatelessWidget {
  final List<_ToggleRow> rows;
  const _ToggleGroup({required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(rows[i].label,
                              style: const TextStyle(
                                  fontSize: 14, color: Nocturne.text)),
                          Text(rows[i].desc,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Nocturne.neutral500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Switch(
                        value: rows[i].value, onChanged: rows[i].onChanged),
                  ],
                ),
              ),
              if (i < rows.length - 1) const V3RowDivider(),
            ],
          ],
        ),
      );
}

/// `width:44px;height:26px;border-radius:13px` with an 18px knob that slides
/// 18px — the design's own toggle, not Material's.
class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Switch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            color: value ? Nocturne.accent700 : Nocturne.neutral900,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: value ? Nocturne.accent500 : Nocturne.neutral800,
                width: 1),
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
                color: value ? Nocturne.accent100 : Nocturne.neutral600,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

class _Seg extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _Seg({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Nocturne.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? Nocturne.accent900
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == selected
                            ? Nocturne.accent600
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(options[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          color: i == selected
                              ? Nocturne.accent100
                              : Nocturne.neutral400,
                        )),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _DataRow({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? Nocturne.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14, color: color ?? Nocturne.text)),
              ),
              const Icon(PhRegular.caretRight,
                  size: 14, color: Nocturne.neutral600),
            ],
          ),
        ),
      );
}

/// Exposed so other screens can reuse the same switch styling.
typedef V3SettingsSwitch = _Switch;

/// Keeps the import of PrefsRow meaningful to readers of this file.
typedef V3Prefs = PrefsRow;

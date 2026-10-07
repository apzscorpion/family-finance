import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_log.dart';
import '../../services/update_service.dart';
import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/prayer/prayer_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/update_sheet_v3.dart';
import 'import_v3.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import 'sources_manager_v3.dart';
import '../sheets/v3_sheets.dart';
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
        GestureDetector(
          onTap: () => _showEditNameDialog(context, s),
          behavior: HitTestBehavior.opaque,
          child: Container(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(me?.name ?? 'You',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, color: Nocturne.text)),
                          ),
                          const SizedBox(width: 6),
                          const Icon(PhRegular.pencilSimple,
                              size: 13, color: Nocturne.neutral500),
                        ],
                      ),
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
        ),

        const _Kicker('Workspace'),
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
                icon: PhRegular.wallet,
                label: 'Money sources (${s.sources.length})',
                onTap: () => SourcesManagerV3.open(context),
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.arrowsClockwise,
                label: 'Recurring rules (${s.recurring.length})',
                onTap: () => V3Sheets.openRecurring(context),
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.pencilSimple,
                label: 'Rename workspace (${s.family?.name ?? 'Family'})',
                onTap: () => _showRenameFamilyDialog(context, s),
              ),
            ],
          ),
        ),

        const _Kicker('Personal'),
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
                icon: PhRegular.mosque,
                label: context.watch<PrayerController>().enabled
                    ? 'Prayer times (on)'
                    : 'Prayer times',
                onTap: () =>
                    context.read<V3Nav>().goPage(V3Page.prayerSettings),
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.sparkle,
                label: 'AI restructuring',
                onTap: () => context.read<V3Nav>().goPage(V3Page.aiSettings),
              ),
            ],
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

        const _Kicker('App Updates'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Nocturne.neutral800, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Version ${UpdateService.currentVersion}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Nocturne.accent900,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Release',
                              style: TextStyle(
                                  fontSize: 10, color: Nocturne.accent200)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Direct GitHub release updates',
                      style: TextStyle(
                          fontSize: 12, color: Nocturne.neutral500),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => UpdateSheetV3.check(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Nocturne.mix(Nocturne.accent, 14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Nocturne.accent, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhRegular.downloadSimple,
                          size: 15, color: Nocturne.accent200),
                      SizedBox(width: 6),
                      Text(
                        'Check now',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.accent200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const _Kicker('Import & Export'),
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
                icon: PhRegular.downloadSimple,
                label: 'Import expenses (CSV, Excel, Markdown)',
                onTap: () => ImportV3.open(context),
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.trash,
                label: s.importedTxns.isEmpty
                    ? 'Delete imported data'
                    : 'Delete imported data (${s.importedTxns.length})',
                color: s.importedTxns.isEmpty
                    ? Nocturne.neutral400
                    : NocturneSemantic.expense,
                onTap: () {
                  if (s.importedTxns.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No imported transactions to delete'),
                      ),
                    );
                    return;
                  }
                  ImportV3.openManageImported(context);
                },
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.shareNetwork,
                label: 'Export transactions (CSV)',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final csv = DataExport.transactionsCsv(
                    s.txns,
                    nameOf: s.memberName,
                  );
                  final ok = await DataExport.share(
                    csv,
                    'transactions-${_stamp()}.csv',
                    subject: 'Family Spend Tracker transactions',
                  );
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not export the file')));
                  }
                },
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.note,
                label: 'Export notes (Markdown)',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (s.notes.isEmpty) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('You have no notes to export')));
                    return;
                  }
                  final ok = await DataExport.share(
                    DataExport.notesMarkdown(s.notes),
                    'notes-${_stamp()}.md',
                    subject: 'Family Spend Tracker notes',
                  );
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not export the file')));
                  }
                },
              ),
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.arrowsClockwise,
                label: 'Refresh workspace',
                onTap: s.refresh,
              ),
            ],
          ),
        ),

        const _Kicker('Support & Account'),
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
                icon: PhRegular.info,
                label: 'Developer support & error log',
                onTap: () => _showDeveloperSupport(context),
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
              const V3RowDivider(),
              _DataRow(
                icon: PhRegular.trash,
                label: 'Delete account',
                color: NocturneSemantic.expense,
                onTap: () => _showDeleteAccountDialog(context, s),
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

  static void _showEditNameDialog(BuildContext context, V3State s) {
    final ctrl = TextEditingController(text: s.me?.name ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Your Name',
            style: TextStyle(
                color: Nocturne.text,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Nocturne.text),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: const TextStyle(color: Nocturne.neutral500),
            filled: true,
            fillColor: Nocturne.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nocturne.accent,
              foregroundColor: Nocturne.bg,
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                await s.renameMe(val);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showRenameFamilyDialog(BuildContext context, V3State s) {
    final ctrl = TextEditingController(text: s.family?.name ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Workspace',
            style: TextStyle(
                color: Nocturne.text,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Nocturne.text),
          decoration: InputDecoration(
            hintText: 'Workspace name',
            hintStyle: const TextStyle(color: Nocturne.neutral500),
            filled: true,
            fillColor: Nocturne.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nocturne.accent,
              foregroundColor: Nocturne.bg,
            ),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                await s.renameFamily(val);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context, V3State s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?',
            style: TextStyle(
                color: NocturneSemantic.expense,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete your account. If other members are in your workspace, '
          'the workspace will be preserved and ownership handed on.',
          style: TextStyle(color: Nocturne.neutral400, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NocturneSemantic.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await s.deleteMyAccount();
            },
            child: const Text('Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showDeveloperSupport(BuildContext context) {
    final reportCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
            const Row(
              children: [
                Icon(PhRegular.info, color: Nocturne.accent200, size: 22),
                SizedBox(width: 8),
                Text('Developer Support',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Nocturne.text)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Describe what went wrong or suggest a feature:',
                style: TextStyle(fontSize: 12.5, color: Nocturne.neutral500)),
            const SizedBox(height: 12),
            TextField(
              controller: reportCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 13.5, color: Nocturne.text),
              decoration: InputDecoration(
                hintText: 'Describe the issue or feedback...',
                hintStyle: const TextStyle(color: Nocturne.neutral600),
                filled: true,
                fillColor: Nocturne.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final msg = reportCtrl.text.trim();
                  Navigator.pop(ctx);
                  final body = StringBuffer()
                    ..writeln(msg.isNotEmpty
                        ? msg
                        : '(no description provided)')
                    ..writeln()
                    ..writeln('---')
                    ..writeln('Recent errors:')
                    ..writeln(
                        AppLog.hasEntries ? AppLog.dump() : '(none captured)');
                  final uri = Uri.parse(
                    'https://github.com/${UpdateService.githubRepo}/issues/new'
                    '?title=${Uri.encodeComponent('App error report')}'
                    '&body=${Uri.encodeComponent(body.toString())}',
                  );
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(PhRegular.shareNetwork, size: 16),
                label: const Text('Send Error Log',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Nocturne.accent,
                  foregroundColor: Nocturne.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dates the export file so successive exports do not overwrite each other
  /// in the receiving app.
  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
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

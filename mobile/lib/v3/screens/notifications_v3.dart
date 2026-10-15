import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../data/v3_models.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import 'family_v3.dart';
import '../widgets/v3_primitives.dart';

/// Notifications, assembled from the things that actually need attention:
/// approvals, unsettled balances, detected payments and budget alerts.
class NotificationsV3 extends StatelessWidget {
  const NotificationsV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final nav = context.read<V3Nav>();

    final items = <_Notif>[
      for (final a in s.approvals)
        _Notif(
          icon: PhRegular.pencilSimple,
          color: Nocturne.palette.warning,
          title: '${_t(a.kind)} request from ${s.memberName(a.requestedBy)}',
          body: a.reason ?? 'Waiting for your decision',
          time: _ago(a.createdAt),
          onTap: () => V3Sheets.openApproval(context, a),
        ),
      for (final t in s.incomeForMe)
        _Notif(
          icon: PhRegular.arrowCircleDown,
          color: Nocturne.palette.income,
          title: '${s.memberName(t.addedBy)} added ${s.money(t.amount)} income for you',
          body: '${t.title.isEmpty ? 'Income' : t.title} · approve it to count it',
          time: '',
          onTap: () => _incomeDialog(context, s, t),
        ),
      for (final t in s.incomeIRejected)
        _Notif(
          icon: PhRegular.arrowCircleDown,
          color: Nocturne.palette.muted,
          title: 'You rejected ${s.money(t.amount)} from ${s.memberName(t.addedBy)}',
          body: '${t.title.isEmpty ? 'Income' : t.title} · you can still approve it',
          time: '',
          onTap: () => _incomeDialog(context, s, t),
        ),
      for (final t in s.incomeISent)
        _Notif(
          icon: PhRegular.arrowCircleDown,
          color: t.status == 'rejected'
              ? Nocturne.palette.expense
              : Nocturne.palette.warning,
          title: t.status == 'rejected'
              ? '${s.memberName(t.userId)} rejected ${s.money(t.amount)} income'
              : 'Waiting for ${s.memberName(t.userId)} to approve ${s.money(t.amount)}',
          body: '${t.title.isEmpty ? 'Income' : t.title}'
              '${t.status == 'rejected' ? ' · tap to send again' : ''}',
          time: '',
          onTap: t.status == 'rejected'
              ? () => _incomeDialog(context, s, t)
              : () {},
        ),
      for (final d in s.myDebts)
        _Notif(
          icon: PhRegular.handCoins,
          color: Nocturne.palette.accentMuted,
          title: d.amount > 0
              ? '${s.memberName(d.userId)} owes you ${s.money(d.amount)}'
              : 'You owe ${s.memberName(d.userId)} ${s.money(-d.amount)}',
          body: 'From split expenses · tap to settle up',
          time: '',
          onTap: () => SharedWithSheet.open(context, d.userId),
        ),
      if (s.detected.isNotEmpty)
        _Notif(
          icon: PhRegular.bellRinging,
          color: const Color(0xFF67B5E1),
          title: '${s.detected.length} detected payment'
              '${s.detected.length == 1 ? '' : 's'} to review',
          body: 'Confirm or ignore them so your totals stay accurate',
          time: '',
          onTap: () => nav.goPage(V3Page.detected),
        ),
      for (final b in s.budgetAlerts)
        _Notif(
          icon: PhRegular.warning,
          color: b.spent > b.limit
              ? Nocturne.palette.expense
              : Nocturne.palette.warning,
          title: b.spent > b.limit
              ? '${b.cat.name} is over budget'
              : '${b.cat.name} is at ${(b.spent * 100 / b.limit).round()}% '
                  'of budget',
          body: '${V3Design.inr(b.spent)} spent of ${V3Design.inr(b.limit)}',
          time: '',
          onTap: () => nav.goTab(2),
        ),
    ];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhRegular.bell, size: 38, color: Nocturne.palette.faint),
              SizedBox(height: 10),
              Text('Nothing needs you',
                  style: TextStyle(fontSize: 15, color: Nocturne.palette.neutral300)),
              SizedBox(height: 4),
              Text('Approvals, settlements and budget alerts show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Nocturne.palette.muted)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      children: [
        for (final n in items)
          GestureDetector(
            onTap: n.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Nocturne.palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Nocturne.palette.line, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  V3IconTile(
                      icon: n.icon, color: n.color, size: 36, radius: 11),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: Nocturne.palette.text)),
                            ),
                            if (n.time.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(n.time,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Nocturne.palette.muted)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: Nocturne.palette.subtle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => nav.goPage(V3Page.settings),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(PhRegular.slidersHorizontal,
                    size: 16, color: Nocturne.palette.accentMuted),
                SizedBox(width: 6),
                Text('Notification settings',
                    style:
                        TextStyle(fontSize: 13, color: Nocturne.palette.accentMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Approve or reject income added for me, or send rejected income again.
  static Future<void> _incomeDialog(
      BuildContext context, V3State s, TxnRow t) async {
    final mine = t.userId == s.myId;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text(
            mine
                ? 'Income from ${s.memberName(t.addedBy)}'
                : 'Send to ${s.memberName(t.userId)} again?',
            style: TextStyle(color: Nocturne.palette.text, fontSize: 17)),
        content: Text(
            '${s.money(t.amount)} · ${t.title.isEmpty ? 'Income' : t.title}\n'
            '${mine ? 'It counts in your balance once you approve it.' : 'They can approve or reject it again.'}',
            style: TextStyle(color: Nocturne.palette.subtle)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Close',
                  style: TextStyle(color: Nocturne.palette.muted))),
          if (mine && t.status == 'pending')
            TextButton(
                onPressed: () => Navigator.pop(c, 'reject'),
                child: Text('Reject',
                    style: TextStyle(color: Nocturne.palette.expense))),
          TextButton(
              onPressed: () => Navigator.pop(c, mine ? 'approve' : 'resend'),
              child: Text(mine ? 'Approve' : 'Send again',
                  style: TextStyle(color: Nocturne.palette.income))),
        ],
      ),
    );
    switch (choice) {
      case 'approve':
        await s.decideIncome(t.id, true);
      case 'reject':
        await s.decideIncome(t.id, false);
      case 'resend':
        await s.resendIncome(t.id);
    }
  }

  static String _t(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _Notif {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final VoidCallback onTap;

  const _Notif({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.onTap,
  });
}

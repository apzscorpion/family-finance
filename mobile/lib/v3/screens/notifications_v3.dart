import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Notifications, assembled from the things that actually need attention:
/// approvals, open settlements, detected payments and budget breaches.
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
          color: NocturneSemantic.warning,
          title: '${_t(a.kind)} request from ${s.memberName(a.requestedBy)}',
          body: a.reason ?? 'Waiting for your decision',
          time: _ago(a.createdAt),
          onTap: () => V3Sheets.openApproval(context, a),
        ),
      for (final d in s.myDebts)
        _Notif(
          icon: PhRegular.handCoins,
          color: Nocturne.accent300,
          title: d.toUser == s.myId
              ? '${s.memberName(d.fromUser)} owes you ${V3Design.inr(d.amount)}'
              : 'You owe ${s.memberName(d.toUser)} ${V3Design.inr(d.amount)}',
          body: d.note ?? 'From a split expense',
          time: '',
          onTap: () => s.settleDebt(d.id),
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
      for (final b in s.budgetRows.where((b) => b.spent > b.limit))
        _Notif(
          icon: PhRegular.warning,
          color: NocturneSemantic.expense,
          title: '${b.cat.name} is over budget',
          body: '${V3Design.inr(b.spent)} spent of ${V3Design.inr(b.limit)}',
          time: '',
          onTap: () => nav.goTab(2),
        ),
    ];

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhRegular.bell, size: 38, color: Nocturne.neutral600),
              SizedBox(height: 10),
              Text('Nothing needs you',
                  style: TextStyle(fontSize: 15, color: Nocturne.neutral300)),
              SizedBox(height: 4),
              Text('Approvals, settlements and budget alerts show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Nocturne.neutral500)),
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
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Nocturne.neutral900, width: 1),
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
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: Nocturne.text)),
                            ),
                            if (n.time.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(n.time,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Nocturne.neutral500)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: Nocturne.neutral400)),
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
            child: const Row(
              children: [
                Icon(PhRegular.slidersHorizontal,
                    size: 16, color: Nocturne.accent300),
                SizedBox(width: 6),
                Text('Notification settings',
                    style:
                        TextStyle(fontSize: 13, color: Nocturne.accent300)),
              ],
            ),
          ),
        ),
      ],
    );
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

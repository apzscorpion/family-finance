import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/upi_service.dart';
import '../../theme/nocturne.dart';
import '../../theme/nocturne_palette.dart';
import '../data/chat_controller.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Family: members with roles and spend, pending approvals, open settlements,
/// and the workspace's invite code.
class FamilyV3 extends StatelessWidget {
  const FamilyV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final chat = context.watch<ChatController?>();
    final unreadTotal = chat?.totalUnread ?? 0;
    final spendByMember = {for (final e in s.byMember) e.key.userId: e.value};

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: palette.accent,
      backgroundColor: palette.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _renameFamilyDialog(context, s),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(s.family?.name ?? 'Family',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: palette.text)),
                            ),
                            const SizedBox(width: 6),
                            Icon(PhRegular.pencilSimple,
                                size: 14, color: palette.muted),
                          ],
                        ),
                      ),
                      Text(
                          '${s.members.where((m) => m.isActive).length} members · '
                          '${s.family?.kind ?? 'Family'}',
                          style: TextStyle(
                              fontSize: 12, color: palette.muted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      context.read<V3Nav>().goPage(V3Page.settings),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: palette.edge, width: 1),
                    ),
                    child: Icon(PhRegular.slidersHorizontal,
                        size: 19, color: palette.subtle),
                  ),
                ),
              ],
            ),
          ),

          // Invite code
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.edge, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Workspace code',
                          style: TextStyle(
                              fontSize: 11, color: palette.muted)),
                      const SizedBox(height: 2),
                      Text(
                        s.family?.inviteCode ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          letterSpacing: 2.8,
                          fontFamily: 'monospace',
                          color: palette.accentLight,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: s.family?.inviteCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: palette.accent, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhRegular.copy,
                            size: 14, color: palette.accent),
                        const SizedBox(width: 6),
                        Text('Copy',
                            style: TextStyle(
                                fontSize: 12.5, color: palette.accentLight)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Direct Messages card
          GestureDetector(
            onTap: () => context.read<V3Nav>().goPage(V3Page.chat),
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unreadTotal > 0 ? palette.accent : palette.edge,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  V3IconTile(
                    icon: PhRegular.chatCircleDots,
                    color: palette.accent,
                    size: 36,
                    radius: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Direct messages',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.palette.text,
                          ),
                        ),
                        Text(
                          unreadTotal > 0
                              ? '$unreadTotal unread message${unreadTotal == 1 ? '' : 's'}'
                              : 'Private 1:1 chats with family members',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: unreadTotal > 0
                                ? Nocturne.palette.accentLight
                                : Nocturne.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadTotal > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Nocturne.palette.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadTotal > 9 ? '9+' : '$unreadTotal',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Nocturne.palette.bg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.palette.faint),
                ],
              ),
            ),
          ),

          if (s.approvals.isNotEmpty) ...[
            const V3SectionHeader(title: 'Approvals'),
            V3Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < s.approvals.length; i++) ...[
                    GestureDetector(
                      onTap: () =>
                          V3Sheets.openApproval(context, s.approvals[i]),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            V3IconTile(
                                icon: PhRegular.pencilSimple,
                                color: Nocturne.palette.warning,
                                size: 36,
                                radius: 11),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      '${s.approvals[i].kind} · '
                                      '${s.memberName(s.approvals[i].requestedBy)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Nocturne.palette.text)),
                                  Text(
                                      s.approvals[i].reason ??
                                          'Tap to review',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Nocturne.palette.muted)),
                                ],
                              ),
                            ),
                            Icon(PhRegular.caretRight,
                                size: 14, color: Nocturne.palette.faint),
                          ],
                        ),
                      ),
                    ),
                    if (i < s.approvals.length - 1) const V3RowDivider(),
                  ],
                ],
              ),
            ),
          ],

          if (s.settlements.isNotEmpty) ...[
            V3SectionHeader(
              title: 'Who owes who',
              actionLabel: 'Split receipt',
              onAction: () => V3Sheets.openReceiptSplitter(context),
            ),
            V3Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < s.settlements.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          V3IconTile(
                              icon: PhRegular.handCoins,
                              color: Nocturne.palette.accentMuted,
                              size: 36,
                              radius: 11),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    '${s.memberName(s.settlements[i].fromUser)} → '
                                    '${s.memberName(s.settlements[i].toUser)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Nocturne.palette.text)),
                                Text(s.settlements[i].note ?? 'Split expense',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Nocturne.palette.muted)),
                              ],
                            ),
                          ),
                          V3Num(V3Design.inr(s.settlements[i].amount),
                              style: TextStyle(
                                  fontSize: 13.5, color: Nocturne.palette.text)),
                          const SizedBox(width: 8),
                          if (s.settlements[i].fromUser == s.myId) ...[
                            Builder(
                              builder: (ctx) {
                                final toMember = s.members.cast<MemberRow?>().firstWhere(
                                      (m) => m?.userId == s.settlements[i].toUser,
                                      orElse: () => null,
                                    );
                                final upi = toMember?.upiId;
                                if (toMember == null || upi == null || upi.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    onTap: () => UpiService.openUpiPayment(
                                      upiId: upi,
                                      payeeName: toMember.name,
                                      amount: s.settlements[i].amount,
                                      note: s.settlements[i].note,
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Nocturne.palette.income.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Nocturne.palette.income, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(PhRegular.lightning,
                                              size: 11, color: Nocturne.palette.income),
                                          SizedBox(width: 3),
                                          Text('UPI',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Nocturne.palette.income)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          GestureDetector(
                            onTap: () => s.settleDebt(s.settlements[i].id),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Nocturne.palette.accentMuted, width: 1),
                              ),
                              child: Text('Settle',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Nocturne.palette.accentMuted)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < s.settlements.length - 1) const V3RowDivider(),
                  ],
                ],
              ),
            ),
          ],

          V3SectionHeader(
            title: 'Members',
            actionLabel: s.isOwner || (s.me?.role == 'admin') ? 'Invite' : null,
            onAction: () => V3Sheets.openInvite(context),
          ),
          V3Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < s.members.length; i++) ...[
                  _MemberRowTile(
                    index: i,
                    spent: spendByMember[s.members[i].userId] ?? 0,
                  ),
                  if (i < s.members.length - 1) const V3RowDivider(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _renameFamilyDialog(BuildContext context, V3State s) {
    final ctrl = TextEditingController(text: s.family?.name ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Workspace',
            style: TextStyle(
                color: Nocturne.palette.text,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: Nocturne.palette.text),
          decoration: InputDecoration(
            hintText: 'Workspace name',
            hintStyle: TextStyle(color: Nocturne.palette.muted),
            filled: true,
            fillColor: Nocturne.palette.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Nocturne.palette.subtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nocturne.palette.accent,
              foregroundColor: Nocturne.palette.bg,
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
}

/// Owner: a member's daily built-in AI limit. Owner or admin: which
/// built-in models they may pick.
Future<void> _aiAccess(BuildContext context, V3State s, MemberRow m) async {
  final info = await s.aiInfo();
  if (!context.mounted) return;
  final models = [
    for (final x in (info?['models'] as List?) ?? const [])
      if (x is Map) (id: '${x['id']}', label: '${x['label']}'),
  ];
  final limit = TextEditingController(text: m.aiDailyLimit?.toString() ?? '');
  final chosen = {...m.aiModels};
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text('AI access · ${m.name}',
            style: TextStyle(color: Nocturne.palette.text, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: limit,
                enabled: s.isOwner,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Nocturne.palette.text),
                decoration: InputDecoration(
                  labelText: 'Requests per day',
                  hintText: 'Default (${info?['limit'] ?? 30})',
                  helperText: s.isOwner
                      ? '0 turns it off. Empty uses the default.'
                      : 'Only an owner changes the limit.',
                ),
              ),
              if (info?['members_used'] is Map)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Used today: ${(info!['members_used'] as Map)[m.userId] ?? 0}',
                      style: TextStyle(
                          fontSize: 12.5, color: Nocturne.palette.subtle)),
                ),
              const SizedBox(height: 12),
              Text('Models they may choose',
                  style: TextStyle(
                      fontSize: 12.5, color: Nocturne.palette.muted)),
              if (models.isEmpty)
                Text('No models available',
                    style: TextStyle(color: Nocturne.palette.faint)),
              for (final x in models)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: chosen.contains(x.id),
                  onChanged: (v) => setLocal(
                      () => v == true ? chosen.add(x.id) : chosen.remove(x.id)),
                  title: Text(x.label,
                      style: TextStyle(color: Nocturne.palette.text)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel',
                  style: TextStyle(color: Nocturne.palette.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Save',
                  style: TextStyle(color: Nocturne.palette.accentMuted))),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final n = int.tryParse(limit.text.trim());
  final saved = await s.setMemberAi(
      m.userId, s.isOwner ? n : m.aiDailyLimit, chosen.toList());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved ? 'AI access saved' : 'Could not save AI access')));
}

class _MemberRowTile extends StatelessWidget {
  final int index;
  final double spent;

  const _MemberRowTile({required this.index, required this.spent});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final m = s.members[index];
    final isMe = m.userId == s.myId;
    // Owners are managed by the primary owner only; the primary by nobody.
    final canManage = (s.isOwner || s.me?.role == 'admin') &&
        !isMe &&
        m.userId != s.family?.ownerId &&
        (m.role != 'owner' || s.isPrimaryOwner);
    final pairBal = s.balanceWith(m.userId);
    final hasDebt = pairBal.abs() >= 0.5;

    return GestureDetector(
      onTap: isMe ? null : () => SharedWithSheet.open(context, m.userId),
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          V3Avatar(
              initial: m.initial,
              color: m.color,
              size: 38,
              fontSize: 14,
              opacity: m.isActive ? 1 : 0.4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(isMe ? '${m.name} (you)' : m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: palette.text)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: palette.isDark ? Nocturne.palette.edge : palette.edge,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(m.userId == s.family?.ownerId ? 'primary owner' : m.role,
                          style: TextStyle(
                              fontSize: 10, color: palette.subtle)),
                    ),
                    if (!m.isActive) ...[
                      const SizedBox(width: 6),
                      Text('disabled',
                          style: TextStyle(
                              fontSize: 10,
                              color: palette.expense)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        [
                          if (m.relationship.isNotEmpty) m.relationship,
                          '${s.moneyShort(spent)} spent',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: palette.muted),
                      ),
                    ),
                    if (!isMe && hasDebt) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: pairBal > 0
                              ? palette.income.withValues(alpha: 0.15)
                              : palette.expense.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: pairBal > 0
                                ? palette.income
                                : palette.expense,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          pairBal > 0
                              ? 'Owes you ${s.moneyShort(pairBal)}'
                              : 'You owe ${s.moneyShort(-pairBal)}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: pairBal > 0
                                ? palette.income
                                : palette.expense,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isMe && m.isActive) ...[
            GestureDetector(
              onTap: () async {
                final chat = context.read<ChatController?>();
                if (chat == null) return;
                chat.syncContext(
                  familyId: s.familyId,
                  myId: s.myId,
                  members: s.members,
                );
                await chat.pokeMember(m.userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('👋 Poked ${m.name}!')),
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhRegular.bellRinging,
                    size: 17, color: palette.warning),
              ),
            ),
            GestureDetector(
              onTap: () => context.read<V3Nav>().openChat(m.userId),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhRegular.chatCircleDots,
                    size: 18, color: palette.accent),
              ),
            ),
          ],
          if (canManage)
            GestureDetector(
              onTap: () => _manage(context, s, index),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(PhRegular.dotsThree,
                    size: 18, color: palette.muted),
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _manage(BuildContext context, V3State s, int i) {
    final m = s.members[i];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Nocturne.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(m.name,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.palette.text)),
            const SizedBox(height: 8),
            for (final role in [
              if (s.isPrimaryOwner) 'owner',
              'admin',
              'member',
              'viewer',
            ])
              ListTile(
                leading: Icon(
                  m.role == role ? PhFill.checkCircle : PhRegular.circle,
                  size: 18,
                  color: m.role == role
                      ? Nocturne.palette.accentMuted
                      : Nocturne.palette.faint,
                ),
                title: Text('Set as $role',
                    style: TextStyle(
                        fontSize: 14, color: Nocturne.palette.text)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await s.setMemberRole(m.userId, role);
                },
              ),
            ListTile(
              leading: Icon(PhRegular.sparkle,
                  size: 18, color: Nocturne.palette.accentMuted),
              title: Text('AI access',
                  style: TextStyle(
                      fontSize: 14, color: Nocturne.palette.text)),
              subtitle: Text(
                  '${m.aiDailyLimit ?? 'Default'} requests a day'
                  '${m.aiModels.isEmpty ? '' : ' · ${m.aiModels.length} models approved'}',
                  style: TextStyle(
                      fontSize: 11.5, color: Nocturne.palette.muted)),
              onTap: () {
                Navigator.pop(ctx);
                _aiAccess(context, s, m);
              },
            ),
            if (s.isPrimaryOwner)
              ListTile(
                leading: Icon(PhRegular.shieldCheck,
                    size: 18, color: Nocturne.palette.accentMuted),
                title: Text('Make primary owner',
                    style: TextStyle(
                        fontSize: 14, color: Nocturne.palette.text)),
                subtitle: Text(
                    'They can then grant or remove owners. You stay an owner.',
                    style: TextStyle(
                        fontSize: 11.5, color: Nocturne.palette.muted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Nocturne.palette.surface,
                      title: Text('Make ${m.name} the primary owner?',
                          style: TextStyle(color: Nocturne.palette.text)),
                      content: Text(
                          'Only they will be able to add or remove owners after this.',
                          style: TextStyle(color: Nocturne.palette.subtle)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: Nocturne.palette.muted))),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text('Make primary',
                                style: TextStyle(
                                    color: Nocturne.palette.accentMuted))),
                      ],
                    ),
                  );
                  if (ok == true) await s.transferOwnership(m.userId);
                },
              ),
            ListTile(
              leading: Icon(
                m.isActive ? PhRegular.xCircle : PhRegular.checkCircle,
                size: 18,
                color: m.isActive
                    ? Nocturne.palette.expense
                    : Nocturne.palette.income,
              ),
              title: Text(m.isActive ? 'Disable access' : 'Re-enable access',
                  style: TextStyle(fontSize: 14, color: Nocturne.palette.text)),
              onTap: () async {
                Navigator.pop(ctx);
                await s.setMemberStatus(
                    m.userId, m.isActive ? 'disabled' : 'active');
              },
            ),
            ListTile(
              leading: Icon(PhRegular.trash,
                  size: 18, color: Nocturne.palette.expense),
              title: Text('Remove from workspace',
                  style: TextStyle(
                      fontSize: 14, color: Nocturne.palette.expense)),
              subtitle: Text(
                  'Past transactions and shared records remain intact',
                  style: TextStyle(
                      fontSize: 11.5, color: Nocturne.palette.muted)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Nocturne.palette.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Remove ${m.name}?',
                        style: TextStyle(
                            color: Nocturne.palette.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                        'Are you sure you want to remove ${m.name} from the workspace? '
                        'Their shared transactions and history will be preserved.',
                        style: TextStyle(color: Nocturne.palette.subtle)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text('Cancel',
                            style: TextStyle(color: Nocturne.palette.muted)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Nocturne.palette.expense),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await s.removeMember(m.userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? '${m.name} removed from workspace'
                          : 'Could not remove member'),
                    ));
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The money picture between me and one other member: what I paid for them,
/// what they paid for me, what we split, and who owes whom now.
class SharedWithSheet extends StatefulWidget {
  final String otherId;
  const SharedWithSheet({super.key, required this.otherId});

  static Future<void> open(BuildContext context, String otherId) {
    final palette =
        context.read<ThemeController?>()?.palette ?? Nocturne.palette;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SharedWithSheet(otherId: otherId),
    );
  }

  @override
  State<SharedWithSheet> createState() => _SharedWithSheetState();
}

class _SharedWithSheetState extends State<SharedWithSheet> {
  // Server-side so recorded settlements are netted off.
  late Future<double> _balance =
      context.read<V3State>().pairBalance(widget.otherId);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    final other = s.memberById(widget.otherId);
    final name = other?.name ?? 'Them';
    final ledger = s.ledgerWith(widget.otherId);
    var paidForThem = 0.0, paidForMe = 0.0, together = 0.0;
    for (final t in ledger) {
      together += t.amount;
      final v = s.signedShare(t, widget.otherId);
      if (v > 0) {
        paidForThem += v;
      } else {
        paidForMe -= v;
      }
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          children: [
            Row(
              children: [
                V3Avatar(
                    initial: other?.initial ?? '?',
                    color: other?.color ?? palette.accent,
                    size: 40,
                    fontSize: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('You & $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<double>(
              future: _balance,
              builder: (_, snap) {
                final syncBal = s.pairBalanceSync(widget.otherId);
                final b = (snap.hasData && snap.data != 0.0)
                    ? snap.data!
                    : (snap.connectionState == ConnectionState.done
                        ? (snap.data ?? syncBal)
                        : (syncBal.abs() >= 0.5 ? syncBal : snap.data));
                final settled = b != null && b.abs() < 0.5;
                final text = b == null
                    ? 'Working out the balance…'
                    : settled
                        ? 'All settled up'
                        : b > 0
                            ? '$name owes you ${s.money(b)}'
                            : 'You owe $name ${s.money(-b)}';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.isDark ? palette.bg : palette.line,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(text,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: b == null || settled
                                    ? palette.muted
                                    : b > 0
                                        ? palette.income
                                        : palette.expense)),
                      ),
                      if (b != null && !settled) ...[
                        if (b < 0 && other != null && other.upiId != null && other.upiId!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.income,
                                foregroundColor: palette.isDark ? palette.bg : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => UpiService.openUpiPayment(
                                upiId: other.upiId!,
                                payeeName: name,
                                amount: -b,
                                note: 'Settle balance with $name',
                              ),
                              icon: const Icon(PhRegular.lightning, size: 13),
                              label: const Text('Pay UPI',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                        TextButton(
                          onPressed: () async {
                            final ok = await s.settleWith(widget.otherId, b);
                            if (!mounted || !ok) return;
                            setState(() =>
                                _balance = s.pairBalance(widget.otherId));
                          },
                          child: Text('Settle up',
                              style: TextStyle(color: palette.accent)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('You paid for $name', s.moneyShort(paidForThem), palette),
                const SizedBox(width: 8),
                _stat('$name paid for you', s.moneyShort(paidForMe), palette),
                const SizedBox(width: 8),
                _stat('Split together', s.moneyShort(together), palette),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.accent,
                  side: BorderSide(color: palette.edge),
                ),
                icon: const Icon(PhRegular.handCoins, size: 16),
                label: Text('Send money to $name'),
                onPressed: () => _sendMoney(context, s, name),
              ),
            ),
            const SizedBox(height: 16),
            Text('SHARED ENTRIES',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: palette.muted)),
            const SizedBox(height: 6),
            if (ledger.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Nothing shared yet.',
                    style:
                        TextStyle(fontSize: 13, color: palette.muted)),
              ),
            for (final t in ledger) _entry(s, t, name, palette),
          ],
        ),
      ),
    );
  }

  Widget _entry(V3State s, TxnRow t, String name, NocturnePalette palette) {
    final v = s.signedShare(t, widget.otherId);
    final payer = t.paidBy ?? t.userId;
    final isMe = payer == s.myId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13.5, color: palette.text)),
                Text(
                  '${isMe ? 'You' : name} paid '
                  '${s.moneyShort(t.amount)}',
                  style: TextStyle(
                      fontSize: 11.5, color: palette.muted),
                ),
              ],
            ),
          ),
          Text(
            v >= 0 ? '+${s.moneyShort(v)}' : '−${s.moneyShort(-v)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: v >= 0
                    ? palette.income
                    : palette.expense),
          ),
        ],
      ),
    );
  }

  /// Records money I gave [name]: my expense now, their income once they
  /// approve it.
  Future<void> _sendMoney(BuildContext context, V3State s, String name) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text('Send money to $name',
            style: TextStyle(color: Nocturne.palette.text, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: Nocturne.palette.text),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            TextField(
              controller: note,
              style: TextStyle(color: Nocturne.palette.text),
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 8),
            Text('From your main account. It counts for $name once they approve it.',
                style: TextStyle(
                    fontSize: 11.5, color: Nocturne.palette.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel',
                  style: TextStyle(color: Nocturne.palette.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Send',
                  style: TextStyle(color: Nocturne.palette.accentMuted))),
        ],
      ),
    );
    final value = double.tryParse(amount.text.trim());
    if (ok != true || value == null || value <= 0) return;
    final sent = await s.transferMoney(
      toUserId: widget.otherId,
      amount: value,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      sourceId: s.mainSourceId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? 'Sent ${s.money(value)} to $name. Waiting for them to approve.'
            : 'Could not send. Check your connection.')));
  }

  Widget _stat(String label, String value, NocturnePalette palette) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.isDark ? palette.bg : palette.line,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 10.5, color: palette.muted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text)),
              ),
            ],
          ),
        ),
      );
}

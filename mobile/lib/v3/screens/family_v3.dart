import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/upi_service.dart';
import '../../theme/nocturne.dart';
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
    final chat = context.watch<ChatController?>();
    final unreadTotal = chat?.totalUnread ?? 0;
    final spendByMember = {for (final e in s.byMember) e.key.userId: e.value};

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: Nocturne.accent300,
      backgroundColor: Nocturne.surface,
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
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: Nocturne.text)),
                            ),
                            const SizedBox(width: 6),
                            const Icon(PhRegular.pencilSimple,
                                size: 14, color: Nocturne.neutral500),
                          ],
                        ),
                      ),
                      Text(
                          '${s.members.where((m) => m.isActive).length} members · '
                          '${s.family?.kind ?? 'Family'}',
                          style: const TextStyle(
                              fontSize: 12, color: Nocturne.neutral500)),
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
                      color: Nocturne.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: const Icon(PhRegular.slidersHorizontal,
                        size: 19, color: Nocturne.neutral300),
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
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.accent800, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Workspace code',
                          style: TextStyle(
                              fontSize: 11, color: Nocturne.neutral500)),
                      const SizedBox(height: 2),
                      Text(
                        s.family?.inviteCode ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 2.8,
                          fontFamily: 'monospace',
                          color: Nocturne.accent200,
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
                      border: Border.all(color: Nocturne.accent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhRegular.copy,
                            size: 14, color: Nocturne.accent200),
                        SizedBox(width: 6),
                        Text('Copy',
                            style: TextStyle(
                                fontSize: 12.5, color: Nocturne.accent200)),
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
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unreadTotal > 0 ? Nocturne.accent700 : Nocturne.neutral800,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const V3IconTile(
                    icon: PhRegular.chatCircleDots,
                    color: Nocturne.accent300,
                    size: 36,
                    radius: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Direct messages',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text,
                          ),
                        ),
                        Text(
                          unreadTotal > 0
                              ? '$unreadTotal unread message${unreadTotal == 1 ? '' : 's'}'
                              : 'Private 1:1 chats with family members',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: unreadTotal > 0
                                ? Nocturne.accent200
                                : Nocturne.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadTotal > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Nocturne.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadTotal > 9 ? '9+' : '$unreadTotal',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Nocturne.bg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.neutral600),
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
                                color: NocturneSemantic.warning,
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
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Nocturne.text)),
                                  Text(
                                      s.approvals[i].reason ??
                                          'Tap to review',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Nocturne.neutral500)),
                                ],
                              ),
                            ),
                            const Icon(PhRegular.caretRight,
                                size: 14, color: Nocturne.neutral600),
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
                              color: Nocturne.accent300,
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
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Nocturne.text)),
                                Text(s.settlements[i].note ?? 'Split expense',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Nocturne.neutral500)),
                              ],
                            ),
                          ),
                          V3Num(V3Design.inr(s.settlements[i].amount),
                              style: const TextStyle(
                                  fontSize: 13.5, color: Nocturne.text)),
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
                                        color: NocturneSemantic.income.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: NocturneSemantic.income, width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(PhRegular.lightning,
                                              size: 11, color: NocturneSemantic.income),
                                          SizedBox(width: 3),
                                          Text('UPI',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: NocturneSemantic.income)),
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
                                    color: Nocturne.accent300, width: 1),
                              ),
                              child: const Text('Settle',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Nocturne.accent300)),
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
}

class _MemberRowTile extends StatelessWidget {
  final int index;
  final double spent;

  const _MemberRowTile({required this.index, required this.spent});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final m = s.members[index];
    final isMe = m.userId == s.myId;
    final canManage = (s.isOwner || s.me?.role == 'admin') && !isMe;

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
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Nocturne.neutral800,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(m.role,
                          style: const TextStyle(
                              fontSize: 10, color: Nocturne.neutral200)),
                    ),
                    if (!m.isActive) ...[
                      const SizedBox(width: 6),
                      const Text('disabled',
                          style: TextStyle(
                              fontSize: 10,
                              color: NocturneSemantic.expense)),
                    ],
                  ],
                ),
                Text(
                  [
                    if (m.relationship.isNotEmpty) m.relationship,
                    '${s.moneyShort(spent)} this period',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500),
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
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhRegular.bellRinging,
                    size: 17, color: NocturneSemantic.warning),
              ),
            ),
            GestureDetector(
              onTap: () => context.read<V3Nav>().openChat(m.userId),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhRegular.chatCircleDots,
                    size: 18, color: Nocturne.accent300),
              ),
            ),
          ],
          if (canManage)
            GestureDetector(
              onTap: () => _manage(context, s, index),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(PhRegular.dotsThree,
                    size: 18, color: Nocturne.neutral500),
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
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(m.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.text)),
            const SizedBox(height: 8),
            for (final role in const ['admin', 'member', 'viewer'])
              ListTile(
                leading: Icon(
                  m.role == role ? PhFill.checkCircle : PhRegular.circle,
                  size: 18,
                  color: m.role == role
                      ? Nocturne.accent300
                      : Nocturne.neutral600,
                ),
                title: Text('Set as $role',
                    style: const TextStyle(
                        fontSize: 14, color: Nocturne.text)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await s.repo.setMemberRole(s.familyId, m.userId, role);
                  await s.refresh();
                },
              ),
            ListTile(
              leading: Icon(
                m.isActive ? PhRegular.xCircle : PhRegular.checkCircle,
                size: 18,
                color: m.isActive
                    ? NocturneSemantic.expense
                    : NocturneSemantic.income,
              ),
              title: Text(m.isActive ? 'Disable access' : 'Re-enable access',
                  style: const TextStyle(fontSize: 14, color: Nocturne.text)),
              onTap: () async {
                Navigator.pop(ctx);
                await s.setMemberStatus(
                    m.userId, m.isActive ? 'disabled' : 'active');
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.trash,
                  size: 18, color: NocturneSemantic.expense),
              title: const Text('Remove from workspace',
                  style: TextStyle(
                      fontSize: 14, color: NocturneSemantic.expense)),
              subtitle: const Text(
                  'Past transactions and shared records remain intact',
                  style: TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Nocturne.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Remove ${m.name}?',
                        style: const TextStyle(
                            color: Nocturne.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                        'Are you sure you want to remove ${m.name} from the workspace? '
                        'Their shared transactions and history will be preserved.',
                        style: const TextStyle(color: Nocturne.neutral400)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Nocturne.neutral500)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: NocturneSemantic.expense),
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

  static Future<void> open(BuildContext context, String otherId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Nocturne.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => SharedWithSheet(otherId: otherId),
      );

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
                    color: other?.color ?? Nocturne.neutral700,
                    size: 40,
                    fontSize: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('You & $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<double>(
              future: _balance,
              builder: (_, snap) {
                final b = snap.data;
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
                    color: Nocturne.bg,
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
                                    ? Nocturne.neutral300
                                    : b > 0
                                        ? NocturneSemantic.income
                                        : NocturneSemantic.expense)),
                      ),
                      if (b != null && !settled) ...[
                        if (b < 0 && other != null && other.upiId != null && other.upiId!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: NocturneSemantic.income,
                                foregroundColor: Nocturne.bg,
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
                          child: const Text('Settle up',
                              style: TextStyle(color: Nocturne.accent300)),
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
                _stat('You paid for $name', s.moneyShort(paidForThem)),
                const SizedBox(width: 8),
                _stat('$name paid for you', s.moneyShort(paidForMe)),
                const SizedBox(width: 8),
                _stat('Split together', s.moneyShort(together)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('SHARED ENTRIES',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: Nocturne.neutral500)),
            const SizedBox(height: 6),
            if (ledger.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('Nothing shared yet.',
                    style:
                        TextStyle(fontSize: 13, color: Nocturne.neutral500)),
              ),
            for (final t in ledger) _entry(s, t, name),
          ],
        ),
      ),
    );
  }

  Widget _entry(V3State s, TxnRow t, String name) {
    final v = s.signedShare(t, widget.otherId);
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
                        const TextStyle(fontSize: 13.5, color: Nocturne.text)),
                Text(
                  '${t.paidBy == s.myId ? 'You' : name} paid '
                  '${s.moneyShort(t.amount)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500),
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
                    ? NocturneSemantic.income
                    : NocturneSemantic.expense),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Nocturne.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 10.5, color: Nocturne.neutral500)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text)),
              ),
            ],
          ),
        ),
      );
}

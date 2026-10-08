import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/chat_controller.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_design.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'chat_thread_v3.dart';

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
                    icon: PhRegular.envelopeSimple,
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
            const V3SectionHeader(title: 'Who owes who'),
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
                          const SizedBox(width: 10),
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

    return Padding(
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
          if (!isMe && m.isActive)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatThreadV3(partner: m),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhRegular.envelopeSimple,
                    size: 18, color: Nocturne.accent300),
              ),
            ),
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

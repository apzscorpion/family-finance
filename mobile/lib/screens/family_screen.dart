import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../services/note_import_service.dart';
import '../theme/app_theme.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';
    final pendingLoginReqs = provider.pendingFamilyLoginRequests;
    final disabledCount = provider.members.where((m) => m.isDisabled).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Invite Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.familyName,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showRenameFamilyDialog(context, provider),
                          child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSubtle),
                        ),
                      ],
                    ),
                    Text(
                      '${provider.members.length} ${provider.members.length == 1 ? 'member' : 'members'}'
                      '${disabledCount > 0 ? ' ($disabledCount disabled)' : ''} · Code: ${provider.familyCode}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showJoinFamilyDialog(context, provider),
                icon: const Icon(Icons.group_add, size: 16, color: AppTheme.accent200),
                label: const Text('Join', style: TextStyle(fontSize: 13, color: AppTheme.accent200)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Family Invite Code + 6-Digit Family Security OTP Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.balanceGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              boxShadow: const [AppTheme.shadowSm],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 17, color: AppTheme.accent200),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FAMILY INVITE CODE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.accent300, letterSpacing: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 1: Family Invite Code
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Family Invite Code', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            provider.familyCode,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Text('Owner Verification OTP', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => provider.rotateFamilyVerificationOtp(),
                              child: const Icon(Icons.refresh, size: 14, color: AppTheme.accent200),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: provider.familyVerificationOtp));
                            provider.showToast('Family Security OTP ${provider.familyVerificationOtp} copied!');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.green.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline, size: 14, color: AppTheme.green),
                                const SizedBox(width: 6),
                                Text(
                                  provider.familyVerificationOtp,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.green, letterSpacing: 2.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: 'Family Code: ${provider.familyCode} | Security OTP: ${provider.familyVerificationOtp}',
                            ),
                          );
                          provider.showToast('Family Code & Security OTP copied!');
                        },
                        icon: const Icon(Icons.copy, size: 13, color: AppTheme.accent100),
                        label: const Text('Copy invite', style: TextStyle(fontSize: 11.5, color: AppTheme.accent100)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.accent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final msg =
                              'Join our "${provider.familyName}" workspace on Family Spend Tracker!\n\n'
                              '1. Family Invite Code: ${provider.familyCode}\n'
                              '2. Family Security Verification OTP: ${provider.familyVerificationOtp}\n\n'
                              'Open the app -> Select "Join via Code" -> Enter Code & Verification OTP.';
                          NoteImportService.shareExternally(
                            text: msg,
                            title: 'Join ${provider.familyName} on Family Spend Tracker',
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 13),
                        label: const Text('Share invite', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Anyone trying to use your Family Code must enter your 6-digit Owner Verification OTP above (or be approved by you below).',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSubtle, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Family Login Verification Requests Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_outlined, size: 16, color: AppTheme.accent200),
                  const SizedBox(width: 6),
                  const Text(
                    'Family Login Verification',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text),
                  ),
                  const SizedBox(width: 8),
                  if (pendingLoginReqs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.amberBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingLoginReqs.length} pending',
                        style: const TextStyle(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: () => provider.rotateFamilyVerificationOtp(),
                icon: const Icon(Icons.autorenew, size: 14, color: AppTheme.accent200),
                label: const Text('Rotate OTP', style: TextStyle(fontSize: 11.5, color: AppTheme.accent200)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (pendingLoginReqs.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user, size: 20, color: AppTheme.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No unverified login attempts on your Family Code. If someone tries to use your family login, their request will appear here.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            ...pendingLoginReqs.map((req) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.amber.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.amberBg,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_person_outlined, size: 18, color: AppTheme.amber),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${req.name} is trying to use your Family Login',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                              ),
                              Text(
                                '${req.email} · Request OTP: ${req.verificationOtp}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => provider.rejectAndBlockFamilyLoginRequest(req),
                            icon: const Icon(Icons.block, size: 15, color: AppTheme.red),
                            label: const Text('Block & Disable', style: TextStyle(fontSize: 12.5, color: AppTheme.red)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.red.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(0, 38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => provider.approveFamilyLoginRequest(req),
                            icon: const Icon(Icons.check_circle_outline, size: 15),
                            label: const Text('Verify & Approve', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.green,
                              foregroundColor: AppTheme.bg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(0, 38),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),

          // Expense Approval Requests Section
          Row(
            children: [
              const Text('Needs your review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
              const SizedBox(width: 8),
              if (provider.approvals.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.amberBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${provider.approvals.length}', style: const TextStyle(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (provider.approvals.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 22, color: AppTheme.green),
                  SizedBox(width: 12),
                  Text('All caught up — nothing waiting for review.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
            )
          else
            ...provider.approvals.map((a) {
              final fromMember = provider.members.firstWhere(
                (m) => m.id == a.fromMemberId,
                orElse: () => FamilyMemberDef(
                  id: a.fromMemberId,
                  name: a.fromMemberId,
                  rel: 'Member',
                  role: 'Member',
                  openingBalance: 0,
                  color: AppTheme.accent,
                ),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.amber.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: fromMember.color.withOpacity(0.4)),
                          alignment: Alignment.center,
                          child: Text(fromMember.initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 13, color: AppTheme.text),
                                  children: [
                                    TextSpan(text: fromMember.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    TextSpan(
                                      text: a.kind == 'Edit' ? ' proposed an edit' : ' added "${a.newTxn?.title ?? ''}" for you',
                                      style: const TextStyle(color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(a.time, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF595D6C)),
                          ),
                          child: Text(a.kind == 'Edit' ? 'Edit request' : 'New expense', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount', style: TextStyle(fontSize: 12.5, color: AppTheme.textSubtle)),
                          Text(
                            formatInr(a.kind == 'Edit' ? (a.changes!['amt'] as num).toDouble() : (a.newTxn?.amount ?? 0)),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.amber),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(a.reason, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => provider.rejectItem(a),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF595D6C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Reject', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => provider.approveItem(a),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent900,
                              foregroundColor: AppTheme.accent200,
                              side: const BorderSide(color: AppTheme.accent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Members & Login Access Control',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text),
              ),
              TextButton.icon(
                onPressed: () => _showAddMemberDialog(context, provider),
                icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppTheme.accent200),
                label: const Text('Add Member', style: TextStyle(fontSize: 12.5, color: AppTheme.accent200)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Member Directory List with Enable / Disable Login Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: provider.members.map((m) {
                final mSpent = provider.transactions
                    .filterInScope(m.id, 30)
                    .where((t) => t.type == 'expense')
                    .fold(0.0, (s, t) => s + t.amount);
                final isOwner = m.id == 'me';

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: m == provider.members.last ? Colors.transparent : const Color(0xFF2E313A),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => provider.setContext(m.id),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: m.isDisabled ? AppTheme.redBg : m.color.withOpacity(0.4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                m.initial,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: m.isDisabled ? AppTheme.red : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          m.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: m.isDisabled ? AppTheme.textSubtle : AppTheme.text,
                                            decoration: m.isDisabled ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: m.isDisabled ? AppTheme.redBg : AppTheme.greenBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          m.isDisabled ? 'LOGIN DISABLED' : (isOwner ? 'OWNER' : 'VERIFIED'),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: m.isDisabled ? AppTheme.red : AppTheme.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${m.rel} · ${m.role}${m.email.isNotEmpty ? ' · ${m.email}' : ''}',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatInr(mSpent), style: const TextStyle(fontSize: 13.5, color: AppTheme.text)),
                                const Text('spent · 30d', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Member Login Access Controls (Disable / Enable Login + OTP)
                      if (!isOwner) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (m.memberOtp.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: m.memberOtp));
                                  provider.showToast('Member OTP ${m.memberOtp} copied');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.pin_outlined, size: 13, color: AppTheme.accent200),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Member OTP: ${m.memberOtp}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.accent100, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => provider.toggleMemberDisabled(m.id),
                                  icon: Icon(
                                    m.isDisabled ? Icons.check_circle_outline : Icons.person_off_outlined,
                                    size: 14,
                                    color: m.isDisabled ? AppTheme.green : AppTheme.red,
                                  ),
                                  label: Text(
                                    m.isDisabled ? 'Enable Login' : 'Disable Login',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: m.isDisabled ? AppTheme.green : AppTheme.red,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: (m.isDisabled ? AppTheme.green : AppTheme.red).withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    minimumSize: const Size(0, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => provider.removeFamilyMember(m.id),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textSubtle),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove member',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add & Verify Family Member', style: TextStyle(color: AppTheme.text, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a member to your family workspace. You can disable or enable their login anytime:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Member Name',
                hintStyle: const TextStyle(color: AppTheme.textSubtle),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Member Phone or Email (Optional)',
                hintStyle: const TextStyle(color: AppTheme.textSubtle),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: relCtrl,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Relationship (e.g. Wife, Brother, Father)',
                hintStyle: const TextStyle(color: AppTheme.textSubtle),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSubtle)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                provider.addFamilyMember(
                  name: name,
                  rel: relCtrl.text.trim().isNotEmpty ? relCtrl.text.trim() : 'Family',
                  email: emailCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg),
            child: const Text('Add & Generate OTP'),
          ),
        ],
      ),
    );
  }

  void _showRenameFamilyDialog(BuildContext context, FinanceProvider provider) {
    final ctrl = TextEditingController(text: provider.familyName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Family Workspace Name', style: TextStyle(color: AppTheme.text, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your family name',
            hintStyle: const TextStyle(color: AppTheme.textSubtle),
            filled: true,
            fillColor: AppTheme.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSubtle)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                provider.setFamilyDetails(name: name, code: provider.familyCode);
                Navigator.pop(ctx);
                provider.showToast('Family name updated to $name');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showJoinFamilyDialog(BuildContext context, FinanceProvider provider) {
    final ctrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Family Household', style: TextStyle(color: AppTheme.text, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the 6–8 character unique Family Invite Code:', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'Invite Code (e.g. A7B9X2K4)',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle, letterSpacing: 0),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Family Name (Optional)',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSubtle)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = ctrl.text.trim();
              if (code.length >= 6) {
                provider.joinFamilyWithCode(code, familyName: nameCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg),
            child: const Text('Join Workspace'),
          ),
        ],
      ),
    );
  }
}

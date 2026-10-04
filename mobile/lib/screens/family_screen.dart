import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Invite Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khan Family', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.text)),
                  Text('${FinanceProvider.members.length} of 30 members · you\'re the owner', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => provider.showToast('Invite link copied · valid 7 days'),
                icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppTheme.accent200),
                label: const Text('Invite', style: TextStyle(fontSize: 13, color: AppTheme.accent200)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Approval Requests Section
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
              final fromMember = FinanceProvider.members.firstWhere(
                (m) => m.id == a.fromMemberId,
                orElse: () => FamilyMemberDef(id: a.fromMemberId, name: a.fromMemberId, rel: 'Member', role: 'Member', openingBalance: 0, color: AppTheme.accent),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: fromMember.color.withValues(alpha: 0.4)),
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
                    // Difference Diff Card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount', style: TextStyle(fontSize: 12.5, color: AppTheme.textSubtle)),
                          Row(
                            children: [
                              Text(
                                a.kind == 'Edit' ? formatInr(2000) : '—',
                                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSubtle, decoration: TextDecoration.lineThrough),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 12, color: AppTheme.textSubtle),
                              const SizedBox(width: 8),
                              Text(
                                formatInr(a.kind == 'Edit' ? (a.changes!['amt'] as num).toDouble() : (a.newTxn?.amount ?? 0)),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.amber),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(a.reason, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    // Action Buttons (Reject vs Approve)
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

          const SizedBox(height: 16),
          const Text('Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
          const SizedBox(height: 8),

          // Member Directory List
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: FinanceProvider.members.map((m) {
                final mSpent = provider.transactions
                    .filterInScope(m.id, 30)
                    .where((t) => t.type == 'expense')
                    .fold(0.0, (s, t) => s + t.amount);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: InkWell(
                    onTap: () => provider.setContext(m.id == 'asif' ? 'me' : m.id),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: m.color.withValues(alpha: 0.4)),
                          alignment: Alignment.center,
                          child: Text(m.initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: const TextStyle(fontSize: 14, color: AppTheme.text)),
                              Text('${m.rel} · ${m.role}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
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
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSubtle),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

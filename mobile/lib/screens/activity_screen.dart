import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';

    final q = provider.searchQuery.trim().toLowerCase();
    final filteredTxns = provider.scopedTransactions.where((t) {
      final matchesType = provider.filterType == 'all' || t.type == provider.filterType;
      final matchesCat = provider.filterCatKey == null || t.catKey == provider.filterCatKey;
      final catName = FinanceProvider.categories[t.catKey]?.name.toLowerCase() ?? '';
      final matchesSearch = q.isEmpty || t.title.toLowerCase().contains(q) || catName.contains(q);
      return matchesType && matchesCat && matchesSearch;
    }).toList();

    // Group transactions by date
    final Map<int, List<TransactionDef>> groups = {};
    for (var t in filteredTxns) {
      groups.putIfAbsent(t.ageInDays, () => []).add(t);
    }
    final sortedDays = groups.keys.toList()..sort();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.text)),
          Text(
            provider.scopeMemberId == null
                ? '${provider.familyName} · all members'
                : (provider.scopeMemberId == 'me'
                    ? 'My finances'
                    : '${provider.members.firstWhere((m) => m.id == provider.scopeMemberId, orElse: () => provider.members.first).name}\'s finances'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
          ),
          const SizedBox(height: 14),

          // Search Field
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3F424D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (val) => provider.setSearchQuery(val),
                    style: const TextStyle(fontSize: 14, color: AppTheme.text),
                    decoration: const InputDecoration(
                      hintText: 'Search merchant or note',
                      hintStyle: TextStyle(fontSize: 14, color: AppTheme.textSubtle),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Type Chips (All, Spent, Received) & Category Clear Pill
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...[
                  ['all', 'All'],
                  ['expense', 'Spent'],
                  ['income', 'Received']
                ].map((item) {
                  final key = item[0];
                  final label = item[1];
                  final isSelected = provider.filterType == key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(label, style: TextStyle(fontSize: 12.5, color: isSelected ? AppTheme.accent100 : AppTheme.textMuted)),
                      selected: isSelected,
                      onSelected: (_) => provider.setFilterType(key),
                      backgroundColor: AppTheme.bg,
                      selectedColor: AppTheme.accent900,
                      side: BorderSide(color: isSelected ? AppTheme.accent : const Color(0xFF3F424D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                  );
                }),
                if (provider.filterCatKey != null) ...[
                  InputChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text((FinanceProvider.categories[provider.filterCatKey]?.name ?? provider.filterCatKey ?? ''), style: const TextStyle(fontSize: 12.5, color: AppTheme.accent100)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 14, color: AppTheme.accent100),
                      ],
                    ),
                    onPressed: () => provider.setFilterCategory(null),
                    backgroundColor: AppTheme.accent900,
                    side: const BorderSide(color: AppTheme.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Account / Wallet Filter Chips (All, Cash, Salary, Loan, UPI, Bank, Card)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FinanceProvider.walletAccounts.map((acct) {
                final isSel = provider.selectedAccount == acct;
                final bal = provider.accountBalance(acct);
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      '$acct · ${formatInr(bal)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                        color: isSel ? AppTheme.accent100 : AppTheme.textMuted,
                      ),
                    ),
                    selected: isSel,
                    onSelected: (_) => provider.setSelectedAccount(acct),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.accent900,
                    side: BorderSide(color: isSel ? AppTheme.accent : const Color(0xFF3F424D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Total Spent & Total Received Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spent · ${provider.selectedAccount}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        formatInr(filteredTxns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount)),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.red),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Received · ${provider.selectedAccount}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        formatInr(filteredTxns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount)),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grouped Transaction List
          if (sortedDays.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 40, color: AppTheme.textSubtle),
                    SizedBox(height: 8),
                    Text('No transactions match', style: TextStyle(fontSize: 14, color: AppTheme.text)),
                    Text('Try another search or clear filters', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                  ],
                ),
              ),
            )
          else
            ...sortedDays.map((d) {
              final dayTxns = groups[d] ?? [];
              final dayTitle = d == 0 ? 'Today' : (d == 1 ? 'Yesterday' : '$d days ago');
              final dayTotal = dayTxns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dayTitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                        Text('-${formatInr(dayTotal)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: dayTxns.map((t) {
                        final cat = FinanceProvider.categories[t.catKey] ?? FinanceProvider.categories['shopping']!;
                        final member = provider.members.firstWhere(
                          (m) => m.id == t.memberId,
                          orElse: () => FamilyMemberDef(id: t.memberId, name: provider.currentUserName, rel: 'You', role: 'Owner', openingBalance: 0, color: AppTheme.accent),
                        );
                        final isIncome = t.type == 'income';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cat.color.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(cat.icon, size: 19, color: cat.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.title, style: const TextStyle(fontSize: 14, color: AppTheme.text)),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text('${t.time} · ${member.name}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent900,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.accent700),
                                          ),
                                          child: Text(
                                            t.cardId != null && provider.cardById(t.cardId) != null
                                                ? '${provider.cardById(t.cardId)!.shortLabel} · Avl ${formatInr(provider.cardAvailableCredit(t.cardId!))}'
                                                : '${t.method} · Bal ${formatInr(provider.accountBalance(t.method))}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent200),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'}${formatInr(t.amount)}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isIncome ? AppTheme.green : AppTheme.text),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

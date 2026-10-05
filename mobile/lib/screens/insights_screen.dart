import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';

    // Calculate weekly cash flow data for 4 weeks
    final weeks = [
      {'label': '3 wks ago', 'min': 21, 'max': 29},
      {'label': '2 wks ago', 'min': 14, 'max': 20},
      {'label': 'Last week', 'min': 7, 'max': 13},
      {'label': 'This week', 'min': 0, 'max': 6},
    ].map((w) {
      final rangeTxns = provider.scopedTransactions.where((t) => t.ageInDays >= (w['min'] as int) && t.ageInDays <= (w['max'] as int)).toList();
      final inc = rangeTxns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
      final exp = rangeTxns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
      return {'label': w['label'], 'inc': inc, 'exp': exp};
    }).toList();

    double maxVal = 1.0;
    for (var w in weeks) {
      if ((w['inc'] as double) > maxVal) maxVal = w['inc'] as double;
      if ((w['exp'] as double) > maxVal) maxVal = w['exp'] as double;
    }

    // Compute dynamic highlights from real user transactions
    final expenses = provider.scopedTransactions.where((t) => t.type == 'expense').toList();
    final totExp = provider.totalExpense;

    String? topCatTitle;
    String? topCatBody;
    if (expenses.isNotEmpty && totExp > 0) {
      final Map<String, double> byCat = {};
      for (var t in expenses) {
        byCat[t.catKey] = (byCat[t.catKey] ?? 0.0) + t.amount;
      }
      final topEntry = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final catName = FinanceProvider.categories[topEntry.key]?.name ?? topEntry.key;
      final pct = (topEntry.value / totExp * 100).round();
      topCatTitle = '$catName leads at $pct%';
      topCatBody = '${formatInr(topEntry.value)} of ${formatInr(totExp)} spent in the selected period.';
    }

    String? largestTitle;
    String? largestBody;
    if (expenses.isNotEmpty) {
      final largest = expenses.reduce((a, b) => a.amount >= b.amount ? a : b);
      final memberName = provider.members
          .firstWhere((m) => m.id == largest.memberId, orElse: () => provider.members.first)
          .name;
      largestTitle = 'Largest expense: ${largest.title}';
      largestBody = '${formatInr(largest.amount)} by $memberName · ${largest.method}.';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: AppTheme.text)),
          Text(
            provider.scopeMemberId == null
                ? '${provider.familyName} · last 4 weeks'
                : 'My finances · last 4 weeks',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
          ),
          const SizedBox(height: 16),

          // 1. Weekly Cash Flow Chart Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [AppTheme.shadowSm],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weekly cash flow', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                    Row(
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            const Text('In', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            const Text('Out', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 170,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: weeks.map((w) {
                      final incH = ((w['inc'] as double) / maxVal * 140).clamp(6.0, 140.0);
                      final expH = ((w['exp'] as double) / maxVal * 140).clamp(6.0, 140.0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 16,
                            height: incH,
                            decoration: const BoxDecoration(
                              color: AppTheme.green,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 16,
                            height: expH,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const Divider(color: Color(0xFF3F424D), height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weeks.map((w) {
                    return Column(
                      children: [
                        Text(w['label'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                        Text(formatInr(w['exp'] as double), style: const TextStyle(fontSize: 11.5, color: AppTheme.text)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Dynamic Highlight Cards
          if (expenses.isEmpty)
            _buildInsightHighlightCard(
              icon: Icons.insights_outlined,
              title: 'No spending data yet',
              body: 'Add your first income or expense to see real-time category breakdowns and weekly trends.',
            )
          else ...[
            if (topCatTitle != null && topCatBody != null) ...[
              _buildInsightHighlightCard(
                icon: Icons.pie_chart_outline,
                title: topCatTitle,
                body: topCatBody,
              ),
              const SizedBox(height: 10),
            ],
            if (largestTitle != null && largestBody != null)
              _buildInsightHighlightCard(
                icon: Icons.arrow_circle_up_outlined,
                title: largestTitle,
                body: largestBody,
              ),
          ],
          const SizedBox(height: 14),

          // 3. Category Breakdown List
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('By category', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                const SizedBox(height: 14),
                ...FinanceProvider.categories.entries.where((e) => !e.value.isIncome).map((entry) {
                  final cat = entry.value;
                  final spent = provider.scopedTransactions
                      .where((t) => t.catKey == cat.key && t.type == 'expense')
                      .fold(0.0, (s, t) => s + t.amount);

                  final pct = provider.totalExpense > 0 ? (spent / provider.totalExpense * 100) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 13, color: AppTheme.text))),
                            Text(formatInr(spent), style: const TextStyle(fontSize: 13, color: AppTheme.text)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 34,
                              child: Text('${pct.round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppTheme.bg,
                            valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightHighlightCard({required IconData icon, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTheme.accent900, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: AppTheme.accent300),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.text)),
                Text(body, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

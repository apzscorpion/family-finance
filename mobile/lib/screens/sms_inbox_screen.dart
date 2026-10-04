import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add_sheet.dart';

class SmsInboxScreen extends StatelessWidget {
  const SmsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    String formatInr(double n) => '₹${n.round()}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => provider.closeSubPage(),
        ),
        title: const Text('Bank notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.text)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 18, right: 18, top: 6, bottom: 40),
        child: Column(
          children: [
            // Privacy Shield Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent900,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: AppTheme.accent200),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only bank transaction notifications are read, on this device. OTPs and personal messages are skipped; account numbers stay masked.',
                      style: TextStyle(fontSize: 12, color: AppTheme.accent200, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (provider.smsQueue.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textSubtle),
                    SizedBox(height: 8),
                    Text('Inbox clear', style: TextStyle(fontSize: 14, color: AppTheme.text)),
                    Text('New bank notifications will appear here for review', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                  ],
                ),
              )
            else
              ...provider.smsQueue.map((item) {
                final cat = FinanceProvider.categories[item.catKey] ?? FinanceProvider.categories['shopping']!;
                final isDup = item.isDuplicate;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDup ? AppTheme.red.withOpacity(0.4) : const Color(0xFF3F424D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 6),
                              Text('${item.bank} · ${item.when}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDup ? AppTheme.redBg : AppTheme.greenBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.confidence,
                              style: TextStyle(fontSize: 10.5, color: isDup ? AppTheme.red : AppTheme.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: cat.color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(cat.icon, size: 20, color: cat.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.merchant, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.text)),
                                Text('Suggested: ${cat.name}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Text(formatInr(item.amount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.text)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Raw Snippet Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                        child: Text(item.snippet, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted)),
                      ),
                      const SizedBox(height: 8),
                      Text(item.note, style: TextStyle(fontSize: 12, color: isDup ? AppTheme.red : AppTheme.textMuted)),
                      const SizedBox(height: 12),
                      // 3 Action Buttons (Ignore, Edit, Confirm)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => provider.ignoreSmsItem(item),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF3F424D)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 38),
                              ),
                              child: const Text('Ignore', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                QuickAddSheet.show(
                                  context,
                                  type: 'expense',
                                  amount: item.amount.toStringAsFixed(0),
                                  cat: item.catKey,
                                  title: item.merchant,
                                  smsId: item.id,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF595D6C)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 38),
                              ),
                              child: const Text('Edit', style: TextStyle(fontSize: 12.5, color: AppTheme.text)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => provider.confirmSmsItem(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent900,
                                foregroundColor: AppTheme.accent200,
                                side: const BorderSide(color: AppTheme.accent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: const Size(0, 38),
                              ),
                              child: const Text('Confirm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

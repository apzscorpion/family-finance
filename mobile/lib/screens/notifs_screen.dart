import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class NotifsScreen extends StatelessWidget {
  const NotifsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    final notifItems = <Map<String, dynamic>>[
      if (provider.approvals.isNotEmpty)
        {
          'icon': Icons.hourglass_empty,
          'bg': AppTheme.amberBg,
          'color': AppTheme.amber,
          'title': '${provider.approvals.length} approval${provider.approvals.length > 1 ? 's' : ''} waiting',
          'body': 'Family members sent requests for your records',
          'time': 'Now',
          'action': () => provider.setTab(3),
        },
      if (provider.smsQueue.isNotEmpty)
        {
          'icon': Icons.chat_bubble_outline,
          'bg': AppTheme.accent900,
          'color': AppTheme.accent300,
          'title': '${provider.smsQueue.length} transactions detected',
          'body': 'Tap to review parsed transactions',
          'time': 'Now',
          'action': () => provider.openSubPage('sms_inbox'),
        },
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => provider.closeSubPage(),
        ),
        title: const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.text)),
      ),
      body: notifItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 44, color: AppTheme.textSubtle),
                  SizedBox(height: 10),
                  Text('No new notifications', style: TextStyle(fontSize: 15, color: AppTheme.text)),
                  SizedBox(height: 4),
                  Text('Alerts for family approvals and budgets will appear here', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: notifItems.length,
              itemBuilder: (ctx, i) {
                final item = notifItems[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    onTap: item['action'] as VoidCallback?,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item['bg'] as Color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item['icon'] as IconData, size: 19, color: item['color'] as Color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['title'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.text)),
                                    Text(item['time'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(item['body'] as String, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

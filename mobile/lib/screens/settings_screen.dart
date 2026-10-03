import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => provider.closeSubPage(),
        ),
        title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.text)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 18, right: 18, top: 6, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Auto-read SMS
            const Text('AUTO-READ SMS', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  _buildSwitchRow('Read bank SMS automatically', 'Detect debits & credits from your bank messages', provider.autoSms, (val) => provider.autoSms = val),
                  _buildSwitchRow('Smart categories', 'Guess category from merchant name', provider.smartCat, (val) => provider.smartCat = val),
                  _buildSwitchRow('Review before adding', 'Detected items wait in the inbox for you to confirm', provider.reviewSms, (val) => provider.reviewSms = val),
                  _buildSwitchRow('Skip OTP & promotional', 'Never parse OTPs, offers or personal messages', provider.skipPromo, (val) => provider.skipPromo = val),
                  const Divider(color: Color(0xFF292B31), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Banks detected', style: TextStyle(fontSize: 14, color: AppTheme.text)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            _BankTag(label: 'HDFC ··4821'),
                            SizedBox(width: 6),
                            _BankTag(label: 'ICICI ··9910'),
                            SizedBox(width: 6),
                            _BankTag(label: 'SBI ··2207'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Section 2: Notifications
            const Text('NOTIFICATIONS', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  _buildSwitchRow('Budget limit warnings', 'When a budget crosses your alert threshold', provider.notifBudget, (val) => provider.notifBudget = val),
                  _buildSwitchRow('Family member spending', 'When a member adds an expense above ₹2,000', provider.notifFamily, (val) => provider.notifFamily = val),
                  _buildSwitchRow('Approvals needed', 'Edits and entries made on your behalf', provider.notifApprovals, (val) => provider.notifApprovals = val),
                  _buildSwitchRow('Daily summary', 'A 9 PM recap of the day\'s spending', provider.notifDaily, (val) => provider.notifDaily = val),
                  const Divider(color: Color(0xFF292B31), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Budget alert threshold', style: TextStyle(fontSize: 14, color: AppTheme.text)),
                        const SizedBox(height: 10),
                        Row(
                          children: [70, 80, 90].map((t) {
                            final isSelected = provider.alertThreshold == t;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                child: GestureDetector(
                                  onTap: () => provider.setAlertThreshold(t),
                                  child: Container(
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.accent900 : AppTheme.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text('$t%', style: TextStyle(fontSize: 12.5, color: isSelected ? AppTheme.accent100 : AppTheme.textMuted)),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Section 3: Privacy Information
            const Text('PRIVACY', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'Turning off SMS reading keeps manual tracking working. Parsed data stays in your family workspace; raw messages are never uploaded.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, String desc, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.text)),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.accent200,
            activeTrackColor: AppTheme.accent800,
            inactiveTrackColor: AppTheme.bg,
          ),
        ],
      ),
    );
  }
}

class _BankTag extends StatelessWidget {
  final String label;
  const _BankTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.text)),
    );
  }
}

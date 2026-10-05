import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/update_service.dart';
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
            // Section 0: Account & Family Workspace
            const Text('ACCOUNT & WORKSPACE', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [AppTheme.accent500, AppTheme.accent700]),
                        ),
                        alignment: Alignment.center,
                        child: Text(provider.currentUserInitial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.currentUserName.isNotEmpty ? provider.currentUserName : 'User',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text),
                            ),
                            Text(
                              '${provider.familyName} · Code: ${provider.familyCode}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => provider.clearAllData(),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppTheme.textMuted),
                          label: const Text('Clear Data', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3F424D)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(0, 38),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => provider.logout(),
                          icon: const Icon(Icons.logout, size: 16, color: AppTheme.red),
                          label: const Text('Sign Out', style: TextStyle(fontSize: 12.5, color: AppTheme.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.red.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(0, 38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Section 1: Smart SMS Parsing
            const Text('SMART SMS & CATEGORIZATION', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  _buildSwitchRow('Smart categories', 'Guess category from merchant name', provider.smartCat, (val) => provider.smartCat = val),
                  _buildSwitchRow('Review before adding', 'Detected items wait in the inbox for you to confirm', provider.reviewSms, (val) => provider.reviewSms = val),
                  _buildSwitchRow('Skip OTP & promotional', 'Never parse OTPs, offers or personal messages', provider.skipPromo, (val) => provider.skipPromo = val),
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

            // Section 3: App Updates
            const Text('APP UPDATES', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version ${UpdateService.currentVersion}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text)),
                      Text('GitHub release updates enabled', style: TextStyle(fontSize: 12, color: AppTheme.textSubtle)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => UpdateService.checkForUpdates(context, silent: false),
                    icon: const Icon(Icons.system_update_outlined, size: 16, color: AppTheme.accent200),
                    label: const Text('Check Now', style: TextStyle(fontSize: 12.5, color: AppTheme.accent200)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Section 4: Developer Support & Error Reporting
            const Text('DEVELOPER SUPPORT & FEEDBACK', style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppTheme.accent300)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Encountered an issue or have feedback?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.text)),
                  const SizedBox(height: 4),
                  const Text('Send diagnostic error logs directly to the developer (apzscorpion).', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDeveloperSupportDialog(context, provider),
                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                      label: const Text('Report Error / Send Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent900,
                        foregroundColor: AppTheme.accent200,
                        side: const BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeveloperSupportDialog(BuildContext context, FinanceProvider provider) {
    final reportCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.developer_mode, color: AppTheme.accent, size: 22),
                  SizedBox(width: 8),
                  Text('Developer Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Describe what went wrong or suggest a feature:', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: reportCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.text),
                decoration: const InputDecoration(
                  hintText: 'Describe the issue or feedback...',
                  hintStyle: TextStyle(color: AppTheme.textSubtle),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final msg = reportCtrl.text.trim();
                    Navigator.pop(ctx);
                    provider.showToast(msg.isNotEmpty ? 'Error report sent to developer (apzscorpion)' : 'Diagnostic log captured');
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Error Log', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/magic_ai_service.dart';
import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal bottom sheet for "AI That Feels Like Magic":
/// 1. "What-If" Goal Accelerometer Slider
/// 2. Duplicate Family Subscriptions Detector
/// 3. Awkward Money Reminder Writer
/// 4. Price in Hours of Work Calculator
class MagicAiSheet extends StatefulWidget {
  final int initialTab;
  const MagicAiSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => MagicAiSheet(initialTab: initialTab),
    );
  }

  @override
  State<MagicAiSheet> createState() => _MagicAiSheetState();
}

class _MagicAiSheetState extends State<MagicAiSheet> {
  late int _tab;

  // What-If state
  double _cutPercentage = 30.0;
  String _selectedCategoryKey = 'dining';
  String? _selectedGoalId;

  // Awkward reminder state
  final TextEditingController _recipientCtrl = TextEditingController(text: 'Rahul');
  final TextEditingController _reminderAmountCtrl = TextEditingController(text: '1450');
  final TextEditingController _reasonCtrl = TextEditingController(text: 'weekend dinner');
  String _reminderTone = 'polite';
  String _reminderLang = 'english';

  // Work hours calculator state
  final TextEditingController _salaryCtrl = TextEditingController(text: '60000');
  final TextEditingController _itemPriceCtrl = TextEditingController(text: '12500');

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _reminderAmountCtrl.dispose();
    _reasonCtrl.dispose();
    _salaryCtrl.dispose();
    _itemPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Nocturne.neutral700, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Nocturne.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhRegular.sparkle, size: 20, color: Nocturne.accent200),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI That Feels Like Magic',
                      style: TextStyle(color: Nocturne.text, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Goal accelerator · Duplicate finder · Polite reminders',
                      style: TextStyle(color: Nocturne.neutral400, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: Row(
              children: [
                _buildTabBtn(0, '🎯 What-If'),
                _buildTabBtn(1, '🔁 Subscriptions'),
                _buildTabBtn(2, '💬 Reminder'),
                _buildTabBtn(3, '⏳ Work Hours'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _tab == 0
                ? _buildWhatIfTab(s)
                : (_tab == 1
                    ? _buildSubscriptionsTab(s)
                    : (_tab == 2 ? _buildReminderTab(s) : _buildWorkHoursTab(s))),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int index, String label) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Nocturne.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Nocturne.text : Nocturne.neutral400,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. "WHAT-IF" GOAL ACCELEROMETER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWhatIfTab(V3State s) {
    final goals = s.goals;
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhRegular.target, size: 40, color: Nocturne.accent300),
              const SizedBox(height: 12),
              const Text('No savings goals yet', style: TextStyle(color: Nocturne.text, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Create a family goal (e.g. Umrah 2027, New Car) first to simulate acceleration.', textAlign: TextAlign.center, style: TextStyle(color: Nocturne.neutral400, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final targetGoal = (_selectedGoalId != null)
        ? goals.cast<GoalRow?>().firstWhere((g) => g?.id == _selectedGoalId, orElse: () => goals.first)!
        : goals.first;

    // Calculate monthly spend in selected category
    final now = DateTime.now();
    double catMonthlySpend = 0.0;
    for (final t in s.txns) {
      if (t.isExpense && now.difference(t.occurredAt).inDays <= 30) {
        if (t.categoryKey.toLowerCase() == _selectedCategoryKey.toLowerCase()) {
          catMonthlySpend += t.amount;
        }
      }
    }
    if (catMonthlySpend == 0) catMonthlySpend = 9500.0; // Realistic baseline if new install

    final sim = MagicAiService.simulateGoalAcceleration(
      goal: targetGoal,
      currentCategoryMonthlySpend: catMonthlySpend,
      cutPercentage: _cutPercentage,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.accent600, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Goal to Accelerate:', style: TextStyle(color: Nocturne.neutral400, fontSize: 11)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: targetGoal.id,
                  isExpanded: true,
                  dropdownColor: Nocturne.surface,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final g in goals)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text('${g.name} (${V3Design.inr(g.targetAmount)})', style: const TextStyle(color: Nocturne.text, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                  ],
                  onChanged: (id) => setState(() => _selectedGoalId = id),
                ),
                const SizedBox(height: 12),

                const Text('Choose Category to Cut:', style: TextStyle(color: Nocturne.neutral400, fontSize: 11)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        ['dining', 'Food Delivery & Dining'],
                        ['shopping', 'Online Shopping'],
                        ['cabs', 'Cabs & Auto'],
                        ['entertainment', 'Outings & Movies'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(entry[1], style: TextStyle(fontSize: 11, color: _selectedCategoryKey == entry[0] ? Nocturne.bg : Nocturne.text)),
                            selected: _selectedCategoryKey == entry[0],
                            selectedColor: Nocturne.accent,
                            backgroundColor: Nocturne.surface,
                            onSelected: (_) => setState(() => _selectedCategoryKey = entry[0]),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Text('Cut spend by ${_cutPercentage.round()}%', style: const TextStyle(color: Nocturne.text, fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('Current: ${V3Design.inr(catMonthlySpend)}/mo', style: const TextStyle(color: Nocturne.neutral400, fontSize: 11.5)),
                  ],
                ),
                Slider(
                  value: _cutPercentage,
                  min: 10,
                  max: 75,
                  divisions: 13,
                  activeColor: Nocturne.accent,
                  inactiveColor: Nocturne.neutral800,
                  onChanged: (v) => setState(() => _cutPercentage = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Simulation Outcome Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NocturneSemantic.income.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NocturneSemantic.income, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhRegular.lightning, color: NocturneSemantic.income, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reach "${targetGoal.name}" ${sim.monthsSaved} months sooner!',
                        style: const TextStyle(color: Nocturne.text, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Trimming ${_cutPercentage.round()}% frees up ${V3Design.inr(sim.monthlySavings)} every month (${V3Design.inr(sim.annualSavings)} per year). You achieve the goal in ${sim.newCompletionMonths} months instead of ${targetGoal.remainingMonths ?? 12}.',
                  style: const TextStyle(color: NocturneSemantic.income, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Nocturne.accent,
                foregroundColor: Nocturne.bg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final targetBudget = (catMonthlySpend * (1 - _cutPercentage / 100.0)).roundToDouble();
                final cat = s.categoryByKey(_selectedCategoryKey);
                if (cat != null) {
                  await s.upsertBudget(categoryId: cat.id, limitAmount: targetBudget);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Budget for $_selectedCategoryKey set to ${V3Design.inr(targetBudget)}/mo.')),
                );
              },
              icon: const Icon(PhRegular.slidersHorizontal, size: 16),
              label: const Text('Lock in this budget restriction', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. DUPLICATE SUBSCRIPTIONS DETECTOR
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSubscriptionsTab(V3State s) {
    final duplicates = MagicAiService.findDuplicates(
      recurringCharges: s.recurring,
      transactions: s.txns,
      members: s.members,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: const Row(
              children: [
                Icon(PhRegular.playCircle, size: 20, color: Nocturne.accent200),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Subscription Audit',
                        style: TextStyle(color: Nocturne.text, fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Detects when multiple family members pay for separate individual plans.',
                        style: TextStyle(color: Nocturne.neutral400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (duplicates.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const Icon(PhRegular.checkCircle, size: 40, color: NocturneSemantic.income),
                    const SizedBox(height: 10),
                    const Text('No duplicate subscriptions found', style: TextStyle(color: Nocturne.text, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'None of your family members are currently paying for duplicate Spotify, YouTube or Netflix plans.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Nocturne.neutral400, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (final d in duplicates)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NocturneSemantic.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NocturneSemantic.warning, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(PhRegular.warning, color: NocturneSemantic.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duplicate ${d.serviceName} Subscriptions',
                            style: const TextStyle(color: Nocturne.text, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NocturneSemantic.income,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Saves ${V3Design.inr(d.annualSavings)}/yr',
                            style: const TextStyle(color: Nocturne.bg, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${d.payerNames.join(" and ")} both pay for individual plans. Combined current cost: ${V3Design.inr(d.currentMonthlySpend)}/mo.',
                      style: const TextStyle(color: Nocturne.neutral300, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Switching to a shared ${d.familyPlanName} (${V3Design.inr(d.familyPlanMonthlyCost)}/mo) saves your family ${V3Design.inr(d.annualSavings)} every year.',
                      style: const TextStyle(color: NocturneSemantic.warning, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. AI WRITES THE AWKWARD REMINDER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildReminderTab(V3State s) {
    final myMember = s.members.cast<MemberRow?>().firstWhere(
          (m) => m?.userId == s.myId,
          orElse: () => null,
        );
    final myUpi = myMember?.upiId;

    final reminderText = MagicAiService.generateAwkwardReminder(
      recipientName: _recipientCtrl.text.trim().isEmpty ? 'Friend' : _recipientCtrl.text.trim(),
      amount: double.tryParse(_reminderAmountCtrl.text.trim()) ?? 0.0,
      reason: _reasonCtrl.text.trim().isEmpty ? 'the expense' : _reasonCtrl.text.trim(),
      tone: _reminderTone,
      language: _reminderLang,
      upiId: myUpi,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _recipientCtrl,
                  style: const TextStyle(color: Nocturne.text, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Who owes you?',
                    labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _reminderAmountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Nocturne.text, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _reasonCtrl,
            style: const TextStyle(color: Nocturne.text, fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'What was this for? (e.g. dinner, cab, movie ticket)',
              labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Tone Selector
          const Text('Tone:', style: TextStyle(color: Nocturne.neutral400, fontSize: 11)),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in [
                  ['polite', '🌸 Polite & Gentle'],
                  ['casual', '😎 Casual / Banter'],
                  ['formal', '👔 Professional'],
                  ['elder', '🧓 Elder Respectful'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t[1], style: TextStyle(fontSize: 11, color: _reminderTone == t[0] ? Nocturne.bg : Nocturne.text)),
                      selected: _reminderTone == t[0],
                      selectedColor: Nocturne.accent,
                      backgroundColor: Nocturne.bg,
                      onSelected: (_) => setState(() => _reminderTone = t[0]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Language Selector
          const Text('Language:', style: TextStyle(color: Nocturne.neutral400, fontSize: 11)),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in [
                  ['english', 'English'],
                  ['hinglish', 'Hinglish / Hindi'],
                  ['malayalam', 'Malayalam'],
                  ['tamil', 'Tamil'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(l[1], style: TextStyle(fontSize: 11, color: _reminderLang == l[0] ? Nocturne.bg : Nocturne.text)),
                      selected: _reminderLang == l[0],
                      selectedColor: Nocturne.accent,
                      backgroundColor: Nocturne.bg,
                      onSelected: (_) => setState(() => _reminderLang = l[0]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Message Preview Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.accent700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(PhRegular.chatCircleDots, size: 14, color: Nocturne.accent200),
                    SizedBox(width: 6),
                    Text('Ready to send:', style: TextStyle(color: Nocturne.accent200, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  reminderText,
                  style: const TextStyle(fontSize: 13, color: Nocturne.text, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Nocturne.text,
                    side: const BorderSide(color: Nocturne.neutral700),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: reminderText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied reminder to clipboard.')),
                    );
                  },
                  icon: const Icon(PhRegular.copy, size: 16),
                  label: const Text('Copy Text'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Nocturne.accent,
                    foregroundColor: Nocturne.bg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Share.share(reminderText, subject: 'Gentle reminder');
                  },
                  icon: const Icon(PhRegular.shareNetwork, size: 16),
                  label: const Text('Share WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. PRICE IN HOURS OF WORK
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWorkHoursTab(V3State s) {
    final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 50000.0;
    final price = double.tryParse(_itemPriceCtrl.text.trim()) ?? 0.0;
    final hours = MagicAiService.calculateWorkHours(price: price, monthlyIncome: salary);
    final formatted = MagicAiService.formatWorkHours(hours);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: const Row(
              children: [
                Icon(PhRegular.clock, size: 20, color: Nocturne.accent200),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What Does It Really Cost?',
                        style: TextStyle(color: Nocturne.text, fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Translates price tags into literal hours of your life and labor.',
                        style: TextStyle(color: Nocturne.neutral400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _salaryCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Nocturne.text, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Salary (₹)',
                    labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _itemPriceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Nocturne.text, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Item Price (₹)',
                    labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Output Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Nocturne.accent800.withValues(alpha: 0.3), Nocturne.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Nocturne.accent600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price in Hours of Life:', style: TextStyle(color: Nocturne.neutral300, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  formatted,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Nocturne.accent100),
                ),
                const SizedBox(height: 8),
                Text(
                  'At an hourly earning rate of ${V3Design.inr((salary / 160).round())}/hr, purchasing an item worth ${V3Design.inr(price)} requires approximately ${hours.toStringAsFixed(1)} hours of focused work.',
                  style: const TextStyle(color: Nocturne.neutral300, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

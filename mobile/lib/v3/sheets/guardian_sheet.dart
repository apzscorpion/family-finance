import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/card_optimizer_service.dart';
import '../../services/guardian_service.dart';
import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal bottom sheet for Install Magnets:
/// 1. Guardian Mode (Elderly & Parent UPI fraud protection, scam alerts, scam tester)
/// 2. Credit Card Cashback & Rewards Optimizer ("Which card should I use here?")
class GuardianSheet extends StatefulWidget {
  final int initialTab;
  const GuardianSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => GuardianSheet(initialTab: initialTab),
    );
  }

  @override
  State<GuardianSheet> createState() => _GuardianSheetState();
}

class _GuardianSheetState extends State<GuardianSheet> {
  late int _tab;
  final TextEditingController _testTextCtrl = TextEditingController();
  GuardianRiskAssessment? _testAssessment;

  // Best card search state
  String _selectedMerchant = 'Swiggy';
  static const double _testAmount = 1500.0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _testTextCtrl.dispose();
    super.dispose();
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number saved for this member.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAddCardDialog() {
    final s = context.read<V3State>();
    int selectedPreset = 0;
    final lastFourCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final preset = CardOptimizerService.cardPresets[selectedPreset];
          return AlertDialog(
            backgroundColor: Nocturne.palette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Add Family Credit Card', style: TextStyle(color: Nocturne.palette.text, fontSize: 17, fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Card Preset:', style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedPreset,
                    dropdownColor: Nocturne.palette.surface,
                    items: [
                      for (int i = 0; i < CardOptimizerService.cardPresets.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${CardOptimizerService.cardPresets[i]['name']} (${CardOptimizerService.cardPresets[i]['bank']})',
                            style: TextStyle(color: Nocturne.palette.text, fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (idx) => setDialogState(() => selectedPreset = idx ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastFourCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: TextStyle(color: Nocturne.palette.text),
                    decoration: InputDecoration(
                      labelText: 'Last 4 Digits (Optional)',
                      labelStyle: TextStyle(color: Nocturne.palette.subtle),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Nocturne.palette.text),
                    decoration: InputDecoration(
                      labelText: 'Reward Points Balance',
                      labelStyle: TextStyle(color: Nocturne.palette.subtle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Nocturne.palette.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cashback Rules Included:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Nocturne.palette.accentMuted)),
                        const SizedBox(height: 4),
                        for (final r in (preset['rules'] as Map<String, double>).entries)
                          Text('• ${r.key.toUpperCase()}: ${r.value}% cashback', style: TextStyle(fontSize: 11, color: Nocturne.palette.subtle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Nocturne.palette.subtle))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
                onPressed: () async {
                  final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
                  final ok = await s.addCreditCard(
                    cardName: preset['name'] as String,
                    bank: preset['bank'] as String,
                    cardNetwork: preset['network'] as String,
                    lastFour: lastFourCtrl.text.trim().isNotEmpty ? lastFourCtrl.text.trim() : null,
                    ownerUserId: s.myId,
                    rewardPointsBalance: points,
                    cashbackRules: preset['rules'] as Map<String, double>,
                  );
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Add Card'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final maxH = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Nocturne.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.palette.edge, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Icon(
                _tab == 0 ? PhFill.warning : PhFill.creditCard,
                size: 22,
                color: _tab == 0 ? Nocturne.palette.expense : Nocturne.palette.accentMuted,
              ),
              const SizedBox(width: 8),
              Text(
                _tab == 0 ? 'Guardian Mode (Scam Watch)' : 'Card Cashback Optimizer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Nocturne.palette.text),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(PhRegular.x, size: 20, color: Nocturne.palette.subtle),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar
          Row(
            children: [
              _TabPill(
                label: 'Guardian Alerts (${s.activeSecurityAlertsCount})',
                selected: _tab == 0,
                badgeAlert: s.criticalSecurityAlert != null,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Best Card (${s.creditCards.length})',
                selected: _tab == 1,
                badgeAlert: s.cardsWithExpiringPoints.isNotEmpty,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Body
          Expanded(
            child: _tab == 0 ? _buildGuardianTab(s) : _buildCardsTab(s),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 0: GUARDIAN MODE & SCAM PROTECTION
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGuardianTab(V3State s) {
    final alerts = s.securityAlerts;
    final members = s.members.where((m) => m.isActive).toList();
    final protectedMembers = members.where((m) => m.isProtectedMember).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner explaining Guardian Mode
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.palette.edge),
            ),
            child: Row(
              children: [
                Icon(PhRegular.lockSimple, color: Nocturne.palette.income, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent & Elderly Protection Active',
                        style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        protectedMembers.isNotEmpty
                            ? 'Watching ${protectedMembers.map((m) => m.name).join(", ")} for fake KYC, power-cut SMS, and unfamiliar payees.'
                            : 'Tag your parents below so KinPurse flags scam messages and unusual debits immediately.',
                        style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Protected members toggles
          Text('Protected Family Members (Guardian Mode):', style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in members)
                GestureDetector(
                  onTap: () => s.toggleMemberProtection(m.userId, !m.isProtectedMember),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: m.isProtectedMember ? Nocturne.palette.accent.withValues(alpha: 0.16) : Nocturne.palette.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: m.isProtectedMember ? Nocturne.palette.accent : Nocturne.palette.edge,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m.isProtectedMember ? PhBold.lock : PhRegular.lockSimple,
                          size: 14,
                          color: m.isProtectedMember ? Nocturne.palette.accentLight : Nocturne.palette.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.userId == s.myId ? '${m.name} (You)' : m.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: m.isProtectedMember ? FontWeight.w600 : FontWeight.w400,
                            color: m.isProtectedMember ? Nocturne.palette.text : Nocturne.palette.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Alerts List
          if (alerts.any((a) => a.isActive)) ...[
            Text('Active Security Alerts:', style: TextStyle(color: Nocturne.palette.expense, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final a in alerts.where((x) => x.isActive)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Nocturne.palette.expense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Nocturne.palette.expense, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(PhRegular.warning, size: 18, color: Nocturne.palette.expense),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a.title,
                            style: TextStyle(color: Nocturne.palette.text, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          DateFormat('d MMM').format(a.createdAt),
                          style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(a.description, style: TextStyle(color: Nocturne.palette.neutral300, fontSize: 12)),
                    if (a.snippet != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Nocturne.palette.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '"${a.snippet}"',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Nocturne.palette.subtle),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Nocturne.palette.expense,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            MemberRow? targetMember;
                            for (final m in members) {
                              if (m.userId == a.userId) {
                                targetMember = m;
                                break;
                              }
                            }
                            _callPhone(targetMember?.relationship);
                          },
                          icon: const Icon(Icons.phone, size: 13),
                          label: const Text('Call Member', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => s.updateSecurityAlertStatus(a.id, 'resolved'),
                          child: Text('Mark Safe / Dismiss', style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Interactive Scam Message Tester (Simulator)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.palette.edge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhRegular.magnifyingGlass, color: Nocturne.palette.accentMuted, size: 16),
                    SizedBox(width: 6),
                    Text('Check Suspicious Message or Link:', style: TextStyle(color: Nocturne.palette.text, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _testTextCtrl,
                  maxLines: 2,
                  style: TextStyle(color: Nocturne.palette.text, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Paste suspicious SMS / WhatsApp text here to test…',
                    hintStyle: TextStyle(color: Nocturne.palette.muted, fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Nocturne.palette.accent,
                        foregroundColor: Nocturne.palette.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _testAssessment = GuardianService.analyzeText(_testTextCtrl.text);
                        });
                      },
                      child: const Text('Scan with Heuristics', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _testTextCtrl.text = 'Dear customer, your electricity power will be disconnected tonight at 9:30 PM. Call officer 9876543210 immediately.';
                        setState(() {
                          _testAssessment = GuardianService.analyzeText(_testTextCtrl.text);
                        });
                      },
                      child: Text('Test Power Scam Example', style: TextStyle(fontSize: 11, color: Nocturne.palette.accentMuted)),
                    ),
                  ],
                ),
                if (_testAssessment != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _testAssessment!.isSuspicious
                          ? Nocturne.palette.expense.withValues(alpha: 0.16)
                          : Nocturne.palette.income.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testAssessment!.isSuspicious ? Nocturne.palette.expense : Nocturne.palette.income,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _testAssessment!.isSuspicious ? '🚨 ${_testAssessment!.title}' : '✅ No Scam Indicators Detected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _testAssessment!.isSuspicious ? Nocturne.palette.expense : Nocturne.palette.income,
                          ),
                        ),
                        if (_testAssessment!.isSuspicious) ...[
                          const SizedBox(height: 4),
                          Text(_testAssessment!.reason ?? '', style: TextStyle(fontSize: 11, color: Nocturne.palette.neutral300)),
                          const SizedBox(height: 4),
                          Text('Advice: ${_testAssessment!.safetyAdvice}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Nocturne.palette.accentLight)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // The 4 Golden Rules for Parents
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.palette.faint),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🛡️ The 4 Golden Rules for Parents:', style: TextStyle(color: Nocturne.palette.text, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('1. UPI PIN is ONLY entered to SEND money, never to receive money or cashback.', style: TextStyle(fontSize: 11.5, color: Nocturne.palette.neutral300)),
                SizedBox(height: 4),
                Text('2. Power companies NEVER send SMS threatening disconnection tonight with a mobile number.', style: TextStyle(fontSize: 11.5, color: Nocturne.palette.neutral300)),
                SizedBox(height: 4),
                Text('3. NEVER install AnyDesk, RustDesk or TeamViewer on someone’s phone advice.', style: TextStyle(fontSize: 11.5, color: Nocturne.palette.neutral300)),
                SizedBox(height: 4),
                Text('4. Banks will NEVER ask you to click SMS links to update PAN or unblock YONO.', style: TextStyle(fontSize: 11.5, color: Nocturne.palette.neutral300)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 1: CREDIT CARD OPTIMIZER ("Which card should I use here?")
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCardsTab(V3State s) {
    final cards = s.creditCards;
    final recommendation = CardOptimizerService.findBestCard(
      familyCards: cards,
      merchantOrCategory: _selectedMerchant,
      amount: _testAmount,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interactive "Which card should I use?" widget
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Nocturne.palette.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.palette.tintEdge, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhFill.creditCard, color: Nocturne.palette.accentMuted, size: 18),
                    SizedBox(width: 8),
                    Text('Which card should I use here?', style: TextStyle(color: Nocturne.palette.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick merchant buttons
                Text('Where are you spending?', style: TextStyle(color: Nocturne.palette.subtle, fontSize: 11)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in ['Swiggy', 'Amazon', 'Airtel', 'BigBasket', 'Flipkart', 'Fuel', 'Flight'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(m, style: TextStyle(fontSize: 11, color: _selectedMerchant == m ? Nocturne.palette.bg : Nocturne.palette.text)),
                            selected: _selectedMerchant == m,
                            selectedColor: Nocturne.palette.accent,
                            backgroundColor: Nocturne.palette.surface,
                            onSelected: (_) => setState(() => _selectedMerchant = m),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Best card outcome
                if (recommendation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Nocturne.palette.income.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Nocturne.palette.income, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(PhFill.star, color: Nocturne.palette.income, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use: ${recommendation.card.cardName}',
                                style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${recommendation.perkReason} · You save ${V3Design.inr(recommendation.estimatedSavings)} on ${V3Design.inr(_testAmount)} spend',
                                style: TextStyle(color: Nocturne.palette.income, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Nocturne.palette.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Add your family credit cards below to see live cashback calculations.',
                      style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cards List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cards.length} Family Card(s)', style: TextStyle(color: Nocturne.palette.subtle, fontSize: 13)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Nocturne.palette.accent,
                  foregroundColor: Nocturne.palette.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddCardDialog,
                icon: const Icon(PhRegular.plus, size: 14),
                label: const Text('Add Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cards list
          if (cards.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(PhRegular.creditCard, size: 38, color: Nocturne.palette.faint),
                  const SizedBox(height: 8),
                  Text('No credit cards added yet', style: TextStyle(color: Nocturne.palette.text, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Add your family cards (HDFC Swiggy, SBI Cashback, ICICI Amazon)\nto maximize reward points and cashback on every family purchase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Nocturne.palette.subtle, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Nocturne.palette.accent, foregroundColor: Nocturne.palette.bg),
                    onPressed: _showAddCardDialog,
                    child: const Text('+ Add HDFC / SBI / ICICI Card'),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final c in cards) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Nocturne.palette.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.hasExpiringPoints ? Nocturne.palette.warning : Nocturne.palette.edge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Nocturne.palette.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.bank.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Nocturne.palette.accentMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.cardName,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nocturne.palette.text),
                          ),
                        ),
                        if (c.lastFour != null)
                          Text('•••• ${c.lastFour}', style: TextStyle(fontSize: 12, color: Nocturne.palette.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${NumberFormat.decimalPattern().format(c.rewardPointsBalance)} points',
                          style: TextStyle(fontSize: 12, color: Nocturne.palette.neutral300, fontWeight: FontWeight.w500),
                        ),
                        if (c.hasExpiringPoints) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Nocturne.palette.warning.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('⚠️ Expiring Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Nocturne.palette.warning)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final r in c.cashbackRules.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Nocturne.palette.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${r.key}: ${r.value}%',
                              style: TextStyle(fontSize: 10, color: Nocturne.palette.subtle),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badgeAlert;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Nocturne.palette.accent : Nocturne.palette.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeAlert ? Nocturne.palette.expense : (selected ? Nocturne.palette.accent : Nocturne.palette.edge),
            width: badgeAlert ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Nocturne.palette.bg : Nocturne.palette.text,
              ),
            ),
            if (badgeAlert) ...[
              const SizedBox(width: 4),
              Icon(PhFill.warning, size: 12, color: Nocturne.palette.expense),
            ],
          ],
        ),
      ),
    );
  }
}

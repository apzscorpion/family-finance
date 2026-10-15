import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/viral_magnets_service.dart';
import '../../theme/nocturne.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal bottom sheet for:
/// 1. "Let AI roast your spending" (funny shareable monthly roast cards)
/// 2. "Your family's own inflation rate" (personal cost of living index tracking staples)
/// 3. "Split with anyone, no app needed" (universal UPI shareable links)
class SpendRoastSheet extends StatefulWidget {
  final int initialTab;
  const SpendRoastSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => SpendRoastSheet(initialTab: initialTab),
    );
  }

  @override
  State<SpendRoastSheet> createState() => _SpendRoastSheetState();
}

class _SpendRoastSheetState extends State<SpendRoastSheet> {
  late int _tab;

  // Split with anyone state
  final TextEditingController _splitTitleCtrl = TextEditingController(text: 'Dinner Split');
  final TextEditingController _splitAmountCtrl = TextEditingController(text: '1200');
  int _splitCount = 3;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _splitTitleCtrl.dispose();
    _splitAmountCtrl.dispose();
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

          // Tab Selector
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: Row(
              children: [
                _buildTabBtn(0, '🔥 Spend Roast'),
                _buildTabBtn(1, '📈 Our Inflation'),
                _buildTabBtn(2, '⚡ Universal Split'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: _tab == 0
                ? _buildRoastTab(s)
                : (_tab == 1 ? _buildInflationTab(s) : _buildSplitTab(s)),
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
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Nocturne.text : Nocturne.neutral400,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SPEND ROAST
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRoastTab(V3State s) {
    final roast = ViralMagnetsService.generateRoast(s.txns);

    final shareText = '''
🔥 KinPurse roasted my spending this month:
"${roast.title}"
${roast.punchline}
📊 Stat: ${roast.highlightStat}
#KinPurseRoast
'''.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Roast Card (designed like a viral shareable poster)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1218), Color(0xFF1A0D10), Color(0xFF0F0B14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE53935), width: 0.8),
                      ),
                      child: Text(
                        '🔥 ${roast.categoryTag.toUpperCase()}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF8A80)),
                      ),
                    ),
                    const Spacer(),
                    const Text('KINPURSE AI', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Nocturne.neutral400)),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  roast.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  '"${roast.punchline}"',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: Nocturne.neutral200,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhRegular.lightning, size: 14, color: Nocturne.accent200),
                      const SizedBox(width: 6),
                      Text(
                        roast.highlightStat,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Nocturne.accent100),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
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
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Roast copied to clipboard.')),
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
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Share.share(shareText, subject: 'My Monthly Spending Roast');
                  },
                  icon: const Icon(PhRegular.shareNetwork, size: 16),
                  label: const Text('Share Roast', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: const Row(
              children: [
                Icon(PhRegular.sparkle, size: 18, color: Nocturne.accent200),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Roasts analyze your actual Swiggy, Uber, coffee and impulse buys. New funny punchlines generate every 30 days.',
                    style: TextStyle(color: Nocturne.neutral400, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. FAMILY INFLATION RATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildInflationTab(V3State s) {
    final inf = ViralMagnetsService.calculateInflation(s.txns);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Nocturne.accent800.withValues(alpha: 0.4), Nocturne.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Nocturne.accent600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Family\'s Personal Inflation Rate', style: TextStyle(color: Nocturne.neutral300, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '+${inf.overallInflationPct}%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Nocturne.accent100),
                    ),
                    const SizedBox(width: 8),
                    const Text('vs prior period', style: TextStyle(fontSize: 13, color: Nocturne.neutral400)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your household spent ${V3Design.inr(inf.currentSpend)} on staples this month, compared to ${V3Design.inr(inf.priorSpend)} in the previous period.',
                  style: const TextStyle(color: Nocturne.neutral300, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Essential Staples Breakdown:', style: TextStyle(color: Nocturne.text, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildInflationItem(
            title: 'Groceries & Provisions',
            changePct: inf.groceryChangePct,
            desc: 'Milk, vegetables, cooking oil and supermarket orders.',
            icon: PhRegular.basket,
          ),
          _buildInflationItem(
            title: 'Fuel & Commute',
            changePct: inf.fuelChangePct,
            desc: 'Petrol, diesel, and recurring travel expenses.',
            icon: PhRegular.gasPump,
          ),
          _buildInflationItem(
            title: 'Utilities & Household Bills',
            changePct: inf.utilityChangePct,
            desc: 'Electricity, LPG cylinder, piped gas, and water.',
            icon: PhRegular.lightning,
          ),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.neutral800),
            ),
            child: const Row(
              children: [
                Icon(PhRegular.info, size: 16, color: Nocturne.neutral400),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unlike national CPI surveys, this inflation index is calculated exclusively from what your family actually paid for recurring essentials.',
                    style: TextStyle(color: Nocturne.neutral400, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInflationItem({
    required String title,
    required double changePct,
    required String desc,
    required IconData icon,
  }) {
    final isIncrease = changePct >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nocturne.neutral800),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Nocturne.accent200),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Nocturne.text, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Nocturne.neutral400, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isIncrease ? NocturneSemantic.expense : NocturneSemantic.income).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isIncrease ? PhRegular.trendUp : PhRegular.trendDown,
                  size: 13,
                  color: isIncrease ? NocturneSemantic.expense : NocturneSemantic.income,
                ),
                const SizedBox(width: 3),
                Text(
                  '${isIncrease ? '+' : ''}$changePct%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isIncrease ? NocturneSemantic.expense : NocturneSemantic.income,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. UNIVERSAL WEB SPLIT (NO APP NEEDED)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSplitTab(V3State s) {
    final total = double.tryParse(_splitAmountCtrl.text.trim()) ?? 0.0;
    final perPerson = _splitCount > 0 ? total / _splitCount : 0.0;
    final myMember = s.members.cast<MemberRow?>().firstWhere(
          (m) => m?.userId == s.myId,
          orElse: () => null,
        );
    final myUpi = myMember?.upiId ?? 'yourname@okhdfcbank';
    final myName = myMember?.name ?? 'Me';

    final shareMsg = ViralMagnetsService.buildShareMessage(
      title: _splitTitleCtrl.text.trim(),
      totalAmount: total,
      splitCount: _splitCount,
      perPersonAmount: perPerson,
      receiverName: myName,
      upiId: myUpi,
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
                const Row(
                  children: [
                    Icon(PhRegular.shareNetwork, size: 18, color: Nocturne.accent200),
                    SizedBox(width: 8),
                    Text('Split with anyone — no app needed', style: TextStyle(color: Nocturne.text, fontSize: 13.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Send a WhatsApp link to friends. Tapping it opens their Google Pay / PhonePe with your share amount already filled in.',
                  style: TextStyle(color: Nocturne.neutral300, fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _splitTitleCtrl,
                        style: const TextStyle(color: Nocturne.text, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'What is this for?',
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
                        controller: _splitAmountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Nocturne.text, fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Total (₹)',
                          labelStyle: TextStyle(color: Nocturne.neutral400, fontSize: 12),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // People counter
                Row(
                  children: [
                    const Text('Split between:', style: TextStyle(color: Nocturne.neutral300, fontSize: 12)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(PhRegular.minus, size: 16, color: Nocturne.accent200),
                      onPressed: _splitCount > 2 ? () => setState(() => _splitCount--) : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Nocturne.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$_splitCount people', style: const TextStyle(color: Nocturne.text, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(PhRegular.plus, size: 16, color: Nocturne.accent200),
                      onPressed: () => setState(() => _splitCount++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Per-person outcome
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NocturneSemantic.income.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NocturneSemantic.income, width: 1),
            ),
            child: Row(
              children: [
                const Icon(PhRegular.coins, color: NocturneSemantic.income, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Each person pays: ${V3Design.inr(perPerson)}',
                        style: const TextStyle(color: Nocturne.text, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Will be paid to UPI ID: $myUpi',
                        style: const TextStyle(color: NocturneSemantic.income, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Share Actions
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
                    Clipboard.setData(ClipboardData(text: shareMsg));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Split payment link copied to clipboard.')),
                    );
                  },
                  icon: const Icon(PhRegular.copy, size: 16),
                  label: const Text('Copy Message'),
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
                    Share.share(shareMsg, subject: 'Split for ${_splitTitleCtrl.text}');
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
}

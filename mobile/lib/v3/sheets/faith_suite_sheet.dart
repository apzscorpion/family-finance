import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
// import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';

/// Modal sheet for Zakat calculation, gold & silver holdings, and Sadaqah tracking.
class FaithSuiteSheet extends StatefulWidget {
  const FaithSuiteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA306070E),
      isScrollControlled: true,
      builder: (_) => const FaithSuiteSheet(),
    );
  }

  @override
  State<FaithSuiteSheet> createState() => _FaithSuiteSheetState();
}

class _FaithSuiteSheetState extends State<FaithSuiteSheet> {
  int _tab = 0; // 0 = Zakat Calculator, 1 = Gold Tracker, 2 = Sadaqah

  // Current market benchmark rates (configurable in UI)
  double _goldPerGram = 7250.0; // ₹ per gram 24K
  final double _silverPerGram = 92.0; // ₹ per gram

  // Additional cash / business assets for zakat
  final double _extraSavings = 0.0;
  final double _debtsOwed = 0.0;

  // Nisab threshold constant (Silver nisab: 595 grams standard)
  static const double silverNisabGrams = 595.0;

  void _showAddGoldDialog() {
    final s = context.read<V3State>();
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    int purity = 22;
    String metal = 'gold';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Nocturne.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Add Precious Metal', style: TextStyle(color: Nocturne.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Nocturne.text),
                decoration: const InputDecoration(
                  labelText: 'Item Name (e.g. Bangles, Coin, Bar)',
                  labelStyle: TextStyle(color: Nocturne.neutral400),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: metal,
                      dropdownColor: Nocturne.surface,
                      items: const [
                        DropdownMenuItem(value: 'gold', child: Text('Gold')),
                        DropdownMenuItem(value: 'silver', child: Text('Silver')),
                      ],
                      onChanged: (v) => setDialogState(() => metal = v ?? 'gold'),
                    ),
                  ),
                  if (metal == 'gold') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<int>(
                        value: purity,
                        dropdownColor: Nocturne.surface,
                        items: const [
                          DropdownMenuItem(value: 24, child: Text('24K (99.9%)')),
                          DropdownMenuItem(value: 22, child: Text('22K (91.6%)')),
                          DropdownMenuItem(value: 18, child: Text('18K (75%)')),
                        ],
                        onChanged: (v) => setDialogState(() => purity = v ?? 22),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Nocturne.text),
                decoration: const InputDecoration(
                  labelText: 'Weight in Grams',
                  labelStyle: TextStyle(color: Nocturne.neutral400),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Nocturne.neutral400)),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightCtrl.text) ?? 0.0;
                final name = nameCtrl.text.trim();
                if (weight > 0 && name.isNotEmpty) {
                  await s.addGoldHolding(
                    itemName: name,
                    metalType: metal,
                    weightGrams: weight,
                    purityKarat: metal == 'gold' ? purity : 24,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Nocturne.accent),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final maxH = MediaQuery.of(context).size.height * 0.92;

    // Total gold and silver valuation
    final goldValue = s.totalGoldGrams * _goldPerGram;
    final silverValue = s.totalSilverGrams * _silverPerGram;
    final liquidCash = s.balance > 0 ? s.balance : 0.0;

    // Net Zakatable Wealth
    final totalZakatable = (liquidCash + goldValue + silverValue + _extraSavings - _debtsOwed).clamp(0.0, double.infinity);

    // Silver Nisab threshold value (standard traditional benchmark)
    final silverNisabValue = silverNisabGrams * _silverPerGram;
    final isZakatObligatory = totalZakatable >= silverNisabValue;
    final zakatDue = isZakatObligatory ? (totalZakatable * 0.025) : 0.0;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral800, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet pill
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.neutral700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              const Icon(PhFill.starAndCrescent, size: 22, color: Color(0xFFEAB308)),
              const SizedBox(width: 8),
              const Text(
                'Zakat & Faith Suite',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.text,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(PhRegular.x, size: 20, color: Nocturne.neutral400),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar
          Row(
            children: [
              _TabPill(
                label: 'Zakat Calc',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Gold (${s.totalGoldGrams.toStringAsFixed(1)}g)',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Sadaqah Log',
                selected: _tab == 2,
                onTap: () => setState(() => _tab = 2),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Body
          Expanded(
            child: switch (_tab) {
              0 => _buildZakatCalculator(
                  s: s,
                  liquidCash: liquidCash,
                  goldValue: goldValue,
                  silverValue: silverValue,
                  totalZakatable: totalZakatable,
                  silverNisabValue: silverNisabValue,
                  isZakatObligatory: isZakatObligatory,
                  zakatDue: zakatDue,
                ),
              1 => _buildGoldTracker(s),
              2 => _buildSadaqahTracker(s),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZakatCalculator({
    required V3State s,
    required double liquidCash,
    required double goldValue,
    required double silverValue,
    required double totalZakatable,
    required double silverNisabValue,
    required bool isZakatObligatory,
    required double zakatDue,
  }) {
    return ListView(
      children: [
        // Zakat Due Hero Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E230B), Color(0xFF1E1E28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ZAKAT PAYABLE (2.5%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDE047),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isZakatObligatory
                          ? const Color(0xFF15803D).withValues(alpha: 0.3)
                          : Nocturne.neutral800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isZakatObligatory ? 'Above Nisab' : 'Below Nisab',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isZakatObligatory ? const Color(0xFF4ADE80) : Nocturne.neutral400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isZakatObligatory ? V3Design.inr(zakatDue) : '₹0',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Calculated on ${V3Design.inr(totalZakatable)} net wealth (Silver Nisab benchmark: ${V3Design.inr(silverNisabValue)})',
                style: const TextStyle(fontSize: 11, color: Nocturne.neutral400),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'Wealth Breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nocturne.text),
        ),
        const SizedBox(height: 8),

        _BreakdownRow(
          title: 'Account & Cash Balances',
          subtitle: 'From active bank & savings accounts',
          amount: V3Design.inr(liquidCash),
        ),
        _BreakdownRow(
          title: 'Gold Holdings (${s.totalGoldGrams.toStringAsFixed(1)}g)',
          subtitle: '@ ₹${_goldPerGram.toInt()}/g (24K benchmark)',
          amount: V3Design.inr(goldValue),
        ),
        _BreakdownRow(
          title: 'Silver Holdings (${s.totalSilverGrams.toStringAsFixed(1)}g)',
          subtitle: '@ ₹${_silverPerGram.toInt()}/g benchmark',
          amount: V3Design.inr(silverValue),
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gold Rate per Gram (₹):',
              style: TextStyle(fontSize: 12.5, color: Nocturne.neutral400),
            ),
            SizedBox(
              width: 100,
              height: 36,
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, color: Nocturne.text),
                decoration: InputDecoration(
                  hintText: '$_goldPerGram',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed > 0) {
                    setState(() => _goldPerGram = parsed);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoldTracker(V3State s) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Family Precious Metals (${s.goldHoldings.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nocturne.text),
            ),
            ElevatedButton.icon(
              onPressed: _showAddGoldDialog,
              icon: const Icon(PhBold.plus, size: 14),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: s.goldHoldings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhRegular.coins, size: 40, color: Nocturne.neutral600),
                      const SizedBox(height: 8),
                      const Text(
                        'No gold or silver items added yet',
                        style: TextStyle(fontSize: 13, color: Nocturne.neutral400),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _showAddGoldDialog,
                        child: const Text('Add your first holding'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: s.goldHoldings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = s.goldHoldings[i];
                    final isGold = item.metalType == 'gold';
                    final estValue = isGold
                        ? item.pure24kGrams * _goldPerGram
                        : item.weightGrams * _silverPerGram;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Nocturne.neutral800),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isGold
                                  ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                                  : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              PhBold.coins,
                              color: isGold ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Nocturne.text,
                                  ),
                                ),
                                Text(
                                  isGold
                                      ? '${item.weightGrams}g (${item.purityKarat}K) · Pure: ${item.pure24kGrams.toStringAsFixed(1)}g'
                                      : '${item.weightGrams}g Silver',
                                  style: const TextStyle(fontSize: 11.5, color: Nocturne.neutral400),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                V3Design.inr(estValue),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Nocturne.text,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(PhRegular.trash, size: 14, color: NocturneSemantic.expense),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () => s.deleteGoldHolding(item.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSadaqahTracker(V3State s) {
    final charityTxns = s.txns.where((t) =>
        t.isExpense &&
        (t.categoryKey.toLowerCase() == 'charity' ||
            t.title.toLowerCase().contains('sadaqah') ||
            t.title.toLowerCase().contains('charity') ||
            t.title.toLowerCase().contains('zakat'))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Nocturne.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(PhFill.handCoins, size: 28, color: Color(0xFF34D399)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL GIVING THIS YEAR',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    V3Design.inr(s.totalCharityGiven),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Nocturne.text),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Donation Log',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nocturne.text),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: charityTxns.isEmpty
              ? const Center(
                  child: Text(
                    'No donations recorded under Charity / Sadaqah yet',
                    style: TextStyle(fontSize: 12.5, color: Nocturne.neutral500),
                  ),
                )
              : ListView.separated(
                  itemCount: charityTxns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final txn = charityTxns[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Nocturne.neutral800),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhBold.handCoins, size: 16, color: Color(0xFF34D399)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  txn.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.text,
                                  ),
                                ),
                                Text(
                                  '${txn.occurredAt.day}/${txn.occurredAt.month}/${txn.occurredAt.year}',
                                  style: const TextStyle(fontSize: 11, color: Nocturne.neutral400),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            V3Design.inr(txn.amount),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nocturne.text),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Nocturne.accent : Nocturne.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Nocturne.accent : Nocturne.neutral800,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Nocturne.neutral300,
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;

  const _BreakdownRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Nocturne.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Nocturne.neutral800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Nocturne.text)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Nocturne.neutral500)),
            ],
          ),
          Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nocturne.text)),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';
import '../services/note_import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add_sheet.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  String? _selectedCardFilterId;

  String _formatInr(double n) => '₹${n.round()}';

  static const List<Map<String, dynamic>> _cardPalettes = [
    {'name': 'Royal Indigo', 'hex': 0xFF312E81},
    {'name': 'Emerald Teal', 'hex': 0xFF0F766E},
    {'name': 'Crimson Gold', 'hex': 0xFF7C2D12},
    {'name': 'Midnight Blue', 'hex': 0xFF1E3A8A},
    {'name': 'Amethyst Purple', 'hex': 0xFF4C1D95},
    {'name': 'Obsidian Slate', 'hex': 0xFF1F2937},
  ];

  static const List<Map<String, dynamic>> _quickBankPresets = [
    {'bank': 'HDFC Bank', 'card': 'Regalia Gold', 'network': 'Visa', 'type': 'Credit', 'limit': 200000.0, 'hex': 0xFF1E3A8A},
    {'bank': 'SBI Card', 'card': 'Cashback SBI', 'network': 'Visa', 'type': 'Credit', 'limit': 150000.0, 'hex': 0xFF312E81},
    {'bank': 'ICICI Bank', 'card': 'Amazon Pay', 'network': 'Visa', 'type': 'Credit', 'limit': 180000.0, 'hex': 0xFF7C2D12},
    {'bank': 'Axis Bank', 'card': 'Flipkart Axis', 'network': 'Mastercard', 'type': 'Credit', 'limit': 120000.0, 'hex': 0xFF831843},
    {'bank': 'HDFC Bank', 'card': ' Tata Neu UPI', 'network': 'RuPay', 'type': 'RuPay UPI', 'limit': 100000.0, 'hex': 0xFF4C1D95},
    {'bank': 'Kotak Bank', 'card': 'League Platinum', 'network': 'Visa', 'type': 'Credit', 'limit': 100000.0, 'hex': 0xFF0F766E},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final cards = provider.cards;
    final totalLimit = provider.totalCreditLimit;
    final totalUsed = provider.totalCreditUsed;
    final totalAvail = provider.totalAvailableCredit;
    final utilPct = provider.totalCreditUtilizationPct;

    final Color utilColor = utilPct >= 70
        ? AppTheme.red
        : (utilPct >= 30 ? AppTheme.amber : AppTheme.green);
    final String utilHealthLabel = utilPct >= 70
        ? 'High Usage (>70%)'
        : (utilPct >= 30 ? 'Moderate (${utilPct.round()}%)' : 'Healthy (<30%)');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.text),
          onPressed: () => provider.closeSubPage(),
        ),
        title: const Text(
          'Cards & Auto Credit Usage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.text),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddOrEditCardModal(context, provider),
            icon: const Icon(Icons.add_card, size: 17, color: AppTheme.accent200),
            label: const Text(
              'Add Card',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.accent200),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Total Credit Usage Summary Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: AppTheme.balanceGradient,
                border: Border.all(color: AppTheme.accent700),
                boxShadow: const [AppTheme.shadowMd],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL CREDIT USAGE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent200,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: utilColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: utilColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          utilHealthLabel,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: utilColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        provider.balanceHidden ? '₹ •••••' : _formatInr(totalUsed),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.balanceHidden ? '/ ₹ •••••' : 'used of ${_formatInr(totalLimit)}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.accent200),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalLimit > 0 ? (totalUsed / totalLimit).clamp(0.0, 1.0) : 0.0,
                      minHeight: 8,
                      backgroundColor: Colors.black38,
                      valueColor: AlwaysStoppedAnimation<Color>(utilColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBox(
                          label: 'AVAILABLE CREDIT',
                          value: provider.balanceHidden ? '₹ ••••' : _formatInr(totalAvail),
                          valueColor: AppTheme.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricBox(
                          label: 'UTILIZATION',
                          value: '${utilPct.toStringAsFixed(1)}%',
                          valueColor: utilColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricBox(
                          label: 'TOTAL CARDS',
                          value: '${cards.length}',
                          valueColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Automatic Credit Usage Bar (Auto-Scan SMS / Clipboard, Import Statement PDF/CSV, Auto-Recurring)
            const Text(
              'Automatic Credit Usage Tools',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAutoActionChip(
                    icon: Icons.bolt_rounded,
                    label: 'Auto-Scan Bank Alert / SMS',
                    color: AppTheme.accent300,
                    onTap: () => _showAutoScanAlertDialog(context, provider),
                  ),
                  const SizedBox(width: 8),
                  _buildAutoActionChip(
                    icon: Icons.upload_file_rounded,
                    label: 'Import Card Statement (PDF/CSV)',
                    color: const Color(0xFF34D399),
                    onTap: () => _importCardStatementFile(context, provider),
                  ),
                  const SizedBox(width: 8),
                  _buildAutoActionChip(
                    icon: Icons.autorenew_rounded,
                    label: 'Add Auto-Charge / EMI',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _showAddAutoChargeModal(context, provider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Total Card List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Card List (${cards.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text),
                ),
                if (_selectedCardFilterId != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedCardFilterId = null),
                    child: const Text('Show All Cards', style: TextStyle(fontSize: 12, color: AppTheme.accent300)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Empty State with 1-Tap Popular Card Presets
            if (cards.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3F424D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.accent900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.credit_card, color: AppTheme.accent200),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No cards added yet',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Add your credit/debit cards below or tap a quick preset to start tracking automatic credit usage.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '1-TAP QUICK ADD PRESETS:',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.textSubtle, letterSpacing: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickBankPresets.map((preset) {
                        return ActionChip(
                          avatar: const Icon(Icons.add_card, size: 15, color: AppTheme.accent200),
                          label: Text(
                            '${preset['bank']} ${preset['card']}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.text),
                          ),
                          backgroundColor: AppTheme.bg,
                          side: const BorderSide(color: Color(0xFF3F424D)),
                          onPressed: () => _showAddOrEditCardModal(
                            context,
                            provider,
                            preset: preset,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAddOrEditCardModal(context, provider),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Custom Credit / Debit Card', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...cards.map((card) => _buildCreditCardTile(context, provider, card)),

            const SizedBox(height: 20),

            // 4. Automatic Recurring Card Charges (EMIs & Subscriptions)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3F424D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.autorenew_rounded, size: 18, color: AppTheme.amber),
                          SizedBox(width: 8),
                          Text(
                            'Auto Credit Usage (EMIs & Subscriptions)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _showAddAutoChargeModal(context, provider),
                        child: const Text('+ Add', style: TextStyle(fontSize: 12, color: AppTheme.accent300)),
                      ),
                    ],
                  ),
                  if (provider.autoCharges.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Set up monthly EMIs, Netflix, Wi-Fi, or utility bills so they automatically add to your card\'s credit usage on their billing day.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    )
                  else
                    ...provider.autoCharges.map((ac) {
                      final card = provider.cardById(ac.cardId);
                      final cat = FinanceProvider.categories[ac.catKey] ?? FinanceProvider.categories['bills']!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(cat.icon, size: 18, color: cat.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ac.title,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.text),
                                  ),
                                  Text(
                                    '${card?.shortLabel ?? 'Card'} · Day ${ac.dayOfMonth} every month',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSubtle),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatInr(ac.amount),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.text),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () => provider.triggerAutoChargeNow(ac),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                backgroundColor: AppTheme.accent900,
                              ),
                              child: const Text('Charge', style: TextStyle(fontSize: 11, color: AppTheme.accent200)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.textSubtle),
                              onPressed: () => provider.deleteAutoCardCharge(ac.id),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Card Transactions List
            Text(
              _selectedCardFilterId == null
                  ? 'Recent Card Usage Activity'
                  : 'Activity · ${provider.cardById(_selectedCardFilterId)?.shortLabel ?? 'Selected Card'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text),
            ),
            const SizedBox(height: 10),
            _buildCardTransactionsList(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textSubtle),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAutoActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardTile(BuildContext context, FinanceProvider provider, CreditCardDef card) {
    final used = provider.cardUsedAmount(card.id);
    final avail = provider.cardAvailableCredit(card.id);
    final util = provider.cardUtilizationPct(card.id);
    final isSelected = _selectedCardFilterId == card.id;
    final holder = provider.members.firstWhere(
      (m) => m.id == card.holderMemberId,
      orElse: () => provider.members.first,
    );

    final Color baseColor = Color(card.colorHex);
    final Color barColor = util >= 75
        ? AppTheme.red
        : (util >= 35 ? AppTheme.amber : const Color(0xFF4ADE80));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardFilterId = isSelected ? null : card.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor,
              Color.lerp(baseColor, Colors.black, 0.45) ?? Colors.black87,
            ],
          ),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: const [AppTheme.shadowMd],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Bank + Card Name + Network Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.displayTitle,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${card.cardType} · ${holder.name} · Bill Day ${card.billingDay} · Due Day ${card.dueDay}',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    card.network.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Masked Card Number & Auto-Track Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '••••  ••••  ••••  ${card.last4}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${util.toStringAsFixed(1)}% used',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Utilization Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: card.creditLimit > 0 ? (used / card.creditLimit).clamp(0.0, 1.0) : 0.0,
                minHeight: 6,
                backgroundColor: Colors.black38,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 12),

            // Used / Available / Total Limit Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('USED', style: TextStyle(fontSize: 10, color: Colors.white60)),
                    Text(
                      provider.balanceHidden ? '₹ ••••' : _formatInr(used),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AVAILABLE', style: TextStyle(fontSize: 10, color: Colors.white60)),
                    Text(
                      provider.balanceHidden ? '₹ ••••' : _formatInr(avail),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CREDIT LIMIT', style: TextStyle(fontSize: 10, color: Colors.white60)),
                    Text(
                      provider.balanceHidden ? '₹ ••••' : _formatInr(card.creditLimit),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // Card Actions Row: + Spend, Pay Bill, Edit, Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    QuickAddSheet.show(
                      context,
                      type: 'expense',
                      initialMethod: 'Card',
                      initialCardId: card.id,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text('Spend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showPayCardBillDialog(context, provider, card, used),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF4ADE80)),
                        SizedBox(width: 5),
                        Text('Pay Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4ADE80))),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                  onPressed: () => _showAddOrEditCardModal(context, provider, existing: card),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit Card',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
                  onPressed: () => provider.deleteCard(card.id),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove Card',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTransactionsList(BuildContext context, FinanceProvider provider) {
    final txns = _selectedCardFilterId != null
        ? provider.transactionsForCard(_selectedCardFilterId!)
        : provider.transactions.where((t) => t.method.toLowerCase() == 'card' || t.cardId != null).toList();

    if (txns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.textSubtle),
            SizedBox(height: 6),
            Text('No card transactions recorded yet', style: TextStyle(fontSize: 13.5, color: AppTheme.text)),
            SizedBox(height: 2),
            Text(
              'Spend on a card, scan a bank SMS alert, or import a statement to see live credit usage.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSubtle),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: txns.take(25).map((t) {
          final cat = FinanceProvider.categories[t.catKey] ?? FinanceProvider.categories['shopping']!;
          final card = provider.cardById(t.cardId);
          final isIncome = t.type == 'income';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(cat.icon, size: 18, color: cat.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.text)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${t.time} · ${card?.shortLabel ?? 'Card'}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          ),
                          if (t.origin == 'auto_card') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accent900,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'AUTO',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accent200),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '-' : '+'}${_formatInr(t.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? AppTheme.green : AppTheme.red,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddOrEditCardModal(
    BuildContext context,
    FinanceProvider provider, {
    CreditCardDef? existing,
    Map<String, dynamic>? preset,
  }) {
    final bankCtrl = TextEditingController(
      text: existing?.bankName ?? (preset?['bank'] as String?) ?? 'HDFC Bank',
    );
    final nameCtrl = TextEditingController(
      text: existing?.cardName ?? (preset?['card'] as String?) ?? '',
    );
    final last4Ctrl = TextEditingController(
      text: existing?.last4 ?? '',
    );
    final limitCtrl = TextEditingController(
      text: existing != null
          ? existing.creditLimit.round().toString()
          : ((preset?['limit'] as double?)?.round().toString() ?? '150000'),
    );
    final usedCtrl = TextEditingController(
      text: existing != null && existing.openingUsed > 0 ? existing.openingUsed.round().toString() : '0',
    );
    final billDayCtrl = TextEditingController(
      text: (existing?.billingDay ?? 15).toString(),
    );
    final dueDayCtrl = TextEditingController(
      text: (existing?.dueDay ?? 5).toString(),
    );

    String network = existing?.network ?? (preset?['network'] as String?) ?? 'Visa';
    String cardType = existing?.cardType ?? (preset?['type'] as String?) ?? 'Credit';
    int colorHex = existing?.colorHex ?? (preset?['hex'] as int?) ?? 0xFF312E81;
    String holderId = existing?.holderMemberId ?? 'me';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existing == null ? 'Add Credit / Debit Card' : 'Edit Card Details',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(bankCtrl, 'Bank Name (e.g. HDFC, SBI)', Icons.account_balance_outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(nameCtrl, 'Card Variant (e.g. Regalia)', Icons.credit_card),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(last4Ctrl, 'Last 4 Digits (e.g. 4821)', Icons.pin_outlined, isNumber: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(limitCtrl, 'Total Credit Limit (₹)', Icons.speed_outlined, isNumber: true),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(usedCtrl, 'Current Used Balance (₹)', Icons.receipt_long_outlined, isNumber: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(billDayCtrl, 'Bill Day (1-28)', Icons.calendar_today_outlined, isNumber: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(dueDayCtrl, 'Due Day (1-28)', Icons.event_available_outlined, isNumber: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Network & Card Type Selector
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Visa', 'Mastercard', 'RuPay', 'Amex'].map((n) {
                    final sel = network == n;
                    return ChoiceChip(
                      label: Text(n, style: TextStyle(fontSize: 11.5, color: sel ? AppTheme.accent100 : AppTheme.textMuted)),
                      selected: sel,
                      onSelected: (_) => setModalState(() => network = n),
                      backgroundColor: AppTheme.bg,
                      selectedColor: AppTheme.accent900,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Credit', 'RuPay UPI', 'Debit'].map((t) {
                    final sel = cardType == t;
                    return ChoiceChip(
                      label: Text(t, style: TextStyle(fontSize: 11.5, color: sel ? AppTheme.accent100 : AppTheme.textMuted)),
                      selected: sel,
                      onSelected: (_) => setModalState(() => cardType = t),
                      backgroundColor: AppTheme.bg,
                      selectedColor: AppTheme.accent900,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // Color Swatches
                Row(
                  children: [
                    const Text('Card Theme: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 6),
                    ..._cardPalettes.map((p) {
                      final hex = p['hex'] as int;
                      final sel = colorHex == hex;
                      return GestureDetector(
                        onTap: () => setModalState(() => colorHex = hex),
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(hex),
                            shape: BoxShape.circle,
                            border: Border.all(color: sel ? Colors.white : Colors.white24, width: sel ? 2.2 : 1),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final bank = bankCtrl.text.trim().isNotEmpty ? bankCtrl.text.trim() : 'Bank';
                      final name = nameCtrl.text.trim();
                      final rawLast4 = last4Ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final last4 = rawLast4.length >= 4
                          ? rawLast4.substring(rawLast4.length - 4)
                          : rawLast4.padLeft(4, '0');
                      final limit = double.tryParse(limitCtrl.text.replaceAll(',', '').trim()) ?? 100000.0;
                      final used = double.tryParse(usedCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                      final billDay = (int.tryParse(billDayCtrl.text.trim()) ?? 15).clamp(1, 28);
                      final dueDay = (int.tryParse(dueDayCtrl.text.trim()) ?? 5).clamp(1, 28);

                      final card = CreditCardDef(
                        id: existing?.id ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
                        bankName: bank,
                        cardName: name,
                        last4: last4,
                        network: network,
                        cardType: cardType,
                        creditLimit: limit,
                        openingUsed: used,
                        billingDay: billDay,
                        dueDay: dueDay,
                        colorHex: colorHex,
                        holderMemberId: holderId,
                      );
                      await provider.addOrUpdateCard(card);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      existing == null ? 'Save Card to Total Card List' : 'Update Card',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 13.5, color: AppTheme.text),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 17, color: AppTheme.accent300),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3F424D)),
        ),
      ),
    );
  }

  void _showPayCardBillDialog(
    BuildContext context,
    FinanceProvider provider,
    CreditCardDef card,
    double currentUsed,
  ) {
    final amtCtrl = TextEditingController(
      text: currentUsed > 0 ? currentUsed.round().toString() : '',
    );
    String payFrom = 'Bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay Bill · ${card.shortLabel}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Used: ${_formatInr(currentUsed)} · Available: ${_formatInr(provider.cardAvailableCredit(card.id))}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              _buildField(amtCtrl, 'Payment Amount (₹)', Icons.currency_rupee, isNumber: true),
              const SizedBox(height: 12),
              const Text('Pay From Account:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Bank', 'UPI', 'Cash', 'Salary'].map((acct) {
                  final sel = payFrom == acct;
                  return ChoiceChip(
                    label: Text('$acct (₹${provider.accountBalance(acct).round()})'),
                    selected: sel,
                    onSelected: (_) => setModalState(() => payFrom = acct),
                    backgroundColor: AppTheme.bg,
                    selectedColor: AppTheme.accent900,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amtCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                    if (amt <= 0) return;
                    await provider.payCardBill(
                      cardId: card.id,
                      amount: amt,
                      payFromAccount: payFrom,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Record Bill Payment & Restore Credit Limit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoScanAlertDialog(BuildContext context, FinanceProvider provider) {
    final textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppTheme.accent300),
                    SizedBox(width: 8),
                    Text(
                      'Auto-Detect Credit Card Usage',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Text(
              'Paste one or more bank SMS/email alerts below, or tap "Paste Clipboard". It automatically detects the bank, card last 4 digits, amount, merchant, and available credit limit!',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      textCtrl.text = data.text!.trim();
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 15),
                  label: const Text('Paste Clipboard', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    textCtrl.text =
                        'Alert: Rs. 2,450.00 spent on your HDFC Bank Credit Card ending 4821 at SWIGGY on 05-Oct. Avl Limit: Rs. 1,97,550. Total Limit: Rs. 2,00,000.\n\n'
                        'INR 5,890.00 spent on SBI Card ending 9012 at AMAZON on 05-Oct. Available Limit Rs. 1,44,110.';
                  },
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('Try Sample Alerts', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.text, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. Rs. 1,450 spent on HDFC Bank Credit Card ending 4821 at Amazon. Avl Limit: Rs. 1,85,000',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                filled: true,
                fillColor: AppTheme.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final count = await provider.autoParseBankOrCardAlert(textCtrl.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (count == 0) {
                      provider.showToast('No valid card amount found in text');
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Auto-Detect & Update Credit Usage', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCardStatementFile(BuildContext context, FinanceProvider provider) async {
    final doc = await NoteImportService.pickNativeDocument(type: 'any');
    if (doc == null || doc.text.trim().isEmpty) {
      provider.showToast('No statement text found in file');
      return;
    }
    final count = await provider.autoParseBankOrCardAlert(doc.text);
    if (count == 0) {
      provider.showToast('Could not detect card transactions in ${doc.fileName}');
    }
  }

  void _showAddAutoChargeModal(BuildContext context, FinanceProvider provider) {
    if (provider.cards.isEmpty) {
      provider.showToast('Add a card first to set up automatic charges');
      _showAddOrEditCardModal(context, provider);
      return;
    }

    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '5');
    String selectedCardId = provider.cards.first.id;
    String selectedCat = 'bills';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Automatic Monthly Card Charge / EMI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text),
              ),
              const SizedBox(height: 10),
              _buildField(titleCtrl, 'Title (e.g. Netflix, Phone EMI, Wi-Fi)', Icons.autorenew_rounded),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildField(amtCtrl, 'Monthly Amount (₹)', Icons.currency_rupee, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(dayCtrl, 'Billing Day (1-28)', Icons.calendar_today, isNumber: true)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Select Card:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: provider.cards.map((c) {
                  final sel = selectedCardId == c.id;
                  return ChoiceChip(
                    label: Text(c.shortLabel),
                    selected: sel,
                    onSelected: (_) => setModalState(() => selectedCardId = c.id),
                    backgroundColor: AppTheme.bg,
                    selectedColor: AppTheme.accent900,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final amt = double.tryParse(amtCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
                    final day = (int.tryParse(dayCtrl.text.trim()) ?? 1).clamp(1, 28);
                    if (title.isEmpty || amt <= 0) return;

                    await provider.addAutoCardCharge(
                      AutoCardCharge(
                        id: 'ac_${DateTime.now().millisecondsSinceEpoch}',
                        cardId: selectedCardId,
                        title: title,
                        amount: amt,
                        catKey: selectedCat,
                        dayOfMonth: day,
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Automatic Card Charge', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

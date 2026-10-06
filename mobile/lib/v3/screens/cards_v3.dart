import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Cards & accounts: the card carousel with utilisation, then money sources
/// as running balances.
class CardsV3 extends StatelessWidget {
  const CardsV3({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const _Kicker('Credit cards'),
        if (s.cards.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Nocturne.neutral900, width: 1),
            ),
            child: Column(
              children: [
                const Icon(PhRegular.creditCard,
                    size: 32, color: Nocturne.neutral600),
                const SizedBox(height: 10),
                const Text('No cards yet',
                    style:
                        TextStyle(fontSize: 14, color: Nocturne.neutral300)),
                const SizedBox(height: 4),
                const Text('Add a card to track its limit and dues',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Nocturne.neutral500)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _addCard(context, s),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Nocturne.accent, width: 1),
                    ),
                    child: const Text('Add card',
                        style: TextStyle(
                            fontSize: 13, color: Nocturne.accent200)),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: s.cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _CardTile(index: i),
            ),
          ),
        const _Kicker('Accounts'),
        V3Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < s.sources.length; i++) ...[
                Builder(builder: (_) {
                  final src = s.sources[i];
                  final t = s.sourceTotals(src.id);
                  final bal = src.openingBalance + t.inAmt - t.outAmt;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        V3IconTile(
                            icon: src.design.icon,
                            color: src.design.color,
                            size: 38,
                            radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(src.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5, color: Nocturne.text)),
                              Text(
                                  'In ${s.moneyShort(t.inAmt)} · '
                                  'Spent ${s.moneyShort(t.outAmt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Nocturne.neutral500)),
                            ],
                          ),
                        ),
                        V3Num(s.money(bal),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: bal >= 0
                                    ? Nocturne.text
                                    : NocturneSemantic.expense)),
                      ],
                    ),
                  );
                }),
                if (i < s.sources.length - 1) const V3RowDivider(),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Balances are tracked from your entries and detected payments — '
            'not pulled live from your bank.',
            style: TextStyle(
                fontSize: 11.5, height: 1.5, color: Nocturne.neutral500),
          ),
        ),
      ],
    );
  }

  static Future<void> _addCard(BuildContext context, V3State s) async {
    final label = TextEditingController();
    final last4 = TextEditingController();
    final limit = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: const Text('Add card',
            style: TextStyle(fontSize: 17, color: Nocturne.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: label, hint: 'Card name (e.g. HDFC Regalia)'),
            const SizedBox(height: 10),
            _Field(controller: last4, hint: 'Last 4 digits', digits: true),
            const SizedBox(height: 10),
            _Field(controller: limit, hint: 'Credit limit', digits: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add',
                  style: TextStyle(color: Nocturne.accent300))),
        ],
      ),
    );

    if (ok != true || label.text.trim().isEmpty) return;
    await s.repo.addCard(
      familyId: s.familyId,
      label: label.text.trim(),
      last4: last4.text.trim().isEmpty ? null : last4.text.trim(),
      creditLimit: double.tryParse(limit.text.trim()) ?? 0,
    );
    await s.refresh();
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool digits;

  const _Field(
      {required this.controller, required this.hint, this.digits = false});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, color: Nocturne.text),
        cursorColor: Nocturne.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 14, color: Nocturne.neutral600),
          filled: true,
          fillColor: Nocturne.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.72,
                color: Nocturne.accent300)),
      );
}

class _CardTile extends StatelessWidget {
  final int index;
  const _CardTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final c = s.cards[index];

    final used = s.txns
        .where((t) => t.cardId == c.id && t.isExpense)
        .fold(0.0, (a, t) => a + t.amount);
    final util = c.creditLimit <= 0 ? 0.0 : used / c.creditLimit;
    final hue = index.isEven ? 289 : 200;
    final tint = V3Design.hue(hue);
    final due = c.dueInDays;

    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 176,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Nocturne.mix(tint, 55), Nocturne.surface],
              ),
              border: Border.all(color: Nocturne.mix(tint, 45), width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 36,
                    offset: Offset(0, 16)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text)),
                    ),
                    const Icon(PhRegular.contactlessPayment,
                        size: 22, color: Nocturne.neutral300),
                  ],
                ),
                const Spacer(),
                Text('•••• •••• •••• ${c.last4 ?? '••••'}',
                    style: const TextStyle(
                      fontSize: 13,
                      letterSpacing: 2.34,
                      color: Nocturne.neutral300,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('USED',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.6,
                                color: Nocturne.neutral400)),
                        V3Num(s.moneyShort(used),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.text)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('AVAILABLE',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.6,
                                color: Nocturne.neutral400)),
                        V3Num(
                            s.moneyShort(
                                (c.creditLimit - used).clamp(0, double.infinity)),
                            style: const TextStyle(
                                fontSize: 13, color: Nocturne.text)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.neutral900, width: 1),
            ),
            child: Column(
              children: [
                V3ProgressBar(
                  fraction: util,
                  fill: util > 0.8
                      ? NocturneSemantic.expense
                      : util > 0.5
                          ? NocturneSemantic.warning
                          : tint,
                  height: 5,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(util * 100).round()}% used',
                        style: const TextStyle(
                            fontSize: 11, color: Nocturne.neutral500)),
                    Text('Limit ${V3Design.inrShort(c.creditLimit)}',
                        style: const TextStyle(
                            fontSize: 11, color: Nocturne.neutral500)),
                  ],
                ),
                if (due >= 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          due == 0 ? 'Payment due today' : 'Due in $due days',
                          style: TextStyle(
                            fontSize: 12,
                            color: due <= 3
                                ? NocturneSemantic.warning
                                : Nocturne.neutral400,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => s.addTransaction(
                          title: '${c.label} bill',
                          amount: used,
                          type: 'expense',
                          categoryKey: 'bills',
                          method: 'Bank',
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 32,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Nocturne.mix(Nocturne.accent, 12),
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: Nocturne.accent, width: 1),
                          ),
                          child: const Text('Pay bill',
                              style: TextStyle(
                                  fontSize: 12, color: Nocturne.accent100)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

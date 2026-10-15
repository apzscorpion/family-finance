import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/card_scan.dart';
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
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Nocturne.palette.line, width: 1),
            ),
            child: Column(
              children: [
                Icon(PhRegular.creditCard,
                    size: 32, color: Nocturne.palette.faint),
                const SizedBox(height: 10),
                Text('No cards yet',
                    style:
                        TextStyle(fontSize: 14, color: Nocturne.palette.neutral300)),
                const SizedBox(height: 4),
                Text('Add a card to track its limit and dues',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Nocturne.palette.muted)),
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
                      border: Border.all(color: Nocturne.palette.accent, width: 1),
                    ),
                    child: Text('Add card',
                        style: TextStyle(
                            fontSize: 13, color: Nocturne.palette.accentLight)),
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
                                  style: TextStyle(
                                      fontSize: 13.5, color: Nocturne.palette.text)),
                              Text(
                                  'In ${s.moneyShort(t.inAmt)} · '
                                  'Spent ${s.moneyShort(t.outAmt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Nocturne.palette.muted)),
                            ],
                          ),
                        ),
                        V3Num(s.money(bal),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: bal >= 0
                                    ? Nocturne.palette.text
                                    : Nocturne.palette.expense)),
                      ],
                    ),
                  );
                }),
                if (i < s.sources.length - 1) const V3RowDivider(),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Balances are tracked from your entries and detected payments — '
            'not pulled live from your bank.',
            style: TextStyle(
                fontSize: 11.5, height: 1.5, color: Nocturne.palette.muted),
          ),
        ),
      ],
    );
  }

  static Future<void> _addCard(BuildContext context, V3State s) async {
    final label = TextEditingController();
    final last4 = TextEditingController();
    final limit = TextEditingController();
    String? scanNote;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.palette.surface,
        title: Text('Add card',
            style: TextStyle(fontSize: 17, color: Nocturne.palette.text)),
        content: StatefulBuilder(
          builder: (ctx, setInner) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                CardScan? r;
                try {
                  r = await scanCard();
                } catch (_) {
                  r = (last4: null, expiry: null);
                }
                if (r == null) return;
                if (r.last4 != null) last4.text = r.last4!;
                setInner(() => scanNote = r!.last4 == null
                    ? "Couldn't read the number. Try again in good light, card filling the frame."
                    : 'Read card ending ${r.last4}'
                        '${r.expiry == null ? '' : ', expires ${r.expiry}'}');
              },
              icon: const Icon(PhRegular.camera, size: 18),
              label: const Text('Scan card (front)'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Nocturne.palette.accentMuted,
                  side: BorderSide(color: Nocturne.palette.edge)),
            ),
            if (scanNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(scanNote!,
                    style: TextStyle(
                        fontSize: 12, color: Nocturne.palette.subtle)),
              ),
            const SizedBox(height: 10),
            _Field(controller: label, hint: 'Card name (e.g. HDFC Regalia)'),
            const SizedBox(height: 10),
            _Field(controller: last4, hint: 'Last 4 digits', digits: true),
            const SizedBox(height: 10),
            _Field(controller: limit, hint: 'Credit limit', digits: true),
          ],
        ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: Nocturne.palette.subtle))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Add',
                  style: TextStyle(color: Nocturne.palette.accentMuted))),
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
        style: TextStyle(fontSize: 14, color: Nocturne.palette.text),
        cursorColor: Nocturne.palette.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(fontSize: 14, color: Nocturne.palette.faint),
          filled: true,
          fillColor: Nocturne.palette.bg,
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
            style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.72,
                color: Nocturne.palette.accentMuted)),
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
                colors: [Nocturne.mix(tint, 55), Nocturne.palette.surface],
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
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.palette.text)),
                    ),
                    Icon(PhRegular.contactlessPayment,
                        size: 22, color: Nocturne.palette.neutral300),
                  ],
                ),
                const Spacer(),
                Text('•••• •••• •••• ${c.last4 ?? '••••'}',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 2.34,
                      color: Nocturne.palette.neutral300,
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
                        Text('USED',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.6,
                                color: Nocturne.palette.subtle)),
                        V3Num(s.moneyShort(used),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.palette.text)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('AVAILABLE',
                            style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.6,
                                color: Nocturne.palette.subtle)),
                        V3Num(
                            s.moneyShort(
                                (c.creditLimit - used).clamp(0, double.infinity)),
                            style: TextStyle(
                                fontSize: 13, color: Nocturne.palette.text)),
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
              color: Nocturne.palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nocturne.palette.line, width: 1),
            ),
            child: Column(
              children: [
                V3ProgressBar(
                  fraction: util,
                  fill: util > 0.8
                      ? Nocturne.palette.expense
                      : util > 0.5
                          ? Nocturne.palette.warning
                          : tint,
                  height: 5,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(util * 100).round()}% used',
                        style: TextStyle(
                            fontSize: 11, color: Nocturne.palette.muted)),
                    Text('Limit ${V3Design.inrShort(c.creditLimit)}',
                        style: TextStyle(
                            fontSize: 11, color: Nocturne.palette.muted)),
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
                                ? Nocturne.palette.warning
                                : Nocturne.palette.subtle,
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
                            color: Nocturne.mix(Nocturne.palette.accent, 12),
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: Nocturne.palette.accent, width: 1),
                          ),
                          child: Text('Pay bill',
                              style: TextStyle(
                                  fontSize: 12, color: Nocturne.palette.accentLight)),
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

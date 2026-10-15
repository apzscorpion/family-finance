import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';

/// Manage money sources: add, rename, remove.
///
/// Removal deletes a source nothing references, and archives one that has
/// history — a past transaction's source is never silently rewritten.
class SourcesManagerV3 extends StatelessWidget {
  const SourcesManagerV3({super.key});

  /// Opens as a full page from anywhere.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SourcesManagerV3()),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(PhRegular.arrowLeft,
                          size: 22, color: Nocturne.text),
                    ),
                  ),
                  const Expanded(
                    child: Text('Money sources',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.text)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Where money comes from and goes to — salary, a loan, a '
                      'side business. Add only the ones you actually use.',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Nocturne.neutral500),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (s.sources.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: Column(
                        children: [
                          Icon(PhRegular.wallet,
                              size: 34, color: Nocturne.neutral600),
                          SizedBox(height: 10),
                          Text('No sources yet',
                              style: TextStyle(
                                  fontSize: 14, color: Nocturne.neutral300)),
                        ],
                      ),
                    )
                  else
                    V3Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (var i = 0; i < s.sources.length; i++) ...[
                            _SourceRowTile(index: i),
                            if (i < s.sources.length - 1)
                              const V3RowDivider(),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => _addDialog(context, s),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Nocturne.accent700, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhRegular.plus,
                                size: 16, color: Nocturne.accent200),
                            SizedBox(width: 8),
                            Text('Add a source',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Nocturne.accent200)),
                          ],
                        ),
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

  /// The cash / bank split of [sourceIds] (one source, or every source),
  /// with withdraw, deposit and set-balance actions.
  static Future<void> openWallet(BuildContext context, List<String> sourceIds) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Nocturne.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _WalletSheet(sourceIds: sourceIds),
      );

  static Future<void> _addDialog(BuildContext context, V3State s) async {
    final name = TextEditingController();
    var kind = 'income';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Nocturne.surface,
          title: const Text('Add money source',
              style: TextStyle(fontSize: 17, color: Nocturne.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14, color: Nocturne.text),
                cursorColor: Nocturne.accent,
                decoration: InputDecoration(
                  hintText: 'e.g. Side business, Rent income',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: Nocturne.neutral600),
                  filled: true,
                  fillColor: Nocturne.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Type',
                  style:
                      TextStyle(fontSize: 12, color: Nocturne.neutral500)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final k in const [
                    ('income', 'Income'),
                    ('savings', 'Savings'),
                    ('loan', 'Loan'),
                    ('cash', 'Cash'),
                  ])
                    GestureDetector(
                      onTap: () => setLocal(() => kind = k.$1),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 30,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kind == k.$1
                              ? Nocturne.accent900
                              : Nocturne.bg,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: kind == k.$1
                                ? Nocturne.accent600
                                : Nocturne.neutral800,
                            width: 1,
                          ),
                        ),
                        child: Text(k.$2,
                            style: TextStyle(
                              fontSize: 12,
                              color: kind == k.$1
                                  ? Nocturne.accent100
                                  : Nocturne.neutral300,
                            )),
                      ),
                    ),
                ],
              ),
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
      ),
    );

    if (ok != true || name.text.trim().isEmpty) return;
    final added = await s.addSource(name.text.trim(), kind: kind);
    if (!context.mounted) return;
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not add — that name may already exist')),
      );
    }
  }
}

class _SourceRowTile extends StatelessWidget {
  final int index;
  const _SourceRowTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final src = s.sources[index];
    final design = src.design;
    final totals = s.sourceTotals(src.id);
    final w = s.wallet(src.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          V3IconTile(
              icon: design.icon, color: design.color, size: 38, radius: 12),
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
                  'Cash ${s.moneyShort(w.cash)} · Bank ${s.moneyShort(w.bank)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Nocturne.accent200),
                ),
                Text(
                  '${_kindLabel(src.kind)} · In ${s.moneyShort(totals.inAmt)}'
                  ' · Spent ${s.moneyShort(totals.outAmt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Nocturne.neutral500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _menu(context, s, index),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(PhRegular.dotsThree,
                  size: 18, color: Nocturne.neutral500),
            ),
          ),
        ],
      ),
    );
  }

  static String _kindLabel(String k) => switch (k) {
        'loan' => 'Loan',
        'savings' => 'Savings',
        'cash' => 'Cash',
        'card' => 'Card',
        _ => 'Income',
      };

  void _menu(BuildContext context, V3State s, int i) {
    final src = s.sources[i];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(src.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.text)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(PhRegular.wallet,
                  size: 18, color: Nocturne.text),
              title: const Text('Set cash & bank balance',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              subtitle: const Text('What this account holds right now',
                  style:
                      TextStyle(fontSize: 11.5, color: Nocturne.neutral500)),
              onTap: () async {
                Navigator.pop(ctx);
                await setBalances(context, s, src.id);
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.arrowCircleDown,
                  size: 18, color: Nocturne.text),
              title: const Text('Withdraw to cash',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              onTap: () async {
                Navigator.pop(ctx);
                await moveMoney(context, s, src.id, toCash: true);
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.bank,
                  size: 18, color: Nocturne.text),
              title: const Text('Deposit cash to bank',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              onTap: () async {
                Navigator.pop(ctx);
                await moveMoney(context, s, src.id, toCash: false);
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.pencilSimple,
                  size: 18, color: Nocturne.text),
              title: const Text('Rename',
                  style: TextStyle(fontSize: 14, color: Nocturne.text)),
              onTap: () async {
                Navigator.pop(ctx);
                await _rename(context, s, i);
              },
            ),
            ListTile(
              leading: const Icon(PhRegular.trash,
                  size: 18, color: NocturneSemantic.expense),
              title: const Text('Remove',
                  style: TextStyle(
                      fontSize: 14, color: NocturneSemantic.expense)),
              subtitle: const Text(
                  'Kept as history if it has been used',
                  style:
                      TextStyle(fontSize: 11.5, color: Nocturne.neutral500)),
              onTap: () async {
                Navigator.pop(ctx);
                final outcome = await s.removeSource(src.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(outcome == 'deleted'
                        ? '${src.name} removed'
                        : '${src.name} archived — past entries keep it'),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static InputDecoration _amountField(String label) => InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        labelStyle: const TextStyle(fontSize: 13, color: Nocturne.neutral400),
        filled: true,
        fillColor: Nocturne.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  /// Asks for the cash and bank amounts the source holds now.
  static Future<void> setBalances(
      BuildContext context, V3State s, String sourceId) async {
    final now = s.wallet(sourceId);
    final cash = TextEditingController(text: now.cash.toStringAsFixed(0));
    final bank = TextEditingController(text: now.bank.toStringAsFixed(0));
    const keyboard = TextInputType.numberWithOptions(decimal: true);
    const style = TextStyle(fontSize: 14, color: Nocturne.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: Text('${s.sourceById(sourceId)?.name ?? 'Account'} balance',
            style: const TextStyle(fontSize: 17, color: Nocturne.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: cash,
                keyboardType: keyboard,
                style: style,
                decoration: _amountField('Cash in hand')),
            const SizedBox(height: 10),
            TextField(
                controller: bank,
                keyboardType: keyboard,
                style: style,
                decoration: _amountField('In the bank')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(color: Nocturne.accent300))),
        ],
      ),
    );
    final c = double.tryParse(cash.text.trim());
    final b = double.tryParse(bank.text.trim());
    if (ok != true || c == null || b == null) return;
    await s.setWalletBalance(sourceId, c, b);
  }

  /// Withdraw ([toCash]) or deposit inside one source.
  static Future<void> moveMoney(BuildContext context, V3State s, String sourceId,
      {required bool toCash}) async {
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: Text(toCash ? 'Withdraw to cash' : 'Deposit cash to bank',
            style: const TextStyle(fontSize: 17, color: Nocturne.text)),
        content: TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, color: Nocturne.text),
          decoration: _amountField('Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(toCash ? 'Withdraw' : 'Deposit',
                  style: const TextStyle(color: Nocturne.accent300))),
        ],
      ),
    );
    final v = double.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || v <= 0) return;
    final moved = await s.moveMoney(sourceId, v, toCash: toCash);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(moved
          ? (toCash ? 'Moved to cash' : 'Moved to bank')
          : 'Could not save — check your connection'),
    ));
  }

  static Future<void> _rename(
      BuildContext context, V3State s, int i) async {
    final src = s.sources[i];
    final name = TextEditingController(text: src.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: const Text('Rename source',
            style: TextStyle(fontSize: 17, color: Nocturne.text)),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 14, color: Nocturne.text),
          cursorColor: Nocturne.accent,
          decoration: InputDecoration(
            filled: true,
            fillColor: Nocturne.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(color: Nocturne.accent300))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await s.renameSource(src.id, name.text.trim());
    }
  }
}

class _WalletSheet extends StatelessWidget {
  final List<String> sourceIds;
  const _WalletSheet({required this.sourceIds});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          children: [
            const Text('Cash & bank',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text)),
            const SizedBox(height: 4),
            const Text(
                'Cash entries change the cash part; UPI, bank and card change '
                'the bank part.',
                style: TextStyle(fontSize: 12, color: Nocturne.neutral500)),
            for (final id in sourceIds) ...[
              const SizedBox(height: 14),
              _WalletCard(sourceId: id),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String sourceId;
  const _WalletCard({required this.sourceId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final src = s.sourceById(sourceId);
    if (src == null) return const SizedBox.shrink();
    final w = s.wallet(sourceId);

    Widget amount(String label, double v, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 14, color: Nocturne.neutral400),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral400)),
                ]),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: V3Num(s.money(v),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: v >= 0
                              ? Nocturne.text
                              : NocturneSemantic.expense)),
                ),
              ],
            ),
          ),
        );

    Widget action(String label, IconData icon, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Nocturne.accent700, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Nocturne.accent200),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Nocturne.accent200)),
                  ),
                ],
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          V3IconTile(
              icon: src.design.icon,
              color: src.design.color,
              size: 28,
              radius: 9,
              iconSize: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(src.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Nocturne.text)),
          ),
          V3Num(s.money(w.cash + w.bank),
              style: const TextStyle(
                  fontSize: 13.5, color: Nocturne.neutral300)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          amount('Cash', w.cash, PhRegular.coins),
          const SizedBox(width: 8),
          amount('Bank', w.bank, PhRegular.bank),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          action('Withdraw', PhRegular.arrowCircleDown,
              () => _SourceRowTile.moveMoney(context, s, sourceId,
                  toCash: true)),
          const SizedBox(width: 6),
          action('Deposit', PhRegular.bank,
              () => _SourceRowTile.moveMoney(context, s, sourceId,
                  toCash: false)),
          // Only on your own view: from someone else's, the figure shown
          // isn't yours, and saving it rewrote the shared opening balance.
          if (s.scope == s.myId) ...[
            const SizedBox(width: 6),
            action('Set balance', PhRegular.pencilSimple,
                () => _SourceRowTile.setBalances(context, s, sourceId)),
          ],
        ]),
      ],
    );
  }
}

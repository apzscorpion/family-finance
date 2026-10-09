import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/ai/ai_config.dart';
import '../data/expense_import.dart';
import '../data/import_ai.dart';
import '../phosphor_icons.dart';
import '../v3_design.dart';
import '../v3_state.dart';
import '../widgets/v3_motion.dart';

/// Lets the user confirm how a file maps onto their accounts and categories,
/// with the configured AI model proposing the mapping and asking about
/// anything it is unsure of. Pops the confirmed [ImportReview].
class ImportReviewSheet extends StatefulWidget {
  const ImportReviewSheet({super.key, required this.rows});

  final List<ImportedExpense> rows;

  static Future<ImportReview?> open(
          BuildContext context, List<ImportedExpense> rows) =>
      showModalBottomSheet<ImportReview>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ImportReviewSheet(rows: rows),
      );

  @override
  State<ImportReviewSheet> createState() => _ImportReviewSheetState();
}

class _ImportReviewSheetState extends State<ImportReviewSheet> {
  final _answers = TextEditingController();
  late ImportReview _review = ImportAi.draft(widget.rows);
  bool _asking = false;
  String? _error;
  bool _noKey = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void dispose() {
    _answers.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final s = context.read<V3State>();
    setState(() {
      _asking = true;
      _error = null;
    });
    final config = await AiConfigStore.load();
    if (!mounted) return;
    if (!config.isConfigured) {
      setState(() {
        _asking = false;
        _noKey = true;
      });
      return;
    }
    final result = await ImportAi.ask(
      widget.rows,
      config: config,
      accounts: [for (final src in s.sources) (id: src.id, name: src.name)],
      categories: [
        for (final c in s.categories)
          (
            key: c.key,
            name: c.name,
            income: V3Design.incomeCats.contains(c.key),
          ),
      ],
      answers: _answers.text,
    );
    if (!mounted) return;
    setState(() {
      _asking = false;
      _error = result.error;
      if (result.review != null) _review = result.review!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final r = _review;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral700, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(PhRegular.sparkle, size: 18, color: Nocturne.accent200),
                SizedBox(width: 8),
                Text('AI import review',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text)),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_asking)
                    const _Note(
                      icon: PhRegular.sparkle,
                      text: 'Reading your file and your accounts…',
                    )
                  else if (_noKey)
                    const _Note(
                      icon: PhRegular.info,
                      text: 'No AI key is set up, so these are the on-device '
                          'suggestions. Add a key in Settings → AI '
                          'restructuring for smarter checks.',
                    )
                  else if (_error != null)
                    _Note(icon: PhRegular.warning, text: _error!)
                  else if (r.summary.isNotEmpty)
                    _Note(icon: PhRegular.sparkle, text: r.summary),
                  for (final q in r.questions)
                    _Note(icon: PhRegular.info, text: q, amber: true),
                  const _Label('WALLET → ACCOUNT'),
                  for (final e in r.walletCounts.entries)
                    _MapRow(
                      label: e.key.isEmpty ? '(no wallet)' : e.key,
                      count: e.value,
                      value: r.wallets[e.key],
                      options: [
                        for (final src in s.sources) (src.id, src.name),
                      ],
                      onChanged: (v) => setState(() => r.wallets[e.key] = v),
                    ),
                  const _Label('CATEGORY → CATEGORY'),
                  for (final e in r.categoryCounts.entries)
                    _MapRow(
                      label: e.key.isEmpty ? '(no category)' : e.key,
                      count: e.value,
                      value: r.categories[e.key],
                      options: [
                        for (final c in s.categories)
                          (c.key, s.catStyle(c.key).name),
                      ],
                      onChanged: (v) =>
                          setState(() => r.categories[e.key] = v),
                    ),
                  if (r.typeChanges.isNotEmpty) ...[
                    const _Label('INCOME / EXPENSE FIXES'),
                    for (final c in r.typeChanges)
                      _TypeRow(
                        row: widget.rows[c.index],
                        change: c,
                        money: s.money,
                        onToggle: () =>
                            setState(() => c.accepted = !c.accepted),
                      ),
                  ],
                  if (!_noKey) ...[
                    const _Label('ANSWER THE AI OR ADD A HINT'),
                    TextField(
                      controller: _answers,
                      minLines: 1,
                      maxLines: 3,
                      style:
                          const TextStyle(fontSize: 13.5, color: Nocturne.text),
                      decoration: InputDecoration(
                        hintText: 'e.g. Allowance is my salary; '
                            '"With Sinu" is dining',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Nocturne.neutral500),
                        filled: true,
                        fillColor: Nocturne.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Nocturne.neutral800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _asking ? null : _ask,
                        icon: const Icon(PhRegular.arrowsClockwise,
                            size: 15, color: Nocturne.accent200),
                        label: const Text('Ask AI again',
                            style: TextStyle(color: Nocturne.accent200)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            V3Press(
              key: const ValueKey('import_review_apply'),
              onTap: _asking ? null : () => Navigator.pop(context, _review),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nocturne.accent700,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Nocturne.accent400),
                ),
                child: const Text('Apply to import',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.accent100)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.amber = false});

  final IconData icon;
  final String text;
  final bool amber;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: amber ? const Color(0x22E2C06D) : Nocturne.accent900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 15,
                color: amber ? const Color(0xFFE2C06D) : Nocturne.accent200),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.4, color: Nocturne.neutral200)),
            ),
          ],
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: Nocturne.neutral400)),
      );
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.label,
    required this.count,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int count;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.$1 == value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text('$label · $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Nocturne.text)),
          ),
          const Icon(PhRegular.caretRight,
              size: 12, color: Nocturne.neutral600),
          const SizedBox(width: 6),
          DropdownButton<String?>(
            value: known ? value : null,
            hint: const Text('Auto',
                style: TextStyle(fontSize: 13, color: Nocturne.neutral500)),
            dropdownColor: Nocturne.surface,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 13, color: Nocturne.accent200),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o.$1, child: Text(o.$2)),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.row,
    required this.change,
    required this.money,
    required this.onToggle,
  });

  final ImportedExpense row;
  final TypeChange change;
  final String Function(double) money;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(change.accepted ? PhFill.checkCircle : PhRegular.circle,
                  size: 18,
                  color: change.accepted
                      ? Nocturne.accent
                      : Nocturne.neutral500),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${row.title} · ${money(row.amount)} → '
                        '${change.isIncome ? 'income' : 'expense'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Nocturne.text)),
                    if (change.reason.isNotEmpty)
                      Text(change.reason,
                          style: const TextStyle(
                              fontSize: 11.5, color: Nocturne.neutral500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'home_v3.dart' show V3TxnRow;
import 'import_v3.dart';

/// Activity: search, type segment, category chips, member filter, totals, and
/// transactions grouped by day.
class ActivityV3 extends StatefulWidget {
  const ActivityV3({super.key});

  @override
  State<ActivityV3> createState() => _ActivityV3State();
}

class _ActivityV3State extends State<ActivityV3> {
  final _search = TextEditingController();
  String _type = 'all';
  String? _catKey;
  String? _memberId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TxnRow> _filtered(V3State s) {
    final q = _search.text.trim().toLowerCase();
    return s.scoped.where((t) {
      if (_type != 'all' && t.type != _type) return false;
      if (_catKey != null && t.categoryKey != _catKey) return false;
      if (_memberId != null && t.userId != _memberId) return false;
      if (q.isNotEmpty) {
        final cat = s.catStyle(t.categoryKey).name.toLowerCase();
        final who = (s.memberById(t.userId)?.name ?? '').toLowerCase();
        if (!t.title.toLowerCase().contains(q) &&
            !cat.contains(q) &&
            !who.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _reset() => setState(() {
        _search.clear();
        _type = 'all';
        _catKey = null;
        _memberId = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final items = _filtered(s);
    final spent =
        items.where((t) => t.isExpense).fold(0.0, (a, t) => a + t.amount);
    final received =
        items.where((t) => !t.isExpense).fold(0.0, (a, t) => a + t.amount);

    // Categories present in the current scope, most used first.
    final counts = <String, int>{};
    for (final t in s.scoped) {
      counts[t.categoryKey] = (counts[t.categoryKey] ?? 0) + 1;
    }
    final catKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final groups = <int, List<TxnRow>>{};
    for (final t in items) {
      groups.putIfAbsent(t.ageInDays, () => []).add(t);
    }
    final dayKeys = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: Nocturne.accent300,
      backgroundColor: Nocturne.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Activity',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text)),
                      GestureDetector(
                        onTap: () => V3Sheets.openScope(context),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(s.scopeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Nocturne.neutral500)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(PhBold.caretDown,
                                size: 10, color: Nocturne.neutral500),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${items.length}',
                        style: const TextStyle(
                            fontSize: 12, color: Nocturne.neutral500)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ImportV3.open(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Nocturne.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Nocturne.neutral800, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhRegular.downloadSimple,
                                size: 12, color: Nocturne.accent200),
                            SizedBox(width: 4),
                            Text('Import',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.accent200)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (items.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                              content: Text('No transactions to export')));
                          return;
                        }
                        final csv = DataExport.transactionsCsv(
                          items,
                          nameOf: s.memberName,
                        );
                        final now = DateTime.now();
                        final stamp =
                            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                        final ok = await DataExport.share(
                          csv,
                          'transactions-$stamp.csv',
                          subject: 'Activity transactions',
                        );
                        if (!ok) {
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Could not export transactions')));
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Nocturne.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Nocturne.neutral800, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhRegular.shareNetwork,
                                size: 12, color: Nocturne.neutral300),
                            SizedBox(width: 4),
                            Text('Export',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.neutral300)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Search
          Container(
            height: 44,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Nocturne.neutral800, width: 1),
            ),
            child: Row(
              children: [
                const Icon(PhRegular.magnifyingGlass,
                    size: 18, color: Nocturne.neutral500),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style:
                        const TextStyle(fontSize: 14, color: Nocturne.text),
                    cursorColor: Nocturne.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search merchant, category, member',
                      hintStyle: TextStyle(
                          fontSize: 14, color: Nocturne.neutral600),
                    ),
                  ),
                ),
                if (_search.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_search.clear),
                    child: const Icon(PhFill.xCircle,
                        size: 16, color: Nocturne.neutral500),
                  ),
              ],
            ),
          ),
          // Type segment
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                for (final o in const [
                  ('all', 'All'),
                  ('expense', 'Spent'),
                  ('income', 'Received'),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = o.$1),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _type == o.$1
                              ? Nocturne.accent900
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _type == o.$1
                                ? Nocturne.accent600
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(o.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _type == o.$1
                                  ? Nocturne.accent100
                                  : Nocturne.neutral400,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (catKeys.isNotEmpty)
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: catKeys.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final k = catKeys[i];
                  final c = s.catStyle(k);
                  return V3Chip(
                    label: c.short,
                    height: 30,
                    icon: c.icon,
                    iconColor: c.color,
                    selected: _catKey == k,
                    onTap: () =>
                        setState(() => _catKey = _catKey == k ? null : k),
                  );
                },
              ),
            ),
          if (s.isFamily && s.members.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const Text('By',
                      style: TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: s.members.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final m = s.members[i];
                          final on = _memberId == m.userId;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _memberId = on ? null : m.userId),
                            child: V3Avatar(
                              initial: m.initial,
                              color: m.color,
                              size: 30,
                              fontSize: 11.5,
                              opacity: _memberId == null || on ? 1 : 0.4,
                              ringColor: on ? Nocturne.accent400 : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Totals
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                      label: 'Spent · shown',
                      value: s.money(spent),
                      color: Nocturne.text),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                      label: 'Received · shown',
                      value: s.money(received),
                      color: NocturneSemantic.income),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                children: [
                  const Icon(PhRegular.receiptX,
                      size: 38, color: Nocturne.neutral600),
                  const SizedBox(height: 8),
                  const Text('No transactions match',
                      style: TextStyle(
                          fontSize: 14, color: Nocturne.neutral300)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _reset,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Nocturne.accent700, width: 1),
                      ),
                      child: const Text('Reset filters',
                          style: TextStyle(
                              fontSize: 12.5, color: Nocturne.accent200)),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final day in dayKeys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dayLabel(day).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.58,
                            color: Nocturne.neutral500)),
                    V3Num(
                      s.money(groups[day]!
                          .where((t) => t.isExpense)
                          .fold(0.0, (a, t) => a + t.amount)),
                      style: const TextStyle(
                          fontSize: 11.5, color: Nocturne.neutral500),
                    ),
                  ],
                ),
              ),
              V3Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[day]!.length; i++) ...[
                      V3TxnRow(txn: groups[day]![i]),
                      if (i < groups[day]!.length - 1) const V3RowDivider(),
                    ],
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  static String _dayLabel(int daysAgo) {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Nocturne.neutral500)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: V3Num(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ),
          ],
        ),
      );
}

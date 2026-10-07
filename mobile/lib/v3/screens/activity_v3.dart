import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/v3_sheets.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_primitives.dart';
import 'home_v3.dart' show V3TxnRow;
import 'import_v3.dart';

/// Activity: search, type segment, category chips, member filter, totals,
/// batch selection, imported data management, and transactions grouped by day.
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

  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};
  bool _deleting = false;
  V3Nav? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = Provider.of<V3Nav?>(context, listen: false);
    if (_nav != nav) {
      _nav?.unregisterBackHandler(_handleBack);
      _nav = nav;
      _nav?.registerBackHandler(_handleBack);
    }
  }

  bool _handleBack() {
    if (!mounted) return false;
    final nav = _nav;
    if (nav != null && (nav.page != null || nav.tab != 1)) return false;
    if (_selecting) {
      _exitSelection();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _nav?.unregisterBackHandler(_handleBack);
    _search.dispose();
    super.dispose();
  }

  List<TxnRow> _filtered(V3State s) {
    final q = _search.text.trim().toLowerCase();
    // When viewing Imported (or in batch-selection mode so imported rows from
    // older months are never hidden), include imported rows beyond the 7d/30d
    // period window.
    final base = _type == 'imported' ? s.importedTxns : s.scoped;
    return base.where((t) {
      if (_type == 'expense' && !t.isExpense) return false;
      if (_type == 'income' && t.isExpense) return false;
      if (_type == 'imported' && t.origin != 'import') return false;
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

  void _toggleRow(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionWith(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleDayGroup(List<TxnRow> dayRows) {
    HapticFeedback.selectionClick();
    final ids = dayRows.map((t) => t.id).toList();
    final allIn = ids.every(_selectedIds.contains);
    setState(() {
      if (allIn) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _selectImported(V3State s) {
    HapticFeedback.selectionClick();
    final imported = s.importedTxns;
    setState(() {
      _selecting = true;
      _type = 'imported';
      _selectedIds
        ..clear()
        ..addAll(imported.map((t) => t.id));
    });
  }

  Future<void> _confirmDeleteSelected(V3State s) async {
    if (_selectedIds.isEmpty || _deleting) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete $count transaction${count == 1 ? '' : 's'}?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Nocturne.text,
          ),
        ),
        content: Text(
          'This will permanently remove the $count selected transaction${count == 1 ? '' : 's'} from your workspace.',
          style: const TextStyle(fontSize: 13, color: Nocturne.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: NocturneSemantic.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final idsToDelete = _selectedIds.toList();
    final removed = await s.deleteTransactions(idsToDelete);
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selecting = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $removed transaction${removed == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAllImported(V3State s) async {
    final imported = s.importedTxns;
    if (imported.isEmpty || _deleting) return;
    final count = imported.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete $count imported transaction${count == 1 ? '' : 's'}?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Nocturne.text,
          ),
        ),
        content: Text(
          'This will permanently delete all $count imported transaction${count == 1 ? '' : 's'} in ${s.isFamily ? 'this workspace' : "${s.scopeName}'s view"}. Manually added entries will not be touched.',
          style: const TextStyle(fontSize: 13, color: Nocturne.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Nocturne.neutral400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete imported',
              style: TextStyle(
                color: NocturneSemantic.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final removed = await s.deleteImportedTransactions();
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selecting = false;
      _selectedIds.clear();
      if (_type == 'imported') _type = 'all';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $removed imported transaction${removed == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final items = _filtered(s);
    final importedCount = s.importedTxns.length;
    final spent =
        items.where((t) => t.isExpense).fold(0.0, (a, t) => a + t.amount);
    final received =
        items.where((t) => !t.isExpense).fold(0.0, (a, t) => a + t.amount);

    // Categories present in the current scope, most used first.
    final counts = <String, int>{};
    final catSource = _type == 'imported' ? s.importedTxns : s.scoped;
    for (final t in catSource) {
      counts[t.categoryKey] = (counts[t.categoryKey] ?? 1) + 1;
    }
    final catKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final groups = <int, List<TxnRow>>{};
    for (final t in items) {
      groups.putIfAbsent(t.ageInDays, () => []).add(t);
    }
    final dayKeys = groups.keys.toList()..sort();

    final allShownSelected =
        items.isNotEmpty && items.every((t) => _selectedIds.contains(t.id));

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
                      onTap: () {
                        if (_selecting) {
                          _exitSelection();
                        } else {
                          setState(() => _selecting = true);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selecting
                              ? Nocturne.accent900
                              : Nocturne.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selecting
                                ? Nocturne.accent600
                                : Nocturne.neutral800,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selecting
                                  ? PhBold.x
                                  : PhRegular.listChecks,
                              size: 12,
                              color: _selecting
                                  ? Nocturne.accent100
                                  : Nocturne.neutral300,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selecting ? 'Done' : 'Select',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _selecting
                                    ? Nocturne.accent100
                                    : Nocturne.neutral300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
          // Type segment (includes Imported tab)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                for (final o in [
                  ('all', 'All'),
                  ('expense', 'Spent'),
                  ('income', 'Received'),
                  (
                    'imported',
                    importedCount > 0
                        ? 'Imported ($importedCount)'
                        : 'Imported',
                  ),
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
                        child: Text(
                          o.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _type == o.$1
                                ? Nocturne.accent100
                                : Nocturne.neutral400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Batch selection toolbar
          if (_selecting)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nocturne.accent700, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedIds.isEmpty
                            ? PhRegular.circle
                            : PhFill.checkCircle,
                        size: 18,
                        color: _selectedIds.isEmpty
                            ? Nocturne.neutral500
                            : Nocturne.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} selected',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.text,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _selectedIds.isEmpty || _deleting
                            ? null
                            : () => _confirmDeleteSelected(s),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedIds.isEmpty
                                ? Nocturne.neutral800
                                : Nocturne.mix(NocturneSemantic.expense, 20),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _selectedIds.isEmpty
                                  ? Nocturne.neutral700
                                  : NocturneSemantic.expense,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhRegular.trash,
                                size: 13,
                                color: _selectedIds.isEmpty
                                    ? Nocturne.neutral500
                                    : NocturneSemantic.expense,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _deleting
                                    ? 'Deleting…'
                                    : 'Delete (${_selectedIds.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedIds.isEmpty
                                      ? Nocturne.neutral500
                                      : NocturneSemantic.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _ActionPill(
                        icon: allShownSelected
                            ? PhRegular.circle
                            : PhRegular.listChecks,
                        label: allShownSelected
                            ? 'Deselect shown'
                            : 'Select all shown (${items.length})',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (allShownSelected) {
                              _selectedIds.removeAll(items.map((t) => t.id));
                            } else {
                              _selectedIds.addAll(items.map((t) => t.id));
                            }
                          });
                        },
                      ),
                      if (importedCount > 0)
                        _ActionPill(
                          icon: PhRegular.downloadSimple,
                          label: 'Select imported ($importedCount)',
                          accent: true,
                          onTap: () => _selectImported(s),
                        ),
                      if (importedCount > 0)
                        _ActionPill(
                          icon: PhRegular.trash,
                          label: 'Delete all imported ($importedCount)',
                          danger: true,
                          onTap: () => _confirmDeleteAllImported(s),
                        ),
                      if (_selectedIds.isNotEmpty)
                        _ActionPill(
                          icon: PhRegular.x,
                          label: 'Clear selection',
                          onTap: () => setState(_selectedIds.clear),
                        ),
                    ],
                  ),
                ],
              ),
            )
          else if (importedCount > 0)
            // Quick banner for imported transactions so user can batch-select or
            // delete imported data with one tap
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(PhRegular.downloadSimple,
                      size: 15, color: Nocturne.accent200),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$importedCount imported transaction${importedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Nocturne.neutral300,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _selectImported(s),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Nocturne.bg,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Nocturne.neutral700, width: 1),
                      ),
                      child: const Text(
                        'Batch select',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.accent200,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _confirmDeleteAllImported(s),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Nocturne.mix(NocturneSemantic.expense, 16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Nocturne.mix(NocturneSemantic.expense, 45),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhRegular.trash,
                              size: 12, color: NocturneSemantic.expense),
                          SizedBox(width: 4),
                          Text(
                            'Delete imported',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: NocturneSemantic.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (catKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
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
                child: GestureDetector(
                  onTap: _selecting
                      ? () => _toggleDayGroup(groups[day]!)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selecting) ...[
                            Icon(
                              groups[day]!
                                      .every((t) => _selectedIds.contains(t.id))
                                  ? PhFill.checkCircle
                                  : PhRegular.circle,
                              size: 15,
                              color: groups[day]!
                                      .every((t) => _selectedIds.contains(t.id))
                                  ? Nocturne.accent
                                  : Nocturne.neutral500,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(_dayLabel(day).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 0.58,
                                  color: Nocturne.neutral500)),
                        ],
                      ),
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
              ),
              V3Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[day]!.length; i++) ...[
                      V3TxnRow(
                        txn: groups[day]![i],
                        selectable: _selecting,
                        selected: _selectedIds.contains(groups[day]![i].id),
                        onToggleSelect: () => _toggleRow(groups[day]![i].id),
                        onLongPress: () =>
                            _enterSelectionWith(groups[day]![i].id),
                      ),
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

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  final bool danger;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? NocturneSemantic.expense
        : accent
            ? Nocturne.accent200
            : Nocturne.neutral300;
    final bg = danger
        ? Nocturne.mix(NocturneSemantic.expense, 14)
        : accent
            ? Nocturne.accent900
            : Nocturne.bg;
    final border = danger
        ? Nocturne.mix(NocturneSemantic.expense, 40)
        : accent
            ? Nocturne.accent700
            : Nocturne.neutral800;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
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

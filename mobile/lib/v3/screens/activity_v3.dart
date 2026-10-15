import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../../theme/nocturne_palette.dart';
import '../data/data_export.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/batch_edit_sheet.dart';
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
  String? _subId;
  String? _memberId;

  /// Entries where this person has a share ("For" / spent with them).
  String? _forId;

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
    final base = _type == 'imported' ? s.importedTxns : s.scopedAllAccounts;
    return base.where((t) {
      if (_type == 'expense' && !t.isExpense) return false;
      if (_type == 'income' && t.isExpense) return false;
      if (_type == 'imported' && t.origin != 'import') return false;
      if (_catKey != null && t.categoryKey != _catKey) return false;
      if (_subId != null && t.subCategoryId != _subId) return false;
      if (_memberId != null && t.userId != _memberId) return false;
      if (_forId != null && !t.shares.containsKey(_forId)) return false;
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
        _subId = null;
        _memberId = null;
        _forId = null;
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

  Future<void> _editSelected(V3State s) async {
    final ids = _selectedIds.toList();
    final edit = await BatchEditSheet.open(context, count: ids.length);
    if (edit == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = await s.batchUpdateTransactions(
      ids,
      sourceId: edit.sourceId,
      categoryKey: edit.categoryKey,
      type: edit.isIncome == null
          ? null
          : (edit.isIncome! ? 'income' : 'expense'),
    );
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
    messenger.showSnackBar(SnackBar(
        content: Text('Updated $n transaction${n == 1 ? '' : 's'}')));
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
    final p = context.read<ThemeController?>()?.palette ?? Nocturne.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete $count transaction${count == 1 ? '' : 's'}?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        content: Text(
          'This will permanently remove the $count selected transaction${count == 1 ? '' : 's'} from your workspace.',
          style: TextStyle(fontSize: 13, color: p.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: p.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: p.expense,
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
    final p = context.read<ThemeController?>()?.palette ?? Nocturne.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete $count imported transaction${count == 1 ? '' : 's'}?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
        content: Text(
          'This will permanently delete all $count imported transaction${count == 1 ? '' : 's'} in ${s.isFamily ? 'this workspace' : "${s.scopeName}'s view"}. Manually added entries will not be touched.',
          style: TextStyle(fontSize: 13, color: Nocturne.palette.subtle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Nocturne.palette.subtle)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete imported',
              style: TextStyle(
                color: Nocturne.palette.expense,
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
    final catSource =
        _type == 'imported' ? s.importedTxns : s.scopedAllAccounts;
    for (final t in catSource) {
      counts[t.categoryKey] = (counts[t.categoryKey] ?? 1) + 1;
    }
    final catKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    // Sub-categories in use, under the chosen main category if there is one.
    final subCounts = <String, int>{};
    for (final t in catSource) {
      final id = t.subCategoryId;
      if (id == null || (_catKey != null && t.categoryKey != _catKey)) continue;
      subCounts[id] = (subCounts[id] ?? 0) + 1;
    }
    final subIds = subCounts.keys
        .where((id) => s.categoryById(id) != null)
        .toList()
      ..sort((a, b) => subCounts[b]!.compareTo(subCounts[a]!));
    final forName = s.memberById(_forId)?.name;
    final forShare = _forId == null
        ? 0.0
        : items.fold(0.0, (a, t) => a + t.shareOf(_forId));

    final groups = <int, List<TxnRow>>{};
    for (final t in items) {
      groups.putIfAbsent(t.ageInDays, () => []).add(t);
    }
    final dayKeys = groups.keys.toList()..sort();

    final allShownSelected =
        items.isNotEmpty && items.every((t) => _selectedIds.contains(t.id));

    final palette =
        context.watch<ThemeController?>()?.palette ?? Nocturne.palette;

    return RefreshIndicator(
      onRefresh: s.refresh,
      color: palette.accent,
      backgroundColor: palette.surface,
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
                      Text('Activity',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: palette.text)),
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
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: palette.muted)),
                            ),
                            const SizedBox(width: 4),
                            Icon(PhBold.caretDown,
                                size: 10, color: palette.muted),
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
                        style: TextStyle(
                            fontSize: 12, color: palette.muted)),
                    if (!V3Sheets.readOnly) ...[
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
                                ? palette.tint
                                : palette.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selecting
                                  ? palette.tintEdge
                                  : palette.edge,
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
                                    ? palette.accentLight
                                    : palette.subtle,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selecting ? 'Done' : 'Select',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _selecting
                                      ? palette.accentLight
                                      : palette.subtle,
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
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: palette.edge, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhRegular.downloadSimple,
                                  size: 12, color: Nocturne.palette.accentLight),
                              SizedBox(width: 4),
                              Text('Import',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Nocturne.palette.accentLight)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: palette.edge, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhRegular.shareNetwork,
                                size: 12, color: palette.subtle),
                            const SizedBox(width: 4),
                            Text('Export',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: palette.subtle)),
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
              color: palette.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: palette.edge, width: 1),
            ),
            child: Row(
              children: [
                Icon(PhRegular.magnifyingGlass,
                    size: 18, color: palette.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style:
                        TextStyle(fontSize: 14, color: palette.text),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search merchant, category, member',
                      hintStyle: TextStyle(
                          fontSize: 14, color: palette.muted),
                    ),
                  ),
                ),
                if (_search.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_search.clear),
                    child: Icon(PhFill.xCircle,
                        size: 16, color: palette.muted),
                  ),
              ],
            ),
          ),
          // Type segment (includes Imported tab)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                for (final o in [
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
                              ? palette.tint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _type == o.$1
                                ? palette.tintEdge
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
                            fontWeight: _type == o.$1 ? FontWeight.w600 : FontWeight.w400,
                            color: _type == o.$1
                                ? palette.accent
                                : palette.muted,
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
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.accent, width: 1),
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
                            ? Nocturne.palette.muted
                            : Nocturne.palette.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} selected',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.palette.text,
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey('activity_batch_edit'),
                        onTap: _selectedIds.isEmpty || _deleting
                            ? null
                            : () => _editSelected(s),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedIds.isEmpty
                                ? Nocturne.palette.edge
                                : Nocturne.palette.tint,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _selectedIds.isEmpty
                                  ? Nocturne.palette.faint
                                  : Nocturne.palette.fabEdge,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhRegular.pencilSimple,
                                size: 13,
                                color: _selectedIds.isEmpty
                                    ? Nocturne.palette.muted
                                    : Nocturne.palette.accentLight,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedIds.isEmpty
                                      ? Nocturne.palette.muted
                                      : Nocturne.palette.accentLight,
                                ),
                              ),
                            ],
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
                                ? Nocturne.palette.edge
                                : Nocturne.mix(Nocturne.palette.expense, 20),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _selectedIds.isEmpty
                                  ? Nocturne.palette.faint
                                  : Nocturne.palette.expense,
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
                                    ? Nocturne.palette.muted
                                    : Nocturne.palette.expense,
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
                                      ? Nocturne.palette.muted
                                      : Nocturne.palette.expense,
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
                      onTap: () => setState(() {
                        _catKey = _catKey == k ? null : k;
                        _subId = null;
                      }),
                    );
                  },
                ),
              ),
            ),
          if (subIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: subIds.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final sub = s.categoryById(subIds[i])!;
                    return V3Chip(
                      label: sub.name,
                      height: 28,
                      icon: s.catStyle(sub.key).icon,
                      iconColor: s.catStyle(sub.key).color,
                      selected: _subId == sub.id,
                      onTap: () => setState(
                          () => _subId = _subId == sub.id ? null : sub.id),
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
                  Text('By',
                      style: TextStyle(
                          fontSize: 11.5, color: Nocturne.palette.muted)),
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
                              ringColor: on ? Nocturne.palette.fabEdge : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (s.isFamily && s.members.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('For',
                      style: TextStyle(
                          fontSize: 11.5, color: Nocturne.palette.muted)),
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
                          final on = _forId == m.userId;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _forId = on ? null : m.userId),
                            child: V3Avatar(
                              initial: m.initial,
                              color: m.color,
                              size: 30,
                              fontSize: 11.5,
                              opacity: _forId == null || on ? 1 : 0.4,
                              ringColor: on ? Nocturne.palette.fabEdge : null,
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
                      color: Nocturne.palette.text),
                ),
                const SizedBox(width: 8),
                  Expanded(
                  child: forName != null
                      ? _MiniStat(
                          label: "$forName's share",
                          value: s.money(forShare),
                          color: Nocturne.palette.accentLight)
                      : _MiniStat(
                          label: 'Received · shown',
                          value: s.money(received),
                          color: Nocturne.palette.income),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
              child: Column(
                children: [
                  Icon(PhRegular.receiptX,
                      size: 38, color: Nocturne.palette.faint),
                  const SizedBox(height: 8),
                  Text('No transactions match',
                      style: TextStyle(
                          fontSize: 14, color: Nocturne.palette.neutral300)),
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
                            Border.all(color: Nocturne.palette.switchOn, width: 1),
                      ),
                      child: Text('Reset filters',
                          style: TextStyle(
                              fontSize: 12.5, color: Nocturne.palette.accentLight)),
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
                                  ? Nocturne.palette.accent
                                  : Nocturne.palette.muted,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(_dayLabel(day).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 0.58,
                                  color: Nocturne.palette.muted)),
                        ],
                      ),
                      V3Num(
                        s.money(groups[day]!
                            .where((t) => t.isExpense)
                            .fold(0.0, (a, t) => a + t.amount)),
                        style: TextStyle(
                            fontSize: 11.5, color: Nocturne.palette.muted),
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
        ? Nocturne.palette.expense
        : accent
            ? Nocturne.palette.accentLight
            : Nocturne.palette.neutral300;
    final bg = danger
        ? Nocturne.mix(Nocturne.palette.expense, 14)
        : accent
            ? Nocturne.palette.tint
            : Nocturne.palette.bg;
    final border = danger
        ? Nocturne.mix(Nocturne.palette.expense, 40)
        : accent
            ? Nocturne.palette.switchOn
            : Nocturne.palette.edge;

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
  Widget build(BuildContext context) {
    final p = context.watch<ThemeController?>()?.palette ?? Nocturne.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.edge, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: p.muted)),
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
}

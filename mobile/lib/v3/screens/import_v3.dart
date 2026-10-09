import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/expense_import.dart';
import '../data/expense_import_xlsx.dart';
import '../data/import_picker.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../sheets/batch_edit_sheet.dart';
import '../v3_state.dart';
import '../widgets/v3_motion.dart';
import '../widgets/v3_primitives.dart';

/// Bringing expenses in from a file, a pasted table or an existing note.
///
/// Nothing is written until the rows have been shown and confirmed: these
/// files are often messy, and a silent import of a misread column is worse
/// than no import at all.
class ImportV3 extends StatefulWidget {
  const ImportV3({super.key, this.initialText, this.sourceLabel});

  /// Pre-filled when arriving from a note, so the note's text is parsed
  /// straight away.
  final String? initialText;
  final String? sourceLabel;

  static Future<void> open(BuildContext context,
      {String? text, String? label}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportV3(initialText: text, sourceLabel: label),
    ));
  }

  /// Opens the batch-selection sheet for already-imported transactions.
  static Future<void> openManageImported(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ManageImportedSheet(),
    );
  }

  @override
  State<ImportV3> createState() => _ImportV3State();
}

class _ImportV3State extends State<ImportV3> {
  final _paste = TextEditingController();

  List<ImportedExpense> _rows = const [];
  String? _source;
  bool _busy = false;
  bool _parsed = false;

  /// Account rows go to when nothing in the row says otherwise.
  String? _intoSourceId;

  @override
  void initState() {
    super.initState();
    _intoSourceId = context.read<V3State>().defaultImportSourceId;
    if (widget.initialText != null) {
      _source = widget.sourceLabel;
      _rows = _routed(ExpenseImport.parse(widget.initialText!));
      _parsed = true;
    }
  }

  List<ImportedExpense> _routed(List<ImportedExpense> rows) {
    context.read<V3State>().routeImport(rows, fallbackId: _intoSourceId);
    return rows;
  }

  void _setInto(String id) {
    setState(() {
      _intoSourceId = id;
      _routed(_rows);
    });
  }

  Future<void> _pickRowAccount(ImportedExpense row) async {
    final s = context.read<V3State>();
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountPicker(sources: s.sources, current: row.sourceId),
    );
    if (id == null || !mounted) return;
    setState(() {
      row.sourceId = id;
      row.pinned = true;
    });
  }

  Future<void> _editSelected() async {
    final chosen = _rows.where((r) => r.selected).toList();
    if (chosen.isEmpty) return;
    final edit = await BatchEditSheet.open(context, count: chosen.length);
    if (edit == null || !mounted) return;
    setState(() {
      for (final r in chosen) {
        if (edit.isIncome != null) r.isIncome = edit.isIncome!;
      }
      // Direction feeds routing (a salary credit goes to Salary), so re-route
      // first and let explicit picks win afterwards.
      _routed(_rows);
      for (final r in chosen) {
        if (edit.sourceId != null) {
          r.sourceId = edit.sourceId;
          r.pinned = true;
        }
      }
      for (final r in chosen) {
        if (edit.categoryKey != null) {
          r.categoryKey = edit.categoryKey;
          r.categoryPinned = true;
        }
      }
    });
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    final doc = await ImportPicker.pick();
    if (!mounted) return;

    if (doc == null) {
      setState(() => _busy = false);
      return;
    }

    final rows = doc.isSpreadsheet
        ? (doc.bytes == null
            ? const <ImportedExpense>[]
            : ExpenseImportXlsx.parse(doc.bytes!))
        : ExpenseImport.parse(doc.text, kind: doc.kind);

    setState(() {
      _rows = _routed(rows);
      _source = doc.fileName;
      _parsed = true;
      _busy = false;
    });
  }

  void _parsePaste() {
    final text = _paste.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _rows = _routed(ExpenseImport.parse(text));
      _source = 'Pasted text';
      _parsed = true;
    });
  }

  Future<void> _pickNote() async {
    final s = context.read<V3State>();
    final note = await showModalBottomSheet<NoteRow>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotePicker(notes: s.notes),
    );
    if (note == null || !mounted) return;

    // The Markdown export is the fullest rendering of a note's blocks, so the
    // importer reads that rather than the flattened preview text.
    final text = DataExport.noteMarkdown(note);
    setState(() {
      _rows = _routed(ExpenseImport.parse(text, kind: 'md'));
      _source = note.title.isEmpty ? 'Untitled note' : note.title;
      _parsed = true;
    });
  }

  Future<void> _import() async {
    final selected = _rows.where((r) => r.selected).length;
    if (selected == 0) return;

    setState(() => _busy = true);
    final n = await context.read<V3State>().importExpenses(_rows);
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Nothing was imported'
          : 'Added $n transaction${n == 1 ? '' : 's'}'),
    ));
    if (n > 0) Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteAllImported(V3State s) async {
    final count = s.importedTxns.length;
    if (count == 0 || _busy) return;
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
          'This will permanently remove all $count imported transaction${count == 1 ? '' : 's'}. Manually added entries will not be touched.',
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
              'Delete all',
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

    setState(() => _busy = true);
    final removed = await s.deleteImportedTransactions();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted $removed imported transaction${removed == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  void _handleBack() {
    if (_parsed) {
      setState(() {
        _parsed = false;
        _rows = [];
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _openCsvHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CsvHelpSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _rows.where((r) => r.selected).length;

    return PopScope(
      canPop: !_parsed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _parsed) {
          setState(() {
            _parsed = false;
            _rows = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: Nocturne.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 16, 2),
                child: Row(
                  children: [
                    V3Press(
                      onTap: _handleBack,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(PhRegular.arrowLeft,
                            size: 20, color: Nocturne.text),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text('Import expenses',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openCsvHelp,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Nocturne.surface,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Nocturne.neutral800, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhRegular.info,
                                size: 16, color: Nocturne.accent200),
                            SizedBox(width: 5),
                            Text('Format & AI Prompt',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.accent200)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  if (!_parsed) ..._sourceChoices(),
                  if (_parsed) ..._preview(),
                ],
              ),
            ),
            if (_parsed && _rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: V3Press(
                  onTap: _busy ? null : _import,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Nocturne.accent600, Nocturne.accent800],
                      ),
                      border:
                          Border.all(color: Nocturne.accent400, width: 1),
                    ),
                    child: Text(
                      _busy
                          ? 'Importing…'
                          : 'Import $selected transaction'
                              '${selected == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.accent100),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  List<Widget> _sourceChoices() {
    final s = context.watch<V3State>();
    final imported = s.importedTxns;

    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          'Bring in spending from a bank export, a spreadsheet, or a note '
          'you already keep. Nothing is saved until you have seen what was '
          'read.',
          style: TextStyle(
              fontSize: 12.5, height: 1.5, color: Nocturne.neutral400),
        ),
      ),
      if (imported.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Nocturne.neutral800, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhRegular.downloadSimple,
                      size: 16, color: Nocturne.accent200),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${imported.length} imported transaction${imported.length == 1 ? '' : 's'} in workspace',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Need to clean up a previous import? Batch-select specific rows or delete all imported transactions.',
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: Nocturne.neutral400),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: V3Press(
                      onTap: () => ImportV3.openManageImported(context),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Nocturne.bg,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Nocturne.neutral700, width: 1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhRegular.listChecks,
                                size: 15, color: Nocturne.accent200),
                            SizedBox(width: 6),
                            Text(
                              'Batch select',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Nocturne.accent200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: V3Press(
                      onTap: _busy ? null : () => _confirmDeleteAllImported(s),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Nocturne.mix(NocturneSemantic.expense, 16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Nocturne.mix(NocturneSemantic.expense, 45),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhRegular.trash,
                                size: 15, color: NocturneSemantic.expense),
                            const SizedBox(width: 6),
                            Text(
                              'Delete all (${imported.length})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: NocturneSemantic.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      _SourceTile(
        icon: PhRegular.floppyDisk,
        title: 'Choose a file',
        subtitle: 'CSV, Excel, Markdown or text',
        busy: _busy,
        onTap: _pickFile,
      ),
      _SourceTile(
        icon: PhRegular.note,
        title: 'From a note',
        subtitle: 'Read a table or list you already wrote',
        onTap: _pickNote,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text('Or paste a table',
            style: TextStyle(fontSize: 12.5, color: Nocturne.neutral400)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nocturne.neutral800, width: 1),
        ),
        child: TextField(
          controller: _paste,
          maxLines: 7,
          style: const TextStyle(fontSize: 13.5, color: Nocturne.text),
          cursorColor: Nocturne.accent,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Coffee 120\nGroceries 1,240\n\n'
                'or a | Date | Item | Amount | table',
            hintStyle:
                TextStyle(fontSize: 13.5, color: Nocturne.neutral600),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: V3Press(
          onTap: _parsePaste,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Nocturne.accent, width: 1),
            ),
            child: const Text('Read pasted text',
                style:
                    TextStyle(fontSize: 14.5, color: Nocturne.accent200)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _preview() {
    if (_rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          child: Column(
            children: [
              const Icon(PhRegular.receiptX,
                  size: 38, color: Nocturne.neutral600),
              const SizedBox(height: 10),
              const Text('Nothing recognisable',
                  style:
                      TextStyle(fontSize: 14.5, color: Nocturne.neutral300)),
              const SizedBox(height: 6),
              Text(
                'No rows in ${_source ?? 'that source'} had both a '
                'description and an amount. A column named Amount, or lines '
                'like "Coffee 120", are read best.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.5, color: Nocturne.neutral500),
              ),
              const SizedBox(height: 18),
              V3Press(
                onTap: () => setState(() {
                  _parsed = false;
                  _rows = const [];
                }),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Nocturne.accent, width: 1),
                  ),
                  child: const Text('Try another source',
                      style: TextStyle(
                          fontSize: 14, color: Nocturne.accent200)),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final s = context.watch<V3State>();
    final total = _rows
        .where((r) => r.selected && !r.isIncome)
        .fold<double>(0, (a, r) => a + r.amount);
    final allSelected = _rows.every((r) => r.selected);

    return [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Nocturne.accent900,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(PhRegular.checkCircle,
                size: 17, color: Nocturne.accent200),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Read ${_rows.length} row${_rows.length == 1 ? '' : 's'} '
                'from ${_source ?? 'the file'}. Untick anything you do not '
                'want.',
                style: const TextStyle(
                    fontSize: 12, height: 1.45, color: Nocturne.accent200),
              ),
            ),
          ],
        ),
      ),
      if (s.sources.isNotEmpty) _intoCard(s),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                final next = !allSelected;
                for (final r in _rows) {
                  r.selected = next;
                }
              }),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allSelected ? PhFill.checkCircle : PhRegular.circle,
                    size: 16,
                    color: allSelected ? Nocturne.accent : Nocturne.neutral500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allSelected ? 'Deselect all' : 'Select all',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Nocturne.accent200,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _rows.any((r) => r.selected) ? _editSelected : null,
              behavior: HitTestBehavior.opaque,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhRegular.pencilSimple,
                      size: 15, color: Nocturne.accent200),
                  SizedBox(width: 5),
                  Text('Edit selected',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Nocturne.accent200)),
                ],
              ),
            ),
            const Spacer(),
            const Text('Spent · ',
                style: TextStyle(
                    fontSize: 12.5, color: Nocturne.neutral400)),
            Text(s.money(total),
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text)),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var i = 0; i < _rows.length; i++) ...[
              V3Rise(
                index: i,
                child: _RowTile(
                  row: _rows[i],
                  money: s.money,
                  accountName: s.sourceById(_rows[i].sourceId)?.name,
                  categoryName: _rows[i].categoryKey == null
                      ? null
                      : s.catStyle(_rows[i].categoryKey!).name,
                  onToggle: () => setState(
                      () => _rows[i].selected = !_rows[i].selected),
                  onAccount: s.sources.isEmpty
                      ? null
                      : () => _pickRowAccount(_rows[i]),
                ),
              ),
              if (i < _rows.length - 1) const V3RowDivider(),
            ],
          ],
        ),
      ),
    ];
  }
}

extension on _ImportV3State {
  Widget _intoCard(V3State s) {
    final routedElsewhere =
        _rows.where((r) => !r.pinned && r.sourceId != _intoSourceId).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nocturne.neutral800, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('IMPORT INTO',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.neutral400)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final src in s.sources)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      key: ValueKey('import_into_${src.id}'),
                      onTap: () => _setInto(src.id),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: _intoSourceId == src.id
                              ? Nocturne.accent900
                              : Nocturne.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _intoSourceId == src.id
                                  ? Nocturne.accent400
                                  : Nocturne.neutral800),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(src.design.icon,
                                size: 14,
                                color: _intoSourceId == src.id
                                    ? Nocturne.accent200
                                    : Nocturne.neutral400),
                            const SizedBox(width: 6),
                            Text(src.name,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: _intoSourceId == src.id
                                        ? Nocturne.accent100
                                        : Nocturne.neutral300)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            routedElsewhere == 0
                ? 'Salary credits go to Salary, loan disbursals to Loan, rent '
                    'received to Rental — automatically. Tap a row\'s account '
                    'to change it.'
                : '$routedElsewhere row${routedElsewhere == 1 ? '' : 's'} '
                    'filed elsewhere automatically (salary, loan, rent or the '
                    'account named in the file). Tap a row\'s account to change it.',
            style: const TextStyle(
                fontSize: 11.5, height: 1.4, color: Nocturne.neutral500),
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({required this.sources, required this.current});

  final List<SourceRow> sources;
  final String? current;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File under account',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.text)),
              const SizedBox(height: 6),
              for (final src in sources)
                V3Press(
                  onTap: () => Navigator.of(context).pop(src.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(src.design.icon,
                            size: 18, color: Nocturne.neutral300),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(src.name,
                              style: const TextStyle(
                                  fontSize: 14, color: Nocturne.text)),
                        ),
                        if (src.id == current)
                          const Icon(PhRegular.check,
                              size: 16, color: Nocturne.accent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: V3Press(
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Nocturne.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Nocturne.neutral800, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Nocturne.accent900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: Nocturne.accent200),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14.5, color: Nocturne.text)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Nocturne.neutral500)),
                    ],
                  ),
                ),
                const Icon(PhRegular.caretRight,
                    size: 14, color: Nocturne.neutral600),
              ],
            ),
          ),
        ),
      );
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.money,
    required this.onToggle,
    this.accountName,
    this.categoryName,
    this.onAccount,
  });

  final ImportedExpense row;
  final String Function(double) money;
  final VoidCallback onToggle;
  final String? accountName;
  final String? categoryName;
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context) {
    final date = row.date;
    return V3Press(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              row.selected ? PhFill.checkCircle : PhRegular.circle,
              size: 20,
              color: row.selected ? Nocturne.accent : Nocturne.neutral600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: row.selected
                          ? Nocturne.text
                          : Nocturne.neutral500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (date != null)
                        '${date.day}/${date.month}/${date.year}'
                      else
                        'No date · today',
                      if (categoryName != null)
                        categoryName!
                      else if (row.category != null)
                        row.category!,
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11.5, color: Nocturne.neutral500),
                  ),
                ],
              ),
            ),
            if (onAccount != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAccount,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 96),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Nocturne.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: row.pinned
                            ? Nocturne.accent400
                            : Nocturne.neutral800),
                  ),
                  child: Text(
                    accountName ?? 'No account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Nocturne.accent200),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              '${row.isIncome ? '+' : '−'}${money(row.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: !row.selected
                    ? Nocturne.neutral600
                    : row.isIncome
                        ? NocturneSemantic.income
                        : Nocturne.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotePicker extends StatelessWidget {
  const _NotePicker({required this.notes});

  final List<NoteRow> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick a note',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.text)),
          const SizedBox(height: 10),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('You have no notes yet',
                  style:
                      TextStyle(fontSize: 13, color: Nocturne.neutral500)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: notes.length,
                itemBuilder: (_, i) {
                  final n = notes[i];
                  return V3Press(
                    onTap: () => Navigator.of(context).pop(n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                              n.isPrivate
                                  ? PhRegular.lockSimple
                                  : PhRegular.users,
                              size: 17,
                              color: Nocturne.neutral400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              n.title.isEmpty ? 'Untitled' : n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, color: Nocturne.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageImportedSheet extends StatefulWidget {
  const _ManageImportedSheet();

  @override
  State<_ManageImportedSheet> createState() => _ManageImportedSheetState();
}

class _ManageImportedSheetState extends State<_ManageImportedSheet> {
  final Set<String> _selectedIds = <String>{};
  bool _initialized = false;
  bool _deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final imported = context.read<V3State>().importedTxns;
      _selectedIds.addAll(imported.map((t) => t.id));
      _initialized = true;
    }
  }

  Future<void> _editSelectedImported(V3State s) async {
    final edit = await BatchEditSheet.open(context, count: _selectedIds.length);
    if (edit == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = await s.batchUpdateTransactions(
      _selectedIds,
      sourceId: edit.sourceId,
      categoryKey: edit.categoryKey,
      type: edit.isIncome == null ? null : (edit.isIncome! ? 'income' : 'expense'),
    );
    messenger.showSnackBar(SnackBar(
        content: Text('Updated $n transaction${n == 1 ? '' : 's'}')));
  }

  Future<void> _deleteSelected(V3State s) async {
    if (_selectedIds.isEmpty || _deleting) return;
    setState(() => _deleting = true);
    final ids = _selectedIds.toList();
    final removed = await s.deleteTransactions(ids);
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selectedIds.clear();
    });
    final messenger = ScaffoldMessenger.of(context);
    if (s.importedTxns.isEmpty) {
      Navigator.of(context).pop();
    }
    messenger.showSnackBar(
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
    final rows = s.importedTxns;
    final allSelected =
        rows.isNotEmpty && rows.every((t) => _selectedIds.contains(t.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Nocturne.neutral700, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Nocturne.neutral700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Imported transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text,
                  ),
                ),
              ),
              if (rows.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    if (allSelected) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds
                        ..clear()
                        ..addAll(rows.map((t) => t.id));
                    }
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Nocturne.bg,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Nocturne.neutral800, width: 1),
                    ),
                    child: Text(
                      allSelected
                          ? 'Deselect all'
                          : 'Select all (${rows.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Nocturne.accent200,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No imported transactions in this workspace.',
                  style: TextStyle(fontSize: 13, color: Nocturne.neutral500),
                ),
              ),
            )
          else ...[
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const V3RowDivider(),
                itemBuilder: (_, i) {
                  final t = rows[i];
                  final sel = _selectedIds.contains(t.id);
                  final d = t.occurredAt;
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (!_selectedIds.remove(t.id)) {
                        _selectedIds.add(t.id);
                      }
                    }),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Icon(
                            sel ? PhFill.checkCircle : PhRegular.circle,
                            size: 20,
                            color:
                                sel ? Nocturne.accent : Nocturne.neutral500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: sel
                                        ? Nocturne.text
                                        : Nocturne.neutral400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.day}/${d.month}/${d.year} · ${s.catStyle(t.categoryKey).name} · ${s.sourceById(t.sourceId)?.name ?? 'No account'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Nocturne.neutral500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${t.isExpense ? '−' : '+'}${s.money(t.amount)}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: t.isExpense
                                  ? Nocturne.text
                                  : NocturneSemantic.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            V3Press(
              onTap: _selectedIds.isEmpty || _deleting
                  ? null
                  : () => _editSelectedImported(s),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nocturne.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _selectedIds.isEmpty
                          ? Nocturne.neutral700
                          : Nocturne.accent400),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhRegular.pencilSimple,
                        size: 16, color: Nocturne.accent200),
                    const SizedBox(width: 8),
                    Text(
                      'Edit ${_selectedIds.length} selected (account, type, category)',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.accent200),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            V3Press(
              onTap: _selectedIds.isEmpty || _deleting
                  ? null
                  : () => _deleteSelected(s),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedIds.isEmpty
                      ? Nocturne.neutral800
                      : Nocturne.mix(NocturneSemantic.expense, 20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedIds.isEmpty
                        ? Nocturne.neutral700
                        : NocturneSemantic.expense,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhRegular.trash,
                      size: 16,
                      color: _selectedIds.isEmpty
                          ? Nocturne.neutral500
                          : NocturneSemantic.expense,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _deleting
                          ? 'Deleting…'
                          : 'Delete ${_selectedIds.length} selected transaction${_selectedIds.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 14,
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
        ],
      ),
    );
  }
}

// ── CSV Format & AI Prompt Help Sheet ────────────────────────────────────────

class _CsvHelpSheet extends StatefulWidget {
  const _CsvHelpSheet();

  @override
  State<_CsvHelpSheet> createState() => _CsvHelpSheetState();
}

class _CsvHelpSheetState extends State<_CsvHelpSheet> {
  bool _copied = false;

  static const _sampleCsv = '''Date,Title,Amount,Type,Category,Method
2026-10-01,Monthly Salary,75000,income,Salary,Bank
2026-10-02,Supermarket Groceries,3450,expense,Groceries,UPI
2026-10-03,Electricity Bill,1850,expense,Utilities,Card
2026-10-05,Fuel Petrol,2000,expense,Transport,UPI''';

  static const _aiPrompt = '''Please convert my bank statement or transaction text into a clean CSV format for my family finance tracker.

Required CSV Headers:
Date,Title,Amount,Type,Category,Method

Format Rules:
1. Date: YYYY-MM-DD (e.g. 2026-10-01)
2. Title: Clean merchant or description name (e.g. Supermarket, Electricity Bill, Salary)
3. Amount: Pure positive number (no currency symbols or commas, e.g. 3450 or 1850.50)
4. Type: "expense" for debits/spending, or "income" for credits/salary/deposits
5. Category: One of Groceries, Food, Utilities, Transport, Shopping, Healthcare, Housing, Entertainment, Salary, Investment, Loan, Other
6. Method: UPI, Cash, Card, Bank, or Loan

Output ONLY the CSV block without any markdown chat or extra explanations. Here are my transactions:
[PASTE YOUR TRANSACTIONS OR BANK STATEMENT HERE]''';

  void _copyPrompt() {
    Clipboard.setData(const ClipboardData(text: _aiPrompt));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI Prompt copied to clipboard! Paste into Gemini or ChatGPT.'),
        backgroundColor: Nocturne.surface,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _copySample() {
    Clipboard.setData(const ClipboardData(text: _sampleCsv));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample CSV copied to clipboard!'),
        backgroundColor: Nocturne.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Nocturne.neutral700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(PhRegular.downloadSimple, size: 22, color: Nocturne.accent200),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'CSV Format & AI Prompt Guide',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Nocturne.text,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(PhRegular.x, size: 20, color: Nocturne.neutral400),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Upload CSV files with specific dates, amounts, categories and sources. If you have raw bank statements or spreadsheets, copy our AI prompt below to instantly format them.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: Nocturne.neutral400),
            ),
            const SizedBox(height: 16),

            // ── AI Prompt Box ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nocturne.accent800, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(PhRegular.sparkle, size: 16, color: Nocturne.accent200),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Prompt to give Gemini / ChatGPT',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Nocturne.text,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _copyPrompt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _copied ? NocturneSemantic.income : Nocturne.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _copied ? PhBold.check : PhRegular.copy,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _copied ? 'Copied!' : 'Copy prompt',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    _aiPrompt,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      fontFamily: 'monospace',
                      color: Nocturne.neutral300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Supported Headers Explanation ──────────────────────────────
            const Text(
              'Required & Supported Columns',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Nocturne.text,
              ),
            ),
            const SizedBox(height: 8),
            _headerGuideItem('Date', 'YYYY-MM-DD, DD/MM/YYYY, or standard bank date formats.'),
            _headerGuideItem('Title', 'Merchant name, recipient, or item description.'),
            _headerGuideItem('Amount', 'Value in ₹ (Dr / Cr automatically mapped).'),
            _headerGuideItem('Type', 'expense (debit) or income (credit / salary).'),
            _headerGuideItem('Category', 'Groceries, Utilities, Transport, Food, Salary, etc.'),
            _headerGuideItem('Method', 'UPI, Cash, Card, Bank, Loan (optional).'),
            const SizedBox(height: 14),

            // ── Sample CSV preview ─────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Sample CSV Template',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _copySample,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhRegular.copy, size: 13, color: Nocturne.accent200),
                      SizedBox(width: 4),
                      Text(
                        'Copy sample',
                        style: TextStyle(fontSize: 11.5, color: Nocturne.accent200),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Nocturne.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: const Text(
                _sampleCsv,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  fontFamily: 'monospace',
                  color: Nocturne.neutral300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerGuideItem(String col, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Nocturne.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Nocturne.neutral700, width: 1),
            ),
            child: Text(
              col,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Nocturne.accent200,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(fontSize: 11.5, color: Nocturne.neutral400),
            ),
          ),
        ],
      ),
    );
  }
}

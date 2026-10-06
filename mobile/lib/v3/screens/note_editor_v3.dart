import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/note_blocks.dart';
import '../data/note_structure.dart';
import '../data/notes_presence.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import 'notes_widgets.dart';

/// The Family Notes block editor: heading, paragraph, checklist and table
/// blocks, a per-block tool row when focused, and the floating round toolbar.
class NoteEditorV3 extends StatefulWidget {
  final NoteRow? note;
  final List<NoteBlock>? initialBlocks;

  const NoteEditorV3({super.key, this.note, this.initialBlocks});

  @override
  State<NoteEditorV3> createState() => _NoteEditorV3State();
}

class _NoteEditorV3State extends State<NoteEditorV3> {
  late final TextEditingController _title;
  late List<NoteBlock> _blocks;
  late bool _pinned;
  late bool _private;

  String? _focusedBlock;
  bool _dirty = false;
  bool _saving = false;
  DateTime? _savedAt;

  /// Simple linear history so undo/redo in the header do something real.
  final List<List<NoteBlock>> _history = [];
  int _historyAt = -1;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _title = TextEditingController(text: n?.title ?? '');
    _blocks = n != null && n.blocks.isNotEmpty
        ? List.of(n.blocks)
        : List.of(widget.initialBlocks ?? [NoteBlock.paragraph()]);
    _pinned = n?.pinned ?? false;
    _private = n?.isPrivate ?? false;
    _pushHistory();

    // Tell the family which note this device has open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotesPresenceService>().setActiveNote(
            widget.note?.id ?? 'new',
            title: _title.text.isEmpty ? 'a new note' : _title.text,
          );
    });
  }

  @override
  void dispose() {
    // Read before the element is unmounted; dispose() must not use context.
    _presence?.setActiveNote(null);
    _title.dispose();
    super.dispose();
  }

  NotesPresenceService? _presence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _presence = context.read<NotesPresenceService>();
  }

  /// Broadcasts that this device is typing, at most a few times a second.
  void _typed() {
    _dirty = true;
    final id = widget.note?.id ?? 'new';
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(milliseconds: 900)) {
      _lastTyping = now;
      _presence?.sendTyping(id);
    }
  }

  DateTime? _lastTyping;

  void _pushHistory() {
    // Drop any redo branch before recording a new state.
    if (_historyAt < _history.length - 1) {
      _history.removeRange(_historyAt + 1, _history.length);
    }
    _history.add(_blocks.map((b) => b.copyWith()).toList());
    _historyAt = _history.length - 1;
    if (_history.length > 50) {
      _history.removeAt(0);
      _historyAt--;
    }
  }

  void _mutate(void Function() change) {
    setState(() {
      change();
      _typed();
    });
    _pushHistory();
  }

  bool get _canUndo => _historyAt > 0;
  bool get _canRedo => _historyAt < _history.length - 1;

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      _historyAt--;
      _blocks = _history[_historyAt].map((b) => b.copyWith()).toList();
      _dirty = true;
    });
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyAt++;
      _blocks = _history[_historyAt].map((b) => b.copyWith()).toList();
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = context.read<V3State>();
    setState(() => _saving = true);

    final kept = _blocks.where((b) => !b.isEmpty).toList();
    final ok = await s.saveNote(
      id: widget.note?.id,
      title: _title.text.trim(),
      blocks: kept.isEmpty ? [NoteBlock.paragraph()] : kept,
      pinned: _pinned,
      isPrivate: _private,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = !ok;
      if (ok) _savedAt = DateTime.now();
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — check your connection')),
      );
    }
  }

  Future<void> _delete() async {
    final id = widget.note?.id;
    if (id == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: const Text('Delete note?',
            style: TextStyle(fontSize: 17, color: Nocturne.text)),
        content: const Text('This cannot be undone.',
            style: TextStyle(fontSize: 14, color: Nocturne.neutral400)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Nocturne.neutral400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: NocturneSemantic.expense))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<V3State>().deleteNote(id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareNote() async {
    final title = _title.text.trim().isEmpty ? 'Note' : _title.text.trim();
    final md = DataExport.noteMarkdown(NoteRow(
      id: widget.note?.id ?? 'temp',
      title: title,
      content: blocksToPlainText(_blocks),
      pinned: _pinned,
      visibility: _private ? 'private' : 'family',
      folderId: widget.note?.folderId,
      updatedAt: DateTime.now(),
      blocks: _blocks,
    ));
    final filename =
        '${title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')}.md';
    await DataExport.share(md, filename, subject: title);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    final parsed = parsePastedText(text);
    _mutate(() {
      final keep = _blocks.where((b) => !b.isEmpty).toList();
      _blocks = [...keep, ...parsed];
    });
    if (mounted) {
      final tables =
          parsed.where((b) => b.kind == NoteBlockKind.table).length;
      final lists = parsed.where((b) => b.kind == NoteBlockKind.todo).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pasted ${parsed.length} block'
            '${parsed.length == 1 ? '' : 's'}'
            '${tables > 0 ? ' · $tables table${tables == 1 ? '' : 's'}' : ''}'
            '${lists > 0 ? ' · $lists list${lists == 1 ? '' : 's'}' : ''}'),
      ));
    }
  }

  void _add(NoteBlock b) => _mutate(() {
        _blocks.add(b);
        _focusedBlock = b.id;
      });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();

    return Scaffold(
      backgroundColor: Nocturne.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(s),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    children: [
                      Text(_dateLine(),
                          style: const TextStyle(
                              fontSize: 12, color: Nocturne.neutral500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MetaChip(
                            icon: _private
                                ? PhRegular.lockSimple
                                : PhRegular.users,
                            label: _private
                                ? 'Private to you'
                                : 'Shared with ${s.family?.name ?? 'family'}',
                            background: _private
                                ? Nocturne.neutral900
                                : Nocturne.accent900,
                            color: _private
                                ? Nocturne.neutral300
                                : Nocturne.accent200,
                            onTap: () => setState(() {
                              _private = !_private;
                              _dirty = true;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _MetaChip(
                            icon: _pinned
                                ? PhFill.pushPin
                                : PhRegular.pushPin,
                            label: _pinned ? 'Pinned' : 'Pin',
                            background: Nocturne.neutral900,
                            color: _pinned
                                ? Nocturne.accent200
                                : Nocturne.neutral400,
                            onTap: () => setState(() {
                              _pinned = !_pinned;
                              _dirty = true;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _title,
                              onChanged: (_) => setState(_typed),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.24,
                                  color: Nocturne.text),
                              cursorColor: Nocturne.accent,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Untitled',
                                hintStyle: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: Nocturne.neutral700),
                              ),
                            ),
                          ),
                          const Icon(PhRegular.pencilSimple,
                              size: 18, color: Nocturne.neutral500),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _syncLine(s),
                      const SizedBox(height: 16),
                      for (final b in _blocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _BlockView(
                            block: b,
                            focused: _focusedBlock == b.id,
                            onFocus: () =>
                                setState(() => _focusedBlock = b.id),
                            onChanged: (next) => _mutate(() {
                              final i =
                                  _blocks.indexWhere((x) => x.id == b.id);
                              if (i != -1) _blocks[i] = next;
                            }),
                            onDelete: () => _mutate(() {
                              _blocks.removeWhere((x) => x.id == b.id);
                              if (_blocks.isEmpty) {
                                _blocks.add(NoteBlock.paragraph());
                              }
                            }),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _add(NoteBlock.paragraph()),
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Tap to keep writing…',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Nocturne.neutral600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _toolbar()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(V3State s) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (_dirty) await _save();
                if (mounted) Navigator.pop(context);
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(PhRegular.arrowLeft,
                    size: 22, color: Nocturne.text),
              ),
            ),
            const Spacer(),
            const _PresenceStrip(),
            _IconBtn(
                icon: PhRegular.arrowCounterClockwise,
                enabled: _canUndo,
                onTap: _undo),
            _IconBtn(
                icon: PhRegular.arrowsClockwise,
                enabled: _canRedo,
                onTap: _redo),
            _IconBtn(
                icon: PhRegular.shareNetwork,
                enabled: true,
                onTap: _shareNote),
            _IconBtn(icon: PhRegular.trash, enabled: true, onTap: _delete),
            GestureDetector(
              onTap: _dirty ? _save : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Nocturne.accent200),
                      )
                    : Text(
                        _dirty ? 'Save' : 'Saved',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: _dirty
                              ? Nocturne.accent200
                              : Nocturne.neutral600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );

  Widget _syncLine(V3State s) {
    final who = widget.note?.updatedBy == null
        ? null
        : s.memberById(widget.note!.updatedBy)?.name;
    final synced = !_dirty;
    return Row(
      children: [
        Icon(synced ? PhFill.checkCircle : PhRegular.clock,
            size: 13,
            color: synced ? NocturneSemantic.income : Nocturne.neutral500),
        const SizedBox(width: 6),
        Text(
          synced
              ? (_savedAt != null ? 'Saved' : 'All changes saved')
              : 'Unsaved changes',
          style: TextStyle(
              fontSize: 11.5,
              color:
                  synced ? NocturneSemantic.income : Nocturne.neutral400),
        ),
        if (who != null) ...[
          const Text('  ·  ',
              style: TextStyle(fontSize: 11.5, color: Nocturne.neutral600)),
          Flexible(
            child: Text('Last edited by $who',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, color: Nocturne.neutral500)),
          ),
        ],
      ],
    );
  }

  Widget _toolbar() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Nocturne.mix(Nocturne.surface, 92),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Nocturne.neutral800, width: 1),
          boxShadow: Nocturne.shadowMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in [
              (PhRegular.textbox, 'Heading', () => _add(NoteBlock.heading())),
              (PhRegular.note, 'Paragraph', () => _add(NoteBlock.paragraph())),
              (PhRegular.listChecks, 'Checklist', () => _add(NoteBlock.todo())),
              (PhRegular.chartBar, 'Table', () => _add(NoteBlock.table())),
              (PhRegular.paperclip, 'Paste', _paste),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: GestureDetector(
                  onTap: t.$3,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Icon(t.$1, size: 20, color: Nocturne.neutral300),
                  ),
                ),
              ),
          ],
        ),
      );

  String _dateLine() {
    final d = widget.note?.updatedAt ?? DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: Nocturne.neutral300),
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color color;
  final VoidCallback onTap;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      );
}

// ── Blocks ──────────────────────────────────────────────────────────────────

class _BlockView extends StatelessWidget {
  final NoteBlock block;
  final bool focused;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;
  final VoidCallback onDelete;

  const _BlockView({
    required this.block,
    required this.focused,
    required this.onFocus,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: focused ? Nocturne.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? Nocturne.neutral800 : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (block.kind) {
            NoteBlockKind.heading => _HeadingBlock(
                block: block, onFocus: onFocus, onChanged: onChanged),
            NoteBlockKind.paragraph => _ParagraphBlock(
                block: block, onFocus: onFocus, onChanged: onChanged),
            NoteBlockKind.todo => _TodoBlock(
                block: block, onFocus: onFocus, onChanged: onChanged),
            NoteBlockKind.table => _TableBlock(
                block: block, onFocus: onFocus, onChanged: onChanged),
          },
          if (focused)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _Tool(
                      icon: PhRegular.trash,
                      label: 'Remove',
                      onTap: onDelete,
                      color: NocturneSemantic.expense),
                  if (block.kind == NoteBlockKind.table) ...[
                    const SizedBox(width: 4),
                    _Tool(
                      icon: PhRegular.plus,
                      label: 'Row',
                      onTap: () => onChanged(block.copyWith(
                        rows: [
                          ...block.rows,
                          List.filled(block.head.length, '')
                        ],
                      )),
                    ),
                    const SizedBox(width: 4),
                    _Tool(
                      icon: PhRegular.plus,
                      label: 'Column',
                      onTap: () => onChanged(block.copyWith(
                        head: [...block.head, ''],
                        rows: block.rows.map((r) => [...r, '']).toList(),
                      )),
                    ),
                  ],
                  if (block.kind == NoteBlockKind.todo) ...[
                    const SizedBox(width: 4),
                    _Tool(
                      icon: PhRegular.checks,
                      label: 'Clear done',
                      onTap: () => onChanged(block.copyWith(
                        items:
                            block.items.where((i) => !i.done).toList(),
                      )),
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

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Nocturne.neutral800, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color ?? Nocturne.neutral300),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: color ?? Nocturne.neutral300)),
            ],
          ),
        ),
      );
}

class _HeadingBlock extends StatefulWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;

  const _HeadingBlock(
      {required this.block, required this.onFocus, required this.onChanged});

  @override
  State<_HeadingBlock> createState() => _HeadingBlockState();
}

class _HeadingBlockState extends State<_HeadingBlock> {
  late final TextEditingController _c =
      TextEditingController(text: widget.block.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onTap: widget.onFocus,
        onChanged: (v) => widget.onChanged(widget.block.copyWith(text: v)),
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w500, color: Nocturne.text),
        cursorColor: Nocturne.accent,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          hintText: 'Heading',
          hintStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Nocturne.neutral700),
        ),
      );
}

class _ParagraphBlock extends StatefulWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;

  const _ParagraphBlock(
      {required this.block, required this.onFocus, required this.onChanged});

  @override
  State<_ParagraphBlock> createState() => _ParagraphBlockState();
}

class _ParagraphBlockState extends State<_ParagraphBlock> {
  late final TextEditingController _c =
      TextEditingController(text: widget.block.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onTap: widget.onFocus,
        onChanged: (v) => widget.onChanged(widget.block.copyWith(text: v)),
        maxLines: null,
        style: const TextStyle(
            fontSize: 14.5, height: 1.6, color: Nocturne.neutral200),
        cursorColor: Nocturne.accent,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          border: InputBorder.none,
          hintText: 'Write something, or paste a table…',
          hintStyle: TextStyle(fontSize: 14.5, color: Nocturne.neutral600),
        ),
      );
}

class _TodoBlock extends StatelessWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;

  const _TodoBlock(
      {required this.block, required this.onFocus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final me = context.read<V3State>().myId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < block.items.length; i++)
          _TodoRow(
            key: ValueKey('${block.id}_$i'),
            item: block.items[i],
            onFocus: onFocus,
            onToggle: () {
              final items = [...block.items];
              final was = items[i];
              items[i] = was.copyWith(
                done: !was.done,
                byUserId: !was.done ? me : null,
              );
              onChanged(block.copyWith(items: items));
            },
            onText: (v) {
              final items = [...block.items];
              items[i] = items[i].copyWith(text: v);
              onChanged(block.copyWith(items: items));
            },
            onSubmit: () {
              final items = [...block.items]
                ..insert(i + 1, const TodoItem(text: ''));
              onChanged(block.copyWith(items: items));
            },
          ),
        GestureDetector(
          onTap: () => onChanged(block.copyWith(
              items: [...block.items, const TodoItem(text: '')])),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            height: 34,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(PhRegular.plus,
                      size: 14, color: Nocturne.neutral500),
                ),
                SizedBox(width: 10),
                Text('Add item',
                    style:
                        TextStyle(fontSize: 13, color: Nocturne.neutral500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoRow extends StatefulWidget {
  final TodoItem item;
  final VoidCallback onFocus;
  final VoidCallback onToggle;
  final ValueChanged<String> onText;
  final VoidCallback onSubmit;

  const _TodoRow({
    super.key,
    required this.item,
    required this.onFocus,
    required this.onToggle,
    required this.onText,
    required this.onSubmit,
  });

  @override
  State<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<_TodoRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.item.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final done = widget.item.done;
    final by = widget.item.byUserId == null
        ? null
        : s.memberById(widget.item.byUserId);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? NocturneSemantic.income : Colors.transparent,
                border: Border.all(
                  color: done
                      ? NocturneSemantic.income
                      : Nocturne.neutral600,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(PhBold.check, size: 12, color: Nocturne.bg)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _c,
              onTap: widget.onFocus,
              onChanged: widget.onText,
              onSubmitted: (_) => widget.onSubmit(),
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 14,
                color: done ? Nocturne.neutral600 : Nocturne.text,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: Nocturne.neutral600,
              ),
              cursorColor: Nocturne.accent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'List item',
                hintStyle:
                    TextStyle(fontSize: 14, color: Nocturne.neutral700),
              ),
            ),
          ),
          if (by != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Nocturne.mix(by.color, 22),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(by.name,
                  style: TextStyle(fontSize: 10, color: by.color)),
            ),
        ],
      ),
    );
  }
}

class _TableBlock extends StatelessWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;

  const _TableBlock(
      {required this.block, required this.onFocus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cols = block.head.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(PhRegular.chartBar,
                size: 12, color: Nocturne.neutral500),
            const SizedBox(width: 6),
            Text('${block.rows.length} rows · $cols columns',
                style: const TextStyle(
                    fontSize: 11.5, color: Nocturne.neutral500)),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 76,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  children: [
                    Container(
                      color: Nocturne.neutral900,
                      child: Row(
                        children: [
                          for (var c = 0; c < cols; c++)
                            _Cell(
                              key: ValueKey('${block.id}_h_$c'),
                              text: block.head[c],
                              header: true,
                              onFocus: onFocus,
                              onChanged: (v) {
                                final head = [...block.head];
                                head[c] = v;
                                onChanged(block.copyWith(head: head));
                              },
                            ),
                        ],
                      ),
                    ),
                    for (var r = 0; r < block.rows.length; r++)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: Nocturne.neutral900, width: 1)),
                        ),
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++)
                              _Cell(
                                key: ValueKey('${block.id}_${r}_$c'),
                                text: block.rows[r].length > c
                                    ? block.rows[r][c]
                                    : '',
                                onFocus: onFocus,
                                onChanged: (v) {
                                  final rows = block.rows
                                      .map((e) => [...e])
                                      .toList();
                                  while (rows[r].length <= c) {
                                    rows[r].add('');
                                  }
                                  rows[r][c] = v;
                                  onChanged(block.copyWith(rows: rows));
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatefulWidget {
  final String text;
  final bool header;
  final VoidCallback onFocus;
  final ValueChanged<String> onChanged;

  const _Cell({
    super.key,
    required this.text,
    this.header = false,
    required this.onFocus,
    required this.onChanged,
  });

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  late final TextEditingController _c =
      TextEditingController(text: widget.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: TextField(
          controller: _c,
          onTap: widget.onFocus,
          onChanged: widget.onChanged,
          textAlign: widget.header ? TextAlign.left : TextAlign.left,
          style: TextStyle(
            fontSize: widget.header ? 11 : 13,
            letterSpacing: widget.header ? 0.44 : 0,
            color:
                widget.header ? Nocturne.neutral400 : Nocturne.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          cursorColor: Nocturne.accent,
          textCapitalization: widget.header
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: InputBorder.none,
            hintText: widget.header ? 'COLUMN' : '',
            hintStyle: const TextStyle(
                fontSize: 11, color: Nocturne.neutral700),
          ),
        ),
      );
}


/// Avatars of everyone else currently in this note.
class _PresenceStrip extends StatelessWidget {
  const _PresenceStrip();

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<NotesPresenceService>();
    final s = context.read<V3State>();
    final here = presence.others.where((p) => p.noteId != null).toList();
    if (here.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in here.take(3))
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: PulsingAvatar(
                initial: p.initial,
                color: s.memberById(p.userId)?.color ?? Nocturne.accent600,
                size: 26,
              ),
            ),
        ],
      ),
    );
  }
}

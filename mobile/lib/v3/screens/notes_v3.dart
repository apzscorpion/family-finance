import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/data_export.dart';
import '../data/note_blocks.dart';
import '../data/notes_presence.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_nav.dart';
import '../v3_state.dart';
import '../widgets/v3_motion.dart';
import 'note_editor_v3.dart';
import 'notes_widgets.dart';

/// Family Notes list, per `FamilyNotes.dc.html`: search, Notes/Folders segment,
/// sort cycle, Pinned / All sections in a masonry grid, and the expanding FAB.
class NotesV3 extends StatefulWidget {
  const NotesV3({super.key});

  @override
  State<NotesV3> createState() => _NotesV3State();
}

enum _Sort { edited, created, title }

class _NotesV3State extends State<NotesV3> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.edited;
  int _columns = 2;
  bool _fabOpen = false;
  String _filter = 'all'; // all | shared | private | checklists | tables
  bool _showFolders = false;
  String? _folderId;
  V3Nav? _nav;
  StreamSubscription<NoteRow>? _rowSub;
  StreamSubscription<String>? _delSub;

  @override
  void initState() {
    super.initState();
    // Join the family's notes channel so presence from other devices arrives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<V3State>();
      if (s.familyId.isEmpty) return;
      final presence = context.read<NotesPresenceService>();
      presence.connect(
        familyId: s.familyId,
        selfName: s.me?.name ?? 'Someone',
      );
      _rowSub = presence.remoteNoteRows.listen((row) {
        if (!mounted) return;
        context.read<V3State>().applyRemoteNoteRow(row);
      });
      _delSub = presence.remoteNoteDeletes.listen((id) {
        if (!mounted) return;
        context.read<V3State>().removeRemoteNoteRow(id);
      });
    });
  }

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
    if (nav != null && nav.page != V3Page.notes) return false;
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      return true;
    }
    if (_folderId != null) {
      setState(() => _folderId = null);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _rowSub?.cancel();
    _delSub?.cancel();
    _nav?.unregisterBackHandler(_handleBack);
    _search.dispose();
    super.dispose();
  }

  String get _sortLabel => switch (_sort) {
        _Sort.edited => 'Last edited',
        _Sort.created => 'Newest',
        _Sort.title => 'Title',
      };

  List<NoteRow> _visible(V3State s) {
    final q = _search.text.trim().toLowerCase();
    var list = s.notes.where((n) {
      if (_folderId != null && n.folderId != _folderId) return false;
      if (q.isNotEmpty &&
          !n.title.toLowerCase().contains(q) &&
          !n.content.toLowerCase().contains(q)) {
        return false;
      }
      if (_filter == 'all') return true;
      if (_filter == 'shared') return !n.isPrivate;
      if (_filter == 'private') return n.isPrivate;
      final blocks = _blocksOf(n);
      return switch (_filter) {
        'checklists' =>
          blocks.any((b) => b.kind == NoteBlockKind.todo),
        'tables' => blocks.any((b) => b.kind == NoteBlockKind.table),
        _ => true,
      };
    }).toList();

    list.sort((a, b) => switch (_sort) {
          _Sort.title =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          _ => b.updatedAt.compareTo(a.updatedAt),
        });
    return list;
  }

  static List<NoteBlock> _blocksOf(NoteRow n) => n.blocks;

  /// Uses this State's own context so the `mounted` check actually guards the
  /// context being used after the await.
  Future<void> _create(NoteBlock first) async {
    setState(() => _fabOpen = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorV3(initialBlocks: [first]),
    ));
    if (!mounted) return;
    await context.read<V3State>().refresh();
  }

  Future<void> _followPresence(NotePresence who) async {
    final s = context.read<V3State>();
    final noteId = who.noteId;
    if (noteId == null || noteId == 'new') return;
    NoteRow? target;
    for (final n in s.notes) {
      if (n.id == noteId) {
        target = n;
        break;
      }
    }
    if (target == null) return;
    final found = target;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorV3(
        note: found,
        initialFollowUserId: who.userId,
        initialFocusBlockId: who.blockId,
      ),
    ));
    if (!mounted) return;
    await context.read<V3State>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final notes = _visible(s);
    final pinned = notes.where((n) => n.pinned).toList();
    final rest = notes.where((n) => !n.pinned).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            // Search — `height:44px;border-radius:22px`
            Container(
              height: 44,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Nocturne.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Nocturne.neutral900, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(PhRegular.magnifyingGlass,
                      size: 17, color: Nocturne.neutral500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 14, color: Nocturne.text),
                      cursorColor: Nocturne.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search ${s.notes.length} notes',
                        hintStyle: const TextStyle(
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
            // Notes / Folders segment
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Nocturne.surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        for (final o in const [
                          (false, 'Notes', PhRegular.note),
                          (true, 'Folders', PhFill.pushPin),
                        ])
                          GestureDetector(
                            onTap: () => setState(() {
                              _showFolders = o.$1;
                              if (!o.$1) _folderId = _folderId;
                            }),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              height: 30,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _showFolders == o.$1
                                    ? Nocturne.accent900
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _showFolders == o.$1
                                      ? Nocturne.accent600
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(o.$3,
                                      size: 12,
                                      color: _showFolders == o.$1
                                          ? Nocturne.accent200
                                          : Nocturne.neutral400),
                                  const SizedBox(width: 6),
                                  Text(o.$2,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _showFolders == o.$1
                                            ? Nocturne.accent100
                                            : Nocturne.neutral400,
                                      )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (s.notes.isEmpty) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('You have no notes to export')));
                        return;
                      }
                      final now = DateTime.now();
                      final stamp =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                      final ok = await DataExport.share(
                        DataExport.notesMarkdown(s.notes),
                        'notes-$stamp.md',
                        subject: 'Family Spend Tracker notes',
                      );
                      if (!ok) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Could not export notes')));
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
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
                              size: 13, color: Nocturne.neutral300),
                          SizedBox(width: 4),
                          Text('Export',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Nocturne.neutral300)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            LiveBanner(onTap: _followPresence),
            if (_folderId != null)
              Builder(builder: (_) {
                final matches = s.folders.where((f) => f.id == _folderId);
                if (matches.isEmpty) return const SizedBox.shrink();
                return FolderChip(
                  folder: matches.first,
                  onClear: () => setState(() => _folderId = null),
                );
              }),
            if (_showFolders)
              FolderGrid(
                onOpen: (id) => setState(() {
                  _folderId = id;
                  _showFolders = false;
                }),
              ),
            if (!_showFolders)
            // Filters + sort + layout
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in const [
                            ('all', 'All', PhRegular.note),
                            // Notes are family-visible by default, but there
                            // was no way to tell which from the list.
                            ('shared', 'Shared', PhRegular.users),
                            ('private', 'Private', PhRegular.lockSimple),
                            ('checklists', 'Lists', PhRegular.listChecks),
                            ('tables', 'Tables', PhRegular.chartBar),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _FilterChip(
                                label: f.$2,
                                icon: f.$3,
                                selected: _filter == f.$1,
                                onTap: () => setState(() => _filter = f.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _sort = _Sort
                          .values[(_sort.index + 1) % _Sort.values.length];
                    }),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhRegular.sortAscending,
                              size: 14, color: Nocturne.neutral300),
                          const SizedBox(width: 6),
                          Text(_sortLabel,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Nocturne.neutral300)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _columns = _columns == 2 ? 1 : 2),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                          _columns == 2
                              ? PhRegular.listBullets
                              : PhRegular.chartDonut,
                          size: 18,
                          color: Nocturne.neutral300),
                    ),
                  ),
                ],
              ),
            ),
            if (!_showFolders && notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56, horizontal: 16),
                child: Column(
                  children: [
                    Icon(PhRegular.noteBlank,
                        size: 36, color: Nocturne.neutral600),
                    SizedBox(height: 8),
                    Text('No notes here',
                        style: TextStyle(
                            fontSize: 14, color: Nocturne.neutral300)),
                    SizedBox(height: 4),
                    Text('Tap + to start one',
                        style: TextStyle(
                            fontSize: 12, color: Nocturne.neutral500)),
                  ],
                ),
              ),
            if (!_showFolders && pinned.isNotEmpty) ...[
              const _SectionLabel(icon: PhFill.pushPin, label: 'Pinned'),
              _NoteGrid(notes: pinned, columns: _columns),
            ],
            if (!_showFolders && rest.isNotEmpty) ...[
              if (pinned.isNotEmpty)
                const _SectionLabel(icon: PhRegular.note, label: 'All notes'),
              _NoteGrid(notes: rest, columns: _columns),
            ],
          ],
        ),

        // FAB scrim + menu
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _fabOpen = false),
              child: const ColoredBox(color: Color(0x8C06070E)),
            ),
          ),
        if (_fabOpen)
          Positioned(
            right: 18,
            bottom: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final o in [
                  ('Table', PhRegular.chartBar, NoteBlock.table()),
                  ('Checklist', PhRegular.listChecks, NoteBlock.todo()),
                  ('Heading', PhRegular.textbox, NoteBlock.heading()),
                  ('Note', PhRegular.notePencil, NoteBlock.paragraph()),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: V3Rise(
                      offset: 8,
                      child: GestureDetector(
                      onTap: () => _create(o.$3),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Nocturne.neutral800,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(o.$1,
                                style: const TextStyle(
                                    fontSize: 13, color: Nocturne.text)),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Nocturne.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Nocturne.neutral700, width: 1),
                              boxShadow: Nocturne.shadowMd,
                            ),
                            child: Icon(o.$2,
                                size: 19, color: Nocturne.accent200),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          right: 18,
          bottom: 24,
          child: GestureDetector(
            onTap: () => setState(() => _fabOpen = !_fabOpen),
            behavior: HitTestBehavior.opaque,
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment(-0.34, -1),
                    end: Alignment(0.34, 1),
                    colors: [Nocturne.accent600, Nocturne.accent800],
                  ),
                  border: Border.all(color: Nocturne.accent400, width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Nocturne.mix(Nocturne.accent, 45),
                        blurRadius: 28,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(PhBold.plus,
                    size: 24, color: Nocturne.accent100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? Nocturne.accent900 : Nocturne.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: selected ? Nocturne.accent600 : Nocturne.neutral900,
                width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color:
                      selected ? Nocturne.accent200 : Nocturne.neutral400),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? Nocturne.accent100
                          : Nocturne.neutral300)),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 12, color: Nocturne.neutral500),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.69,
                    color: Nocturne.neutral500)),
          ],
        ),
      );
}

/// The design uses CSS `columns`, which fills top-to-bottom then wraps. This
/// reproduces that by dealing cards into N column lists.
class _NoteGrid extends StatelessWidget {
  final List<NoteRow> notes;
  final int columns;

  const _NoteGrid({required this.notes, required this.columns});

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [for (final n in notes) _NoteCard(note: n)],
        ),
      );
    }

    final cols = List.generate(columns, (_) => <NoteRow>[]);
    for (var i = 0; i < notes.length; i++) {
      cols[i % columns].add(notes[i]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [for (final n in cols[c]) _NoteCard(note: n)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteRow note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final blocks = note.blocks;
    final todo = blocks.where((b) => b.kind == NoteBlockKind.todo).toList();
    final table = blocks.where((b) => b.kind == NoteBlockKind.table).toList();
    final preview = blocks
        .where((b) =>
            b.kind == NoteBlockKind.paragraph ||
            b.kind == NoteBlockKind.heading)
        .map((b) => b.text)
        .where((t) => t.trim().isNotEmpty)
        .join('\n');

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NoteEditorV3(note: note),
        ));
        if (context.mounted) await context.read<V3State>().refresh();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Nocturne.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: note.pinned ? Nocturne.accent800 : Nocturne.neutral900,
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: Nocturne.text),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                      note.isPrivate ? PhRegular.lockSimple : PhRegular.users,
                      size: 14,
                      color: Nocturne.neutral500),
                ),
              ],
            ),
            if (todo.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in todo.first.items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Icon(
                          item.done
                              ? PhFill.checkCircle
                              : PhRegular.circle,
                          size: 15,
                          color: item.done
                              ? NocturneSemantic.income
                              : Nocturne.neutral600),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.done
                                ? Nocturne.neutral600
                                : Nocturne.neutral300,
                            decoration: item.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Nocturne.neutral600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (table.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MiniTable(block: table.first),
            ],
            if (preview.isNotEmpty && todo.isEmpty && table.isEmpty) ...[
              const SizedBox(height: 8),
              Text(preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Nocturne.neutral400)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _meta(s, note),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Nocturne.neutral500),
                  ),
                ),
                if (context.watch<NotesPresenceService>().isLive(note.id)) ...[
                  LiveDot(
                    onTap: () async {
                      final viewers = context
                          .read<NotesPresenceService>()
                          .viewersOf(note.id);
                      final first = viewers.isNotEmpty ? viewers.first : null;
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NoteEditorV3(
                          note: note,
                          initialFollowUserId: first?.userId,
                          initialFocusBlockId: first?.blockId,
                        ),
                      ));
                      if (context.mounted) {
                        await context.read<V3State>().refresh();
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (note.updatedBy != null)
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.memberById(note.updatedBy)?.color ??
                          Nocturne.neutral700,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Nocturne.surface, width: 2),
                    ),
                    child: Text(
                      s.memberById(note.updatedBy)?.initial ?? '?',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.text),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _meta(V3State s, NoteRow n) {
    final who = n.updatedBy == null ? null : s.memberById(n.updatedBy)?.name;
    final when = _ago(n.updatedAt);
    return who == null ? when : 'Edited by $who · $when';
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }
}

class _MiniTable extends StatelessWidget {
  final NoteBlock block;
  const _MiniTable({required this.block});

  @override
  Widget build(BuildContext context) {
    final cols = block.head.length.clamp(1, 3);
    final rows = block.rows.take(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Nocturne.neutral900, width: 1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            for (var r = -1; r < rows.length; r++)
              Container(
                color: r == -1 ? Nocturne.neutral900 : Colors.transparent,
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          child: Text(
                            r == -1
                                ? (block.head.length > c ? block.head[c] : '')
                                : (rows[r].length > c ? rows[r][c] : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: r == -1
                                  ? Nocturne.neutral400
                                  : Nocturne.neutral300,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
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
}

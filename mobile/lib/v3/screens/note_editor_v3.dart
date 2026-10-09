import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/ai/ai_config.dart';
import '../data/ai/ai_structurer.dart';
import '../data/data_export.dart';
import '../data/note_blocks.dart';
import '../data/note_structure.dart';
import '../data/notes_presence.dart';
import '../data/v3_models.dart';
import '../phosphor_icons.dart';
import '../v3_state.dart';
import 'note_ai_chat.dart';
import 'note_markup.dart';
import 'notes_widgets.dart';

/// Clover / Notion-inspired block editor for Family Notes.
///
/// Supports real-time collaborative block-level sync:
/// - Autosave (debounced by payload size: 1.2s <8KB, 3s <30KB, 5s >=30KB)
/// - Conditional concurrency via `save_note_v2` (`notes.version`)
/// - Broadcast `block_delta` (~300ms debounce) + `postgres_changes` fallback
/// - Contested block detection when another member edits the locally focused block
/// - Tappable presence avatars to follow another editor's cursor
/// - Coalesced Undo/Redo (100-entry cap, deep-copied snapshots, rebased on remote edits)
class NoteEditorV3 extends StatefulWidget {
  final NoteRow? note;
  final List<NoteBlock>? initialBlocks;
  final String? initialFollowUserId;
  final String? initialFocusBlockId;

  const NoteEditorV3({
    super.key,
    this.note,
    this.initialBlocks,
    this.initialFollowUserId,
    this.initialFocusBlockId,
  });

  @override
  State<NoteEditorV3> createState() => _NoteEditorV3State();
}

class _NoteEditorV3State extends State<NoteEditorV3>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late List<NoteBlock> _blocks;
  late bool _pinned;
  late bool _private;

  String? _noteId;
  int _localVersion = 0;
  String? _lastUpdatedBy;

  String? _focusedBlock;
  bool _dirty = false;
  bool _saving = false;
  bool _aiBusy = false;
  DateTime? _savedAt;

  AiConfig _aiConfig = const AiConfig();

  /// This note's AI conversation, kept while the editor is open.
  final List<AiTurn> _aiTurns = [];

  /// Linear history for Undo / Redo (cap 100, deep-copied).
  static const int _historyCap = 100;
  final List<List<NoteBlock>> _history = [];
  int _historyAt = -1;
  Timer? _undoCoalesceTimer;
  bool _pendingTextHistory = false;

  /// Autosave & broadcast timers.
  Timer? _autosaveTimer;
  Timer? _deltaBroadcastTimer;
  String? _pendingDeltaBlockId;

  /// Contested blocks: blockId -> name of remote editor contesting it.
  final Map<String, String> _contestedBy = {};
  final Map<String, Timer> _contestedTimers = {};

  /// Follow-user state & block GlobalKeys for scrolling.
  String? _followingUserId;
  final Map<String, GlobalKey> _blockKeys = {};

  NotesPresenceService? _presence;
  StreamSubscription<NoteBlockDelta>? _deltaSub;
  StreamSubscription<NoteRow>? _rowSub;
  DateTime? _lastTyping;

  GlobalKey _keyForBlock(String id) =>
      _blockKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final n = widget.note;
    _noteId = n?.id;
    _localVersion = n?.version ?? 0;
    _lastUpdatedBy = n?.updatedBy;
    _title = TextEditingController(text: n?.title ?? '');
    _blocks = n != null && n.blocks.isNotEmpty
        ? n.blocks.map((b) => b.deepCopy()).toList()
        : (widget.initialBlocks ?? [NoteBlock.paragraph()])
              .map((b) => b.deepCopy())
              .toList();
    _pinned = n?.pinned ?? false;
    _private = n?.isPrivate ?? false;
    _followingUserId = widget.initialFollowUserId;
    if (widget.initialFocusBlockId != null) {
      _focusedBlock = widget.initialFocusBlockId;
    }
    _pushHistoryImmediate();
    _loadAiConfig();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<NotesPresenceService>();
      p.setActiveNote(
        _noteId ?? 'new',
        title: _title.text.isEmpty ? 'a new note' : _title.text,
        blockId: _focusedBlock,
      );
      if (widget.initialFocusBlockId != null) {
        _scrollToBlock(widget.initialFocusBlockId!);
      }
    });
  }

  Future<void> _loadAiConfig() async {
    final cfg = await AiConfigStore.load();
    if (!mounted) return;
    setState(() => _aiConfig = cfg);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPresence = context.read<NotesPresenceService>();
    if (_presence != nextPresence) {
      _presence?.removeListener(_onPresenceChanged);
      _deltaSub?.cancel();
      _rowSub?.cancel();
      _presence = nextPresence;
      _presence!.addListener(_onPresenceChanged);
      _deltaSub = _presence!.blockDeltas.listen(_onRemoteBlockDelta);
      _rowSub = _presence!.remoteNoteRows.listen(_onRemoteNoteRow);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_dirty) {
        _save(pruneEmpty: false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _deltaBroadcastTimer?.cancel();
    _undoCoalesceTimer?.cancel();
    for (final t in _contestedTimers.values) {
      t.cancel();
    }
    _deltaSub?.cancel();
    _rowSub?.cancel();
    _presence?.removeListener(_onPresenceChanged);
    _presence?.setActiveNote(null);
    _title.dispose();
    super.dispose();
  }

  void _onPresenceChanged() {
    if (!mounted) return;
    final p = _presence;
    if (p == null) return;

    // Clear contested indicators if the remote user moved off that block.
    final activeId = _noteId;
    if (activeId != null && _contestedBy.isNotEmpty) {
      final viewers = p.viewersOf(activeId);
      final removed = <String>[];
      _contestedBy.forEach((blockId, _) {
        final stillOnBlock = viewers.any((v) => v.blockId == blockId);
        if (!stillOnBlock) {
          removed.add(blockId);
        }
      });
      if (removed.isNotEmpty) {
        setState(() {
          for (final bId in removed) {
            _contestedBy.remove(bId);
            _contestedTimers.remove(bId)?.cancel();
          }
        });
      }
    }

    // If following someone in this note:
    final followId = _followingUserId;
    if (followId != null && activeId != null) {
      final viewers = p.viewersOf(activeId);
      NotePresence? target;
      for (final v in viewers) {
        if (v.userId == followId) {
          target = v;
          break;
        }
      }
      if (target == null) {
        final s = context.read<V3State>();
        final name = s.memberById(followId)?.name ?? 'Member';
        setState(() => _followingUserId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('$name left this note'),
          ),
        );
      } else if (target.blockId != null) {
        _scrollToBlock(target.blockId!);
      }
    }
  }

  void _scrollToBlock(String blockId) {
    final key = _blockKeys[blockId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    }
  }

  void _focusBlock(String blockId) {
    if (_focusedBlock == blockId) return;
    setState(() => _focusedBlock = blockId);
    _presence?.setFocusedBlock(blockId);
  }

  Duration _autosaveDebounceDuration() {
    final approxBytes = utf8
        .encode(jsonEncode(_blocks.map((b) => b.toJson()).toList()))
        .length;
    if (approxBytes < 8 * 1024) {
      return const Duration(milliseconds: 1200);
    } else if (approxBytes < 30 * 1024) {
      return const Duration(seconds: 3);
    }
    return const Duration(seconds: 5);
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounceDuration(), () {
      if (mounted && _dirty) {
        // Trap #1: Do NOT prune empty blocks on autosave!
        _save(pruneEmpty: false);
      }
    });
  }

  void _scheduleBlockDelta(String blockId) {
    final id = _noteId;
    if (id == null) return;
    _pendingDeltaBlockId = blockId;
    _deltaBroadcastTimer?.cancel();
    _deltaBroadcastTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final targetId = _pendingDeltaBlockId;
      if (targetId == null) return;
      NoteBlock? found;
      for (final b in _blocks) {
        if (b.id == targetId) {
          found = b;
          break;
        }
      }
      _presence?.sendBlockDelta(
        noteId: id,
        blockId: targetId,
        block: found,
        deleted: found == null,
        title: _title.text.trim(),
      );
    });
  }

  void _typed({String? blockId}) {
    _dirty = true;
    final id = _noteId ?? 'new';
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(milliseconds: 900)) {
      _lastTyping = now;
      _presence?.sendTyping(id, blockId: blockId ?? _focusedBlock);
    }
    if (blockId != null) {
      _scheduleBlockDelta(blockId);
    }
    _scheduleAutosave();
  }

  List<NoteBlock> _deepCopyBlocks(List<NoteBlock> src) =>
      src.map((b) => b.deepCopy()).toList();

  void _pushHistoryImmediate() {
    _undoCoalesceTimer?.cancel();
    _pendingTextHistory = false;
    if (_historyAt < _history.length - 1) {
      _history.removeRange(_historyAt + 1, _history.length);
    }
    _history.add(_deepCopyBlocks(_blocks));
    _historyAt = _history.length - 1;
    if (_history.length > _historyCap) {
      _history.removeAt(0);
      _historyAt--;
    }
  }

  void _scheduleTextHistory({bool wordBoundary = false}) {
    if (wordBoundary) {
      _pushHistoryImmediate();
      return;
    }
    _pendingTextHistory = true;
    _undoCoalesceTimer?.cancel();
    _undoCoalesceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || !_pendingTextHistory) return;
      _pushHistoryImmediate();
      setState(() {});
    });
  }

  /// Immediate structural change (adding/removing/converting/moving blocks,
  /// toggling a checkbox, paste structuring).
  void _mutateStructural(void Function() change, {String? deltaBlockId}) {
    if (_pendingTextHistory) {
      _pushHistoryImmediate();
    }
    setState(() {
      change();
      _typed(blockId: deltaBlockId ?? _focusedBlock);
    });
    _pushHistoryImmediate();
  }

  /// Coalesced text change inside a block (pushes history on word boundary or
  /// after 600ms idle, rather than every keystroke).
  void _mutateText(void Function() change, {String? blockId, String? newText}) {
    final isBoundary =
        newText != null &&
        newText.isNotEmpty &&
        (newText.endsWith(' ') ||
            newText.endsWith('.') ||
            newText.endsWith(',') ||
            newText.endsWith('!') ||
            newText.endsWith('?'));
    setState(() {
      change();
      _typed(blockId: blockId ?? _focusedBlock);
    });
    _scheduleTextHistory(wordBoundary: isBoundary);
  }

  /// Trap #4: Rebase every undo history snapshot when a remote edit updates or
  /// deletes a block, so local Undo never reverts another member's typing.
  void _rebaseHistoryForBlock(String blockId, NoteBlock? remoteBlock) {
    for (var h = 0; h < _history.length; h++) {
      final snap = _history[h];
      final idx = snap.indexWhere((b) => b.id == blockId);
      if (remoteBlock == null) {
        if (idx != -1 && snap.length > 1) {
          snap.removeAt(idx);
        }
      } else {
        if (idx != -1) {
          snap[idx] = remoteBlock.deepCopy();
        } else {
          snap.add(remoteBlock.deepCopy());
        }
      }
    }
  }

  void _markBlockContested(String blockId, String whoName) {
    setState(() {
      _contestedBy[blockId] = whoName;
    });
    _contestedTimers[blockId]?.cancel();
    _contestedTimers[blockId] = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _contestedBy.remove(blockId);
        _contestedTimers.remove(blockId);
      });
    });
  }

  void _onRemoteBlockDelta(NoteBlockDelta delta) {
    if (!mounted) return;
    if (_noteId == null || delta.noteId != _noteId) return;

    // If the delta targets the block we currently have focused, do NOT clobber
    // our active typing; surface the conflict indicator instead.
    if (_focusedBlock != null && delta.blockId == _focusedBlock) {
      _markBlockContested(delta.blockId, delta.fromName);
      return;
    }

    setState(() {
      if (delta.title != null && delta.title!.isNotEmpty && !_dirty) {
        _title.text = delta.title!;
      }
      if (delta.deleted) {
        _blocks.removeWhere((b) => b.id == delta.blockId);
        if (_blocks.isEmpty) {
          _blocks.add(NoteBlock.paragraph());
        }
        _rebaseHistoryForBlock(delta.blockId, null);
      } else if (delta.block != null) {
        final idx = _blocks.indexWhere((b) => b.id == delta.blockId);
        if (idx != -1) {
          _blocks[idx] = delta.block!.deepCopy();
        } else {
          _blocks.add(delta.block!.deepCopy());
        }
        _rebaseHistoryForBlock(delta.blockId, delta.block);
      }
    });
  }

  void _onRemoteNoteRow(NoteRow row) {
    if (!mounted) return;
    if (_noteId == null || row.id != _noteId) return;
    final s = context.read<V3State>();

    // Trap #2: Suppress postgres_changes self-echo!
    if (row.updatedBy == s.myId && row.version <= _localVersion) {
      return;
    }
    if (row.version < _localVersion) {
      return;
    }

    _applyAuthoritativeRemoteRow(row);
  }

  void _applyAuthoritativeRemoteRow(NoteRow row) {
    final s = context.read<V3State>();
    final whoName = s.memberById(row.updatedBy)?.name ?? 'Someone';
    setState(() {
      _localVersion = row.version;
      _lastUpdatedBy = row.updatedBy;
      _pinned = row.pinned;
      _private = row.isPrivate;
      if (!_dirty && row.title != _title.text) {
        _title.text = row.title;
      }

      // Merge every block except the locally focused one if we have unsaved edits.
      final remoteById = {for (final b in row.blocks) b.id: b};
      final nextBlocks = <NoteBlock>[];

      for (final remoteBlock in row.blocks) {
        if (_focusedBlock == remoteBlock.id && _dirty) {
          final localIdx = _blocks.indexWhere((b) => b.id == remoteBlock.id);
          if (localIdx != -1) {
            final localBlock = _blocks[localIdx];
            nextBlocks.add(localBlock);
            if (jsonEncode(localBlock.toJson()) !=
                jsonEncode(remoteBlock.toJson())) {
              _markBlockContested(remoteBlock.id, whoName);
            }
            continue;
          }
        }
        nextBlocks.add(remoteBlock.deepCopy());
        _rebaseHistoryForBlock(remoteBlock.id, remoteBlock);
      }

      // Preserve any newly added local focused block that hasn't been saved yet.
      if (_focusedBlock != null &&
          _dirty &&
          !remoteById.containsKey(_focusedBlock)) {
        final localIdx = _blocks.indexWhere((b) => b.id == _focusedBlock);
        if (localIdx != -1) {
          nextBlocks.add(_blocks[localIdx]);
        }
      }

      if (nextBlocks.isNotEmpty) {
        _blocks = nextBlocks;
      }
    });
  }

  bool get _canUndo => _historyAt > 0 || _pendingTextHistory;
  bool get _canRedo => _historyAt < _history.length - 1;

  void _undo() {
    if (_pendingTextHistory) {
      _pushHistoryImmediate();
    }
    if (_historyAt <= 0) return;
    setState(() {
      _historyAt--;
      _blocks = _deepCopyBlocks(_history[_historyAt]);
      _dirty = true;
    });
    _scheduleAutosave();
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyAt++;
      _blocks = _deepCopyBlocks(_history[_historyAt]);
      _dirty = true;
    });
    _scheduleAutosave();
  }

  /// Saves the note.
  ///
  /// Trap #1: When [pruneEmpty] is false (used by background autosave), empty
  /// blocks are preserved so a block the user just added and paused in is never
  /// deleted under their cursor. Only final flush on close sets `pruneEmpty: true`.
  Future<void> _save({bool pruneEmpty = false}) async {
    if (_saving) return;
    _autosaveTimer?.cancel();
    final s = context.read<V3State>();
    setState(() => _saving = true);

    final blocksToSave = pruneEmpty
        ? _blocks.where((b) => !b.isEmpty).toList()
        : _blocks;
    final payloadBlocks = blocksToSave.isEmpty
        ? [NoteBlock.paragraph()]
        : blocksToSave;

    var res = await s.saveNoteConditional(
      id: _noteId,
      title: _title.text.trim(),
      blocks: payloadBlocks,
      pinned: _pinned,
      isPrivate: _private,
      folderId: widget.note?.folderId,
      expectedVersion: _noteId == null ? null : _localVersion,
    );

    // If conditional update failed due to a concurrent writer (`res.ok == false`),
    // merge the winning server row (preserving our focused block) and retry once.
    if (res != null && !res.ok) {
      _applyAuthoritativeRemoteRow(res.row);
      final mergedBlocks = pruneEmpty
          ? _blocks.where((b) => !b.isEmpty).toList()
          : _blocks;
      res = await s.saveNoteConditional(
        id: _noteId,
        title: _title.text.trim(),
        blocks: mergedBlocks.isEmpty ? [NoteBlock.paragraph()] : mergedBlocks,
        pinned: _pinned,
        isPrivate: _private,
        folderId: widget.note?.folderId,
        expectedVersion: _localVersion,
      );
    }

    if (!mounted) return;
    final savedRow = res != null && res.ok ? res.row : null;
    final ok = savedRow != null;
    setState(() {
      _saving = false;
      if (savedRow != null) {
        final wasNew = _noteId == null;
        _noteId = savedRow.id;
        _localVersion = savedRow.version;
        _lastUpdatedBy = savedRow.updatedBy;
        _dirty = false;
        _savedAt = DateTime.now();
        if (wasNew) {
          _presence?.setActiveNote(
            _noteId,
            title: _title.text.isEmpty ? 'a new note' : _title.text,
            blockId: _focusedBlock,
          );
        }
      } else {
        _dirty = true;
      }
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — check your connection')),
      );
    }
  }

  Future<void> _delete() async {
    final id = _noteId;
    if (id == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Nocturne.surface,
        title: const Text(
          'Delete note?',
          style: TextStyle(fontSize: 17, color: Nocturne.text),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(fontSize: 14, color: Nocturne.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Nocturne.neutral400),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: NocturneSemantic.expense),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<V3State>().deleteNote(id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareNote() async {
    final title = _title.text.trim().isEmpty ? 'Note' : _title.text.trim();
    final md = DataExport.noteMarkdown(
      NoteRow(
        id: _noteId ?? 'temp',
        title: title,
        content: blocksToPlainText(_blocks),
        pinned: _pinned,
        visibility: _private ? 'private' : 'family',
        folderId: widget.note?.folderId,
        updatedAt: DateTime.now(),
        blocks: _blocks,
      ),
    );
    final filename = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')}.md';
    await DataExport.share(md, filename, subject: title);
  }

  /// Counts logical items produced by [blocks] for the paste snackbar.
  static int _countStructuredItems(List<NoteBlock> blocks) {
    var count = 0;
    for (final b in blocks) {
      switch (b.kind) {
        case NoteBlockKind.todo:
          count += b.items.length;
        case NoteBlockKind.table:
          count += b.rows.length;
        case NoteBlockKind.heading:
        case NoteBlockKind.paragraph:
          count += 1;
      }
    }
    return count == 0 ? 1 : count;
  }

  /// Applies structured paste either replacing [targetBlockId] (if empty or
  /// matching) or appending at the end of the note, and offers Undo + AI.
  void _applyStructuredPaste(String rawText, {String? targetBlockId}) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return;

    final parsed = NoteStructure.parse(trimmed);
    final beforeBlocks = _deepCopyBlocks(_blocks);

    _mutateStructural(() {
      if (targetBlockId != null) {
        final idx = _blocks.indexWhere((b) => b.id == targetBlockId);
        if (idx != -1) {
          final current = _blocks[idx];
          if (current.isEmpty || current.text.trim() == trimmed) {
            _blocks.replaceRange(idx, idx + 1, parsed);
          } else {
            _blocks.insertAll(idx + 1, parsed);
          }
          _focusedBlock = parsed.last.id;
          return;
        }
      }
      final keep = _blocks.where((b) => !b.isEmpty).toList();
      _blocks = [...keep, ...parsed];
      _focusedBlock = _blocks.last.id;
    }, deltaBlockId: parsed.last.id);

    if (!mounted) return;
    final itemCount = _countStructuredItems(parsed);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Structured into $itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 13, color: Nocturne.text),
              ),
            ),
            if (_aiConfig.isConfigured)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    _restructureRawWithAi(
                      trimmed,
                      replaceIds: parsed.map((b) => b.id).toSet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Nocturne.accent900,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Nocturne.accent600, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhRegular.sparkle,
                          size: 12,
                          color: Nocturne.accent200,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Restructure with AI',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Nocturne.accent200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Nocturne.accent200,
          onPressed: () {
            _mutateStructural(() {
              // Restore the previous blocks, placing the raw text as a single
              // paragraph so nothing pasted is lost.
              final restored = _deepCopyBlocks(beforeBlocks);
              final rawBlock = NoteBlock.paragraph(trimmed);
              if (targetBlockId != null) {
                final idx = restored.indexWhere((b) => b.id == targetBlockId);
                if (idx != -1) {
                  restored[idx] = rawBlock;
                  _blocks = restored;
                  _focusedBlock = rawBlock.id;
                  return;
                }
              }
              final nonEmpty = restored.where((b) => !b.isEmpty).toList();
              _blocks = [...nonEmpty, rawBlock];
              _focusedBlock = rawBlock.id;
            });
          },
        ),
      ),
    );
  }

  Future<void> _pasteFromToolbar() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      }
      return;
    }
    _applyStructuredPaste(text, targetBlockId: _focusedBlock);
  }

  Future<void> _restructureRawWithAi(
    String rawText, {
    Set<String>? replaceIds,
  }) async {
    if (_aiBusy) return;
    final cfg = await AiConfigStore.load();
    if (!mounted) return;
    setState(() {
      _aiConfig = cfg;
      _aiBusy = true;
    });

    final result = await AiStructurer.structure(rawText, cfg);
    if (!mounted) return;
    setState(() => _aiBusy = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'AI restructure failed')),
      );
      return;
    }

    final aiBlocks = result.blocks!;
    _mutateStructural(() {
      if (replaceIds != null && replaceIds.isNotEmpty) {
        final firstIdx = _blocks.indexWhere((b) => replaceIds.contains(b.id));
        if (firstIdx != -1) {
          _blocks.removeWhere((b) => replaceIds.contains(b.id));
          _blocks.insertAll(firstIdx, aiBlocks);
          _focusedBlock = aiBlocks.last.id;
          return;
        }
      }
      _blocks = aiBlocks;
      _focusedBlock = aiBlocks.last.id;
    }, deltaBlockId: aiBlocks.last.id);

    final count = _countStructuredItems(aiBlocks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI structured into $count ${count == 1 ? 'item' : 'items'}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Nocturne.accent200,
          onPressed: _undo,
        ),
      ),
    );
  }

  Future<void> _restructureNoteOrBlockWithAi() async {
    final cfg = await AiConfigStore.load();
    if (!mounted) return;
    setState(() => _aiConfig = cfg);

    if (!cfg.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure an AI provider in Settings → AI restructuring first',
          ),
        ),
      );
      return;
    }

    // If a non-empty block is focused, restructure that block; otherwise
    // restructure the whole note's plain text.
    NoteBlock? focused;
    if (_focusedBlock != null) {
      for (final b in _blocks) {
        if (b.id == _focusedBlock && !b.isEmpty) {
          focused = b;
          break;
        }
      }
    }

    if (focused != null) {
      await _restructureRawWithAi(focused.plain, replaceIds: {focused.id});
    } else {
      final allText = blocksToPlainText(_blocks).trim();
      if (allText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Write or paste some text first')),
        );
        return;
      }
      await _restructureRawWithAi(
        allText,
        replaceIds: _blocks.map((b) => b.id).toSet(),
      );
    }
  }

  Future<void> _openAiChat() async {
    final cfg = await AiConfigStore.load();
    if (!mounted) return;
    setState(() => _aiConfig = cfg);
    if (!cfg.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add an AI key in Settings → AI restructuring to use AI here',
          ),
        ),
      );
      return;
    }
    final focused = _blocks.indexWhere((b) => b.id == _focusedBlock);
    await showNoteAiChat(
      context,
      turns: _aiTurns,
      focusLabel: focused == -1 || _blocks[focused].isEmpty
          ? null
          : _blocks[focused].plain,
      ask: _askAi,
      onUndo: _undo,
      onRestructure: _restructureNoteOrBlockWithAi,
    );
  }

  /// One chat turn: sends the note and [request], applies the returned note
  /// as a single undo step when it differs.
  Future<AiTurn> _askAi(String request) async {
    final cfg = await AiConfigStore.load();
    final focused = _blocks.indexWhere((b) => b.id == _focusedBlock);
    final res = await AiStructurer.edit(
      blocks: _blocks,
      request: request,
      config: cfg,
      focusedIndex: focused == -1 ? null : focused,
      history: [
        for (final t in _aiTurns.reversed.take(6).toList().reversed)
          if (t.reply != null) (t.request, t.reply!),
      ],
    );
    final turn = AiTurn(request, reply: res.reply, error: res.error);
    final next = res.blocks == null ? null : carryOver(_blocks, res.blocks!);
    if (mounted && next != null && !sameBlocks(_blocks, next)) {
      _mutateStructural(() {
        _blocks = next;
        if (!_blocks.any((b) => b.id == _focusedBlock)) _focusedBlock = null;
      }, deltaBlockId: next.first.id);
      turn.changed = true;
    }
    _aiTurns.add(turn);
    return turn;
  }

  void _add(NoteBlock b, {int? afterIndex}) => _mutateStructural(() {
    if (afterIndex != null && afterIndex >= 0 && afterIndex < _blocks.length) {
      _blocks.insert(afterIndex + 1, b);
    } else {
      // If the last block is an empty paragraph and we're adding a
      // non-paragraph block, replace that trailing empty paragraph.
      if (_blocks.length == 1 &&
          _blocks.first.isEmpty &&
          _blocks.first.kind == NoteBlockKind.paragraph &&
          b.kind != NoteBlockKind.paragraph) {
        _blocks[0] = b;
      } else {
        _blocks.add(b);
      }
    }
    _focusedBlock = b.id;
  }, deltaBlockId: b.id);

  void _replaceBlock(String blockId, NoteBlock next) => _mutateStructural(() {
    final i = _blocks.indexWhere((x) => x.id == blockId);
    if (i != -1) {
      _blocks[i] = next;
      _focusedBlock = next.id;
    }
  }, deltaBlockId: next.id);

  void _moveBlock(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _blocks.length) return;
    _mutateStructural(() {
      final item = _blocks.removeAt(index);
      _blocks.insert(target, item);
      _focusedBlock = item.id;
    });
  }

  void _duplicateBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final b = _blocks[index];
    final copy = NoteBlock(
      id: NoteBlock.paragraph().id,
      kind: b.kind,
      text: b.text,
      items: [for (final i in b.items) i.copyWith()],
      head: [...b.head],
      rows: [
        for (final r in b.rows) [...r],
      ],
    );
    _mutateStructural(() {
      _blocks.insert(index + 1, copy);
      _focusedBlock = copy.id;
    }, deltaBlockId: copy.id);
  }

  void _deleteBlock(String blockId) => _mutateStructural(() {
    _blocks.removeWhere((x) => x.id == blockId);
    if (_blocks.isEmpty) {
      final p = NoteBlock.paragraph();
      _blocks.add(p);
      _focusedBlock = p.id;
    }
  }, deltaBlockId: blockId);

  Future<void> _openBlockMenu(int index) async {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Nocturne.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Nocturne.neutral800,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'BLOCK ACTIONS',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.7,
                  color: Nocturne.neutral500,
                ),
              ),
              const SizedBox(height: 8),
              if (block.kind != NoteBlockKind.todo)
                _MenuTile(
                  icon: PhRegular.listChecks,
                  label: 'Convert to checklist',
                  onTap: () {
                    Navigator.pop(ctx);
                    _replaceBlock(block.id, NoteStructure.toTodo(block));
                  },
                ),
              if (block.kind == NoteBlockKind.todo)
                _MenuTile(
                  icon: PhRegular.chartBar,
                  label: 'Convert to table',
                  onTap: () {
                    Navigator.pop(ctx);
                    _replaceBlock(block.id, NoteStructure.toTable(block));
                  },
                ),
              if (block.kind != NoteBlockKind.paragraph)
                _MenuTile(
                  icon: PhRegular.note,
                  label: 'Convert to paragraph',
                  onTap: () {
                    Navigator.pop(ctx);
                    _replaceBlock(block.id, NoteStructure.toParagraph(block));
                  },
                ),
              if (block.kind == NoteBlockKind.paragraph)
                _MenuTile(
                  icon: PhRegular.textbox,
                  label: 'Convert to heading',
                  onTap: () {
                    Navigator.pop(ctx);
                    _replaceBlock(
                      block.id,
                      NoteBlock.heading(block.text.trim()),
                    );
                  },
                ),
              if (_aiConfig.isConfigured && !block.isEmpty)
                _MenuTile(
                  icon: PhRegular.sparkle,
                  label: 'Restructure block with AI',
                  color: Nocturne.accent200,
                  onTap: () {
                    Navigator.pop(ctx);
                    _restructureRawWithAi(block.plain, replaceIds: {block.id});
                  },
                ),
              const Divider(color: Nocturne.neutral900, height: 16),
              if (index > 0)
                _MenuTile(
                  icon: PhRegular.caretUp,
                  label: 'Move up',
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveBlock(index, -1);
                  },
                ),
              if (index < _blocks.length - 1)
                _MenuTile(
                  icon: PhRegular.caretDown,
                  label: 'Move down',
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveBlock(index, 1);
                  },
                ),
              _MenuTile(
                icon: PhRegular.copy,
                label: 'Duplicate block',
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateBlock(index);
                },
              ),
              _MenuTile(
                icon: PhRegular.trash,
                label: 'Delete block',
                color: NocturneSemantic.expense,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteBlock(block.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V3State>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_dirty) await _save(pruneEmpty: true);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Nocturne.bg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _header(s),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        bottomInset + 100,
                      ),
                      children: [
                        // Clean Clover-style metadata row
                        Row(
                          children: [
                            Text(
                              _dateLine(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Nocturne.neutral500,
                              ),
                            ),
                            const Spacer(),
                            _MetaChip(
                              icon: _private
                                  ? PhRegular.lockSimple
                                  : PhRegular.users,
                              label: _private
                                  ? 'Private'
                                  : (s.family?.name ?? 'Family'),
                              background: _private
                                  ? Nocturne.neutral900
                                  : Nocturne.accent900,
                              color: _private
                                  ? Nocturne.neutral300
                                  : Nocturne.accent200,
                              onTap: () {
                                setState(() {
                                  _private = !_private;
                                  _dirty = true;
                                });
                                _scheduleAutosave();
                              },
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
                              onTap: () {
                                setState(() {
                                  _pinned = !_pinned;
                                  _dirty = true;
                                });
                                _scheduleAutosave();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Large Clover-style title field (~30px, w700)
                        TextField(
                          controller: _title,
                          onChanged: (v) {
                            setState(() => _typed());
                            _presence?.setActiveNote(
                              _noteId ?? 'new',
                              title: v.trim().isEmpty ? 'a new note' : v.trim(),
                              blockId: _focusedBlock,
                            );
                          },
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.6,
                            color: Nocturne.text,
                          ),
                          cursorColor: Nocturne.accent,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'Untitled',
                            hintStyle: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: -0.6,
                              color: Nocturne.neutral700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _syncLine(s),
                        const SizedBox(height: 22),
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          buildDefaultDragHandles: false,
                          proxyDecorator: _liftedProxy,
                          onReorderItem: (from, to) => _moveBlock(
                            from,
                            to - from,
                          ),
                          children: [
                            for (var i = 0; i < _blocks.length; i++)
                              Padding(
                                key: _keyForBlock(_blocks[i].id),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_blocks.length > 1)
                                      _DragHandle(
                                        index: i,
                                        tooltip: 'Drag to move block · tap for block options',
                                        onTap: () => _openBlockMenu(i),
                                      ),
                                    Expanded(
                                      child: _BlockRow(
                                        key: ValueKey(_blocks[i].id),
                                        block: _blocks[i],
                                        focused: _focusedBlock == _blocks[i].id,
                                        contestedBy:
                                            _contestedBy[_blocks[i].id],
                                        aiConfigured: _aiConfig.isConfigured,
                                        onFocus: () =>
                                            _focusBlock(_blocks[i].id),
                                        onOpenMenu: () => _openBlockMenu(i),
                                        onChanged: (next) {
                                          final prev = _blocks[i];
                                          final isStructural =
                                              prev.kind != next.kind ||
                                              prev.items.length !=
                                                  next.items.length ||
                                              prev.head.length !=
                                                  next.head.length ||
                                              prev.rows.length !=
                                                  next.rows.length ||
                                              (prev.kind ==
                                                      NoteBlockKind.todo &&
                                                  (_todoDoneChanged(
                                                        prev.items,
                                                        next.items,
                                                      ) ||
                                                      _linesChanged(
                                                            prev.items,
                                                            next.items,
                                                          ) >
                                                          1));
                                          if (isStructural) {
                                            _mutateStructural(() {
                                              final idx = _blocks.indexWhere(
                                                (x) => x.id == prev.id,
                                              );
                                              if (idx != -1) {
                                                _blocks[idx] = next;
                                              }
                                            }, deltaBlockId: prev.id);
                                          } else {
                                            _mutateText(
                                              () {
                                                final idx = _blocks.indexWhere(
                                                  (x) => x.id == prev.id,
                                                );
                                                if (idx != -1) {
                                                  _blocks[idx] = next;
                                                }
                                              },
                                              blockId: prev.id,
                                              newText: next.plain,
                                            );
                                          }
                                        },
                                        onReplaceBlock: (next) =>
                                            _replaceBlock(_blocks[i].id, next),
                                        onDelete: () =>
                                            _deleteBlock(_blocks[i].id),
                                        onMultilinePaste: (raw) =>
                                            _applyStructuredPaste(
                                              raw,
                                              targetBlockId: _blocks[i].id,
                                            ),
                                        onSlashPaste: _pasteFromToolbar,
                                        onSlashAi:
                                            _restructureNoteOrBlockWithAi,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _add(NoteBlock.paragraph()),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            height: 52,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Tap to keep writing, or type / for blocks…',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Nocturne.neutral600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Keyboard-docked formatting bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: bottomInset > 0 ? bottomInset + 8 : 14,
                  ),
                  child: Center(child: _toolbar()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _linesChanged(List<TodoItem> a, List<TodoItem> b) {
    var n = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i].text != b[i].text) n++;
    }
    return n;
  }

  static bool _todoDoneChanged(List<TodoItem> a, List<TodoItem> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].done != b[i].done) return true;
    }
    return false;
  }

  Widget _header(V3State s) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    child: Row(
      children: [
        GestureDetector(
          onTap: () async {
            if (_dirty) await _save(pruneEmpty: true);
            if (mounted) Navigator.pop(context);
          },
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(PhRegular.arrowLeft, size: 22, color: Nocturne.text),
          ),
        ),
        const Spacer(),
        _PresenceStrip(
          noteId: _noteId,
          followingUserId: _followingUserId,
          onTapPresence: (p) {
            setState(() {
              if (_followingUserId == p.userId) {
                _followingUserId = null;
              } else {
                _followingUserId = p.userId;
              }
            });
            if (p.blockId != null) {
              _scrollToBlock(p.blockId!);
            }
          },
        ),
        _IconBtn(
          icon: PhRegular.arrowCounterClockwise,
          enabled: _canUndo,
          onTap: _undo,
        ),
        _IconBtn(
          icon: PhRegular.arrowsClockwise,
          enabled: _canRedo,
          onTap: _redo,
        ),
        _IconBtn(
          icon: PhRegular.shareNetwork,
          enabled: true,
          onTap: _shareNote,
        ),
        _IconBtn(icon: PhRegular.trash, enabled: true, onTap: _delete),
        GestureDetector(
          onTap: _dirty ? () => _save(pruneEmpty: false) : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _dirty ? Nocturne.accent900 : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Nocturne.accent200,
                    ),
                  )
                : Text(
                    _dirty ? 'Save' : 'Saved',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _dirty ? Nocturne.accent200 : Nocturne.neutral600,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _syncLine(V3State s) {
    final updatedBy = _lastUpdatedBy ?? widget.note?.updatedBy;
    final who = updatedBy == null ? null : s.memberById(updatedBy)?.name;
    final synced = !_dirty && !_saving;
    return Row(
      children: [
        Icon(
          _saving
              ? PhRegular.arrowsClockwise
              : (synced ? PhFill.checkCircle : PhRegular.clock),
          size: 12,
          color: synced ? NocturneSemantic.income : Nocturne.neutral500,
        ),
        const SizedBox(width: 5),
        Text(
          _saving
              ? 'Saving…'
              : (synced
                    ? (_savedAt != null ? 'Saved' : 'All changes saved')
                    : 'Autosaving…'),
          style: TextStyle(
            fontSize: 11.5,
            color: synced ? NocturneSemantic.income : Nocturne.neutral400,
          ),
        ),
        if (who != null) ...[
          const Text(
            '  ·  ',
            style: TextStyle(fontSize: 11.5, color: Nocturne.neutral600),
          ),
          Flexible(
            child: Text(
              'Edited by $who',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Nocturne.neutral500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Nocturne.mix(Nocturne.surface, 95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Nocturne.neutral800, width: 1),
        boxShadow: Nocturne.shadowMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarBtn(
            icon: PhRegular.listChecks,
            tooltip: 'Add checklist',
            onTap: () => _add(NoteBlock.todo()),
          ),
          _ToolbarBtn(
            icon: PhRegular.textbox,
            tooltip: 'Add heading',
            onTap: () => _add(NoteBlock.heading()),
          ),
          _ToolbarBtn(
            icon: PhRegular.table,
            tooltip: 'Add table',
            onTap: () => _add(NoteBlock.table()),
          ),
          _ToolbarBtn(
            icon: PhRegular.note,
            tooltip: 'Add text paragraph',
            onTap: () => _add(NoteBlock.paragraph()),
          ),
          _ToolbarBtn(
            icon: PhRegular.clipboardText,
            tooltip: 'Paste clipboard as a list or table',
            onTap: _pasteFromToolbar,
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: Nocturne.neutral800,
          ),
          Tooltip(
            message: 'Ask AI to edit this note',
            triggerMode: TooltipTriggerMode.longPress,
            child: GestureDetector(
              onTap: _aiBusy ? null : _openAiChat,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _aiConfig.isConfigured
                      ? Nocturne.accent900
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _aiBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Nocturne.accent200,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhRegular.sparkle,
                            size: 16,
                            color: _aiConfig.isConfigured
                                ? Nocturne.accent200
                                : Nocturne.neutral400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _aiConfig.isConfigured
                                  ? Nocturne.accent200
                                  : Nocturne.neutral400,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLine() {
    final d = widget.note?.updatedAt ?? DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    triggerMode: TooltipTriggerMode.longPress,
    child: Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: Nocturne.neutral200),
        ),
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Nocturne.neutral300),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color ?? Nocturne.text),
          ),
        ],
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
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

// ── Clover-style Block Row ──────────────────────────────────────────────────

class _BlockRow extends StatelessWidget {
  final NoteBlock block;
  final bool focused;
  final String? contestedBy;
  final bool aiConfigured;
  final VoidCallback onFocus;
  final VoidCallback onOpenMenu;
  final ValueChanged<NoteBlock> onChanged;
  final ValueChanged<NoteBlock> onReplaceBlock;
  final VoidCallback onDelete;
  final ValueChanged<String> onMultilinePaste;
  final VoidCallback onSlashPaste;
  final VoidCallback onSlashAi;

  const _BlockRow({
    super.key,
    required this.block,
    required this.focused,
    this.contestedBy,
    required this.aiConfigured,
    required this.onFocus,
    required this.onOpenMenu,
    required this.onChanged,
    required this.onReplaceBlock,
    required this.onDelete,
    required this.onMultilinePaste,
    required this.onSlashPaste,
    required this.onSlashAi,
  });

  bool get _showSlashMenu {
    if (block.kind != NoteBlockKind.paragraph) return false;
    final t = block.text;
    if (!t.startsWith('/')) return false;
    return !t.contains('\n') && t.length <= 16;
  }

  @override
  Widget build(BuildContext context) {
    final slashQuery = _showSlashMenu
        ? block.text.substring(1).trim().toLowerCase()
        : '';
    final isContested = contestedBy != null;

    return GestureDetector(
      onLongPress: onOpenMenu,
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: isContested
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : EdgeInsets.zero,
        decoration: isContested
            ? BoxDecoration(
                color: Nocturne.mix(NocturneSemantic.warning, 10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Nocturne.mix(NocturneSemantic.warning, 50),
                  width: 1,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isContested)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      PhRegular.warning,
                      size: 12,
                      color: NocturneSemantic.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$contestedBy is editing this line',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: NocturneSemantic.warning,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: switch (block.kind) {
                    NoteBlockKind.heading => _HeadingBlock(
                      block: block,
                      onFocus: onFocus,
                      onChanged: onChanged,
                      onMultilinePaste: onMultilinePaste,
                    ),
                    NoteBlockKind.paragraph => _ParagraphBlock(
                      block: block,
                      onFocus: onFocus,
                      onChanged: onChanged,
                      onMultilinePaste: onMultilinePaste,
                    ),
                    NoteBlockKind.todo => _TodoBlock(
                      block: block,
                      onFocus: onFocus,
                      onChanged: onChanged,
                    ),
                    NoteBlockKind.table => _TableBlock(
                      block: block,
                      onFocus: onFocus,
                      onChanged: onChanged,
                    ),
                  },
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onOpenMenu,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: focused ? 0.9 : 0.25,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4, bottom: 4),
                      child: Icon(
                        PhRegular.dotsThreeVertical,
                        size: 16,
                        color: Nocturne.neutral400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Slash-command menu when typing `/` at the start of a paragraph
            if (_showSlashMenu)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _SlashCommandMenu(
                  query: slashQuery,
                  aiConfigured: aiConfigured,
                  onSelectBlock: onReplaceBlock,
                  onPaste: () {
                    onChanged(block.copyWith(text: ''));
                    onSlashPaste();
                  },
                  onAi: () {
                    onChanged(block.copyWith(text: ''));
                    onSlashAi();
                  },
                ),
              ),
            // Focused inline quick-conversion & table/todo controls
            if (focused && !_showSlashMenu)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (block.kind == NoteBlockKind.todo)
                      _QuickPill(
                        icon: PhRegular.chartBar,
                        label: 'To table',
                        onTap: () =>
                            onReplaceBlock(NoteStructure.toTable(block)),
                      ),
                    if (block.kind == NoteBlockKind.todo &&
                        block.items.any((i) => i.done))
                      _QuickPill(
                        icon: PhRegular.checks,
                        label: 'Clear done',
                        onTap: () => onChanged(
                          block.copyWith(
                            items: block.items.where((i) => !i.done).toList(),
                          ),
                        ),
                      ),
                    if (block.kind == NoteBlockKind.table) ...[
                      _QuickPill(
                        icon: PhRegular.plus,
                        label: 'Row',
                        onTap: () => onChanged(
                          block.copyWith(
                            rows: [
                              ...block.rows,
                              List.filled(block.head.length, ''),
                            ],
                          ),
                        ),
                      ),
                      _QuickPill(
                        icon: PhRegular.plus,
                        label: 'Column',
                        onTap: () => onChanged(
                          block.copyWith(
                            head: [...block.head, ''],
                            rows: block.rows.map((r) => [...r, '']).toList(),
                          ),
                        ),
                      ),
                      _QuickPill(
                        icon: PhRegular.listChecks,
                        label: 'To checklist',
                        onTap: () =>
                            onReplaceBlock(NoteStructure.toTodo(block)),
                      ),
                    ],
                    if (block.kind == NoteBlockKind.paragraph &&
                        block.text.trim().isNotEmpty)
                      _QuickPill(
                        icon: PhRegular.listChecks,
                        label: 'To checklist',
                        onTap: () =>
                            onReplaceBlock(NoteStructure.toTodo(block)),
                      ),
                    _QuickPill(
                      icon: PhRegular.dotsThree,
                      label: 'More',
                      onTap: onOpenMenu,
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

/// Six-dot grip: drag to reorder within the nearest reorderable list, tap
/// for options. Long-press shows what it does.
class _DragHandle extends StatelessWidget {
  final int index;
  final String tooltip;
  final VoidCallback onTap;

  const _DragHandle({
    required this.index,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 22,
          height: 38,
          child: Icon(
            PhRegular.dotsSixVertical,
            size: 15,
            color: Nocturne.neutral600,
          ),
        ),
      ),
    ),
  );
}

Widget _liftedProxy(Widget child, int index, Animation<double> animation) =>
    Material(
      color: Nocturne.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );

class _QuickPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Nocturne.neutral800, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Nocturne.neutral400),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Nocturne.neutral300),
          ),
        ],
      ),
    ),
  );
}

class _SlashCommandMenu extends StatelessWidget {
  final String query;
  final bool aiConfigured;
  final ValueChanged<NoteBlock> onSelectBlock;
  final VoidCallback onPaste;
  final VoidCallback onAi;

  const _SlashCommandMenu({
    required this.query,
    required this.aiConfigured,
    required this.onSelectBlock,
    required this.onPaste,
    required this.onAi,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        <({IconData icon, String title, String subtitle, VoidCallback onTap})>[
          (
            icon: PhRegular.listChecks,
            title: 'Checklist',
            subtitle: 'Track tasks or shopping items',
            onTap: () => onSelectBlock(NoteBlock.todo()),
          ),
          (
            icon: PhRegular.textbox,
            title: 'Heading',
            subtitle: 'Section heading',
            onTap: () => onSelectBlock(NoteBlock.heading()),
          ),
          (
            icon: PhRegular.chartBar,
            title: 'Table',
            subtitle: 'Rows and columns',
            onTap: () => onSelectBlock(NoteBlock.table()),
          ),
          (
            icon: PhRegular.paperclip,
            title: 'Paste structured',
            subtitle: 'Turn clipboard into checklist or table',
            onTap: onPaste,
          ),
          if (aiConfigured)
            (
              icon: PhRegular.sparkle,
              title: 'Restructure with AI',
              subtitle: 'Organise note with your AI model',
              onTap: onAi,
            ),
        ].where((item) {
          if (query.isEmpty) return true;
          return item.title.toLowerCase().contains(query) ||
              item.subtitle.toLowerCase().contains(query);
        }).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Nocturne.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nocturne.neutral800, width: 1),
        boxShadow: Nocturne.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'INSERT BLOCK',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.7,
                color: Nocturne.neutral500,
              ),
            ),
          ),
          for (final item in items)
            GestureDetector(
              onTap: item.onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Nocturne.neutral900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 15,
                        color: Nocturne.accent200,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Nocturne.text,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Nocturne.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Individual Block Widgets ────────────────────────────────────────────────

class _HeadingBlock extends StatefulWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;
  final ValueChanged<String> onMultilinePaste;

  const _HeadingBlock({
    required this.block,
    required this.onFocus,
    required this.onChanged,
    required this.onMultilinePaste,
  });

  @override
  State<_HeadingBlock> createState() => _HeadingBlockState();
}

class _HeadingBlockState extends State<_HeadingBlock> {
  late final TextEditingController _c = MarkupController(
    text: widget.block.text,
  );

  @override
  void didUpdateWidget(covariant _HeadingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.text != _c.text) {
      _c.text = widget.block.text;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    onTap: widget.onFocus,
    onChanged: (v) {
      if (v.contains('\n')) {
        widget.onMultilinePaste(v);
        return;
      }
      widget.onChanged(widget.block.copyWith(text: v));
    },
    contextMenuBuilder: formatContextMenu,
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: Nocturne.text,
    ),
    cursorColor: Nocturne.accent,
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 4),
      border: InputBorder.none,
      hintText: 'Heading',
      hintStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Nocturne.neutral700,
      ),
    ),
  );
}

class _ParagraphBlock extends StatefulWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;
  final ValueChanged<String> onMultilinePaste;

  const _ParagraphBlock({
    required this.block,
    required this.onFocus,
    required this.onChanged,
    required this.onMultilinePaste,
  });

  @override
  State<_ParagraphBlock> createState() => _ParagraphBlockState();
}

class _ParagraphBlockState extends State<_ParagraphBlock> {
  late final TextEditingController _c = MarkupController(
    text: widget.block.text,
  );
  String _prevText = '';

  @override
  void initState() {
    super.initState();
    _prevText = widget.block.text;
  }

  @override
  void didUpdateWidget(covariant _ParagraphBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.text != _c.text) {
      _c.text = widget.block.text;
      _prevText = widget.block.text;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _handleClipboardPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clip = data?.text;
    if (clip == null || clip.isEmpty) return;

    if (clip.trim().contains('\n')) {
      widget.onMultilinePaste(clip);
      return;
    }

    // Single-line paste: insert at current cursor position normally.
    final sel = _c.selection;
    final text = _c.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, clip);
    _prevText = next;
    _c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + clip.length),
    );
    widget.onChanged(widget.block.copyWith(text: next));
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) {
            _handleClipboardPaste();
            return null;
          },
        ),
      },
      child: TextField(
        controller: _c,
        onTap: widget.onFocus,
        onChanged: (v) {
          // Detect multi-line paste coming from soft keyboard clipboard chips
          // or direct input injection (more than 1 line added in a single step).
          final prevLines = _prevText.split('\n').length;
          final nextLines = v.split('\n').length;
          final addedChars = v.length - _prevText.length;
          if (nextLines - prevLines >= 1 &&
              addedChars > 3 &&
              _prevText.isEmpty) {
            _prevText = v;
            widget.onMultilinePaste(v);
            return;
          }
          _prevText = v;
          widget.onChanged(widget.block.copyWith(text: v));
        },
        contextMenuBuilder: (ctx, editableTextState) {
          final items = editableTextState.contextMenuButtonItems.map((item) {
            if (item.type == ContextMenuButtonType.paste) {
              return item.copyWith(
                onPressed: () {
                  ContextMenuController.removeAny();
                  _handleClipboardPaste();
                },
              );
            }
            return item;
          }).toList();
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: [...formatButtons(editableTextState), ...items],
          );
        },
        maxLines: null,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Nocturne.neutral200,
        ),
        cursorColor: Nocturne.accent,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 3),
          border: InputBorder.none,
          hintText: 'Write something, type / for blocks, or paste a list…',
          hintStyle: TextStyle(fontSize: 15, color: Nocturne.neutral600),
        ),
      ),
    );
  }
}

class _TodoBlock extends StatelessWidget {
  final NoteBlock block;
  final VoidCallback onFocus;
  final ValueChanged<NoteBlock> onChanged;

  const _TodoBlock({
    required this.block,
    required this.onFocus,
    required this.onChanged,
  });

  void _moveItem(int from, int to) {
    if (from == to || to < 0 || to >= block.items.length) return;
    final items = [...block.items];
    items.insert(to, items.removeAt(from));
    onChanged(block.copyWith(items: items));
  }

  Future<void> _openItemMenu(
    BuildContext context,
    int i,
  ) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Nocturne.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      void run(VoidCallback action) {
        Navigator.pop(ctx);
        action();
      }

      final items = block.items;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items[i].text.trim().isEmpty
                    ? 'LINE ${i + 1}'
                    : items[i].text.trim().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.7,
                  color: Nocturne.neutral500,
                ),
              ),
              const SizedBox(height: 8),
              if (i > 0)
                _MenuTile(
                  icon: PhRegular.caretUp,
                  label: 'Move up',
                  onTap: () => run(() => _moveItem(i, i - 1)),
                ),
              if (i < items.length - 1)
                _MenuTile(
                  icon: PhRegular.caretDown,
                  label: 'Move down',
                  onTap: () => run(() => _moveItem(i, i + 1)),
                ),
              _MenuTile(
                icon: PhRegular.plus,
                label: 'Insert line below',
                onTap: () => run(
                  () => onChanged(
                    block.copyWith(
                      items: [...items]
                        ..insert(i + 1, const TodoItem(text: '')),
                    ),
                  ),
                ),
              ),
              _MenuTile(
                icon: PhRegular.textStrikethrough,
                label:
                    items[i].text.startsWith('~~') &&
                        items[i].text.endsWith('~~') &&
                        items[i].text.length > 4
                    ? 'Remove strikethrough'
                    : 'Strike through (without ticking)',
                onTap: () => run(() {
                  final t = items[i].text;
                  final struck =
                      t.startsWith('~~') && t.endsWith('~~') && t.length > 4;
                  final next = [...items];
                  next[i] = next[i].copyWith(
                    text: struck ? t.substring(2, t.length - 2) : '~~$t~~',
                  );
                  onChanged(block.copyWith(items: next));
                }),
              ),
              _MenuTile(
                icon: PhRegular.trash,
                label: 'Delete line',
                color: NocturneSemantic.expense,
                onTap: () => run(() {
                  final next = [...items]..removeAt(i);
                  onChanged(
                    block.copyWith(
                      items: next.isEmpty ? const [TodoItem(text: '')] : next,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final me = context.read<V3State>().myId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          buildDefaultDragHandles: false,
          proxyDecorator: _liftedProxy,
          onReorderItem: _moveItem,
          children: [
            for (var i = 0; i < block.items.length; i++)
              Row(
                key: ValueKey('${block.id}_$i'),
                children: [
                  _DragHandle(
                    index: i,
                    tooltip: 'Drag to move · tap for line options',
                    onTap: () => _openItemMenu(context, i),
                  ),
                  Expanded(
                    child: _TodoRow(
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
                  ),
                ],
              ),
          ],
        ),
        GestureDetector(
          onTap: () => onChanged(
            block.copyWith(
              items: [
                ...block.items,
                const TodoItem(text: ''),
              ],
            ),
          ),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            height: 34,
            child: Row(
              children: [
                SizedBox(width: 22),
                SizedBox(
                  width: 22,
                  child: Icon(
                    PhRegular.plus,
                    size: 14,
                    color: Nocturne.neutral500,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Add item',
                  style: TextStyle(fontSize: 13.5, color: Nocturne.neutral500),
                ),
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
  late final TextEditingController _c = MarkupController(
    text: widget.item.text,
  );

  @override
  void didUpdateWidget(covariant _TodoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.text != _c.text) {
      _c.text = widget.item.text;
    }
  }

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
              duration: const Duration(milliseconds: 180),
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: done ? Nocturne.accent600 : Colors.transparent,
                border: Border.all(
                  color: done ? Nocturne.accent600 : Nocturne.neutral600,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(PhBold.check, size: 12, color: Nocturne.text)
                  : null,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: _c,
              onTap: widget.onFocus,
              onChanged: widget.onText,
              onSubmitted: (_) => widget.onSubmit(),
              contextMenuBuilder: formatContextMenu,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: 15,
                color: done ? Nocturne.neutral500 : Nocturne.text,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: Nocturne.neutral600,
              ),
              cursorColor: Nocturne.accent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'To-do',
                hintStyle: TextStyle(fontSize: 15, color: Nocturne.neutral700),
              ),
            ),
          ),
          if (by != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Nocturne.mix(by.color, 22),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                by.name,
                style: TextStyle(fontSize: 10, color: by.color),
              ),
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

  const _TableBlock({
    required this.block,
    required this.onFocus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cols = block.head.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 68,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Nocturne.neutral800, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                              color: Nocturne.neutral900,
                              width: 1,
                            ),
                          ),
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
  late final TextEditingController _c = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant _Cell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _c.text) {
      _c.text = widget.text;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 124,
    child: TextField(
      controller: _c,
      onTap: widget.onFocus,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontSize: widget.header ? 11.5 : 13.5,
        fontWeight: widget.header ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: widget.header ? 0.3 : 0,
        color: widget.header ? Nocturne.neutral300 : Nocturne.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      cursorColor: Nocturne.accent,
      textCapitalization: widget.header
          ? TextCapitalization.words
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: InputBorder.none,
        hintText: widget.header ? 'Header' : '',
        hintStyle: const TextStyle(fontSize: 11.5, color: Nocturne.neutral700),
      ),
    ),
  );
}

class _PresenceStrip extends StatelessWidget {
  final String? noteId;
  final String? followingUserId;
  final ValueChanged<NotePresence> onTapPresence;

  const _PresenceStrip({
    required this.noteId,
    required this.followingUserId,
    required this.onTapPresence,
  });

  @override
  Widget build(BuildContext context) {
    final id = noteId;
    if (id == null) return const SizedBox.shrink();
    final presence = context.watch<NotesPresenceService>();
    final s = context.read<V3State>();
    final here = presence.viewersOf(id);
    if (here.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in here.take(3))
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: GestureDetector(
                onTap: () => onTapPresence(p),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: followingUserId == p.userId
                        ? Border.all(color: Nocturne.accent, width: 1.5)
                        : null,
                  ),
                  child: PulsingAvatar(
                    initial: p.initial,
                    color: s.memberById(p.userId)?.color ?? Nocturne.accent600,
                    size: 26,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

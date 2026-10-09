import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';
import '../data/note_blocks.dart';
import '../phosphor_icons.dart';

/// One exchange in a note's AI chat.
class AiTurn {
  final String request;
  final String? reply;
  final String? error;

  /// Whether this turn changed the note (so it can offer Undo).
  bool changed = false;

  AiTurn(this.request, {this.reply, this.error});
}

/// The model rebuilds the whole note, so ids and "ticked by" badges would be
/// lost. Keep them wherever the block at the same position has the same kind
/// (and, for checklist lines, the same text): realtime sync and the editor's
/// per-block state then treat untouched blocks as untouched.
List<NoteBlock> carryOver(List<NoteBlock> old, List<NoteBlock> next) => [
  for (var i = 0; i < next.length; i++)
    if (i < old.length && old[i].kind == next[i].kind)
      NoteBlock(
        id: old[i].id,
        kind: next[i].kind,
        text: next[i].text,
        head: next[i].head,
        rows: next[i].rows,
        items: [
          for (var j = 0; j < next[i].items.length; j++)
            j < old[i].items.length &&
                    old[i].items[j].text == next[i].items[j].text &&
                    old[i].items[j].done == next[i].items[j].done
                ? old[i].items[j]
                : next[i].items[j],
        ],
      )
    else
      next[i],
];

bool sameBlocks(List<NoteBlock> a, List<NoteBlock> b) =>
    jsonEncode([for (final x in a) x.toJson()]) ==
    jsonEncode([for (final x in b) x.toJson()]);

/// Opens the chat sheet. [ask] runs one turn and applies it to the note.
Future<void> showNoteAiChat(
  BuildContext context, {
  required List<AiTurn> turns,
  required String? focusLabel,
  required Future<AiTurn> Function(String request) ask,
  required VoidCallback onUndo,
  required VoidCallback onRestructure,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Nocturne.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (_) => _NoteAiChat(
    turns: turns,
    focusLabel: focusLabel,
    ask: ask,
    onUndo: onUndo,
    onRestructure: onRestructure,
  ),
);

class _NoteAiChat extends StatefulWidget {
  final List<AiTurn> turns;
  final String? focusLabel;
  final Future<AiTurn> Function(String request) ask;
  final VoidCallback onUndo;
  final VoidCallback onRestructure;

  const _NoteAiChat({
    required this.turns,
    required this.focusLabel,
    required this.ask,
    required this.onUndo,
    required this.onRestructure,
  });

  @override
  State<_NoteAiChat> createState() => _NoteAiChatState();
}

class _NoteAiChatState extends State<_NoteAiChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _pending;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _suggestions => [
    if (widget.focusLabel != null) 'Rephrase this line',
    'Fix spelling and grammar',
    'Turn this into a checklist',
    'Add a short summary at the top',
    'Sort the list alphabetically',
  ];

  Future<void> _send(String text) async {
    final request = text.trim();
    if (request.isEmpty || _pending != null) return;
    _input.clear();
    setState(() => _pending = request);
    _toBottom();
    await widget.ask(request);
    if (!mounted) return;
    setState(() => _pending = null);
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final turns = widget.turns;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  const Icon(
                    PhRegular.sparkle,
                    size: 18,
                    color: Nocturne.accent200,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ask AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Nocturne.text,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRestructure();
                    },
                    child: const Text('Restructure note'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.focusLabel == null
                    ? 'Changes apply to the whole note. Undo anytime.'
                    : 'On: “${widget.focusLabel}”. Say “this line” to mean it.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Nocturne.neutral500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  if (turns.isEmpty && _pending == null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _suggestions)
                          ActionChip(
                            label: Text(s),
                            onPressed: () => _send(s),
                            backgroundColor: Nocturne.bg,
                            side: const BorderSide(color: Nocturne.neutral800),
                            labelStyle: const TextStyle(
                              fontSize: 12.5,
                              color: Nocturne.neutral200,
                            ),
                          ),
                      ],
                    ),
                  for (var i = 0; i < turns.length; i++) ...[
                    _Bubble(text: turns[i].request, mine: true),
                    _Bubble(
                      text: turns[i].error ?? turns[i].reply ?? '',
                      error: turns[i].error != null,
                      // Undo reverts the latest change only, so offer it on
                      // the latest turn only.
                      onUndo: turns[i].changed && i == turns.length - 1
                          ? () {
                              widget.onUndo();
                              setState(() => turns[i].changed = false);
                            }
                          : null,
                    ),
                  ],
                  if (_pending != null) ...[
                    _Bubble(text: _pending!, mine: true),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Nocturne.accent200,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Nocturne.text,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. “add milk after eggs”, “make it shorter”',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Nocturne.neutral600,
                          ),
                          filled: true,
                          fillColor: Nocturne.bg,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      onPressed: _pending == null
                          ? () => _send(_input.text)
                          : null,
                      icon: const Icon(
                        PhRegular.paperPlaneRight,
                        color: Nocturne.accent200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final bool error;
  final VoidCallback? onUndo;

  const _Bubble({
    required this.text,
    this.mine = false,
    this.error = false,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        color: mine
            ? Nocturne.accent900
            : error
            ? Nocturne.mix(NocturneSemantic.expense, 14)
            : Nocturne.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Nocturne.neutral200,
            ),
          ),
          if (onUndo != null)
            GestureDetector(
              onTap: onUndo,
              child: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Undo this change',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.accent200,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

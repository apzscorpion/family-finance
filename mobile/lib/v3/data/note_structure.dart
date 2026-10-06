import 'note_blocks.dart';

/// Turns pasted text into note blocks.
///
/// The guiding rule is that a run of separate lines is a *list of things*, not
/// a paragraph. Pasting
///
/// ```
/// Milk
/// Eggs
/// Bread
/// ```
///
/// gives three checkboxes, because that is almost always what someone pasting
/// it wants. Prose still has to come through as prose, so a run only becomes a
/// list when its lines look like items rather than wrapped sentences — see
/// [_looksLikeItemRun].
///
/// Tables are only inferred from genuinely delimited data (pipes, tabs, CSV).
/// Anything else that *could* be tabular, such as `Day 1: Tokyo`, becomes a
/// checklist, and [NoteStructure.toTable] converts it in one tap. Guessing
/// wrongly towards a table is much more annoying to undo than the reverse.
class NoteStructure {
  NoteStructure._();

  /// Longest a line can be and still count as a list item rather than prose.
  static const _itemMaxLength = 90;

  // ── Line patterns ─────────────────────────────────────────────────────────

  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _checkbox =
      RegExp(r'^\s*(?:[-*+•]\s*)?\[([ xX✓])\]\s*(.*)$');
  static final _bullet = RegExp(r'^\s*[-*+•‣▪·–—]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*\(?(\d{1,3})[.)\]]\s+(.*)$');

  /// `Key: value`, with a key short enough to be a label.
  static final _keyValue = RegExp(r'^\s*([^:\t]{1,48}?)\s*:\s*(\S.*)$');

  /// A Markdown table separator: `|---|:--:|`
  static final _separator = RegExp(r'^\s*\|?[\s:|-]*-[\s:|-]*$');

  /// Trailing sentence punctuation, which suggests prose rather than an item.
  static final _sentenceEnd = RegExp(r'[.!?]["’”)]?$');

  /// Parses [raw] into blocks. Never returns an empty list.
  static List<NoteBlock> parse(String raw) {
    final lines = _normalise(raw);
    final blocks = <NoteBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      final joined = paragraph.join('\n').trim();
      if (joined.isNotEmpty) blocks.add(NoteBlock.paragraph(joined));
      paragraph.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      // 1. Markdown heading.
      final h = _heading.firstMatch(line.trim());
      if (h != null) {
        flushParagraph();
        blocks.add(NoteBlock.heading(h.group(2)!.trim()));
        i++;
        continue;
      }

      // 2. Setext heading: a line underlined by === or ---.
      if (i + 1 < lines.length && _isUnderline(lines[i + 1]) &&
          line.trim().length <= _itemMaxLength) {
        flushParagraph();
        blocks.add(NoteBlock.heading(line.trim()));
        i += 2;
        continue;
      }

      // 3. Delimited table.
      final table = _tryTable(lines, i);
      if (table != null) {
        flushParagraph();
        blocks.add(table.block);
        i = table.next;
        continue;
      }

      // 4. Marked list: checkboxes, bullets or numbers.
      final marked = _tryMarkedList(lines, i);
      if (marked != null) {
        flushParagraph();
        blocks.add(marked.block);
        i = marked.next;
        continue;
      }

      // 5. A run of bare lines that reads as a list rather than a paragraph.
      final bare = _tryBareList(lines, i);
      if (bare != null) {
        flushParagraph();
        blocks.add(bare.block);
        i = bare.next;
        continue;
      }

      paragraph.add(line);
      i++;
    }

    flushParagraph();
    if (blocks.isEmpty) blocks.add(NoteBlock.paragraph());
    return blocks;
  }

  static List<String> _normalise(String raw) => raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      // Zero-width and non-breaking characters routinely ride along with text
      // copied from the web and would defeat every pattern below.
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[​-‍﻿]'), '')
      .split('\n')
      .map((l) => l.trimRight())
      .toList();

  static bool _isUnderline(String line) {
    final t = line.trim();
    if (t.length < 2) return false;
    return RegExp(r'^=+$').hasMatch(t) || RegExp(r'^-{2,}$').hasMatch(t);
  }

  // ── Lists ─────────────────────────────────────────────────────────────────

  /// A consecutive run of checkbox, bullet or numbered lines.
  static ({NoteBlock block, int next})? _tryMarkedList(
      List<String> lines, int start) {
    final items = <TodoItem>[];
    var i = start;

    while (i < lines.length) {
      final line = lines[i];
      final check = _checkbox.firstMatch(line);
      final bullet = _bullet.firstMatch(line);
      final number = _numbered.firstMatch(line);

      if (check != null) {
        final mark = check.group(1)!;
        items.add(TodoItem(
          text: check.group(2)!.trim(),
          done: mark != ' ',
        ));
      } else if (bullet != null) {
        items.add(TodoItem(text: bullet.group(1)!.trim()));
      } else if (number != null) {
        items.add(TodoItem(text: number.group(2)!.trim()));
      } else {
        break;
      }
      i++;
    }

    if (items.isEmpty) return null;
    return (block: NoteBlock.todoItems(items), next: i);
  }

  /// A run of unmarked lines that reads as a list.
  static ({NoteBlock block, int next})? _tryBareList(
      List<String> lines, int start) {
    final run = <String>[];
    var i = start;

    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty) break;
      // A line that any other rule would claim ends the run.
      if (_heading.hasMatch(line.trim()) ||
          _checkbox.hasMatch(line) ||
          _bullet.hasMatch(line) ||
          _numbered.hasMatch(line) ||
          _looksDelimited(line)) {
        break;
      }
      run.add(line.trim());
      i++;
    }

    if (!_looksLikeItemRun(run)) return null;
    return (
      block: NoteBlock.todoItems([for (final t in run) TodoItem(text: t)]),
      next: i,
    );
  }

  /// Whether a run of bare lines should become checkboxes rather than a
  /// paragraph.
  ///
  /// Wrapped prose and a list of items look similar, so this leans on the
  /// things that actually separate them: items are short, there are several of
  /// them, and they do not end in sentence punctuation.
  static bool _looksLikeItemRun(List<String> run) {
    if (run.length < 2) return false;

    for (final line in run) {
      if (line.length > _itemMaxLength) return false;
    }

    // Prose broken across lines still ends most lines mid-sentence, but it is
    // the *last* line that gives it away, along with full stops throughout.
    final sentenceEnders =
        run.where((l) => _sentenceEnd.hasMatch(l)).length;
    if (sentenceEnders > run.length / 2) return false;

    return true;
  }

  // ── Tables ────────────────────────────────────────────────────────────────

  static bool _looksDelimited(String line) {
    if (line.contains('|')) return true;
    if (line.contains('\t')) return true;
    // Commas only count as a delimiter with enough fields that it cannot be
    // ordinary prose punctuation.
    return line.split(',').length >= 3;
  }

  static List<String> _splitRow(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    if (s.contains('|')) return _trimAll(s.split('|'));
    if (s.contains('\t')) return _trimAll(s.split('\t'));
    return _trimAll(s.split(','));
  }

  static List<String> _trimAll(List<String> parts) =>
      [for (final p in parts) p.trim()];

  /// A run of delimited rows sharing a consistent column count.
  static ({NoteBlock block, int next})? _tryTable(
      List<String> lines, int start) {
    if (!_looksDelimited(lines[start])) return null;
    if (start + 1 >= lines.length) return null;

    final next = lines[start + 1];
    final hasSeparator = _separator.hasMatch(next) && next.contains('-');
    if (!hasSeparator && !_looksDelimited(next)) return null;

    final head = _splitRow(lines[start]);
    if (head.length < 2) return null;

    var i = start + 1;
    if (hasSeparator) i++;

    final rows = <List<String>>[];
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        _looksDelimited(lines[i])) {
      rows.add(_splitRow(lines[i]));
      i++;
    }

    if (rows.isEmpty) return null;
    return (block: NoteBlock.tableOf(head, rows), next: i);
  }

  // ── Conversions ───────────────────────────────────────────────────────────

  /// Turns a checklist into a table.
  ///
  /// If the items share a separator — `Day 1: Tokyo`, `Rice - 120` — they are
  /// split into two columns on it. Otherwise everything goes into one column,
  /// which is still a useful starting point for adding more.
  static NoteBlock toTable(NoteBlock block) {
    if (block.kind != NoteBlockKind.todo) return block;

    final texts = [
      for (final item in block.items)
        if (item.text.trim().isNotEmpty) item.text.trim(),
    ];
    if (texts.isEmpty) return NoteBlock.table();

    final splitter = _sharedSplitter(texts);
    if (splitter == null) {
      return NoteBlock.tableOf(['Item'], [for (final t in texts) [t]]);
    }

    final rows = <List<String>>[];
    for (final t in texts) {
      final at = t.indexOf(splitter);
      rows.add([
        t.substring(0, at).trim(),
        t.substring(at + splitter.length).trim(),
      ]);
    }
    return NoteBlock.tableOf(['Item', 'Detail'], rows);
  }

  /// The first separator present in every line, or null when they disagree.
  static String? _sharedSplitter(List<String> texts) {
    for (final candidate in const [': ', ' - ', ' – ', '\t', ' = ']) {
      if (texts.every((t) => t.contains(candidate))) return candidate;
    }
    // A bare colon is worth trying last, since it is the most common and the
    // most likely to appear mid-sentence.
    if (texts.every((t) => _keyValue.hasMatch(t))) return ':';
    return null;
  }

  /// Turns a table back into a checklist, joining each row's cells.
  static NoteBlock toTodo(NoteBlock block) {
    if (block.kind == NoteBlockKind.todo) return block;

    if (block.kind == NoteBlockKind.table) {
      final items = <TodoItem>[];
      for (final row in block.rows) {
        final text =
            row.where((c) => c.trim().isNotEmpty).join(' · ').trim();
        if (text.isNotEmpty) items.add(TodoItem(text: text));
      }
      return NoteBlock.todoItems(items);
    }

    // Heading or paragraph: split on lines.
    final items = [
      for (final line in block.text.split('\n'))
        if (line.trim().isNotEmpty) TodoItem(text: line.trim()),
    ];
    return NoteBlock.todoItems(items);
  }

  /// Flattens any block back to a paragraph.
  static NoteBlock toParagraph(NoteBlock block) =>
      NoteBlock.paragraph(block.plain);
}

/// Kept so existing callers keep working; see [NoteStructure.parse].
List<NoteBlock> parsePastedText(String raw) => NoteStructure.parse(raw);

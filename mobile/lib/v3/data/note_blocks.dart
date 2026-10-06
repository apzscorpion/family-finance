/// Block model for the Family Notes editor.
///
/// Stored in `notes.blocks` as JSON. A flattened plain-text version is mirrored
/// into `notes.content` so previews and search do not have to parse JSON.

library;

enum NoteBlockKind { heading, paragraph, todo, table }

class TodoItem {
  final String text;
  final bool done;

  /// Who ticked it, so the design's "by" badge can be shown.
  final String? byUserId;

  const TodoItem({required this.text, this.done = false, this.byUserId});

  Map<String, dynamic> toJson() => {
        'text': text,
        'done': done,
        if (byUserId != null) 'by': byUserId,
      };

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        text: j['text']?.toString() ?? '',
        done: (j['done'] as bool?) ?? false,
        byUserId: j['by']?.toString(),
      );

  TodoItem copyWith({String? text, bool? done, String? byUserId}) => TodoItem(
        text: text ?? this.text,
        done: done ?? this.done,
        byUserId: byUserId ?? this.byUserId,
      );
}

class NoteBlock {
  final String id;
  final NoteBlockKind kind;

  /// heading / paragraph text.
  final String text;

  /// todo items.
  final List<TodoItem> items;

  /// table header labels.
  final List<String> head;

  /// table body, row-major.
  final List<List<String>> rows;

  const NoteBlock({
    required this.id,
    required this.kind,
    this.text = '',
    this.items = const [],
    this.head = const [],
    this.rows = const [],
  });

  factory NoteBlock.paragraph([String text = '']) => NoteBlock(
        id: _id(),
        kind: NoteBlockKind.paragraph,
        text: text,
      );

  factory NoteBlock.heading([String text = '']) => NoteBlock(
        id: _id(),
        kind: NoteBlockKind.heading,
        text: text,
      );

  factory NoteBlock.todo() => NoteBlock(
        id: _id(),
        kind: NoteBlockKind.todo,
        items: const [TodoItem(text: '')],
      );

  factory NoteBlock.table() => NoteBlock(
        id: _id(),
        kind: NoteBlockKind.table,
        head: const ['Item', 'Amount'],
        rows: const [
          ['', ''],
          ['', ''],
        ],
      );

  static int _seq = 0;
  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        if (kind == NoteBlockKind.heading || kind == NoteBlockKind.paragraph)
          'text': text,
        if (kind == NoteBlockKind.todo)
          'items': items.map((i) => i.toJson()).toList(),
        if (kind == NoteBlockKind.table) ...{
          'head': head,
          'rows': rows,
        },
      };

  factory NoteBlock.fromJson(Map<String, dynamic> j) {
    final kind = NoteBlockKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => NoteBlockKind.paragraph,
    );
    return NoteBlock(
      id: j['id']?.toString() ?? _id(),
      kind: kind,
      text: j['text']?.toString() ?? '',
      items: (j['items'] as List?)
              ?.whereType<Map>()
              .map((e) => TodoItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      head: (j['head'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      rows: (j['rows'] as List?)
              ?.whereType<List>()
              .map((r) => r.map((c) => c.toString()).toList())
              .toList() ??
          const [],
    );
  }

  NoteBlock copyWith({
    String? text,
    List<TodoItem>? items,
    List<String>? head,
    List<List<String>>? rows,
  }) =>
      NoteBlock(
        id: id,
        kind: kind,
        text: text ?? this.text,
        items: items ?? this.items,
        head: head ?? this.head,
        rows: rows ?? this.rows,
      );

  /// Plain text for previews and search.
  String get plain => switch (kind) {
        NoteBlockKind.heading => text,
        NoteBlockKind.paragraph => text,
        NoteBlockKind.todo => items.map((i) => i.text).join(', '),
        NoteBlockKind.table =>
          [head.join(' | '), ...rows.map((r) => r.join(' | '))].join('\n'),
      };

  bool get isEmpty => switch (kind) {
        NoteBlockKind.heading => text.trim().isEmpty,
        NoteBlockKind.paragraph => text.trim().isEmpty,
        NoteBlockKind.todo => items.every((i) => i.text.trim().isEmpty),
        NoteBlockKind.table =>
          head.every((h) => h.trim().isEmpty) &&
              rows.every((r) => r.every((c) => c.trim().isEmpty)),
      };
}

/// Parses pasted text into blocks, detecting Markdown headings, checklists,
/// bullet lists and pipe/tab/comma tables — the design's "format is detected
/// for you".
List<NoteBlock> parsePastedText(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final blocks = <NoteBlock>[];

  var i = 0;
  final para = <String>[];

  void flushParagraph() {
    final joined = para.join('\n').trim();
    if (joined.isNotEmpty) blocks.add(NoteBlock.paragraph(joined));
    para.clear();
  }

  bool looksLikeTableRow(String l) =>
      l.contains('|') || l.contains('\t') || l.split(',').length >= 3;

  List<String> splitRow(String l) {
    var s = l.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    if (s.contains('|')) return s.split('|').map((c) => c.trim()).toList();
    if (s.contains('\t')) return s.split('\t').map((c) => c.trim()).toList();
    return s.split(',').map((c) => c.trim()).toList();
  }

  /// A Markdown separator row: |---|:--:|
  bool isSeparator(String l) =>
      RegExp(r'^\s*\|?[\s:-]+\|[\s:|-]*$').hasMatch(l) && l.contains('-');

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    // Heading: # Title
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (h != null) {
      flushParagraph();
      blocks.add(NoteBlock.heading(h.group(2)!.trim()));
      i++;
      continue;
    }

    // Checklist / bullet list run
    final checkRe = RegExp(r'^\s*(?:[-*]\s*)?\[( |x|X)\]\s*(.*)$');
    final bulletRe = RegExp(r'^\s*[-*•]\s+(.*)$');
    if (checkRe.hasMatch(line) || bulletRe.hasMatch(line)) {
      flushParagraph();
      final items = <TodoItem>[];
      while (i < lines.length) {
        final l = lines[i];
        final c = checkRe.firstMatch(l);
        final b = bulletRe.firstMatch(l);
        if (c != null) {
          items.add(TodoItem(
              text: c.group(2)!.trim(),
              done: c.group(1)!.toLowerCase() == 'x'));
        } else if (b != null) {
          items.add(TodoItem(text: b.group(1)!.trim()));
        } else {
          break;
        }
        i++;
      }
      blocks.add(NoteBlock(
          id: NoteBlock._id(), kind: NoteBlockKind.todo, items: items));
      continue;
    }

    // Table run
    if (looksLikeTableRow(line) && i + 1 < lines.length) {
      final next = lines[i + 1];
      if (looksLikeTableRow(next) || isSeparator(next)) {
        flushParagraph();
        final head = splitRow(line);
        i++;
        if (i < lines.length && isSeparator(lines[i])) i++;
        final rows = <List<String>>[];
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            looksLikeTableRow(lines[i])) {
          final cells = splitRow(lines[i]);
          // Pad or trim so every row matches the header width.
          while (cells.length < head.length) {
            cells.add('');
          }
          rows.add(cells.take(head.length).toList());
          i++;
        }
        blocks.add(NoteBlock(
          id: NoteBlock._id(),
          kind: NoteBlockKind.table,
          head: head,
          rows: rows.isEmpty ? [List.filled(head.length, '')] : rows,
        ));
        continue;
      }
    }

    para.add(line);
    i++;
  }

  flushParagraph();
  if (blocks.isEmpty) blocks.add(NoteBlock.paragraph());
  return blocks;
}

/// Flattens blocks for the `content` mirror.
String blocksToPlainText(List<NoteBlock> blocks) =>
    blocks.map((b) => b.plain).where((t) => t.trim().isNotEmpty).join('\n');

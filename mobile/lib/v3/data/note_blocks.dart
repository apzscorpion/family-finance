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

  /// A todo block from already-built items. Used by the paste structurer.
  factory NoteBlock.todoItems(List<TodoItem> items) => NoteBlock(
        id: _id(),
        kind: NoteBlockKind.todo,
        items: items.isEmpty ? const [TodoItem(text: '')] : items,
      );

  /// A table from a header row and body rows, padded to a uniform width.
  factory NoteBlock.tableOf(List<String> head, List<List<String>> rows) {
    final width = head.isEmpty ? 1 : head.length;
    return NoteBlock(
      id: _id(),
      kind: NoteBlockKind.table,
      head: head.isEmpty ? const ['Column 1'] : head,
      rows: rows.isEmpty
          ? [List.filled(width, '')]
          : [
              for (final r in rows)
                [
                  ...r.take(width),
                  ...List.filled((width - r.length).clamp(0, width), ''),
                ],
            ],
    );
  }

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

  /// Creates an independent deep copy of this block (including mutable lists
  /// `items`, `head`, and `rows`) so undo history snapshots never alias state.
  NoteBlock deepCopy() => NoteBlock(
        id: id,
        kind: kind,
        text: text,
        items: [for (final item in items) item.copyWith()],
        head: [...head],
        rows: [
          for (final r in rows) [...r]
        ],
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

/// Flattens blocks for the `content` mirror.
String blocksToPlainText(List<NoteBlock> blocks) =>
    blocks.map((b) => b.plain).where((t) => t.trim().isNotEmpty).join('\n');

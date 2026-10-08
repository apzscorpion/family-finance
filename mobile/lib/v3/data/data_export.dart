import 'data_export_io.dart'
    if (dart.library.js_interop) 'data_export_web.dart' as platform_export;
import 'note_blocks.dart';
import 'v3_models.dart';

/// Writing transactions and notes out to files the user can keep.
///
/// Everything goes to the app's own cache directory and is handed to the
/// system share sheet (or downloaded on web), so no storage permission is
/// involved — and nothing is left sitting in shared storage afterwards.
class DataExport {
  DataExport._();

  /// Transactions as CSV, in the shape the importer reads back.
  ///
  /// Round-tripping matters: an export that cannot be re-imported is a dead
  /// end if someone moves accounts.
  static String transactionsCsv(
    List<TxnRow> txns, {
    String Function(String userId)? nameOf,
  }) {
    final buf = StringBuffer()
      ..writeln('Date,Title,Amount,Type,Category,Method,Paid by,Note');

    for (final t in txns) {
      final date = t.occurredAt;
      buf.writeln([
        '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        _escape(t.title),
        t.amount.toStringAsFixed(2),
        t.type,
        _escape(t.categoryKey),
        _escape(t.method),
        _escape(t.paidBy == null ? '' : (nameOf?.call(t.paidBy!) ?? '')),
        _escape(t.note ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  /// One note as Markdown, preserving the block structure.
  static String noteMarkdown(NoteRow note) {
    final buf = StringBuffer();
    if (note.title.trim().isNotEmpty) {
      buf
        ..writeln('# ${note.title.trim()}')
        ..writeln();
    }

    for (final b in note.blocks) {
      switch (b.kind) {
        case NoteBlockKind.heading:
          buf
            ..writeln('## ${b.text}')
            ..writeln();
        case NoteBlockKind.todo:
          for (final item in b.items) {
            buf.writeln('- [${item.done ? 'x' : ' '}] ${item.text}');
          }
          buf.writeln();
        case NoteBlockKind.table:
          _writeTable(buf, b);
        case NoteBlockKind.paragraph:
          if (b.text.trim().isNotEmpty) {
            buf
              ..writeln(b.text)
              ..writeln();
          }
      }
    }
    return buf.toString().trimRight();
  }

  /// Every note in one document, each under its own heading.
  static String notesMarkdown(List<NoteRow> notes) {
    final parts = <String>[];
    for (final n in notes) {
      final body = noteMarkdown(n);
      if (body.trim().isEmpty) continue;
      parts.add(body);
    }
    return parts.join('\n\n---\n\n');
  }

  static void _writeTable(StringBuffer buf, NoteBlock b) {
    if (b.head.isEmpty && b.rows.isEmpty) return;

    // A table with no header still exports; the first row becomes the header
    // so the Markdown stays valid and re-imports cleanly.
    final head = b.head.isNotEmpty
        ? b.head
        : (b.rows.isNotEmpty ? b.rows.first : const <String>[]);
    final body = b.head.isNotEmpty ? b.rows : b.rows.skip(1).toList();
    if (head.isEmpty) return;

    final width = [head.length, ...body.map((r) => r.length)]
        .reduce((a, c) => a > c ? a : c);

    String line(List<String> cells) {
      final padded = [...cells, ...List.filled(width - cells.length, '')];
      return '| ${padded.map((c) => c.replaceAll('|', r'\|')).join(' | ')} |';
    }

    buf.writeln(line(head));
    buf.writeln('|${List.filled(width, '---').join('|')}|');
    for (final r in body) {
      buf.writeln(line(r));
    }
    buf.writeln();
  }

  /// Writes [content] to a temporary file (or browser download on web) and
  /// opens the share sheet.
  ///
  /// Returns false if the file could not be written or shared; the caller
  /// reports that rather than leaving the user guessing.
  static Future<bool> share(
    String content,
    String fileName, {
    String? subject,
  }) =>
      platform_export.shareExportedContent(
        content,
        fileName,
        subject: subject,
      );

  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

import 'package:flutter/services.dart';

class ImportedDocumentResult {
  final String kind; // 'csv', 'pdf', 'md', 'txt'
  final String fileName;
  final String rawText;
  final String formattedContent;
  final int pageCount;
  final List<Uint8List> pdfPagesPng;

  const ImportedDocumentResult({
    required this.kind,
    required this.fileName,
    required this.rawText,
    required this.formattedContent,
    this.pageCount = 1,
    this.pdfPagesPng = const [],
  });

  String get text => rawText.isNotEmpty ? rawText : formattedContent;
}

class ParsedNoteTable {
  final List<String> headers;
  final List<List<String>> rows;
  final Map<int, double> numericColumnTotals;

  const ParsedNoteTable({
    required this.headers,
    required this.rows,
    this.numericColumnTotals = const {},
  });
}

class NoteImportService {
  static const MethodChannel _channel = MethodChannel('com.familyfinance/file_import');

  /// Alias used by CardsScreen for importing statement documents
  static Future<ImportedDocumentResult?> pickNativeDocument({String type = 'any'}) {
    return pickDocument(type: type);
  }

  /// Opens Android native document picker (`ACTION_OPEN_DOCUMENT`) for CSV, PDF, Markdown, or text.
  static Future<ImportedDocumentResult?> pickDocument({String type = 'any'}) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('pickDocument', {'type': type});
      if (raw == null || raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final kind = (map['kind'] ?? 'txt').toString();
      final fileName = (map['fileName'] ?? 'document').toString();
      final text = (map['text'] ?? '').toString();
      final pageCount = (map['pageCount'] as num?)?.toInt() ?? 1;

      final List<Uint8List> pagesPng = [];
      if (map['pagesPng'] is List) {
        for (final item in (map['pagesPng'] as List)) {
          if (item is Uint8List) {
            pagesPng.add(item);
          } else if (item is List<int>) {
            pagesPng.add(Uint8List.fromList(item));
          }
        }
      }

      String formatted;
      if (kind == 'csv') {
        formatted = formatCsvToNoteContent(text, fileName: fileName);
      } else if (kind == 'pdf') {
        formatted = formatPdfToNoteContent(text, fileName: fileName, pageCount: pageCount);
      } else {
        formatted = formatSmartPasteOrMarkdown(text);
      }

      return ImportedDocumentResult(
        kind: kind,
        fileName: fileName,
        rawText: text,
        formattedContent: formatted,
        pageCount: pageCount,
        pdfPagesPng: pagesPng,
      );
    } catch (_) {
      return null;
    }
  }

  /// Consumes text shared from ChatGPT, Gemini, or another app via Android's `ACTION_SEND` intent.
  static Future<String?> consumeSharedText() async {
    try {
      final res = await _channel.invokeMethod<String>('consumeSharedText');
      if (res != null && res.trim().isNotEmpty) {
        return formatSmartPasteOrMarkdown(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Shares text externally via Android's native Share Sheet (WhatsApp, SMS, Email, Telegram, etc.).
  static Future<void> shareExternally({required String text, String title = 'Share'}) async {
    try {
      await _channel.invokeMethod('shareText', {
        'text': text,
        'title': title,
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Converts raw CSV text into a Markdown table + interactive checklist items with auto `₹` formatting.
  static String formatCsvToNoteContent(String csvText, {String fileName = 'data.csv'}) {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '▸ Imported CSV: $fileName';

    final parsedRows = lines.map(_parseCsvLine).where((r) => r.isNotEmpty).toList();
    if (parsedRows.isEmpty) return csvText;

    final headers = parsedRows.first;
    final dataRows = parsedRows.skip(1).toList();

    // Detect money columns by header keywords
    final moneyCols = <int>{};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      if (h.contains('amount') ||
          h.contains('price') ||
          h.contains('cost') ||
          h.contains('total') ||
          h.contains('rs') ||
          h.contains('inr') ||
          h.contains('₹') ||
          h.contains('spend') ||
          h.contains('balance')) {
        moneyCols.add(i);
      }
    }

    final sb = StringBuffer();
    sb.writeln('▸ CSV Table: $fileName');
    sb.writeln('| ${headers.join(' | ')} |');
    sb.writeln('| ${List.filled(headers.length, '---').join(' | ')} |');

    final checklistItems = <String>[];
    for (final row in dataRows) {
      final cells = List<String>.generate(headers.length, (i) {
        final val = i < row.length ? row[i].trim() : '';
        if (val.isEmpty) return '-';
        final numVal = double.tryParse(val.replaceAll(',', '').replaceAll('₹', '').trim());
        if (numVal != null && (moneyCols.contains(i) || (i > 0 && headers.length <= 4))) {
          return '₹${numVal.toStringAsFixed(numVal == numVal.roundToDouble() ? 0 : 2)}';
        }
        return val;
      });
      sb.writeln('| ${cells.join(' | ')} |');

      if (cells.isNotEmpty) {
        final label = cells.first;
        final amountCell = cells.skip(1).firstWhere((c) => c.contains('₹'), orElse: () => '');
        if (label.isNotEmpty && label != '-') {
          checklistItems.add('☐ $label${amountCell.isNotEmpty ? ' — $amountCell' : ''}');
        }
      }
    }

    if (checklistItems.isNotEmpty) {
      sb.writeln('\n▸ Interactive Checklist Items');
      for (final item in checklistItems.take(25)) {
        sb.writeln(item);
      }
    }

    return sb.toString().trim();
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if ((ch == ',' || ch == ';') && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  /// Formats extracted PDF text into structured note sections + checklists.
  static String formatPdfToNoteContent(String extractedText, {String fileName = 'document.pdf', int pageCount = 1}) {
    final sb = StringBuffer();
    sb.writeln('▸ PDF Document: $fileName ($pageCount ${pageCount == 1 ? 'page' : 'pages'})');
    if (extractedText.trim().isEmpty) {
      sb.writeln('• Visual PDF pages attached above (use pinch-to-zoom & page arrows).');
      sb.writeln('☐ Add your notes or action items from this PDF below');
      return sb.toString().trim();
    }
    sb.writeln(formatSmartPasteOrMarkdown(extractedText));
    return sb.toString().trim();
  }

  /// Formats text copied/shared from ChatGPT, Gemini, Markdown (.md), or TSV/CSV into clean Samsung Notes blocks,
  /// interactive checkboxes (`☐` / `☑`), and normalized Markdown pipe tables (`| Col 1 | Col 2 |`).
  static String formatSmartPasteOrMarkdown(String raw) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final out = <String>[];

    // If the entire block looks like comma-separated CSV (and no pipe tables yet)
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    if (nonEmpty.length >= 2 &&
        !raw.contains('|') &&
        nonEmpty.take(3).every((l) => l.split(',').length >= 3)) {
      return formatCsvToNoteContent(raw, fileName: 'Pasted Data');
    }

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        out.add('');
        continue;
      }

      // Skip markdown code fences
      if (trimmed.startsWith('```')) continue;

      // Convert TSV (tab-separated) lines into pipe table rows
      if (trimmed.contains('\t') && !trimmed.startsWith('|')) {
        final cells = trimmed.split('\t').map((c) => c.trim()).toList();
        out.add('| ${cells.join(' | ')} |');
        continue;
      }

      // Normalize Markdown headings (#, ##, ###) to Samsung Notes section headers `▸ `
      final headingMatch = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final headingText = headingMatch.group(1)!.replaceAll('**', '').trim();
        out.add('▸ $headingText');
        continue;
      }

      // Normalize Markdown task lists (- [ ], * [ ], - [x], * [X]) to interactive `☐ ` / `☑ `
      final uncheckedMatch = RegExp(r'^[-*•]?\s*\[\s*\]\s+(.*)$').firstMatch(trimmed);
      if (uncheckedMatch != null) {
        out.add('☐ ${_stripInlineMarkdown(uncheckedMatch.group(1)!)}');
        continue;
      }
      final checkedMatch = RegExp(r'^[-*•]?\s*\[[xX✓✔]\]\s+(.*)$').firstMatch(trimmed);
      if (checkedMatch != null) {
        out.add('☑ ${_stripInlineMarkdown(checkedMatch.group(1)!)}');
        continue;
      }

      // Normalize Markdown bullets (- item, * item) to `• `
      final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null && !trimmed.startsWith('---')) {
        out.add('• ${_stripInlineMarkdown(bulletMatch.group(1)!)}');
        continue;
      }

      // Keep Markdown pipe table rows clean
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cleanRow = trimmed
            .split('|')
            .map((c) => _stripInlineMarkdown(c.trim()))
            .join(' | ');
        out.add(cleanRow.startsWith('|') ? cleanRow : '| $cleanRow |');
        continue;
      }

      out.add(_stripInlineMarkdown(trimmed));
    }

    return out.join('\n').trim();
  }

  static String _stripInlineMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1');
  }

  /// Extracts all Markdown pipe tables (`| A | B |`) from a note's content so the editor can render interactive visual DataTables.
  static List<ParsedNoteTable> extractTablesFromContent(String content) {
    final lines = content.split('\n');
    final tables = <ParsedNoteTable>[];

    List<String> currentBlock = [];
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('|') && t.endsWith('|') && t.length > 2) {
        currentBlock.add(t);
      } else {
        if (currentBlock.length >= 2) {
          final parsed = _buildTableFromPipeLines(currentBlock);
          if (parsed != null) tables.add(parsed);
        }
        currentBlock = [];
      }
    }
    if (currentBlock.length >= 2) {
      final parsed = _buildTableFromPipeLines(currentBlock);
      if (parsed != null) tables.add(parsed);
    }

    return tables;
  }

  static ParsedNoteTable? _buildTableFromPipeLines(List<String> pipeLines) {
    final parsedRows = <List<String>>[];
    for (final line in pipeLines) {
      final rawCells = line
          .substring(1, line.length - 1)
          .split('|')
          .map((c) => c.trim())
          .toList();
      if (rawCells.isEmpty) continue;
      // Skip separator row like | --- | --- |
      final isSeparator = rawCells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
      if (isSeparator) continue;
      parsedRows.add(rawCells);
    }
    if (parsedRows.isEmpty) return null;

    final headers = parsedRows.first;
    final rows = parsedRows.skip(1).toList();
    final totals = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double colSum = 0;
      int numericCount = 0;
      for (final r in rows) {
        if (col >= r.length) continue;
        final cell = r[col].replaceAll(',', '').replaceAll('₹', '').replaceAll('Rs.', '').replaceAll('Rs', '').trim();
        final val = double.tryParse(cell);
        if (val != null) {
          colSum += val;
          numericCount++;
        }
      }
      if (numericCount > 0 && col > 0) {
        totals[col] = colSum;
      }
    }

    return ParsedNoteTable(
      headers: headers,
      rows: rows,
      numericColumnTotals: totals,
    );
  }
}


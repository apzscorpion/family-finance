import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../services/app_log.dart';
import 'expense_import.dart';

/// Reading spreadsheets for the expense importer.
///
/// The sheet is flattened to CSV and handed to [ExpenseImport], so a .xlsx
/// file goes through exactly the same column matching, amount cleaning and
/// date handling as a .csv — and is covered by the same tests.
class ExpenseImportXlsx {
  ExpenseImportXlsx._();

  /// Parses the first sheet that yields any rows.
  ///
  /// Workbooks often lead with a cover or summary sheet, so an empty or
  /// unreadable sheet moves on to the next rather than ending the import.
  static List<ImportedExpense> parse(Uint8List bytes) {
    final csv = toCsv(bytes);
    if (csv == null) return const [];
    return ExpenseImport.parseCsv(csv);
  }

  /// Flattens the most promising sheet to CSV text. Exposed so the preview can
  /// show what was read.
  static String? toCsv(Uint8List bytes) {
    try {
      final book = Excel.decodeBytes(bytes);
      String? best;
      var bestRows = 0;

      for (final name in book.tables.keys) {
        final sheet = book.tables[name];
        if (sheet == null) continue;

        final lines = <String>[];
        for (final row in sheet.rows) {
          final cells = row.map(_cellText).toList();
          if (cells.every((c) => c.trim().isEmpty)) continue;
          lines.add(cells.map(_escape).join(','));
        }

        if (lines.length > bestRows) {
          bestRows = lines.length;
          best = lines.join('\n');
        }
      }
      return best;
    } catch (err, stack) {
      AppLog.error('ExpenseImportXlsx.toCsv', err, stack);
      return null;
    }
  }

  /// Dates and numbers arrive as typed cell values, not strings, so they are
  /// rendered in the shapes the CSV parser already understands.
  static String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';

    if (value is TextCellValue) return value.value.text ?? '';
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    if (value is DateCellValue) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is DateTimeCellValue) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is FormulaCellValue) return '';
    return value.toString();
  }

  /// Quotes a field so a value containing a comma cannot split the row.
  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

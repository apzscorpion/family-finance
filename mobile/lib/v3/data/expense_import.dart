/// Turning a CSV, a Markdown table or a note's text into draft transactions.
///
/// Everything here is deliberately forgiving: these files come from banks,
/// spreadsheets, and notes people typed themselves, so the shapes vary. A row
/// that cannot be read is skipped rather than failing the whole import, and the
/// user confirms the result before anything is saved.
library;

/// One parsed row, before the user has confirmed it.
class ImportedExpense {
  ImportedExpense({
    required this.title,
    required this.amount,
    this.date,
    this.category,
    this.isIncome = false,
    this.selected = true,
  });

  final String title;

  /// Always positive; [isIncome] carries the direction.
  final double amount;

  /// Null when the row had no readable date — the import falls back to today.
  final DateTime? date;

  /// Raw category text from the file, matched against real categories later.
  final String? category;

  final bool isIncome;

  /// Rows start selected; the preview lets the user drop individual ones.
  bool selected;

  ImportedExpense copyWith({bool? selected}) => ImportedExpense(
        title: title,
        amount: amount,
        date: date,
        category: category,
        isIncome: isIncome,
        selected: selected ?? this.selected,
      );

  @override
  String toString() =>
      'ImportedExpense($title, $amount, ${date?.toIso8601String()}, '
      'income=$isIncome)';
}

class ExpenseImport {
  ExpenseImport._();

  // Column header synonyms. Banks and spreadsheets rarely agree on names.
  static const _dateKeys = [
    'date', 'txn date', 'transaction date', 'value date', 'posted',
    'posting date', 'when', 'day',
  ];
  static const _titleKeys = [
    'title', 'description', 'desc', 'details', 'narration', 'particulars',
    'merchant', 'payee', 'name', 'item', 'remarks', 'note', 'transaction',
  ];
  static const _amountKeys = [
    'amount', 'amt', 'value', 'price', 'total', 'sum', 'cost',
  ];
  static const _debitKeys = ['debit', 'withdrawal', 'dr', 'paid out', 'spent'];
  static const _creditKeys = ['credit', 'deposit', 'cr', 'paid in', 'received'];
  static const _categoryKeys = ['category', 'cat', 'tag', 'group', 'head'];
  static const _typeKeys = ['type', 'direction', 'kind', 'dr/cr'];

  /// Parses by file kind, falling back to a best guess from the content.
  static List<ImportedExpense> parse(String text, {String kind = 'txt'}) {
    if (text.trim().isEmpty) return const [];
    switch (kind) {
      case 'csv':
        return parseCsv(text);
      case 'md':
        return parseMarkdown(text);
      default:
        // A note or a plain text file may still hold either shape.
        if (text.contains('|')) {
          final rows = parseMarkdown(text);
          if (rows.isNotEmpty) return rows;
        }
        final csv = parseCsv(text);
        if (csv.isNotEmpty) return csv;
        return parseMarkdown(text);
    }
  }

  // ── CSV ───────────────────────────────────────────────────────────────────

  static List<ImportedExpense> parseCsv(String text) {
    final lines = _contentLines(text);
    if (lines.isEmpty) return const [];

    final delimiter = _detectDelimiter(lines);
    final table = lines.map((l) => _splitCsvLine(l, delimiter)).toList();

    // A header lets columns be identified by name; without one the common
    // date/title/amount ordering is assumed.
    final headerIndex = _findHeaderRow(table);
    if (headerIndex == null) {
      return _parsePositional(table);
    }

    final header = table[headerIndex].map(_norm).toList();
    final dateCol = _matchColumn(header, _dateKeys);
    final titleCol = _matchColumn(header, _titleKeys);
    final amountCol = _matchColumn(header, _amountKeys);
    final debitCol = _matchColumn(header, _debitKeys);
    final creditCol = _matchColumn(header, _creditKeys);
    final categoryCol = _matchColumn(header, _categoryKeys);
    final typeCol = _matchColumn(header, _typeKeys);

    final out = <ImportedExpense>[];
    for (var i = headerIndex + 1; i < table.length; i++) {
      final row = table[i];
      if (row.every((c) => c.trim().isEmpty)) continue;

      double? amount;
      var isIncome = false;

      // Separate debit/credit columns carry the direction themselves.
      if (debitCol != null || creditCol != null) {
        final debit = _amountAt(row, debitCol);
        final credit = _amountAt(row, creditCol);
        if (credit != null && credit != 0) {
          amount = credit;
          isIncome = true;
        } else if (debit != null && debit != 0) {
          amount = debit;
        }
      }

      amount ??= _amountAt(row, amountCol);
      if (amount == null) continue;

      // A single amount column may still be signed, or paired with a type.
      if (debitCol == null && creditCol == null) {
        if (amount < 0) {
          isIncome = false;
        } else if (typeCol != null) {
          isIncome = _looksIncome(_cell(row, typeCol));
        }
      }

      final title = _cell(row, titleCol).trim();
      out.add(ImportedExpense(
        title: title.isEmpty ? 'Imported' : title,
        amount: amount.abs(),
        date: _parseDate(_cell(row, dateCol)),
        category: _blankToNull(_cell(row, categoryCol)),
        isIncome: isIncome,
      ));
    }
    return out;
  }

  /// No header: assume date, then description, then the first readable amount.
  static List<ImportedExpense> _parsePositional(List<List<String>> table) {
    final out = <ImportedExpense>[];
    for (final row in table) {
      if (row.every((c) => c.trim().isEmpty)) continue;

      DateTime? date;
      double? amount;
      final words = <String>[];

      for (final cell in row) {
        final value = cell.trim();
        if (value.isEmpty) continue;
        if (date == null) {
          final d = _parseDate(value);
          if (d != null) {
            date = d;
            continue;
          }
        }
        final a = _parseAmount(value);
        if (a != null) {
          // Keep the last amount: statements often end with a balance, but a
          // leading reference number would otherwise win.
          amount = a;
          continue;
        }
        words.add(value);
      }

      if (amount == null) continue;
      out.add(ImportedExpense(
        title: words.isEmpty ? 'Imported' : words.join(' '),
        amount: amount.abs(),
        date: date,
        isIncome: amount > 0 && false,
      ));
    }
    return out;
  }

  // ── Markdown and free text ────────────────────────────────────────────────

  static List<ImportedExpense> parseMarkdown(String text) {
    final lines = text.split('\n');

    // A table is the most structured thing a note can hold, so prefer it.
    final tableLines = lines.where((l) => l.trim().startsWith('|')).toList();
    if (tableLines.length >= 2) {
      final rows = tableLines
          .where((l) => !_isTableRule(l))
          .map((l) => _splitTableRow(l))
          .toList();
      if (rows.length >= 2) {
        final asCsv = rows.map((r) => r.join('\u0001')).join('\n');
        final parsed = parseCsv(asCsv.replaceAll('\u0001', ','));
        if (parsed.isNotEmpty) return parsed;
      }
    }

    final out = <ImportedExpense>[];
    for (final raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#') || line.startsWith('>')) continue;
      if (_isTableRule(line)) continue;

      // Strip list markers and checkboxes.
      line = line.replaceFirst(RegExp(r'^[-*+]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
      line = line.replaceFirst(RegExp(r'^\[[ xX]\]\s*'), '');
      if (line.isEmpty) continue;

      final parsed = _parseLooseLine(line);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  /// Reads a line like `Coffee 120`, `03/01 Groceries ₹1,240` or
  /// `Salary +50000`.
  static ImportedExpense? _parseLooseLine(String line) {
    final amountMatch = _looseAmount.allMatches(line).toList();
    if (amountMatch.isEmpty) return null;

    // The trailing number is the amount; earlier ones are usually dates or
    // quantities.
    final match = amountMatch.last;
    final amount = _parseAmount(match.group(0)!);
    if (amount == null) return null;

    var rest = (line.substring(0, match.start) +
            line.substring(match.end))
        .trim();

    DateTime? date;
    final dateMatch = _looseDate.firstMatch(rest);
    if (dateMatch != null) {
      date = _parseDate(dateMatch.group(0)!);
      if (date != null) {
        rest = rest.replaceRange(dateMatch.start, dateMatch.end, '').trim();
      }
    }

    rest = rest.replaceAll(RegExp(r'^[\s:,\-–—]+|[\s:,\-–—]+$'), '').trim();
    if (rest.isEmpty) return null;

    // A leading + marks money coming in; a bare number is a spend.
    final isIncome = match.group(0)!.trimLeft().startsWith('+') ||
        _looksIncome(rest);

    return ImportedExpense(
      title: rest,
      amount: amount.abs(),
      date: date,
      isIncome: isIncome,
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  static final _looseAmount = RegExp(
      r'(?<![\w/\-])[+-]?\s*(?:₹|rs\.?|inr)?\s*\d[\d,]*(?:\.\d{1,2})?(?![\d/\-])',
      caseSensitive: false);

  static final _looseDate = RegExp(
      r'\b(\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)\b');

  static List<String> _contentLines(String text) => text
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();

  static bool _isTableRule(String line) =>
      RegExp(r'^\|?[\s:|-]+\|[\s:|-]*$').hasMatch(line.trim()) &&
      line.contains('-');

  static List<String> _splitTableRow(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((c) => c.trim()).toList();
  }

  static String _detectDelimiter(List<String> lines) {
    const candidates = [',', ';', '\t', '|'];
    var best = ',';
    var bestScore = -1;
    for (final d in candidates) {
      // Consistency across lines matters more than raw count: a description
      // full of commas should not beat a genuine semicolon file.
      final counts =
          lines.take(10).map((l) => _splitCsvLine(l, d).length).toList();
      if (counts.isEmpty) continue;
      final max = counts.reduce((a, b) => a > b ? a : b);
      if (max < 2) continue;
      final consistent = counts.where((c) => c == max).length;
      final score = consistent * 10 + max;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  /// Splits one CSV line, honouring double quotes and `""` escapes.
  static List<String> _splitCsvLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == delimiter) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  /// The first row that names at least an amount-ish and one other column.
  static int? _findHeaderRow(List<List<String>> table) {
    for (var i = 0; i < table.length && i < 5; i++) {
      final cells = table[i].map(_norm).toList();
      final hasAmount = _matchColumn(cells, _amountKeys) != null ||
          _matchColumn(cells, _debitKeys) != null ||
          _matchColumn(cells, _creditKeys) != null;
      final hasOther = _matchColumn(cells, _titleKeys) != null ||
          _matchColumn(cells, _dateKeys) != null;
      // A header names its columns; it does not contain the values.
      final looksLikeData = cells.any((c) => _parseAmount(c) != null);
      if (hasAmount && hasOther && !looksLikeData) return i;
    }
    return null;
  }

  static int? _matchColumn(List<String> header, List<String> keys) {
    for (var i = 0; i < header.length; i++) {
      if (keys.contains(header[i])) return i;
    }
    for (var i = 0; i < header.length; i++) {
      for (final k in keys) {
        if (header[i].contains(k)) return i;
      }
    }
    return null;
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z/ ]'), '').trim();

  static String _cell(List<String> row, int? index) =>
      (index == null || index < 0 || index >= row.length) ? '' : row[index];

  static double? _amountAt(List<String> row, int? index) =>
      index == null ? null : _parseAmount(_cell(row, index));

  static String? _blankToNull(String s) =>
      s.trim().isEmpty ? null : s.trim();

  static bool _looksIncome(String s) {
    final v = s.toLowerCase();
    return v.contains('credit') ||
        v.contains('income') ||
        v.contains('deposit') ||
        v.contains('received') ||
        v.contains('salary') ||
        v.contains('refund') ||
        v == 'cr' ||
        v == 'in';
  }

  /// Reads `1,240.50`, `₹1240`, `Rs. 1240`, `(1240)` and `1240 Dr`.
  static double? _parseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    var negative = false;
    if (RegExp(r'^\(.*\)$').hasMatch(s)) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }

    final lower = s.toLowerCase();
    if (lower.endsWith(' dr') || lower.endsWith('dr')) negative = true;

    s = s.replaceAll(
        RegExp(r'(₹|rs\.?|inr|dr|cr)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[,\s]'), '');

    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    }

    if (s.isEmpty || !RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;

    final value = double.tryParse(s);
    if (value == null) return null;
    return negative ? -value : value;
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Day-first for ambiguous `03/04/2026`, which is the convention where this
  /// app is used. A value above 12 in the first position settles it anyway.
  static DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return _safeDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }

    final slash =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?').firstMatch(s);
    if (slash != null) {
      var a = int.parse(slash.group(1)!);
      var b = int.parse(slash.group(2)!);
      final yearRaw = slash.group(3);
      var year = yearRaw == null
          ? DateTime.now().year
          : (yearRaw.length == 2 ? 2000 + int.parse(yearRaw) : int.parse(yearRaw));
      if (a > 12 && b <= 12) return _safeDate(year, b, a);
      if (b > 12 && a <= 12) return _safeDate(year, a, b);
      return _safeDate(year, b, a);
    }

    // `3 Jan 2026`, `Jan 3`, `3rd January`
    final named = RegExp(
            r'^(?:(\d{1,2})\s*(?:st|nd|rd|th)?\s+)?([a-zA-Z]{3,9})\.?(?:\s+(\d{1,2}))?(?:,?\s+(\d{4}))?$')
        .firstMatch(s);
    if (named != null) {
      final month = _months[named.group(2)!.toLowerCase().substring(
          0, named.group(2)!.length >= 4 ? 3 : named.group(2)!.length)];
      if (month != null) {
        final day = int.tryParse(named.group(1) ?? named.group(3) ?? '');
        if (day != null) {
          final year = int.tryParse(named.group(4) ?? '') ?? DateTime.now().year;
          return _safeDate(year, month, day);
        }
      }
    }

    return null;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null;
    return d;
  }
}

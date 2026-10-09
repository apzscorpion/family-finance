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
    this.account,
    this.isIncome = false,
    this.selected = true,
    this.sourceId,
    this.categoryKey,
    this.pinned = false,
    this.categoryPinned = false,
  });

  final String title;

  /// Always positive; [isIncome] carries the direction.
  final double amount;

  /// Null when the row had no readable date — the import falls back to today.
  final DateTime? date;

  /// Raw category text from the file, matched against real categories later.
  final String? category;

  /// Raw account text: an account/bank column, or the statement's own header
  /// ("Account type: Salary") when the file names one.
  final String? account;

  bool isIncome;

  /// Rows start selected; the preview lets the user drop individual ones.
  bool selected;

  /// Money source the row will be filed under. Set by routing or the user.
  String? sourceId;

  /// Category key used when the file's own category text names no real
  /// category.
  String? categoryKey;

  /// The user set this row's account by hand, so re-routing leaves it alone.
  bool pinned;

  /// The user picked this row's category by hand.
  bool categoryPinned;

  ImportedExpense copyWith({bool? selected}) => ImportedExpense(
        title: title,
        amount: amount,
        date: date,
        category: category,
        account: account,
        isIncome: isIncome,
        selected: selected ?? this.selected,
        sourceId: sourceId,
        categoryKey: categoryKey,
        pinned: pinned,
        categoryPinned: categoryPinned,
      );

  @override
  String toString() =>
      'ImportedExpense($title, $amount, ${date?.toIso8601String()}, '
      'income=$isIncome, source=$sourceId, cat=$categoryKey)';
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
    'merchant', 'payee', 'name', 'item', 'remarks', 'note', 'memo', 'notes',
    'transaction',
  ];
  static const _amountKeys = [
    'amount', 'amt', 'value', 'price', 'total', 'sum', 'cost',
  ];
  static const _debitKeys = ['debit', 'withdrawal', 'dr', 'paid out', 'spent'];
  static const _creditKeys = ['credit', 'deposit', 'cr', 'paid in', 'received'];
  static const _categoryKeys = ['category', 'cat', 'tag', 'group', 'head'];
  static const _typeKeys = ['type', 'direction', 'kind', 'dr/cr'];
  static const _accountKeys = [
    'account', 'account name', 'account type', 'source', 'bank', 'wallet',
    'paid from', 'from account', 'fund', 'pocket',
  ];

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
    var accountCol = _matchColumn(header, _accountKeys);
    if (accountCol == titleCol) accountCol = null;

    // Bank statements open with a few lines about the account itself
    // ("Account Type: Salary Account") before the column header.
    final preamble = table.take(headerIndex).expand((r) => r).join(' ');
    final fileAccount = accountGroupOf(preamble) == null ? null : preamble;

    // Does this file express direction with a minus sign? Decided across the
    // whole file, because a single row tells you nothing: an export where
    // every amount is positive is not signed, it is just all spending.
    var usesSigns = false;
    if (debitCol == null && creditCol == null && amountCol != null) {
      for (var i = headerIndex + 1; i < table.length; i++) {
        final a = _amountAt(table[i], amountCol);
        if (a != null && a < 0) {
          usesSigns = true;
          break;
        }
      }
    }

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

      final title = _cell(row, titleCol).trim();
      final category = _cell(row, categoryCol);

      // With one amount column the direction has to be inferred, in order of
      // how trustworthy the signal is. Previously only the type column was
      // consulted, so a row categorised "Salary" with no type column imported
      // as a spend — which is how an income-heavy sheet ended up inflating
      // the expense total.
      if (debitCol == null && creditCol == null) {
        final typeText = _cell(row, typeCol).trim();
        if (typeText.isNotEmpty) {
          isIncome = _looksIncome(typeText);
        } else if (usesSigns) {
          isIncome = amount > 0;
        } else {
          isIncome = _looksIncome(category) || _looksIncome(title);
        }
      }

      out.add(ImportedExpense(
        title: title.isNotEmpty
            ? title
            : (category.trim().isNotEmpty ? category.trim() : 'Imported'),
        amount: amount.abs(),
        date: _parseDate(_cell(row, dateCol)),
        category: _blankToNull(category),
        account: _blankToNull(_cell(row, accountCol)) ?? fileAccount,
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
      final title = words.isEmpty ? 'Imported' : words.join(' ');
      out.add(ImportedExpense(
        title: title,
        amount: amount.abs(),
        date: date,
        // Without a header there is no type column to consult, so the
        // description is the only signal. (This previously read
        // `amount > 0 && false`, which is never true — every headerless row
        // imported as a spend.)
        isIncome: _looksIncome(title),
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
        if (_headerMentions(header[i], k)) return i;
      }
    }
    return null;
  }

  /// Whether a header names [key] as a whole word.
  ///
  /// A plain `contains` was catastrophic for the two-letter keys: "description"
  /// contains "cr", so on any file with a Description column the credit column
  /// bound to the description, the debit/credit branch took over, and every
  /// row's direction was decided by a column holding text rather than money.
  /// That is why income rows imported as spending.
  static bool _headerMentions(String header, String key) {
    if (header == key) return true;
    return RegExp('(^| )${RegExp.escape(key)}( |\$)').hasMatch(header);
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z/ ]'), '').trim();

  static String _cell(List<String> row, int? index) =>
      (index == null || index < 0 || index >= row.length) ? '' : row[index];

  static double? _amountAt(List<String> row, int? index) =>
      index == null ? null : _parseAmount(_cell(row, index));

  static String? _blankToNull(String s) =>
      s.trim().isEmpty ? null : s.trim();

  static final _incomeWords = RegExp(
      r'\b(income|credit|credited|deposit|received|receipt|salary|wages?|'
      r'payroll|stipend|pension|bonus|refund|reimbursement|reimbursed|'
      r'cashback|dividend|commission|payout|inflow|rental income|'
      r'rent received)\b');

  /// "Loan" cuts both ways: money borrowed is income, an EMI or a repayment
  /// is a spend, and the same word appears in both. The outflow words decide.
  static final _loanWord = RegExp(r'\bloans?\b');
  static final _loanOutflow = RegExp(
      r'\b(emi|repay\w*|instal?ments?|interest|premium|closure|payment|paid|'
      r'processing)\b');

  /// Whether a type, category or description reads as money coming in.
  static bool _looksIncome(String s) {
    final v = s.toLowerCase().trim();
    if (v.isEmpty) return false;

    // Bank exports abbreviate the direction; these are unambiguous.
    if (v == 'cr' || v == 'in' || v == 'credit') return true;
    if (v == 'dr' || v == 'out' || v == 'debit') return false;

    if (_loanWord.hasMatch(v)) return !_loanOutflow.hasMatch(v);
    return _incomeWords.hasMatch(v);
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
      return _withTime(
          _safeDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
              int.parse(iso.group(3)!)),
          s.substring(iso.end));
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
      final rest = s.substring(slash.end);
      if (a > 12 && b <= 12) return _withTime(_safeDate(year, b, a), rest);
      if (b > 12 && a <= 12) return _withTime(_safeDate(year, a, b), rest);
      return _withTime(_safeDate(year, b, a), rest);
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

  static final _timeOfDay = RegExp(
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap])?\.?\s*m?\.?',
      caseSensitive: false);

  /// Adds `11:43 pm`, `23:43` or `T23:43:00` after a date, when there is one.
  static DateTime? _withTime(DateTime? date, String rest) {
    if (date == null) return null;
    final m = _timeOfDay.firstMatch(rest);
    if (m == null) return date;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final half = m.group(4)?.toLowerCase();
    if (half == 'p' && hour < 12) hour += 12;
    if (half == 'a' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return date;
    return DateTime(date.year, date.month, date.day, hour, minute,
        int.tryParse(m.group(3) ?? '') ?? 0);
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null;
    return d;
  }

  // ── Routing: which account and category a row belongs to ─────────────────

  static final _salaryWords =
      RegExp(r'\b(salary|salaries|payroll|wages?|stipend|sal cr)\b');
  static final _businessWords = RegExp(
      r'\b(business|freelance|consult\w*|invoice|client|side income|sales)\b');
  static final _rentInWords = RegExp(
      r'\b(rent received|rental income|rent from|tenant|lease income)\b');
  static final _pensionWords = RegExp(r'\b(pension|annuity)\b');
  static final _refundWords = RegExp(
      r'\b(refund|refunded|cashback|reversal|reversed|reimburse\w*)\b');
  static final _giftWords = RegExp(r'\b(gift|gifted)\b');
  static final _loanInWords = RegExp(r'\b(disburs\w*)\b');

  /// The income category key a row's text reads as: `salary`, `loan`,
  /// `rentin`, `pension`, `business`, `refund`, `gift`, or null.
  static String? incomeKindOf(String text) {
    final v = text.toLowerCase();
    if (v.trim().isEmpty) return null;
    // Loan first: "loan against salary" is borrowed money, not pay.
    if (_loanInWords.hasMatch(v) ||
        (_loanWord.hasMatch(v) && !_loanOutflow.hasMatch(v))) {
      return 'loan';
    }
    if (_salaryWords.hasMatch(v)) return 'salary';
    if (_pensionWords.hasMatch(v)) return 'pension';
    if (_rentInWords.hasMatch(v)) return 'rentin';
    if (_refundWords.hasMatch(v)) return 'refund';
    if (_businessWords.hasMatch(v)) return 'business';
    if (_giftWords.hasMatch(v)) return 'gift';
    return null;
  }

  /// Which seeded money source (`salary`, `side`, `rental`, `loan`, `other`)
  /// an account name points at.
  static String? accountGroupOf(String text) {
    final v = text.toLowerCase();
    if (RegExp(r'\bloans?\b').hasMatch(v)) return 'loan';
    if (RegExp(r'\b(salary|payroll|wages?)\b').hasMatch(v)) return 'salary';
    if (RegExp(r'\b(rent|rental|rentals|tenant)\b').hasMatch(v)) {
      return 'rental';
    }
    if (RegExp(r'\b(side|business|shop|freelance)\b').hasMatch(v)) {
      return 'side';
    }
    if (RegExp(r'\b(pension|other)\b').hasMatch(v)) return 'other';
    return null;
  }

  /// Income kind → the source it is paid into. Refunds and gifts land back in
  /// whichever account is being imported into, so they are not routed.
  static const _incomeSource = {
    'salary': 'salary',
    'loan': 'loan',
    'rentin': 'rental',
    'business': 'side',
    'pension': 'other',
  };

  /// Spending words from people's own sheets, before merchant names.
  static final _categoryWords = <String, RegExp>{
    'dining': RegExp(
        r'\b(food|meals?|lunch|dinner|breakfast|snacks?|tea|coffee|restaurant|dosa|biryani|eat\w*)\b'),
    'groceries': RegExp(r'\b(grocer\w*|vegetables?|milk|supermarket|provisions?)\b'),
    'transport': RegExp(
        r'\b(travel|transport|bus|auto|taxi|cab|train|metro|flight|parking|toll)\b'),
    'fuel': RegExp(r'\b(fuel|petrol|diesel)\b'),
    'bills': RegExp(
        r'\b(bills?|electricity|recharge|mobile|internet|wifi|broadband|sim)\b'),
    'home': RegExp(r'\b(rent|house|home|maintenance)\b'),
    'health': RegExp(r'\b(medic\w*|doctor|hospital|pharmacy|clinic|health)\b'),
    'education': RegExp(r'\b(school|college|tuition|fees?|course|books?)\b'),
    'subs': RegExp(r'\b(subscriptions?|netflix|spotify|prime)\b'),
    'shopping': RegExp(r'\b(shopping|clothes|dress|chappal|shoes?)\b'),
  };

  static final _emiWords =
      RegExp(r'\b(emi|repay\w*|instal?ments?|nach|ach d)\b');

  /// Best category key for a row. Income uses its kind; spending uses merchant
  /// hints, with loan repayments filed as bills rather than as shopping.
  static String? inferCategoryKey(
    ImportedExpense r, {
    Map<String, List<String>> expenseHints = const {},
  }) {
    final text = '${r.category ?? ''} ${r.title}'.toLowerCase();
    if (r.isIncome) return incomeKindOf(text);
    if (_emiWords.hasMatch(text) || _loanWord.hasMatch(text)) return 'bills';
    for (final e in _categoryWords.entries) {
      if (e.value.hasMatch(text)) return e.key;
    }
    for (final e in expenseHints.entries) {
      for (final needle in e.value) {
        if (text.contains(needle)) return e.key;
      }
    }
    return null;
  }

  /// Picks the source a row belongs to.
  ///
  /// In order: an account the file names; the source an income kind is paid
  /// into (a salary credit to Salary, a loan disbursal to Loan); otherwise
  /// [fallbackId], the account the user is importing into.
  static String? routeSource(
    ImportedExpense r,
    List<({String id, String name})> sources, {
    String? fallbackId,
  }) {
    String? byGroup(String group) {
      for (final s in sources) {
        if (accountGroupOf(s.name) == group) return s.id;
      }
      return null;
    }

    final account = r.account?.trim().toLowerCase() ?? '';
    if (account.isNotEmpty) {
      for (final s in sources) {
        final n = s.name.trim().toLowerCase();
        if (n.isNotEmpty && (account == n || account.contains(n))) return s.id;
      }
      final g = accountGroupOf(account);
      final hit = g == null ? null : byGroup(g);
      if (hit != null) return hit;
    }

    if (r.isIncome) {
      final group =
          _incomeSource[incomeKindOf('${r.category ?? ''} ${r.title}')];
      final hit = group == null ? null : byGroup(group);
      if (hit != null) return hit;
    }
    return fallbackId;
  }

  /// Routes every row; rows the user pinned by hand keep their account.
  static void route(
    List<ImportedExpense> rows,
    List<({String id, String name})> sources, {
    String? fallbackId,
    Map<String, List<String>> expenseHints = const {},
  }) {
    for (final r in rows) {
      if (!r.categoryPinned) {
        r.categoryKey = inferCategoryKey(r, expenseHints: expenseHints);
      }
      if (r.pinned) continue;
      r.sourceId = routeSource(r, sources, fallbackId: fallbackId);
    }
  }
}

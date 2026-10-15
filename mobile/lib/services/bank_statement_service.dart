import 'package:intl/intl.dart';

import '../v3/data/expense_import.dart';

/// Service for decoding, parsing, and cleaning statements from Indian banks and cards.
class BankStatementService {
  BankStatementService._();

  /// Suggested password hints by bank name.
  static const Map<String, String> bankPasswordHints = {
    'sbi': 'State Bank of India: Your Date of Birth in DDMMYYYY format (e.g. 05081985).',
    'hdfc': 'HDFC Bank: NetBanking Customer ID (8 digits), or DOB in DDMMYYYY format.',
    'icici': 'ICICI Bank: First 4 letters of your name in lowercase + DOB in DDMM format (e.g. asif0508).',
    'axis': 'Axis Bank: First 4 letters of name in CAPITAL letters + last 4 digits of account/customer ID.',
    'kotak': 'Kotak Mahindra: Your 8-digit CRN (Customer Relationship Number).',
    'pnb': 'Punjab National Bank: Account number (no spaces).',
    'canara': 'Canara Bank: Registered mobile number (10 digits).',
    'general': 'Most Indian banks lock statements with Date of Birth (DDMMYYYY) or PAN Card in CAPITAL letters.',
  };

  /// Returns matching password formula hint based on file name or bank keyword.
  static String getPasswordHint(String fileName) {
    final lower = fileName.toLowerCase();
    for (final entry in bankPasswordHints.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return bankPasswordHints['general']!;
  }

  /// Parses plain-text extracted from a PDF or statement table into structured [ImportedExpense] items.
  static List<ImportedExpense> parseStatementText(String rawText) {
    if (rawText.trim().isEmpty) return const [];

    final lines = rawText.split(RegExp(r'\r?\n'));
    final results = <ImportedExpense>[];

    // Common Indian bank date patterns:
    // 15/10/2026, 15-10-2026, 15 Oct 2026, 15-Oct-2026, 15/Oct/2026
    final datePattern = RegExp(
      r'(\b\d{1,2}[\/\-\.](?:\d{1,2}|[A-Za-z]{3})[\/\-\.]\d{2,4}\b)',
    );

    // Number pattern for currency amounts: 1,250.00 or 450.50 or 5000
    final amountPattern = RegExp(
      r'(\b\d{1,3}(?:,\d{2,3})*(?:\.\d{2})\b)',
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 10) continue;

      // Skip common table headers & disclaimers
      final lower = trimmed.toLowerCase();
      if (lower.contains('opening balance') ||
          lower.contains('closing balance') ||
          lower.contains('brought forward') ||
          lower.contains('page') && lower.contains('of')) {
        continue;
      }

      final dateMatch = datePattern.firstMatch(trimmed);
      if (dateMatch == null) continue;

      final dateStr = dateMatch.group(1)!;
      final parsedDate = _parseFlexibleDate(dateStr);
      if (parsedDate == null) continue;

      // Extract all monetary figures on this line
      final allAmounts = amountPattern
          .allMatches(trimmed)
          .map((m) => m.group(1)!.replaceAll(',', ''))
          .map((s) => double.tryParse(s) ?? 0.0)
          .where((amt) => amt > 0.0)
          .toList();

      if (allAmounts.isEmpty) continue;

      // Determine debit vs credit
      final isCredit = lower.contains(' cr ') ||
          lower.endsWith('cr') ||
          lower.contains('credit') ||
          lower.contains('deposit') ||
          lower.contains('salary');

      // In statements with [Withdrawal, Deposit, Balance], withdrawal is first, or credit is second
      final amount = allAmounts.first;

      // Extract and clean narration
      var narration = trimmed.replaceAll(dateStr, '');
      for (final a in amountPattern.allMatches(trimmed)) {
        narration = narration.replaceAll(a.group(1)!, '');
      }
      narration = _cleanNarration(narration);

      if (narration.isEmpty) narration = isCredit ? 'Bank Deposit' : 'Bank Expense';

      // Auto-categorize based on Indian merchants
      final categoryKey = _detectCategory(narration, isCredit);

      results.add(
        ImportedExpense(
          title: narration,
          amount: amount,
          date: parsedDate,
          isIncome: isCredit,
          categoryKey: categoryKey,
          account: 'Bank Statement',
          selected: true,
        ),
      );
    }

    return results;
  }

  /// Parses diverse Indian date formats into DateTime.
  static DateTime? _parseFlexibleDate(String raw) {
    final cleaned = raw.replaceAll('/', '-').replaceAll('.', '-').trim();
    final formats = [
      'd-M-yyyy',
      'dd-MM-yyyy',
      'd-MMM-yyyy',
      'dd-MMM-yyyy',
      'd-MM-yy',
      'dd-MM-yy',
      'yyyy-MM-dd',
    ];

    for (final f in formats) {
      try {
        return DateFormat(f).parse(cleaned);
      } catch (_) {}
    }
    return null;
  }

  /// Cleans raw bank statement narrations:
  /// e.g. "UPI/428910284729/Swiggy/swiggy@icici/Payment" -> "Swiggy"
  static String _cleanNarration(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\b(UPI|IMPS|NEFT|RTGS|POS|ACH|NACH|BIL|INB|MB|ATM)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\/\:\;\*\#\_\-]+'), ' ')
        .replaceAll(RegExp(r'\b\d{10,16}\b'), '') // Remove long account/ref numbers
        .replaceAll(RegExp(r'@[A-Za-z0-9]+'), '') // Remove VPA handles (@icici, @hdfc)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Extract prominent brand name if present
    final brands = [
      'Swiggy', 'Zomato', 'Amazon', 'Flipkart', 'Uber', 'Ola', 'Zepto', 'Blinkit',
      'BigBasket', 'Myntra', 'Nykaa', 'MakeMyTrip', 'IRCTC', 'BookMyShow',
      'Starbucks', 'McDonalds', 'Reliance', 'DMart', 'Apollo Pharmacy', 'Netmeds',
      'Tata Neu', 'Jio', 'Airtel', 'Netflix', 'Spotify', 'Google', 'Apple',
    ];

    for (final b in brands) {
      if (s.toLowerCase().contains(b.toLowerCase())) {
        return b;
      }
    }

    // Capitalize first letter of remaining text
    if (s.length > 28) s = s.substring(0, 28).trim();
    if (s.isEmpty) return 'Bank Transaction';
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Automatic category detector for Indian statement narrations.
  static String _detectCategory(String narration, bool isIncome) {
    if (isIncome) return 'salary';
    final n = narration.toLowerCase();

    if (n.contains('swiggy') || n.contains('zomato') || n.contains('mcdonald') || n.contains('restaurant') || n.contains('cafe')) {
      return 'groceries';
    }
    if (n.contains('zepto') || n.contains('blinkit') || n.contains('bigbasket') || n.contains('dmart') || n.contains('supermarket')) {
      return 'groceries';
    }
    if (n.contains('uber') || n.contains('ola') || n.contains('petrol') || n.contains('fuel') || n.contains('irctc') || n.contains('metro')) {
      return 'transport';
    }
    if (n.contains('amazon') || n.contains('flipkart') || n.contains('myntra') || n.contains('nykaa') || n.contains('shopping')) {
      return 'shopping';
    }
    if (n.contains('netflix') || n.contains('spotify') || n.contains('bookmyshow') || n.contains('cinema') || n.contains('pvr')) {
      return 'entertainment';
    }
    if (n.contains('pharmacy') || n.contains('hospital') || n.contains('apollo') || n.contains('clinic') || n.contains('meds')) {
      return 'healthcare';
    }
    if (n.contains('electricity') || n.contains('water') || n.contains('broadband') || n.contains('airtel') || n.contains('jio')) {
      return 'utilities';
    }
    return 'general';
  }
}


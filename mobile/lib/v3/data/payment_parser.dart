/// Turns a captured bank or UPI notification into a candidate transaction.
///
/// Everything here runs on the device. The raw notification text is parsed,
/// the fields the user reviews are kept, and the original text is shown back
/// to them for context but never uploaded on its own.
library;

/// How confident the parse is, mirroring the design's High / Check / Duplicate.
enum ParseConfidence { high, check, duplicate }

class ParsedPayment {
  final double amount;
  final String merchant;
  final String? categoryKey;
  final String method;
  final String sourceApp;
  final String snippet;
  final ParseConfidence confidence;
  final String? note;
  final DateTime postedAt;

  /// Credit rather than debit — a refund or an incoming transfer.
  final bool isCredit;

  const ParsedPayment({
    required this.amount,
    required this.merchant,
    this.categoryKey,
    required this.method,
    required this.sourceApp,
    required this.snippet,
    required this.confidence,
    this.note,
    required this.postedAt,
    this.isCredit = false,
  });
}

class PaymentParser {
  PaymentParser._();

  /// Friendly names for the packages the listener watches.
  static const Map<String, String> appNames = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.phonepe.app': 'PhonePe',
    'com.amazon.mShop.android.shopping': 'Amazon Pay',
    'com.whatsapp': 'WhatsApp Pay',
    'com.snapwork.hdfc': 'HDFC Bank',
    'com.csam.icici.bank.imobile': 'ICICI iMobile',
    'com.sbi.lotusintouch': 'YONO SBI',
    'com.sbi.SBIFreedomPlus': 'SBI',
    'com.axis.mobile': 'Axis Mobile',
    'com.kotak.mobile': 'Kotak',
    'com.fss.pnbpsp': 'PNB',
    'com.bankofbaroda.mconnect': 'Bank of Baroda',
    'com.infrasofttech.indianBank': 'Indian Bank',
    'com.canarabank.mobility': 'Canara Bank',
    'com.msf.kbank.mobile': 'Kotak Bank',
    'com.idbibank.gomobile': 'IDBI',
    'com.yesbank': 'YES Bank',
  };

  /// ₹1,234.50 / Rs. 1234 / INR 1,234
  static final _amount = RegExp(
    r'(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  /// "to AMAZON", "at BIGBAZAAR", "to Rapido Bike Taxi"
  static final _merchantTo = RegExp(
    r'\b(?:to|at|towards)\s+([A-Za-z0-9][A-Za-z0-9 &._\-]{2,40}?)(?=\s+(?:on|via|using|from|ref|upi|a/c|acct|txn)\b|[.,\n]|$)',
    caseSensitive: false,
  );

  /// Card or account tail: "XX9910", "••4821", "a/c ending 2207"
  static final _tail = RegExp(
    r'(?:x{2,}|\*{2,}|•{2,}|ending\s+)(\d{4})',
    caseSensitive: false,
  );

  static final _credit = RegExp(
    r'\b(credited|received|refund(?:ed)?|cashback|deposited)\b',
    caseSensitive: false,
  );

  static final _debit = RegExp(
    r'\b(debited|paid|spent|sent|withdrawn|purchase)\b',
    caseSensitive: false,
  );

  /// Merchant keyword → category. First match wins, so order matters.
  static const Map<String, List<String>> _categoryHints = {
    'transport': ['uber', 'ola', 'rapido', 'metro', 'irctc', 'redbus', 'cab'],
    'fuel': ['petrol', 'fuel', 'indian oil', 'hp ', 'bharat petroleum', 'shell'],
    'groceries': [
      'bigbasket', 'dmart', 'grofers', 'blinkit', 'zepto', 'reliance fresh',
      'more supermarket', 'spencer', 'nature', 'instamart', 'grocery',
    ],
    'dining': [
      'swiggy', 'zomato', 'dominos', 'pizza', 'cafe', 'restaurant', 'kfc',
      'mcdonald', 'starbucks', 'barbeque', 'eatfit', 'biryani',
    ],
    'shopping': [
      'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'lifestyle',
      'decathlon', 'croma', 'reliance digital', 'tata cliq',
    ],
    'bills': [
      'electricity', 'airtel', 'jio', 'vodafone', 'vi ', 'bsnl', 'broadband',
      'gas', 'water', 'recharge', 'postpaid', 'bescom', 'tneb',
    ],
    'subs': [
      'netflix', 'spotify', 'prime video', 'hotstar', 'youtube', 'canva',
      'adobe', 'icloud', 'google one', 'subscription',
    ],
    'health': [
      'pharmacy', 'apollo', 'medplus', 'hospital', 'clinic', 'diagnostic',
      'practo', 'pharmeasy', '1mg',
    ],
    'education': ['school', 'college', 'tuition', 'course', 'udemy', 'coursera'],
    'home': ['rent', 'maintenance', 'society'],
  };

  /// Parses one captured notification. Returns null when it does not look like
  /// a payment at all.
  static ParsedPayment? parse({
    required String package,
    required String title,
    required String text,
    required DateTime postedAt,
  }) {
    final body = '$title $text'.trim();
    if (body.isEmpty) return null;

    final amountMatch = _amount.firstMatch(body);
    if (amountMatch == null) return null;

    final amount =
        double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return null;

    final isCredit =
        _credit.hasMatch(body) && !_debit.hasMatch(body);

    final merchant = _merchant(body) ?? _fallbackMerchant(title, package);
    final tail = _tail.firstMatch(body)?.group(1);
    final method = _method(body, tail);
    final category = _category(merchant, body, isCredit);

    // Low confidence when the merchant had to be guessed, or the category
    // came from nothing better than a package name.
    final guessedMerchant = _merchant(body) == null;
    final confidence =
        guessedMerchant || category == null ? ParseConfidence.check : ParseConfidence.high;

    return ParsedPayment(
      amount: amount,
      merchant: merchant,
      categoryKey: category,
      method: method,
      sourceApp: appNames[package] ?? 'Bank app',
      snippet: body.length > 220 ? '${body.substring(0, 220)}…' : body,
      confidence: confidence,
      note: switch (confidence) {
        ParseConfidence.high =>
          'Amount and merchant read with high confidence',
        ParseConfidence.check =>
          guessedMerchant
              ? 'Merchant was unclear — please check'
              : 'Category guessed from merchant — please check',
        ParseConfidence.duplicate => 'Looks like an entry you already added',
      },
      postedAt: postedAt,
      isCredit: isCredit,
    );
  }

  static String? _merchant(String body) {
    final m = _merchantTo.firstMatch(body);
    if (m == null) return null;
    var name = m.group(1)!.trim();
    // Strip trailing noise the lookahead could not catch.
    name = name.replaceAll(RegExp(r'\s+(?:upi|ref|txn).*$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[.,;:]+$'), '').trim();
    if (name.length < 3) return null;
    return _titleCase(name);
  }

  static String _fallbackMerchant(String title, String package) {
    final t = title.trim();
    if (t.isNotEmpty && !_amount.hasMatch(t) && t.length <= 40) {
      return _titleCase(t);
    }
    return appNames[package] ?? 'Payment';
  }

  static String _method(String body, String? tail) {
    final lower = body.toLowerCase();
    if (tail != null && (lower.contains('card') || lower.contains('credit'))) {
      return 'Card ••$tail';
    }
    if (lower.contains('upi')) return 'UPI';
    if (lower.contains('card')) return 'Card';
    if (lower.contains('neft') ||
        lower.contains('imps') ||
        lower.contains('a/c') ||
        lower.contains('account')) {
      return 'Bank';
    }
    return 'UPI';
  }

  static String? _category(String merchant, String body, bool isCredit) {
    if (isCredit) return 'refund';
    final hay = '$merchant $body'.toLowerCase();
    for (final entry in _categoryHints.entries) {
      for (final needle in entry.value) {
        if (hay.contains(needle)) return entry.key;
      }
    }
    return null;
  }

  static String _titleCase(String v) => v
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty
          ? w
          : (w.length <= 3 && w == w.toUpperCase()
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'))
      .join(' ');

  /// Flags a parse that matches something already recorded: same amount, same
  /// day, similar merchant.
  static bool looksDuplicate(
    ParsedPayment p,
    Iterable<({double amount, String title, DateTime at})> existing,
  ) {
    for (final e in existing) {
      if ((e.amount - p.amount).abs() > 0.01) continue;
      final sameDay = e.at.year == p.postedAt.year &&
          e.at.month == p.postedAt.month &&
          e.at.day == p.postedAt.day;
      if (!sameDay) continue;
      final a = e.title.toLowerCase();
      final b = p.merchant.toLowerCase();
      if (a.contains(b) || b.contains(a)) return true;
    }
    return false;
  }
}

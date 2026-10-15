/// Service for "Never lose a refund again" — tracking uncredited refunds,
/// failed UPI debits, and generating formal RBI TAT compensation complaint letters.
class RefundWatchdogService {
  RefundWatchdogService._();

  /// Checks if a text snippet indicates an ongoing refund or failed transaction.
  static RefundDetectionResult analyzeText(String text) {
    final lower = text.toLowerCase();

    bool isRefund = lower.contains('refund') ||
        lower.contains('reversed') ||
        lower.contains('debited but') ||
        lower.contains('failed transaction') ||
        lower.contains('will be returned') ||
        lower.contains('money will be credited') ||
        lower.contains('credited back');

    if (!isRefund) {
      return const RefundDetectionResult(isDetected: false);
    }

    // Amount extraction
    double? amount;
    final amtMatch = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'([\d,]+(?:\.\d{2})?)\s*(?:rs|inr|₹)', caseSensitive: false).firstMatch(text);
    if (amtMatch != null) {
      final clean = amtMatch.group(1)?.replaceAll(',', '');
      if (clean != null) amount = double.tryParse(clean);
    }

    // UTR / Reference extraction
    String? utr;
    final utrMatch = RegExp(r'(?:utr|ref|rrn|txn\s*id)[:\s#]*([a-zA-Z0-9]{8,18})', caseSensitive: false).firstMatch(text);
    if (utrMatch != null) {
      utr = utrMatch.group(1);
    }

    // Merchant extraction
    String merchant = 'Merchant / Bank';
    for (final m in ['Swiggy', 'Zomato', 'Amazon', 'Flipkart', 'Uber', 'Ola', 'Blinkit', 'Zepto', 'IRCTC', 'Myntra', 'MakeMyTrip']) {
      if (lower.contains(m.toLowerCase())) {
        merchant = m;
        break;
      }
    }

    return RefundDetectionResult(
      isDetected: true,
      amount: amount ?? 0.0,
      merchant: merchant,
      utr: utr,
      snippet: text.length > 150 ? '${text.substring(0, 147)}…' : text,
    );
  }

  /// Calculates elapsed calendar days since refund was initiated.
  static int daysElapsed(DateTime initiatedAt) {
    return DateTime.now().difference(initiatedAt).inDays;
  }

  /// True if refund is pending for 5 or more days (beyond standard RBI T+5 SLA).
  static bool isOverdue(DateTime initiatedAt) {
    return daysElapsed(initiatedAt) >= 5;
  }

  /// Calculates compensation due as per RBI Circular DPSS.CO.PD No.629/02.01.014/2019-20 (₹100/day after T+5).
  static double compensationDue(DateTime initiatedAt) {
    final days = daysElapsed(initiatedAt);
    if (days > 5) {
      return (days - 5) * 100.0;
    }
    return 0.0;
  }

  /// Generates a formal, bank-ready grievance complaint letter.
  static String generateComplaintLetter({
    required String merchant,
    required double amount,
    required DateTime initiatedAt,
    String? utrNumber,
    String? bankName,
    String? userName,
  }) {
    final days = daysElapsed(initiatedAt);
    final comp = compensationDue(initiatedAt);
    final utr = (utrNumber != null && utrNumber.isNotEmpty) ? utrNumber : 'Pending Bank Statement Verification';
    final bank = (bankName != null && bankName.isNotEmpty) ? bankName : 'Nodal Bank Officer';
    final user = (userName != null && userName.isNotEmpty) ? userName : 'Account Holder';

    return '''
Subject: Urgent Grievance: Unreversed Failed/Refund Transaction of ₹${amount.toStringAsFixed(2)} [Ref: $utr]

To:
The Principal Nodal Grievance Redressal Officer,
$bank

CC: National Payments Corporation of India (NPCI) & RBI Banking Ombudsman

Dear Sir/Madam,

I am writing to lodge a formal dispute regarding an unreversed payment/refund that has not been credited back to my account within the mandated turnaround timeline.

TRANSACTION DETAILS:
• Merchant / Service: $merchant
• Disputed Amount: ₹${amount.toStringAsFixed(2)}
• Initiation Date: ${initiatedAt.day}/${initiatedAt.month}/${initiatedAt.year} ($days days ago)
• UTR / RRN Reference: $utr
• Status: Not Credited

REGULATORY NOTICE & RBI TAT DIRECTIVE:
As per Reserve Bank of India (RBI) Circular DPSS.CO.PD No.629/02.01.014/2019-20 ("Harmonisation of Turn Around Time (TAT) and customer compensation for failed transactions using authorised Payment Systems"):
1. The permitted Turnaround Time (TAT) for reversal of failed transactions/refunds is T + 5 calendar days.
2. If the beneficiary or remitter bank fails to reverse the debit within T + 5 days, compensation of ₹100 per day of delay is statutorily payable to the customer.

Current delay status: $days calendar days (${days > 5 ? '$days - 5 = ${days - 5} days delayed' : 'Under 5 days'}).
${comp > 0 ? 'Accrued statutory delay compensation: ₹${comp.toStringAsFixed(0)} (₹100/day for ${days - 5} delayed days).' : ''}

REQUESTED RESOLUTION:
1. Immediately credit the principal amount of ₹${amount.toStringAsFixed(2)} to my source account.
2. Provide the internal Core Banking reversal reference number.
3. Credit applicable RBI statutory delay compensation if uncredited beyond T+5.

If this grievance is not acknowledged and resolved within 48 hours, I will escalate this complaint along with this correspondence directly to the RBI Ombudsman via the Complaint Management System (CMS) at cms.rbi.org.in.

Yours faithfully,
$user
'''.trim();
  }
}

class RefundDetectionResult {
  final bool isDetected;
  final double amount;
  final String merchant;
  final String? utr;
  final String? snippet;

  const RefundDetectionResult({
    required this.isDetected,
    this.amount = 0.0,
    this.merchant = 'Merchant',
    this.utr,
    this.snippet,
  });
}


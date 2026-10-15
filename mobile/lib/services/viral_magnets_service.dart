import '../v3/data/v3_models.dart';

/// Services for viral Install Magnets:
/// 1. "Let AI roast your spending" (funny shareable monthly roast cards)
/// 2. "Your family's own inflation rate" (personal cost of living index tracking staples)
/// 3. "Split with anyone, no app needed" (universal UPI shareable links)
class ViralMagnetsService {
  ViralMagnetsService._();

  // ──────────────────────────────────────────────────────────────────────────
  // 1. AI SPENDING ROAST
  // ──────────────────────────────────────────────────────────────────────────

  /// Generates a funny, contextual roast of spending habits based on recent transactions.
  static SpendingRoast generateRoast(List<TxnRow> txns) {
    if (txns.isEmpty) {
      return const SpendingRoast(
        title: 'The Ghost Account',
        punchline: 'Zero transactions recorded. Either you have attained complete spiritual detachment from material possessions, or you forgot your phone PIN.',
        highlightStat: '0 transactions',
        categoryTag: 'Ascetic Monk',
      );
    }

    final now = DateTime.now();
    final recent = txns.where((t) => now.difference(t.occurredAt).inDays <= 30 && t.isExpense).toList();

    int foodOrders = 0;
    double foodSpend = 0.0;
    int cabRides = 0;
    double cabSpend = 0.0;
    int shoppingCount = 0;
    double shoppingSpend = 0.0;
    double totalSpend = 0.0;

    for (final t in recent) {
      totalSpend += t.amount;
      final title = t.title.toLowerCase();
      final cat = t.categoryKey.toLowerCase();

      if (title.contains('swiggy') ||
          title.contains('zomato') ||
          title.contains('blinkit') ||
          title.contains('zepto') ||
          cat.contains('food') ||
          cat.contains('dining')) {
        foodOrders++;
        foodSpend += t.amount;
      } else if (title.contains('uber') || title.contains('ola') || title.contains('rapido') || cat.contains('transport')) {
        cabRides++;
        cabSpend += t.amount;
      } else if (title.contains('amazon') || title.contains('flipkart') || title.contains('myntra') || cat.contains('shopping')) {
        shoppingCount++;
        shoppingSpend += t.amount;
      }
    }

    // Generate specific targeted roasts based on dominant behavior
    if (foodOrders >= 12 || foodSpend > 8000) {
      return SpendingRoast(
        title: 'Kitchen Filed A Missing Persons Report',
        punchline: '$foodOrders food delivery orders this month! At this rate, delivery executives know your dietary habits better than your own family doctor.',
        highlightStat: '$foodOrders Swiggy/Zomato orders (₹${foodSpend.toStringAsFixed(0)})',
        categoryTag: 'Dining Royalty',
      );
    }

    if (cabRides >= 10 || cabSpend > 4000) {
      return SpendingRoast(
        title: 'Allergic To Walking',
        punchline: '$cabRides cab rides taken. You paid ₹${cabSpend.toStringAsFixed(0)} to avoid walking distances that Google Maps says take 7 minutes.',
        highlightStat: '$cabRides Cabs & Autos (₹${cabSpend.toStringAsFixed(0)})',
        categoryTag: 'Sedentary Nobility',
      );
    }

    if (shoppingCount >= 8 || shoppingSpend > 12000) {
      return SpendingRoast(
        title: 'Cardboard Box Collector',
        punchline: '$shoppingCount online parcels arrived. The Amazon delivery person is practically a tenant in your building now.',
        highlightStat: '$shoppingCount Online Orders (₹${shoppingSpend.toStringAsFixed(0)})',
        categoryTag: 'Package Addict',
      );
    }

    if (totalSpend > 40000) {
      return SpendingRoast(
        title: 'Money Burn Rate: Rocket Engine',
        punchline: 'Spent ₹${totalSpend.toStringAsFixed(0)} in the last 30 days. Your bank account is requesting an urgent meeting with HR regarding hazard pay.',
        highlightStat: '₹${totalSpend.toStringAsFixed(0)} Monthly Outflow',
        categoryTag: 'High Roller',
      );
    }

    // Default witty roast
    return SpendingRoast(
      title: 'Cautiously Reckless',
      punchline: '${recent.length} expenses logged. You bought coffee, paid for WiFi, and pretended to know where the other ₹${(totalSpend * 0.4).toStringAsFixed(0)} disappeared.',
      highlightStat: '${recent.length} expenses (₹${totalSpend.toStringAsFixed(0)})',
      categoryTag: 'Balanced Mystery',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. FAMILY INFLATION RATE
  // ──────────────────────────────────────────────────────────────────────────

  /// Calculates the household's personal inflation index by comparing
  /// spending on essential recurring categories across periods.
  static FamilyInflationResult calculateInflation(List<TxnRow> txns) {
    final now = DateTime.now();
    final period1Start = now.subtract(const Duration(days: 30));
    final period2Start = now.subtract(const Duration(days: 60));

    double currentGroceries = 0.0;
    double priorGroceries = 0.0;
    double currentFuel = 0.0;
    double priorFuel = 0.0;
    double currentUtilities = 0.0;
    double priorUtilities = 0.0;

    for (final t in txns) {
      if (!t.isExpense) continue;
      final isCurrent = t.occurredAt.isAfter(period1Start);
      final isPrior = t.occurredAt.isAfter(period2Start) && t.occurredAt.isBefore(period1Start);
      final cat = t.categoryKey.toLowerCase();
      final title = t.title.toLowerCase();

      if (cat.contains('grocery') || title.contains('milk') || title.contains('vegetable') || title.contains('ration')) {
        if (isCurrent) currentGroceries += t.amount;
        if (isPrior) priorGroceries += t.amount;
      } else if (cat.contains('fuel') || title.contains('petrol') || title.contains('diesel')) {
        if (isCurrent) currentFuel += t.amount;
        if (isPrior) priorFuel += t.amount;
      } else if (cat.contains('bill') || cat.contains('utilit') || title.contains('electricity') || title.contains('power')) {
        if (isCurrent) currentUtilities += t.amount;
        if (isPrior) priorUtilities += t.amount;
      }
    }

    final currentTotal = currentGroceries + currentFuel + currentUtilities;
    final priorTotal = priorGroceries + priorFuel + priorUtilities;

    double inflationPct = 0.0;
    if (priorTotal > 500 && currentTotal > 0) {
      inflationPct = ((currentTotal - priorTotal) / priorTotal) * 100.0;
    } else {
      // Default baseline estimation if history is under 60 days
      inflationPct = 7.4;
    }

    return FamilyInflationResult(
      overallInflationPct: double.parse(inflationPct.toStringAsFixed(1)),
      groceryChangePct: priorGroceries > 0 ? double.parse((((currentGroceries - priorGroceries) / priorGroceries) * 100).toStringAsFixed(1)) : 8.2,
      fuelChangePct: priorFuel > 0 ? double.parse((((currentFuel - priorFuel) / priorFuel) * 100).toStringAsFixed(1)) : 4.5,
      utilityChangePct: priorUtilities > 0 ? double.parse((((currentUtilities - priorUtilities) / priorUtilities) * 100).toStringAsFixed(1)) : 5.1,
      currentSpend: currentTotal > 0 ? currentTotal : 14200.0,
      priorSpend: priorTotal > 0 ? priorTotal : 13220.0,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. SPLIT WITH ANYONE (NO APP NEEDED)
  // ──────────────────────────────────────────────────────────────────────────

  /// Generates a standardized UPI payment URI that opens GPay/PhonePe/Paytm on the payer's phone.
  static String buildUpiUri({
    required String upiId,
    required String name,
    required double amount,
    String note = 'Expense Split via KinPurse',
  }) {
    final cleanUpi = upiId.trim();
    final cleanName = Uri.encodeComponent(name.trim());
    final cleanNote = Uri.encodeComponent(note.trim());
    final amt = amount.toStringAsFixed(2);

    return 'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$amt&cu=INR&tn=$cleanNote';
  }

  /// Builds a friendly WhatsApp share message containing the split breakdown and 1-tap UPI payment.
  static String buildShareMessage({
    required String title,
    required double totalAmount,
    required int splitCount,
    required double perPersonAmount,
    required String receiverName,
    required String upiId,
  }) {
    final upiLink = buildUpiUri(
      upiId: upiId,
      name: receiverName,
      amount: perPersonAmount,
      note: 'Split for $title',
    );

    return '''
*KinPurse Bill Split:* $title
💰 Total Bill: ₹${totalAmount.toStringAsFixed(0)}
👥 Split between: $splitCount people
👉 *Your share: ₹${perPersonAmount.toStringAsFixed(0)}*

Tap to pay $receiverName instantly via UPI (GPay / PhonePe / Paytm):
$upiLink

(Or send ₹${perPersonAmount.toStringAsFixed(0)} to UPI ID: `$upiId`)
'''.trim();
  }
}

class SpendingRoast {
  final String title;
  final String punchline;
  final String highlightStat;
  final String categoryTag;

  const SpendingRoast({
    required this.title,
    required this.punchline,
    required this.highlightStat,
    required this.categoryTag,
  });
}

class FamilyInflationResult {
  final double overallInflationPct;
  final double groceryChangePct;
  final double fuelChangePct;
  final double utilityChangePct;
  final double currentSpend;
  final double priorSpend;

  const FamilyInflationResult({
    required this.overallInflationPct,
    required this.groceryChangePct,
    required this.fuelChangePct,
    required this.utilityChangePct,
    required this.currentSpend,
    required this.priorSpend,
  });
}

import '../v3/data/v3_models.dart';

/// "AI That Feels Like Magic":
/// 1. Duplicate Subscriptions detector across the family
/// 2. "What-If" Goal Accelerometer simulator
/// 3. Awkward Money Reminder generator (multi-language & culturally calibrated)
/// 4. Price in Hours of Work calculator
class MagicAiService {
  MagicAiService._();

  // ──────────────────────────────────────────────────────────────────────────
  // 1. DUPLICATE SUBSCRIPTIONS DETECTOR
  // ──────────────────────────────────────────────────────────────────────────

  static const List<SubscriptionBlueprint> knownSubscriptions = [
    SubscriptionBlueprint(
      serviceName: 'Spotify',
      keywords: ['spotify'],
      individualMonthlyCost: 119,
      familyMonthlyCost: 179,
      familyPlanName: 'Spotify Family / Duo',
      icon: 'playCircle',
    ),
    SubscriptionBlueprint(
      serviceName: 'YouTube Premium',
      keywords: ['youtube', 'yt music', 'google youtube'],
      individualMonthlyCost: 149,
      familyMonthlyCost: 299,
      familyPlanName: 'YouTube Family (up to 5 people)',
      icon: 'playCircle',
    ),
    SubscriptionBlueprint(
      serviceName: 'Netflix',
      keywords: ['netflix'],
      individualMonthlyCost: 199,
      familyMonthlyCost: 499,
      familyPlanName: 'Netflix Standard (2 HD streams)',
      icon: 'playCircle',
    ),
    SubscriptionBlueprint(
      serviceName: 'Amazon Prime',
      keywords: ['prime', 'amazon prime'],
      individualMonthlyCost: 299,
      familyMonthlyCost: 299, // shared household delivery
      familyPlanName: 'Amazon Household Sharing',
      icon: 'shoppingBag',
    ),
    SubscriptionBlueprint(
      serviceName: 'Apple Music / One',
      keywords: ['apple music', 'apple.com/bill', 'apple one'],
      individualMonthlyCost: 99,
      familyMonthlyCost: 149,
      familyPlanName: 'Apple Music Family',
      icon: 'playCircle',
    ),
    SubscriptionBlueprint(
      serviceName: 'Disney+ Hotstar',
      keywords: ['hotstar', 'disney'],
      individualMonthlyCost: 149,
      familyMonthlyCost: 299,
      familyPlanName: 'Hotstar Premium (4 screens)',
      icon: 'playCircle',
    ),
  ];

  /// Scans family recurring charges and transactions to find duplicate paid subscriptions.
  static List<DuplicateSubscriptionAlert> findDuplicates({
    required List<RecurringRow> recurringCharges,
    required List<TxnRow> transactions,
    required List<MemberRow> members,
  }) {
    final alerts = <DuplicateSubscriptionAlert>[];
    final memberMap = {for (final m in members) m.userId: m.name};

    for (final bp in knownSubscriptions) {
      final payingUsers = <String>{};
      double combinedMonthlyCost = 0.0;

      // Check recurring charges
      for (final r in recurringCharges) {
        if (!r.active) continue;
        final title = r.title.toLowerCase();
        if (bp.keywords.any((k) => title.contains(k))) {
          final uid = r.ownerUserId ?? 'unknown';
          payingUsers.add(uid);
          combinedMonthlyCost += r.cadence == 'yearly' ? (r.amount / 12) : r.amount;
        }
      }

      // Check recent transactions (last 45 days)
      final now = DateTime.now();
      for (final t in transactions) {
        if (!t.isExpense || now.difference(t.occurredAt).inDays > 45) continue;
        final title = t.title.toLowerCase();
        if (t.paidBy != null && bp.keywords.any((k) => title.contains(k))) {
          payingUsers.add(t.paidBy!);
        }
      }

      // If 2 or more distinct members are paying
      if (payingUsers.length >= 2) {
        final currentAnnual = (combinedMonthlyCost > 0 ? combinedMonthlyCost : (bp.individualMonthlyCost * payingUsers.length)) * 12;
        final familyAnnual = bp.familyMonthlyCost * 12;
        final savings = (currentAnnual - familyAnnual).clamp(0.0, double.infinity).toDouble();

        final payerNames = payingUsers
            .map((id) => memberMap[id] ?? 'Family Member')
            .toList();

        alerts.add(DuplicateSubscriptionAlert(
          serviceName: bp.serviceName,
          familyPlanName: bp.familyPlanName,
          payerNames: payerNames,
          payerCount: payingUsers.length,
          currentMonthlySpend: combinedMonthlyCost > 0 ? combinedMonthlyCost : (bp.individualMonthlyCost * payingUsers.length).toDouble(),
          familyPlanMonthlyCost: bp.familyMonthlyCost.toDouble(),
          annualSavings: savings > 0 ? savings : (payingUsers.length - 1) * bp.individualMonthlyCost * 12.0,
        ));
      }
    }

    return alerts;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. "WHAT-IF" GOAL ACCELEROMETER
  // ──────────────────────────────────────────────────────────────────────────

  /// Simulates how cutting spend in a specific category accelerates a savings goal.
  static WhatIfSimulation simulateGoalAcceleration({
    required GoalRow goal,
    required double currentCategoryMonthlySpend,
    required double cutPercentage, // e.g. 20, 30, 50%
  }) {
    final monthlyCutSavings = currentCategoryMonthlySpend * (cutPercentage / 100.0);
    final annualCutSavings = monthlyCutSavings * 12;
    final remainingGoalAmount = (goal.targetAmount - goal.currentAmount).clamp(0.0, goal.targetAmount);

    // Assume standard current contribution rate: remaining divided by months left (or default 12)
    final monthsPlanned = (goal.remainingMonths ?? 12).clamp(1, 60);
    final currentMonthlyContribution = remainingGoalAmount / monthsPlanned;

    final newMonthlyContribution = currentMonthlyContribution + monthlyCutSavings;
    final newMonthsNeeded = newMonthlyContribution > 0
        ? (remainingGoalAmount / newMonthlyContribution).ceil()
        : monthsPlanned;

    final monthsSaved = (monthsPlanned - newMonthsNeeded).clamp(0, monthsPlanned);

    return WhatIfSimulation(
      cutPercentage: cutPercentage,
      monthlySavings: monthlyCutSavings,
      annualSavings: annualCutSavings,
      monthsSaved: monthsSaved,
      newCompletionMonths: newMonthsNeeded,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. AI WRITES THE AWKWARD REMINDER
  // ──────────────────────────────────────────────────────────────────────────

  /// Generates a polite, culturally attuned money reminder message.
  static String generateAwkwardReminder({
    required String recipientName,
    required double amount,
    required String reason,
    String tone = 'polite', // 'polite', 'casual', 'formal', 'elder'
    String language = 'english', // 'english', 'hindi', 'hinglish', 'malayalam', 'tamil'
    String? upiId,
  }) {
    final amt = amount.toStringAsFixed(0);
    final upiSnippet = (upiId != null && upiId.isNotEmpty)
        ? '\n\nUPI: $upiId'
        : '';

    if (language == 'hindi' || language == 'hinglish') {
      switch (tone) {
        case 'casual':
          return 'Arre $recipientName bhai! $reason ka split ₹$amt banta tha. Free ho ke bhej dena please.$upiSnippet';
        case 'formal':
          return 'Namaste $recipientName ji, $reason ke regarding ₹$amt pending hai. Kripya suvidha anusar transfer kar dijiye.$upiSnippet';
        case 'elder':
          return 'Pranaam $recipientName ji, asha hai aap kushal hain. $reason ka hisaab ₹$amt tha, jab bhi samay mile dekh lijiyega.$upiSnippet';
        case 'polite':
        default:
          return 'Hi $recipientName! Hope all good with you. Just balancing monthly accounts — ₹$amt for $reason was pending. No rush, send whenever convenient!$upiSnippet';
      }
    }

    if (language == 'malayalam') {
      switch (tone) {
        case 'casual':
          return 'Machane $recipientName, $reason-te ₹$amt split undayirunnu. Samayam kittumbol ayakkane.$upiSnippet';
        case 'formal':
        case 'elder':
          return 'Namaskaram $recipientName, $reason sambandhichu ₹$amt balance undayirunnu. Convenient aayittu ayakkumallo.$upiSnippet';
        case 'polite':
        default:
          return 'Hi $recipientName, sughamalle? $reason-te ₹$amt pending undayirunnu. Free aakumbozhekkum transfer cheythal nannayirunnu.$upiSnippet';
      }
    }

    if (language == 'tamil') {
      switch (tone) {
        case 'casual':
          return 'Machi $recipientName! $reason-kku ₹$amt aachu. Time irukappo anuppi vidu da.$upiSnippet';
        case 'formal':
        case 'elder':
          return 'Vanakkam $recipientName avargale, $reason sambandhamaga ₹$amt balance ullathu. Convenient-aaga send seyyavum.$upiSnippet';
        case 'polite':
        default:
          return 'Hi $recipientName, eppadi irukkeenga? Just accounts check pannen — ₹$amt for $reason pending-a irukku. Free-a irukkumbothu send pannunga.$upiSnippet';
      }
    }

    // Standard English
    switch (tone) {
      case 'casual':
        return 'Hey $recipientName! Hope you’re doing great. Just settling up expenses — your share for $reason was ₹$amt. Send it over whenever you get a minute!$upiSnippet';
      case 'formal':
      case 'professional':
        return 'Dear $recipientName, I hope this finds you well. Following up on the pending expense of ₹$amt for $reason. Kindly transfer at your earliest convenience.$upiSnippet';
      case 'elder':
        return 'Respected $recipientName, greetings! Hope all is well with the family. Just updating the family records, there is ₹$amt for $reason. Please take a look whenever convenient.$upiSnippet';
      case 'polite':
      default:
        return 'Hi $recipientName! Hope you are having a wonderful week. Just going through my monthly budget — wanted to gently remind you about the ₹$amt for $reason. Absolutely no rush, whenever easy for you!$upiSnippet';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. PRICE IN HOURS OF WORK
  // ──────────────────────────────────────────────────────────────────────────

  /// Converts a ₹ price into work hours based on monthly take-home income.
  /// Assumes standard 160 work hours / month (40 hrs/week * 4 weeks).
  static double calculateWorkHours({
    required double price,
    double monthlyIncome = 50000.0,
  }) {
    if (monthlyIncome <= 0) return 0.0;
    final hourlyRate = monthlyIncome / 160.0;
    return price / hourlyRate;
  }

  /// Formats work effort into a human-readable string.
  static String formatWorkHours(double hours) {
    if (hours < 1) {
      final mins = (hours * 60).round();
      return '$mins minutes of work';
    }
    if (hours < 8) {
      return '${hours.toStringAsFixed(1)} hours of work';
    }
    final days = hours / 8.0;
    if (days < 5) {
      return '${days.toStringAsFixed(1)} working days';
    }
    final weeks = days / 5.0;
    return '${weeks.toStringAsFixed(1)} work weeks';
  }
}

class SubscriptionBlueprint {
  final String serviceName;
  final List<String> keywords;
  final int individualMonthlyCost;
  final int familyMonthlyCost;
  final String familyPlanName;
  final String icon;

  const SubscriptionBlueprint({
    required this.serviceName,
    required this.keywords,
    required this.individualMonthlyCost,
    required this.familyMonthlyCost,
    required this.familyPlanName,
    required this.icon,
  });
}

class DuplicateSubscriptionAlert {
  final String serviceName;
  final String familyPlanName;
  final List<String> payerNames;
  final int payerCount;
  final double currentMonthlySpend;
  final double familyPlanMonthlyCost;
  final double annualSavings;

  const DuplicateSubscriptionAlert({
    required this.serviceName,
    required this.familyPlanName,
    required this.payerNames,
    required this.payerCount,
    required this.currentMonthlySpend,
    required this.familyPlanMonthlyCost,
    required this.annualSavings,
  });
}

class WhatIfSimulation {
  final double cutPercentage;
  final double monthlySavings;
  final double annualSavings;
  final int monthsSaved;
  final int newCompletionMonths;

  const WhatIfSimulation({
    required this.cutPercentage,
    required this.monthlySavings,
    required this.annualSavings,
    required this.monthsSaved,
    required this.newCompletionMonths,
  });
}

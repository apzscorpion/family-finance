import '../v3/data/v3_models.dart';

/// One discovered subscription or recurring candidate based on historical expense patterns.
class DetectedSubscription {
  final String title;
  final double amount;
  final String cadence; // 'monthly' | 'weekly' | 'yearly'
  final int occurrences;
  final DateTime lastOccurred;
  final String? categoryKey;
  final String? sourceId;
  final String? method;
  final String? paidBy;

  const DetectedSubscription({
    required this.title,
    required this.amount,
    required this.cadence,
    required this.occurrences,
    required this.lastOccurred,
    this.categoryKey,
    this.sourceId,
    this.method,
    this.paidBy,
  });
}

/// Service that analyzes local expense transaction history to detect recurring subscriptions
/// (e.g. Netflix, Spotify, gym memberships, electricity bills, rent, SIP).
class SubscriptionFinderService {
  SubscriptionFinderService._();

  /// Scans transactions and compares with existing recurring rules to find candidates.
  static List<DetectedSubscription> findPotentialSubscriptions({
    required List<TxnRow> transactions,
    required List<RecurringRow> existingRecurring,
  }) {
    if (transactions.length < 2) return [];

    // Filter to only expenses
    final expenses = transactions.where((t) => t.isExpense && t.amount > 0).toList();

    // Group expenses by normalized title / merchant
    final grouped = <String, List<TxnRow>>{};
    for (final txn in expenses) {
      final name = txn.title.trim().toLowerCase();
      if (name.isEmpty) continue;
      grouped.putIfAbsent(name, () => []).add(txn);
    }

    final existingTitles = existingRecurring.map((r) => r.title.trim().toLowerCase()).toSet();
    final candidates = <DetectedSubscription>[];

    for (final entry in grouped.entries) {
      final name = entry.key;
      // Skip if already tracked as recurring
      if (existingTitles.contains(name)) continue;

      final txns = entry.value;
      if (txns.length < 2) continue;

      // Sort by date ascending
      txns.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

      // Group by approximate amount (+/- 2%)
      final amountBuckets = <double, List<TxnRow>>{};
      for (final t in txns) {
        var matched = false;
        for (final baseAmount in amountBuckets.keys) {
          if ((t.amount - baseAmount).abs() / baseAmount < 0.03) {
            amountBuckets[baseAmount]!.add(t);
            matched = true;
            break;
          }
        }
        if (!matched) {
          amountBuckets[t.amount] = [t];
        }
      }

      for (final bucket in amountBuckets.values) {
        if (bucket.length < 2) continue;

        // Check intervals between consecutive occurrences
        final daysBetween = <int>[];
        for (var i = 1; i < bucket.length; i++) {
          final diff = bucket[i].occurredAt.difference(bucket[i - 1].occurredAt).inDays;
          daysBetween.add(diff);
        }

        // Monthly pattern check: intervals between 25 and 35 days
        final monthlyMatches = daysBetween.where((d) => d >= 25 && d <= 35).length;
        // Weekly pattern check: intervals between 6 and 8 days
        final weeklyMatches = daysBetween.where((d) => d >= 6 && d <= 8).length;

        String? cadence;
        if (monthlyMatches >= 1 && (monthlyMatches / daysBetween.length) >= 0.5) {
          cadence = 'monthly';
        } else if (weeklyMatches >= 1 && (weeklyMatches / daysBetween.length) >= 0.5) {
          cadence = 'weekly';
        }

        if (cadence != null) {
          final latest = bucket.last;
          candidates.add(
            DetectedSubscription(
              title: latest.title.trim(),
              amount: latest.amount,
              cadence: cadence,
              occurrences: bucket.length,
              lastOccurred: latest.occurredAt,
              categoryKey: latest.categoryKey,
              sourceId: latest.sourceId,
              method: latest.method,
              paidBy: latest.paidBy,
            ),
          );
        }
      }
    }

    // Sort by recent and occurrence count
    candidates.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return candidates;
  }
}

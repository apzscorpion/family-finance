import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance/models/finance_models.dart';
// filterInScope is an extension declared alongside the provider.
import 'package:family_finance/providers/finance_provider.dart';

TransactionDef txn({
  int? createdAtMs,
  int daysAgo = 0,
  int id = 1,
  double amount = 100,
}) =>
    TransactionDef(
      id: id,
      daysAgo: daysAgo,
      createdAtMs: createdAtMs,
      title: 'Test',
      catKey: 'groceries',
      amount: amount,
      type: 'expense',
      memberId: 'me',
      method: 'Cash',
      origin: 'manual',
      time: 'Now',
    );

void main() {
  group('transaction aging', () {
    // Regression: daysAgo was a stored int written once as 0 and never
    // recomputed, so every transaction stayed "today" forever. That silently
    // broke the 7D/30D filter, the weekly chart and the Today/Yesterday
    // grouping. ageInDays must be derived from the timestamp instead.
    test('ageInDays advances with real elapsed time', () {
      final tenDaysAgo =
          DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch;
      final t = txn(createdAtMs: tenDaysAgo, daysAgo: 0);

      expect(t.ageInDays, 10);
      expect(t.daysAgo, 0, reason: 'stale field is kept but must not be used');
    });

    test('a transaction created now is 0 days old', () {
      expect(txn(createdAtMs: DateTime.now().millisecondsSinceEpoch).ageInDays, 0);
    });

    test('legacy records fall back to the epoch-ms id', () {
      final fiveDaysAgo =
          DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch;
      // Old rows have no createdAtMs; their id was millisecondsSinceEpoch.
      final t = txn(id: fiveDaysAgo, createdAtMs: null, daysAgo: 0);

      expect(t.ageInDays, 5);
    });

    test('a 30-day filter excludes an older transaction', () {
      final old = txn(
        createdAtMs:
            DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch,
      );
      final recent = txn(
        createdAtMs:
            DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      );

      final within = [old, recent].filterInScope(null, 30);

      expect(within, [recent]);
    });

    test('7-day and 30-day windows differ', () {
      final list = [
        txn(id: 1, createdAtMs: DateTime.now().millisecondsSinceEpoch),
        txn(
          id: 2,
          createdAtMs: DateTime.now()
              .subtract(const Duration(days: 20))
              .millisecondsSinceEpoch,
        ),
      ];

      expect(list.filterInScope(null, 7).length, 1);
      expect(list.filterInScope(null, 30).length, 2);
    });
  });

  group('transaction serialization', () {
    test('round-trips the timestamp', () {
      final created =
          DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch;
      final restored = TransactionDef.fromJson(txn(createdAtMs: created).toJson());

      expect(restored.ageInDays, 8);
    });

    // Regression: ExpenseSplit had no toJson/fromJson and TransactionDef.toJson
    // dropped the field entirely, so splits never survived a save.
    test('round-trips an expense split', () {
      final original = TransactionDef(
        id: 99,
        daysAgo: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        title: 'Dinner',
        catKey: 'dining',
        amount: 900,
        type: 'expense',
        memberId: 'me',
        method: 'Card',
        origin: 'manual',
        time: 'Now',
        split: const ExpenseSplit(
          paidByMemberId: 'me',
          splitType: 'equal',
          shares: {'me': 300.0, 'sara': 600.0},
          requiresPayback: true,
        ),
      );

      final restored = TransactionDef.fromJson(original.toJson());

      expect(restored.split, isNotNull);
      expect(restored.split!.paidByMemberId, 'me');
      expect(restored.split!.splitType, 'equal');
      expect(restored.split!.shares['sara'], 600.0);
      expect(restored.split!.requiresPayback, isTrue);
    });

    test('a transaction without a split stays null', () {
      expect(TransactionDef.fromJson(txn().toJson()).split, isNull);
    });
  });
}

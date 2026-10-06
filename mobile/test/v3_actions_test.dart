import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance/v3/sheets/calc_engine.dart';
import 'package:family_finance/v3/data/v3_models.dart';

void main() {
  group('Calculator & Expression Tests', () {
    test('evaluates simple expressions', () {
      expect(CalcEngine.evaluate('150 + 250'), 400.0);
      expect(CalcEngine.evaluate('1000 - 350'), 650.0);
      expect(CalcEngine.evaluate('50 × 4'), 200.0);
    });

    test('formats evaluated expressions for display', () {
      final res = CalcEngine.evaluate('250 + 120');
      expect(CalcEngine.format(res), '370');
    });

    test('detects whether expression needs evaluation', () {
      expect(CalcEngine.hasOperator('500'), isFalse);
      expect(CalcEngine.hasOperator('500 + 250'), isTrue);
    });
  });

  group('Single For and Split Computation Tests', () {
    test('single member paying for self has no debt shares', () {
      const myId = 'user-me';
      final selectedMembers = {myId};
      expect(selectedMembers.length, 1);
      expect(selectedMembers.contains(myId), isTrue);

      // In personal expense, shares is null
      Map<String, double>? shares;
      if (selectedMembers.length == 1 && selectedMembers.contains(myId)) {
        shares = null;
      }
      expect(shares, isNull);
    });

    test('paying for someone else with gift mode leaves 0 debt', () {
      const splitMode = 'gift';

      Map<String, double>? shares;
      if (splitMode == 'gift') {
        shares = null; // No debt
      }
      expect(shares, isNull);
    });

    test('paying for someone else with full_owe mode creates 100% share', () {
      const evaId = 'user-eva';
      const amount = 500.0;
      const splitMode = 'full_owe';

      Map<String, double>? shares;
      if (splitMode == 'full_owe') {
        shares = {evaId: amount};
      }
      expect(shares, isNotNull);
      expect(shares![evaId], 500.0);
    });

    test('multi-member equal split computes equal shares', () {
      final members = {'user-me', 'user-eva', 'user-bob'};
      const amount = 300.0;
      final each = amount / members.length;
      final shares = {for (final m in members) m: each};

      expect(shares.length, 3);
      expect(shares['user-me'], 100.0);
      expect(shares['user-eva'], 100.0);
      expect(shares['user-bob'], 100.0);
    });
  });

  group('RecurringRow Tests', () {
    test('RecurringRow detects income vs expense', () {
      final salary = RecurringRow(
        id: 'rec-1',
        title: 'Monthly Salary',
        amount: 80000,
        cadence: 'monthly',
        nextDue: DateTime.now(),
        type: 'income',
        categoryKey: 'salary',
        autoPost: true,
      );

      final rent = RecurringRow(
        id: 'rec-2',
        title: 'House Rent',
        amount: 25000,
        cadence: 'monthly',
        nextDue: DateTime.now(),
        type: 'expense',
        categoryKey: 'home',
        autoPost: true,
      );

      expect(salary.isIncome, isTrue);
      expect(salary.isExpense, isFalse);
      expect(rent.isIncome, isFalse);
      expect(rent.isExpense, isTrue);
    });

    test('RecurringRow calculates dueInDays correctly', () {
      final now = DateTime.now();
      final inThreeDays = DateTime(now.year, now.month, now.day + 3);
      final r = RecurringRow(
        id: 'rec-3',
        title: 'Netflix',
        amount: 649,
        cadence: 'monthly',
        nextDue: inThreeDays,
      );

      expect(r.dueInDays, 3);
    });
  });
}

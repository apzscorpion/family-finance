import 'package:flutter_test/flutter_test.dart';

import 'package:family_finance/v3/data/expense_import.dart';

void main() {
  group('CSV with a header', () {
    test('reads date, description and amount', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Description,Amount\n'
        '2026-01-03,Coffee,120\n'
        '2026-01-04,Groceries,1240.50\n',
      );

      expect(rows, hasLength(2));
      expect(rows[0].title, 'Coffee');
      expect(rows[0].amount, 120);
      expect(rows[0].date, DateTime(2026, 1, 3));
      expect(rows[0].isIncome, isFalse);
      expect(rows[1].amount, 1240.50);
    });

    test('column order does not matter', () {
      final rows = ExpenseImport.parseCsv(
        'Amount,Narration,Txn Date\n'
        '250,Lunch,2026-02-10\n',
      );

      expect(rows.single.title, 'Lunch');
      expect(rows.single.amount, 250);
      expect(rows.single.date, DateTime(2026, 2, 10));
    });

    test('separate debit and credit columns set the direction', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Particulars,Debit,Credit\n'
        '01/03/2026,Electricity,1800,\n'
        '02/03/2026,Salary,,50000\n',
      );

      expect(rows[0].title, 'Electricity');
      expect(rows[0].isIncome, isFalse);
      expect(rows[1].title, 'Salary');
      expect(rows[1].isIncome, isTrue);
      expect(rows[1].amount, 50000);
    });

    test('a type column marks income', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount,Type\n'
        '2026-01-05,Refund,300,credit\n'
        '2026-01-06,Taxi,150,debit\n',
      );

      expect(rows[0].isIncome, isTrue);
      expect(rows[1].isIncome, isFalse);
    });

    test('carries a category through', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount,Category\n'
        '2026-01-03,Coffee,120,Food\n',
      );

      expect(rows.single.category, 'Food');
    });
  });

  group('messy real-world CSV', () {
    test('quoted fields containing the delimiter stay intact', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Description,Amount\n'
        '2026-01-03,"Coffee, large",120\n',
      );

      expect(rows.single.title, 'Coffee, large');
      expect(rows.single.amount, 120);
    });

    test('escaped double quotes survive', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Description,Amount\n'
        '2026-01-03,"He said ""hi""",120\n',
      );

      expect(rows.single.title, 'He said "hi"');
    });

    test('semicolon files are detected', () {
      final rows = ExpenseImport.parseCsv(
        'Date;Description;Amount\n'
        '2026-01-03;Coffee;120\n',
      );

      expect(rows.single.title, 'Coffee');
      expect(rows.single.amount, 120);
    });

    test('currency symbols and thousands separators are stripped', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '2026-01-03,Rent,"₹12,500.00"\n'
        '2026-01-04,Phone,Rs. 499\n',
      );

      expect(rows[0].amount, 12500.00);
      expect(rows[1].amount, 499);
    });

    test('bracketed and Dr-suffixed amounts are read as spends', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '2026-01-03,Fee,(250)\n'
        '2026-01-04,ATM,1000 Dr\n',
      );

      expect(rows[0].amount, 250);
      expect(rows[0].isIncome, isFalse);
      expect(rows[1].amount, 1000);
    });

    test('rows without a readable amount are skipped, not fatal', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '2026-01-03,Coffee,120\n'
        '2026-01-04,Opening balance,\n'
        '2026-01-05,Tea,80\n',
      );

      expect(rows.map((r) => r.title), ['Coffee', 'Tea']);
    });

    test('blank lines are ignored', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '\n'
        '2026-01-03,Coffee,120\n'
        '\n',
      );

      expect(rows, hasLength(1));
    });
  });

  group('dates', () {
    test('day-first is assumed for ambiguous values', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '03/04/2026,Coffee,120\n',
      );

      expect(rows.single.date, DateTime(2026, 4, 3));
    });

    test('a day above 12 settles the order regardless', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '25/12/2026,Gift,500\n',
      );

      expect(rows.single.date, DateTime(2026, 12, 25));
    });

    test('two-digit years expand', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '03-01-26,Coffee,120\n',
      );

      expect(rows.single.date, DateTime(2026, 1, 3));
    });

    test('named months are read', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '3 Jan 2026,Coffee,120\n',
      );

      expect(rows.single.date, DateTime(2026, 1, 3));
    });

    test('an impossible date is dropped rather than rolled over', () {
      final rows = ExpenseImport.parseCsv(
        'Date,Title,Amount\n'
        '31/02/2026,Coffee,120\n',
      );

      expect(rows.single.date, isNull);
      expect(rows.single.amount, 120);
    });
  });

  group('Markdown', () {
    test('a table is read like a spreadsheet', () {
      final rows = ExpenseImport.parseMarkdown('''
# January

| Date       | Item      | Amount |
|------------|-----------|--------|
| 2026-01-03 | Coffee    | 120    |
| 2026-01-04 | Groceries | 1240   |
''');

      expect(rows, hasLength(2));
      expect(rows[0].title, 'Coffee');
      expect(rows[1].amount, 1240);
    });

    test('bullet lists are read', () {
      final rows = ExpenseImport.parseMarkdown('''
- Coffee 120
- Groceries 1240
* Taxi 300
''');

      expect(rows.map((r) => r.title), ['Coffee', 'Groceries', 'Taxi']);
      expect(rows.map((r) => r.amount), [120, 1240, 300]);
    });

    test('checkbox and numbered items are read', () {
      final rows = ExpenseImport.parseMarkdown('''
- [x] Coffee 120
1. Taxi 300
''');

      expect(rows.map((r) => r.title), ['Coffee', 'Taxi']);
    });

    test('a leading date in a loose line is picked up', () {
      final rows = ExpenseImport.parseMarkdown('- 03/01/2026 Coffee 120');

      expect(rows.single.title, 'Coffee');
      expect(rows.single.date, DateTime(2026, 1, 3));
      expect(rows.single.amount, 120);
    });

    test('a plus sign marks money coming in', () {
      final rows = ExpenseImport.parseMarkdown('- Freelance +5000');

      expect(rows.single.isIncome, isTrue);
      expect(rows.single.amount, 5000);
    });

    test('headings and prose without amounts are ignored', () {
      final rows = ExpenseImport.parseMarkdown('''
# Shopping list
Remember to call the bank
> a quote
- Coffee 120
''');

      expect(rows, hasLength(1));
      expect(rows.single.title, 'Coffee');
    });

    test('rupee amounts in notes are read', () {
      final rows = ExpenseImport.parseMarkdown('- Groceries ₹1,240.50');

      expect(rows.single.amount, 1240.50);
      expect(rows.single.title, 'Groceries');
    });
  });

  group('dispatch', () {
    test('empty input yields nothing', () {
      expect(ExpenseImport.parse(''), isEmpty);
      expect(ExpenseImport.parse('   \n  '), isEmpty);
    });

    test('a note holding a table is parsed as one', () {
      final rows = ExpenseImport.parse('''
| Item   | Amount |
|--------|--------|
| Coffee | 120    |
''', kind: 'txt');

      expect(rows.single.title, 'Coffee');
    });

    test('a note holding plain lines still parses', () {
      final rows = ExpenseImport.parse('Coffee 120\nTaxi 300', kind: 'txt');

      expect(rows.map((r) => r.title), ['Coffee', 'Taxi']);
    });

    test('prose with no amounts yields nothing', () {
      final rows = ExpenseImport.parse(
          'Call the bank about the card\nBuy milk', kind: 'txt');

      expect(rows, isEmpty);
    });
  });
}

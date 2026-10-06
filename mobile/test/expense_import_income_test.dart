import 'package:family_finance/v3/data/expense_import.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for income rows importing as expenses.
///
/// The reported symptom was a sheet whose salary and loan rows never reached
/// the income side, leaving the expense total inflated into lakhs.
void main() {
  group('direction from a category column', () {
    test('salary and loan rows import as income', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Amount
01/04/2026,Monthly salary,Salary,125000
02/04/2026,Groceries,Groceries,4200
03/04/2026,Loan received,Loan,500000
04/04/2026,Electricity,Bills,2300
''');

      expect(rows, hasLength(4));
      expect(
        rows.map((r) => r.isIncome),
        [true, false, true, false],
        reason: 'Salary and Loan are income categories',
      );
      expect(rows[0].amount, 125000);
      expect(rows[2].amount, 500000);
    });

    test('the expense total excludes the income rows', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Amount
01/04/2026,Monthly salary,Salary,125000
02/04/2026,Groceries,Groceries,4200
03/04/2026,Loan received,Loan,500000
''');

      final spend = rows
          .where((r) => !r.isIncome)
          .fold<double>(0, (a, r) => a + r.amount);

      expect(spend, 4200);
    });
  });

  group('direction from the description', () {
    test('an income word in the description counts when there is no category',
        () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Amount
01/04/2026,Salary credited,125000
02/04/2026,Petrol,2000
''');

      expect(rows.map((r) => r.isIncome), [true, false]);
    });

    test('headerless rows use the description', () {
      // Previously `isIncome: amount > 0 && false` made this unreachable.
      final rows = ExpenseImport.parse('Salary 125000\nCoffee 120',
          kind: 'txt');

      expect(rows.map((r) => r.isIncome), [true, false]);
    });
  });

  group('loan cuts both ways', () {
    test('money borrowed is income', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Amount
01/04/2026,Home loan disbursed,Loan,500000
''');

      expect(rows.single.isIncome, isTrue);
    });

    test('a loan EMI or repayment is a spend', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Amount
01/04/2026,Home loan EMI,Loan EMI,18000
02/04/2026,Car loan repayment,Loan repayment,12000
03/04/2026,Loan interest,Loan interest,3000
''');

      expect(rows.map((r) => r.isIncome), [false, false, false]);
    });
  });

  group('explicit signals still win', () {
    test('a type column outranks the category', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Type,Amount
01/04/2026,Salary reversal,Salary,Debit,5000
02/04/2026,Bonus,Bonus,Credit,20000
''');

      expect(rows.map((r) => r.isIncome), [false, true]);
    });

    test('separate debit and credit columns are authoritative', () {
      final rows = ExpenseImport.parseCsv('''
Date,Narration,Debit,Credit
01/04/2026,Salary,,125000
02/04/2026,Groceries,4200,
''');

      expect(rows.map((r) => r.isIncome), [true, false]);
      expect(rows[0].amount, 125000);
      expect(rows[1].amount, 4200);
    });

    test('Dr and Cr abbreviations are understood', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Type,Amount
01/04/2026,Salary,Cr,125000
02/04/2026,Rent,Dr,18000
''');

      expect(rows.map((r) => r.isIncome), [true, false]);
    });
  });

  group('signed amounts', () {
    test('a file using minus signs reads the sign as the direction', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Amount
01/04/2026,Salary,125000
02/04/2026,Groceries,-4200
03/04/2026,Rent,-18000
''');

      expect(rows.map((r) => r.isIncome), [true, false, false]);
      expect(rows[1].amount, 4200, reason: 'amount is stored positive');
    });

    test('an all-positive file is not treated as signed', () {
      // Every row positive means the sheet simply lists spending; it must not
      // be read as "everything is income".
      final rows = ExpenseImport.parseCsv('''
Date,Description,Amount
01/04/2026,Groceries,4200
02/04/2026,Rent,18000
''');

      expect(rows.every((r) => !r.isIncome), isTrue);
    });
  });

  group('column matching', () {
    test('a Description column is not mistaken for a Credit column', () {
      // "description" contains "cr", and the old substring match bound the
      // credit column to it. The debit/credit branch then took over and no
      // row's direction was ever inferred.
      final rows = ExpenseImport.parseCsv('''
Date,Description,Category,Amount
01/04/2026,Monthly salary,Salary,125000
''');

      expect(rows.single.isIncome, isTrue);
      expect(rows.single.amount, 125000);
    });

    test('a Description column is not mistaken for a Debit column', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Amount
01/04/2026,Dinner out,900
''');

      expect(rows.single.amount, 900);
      expect(rows.single.isIncome, isFalse);
    });

    test('real debit and credit columns are still found', () {
      final rows = ExpenseImport.parseCsv('''
Date,Particulars,Debit,Credit
01/04/2026,Salary,,125000
''');

      expect(rows.single.isIncome, isTrue);
    });
  });

  group('words that merely contain an income word', () {
    test('a creditor payment is not income', () {
      final rows = ExpenseImport.parseCsv('''
Date,Description,Amount
01/04/2026,Creditors settlement,5000
''');

      expect(rows.single.isIncome, isFalse,
          reason: 'word boundaries stop "credit" matching "creditors"');
    });
  });
}

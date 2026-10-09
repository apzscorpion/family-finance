import 'package:family_finance/v3/data/expense_import.dart';
import 'package:family_finance/v3/data/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// The user's export: Type column, signed amounts, Memo for the title and a
// Wallet column naming the account.
const walletCsv = '''Date,Type,Category,Amount,Currency,Memo,Wallet
"06/10/2026, 11:43 pm",Expense,Bills,-12200.00,INR,Car Loan,Salary Account
"06/10/2026, 11:41 pm",Expense,Marriage,-3000.00,INR,Photography Advance,Loan Account
"05/10/2026, 1:47 pm",Expense,Others,-147.00,INR,mismatch,Loan Account
"05/10/2026, 1:46 pm",Income,Allowance,1462.00,INR,mismatch,Salary Account
"04/10/2026, 1:15 am",Expense,Marriage,-302400.00,INR,Gold Loan Recovery,Loan Account
''';

const sources = [
  (id: 'sal', name: 'Salary'),
  (id: 'loan', name: 'Loan'),
  (id: 'oth', name: 'Pension & other'),
];

void main() {
  test('wallet export: direction, title, account and time are all read', () {
    final rows = ExpenseImport.parse(walletCsv, kind: 'csv');
    ExpenseImport.route(rows, sources,
        fallbackId: 'oth', expenseHints: PaymentParser.categoryHints);
    expect(rows.length, 5);
    expect(rows.map((r) => r.isIncome), [false, false, false, true, false]);
    expect(rows.map((r) => r.title).toList(),
        ['Car Loan', 'Photography Advance', 'mismatch', 'mismatch', 'Gold Loan Recovery']);
    expect(rows.map((r) => r.sourceId), ['sal', 'loan', 'loan', 'sal', 'loan']);
    expect(rows.first.date, DateTime(2026, 10, 6, 23, 43));
    expect(rows[3].date, DateTime(2026, 10, 5, 13, 46));
  });
}

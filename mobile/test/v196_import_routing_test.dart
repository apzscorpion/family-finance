import 'package:family_finance/v3/data/expense_import.dart';
import 'package:family_finance/v3/data/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const sources = [
  (id: 'sal', name: 'Salary'),
  (id: 'side', name: 'Side business'),
  (id: 'rent', name: 'Rental homes'),
  (id: 'loan', name: 'Loan'),
  (id: 'oth', name: 'Pension & other'),
];

List<ImportedExpense> routed(String csv, {String fallback = 'oth'}) {
  final rows = ExpenseImport.parse(csv, kind: 'csv');
  ExpenseImport.route(rows, sources,
      fallbackId: fallback, expenseHints: PaymentParser.categoryHints);
  return rows;
}

void main() {
  test('salary credit goes to Salary, loan disbursal to Loan, rest to default',
      () {
    final rows = routed('''
Date,Description,Debit,Credit
01/09/2026,SALARY CREDIT ACME LTD,,85000
02/09/2026,Personal loan disbursement,,200000
03/09/2026,Swiggy order,450,
05/09/2026,Home loan EMI,32000,
06/09/2026,Rent received from tenant,,18000
''');
    expect(rows.map((r) => r.isIncome),
        [true, true, false, false, true]);
    expect(rows.map((r) => r.sourceId), ['sal', 'loan', 'oth', 'oth', 'rent']);
    expect(rows.map((r) => r.categoryKey),
        ['salary', 'loan', 'dining', 'bills', 'rentin']);
  });

  test('account column wins over income kind', () {
    final rows = routed('''
Date,Description,Amount,Type,Account
01/09/2026,Salary,85000,credit,HDFC Salary A/c
02/09/2026,Groceries,1200,debit,Salary account
03/09/2026,Loan EMI,9000,debit,Loan
''');
    expect(rows.map((r) => r.sourceId), ['sal', 'sal', 'loan']);
    expect(rows[0].categoryKey, 'salary');
  });

  test('statement preamble names the account for every row', () {
    final rows = routed('''
Account Type: Salary Account
Date,Narration,Withdrawal,Deposit
01/09/2026,Amazon,999,
02/09/2026,NEFT transfer in,,500
''');
    expect(rows.map((r) => r.sourceId), ['sal', 'sal']);
  });

  test('pinned rows keep their account on re-route', () {
    final rows = routed('Date,Description,Amount\n01/09/2026,Coffee,120\n');
    rows.first
      ..sourceId = 'side'
      ..pinned = true;
    ExpenseImport.route(rows, sources, fallbackId: 'sal');
    expect(rows.first.sourceId, 'side');
  });

  test('salary loan is a loan, not pay', () {
    expect(ExpenseImport.incomeKindOf('Loan against salary credited'), 'loan');
    expect(ExpenseImport.incomeKindOf('SAL CR SEP'), 'salary');
    expect(ExpenseImport.accountGroupOf('Pension & other'), 'other');
  });
}

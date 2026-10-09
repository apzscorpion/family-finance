import 'dart:async';
import 'dart:convert';

import 'package:family_finance/v3/data/expense_import.dart';
import 'package:family_finance/v3/data/import_ai.dart';
import 'package:family_finance/v3/data/payment_parser.dart';
import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const accounts = [
  (id: 'sal', name: 'Salary'),
  (id: 'loan', name: 'Loan'),
  (id: 'oth', name: 'Pension & other'),
];

const csv = '''Date,Type,Category,Amount,Memo,Wallet
"06/10/2026, 11:43 pm",Expense,Food,-110.00,Lunch - Meals,Salary Account
"06/10/2026, 11:41 pm",Expense,With Sinu,-380.00,Avil milk,Salary Account
"05/10/2026, 1:46 pm",Expense,Allowance,1462.00,mismatch,Salary Account
"04/10/2026, 1:15 am",Expense,Marriage,-302400.00,Gold Loan Recovery,Loan Account
''';

List<ImportedExpense> parsed() {
  final rows = ExpenseImport.parse(csv, kind: 'csv');
  ExpenseImport.route(rows, accounts,
      fallbackId: 'sal', expenseHints: PaymentParser.categoryHints);
  return rows;
}

class _Repo extends V3Repository {
  _Repo()
      : super(SupabaseClient('https://example.supabase.co', 'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));

  @override
  String? get currentUserId => 'me';

  final added = <Map<String, dynamic>>[];
  final upserted = <Map<String, dynamic>>[];

  @override
  Future<int> addTransactionsBulk(
      {required String familyId,
      required List<Map<String, dynamic>> rows}) async {
    added.addAll(rows);
    return rows.length;
  }

  @override
  Future<int> upsertTransactionsBulk(
      {required String familyId,
      required List<Map<String, dynamic>> rows}) async {
    upserted.addAll(rows);
    return rows.length;
  }
}

void main() {
  test('draft summarises the file by wallet and category', () {
    final review = ImportAi.draft(parsed());
    expect(review.walletCounts, {'Salary Account': 3, 'Loan Account': 1});
    expect(review.wallets['Salary Account'], 'sal');
    expect(review.wallets['Loan Account'], 'loan');
    expect(review.categories['Food'], 'dining');
  });

  test('the model sees accounts, distinct values and rows as data', () {
    final input = jsonDecode(ImportAi.buildInput(parsed(),
        accounts: accounts,
        categories: [(key: 'salary', name: 'Salary', income: true)],
        answers: 'Allowance is my salary')) as Map;
    expect(input['accounts'], ['Salary', 'Loan', 'Pension & other']);
    expect((input['file_categories'] as List).length, 4);
    expect((input['rows'] as List).length, 4);
    expect(input['user_answers'], 'Allowance is my salary');
  });

  test('a reply is applied; invalid names and rows are ignored', () {
    final rows = parsed();
    final review = ImportAi.fromReply({
      'summary': 'Daily spending',
      'wallets': [
        {'wallet': 'Loan Account', 'account': 'Salary'},
        {'wallet': 'Nope', 'account': 'Salary'},
      ],
      'categories': [
        {'category': 'Allowance', 'key': 'salary'},
        {'category': 'With Sinu', 'key': 'made-up'},
      ],
      'type_changes': [
        {'i': 2, 'type': 'income', 'reason': 'Allowance is money in'},
        {'i': 99, 'type': 'income', 'reason': 'out of range'},
      ],
      'questions': ['Is With Sinu dining?'],
    }, ImportAi.draft(rows),
        accounts: accounts, categoryKeys: {'salary', 'dining'}, rowCount: rows.length);

    expect(review.typeChanges.map((c) => c.index), [2]);
    expect(review.questions, ['Is With Sinu dining?']);
    expect(review.wallets.containsKey('Nope'), isFalse);

    ImportAi.apply(review, rows);
    expect(rows[2].isIncome, isTrue);
    expect(rows[2].categoryKey, 'salary');
    expect(rows[3].sourceId, 'sal');
    // Untouched mappings keep each row's own routing.
    expect(rows[0].categoryKey, 'dining');
  });

  test('re-importing corrects earlier imports instead of duplicating', () async {
    final repo = _Repo();
    final state = V3State(repo)
      ..family = const FamilyRow(
          id: 'fam', name: 'F', kind: 'family', inviteCode: 'X', ownerId: 'me')
      ..txns = [
        TxnRow(
          id: 'old-1',
          familyId: 'fam',
          userId: 'me',
          title: 'mismatch',
          amount: 1462,
          type: 'expense',
          origin: 'import',
          occurredAt: DateTime(2026, 10, 5, 9),
        ),
      ];
    final rows = parsed();
    rows[2].isIncome = true;

    final n = await state.importExpenses(rows);
    expect(n, 4);
    expect(state.lastImportUpdated, 1);
    expect(repo.upserted.single['id'], 'old-1');
    expect(repo.upserted.single['type'], 'income');
    expect(repo.added.length, 3);
  });

  test('a call that never answers fails instead of hanging the tap', () async {
    final before = V3Repository.guardTimeout;
    V3Repository.guardTimeout = const Duration(milliseconds: 50);
    final result = await V3Repository.guard<int>(
        'hang', () => Completer<int>().future);
    V3Repository.guardTimeout = before;
    expect(result, isNull);
    expect(V3Repository.offline.value, isTrue);
  });
}

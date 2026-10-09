import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

TxnRow _txn(String id, double amount, {String? sourceId, String origin = 'import'}) =>
    TxnRow(
      id: id,
      familyId: 'fam-1',
      userId: 'user-asif',
      title: id,
      amount: amount,
      type: 'expense',
      origin: origin,
      sourceId: sourceId,
      occurredAt: DateTime.now(),
    );

void main() {
  // The reported bug: imports saved with no account vanished from the
  // dashboard and the Activity list once the Salary filter was on.
  test('transactions with no account count under the main (Salary) account',
      () {
    final state = V3State(V3Repository(SupabaseClient(
      'https://example.supabase.co',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    )));
    state.sources = const [
      SourceRow(id: 'loan', name: 'Loan', kind: 'loan', openingBalance: 0, sortOrder: 0),
      SourceRow(id: 'sal', name: 'Salary', kind: 'income', openingBalance: 1000, sortOrder: 1),
    ];
    state.txns = [
      _txn('old-import', 100),
      _txn('salary-spend', 50, sourceId: 'sal', origin: 'manual'),
      _txn('loan-spend', 30, sourceId: 'loan'),
    ];

    state.srcFilter = 'sal';
    expect(state.scoped.map((t) => t.id), ['old-import', 'salary-spend']);
    expect(state.totalSpent, 150);
    expect(state.balance, 850);

    state.srcFilter = 'loan';
    expect(state.scoped.map((t) => t.id), ['loan-spend']);

    // Activity lists every account regardless of the dashboard filter.
    expect(state.scopedAllAccounts.length, 3);
  });
}

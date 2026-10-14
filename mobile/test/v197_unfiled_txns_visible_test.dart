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

class _Repo extends V3Repository {
  _Repo([this.me = 'user-asif'])
      : super(SupabaseClient(
          'https://example.supabase.co',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final String me;

  @override
  String? get currentUserId => me;
}

void main() {
  // The reported bug: imports saved with no account vanished from the
  // dashboard and the Activity list once the Salary filter was on.
  test('transactions with no account count under the main (Salary) account',
      () {
    final state = V3State(_Repo());
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
    // The dashboard and the Cash & bank sheet agree.
    final w = state.wallet('sal');
    expect(w.cash + w.bank, 850);

    state.srcFilter = 'loan';
    expect(state.scoped.map((t) => t.id), ['loan-spend']);

    // Activity lists every account regardless of the dashboard filter.
    expect(state.scopedAllAccounts.length, 3);
  });

  // The reported bug: another member's income logged with no account
  // landed in this account on the Cash & bank sheet but not the dashboard.
  test("another member's account-less entries stay out of the account", () {
    V3State view(String viewer) {
      final state = V3State(_Repo(viewer));
      state.sources = const [
        SourceRow(id: 'sal', name: 'Salary', kind: 'income', openingBalance: 0, sortOrder: 0),
      ];
      state.txns = [
        TxnRow(id: 'mine', familyId: 'fam-1', userId: 'user-asif', title: 'Pay',
            amount: 7938, type: 'income', occurredAt: DateTime.now()),
        TxnRow(id: 'theirs', familyId: 'fam-1', userId: 'user-sinu', title: 'Gift',
            amount: 1900, type: 'income', occurredAt: DateTime.now()),
        TxnRow(id: 'their-spend', familyId: 'fam-1', userId: 'user-sinu',
            title: 'Snack', amount: 45, type: 'expense', sourceId: 'sal',
            occurredAt: DateTime.now()),
      ];
      state.srcFilter = 'sal';
      state.scope = 'user-asif';
      return state;
    }

    final mine = view('user-asif');
    final w = mine.wallet('sal');
    expect(w.cash + w.bank, 7893); // explicit charges still count
    expect(mine.balance, 7893);
    // The reported bug: Sinu viewing Asif saw his account-less pay vanish.
    expect(view('user-sinu').balance, 7893);
    // The family view holds everyone's.
    expect((view('user-sinu')..scope = 'family').balance, 9793);
  });

}

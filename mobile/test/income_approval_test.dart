import 'package:family_finance/v3/data/v3_models.dart';
import 'package:family_finance/v3/data/v3_repository.dart';
import 'package:family_finance/v3/v3_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repo extends V3Repository {
  _Repo(this.me)
      : super(SupabaseClient('https://example.supabase.co', 'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final String me;
  @override
  String? get currentUserId => me;
}

TxnRow _income(String id, String status, {String user = 'b', String by = 'a'}) =>
    TxnRow(
      id: id,
      familyId: 'f',
      userId: user,
      addedBy: by,
      title: 'Pocket money',
      amount: 500,
      type: 'income',
      status: status,
      occurredAt: DateTime.now(),
    );

void main() {
  test('pending and rejected income are requests, never in balances', () {
    final rows = [
      _income('p', 'pending'),
      _income('r', 'rejected'),
      _income('ok', 'posted', by: 'b'),
    ];
    final b = V3State(_Repo('b'))
      ..txns = [for (final t in rows) if (t.isPosted) t]
      ..incomeRequests = [for (final t in rows) if (!t.isPosted) t]
      ..scope = 'b';
    expect(b.totalIncome, 500);
    expect(b.incomeForMe.map((t) => t.id), ['p']);
    expect(b.incomeIRejected.map((t) => t.id), ['r']);
    expect(b.attentionCount, 1);

    final a = V3State(_Repo('a'))..incomeRequests = b.incomeRequests;
    expect(a.incomeISent.map((t) => t.id), ['p', 'r']);
    expect(a.incomeForMe, isEmpty);
  });

  test('status comes from the server row', () {
    final t = TxnRow.fromJson({
      'id': '1',
      'family_id': 'f',
      'user_id': 'b',
      'added_by': 'a',
      'amount': 5,
      'type': 'income',
      'status': 'pending',
      'occurred_at': DateTime.now().toIso8601String(),
    });
    expect(t.isPosted, isFalse);
    expect(t.addedBy, 'a');
    expect(TxnRow.fromJson({'id': '2', 'family_id': 'f', 'amount': 1}).isPosted,
        isTrue);
  });
}

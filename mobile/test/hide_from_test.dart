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

V3State _view(String viewer, String viewerRole) => V3State(_Repo(viewer))
  ..members = [
    MemberRow(userId: viewer, name: 'V', role: viewerRole, status: 'active',
        relationship: '', hue: 0),
    const MemberRow(userId: 'a', name: 'A', role: 'member', status: 'active',
        relationship: '', hue: 0, hiddenFrom: ['b']),
  ]
  ..scope = 'a';

void main() {
  test('hidden only from the people A picked; owners always see', () {
    expect(_view('b', 'member').scopePrivate, isTrue);
    expect(_view('c', 'member').scopePrivate, isFalse);
    expect(_view('b', 'owner').scopePrivate, isFalse);
    expect((_view('b', 'member')..scope = 'family').scopePrivate, isFalse);
  });

  test('hidden_from is read from the membership row', () {
    final m = MemberRow.fromJson({
      'user_id': 'a',
      'hidden_from': ['b', 'c'],
    });
    expect(m.hiddenFrom, ['b', 'c']);
    expect(MemberRow.fromJson({'user_id': 'x'}).hiddenFrom, isEmpty);
  });
}

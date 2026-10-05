import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance/services/supabase_service.dart';

void main() {
  group('LocalAccountRecord password storage', () {
    LocalAccountRecord make(String password) => LocalAccountRecord.withPassword(
          email: 'user@example.com',
          password: password,
          fullName: 'User',
          familyName: 'Family',
          familyCode: 'ABCD1234',
        );

    // Regression: the password was stored as plaintext in SharedPreferences.
    test('never stores the plaintext password', () {
      final record = make('hunter2');
      final serialized = record.toJson().toString();

      expect(serialized.contains('hunter2'), isFalse);
      expect(record.passwordHash.isNotEmpty, isTrue);
      expect(record.passwordSalt.isNotEmpty, isTrue);
    });

    test('verifies the correct password and rejects others', () {
      final record = make('hunter2');

      expect(record.verifyPassword('hunter2'), isTrue);
      expect(record.verifyPassword('Hunter2'), isFalse);
      expect(record.verifyPassword('wrong'), isFalse);
      expect(record.verifyPassword(''), isFalse);
    });

    test('salts so identical passwords hash differently', () {
      expect(make('samepass').passwordHash, isNot(make('samepass').passwordHash));
    });

    test('survives a save/load round-trip', () {
      final restored = LocalAccountRecord.fromJson(make('hunter2').toJson());

      expect(restored.verifyPassword('hunter2'), isTrue);
      expect(restored.verifyPassword('nope'), isFalse);
    });

    test('migrates a legacy plaintext record and drops the plaintext', () {
      final legacy = {
        'email': 'old@example.com',
        'password': 'oldsecret',
        'fullName': 'Old',
        'familyName': 'Family',
        'familyCode': 'ABCD1234',
        'isOwner': true,
        'joinedGroups': <dynamic>[],
      };

      final migrated = LocalAccountRecord.fromJson(legacy);

      expect(migrated.verifyPassword('oldsecret'), isTrue);
      expect(migrated.toJson().toString().contains('oldsecret'), isFalse);
    });

    test('an account with no password cannot be verified against', () {
      final record = make('');

      expect(record.hasPassword, isFalse);
      expect(record.verifyPassword(''), isFalse);
      expect(record.verifyPassword('anything'), isFalse);
    });
  });

  group('owner family code derivation', () {
    // Regression: this matched substrings, so any user whose email or display
    // name merely contained "asif" was routed into one specific person's
    // family workspace.
    test('does not capture unrelated users by substring', () {
      final stranger =
          SupabaseService.deriveDeterministicOwnerCode('asif.khan@elsewhere.com');
      final other = SupabaseService.deriveDeterministicOwnerCode(
        'someone@example.com',
        fullName: 'Asif Khan',
      );

      expect(stranger, isNot('NTY5AFLR'));
      expect(other, isNot('NTY5AFLR'));
    });

    test('is stable for the same identifier', () {
      expect(
        SupabaseService.deriveDeterministicOwnerCode('person@example.com'),
        SupabaseService.deriveDeterministicOwnerCode('person@example.com'),
      );
    });

    // Regression: the old LCG-based derivation emitted only 32 distinct codes
    // in total, so unrelated users were routed into the same family workspace.
    test('spreads across the full code space', () {
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        seen.add(SupabaseService.deriveDeterministicOwnerCode('user$i@example.com'));
      }
      expect(seen.length, greaterThan(4990),
          reason: 'got ${seen.length} distinct codes for 5000 emails');
    });

    test('two specific emails that used to collide no longer do', () {
      expect(
        SupabaseService.deriveDeterministicOwnerCode('neverregistered8899@example.com'),
        isNot(SupabaseService.deriveDeterministicOwnerCode('asifmuhammed1998@gmail.com')),
      );
    });

    test('differs between different identifiers', () {
      expect(
        SupabaseService.deriveDeterministicOwnerCode('a@example.com'),
        isNot(SupabaseService.deriveDeterministicOwnerCode('b@example.com')),
      );
    });
  });
}

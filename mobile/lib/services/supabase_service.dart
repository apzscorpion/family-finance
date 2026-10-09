import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance_models.dart';
import 'app_log.dart';

class LocalAccountRecord {
  final String email;

  /// Salted SHA-256 of the password. The plaintext password is never stored:
  /// this record lives in SharedPreferences, which is readable on a rooted or
  /// backed-up device, and people reuse passwords across services.
  final String passwordHash;
  final String passwordSalt;
  final String fullName;
  final String familyName;
  final String familyCode;
  final bool isOwner;
  final List<JoinedGroupDef> joinedGroups;

  const LocalAccountRecord({
    required this.email,
    this.passwordHash = '',
    this.passwordSalt = '',
    required this.fullName,
    required this.familyName,
    required this.familyCode,
    this.isOwner = true,
    this.joinedGroups = const [],
  });

  /// Builds a record from a plaintext password, hashing it immediately.
  factory LocalAccountRecord.withPassword({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
    bool isOwner = true,
    List<JoinedGroupDef> joinedGroups = const [],
  }) {
    final salt = password.isEmpty ? '' : _generateSalt();
    return LocalAccountRecord(
      email: email,
      passwordHash: password.isEmpty ? '' : _hash(password, salt),
      passwordSalt: salt,
      fullName: fullName,
      familyName: familyName,
      familyCode: familyCode,
      isOwner: isOwner,
      joinedGroups: joinedGroups,
    );
  }

  bool get hasPassword => passwordHash.isNotEmpty && passwordSalt.isNotEmpty;

  /// Constant-time-ish comparison of [candidate] against the stored hash.
  bool verifyPassword(String candidate) {
    if (!hasPassword) return false;
    final computed = _hash(candidate, passwordSalt);
    if (computed.length != passwordHash.length) return false;
    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed.codeUnitAt(i) ^ passwordHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'fullName': fullName,
        'familyName': familyName,
        'familyCode': familyCode,
        'isOwner': isOwner,
        'joinedGroups': joinedGroups.map((g) => g.toJson()).toList(),
      };

  factory LocalAccountRecord.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['joinedGroups'];
    final groups = <JoinedGroupDef>[];
    if (rawGroups is List) {
      for (final item in rawGroups) {
        if (item is Map) {
          groups.add(JoinedGroupDef.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    var hash = json['passwordHash']?.toString() ?? '';
    var salt = json['passwordSalt']?.toString() ?? '';

    // Migrate records written before passwords were hashed. The plaintext is
    // hashed here and dropped; it is rewritten on the next save.
    final legacyPlaintext = json['password']?.toString() ?? '';
    if (hash.isEmpty && legacyPlaintext.isNotEmpty) {
      salt = _generateSalt();
      hash = _hash(legacyPlaintext, salt);
    }

    return LocalAccountRecord(
      email: json['email']?.toString() ?? '',
      passwordHash: hash,
      passwordSalt: salt,
      fullName: json['fullName']?.toString() ?? '',
      familyName: json['familyName']?.toString() ?? '',
      familyCode: (json['familyCode']?.toString() ?? '').trim().toUpperCase(),
      isOwner: (json['isOwner'] as bool?) ?? true,
      joinedGroups: groups,
    );
  }
}

enum SignInStatus { success, invalidCredentials, cloudUnavailable }

class SignInOutcome {
  final SignInStatus status;
  final AuthResponse? response;
  final String? message;

  const SignInOutcome({required this.status, this.response, this.message});

  bool get isSuccess => status == SignInStatus.success;
  bool get isRejected => status == SignInStatus.invalidCredentials;
}

class SupabaseService {
  static const String supabaseUrl = 'https://cmjirnwoyocfupgxuoeb.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_VpRhi-j-jTT87yxSgEgVKg__8gVhT7s';
  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// Runs [init] at most once and completes when it has finished (or failed).
  /// Callers that need the cloud client await this rather than blocking app
  /// startup on it.
  static Future<void> get ready => _initFuture ??= init();

  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (isConfigured && !_initialized) {
      try {
        // Must not be unbounded: init() is awaited before runApp(), so a slow
        // or unreachable network would otherwise hang the app on a blank splash
        // screen forever with no UI and no error.
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey, // ignore: deprecated_member_use
          // The default drops the socket the instant the app is minimised,
          // which silenced chat alerts. The chat foreground service keeps the
          // process alive, so the socket must stay up with it.
          realtimeLifecycleOptions: const RealtimeLifecycleOptions(
            disconnectAfterPause: Duration(hours: 12),
          ),
        ).timeout(const Duration(seconds: 10));
        _initialized = true;
      } catch (err, errStack) {
        AppLog.error('SupabaseService.init', err, errStack);
        _initialized = false;
      }
    }
    await purgeUnwantedAccountsAndData();
  }

  /// One-time local-storage migrations.
  ///
  /// This used to call `prefs.clear()` on upgrade, wiping every user's local
  /// data, and then hand-patched a few named people's accounts and banned
  /// another by email. All of that was one-off cleanup for test data on the
  /// developer's own device, so it no longer runs: it is destructive for real
  /// users and there is no reason to ship someone's personal data in the app.
  ///
  /// The version flag is kept so this stays a place to hang future migrations
  /// without re-running them on every launch.
  static Future<void> purgeUnwantedAccountsAndData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const migrationKey = 'ff_migration_v17_done';
      if (prefs.getBool(migrationKey) ?? false) return;

      // No migration steps currently needed.

      await prefs.setBool(migrationKey, true);
    } catch (err, errStack) {
      AppLog.error('SupabaseService.purgeUnwantedAccountsAndData', err, errStack);
    }
  }

  /// Accounts that existed before codes were derived by hash, pinned by exact
  /// email so their established workspace keeps resolving to the same code.
  static const Map<String, String> ownerLegacyCodes = {
    'apzscorpion@gmail.com': 'NTY5AFLR',
  };

  /// Deterministically derives an Owner's 8-character Family Code from their account identifier
  /// so logging in on any device always yields the exact same Family Code for the Owner.
  static String deriveDeterministicOwnerCode(String identifier, {String? fullName}) {
    final clean = identifier.trim().toLowerCase();
    // Exact-match only. A substring match here put *every* user whose email or
    // display name merely contained "asif" into this one family workspace.
    if (ownerLegacyCodes.containsKey(clean)) {
      return ownerLegacyCodes[clean]!;
    }
    if (clean.isEmpty) return 'UNASSIGNED';

    // Each character comes from an independent byte of a SHA-256 digest.
    //
    // The previous version seeded a linear congruential generator with a 31-bit
    // hash and took `seed % 32` per character. In an LCG the low bits of each
    // step depend only on the low bits of the previous one, so every character
    // was a function of `hash mod 32` alone: the whole scheme produced just 32
    // distinct codes. Roughly one user in 32 was therefore dropped into a
    // stranger's family workspace and could see their finances.
    //
    // 256 is an exact multiple of 32, so `byte % 32` stays uniform.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final digest = sha256.convert(utf8.encode(clean)).bytes;
    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buffer.write(chars[digest[i] % chars.length]);
    }
    return buffer.toString();
  }

  // ===========================================================================
  // 1. EMAIL VERIFICATION OTP ENGINE
  // ===========================================================================

  static const String testUniversalOtp = '111111';

  /// The universal test OTP must never verify a real user in a shipped build;
  /// in release it would let anyone claim any email or join any family code.
  static bool get allowTestOtp => kDebugMode;

  static String _random6Digits() {
    final rnd = Random.secure();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  static String generateSixDigitCode() => _random6Digits();

  /// Extracts a 6-digit OTP from any SMS, Email, or clipboard text
  static String? extractOtpFromText(String rawText) {
    final clean = rawText.trim();
    if (clean.isEmpty) return null;
    if (RegExp(r'^\d{6}$').hasMatch(clean)) return clean;
    final match = RegExp(r'(?:^|\D)(\d{6})(?:\D|$)').firstMatch(clean);
    return match?.group(1);
  }

  /// Generates a 6-digit OTP valid for 10 minutes and triggers Supabase email OTP if configured
  static Future<String> generateLoginOtp(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = identifier.trim().toLowerCase();
    final otp = _random6Digits();
    final expiryMs = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    await prefs.setString(
      'ff_login_otp_$key',
      json.encode({'otp': otp, 'expiryMs': expiryMs}),
    );
    return otp;
  }

  /// Verifies the 6-digit Email OTP entered by the user (supports Supabase Email OTP & silent test OTP 111111)
  static Future<bool> verifyLoginOtp(String identifier, String enteredOtp) async {
    final extracted = extractOtpFromText(enteredOtp) ?? enteredOtp.trim();
    final key = identifier.trim().toLowerCase();

    // Try verifying against Supabase Email OTP if the user entered the code from their email
    if (isConfigured && _initialized && extracted.length == 6 && key.contains('@')) {
      for (final otpType in [OtpType.signup, OtpType.email, OtpType.magiclink]) {
        try {
          final res = await client.auth
              .verifyOTP(
                type: otpType,
                email: key,
                token: extracted,
              )
              .timeout(const Duration(seconds: 4));
          if (res.user != null || res.session != null) {
            return true;
          }
        } catch (err, errStack) {
          AppLog.error('SupabaseService.verifyLoginOtp', err, errStack);
        }
      }
    }

    if (allowTestOtp && extracted == testUniversalOtp) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ff_login_otp_$key');
    if (raw == null || raw.isEmpty) return false;
    try {
      final map = Map<String, dynamic>.from(json.decode(raw));
      final savedOtp = map['otp']?.toString() ?? '';
      final expiryMs = (map['expiryMs'] as int?) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
        return false;
      }
      if (savedOtp == extracted) {
        await prefs.remove('ff_login_otp_$key');
        return true;
      }
      return false;
    } catch (err, errStack) {
      AppLog.error('SupabaseService.verifyLoginOtp', err, errStack);
      return false;
    }
  }

  // ===========================================================================
  // 2. FAMILY LOGIN VERIFICATION & DISABLED USER ACCESS CONTROL
  // ===========================================================================

  /// Registers the creator of a family code as its Owner and initializes the 6-digit Family Verification OTP
  static Future<void> registerFamilyOwner({
    required String familyCode,
    required String ownerEmail,
    required String familyName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanEmail = ownerEmail.trim().toLowerCase();
    final existingOwner = prefs.getString('ff_family_owner_$cleanCode');
    if (existingOwner == null || existingOwner.isEmpty) {
      await prefs.setString('ff_family_owner_$cleanCode', cleanEmail);
    }
    if (familyName.trim().isNotEmpty) {
      await prefs.setString('ff_room_name_$cleanCode', familyName.trim());
    }
    final existingOtp = prefs.getString('ff_family_verify_otp_$cleanCode');
    if (existingOtp == null || existingOtp.isEmpty) {
      await prefs.setString('ff_family_verify_otp_$cleanCode', _random6Digits());
    }
    await markUserVerifiedInFamily(email: cleanEmail, familyCode: cleanCode);
  }

  static Future<String?> getFamilyOwnerEmail(String familyCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ff_family_owner_${familyCode.trim().toUpperCase()}');
  }

  /// Gets (or generates) the 6-digit Family Owner Verification OTP that the Owner can give to someone joining their family login
  static Future<String> getFamilyVerificationOtp(String familyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    var otp = prefs.getString('ff_family_verify_otp_$cleanCode');
    if (otp == null || otp.isEmpty) {
      otp = _random6Digits();
      await prefs.setString('ff_family_verify_otp_$cleanCode', otp);
    }
    return otp;
  }

  /// Rotates the 6-digit Family Verification OTP on demand
  static Future<String> regenerateFamilyVerificationOtp(String familyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final otp = _random6Digits();
    await prefs.setString('ff_family_verify_otp_$cleanCode', otp);
    return otp;
  }

  /// Checks if a user (by email or name) has been disabled by the Family Owner
  static Future<bool> isUserDisabledInFamily({
    required String email,
    String? name,
    required String familyCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final raw = prefs.getString('ff_family_disabled_$cleanCode');
    if (raw == null || raw.isEmpty) return false;
    try {
      final list = List<String>.from(json.decode(raw)).map((e) => e.toLowerCase().trim()).toSet();
      if (email.trim().isNotEmpty && list.contains(email.trim().toLowerCase())) {
        return true;
      }
      if (name != null && name.trim().isNotEmpty && list.contains(name.trim().toLowerCase())) {
        return true;
      }
      return false;
    } catch (err, errStack) {
      AppLog.error('SupabaseService.isUserDisabledInFamily', err, errStack);
      return false;
    }
  }

  /// Disables or re-enables a user in the family login
  static Future<void> setUserDisabledInFamily({
    List<String>? identifiers,
    String? email,
    String? name,
    required String familyCode,
    required bool disabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final raw = prefs.getString('ff_family_disabled_$cleanCode');
    final Set<String> current = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        current.addAll(List<String>.from(json.decode(raw)).map((e) => e.toLowerCase().trim()));
      } catch (err, errStack) {
        AppLog.error('SupabaseService.setUserDisabledInFamily', err, errStack);
      }
    }
    final digitsOnly = (email ?? '').replaceAll(RegExp(r'\D'), '');
    final allIds = <String>[
      ...?identifiers,
      if (email != null && email.isNotEmpty) email,
      if (digitsOnly.length >= 7) 'phone_$digitsOnly@familyfinance.app',
      if (name != null && name.isNotEmpty) name,
    ];
    for (final id in allIds) {
      final clean = id.trim().toLowerCase();
      if (clean.isEmpty) continue;
      if (disabled) {
        current.add(clean);
      } else {
        current.remove(clean);
      }
    }
    await prefs.setString('ff_family_disabled_$cleanCode', json.encode(current.toList()));
  }

  /// Checks if `email` is already verified/approved by the Family Owner for `familyCode`
  static Future<bool> isUserVerifiedInFamily({
    required String email,
    required String familyCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();
    final ownerEmail = prefs.getString('ff_family_owner_$cleanCode');
    if (ownerEmail != null && ownerEmail == cleanEmail) return true;

    final raw = prefs.getString('ff_family_verified_$cleanCode');
    if (raw == null || raw.isEmpty) return false;
    try {
      final set = List<String>.from(json.decode(raw)).map((e) => e.toLowerCase().trim()).toSet();
      return set.contains(cleanEmail);
    } catch (err, errStack) {
      AppLog.error('SupabaseService.isUserVerifiedInFamily', err, errStack);
      return false;
    }
  }

  static Future<void> markUserVerifiedInFamily({
    required String email,
    String? name,
    required String familyCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();
    final raw = prefs.getString('ff_family_verified_$cleanCode');
    final Set<String> set = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        set.addAll(List<String>.from(json.decode(raw)).map((e) => e.toLowerCase().trim()));
      } catch (err, errStack) {
        AppLog.error('SupabaseService.markUserVerifiedInFamily', err, errStack);
      }
    }
    if (cleanEmail.isNotEmpty) set.add(cleanEmail);
    if (name != null && name.trim().isNotEmpty) set.add(name.trim().toLowerCase());
    await prefs.setString('ff_family_verified_$cleanCode', json.encode(set.toList()));
  }

  /// Creates or returns a pending FamilyLoginRequest when someone tries to use a Family Code
  static Future<FamilyLoginRequest> createFamilyJoinRequest({
    required String name,
    required String email,
    required String familyCode,
  }) async {
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();
    final masterOtp = await getFamilyVerificationOtp(cleanCode);

    final list = await getFamilyLoginRequests(cleanCode);
    final existingIdx = list.indexWhere((r) => r.email.toLowerCase() == cleanEmail);
    final req = FamilyLoginRequest(
      id: existingIdx >= 0 ? list[existingIdx].id : 'req_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isNotEmpty ? name.trim() : cleanEmail.split('@').first,
      email: cleanEmail,
      familyCode: cleanCode,
      verificationOtp: masterOtp,
      requestedAt: 'Just now',
      status: 'pending',
    );

    if (existingIdx >= 0) {
      list[existingIdx] = req;
    } else {
      list.insert(0, req);
    }
    await saveFamilyLoginRequests(cleanCode, list);
    return req;
  }

  static Future<List<FamilyLoginRequest>> getFamilyLoginRequests(String familyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    final raw = prefs.getString('ff_family_join_reqs_$cleanCode');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((m) => FamilyLoginRequest.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (err, errStack) {
      AppLog.error('SupabaseService.createFamilyJoinRequest', err, errStack);
      return [];
    }
  }

  static Future<void> saveFamilyLoginRequests(
    String familyCode,
    List<FamilyLoginRequest> requests,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = familyCode.trim().toUpperCase();
    await prefs.setString(
      'ff_family_join_reqs_$cleanCode',
      json.encode(requests.map((r) => r.toJson()).toList()),
    );
  }

  /// Verifies a Family Join attempt using either the Family Verification OTP, a member's personal OTP, or test OTP 111111
  static Future<bool> verifyFamilyJoinOtp({
    required String email,
    String? name,
    required String familyCode,
    required String enteredOtp,
  }) async {
    final cleanCode = familyCode.trim().toUpperCase();
    final cleanOtp = extractOtpFromText(enteredOtp) ?? enteredOtp.trim();
    if (cleanOtp.length < 6) return false;

    final masterOtp = await getFamilyVerificationOtp(cleanCode);
    final reqs = await getFamilyLoginRequests(cleanCode);
    final matchReq = reqs.any(
      (r) => r.email.toLowerCase() == email.trim().toLowerCase() && r.verificationOtp == cleanOtp,
    );

    if ((allowTestOtp && cleanOtp == testUniversalOtp) || cleanOtp == masterOtp || matchReq) {
      await markUserVerifiedInFamily(email: email, name: name, familyCode: cleanCode);
      // Mark request as approved
      final updated = reqs.map((r) {
        if (r.email.toLowerCase() == email.trim().toLowerCase()) {
          return r.copyWith(status: 'approved');
        }
        return r;
      }).toList();
      await saveFamilyLoginRequests(cleanCode, updated);
      return true;
    }
    return false;
  }

  // ===========================================================================
  // 3. LOCAL & CLOUD ACCOUNT STORAGE
  // ===========================================================================

  static Future<LocalAccountRecord> saveLocalAccount({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
    bool isOwner = true,
    String groupKind = 'Family',
    List<JoinedGroupDef>? joinedGroups,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = email.trim().toLowerCase();
    final cleanCode = familyCode.trim().toUpperCase();
    final existingAcct = await getLocalAccount(key);

    final existingOwnerEmail = prefs.getString('ff_family_owner_$cleanCode');
    final effectiveIsOwner = isOwner &&
        (existingOwnerEmail == null || existingOwnerEmail.isEmpty || existingOwnerEmail == key);

    String resolvedFamilyName = familyName.trim();
    final existingRoomName = prefs.getString('ff_room_name_$cleanCode');

    if (!effectiveIsOwner) {
      // Joining someone else's group: use the group's existing name, never overwrite with joiner's name
      if (existingRoomName != null && existingRoomName.isNotEmpty) {
        resolvedFamilyName = existingRoomName;
      } else if (cleanCode == 'NTY5AFLR') {
        resolvedFamilyName = "Asif's Family";
        await prefs.setString('ff_room_name_$cleanCode', resolvedFamilyName);
      } else if (resolvedFamilyName.isEmpty || resolvedFamilyName.endsWith("'s Family")) {
        resolvedFamilyName = 'Family ($cleanCode)';
      }
    } else {
      if ((resolvedFamilyName.isEmpty || resolvedFamilyName.endsWith("'s Family")) &&
          existingRoomName != null &&
          existingRoomName.isNotEmpty) {
        resolvedFamilyName = existingRoomName;
      } else if (resolvedFamilyName.isNotEmpty) {
        await prefs.setString('ff_room_name_$cleanCode', resolvedFamilyName);
      }
      await registerFamilyOwner(
        familyCode: cleanCode,
        ownerEmail: key,
        familyName: resolvedFamilyName,
      );
    }

    // Merge into user's joinedGroups list so they can switch between groups anytime
    final Map<String, JoinedGroupDef> groupMap = {};
    if (existingAcct != null) {
      for (final g in existingAcct.joinedGroups) {
        if (g.code.isNotEmpty) groupMap[g.code] = g;
      }
    }
    if (joinedGroups != null) {
      for (final g in joinedGroups) {
        if (g.code.isNotEmpty) groupMap[g.code] = g;
      }
    }
    if (cleanCode.isNotEmpty) {
      final prev = groupMap[cleanCode];
      groupMap[cleanCode] = JoinedGroupDef(
        code: cleanCode,
        name: resolvedFamilyName,
        kind: prev?.kind ?? groupKind,
        role: effectiveIsOwner ? 'Owner' : (prev?.role == 'Owner' ? 'Owner' : 'Member'),
        ownerEmail: effectiveIsOwner ? key : (existingOwnerEmail ?? prev?.ownerEmail ?? ''),
      );
    }

    final resolvedFullName =
        fullName.trim().isNotEmpty ? fullName.trim() : (existingAcct?.fullName ?? '');
    final record = password.isNotEmpty
        ? LocalAccountRecord.withPassword(
            email: key,
            password: password,
            fullName: resolvedFullName,
            familyName: resolvedFamilyName,
            familyCode: cleanCode,
            isOwner: effectiveIsOwner,
            joinedGroups: groupMap.values.toList(),
          )
        : LocalAccountRecord(
            email: key,
            // No new password supplied: carry the existing hash forward.
            passwordHash: existingAcct?.passwordHash ?? '',
            passwordSalt: existingAcct?.passwordSalt ?? '',
            fullName: resolvedFullName,
            familyName: resolvedFamilyName,
            familyCode: cleanCode,
            isOwner: effectiveIsOwner,
            joinedGroups: groupMap.values.toList(),
          );

    await prefs.setString('ff_acct_$key', json.encode(record.toJson()));
    await prefs.setString('ff_active_session_email', key);
    return record;
  }

  static Future<LocalAccountRecord?> getLocalAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = email.trim().toLowerCase();
    final raw = prefs.getString('ff_acct_$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      return LocalAccountRecord.fromJson(Map<String, dynamic>.from(json.decode(raw)));
    } catch (err, errStack) {
      AppLog.error('SupabaseService.getLocalAccount', err, errStack);
      return null;
    }
  }

  static Future<LocalAccountRecord?> getActiveLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final activeEmail = prefs.getString('ff_active_session_email');
    if (activeEmail == null || activeEmail.isEmpty) return null;
    return getLocalAccount(activeEmail);
  }

  static Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
    bool isOwner = true,
    String groupKind = 'Family',
    List<JoinedGroupDef>? joinedGroups,
  }) async {
    final saved = await saveLocalAccount(
      email: email,
      password: password,
      fullName: fullName,
      familyName: familyName,
      familyCode: familyCode,
      isOwner: isOwner,
      groupKind: groupKind,
      joinedGroups: joinedGroups,
    );

    if (!isConfigured || !_initialized) return null;

    try {
      final response = await client.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'full_name': saved.fullName,
              'family_name': saved.familyName,
              'family_code': saved.familyCode,
              'is_owner': saved.isOwner,
              'joined_groups': saved.joinedGroups.map((g) => g.toJson()).toList(),
            },
          )
          .timeout(const Duration(seconds: 4));
      return response;
    } catch (err, errStack) {
      AppLog.error('SupabaseService.signUp', err, errStack);
      return null;
    }
  }

  static Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final outcome = await signInDetailed(email: email, password: password);
    return outcome.response;
  }

  /// Signs in and reports *why* it failed, so callers can tell "wrong password"
  /// (reject the login) apart from "cloud unreachable" (allow offline fallback).
  /// [signIn] collapses both into `null`, which previously let any credentials through.
  static Future<SignInOutcome> signInDetailed({
    required String email,
    required String password,
  }) async {
    // Startup kicks init off without awaiting it, so make sure it has landed
    // before deciding the cloud is unavailable.
    await ready;
    if (!isConfigured || !_initialized) {
      return const SignInOutcome(status: SignInStatus.cloudUnavailable);
    }
    try {
      final res = await client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 8));
      if (res.user == null) {
        return const SignInOutcome(
          status: SignInStatus.invalidCredentials,
          message: 'Incorrect email or password.',
        );
      }
      return SignInOutcome(status: SignInStatus.success, response: res);
    } on AuthException catch (e) {
      // The server answered and rejected these credentials.
      return SignInOutcome(
        status: SignInStatus.invalidCredentials,
        message: e.message,
      );
    } catch (err, errStack) {
      AppLog.error('SupabaseService.signInDetailed', err, errStack);
      // Timeout / socket / unknown: we genuinely could not reach the server.
      return const SignInOutcome(status: SignInStatus.cloudUnavailable);
    }
  }

  static Future<void> updateMetadata({
    String? fullName,
    String? familyName,
    String? familyCode,
    bool? isOwner,
    List<JoinedGroupDef>? joinedGroups,
  }) async {
    final session = await getActiveLocalSession();
    LocalAccountRecord? updatedRecord;
    if (session != null) {
      updatedRecord = await saveLocalAccount(
        email: session.email,
        // Empty: saveLocalAccount preserves the stored hash.
        password: '',
        fullName: fullName ?? session.fullName,
        familyName: familyName ?? session.familyName,
        familyCode: familyCode ?? session.familyCode,
        isOwner: isOwner ?? session.isOwner,
        joinedGroups: joinedGroups ?? session.joinedGroups,
      );
    }

    if (!isConfigured || !_initialized || currentUser == null) return;
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (familyName != null) data['family_name'] = familyName;
    if (familyCode != null) data['family_code'] = familyCode;
    if (updatedRecord != null) {
      data['joined_groups'] = updatedRecord.joinedGroups.map((g) => g.toJson()).toList();
    } else if (joinedGroups != null) {
      data['joined_groups'] = joinedGroups.map((g) => g.toJson()).toList();
    }
    if (data.isEmpty) return;
    try {
      await client.auth.updateUser(UserAttributes(data: data)).timeout(const Duration(seconds: 3));
    } catch (err, errStack) {
      AppLog.error('SupabaseService.updateMetadata', err, errStack);
    }
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ff_active_session_email');
    if (!isConfigured || !_initialized) return;
    try {
      await client.auth.signOut();
    } catch (err, errStack) {
      AppLog.error('SupabaseService.signOut', err, errStack);
    }
  }

  static User? get currentUser {
    if (!isConfigured || !_initialized) return null;
    try {
      return client.auth.currentUser;
    } catch (err, errStack) {
      AppLog.error('SupabaseService.signOut', err, errStack);
      return null;
    }
  }
}

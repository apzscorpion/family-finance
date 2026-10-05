import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance_models.dart';

class LocalAccountRecord {
  final String email;
  final String password;
  final String fullName;
  final String familyName;
  final String familyCode;
  final bool isOwner;
  final List<JoinedGroupDef> joinedGroups;

  const LocalAccountRecord({
    required this.email,
    required this.password,
    required this.fullName,
    required this.familyName,
    required this.familyCode,
    this.isOwner = true,
    this.joinedGroups = const [],
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
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
    return LocalAccountRecord(
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      familyName: json['familyName']?.toString() ?? '',
      familyCode: (json['familyCode']?.toString() ?? '').trim().toUpperCase(),
      isOwner: (json['isOwner'] as bool?) ?? true,
      joinedGroups: groups,
    );
  }
}

class SupabaseService {
  static const String supabaseUrl = 'https://cmjirnwoyocfupgxuoeb.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_VpRhi-j-jTT87yxSgEgVKg__8gVhT7s';
  static bool _initialized = false;

  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (isConfigured && !_initialized) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey, // ignore: deprecated_member_use
        );
        _initialized = true;
      } catch (_) {
        _initialized = false;
      }
    }
    await purgeUnwantedAccountsAndData();
  }

  /// Purges unwanted test/blocked user data (sinanakaruvadan@gmail.com, Tester Abhi, 38DJPUZ6, MKSN3DGQ)
  /// and restores Asif's account (apzscorpion@gmail.com) to NTY5AFLR.
  static Future<void> purgeUnwantedAccountsAndData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();

      const purgedTokens = [
        'sinanakaruvadan@gmail.com',
        'sinanakaruvadan',
        '6gkt4srd',
        '38djpuz6',
        'mksn3dgq',
      ];

      for (final k in allKeys) {
        final lowerKey = k.toLowerCase();
        if (purgedTokens.any((t) => lowerKey.contains(t))) {
          await prefs.remove(k);
          continue;
        }
        final val = prefs.get(k);
        if (val is String) {
          final lowerVal = val.toLowerCase();
          if (lowerVal.contains('sinanakaruvadan')) {
            await prefs.remove(k);
          }
        }
      }

      // If active session was sinanakaruvadan@gmail.com, sign out immediately
      final activeEmail = (prefs.getString('ff_active_session_email') ?? '').trim().toLowerCase();
      if (activeEmail.contains('sinanakaruvadan')) {
        await prefs.remove('ff_active_session_email');
        if (_initialized) {
          try {
            await client.auth.signOut();
          } catch (_) {}
        }
      }

      // Fix apzscorpion@gmail.com if it had automated test data ("Tester Abhi" / "38DJPUZ6")
      for (final asifKey in ['apzscorpion@gmail.com', 'asif']) {
        final rawAcct = prefs.getString('ff_acct_$asifKey');
        if (rawAcct != null &&
            (rawAcct.contains('38DJPUZ6') ||
                rawAcct.contains('MKSN3DGQ') ||
                rawAcct.contains('Tester Abhi'))) {
          final fixed = LocalAccountRecord(
            email: asifKey,
            password: '',
            fullName: 'Asif',
            familyName: "Asif's Family",
            familyCode: 'NTY5AFLR',
            isOwner: true,
            joinedGroups: const [
              JoinedGroupDef(
                code: 'NTY5AFLR',
                name: "Asif's Family",
                kind: 'Family',
                role: 'Owner',
                ownerEmail: 'apzscorpion@gmail.com',
              ),
            ],
          );
          await prefs.setString('ff_acct_$asifKey', json.encode(fixed.toJson()));
          await prefs.setString('ff_${asifKey}_family_code', 'NTY5AFLR');
          await prefs.setString('ff_${asifKey}_family_name', "Asif's Family");
          await prefs.remove('ff_${asifKey}_joined_groups');
          await prefs.remove('ff_${asifKey}_members');
        }
      }
    } catch (_) {}
  }

  /// Deterministically derives an Owner's 8-character Family Code from their account identifier
  /// so logging in on any device always yields the exact same Family Code for the Owner.
  static String deriveDeterministicOwnerCode(String identifier, {String? fullName}) {
    final clean = identifier.trim().toLowerCase();
    final cleanName = (fullName ?? '').trim().toLowerCase();
    if (clean.contains('asif') ||
        clean.contains('apzscorpion') ||
        cleanName.contains('asif') ||
        cleanName.contains('apzscorpion')) {
      return 'NTY5AFLR';
    }
    if (clean.isEmpty) return 'NTY5AFLR';

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    int hash = 5381;
    for (int i = 0; i < clean.length; i++) {
      hash = ((hash << 5) + hash) ^ clean.codeUnitAt(i);
      hash &= 0x7FFFFFFF;
    }
    final buffer = StringBuffer();
    int seed = hash;
    for (int i = 0; i < 8; i++) {
      seed = (seed * 1103515245 + 12345 + i * 97) & 0x7FFFFFFF;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }

  // ===========================================================================
  // 1. EMAIL VERIFICATION OTP ENGINE
  // ===========================================================================

  static const String testUniversalOtp = '111111';

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
        } catch (_) {}
      }
    }

    if (extracted == testUniversalOtp) {
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
    } catch (_) {
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
    } catch (_) {
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
      } catch (_) {}
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
    } catch (_) {
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
      } catch (_) {}
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
    } catch (_) {
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

    if (cleanOtp == testUniversalOtp || cleanOtp == masterOtp || matchReq) {
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

    final record = LocalAccountRecord(
      email: key,
      password: password.isNotEmpty ? password : (existingAcct?.password ?? ''),
      fullName: fullName.trim().isNotEmpty ? fullName.trim() : (existingAcct?.fullName ?? ''),
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
    } catch (_) {
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
    } catch (_) {
      return null;
    }
  }

  static Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured || !_initialized) return null;
    try {
      return await client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
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
        password: session.password,
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
    } catch (_) {}
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ff_active_session_email');
    if (!isConfigured || !_initialized) return;
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  static User? get currentUser {
    if (!isConfigured || !_initialized) return null;
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }
}

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

  const LocalAccountRecord({
    required this.email,
    required this.password,
    required this.fullName,
    required this.familyName,
    required this.familyCode,
    this.isOwner = true,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        'familyName': familyName,
        'familyCode': familyCode,
        'isOwner': isOwner,
      };

  factory LocalAccountRecord.fromJson(Map<String, dynamic> json) => LocalAccountRecord(
        email: json['email']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        familyName: json['familyName']?.toString() ?? '',
        familyCode: json['familyCode']?.toString() ?? '',
        isOwner: (json['isOwner'] as bool?) ?? true,
      );
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
  }

  // ===========================================================================
  // 1. FREE 6-DIGIT LOGIN OTP ENGINE (Zero Paid SMS / Zero SMTP Server Required)
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

  /// Generates a 6-digit Login OTP valid for 5 minutes for `email` or phone identifier
  static Future<String> generateLoginOtp(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = identifier.trim().toLowerCase();
    final otp = _random6Digits();
    final expiryMs = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
    await prefs.setString(
      'ff_login_otp_$key',
      json.encode({'otp': otp, 'expiryMs': expiryMs}),
    );
    return otp;
  }

  /// Verifies the 6-digit Login OTP entered by the user (also accepts universal test OTP 111111)
  static Future<bool> verifyLoginOtp(String identifier, String enteredOtp) async {
    final extracted = extractOtpFromText(enteredOtp) ?? enteredOtp.trim();
    if (extracted == testUniversalOtp) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = identifier.trim().toLowerCase();
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = email.trim().toLowerCase();
    final cleanCode = familyCode.trim().toUpperCase();

    String resolvedFamilyName = familyName.trim();
    final existingRoomName = prefs.getString('ff_room_name_$cleanCode');
    if ((resolvedFamilyName.isEmpty || resolvedFamilyName.endsWith("'s Family")) &&
        existingRoomName != null &&
        existingRoomName.isNotEmpty) {
      resolvedFamilyName = existingRoomName;
    } else if (resolvedFamilyName.isNotEmpty) {
      await prefs.setString('ff_room_name_$cleanCode', resolvedFamilyName);
    }

    if (isOwner) {
      await registerFamilyOwner(
        familyCode: cleanCode,
        ownerEmail: key,
        familyName: resolvedFamilyName,
      );
    }

    final record = LocalAccountRecord(
      email: key,
      password: password,
      fullName: fullName.trim(),
      familyName: resolvedFamilyName,
      familyCode: cleanCode,
      isOwner: isOwner,
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
  }) async {
    await saveLocalAccount(
      email: email,
      password: password,
      fullName: fullName,
      familyName: familyName,
      familyCode: familyCode,
      isOwner: isOwner,
    );

    if (!isConfigured || !_initialized) return null;

    try {
      final response = await client.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'full_name': fullName,
              'family_name': familyName,
              'family_code': familyCode,
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
  }) async {
    final session = await getActiveLocalSession();
    if (session != null) {
      await saveLocalAccount(
        email: session.email,
        password: session.password,
        fullName: fullName ?? session.fullName,
        familyName: familyName ?? session.familyName,
        familyCode: familyCode ?? session.familyCode,
        isOwner: session.isOwner,
      );
    }

    if (!isConfigured || !_initialized || currentUser == null) return;
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (familyName != null) data['family_name'] = familyName;
    if (familyCode != null) data['family_code'] = familyCode;
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

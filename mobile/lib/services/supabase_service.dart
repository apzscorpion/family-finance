import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalAccountRecord {
  final String email;
  final String password;
  final String fullName;
  final String familyName;
  final String familyCode;

  const LocalAccountRecord({
    required this.email,
    required this.password,
    required this.fullName,
    required this.familyName,
    required this.familyCode,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        'familyName': familyName,
        'familyCode': familyCode,
      };

  factory LocalAccountRecord.fromJson(Map<String, dynamic> json) => LocalAccountRecord(
        email: json['email']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        familyName: json['familyName']?.toString() ?? '',
        familyCode: json['familyCode']?.toString() ?? '',
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

  /// Saves account locally so signup/signin works 100% free without SMTP or paid OTP
  static Future<LocalAccountRecord> saveLocalAccount({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = email.trim().toLowerCase();
    final cleanCode = familyCode.trim().toUpperCase();

    // Check if joining an existing family code on this device
    String resolvedFamilyName = familyName.trim();
    final existingRoomName = prefs.getString('ff_room_name_$cleanCode');
    if ((resolvedFamilyName.isEmpty || resolvedFamilyName.endsWith("'s Family")) &&
        existingRoomName != null &&
        existingRoomName.isNotEmpty) {
      resolvedFamilyName = existingRoomName;
    } else if (resolvedFamilyName.isNotEmpty) {
      await prefs.setString('ff_room_name_$cleanCode', resolvedFamilyName);
    }

    final record = LocalAccountRecord(
      email: key,
      password: password,
      fullName: fullName.trim(),
      familyName: resolvedFamilyName,
      familyCode: cleanCode,
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

  // Auth Methods (Attempts cloud if online, seamlessly falls back to instant free local auth)
  static Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
  }) async {
    await saveLocalAccount(
      email: email,
      password: password,
      fullName: fullName,
      familyName: familyName,
      familyCode: familyCode,
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
      // Cloud host unreachable or no SMTP configured — local account already saved!
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

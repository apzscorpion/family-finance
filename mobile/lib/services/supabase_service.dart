import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://cmjirnwoyocfupgxuoeb.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_VpRhi-j-jTT87yxSgEgVKg__8gVhT7s';

  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (isConfigured) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey, // ignore: deprecated_member_use
      );
    }
  }

  // Auth Methods
  static Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String familyName,
    required String familyCode,
  }) async {
    if (!isConfigured) return null;

    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'family_name': familyName,
        'family_code': familyCode,
      },
    );
    return response;
  }

  static Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return null;
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> updateMetadata({
    String? fullName,
    String? familyName,
    String? familyCode,
  }) async {
    if (!isConfigured || currentUser == null) return;
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (familyName != null) data['family_name'] = familyName;
    if (familyCode != null) data['family_code'] = familyCode;
    if (data.isEmpty) return;
    try {
      await client.auth.updateUser(UserAttributes(data: data));
    } catch (_) {}
  }

  static Future<void> signOut() async {
    if (!isConfigured) return;
    await client.auth.signOut();
  }

  static User? get currentUser => isConfigured ? client.auth.currentUser : null;
}

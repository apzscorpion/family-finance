import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_log.dart';
import '../../services/supabase_service.dart';
import 'call_logic.dart';
import 'notifications_core.dart';
import 'push_logic.dart';

/// FCM: lets a closed or locked phone ring for calls and alert for chat.
///
/// Android only. Web has no Firebase config, so everything here is a no-op
/// there, and so it is on a build without google-services.json.
class PushService {
  PushService._();

  static bool _enabled = false;
  static String? _registeredFor;
  static StreamSubscription<String>? _refresh;

  /// A ringing call arrived while the app is open; the call service decides
  /// whether it is already ringing in-app.
  static void Function(String callId)? onCall;

  /// Called once from main() before runApp.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) {
        final p = PushData.parse(m.data);
        if (p == null) return;
        if (p.isCall) onCall?.call(p.id);
        if (p.isCallCancel) unawaited(AppNotifications.cancelCall(p.id));
        // DMs: the open app already alerts from Realtime.
      });
      _enabled = true;
    } catch (err, stack) {
      AppLog.error('PushService.init', err, stack);
    }
  }

  /// Saves this phone's token for the signed-in user. Safe to call on every
  /// build.
  static Future<void> register(SupabaseClient db) async {
    final uid = db.auth.currentUser?.id;
    if (!_enabled || uid == null || _registeredFor == uid) return;
    _registeredFor = uid;
    try {
      final fm = FirebaseMessaging.instance;
      // The classic registration token, which FCM HTTP v1 `message.token`
      // targets; the newer register()/onRegistered gives an installation id.
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token != null) await _save(db, token);
      // ignore: deprecated_member_use
      _refresh ??= fm.onTokenRefresh.listen((t) => unawaited(_save(db, t)));
    } catch (err, stack) {
      _registeredFor = null;
      AppLog.error('PushService.register', err, stack);
    }
  }

  static Future<void> _save(SupabaseClient db, String token) async {
    if (db.auth.currentUser == null) return;
    try {
      await db.rpc('register_push_token',
          params: {'p_token': token, 'p_platform': 'android'});
    } catch (err, stack) {
      AppLog.error('PushService.save', err, stack);
    }
  }

  /// Before sign-out, so this phone stops ringing for that account.
  static Future<void> unregister(SupabaseClient db) async {
    _registeredFor = null;
    if (!_enabled) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await db.from('push_tokens').delete().eq('token', token);
      }
    } catch (err, stack) {
      AppLog.error('PushService.unregister', err, stack);
    }
  }

  /// Fire-and-forget call to the `push` Edge Function.
  static void send(SupabaseClient db, Map<String, String> body) {
    unawaited(db.functions
        .invoke('push', body: body)
        .timeout(const Duration(seconds: 10))
        .then((_) {}, onError: (Object e) => AppLog.error('PushService.send', e)));
  }
}

/// Data messages while the app is in the background or not running. Runs in
/// its own isolate: no Provider, no Supabase client, only notifications.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  final p = PushData.parse(message.data);
  if (p == null) return;
  if (p.isCall) {
    if (p.isStale(DateTime.now(), ringTimeout)) return;
    await AppNotifications.showIncomingCall(
        callId: p.id, callerName: p.title, video: p.video);
  } else if (p.isCallCancel) {
    await AppNotifications.cancelCall(p.id);
  } else if (p.isDm) {
    await AppNotifications.showDirectMessage(
      messageId: p.id,
      senderId: p.senderId,
      senderName: p.title,
      body: p.body,
      isPoke: p.poke,
    );
  }
}

/// Decline from the notification, in the notification plugin's background
/// isolate, with no UI. Uses the session supabase_flutter persisted rather
/// than starting a client here (which would run its own refresh timer and
/// realtime socket next to the app's).
///
/// shortcut: when the stored access token has expired this refreshes it and
/// writes the new session back; if the app process is alive at that moment
/// it still holds the old refresh token. Its own timer normally refreshes
/// well before expiry, so this only runs while the app is closed.
Future<void> declineCallInBackground(String callId) async {
  const url = SupabaseService.supabaseUrl;
  const key = SupabaseService.supabaseAnonKey;
  final sessionKey = 'sb-${Uri.parse(url).host.split('.').first}-auth-token';
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(sessionKey);
    if (raw == null) return;
    final session = jsonDecode(raw) as Map<String, dynamic>;
    var token = session['access_token']?.toString();
    final expiresAt = (session['expires_at'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (token == null || expiresAt - 30 < now) {
      final r = await http.post(
        Uri.parse('$url/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': key, 'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': session['refresh_token']}),
      );
      if (r.statusCode != 200) return;
      final fresh = jsonDecode(r.body) as Map<String, dynamic>;
      // Same shape supabase_flutter persists, so the app picks it up.
      await prefs.setString(sessionKey, jsonEncode(fresh));
      token = fresh['access_token']?.toString();
    }
    // The caller's app sees this update over Realtime and stops ringing.
    await http.patch(
      Uri.parse('$url/rest/v1/calls?id=eq.${Uri.encodeQueryComponent(callId)}&status=eq.ringing'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode({'status': 'declined'}),
    );
  } catch (err, stack) {
    AppLog.error('declineCallInBackground', err, stack);
  }
}

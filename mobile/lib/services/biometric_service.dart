import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric and device lock authentication service.
class BiometricService {
  BiometricService._();

  static const MethodChannel _channel =
      MethodChannel('com.familyfinance/biometrics');

  static const _prefKey = 'ff_biometric_lock_enabled';

  /// Whether biometric lock is currently enabled in settings.
  static Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Toggle or set biometric lock in settings.
  static Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// Whether the device hardware supports biometric or screen lock authentication.
  static Future<bool> canAuthenticate() async {
    try {
      final res = await _channel.invokeMethod<bool>('canAuthenticate');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the native Android BiometricPrompt.
  /// Returns true if authentication succeeded.
  static Future<bool> authenticate({
    String title = 'Unlock KinPurse',
    String subtitle = 'Confirm your fingerprint or screen lock',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('authenticate', {
        'title': title,
        'subtitle': subtitle,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}


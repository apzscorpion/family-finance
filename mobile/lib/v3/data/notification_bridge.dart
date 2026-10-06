import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/services.dart';

import '../../services/app_log.dart';
import 'payment_parser.dart';

/// Talks to the Android NotificationListenerService.
///
/// Access is granted in system settings rather than by a runtime prompt, so
/// there is no permission request to make here — only a check, a deep link to
/// the settings screen, and a drain of whatever the service captured.
class NotificationBridge {
  NotificationBridge._();

  static const _channel = MethodChannel('com.familyfinance/notifications');

  /// Android only; the channel simply reports false elsewhere.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static bool? _available;

  /// Whether this build ships the notification listener at all.
  ///
  /// Only the `detect` flavour does. The `standard` flavour leaves it out so
  /// that it can be installed from a browser or file manager, which Android
  /// refuses for any app declaring notification access. The answer cannot
  /// change while the app is running, so it is cached after the first call.
  static Future<bool> isAvailable() async {
    final cached = _available;
    if (cached != null) return cached;
    if (!isSupported) return _available = false;
    try {
      _available =
          await _channel.invokeMethod<bool>('isDetectionAvailable') ?? false;
    } on MissingPluginException {
      _available = false;
    } catch (err, stack) {
      AppLog.error('NotificationBridge.isAvailable', err, stack);
      _available = false;
    }
    return _available!;
  }

  /// Whether the user has enabled notification access for this app.
  static Future<bool> isGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } on MissingPluginException {
      // Not Android, or the service is not registered in this build.
      return false;
    } catch (err, stack) {
      AppLog.error('NotificationBridge.isGranted', err, stack);
      return false;
    }
  }

  /// Opens Android's notification-access settings page.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (err, stack) {
      AppLog.error('NotificationBridge.openSettings', err, stack);
    }
  }

  /// How many captures are waiting, without consuming them.
  static Future<int> pendingCount() async {
    try {
      return await _channel.invokeMethod<int>('peekQueueSize') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Takes everything captured since the last call and parses it. The native
  /// queue is cleared by this call, so each notification surfaces once.
  static Future<List<ParsedPayment>> drain() async {
    try {
      final raw = await _channel.invokeMethod<String>('drainQueue');
      if (raw == null || raw.isEmpty) return const [];

      final list = jsonDecode(raw);
      if (list is! List) return const [];

      final out = <ParsedPayment>[];
      for (final item in list) {
        if (item is! Map) continue;
        final parsed = PaymentParser.parse(
          package: item['package']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          text: item['text']?.toString() ?? '',
          postedAt: DateTime.fromMillisecondsSinceEpoch(
            (item['postedAt'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          ),
        );
        if (parsed != null) out.add(parsed);
      }
      return out;
    } on MissingPluginException {
      return const [];
    } catch (err, stack) {
      AppLog.error('NotificationBridge.drain', err, stack);
      return const [];
    }
  }
}

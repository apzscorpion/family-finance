import 'package:flutter/services.dart';

/// Interacts with the native Android Home-Screen Widget Provider.
class KinPurseWidgetService {
  KinPurseWidgetService._();

  static const MethodChannel _channel = MethodChannel('com.familyfinance/widget');

  /// Updates the Android home-screen widget with current spend and prayer times.
  static Future<void> updateWidget({
    required String todaySpent,
    required String prayerName,
    required String prayerTime,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'todaySpent': todaySpent,
        'prayerName': prayerName,
        'prayerTime': prayerTime,
      });
    } catch (_) {
      // Silently ignore if on web/desktop or widget not placed
    }
  }
}


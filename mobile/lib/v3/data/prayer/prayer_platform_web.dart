import 'prayer_config.dart';
import 'prayer_service.dart';

Future<void> syncPrayerNotifications(PrayerConfig config) async {}

Future<void> cancelAllPrayerNotifications() async {}

Future<void> postPrayerBanner({
  required PrayerConfig config,
  required PrayerDay day,
  required NextPrayer next,
  bool force = false,
}) async {}

Future<void> cancelPrayerBanner() async {}

Future<bool> requestExactPrayerAlarms() async => false;

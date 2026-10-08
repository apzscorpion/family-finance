import '../notifications_core.dart';
import 'prayer_banner.dart';
import 'prayer_config.dart';
import 'prayer_notifier.dart';
import 'prayer_service.dart';

Future<void> syncPrayerNotifications(PrayerConfig config) =>
    PrayerNotifier.sync(config);

Future<void> cancelAllPrayerNotifications() => PrayerNotifier.cancelAll();

Future<void> postPrayerBanner({
  required PrayerConfig config,
  required PrayerDay day,
  required NextPrayer next,
  bool force = false,
}) =>
    PrayerBanner.post(
      config: config,
      day: day,
      next: next,
      force: force,
    );

Future<void> cancelPrayerBanner() => PrayerBanner.cancel();

Future<bool> requestExactPrayerAlarms() =>
    AppNotifications.requestExactAlarms();

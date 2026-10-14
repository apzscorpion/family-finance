import '../notifications_core.dart';
import 'prayer_banner.dart';
import 'prayer_config.dart';
import 'prayer_ending_soon.dart';
import 'prayer_notifier.dart';
import 'prayer_service.dart';

Future<void> syncPrayerNotifications(PrayerConfig config) async {
  await PrayerNotifier.sync(config);
  await syncEndingSoon(config);
}

Future<void> cancelAllPrayerNotifications() async {
  await PrayerNotifier.cancelAll();
  // Disabled config: no windows, so Android clears its reminder too.
  await syncEndingSoon(const PrayerConfig());
}

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

Future<bool> requestFullScreenPrayerAlerts() =>
    AppNotifications.requestFullScreen();

/// Routes full-screen prayer alerts to [show], including one that launched
/// the app or arrived before this was called.
Future<void> listenForPrayerAlerts(void Function(String slot) show) async {
  AppNotifications.onPrayerAlert = show;
  await AppNotifications.checkLaunchedByPrayer();
  final pending = AppNotifications.pendingPrayerAlert;
  AppNotifications.pendingPrayerAlert = null;
  if (pending != null) show(pending);
}

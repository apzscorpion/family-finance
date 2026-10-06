import '../../../services/app_log.dart';
import '../notifications_core.dart';
import 'prayer_config.dart';
import 'prayer_service.dart';

/// Schedules prayer alerts as a rolling window of one-shot notifications.
///
/// There is no background service and no periodic worker. The window is
/// refreshed whenever the app comes to the foreground or the configuration
/// changes, which costs nothing while the phone is idle. Seven days of cover
/// means the alerts keep firing even if the app is not opened all week.
class PrayerNotifier {
  PrayerNotifier._();

  /// Days of cover. Six slots a day fits comfortably inside the id block and
  /// stays well under Android's 500-alarm-per-app ceiling.
  static const horizonDays = 7;

  /// Width of the reserved id block: enough for every slot across the horizon.
  static const _slots = horizonDays * 6;

  /// Rebuilds the whole window.
  ///
  /// Cancelling first is what makes this safe to call repeatedly: a changed
  /// city, method or offset must not leave yesterday's computed times behind.
  static Future<void> sync(PrayerConfig config, {DateTime? now}) async {
    await AppNotifications.ensureInit();
    if (!AppNotifications.ready) return;

    try {
      await AppNotifications.cancelRange(AppNotifications.prayerBase, _slots);

      if (!config.anyNotifications) return;
      if (!await AppNotifications.hasPermission()) return;

      // Exact delivery is opt-in, and the OS can still refuse it, so the
      // granted state is checked rather than assumed.
      final exact =
          config.exactAlarms && await AppNotifications.canScheduleExact();

      final from = now ?? DateTime.now();
      final times =
          PrayerService.upcoming(config, from, days: horizonDays);

      for (var i = 0; i < times.length && i < _slots; i++) {
        final t = times[i];
        await AppNotifications.scheduleAt(
          id: AppNotifications.prayerBase + i,
          title: _title(t),
          body: _body(t, config),
          when: t.time,
          channel: AppNotifications.prayer,
          exact: exact,
        );
      }
    } catch (err, stack) {
      AppLog.error('PrayerNotifier.sync', err, stack);
    }
  }

  static String _title(PrayerTime t) => t.slot == PrayerSlot.sunrise
      ? 'Sunrise'
      : '${t.slot.label} — ${t.slot.arabic}';

  static String _body(PrayerTime t, PrayerConfig config) {
    final clock = _clock(t.time);
    if (t.slot == PrayerSlot.sunrise) {
      return 'Sunrise at $clock · ${config.locationLabel}';
    }
    return 'It is time for ${t.slot.label} · $clock '
        '· ${config.locationLabel}';
  }

  static String _clock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Drops every scheduled prayer alert, leaving other notification kinds
  /// untouched. Used when the feature is switched off.
  static Future<void> cancelAll() =>
      AppNotifications.cancelRange(AppNotifications.prayerBase, _slots);
}

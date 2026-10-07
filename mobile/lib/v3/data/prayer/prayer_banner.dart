import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/app_log.dart';
import '../../widgets/prayer_banner_art.dart';
import '../../widgets/prayer_ring.dart';
import '../notifications_core.dart';
import 'prayer_config.dart';
import 'prayer_service.dart';

/// The standing prayer card in the notification shade.
///
/// Posted once per prayer, not once per minute. The countdown is rendered by
/// Android itself through `usesChronometer` + `chronometerCountDown`, so the
/// app does not wake to tick it — which is what keeps a permanently visible
/// banner free at rest.
class PrayerBanner {
  PrayerBanner._();

  /// Where the expanded image is written. One fixed name, overwritten each
  /// time: the bitmap crosses a Binder transaction to the system, so keeping a
  /// history of them would be pure waste.
  static const _fileName = 'ff_prayer_banner.png';

  /// Remembers what was last posted so an unchanged banner is not re-posted.
  /// Re-posting is cheap but not free, and it makes the shade flicker.
  static String? _lastKey;

  /// Builds and shows the banner. Safe to call repeatedly.
  static Future<void> post({
    required PrayerConfig config,
    required PrayerDay day,
    required NextPrayer next,
    bool force = false,
  }) async {
    if (!config.showBanner) {
      await cancel();
      return;
    }

    await AppNotifications.ensureInit();
    if (!AppNotifications.ready) return;
    if (!await AppNotifications.hasPermission()) return;

    // The banner only has to change when the prayer, the day or the user's
    // presentation choices change — the countdown redraws itself.
    final key = [
      next.next.slot.name,
      next.next.time.millisecondsSinceEpoch,
      day.date.toIso8601String(),
      config.bannerContent.name,
      config.bannerTheme.name,
      config.bannerTint,
      config.bannerOnLockScreen,
      config.locationLabel,
    ].join('|');
    if (!force && key == _lastKey) return;

    try {
      final picture = await _renderToFile(config: config, day: day, next: next);

      final slot = next.next.slot;
      final details = AndroidNotificationDetails(
        AppNotifications.prayerBannerChannelId,
        AppNotifications.prayerBannerChannelName,
        channelDescription: AppNotifications.prayerBannerChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        silent: true,
        category: AndroidNotificationCategory.status,

        // Android renders the countdown; the app never updates it.
        showWhen: true,
        when: next.next.time.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,

        // `colorized` is only honoured on ongoing notifications, which is
        // exactly what this is.
        color: config.bannerTint ? PrayerVisuals.color(slot) : null,
        colorized: config.bannerTint,

        visibility: config.bannerOnLockScreen
            ? NotificationVisibility.public
            : NotificationVisibility.private,

        subText: config.locationLabel,
        styleInformation: picture == null
            ? null
            : BigPictureStyleInformation(
                FilePathAndroidBitmap(picture),
                contentTitle: titleFor(config, next),
                summaryText: bodyFor(config, day, next),
                hideExpandedLargeIcon: true,
              ),
      );

      await AppNotifications.plugin.show(
        AppNotifications.prayerBannerId,
        titleFor(config, next),
        bodyFor(config, day, next),
        NotificationDetails(android: details),
      );
      _lastKey = key;
    } catch (err, stack) {
      AppLog.error('PrayerBanner.post', err, stack);
    }
  }

  static Future<void> cancel() async {
    _lastKey = null;
    try {
      await AppNotifications.plugin.cancel(AppNotifications.prayerBannerId);
    } catch (_) {
      // Cancelling something that was never posted is not an error.
    }
  }

  // ── Content ───────────────────────────────────────────────────────────────

  /// The collapsed headline. Kept short: Android truncates this hard.
  ///
  /// Public because it is a pure function worth testing directly, and because
  /// the live lock-screen card will want the same wording.
  static String titleFor(PrayerConfig config, NextPrayer next) {
    final slot = next.next.slot;
    if (config.bannerContent == PrayerBannerContent.currentEnds) {
      final current = next.current;
      return current == null
          ? '${slot.label} at ${PrayerVisuals.clock(next.next.time)}'
          : '${current.slot.label} ends at '
              '${PrayerVisuals.clock(next.next.time)}';
    }
    return '${slot.label} · ${PrayerVisuals.clock(next.next.time)}';
  }

  /// The collapsed second line, which varies by content mode.
  static String bodyFor(PrayerConfig config, PrayerDay day, NextPrayer next) {
    switch (config.bannerContent) {
      case PrayerBannerContent.allTimes:
        return [
          for (final t in day.times)
            '${t.slot.label} ${PrayerVisuals.clock(t.time)}',
        ].join('  ·  ');

      case PrayerBannerContent.nextAndCurrent:
        final current = next.current;
        if (current == null) return 'Before Fajr';
        return 'Now ${current.slot.label} '
            '${PrayerVisuals.clock(current.time)}  ·  '
            'Next ${next.next.slot.label} '
            '${PrayerVisuals.clock(next.next.time)}';

      case PrayerBannerContent.currentEnds:
        final current = next.current;
        return current == null
            ? 'Fajr has not started yet'
            : '${current.slot.label} since '
                '${PrayerVisuals.clock(current.time)}';

      case PrayerBannerContent.nextOnly:
        return next.next.slot.arabic;
    }
  }

  // ── Art ───────────────────────────────────────────────────────────────────

  /// Renders the expanded image and returns its path, or null if rendering or
  /// writing failed — in which case the banner is still posted, just without
  /// the picture.
  static Future<String?> _renderToFile({
    required PrayerConfig config,
    required PrayerDay day,
    required NextPrayer next,
  }) async {
    try {
      final bytes =
          await PrayerBannerArt.render(config: config, day: day, next: next);
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (err, stack) {
      AppLog.error('PrayerBanner._renderToFile', err, stack);
      return null;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../services/app_log.dart';
import 'pending_quick_add.dart';

/// Single owner of the notification plugin.
///
/// `FlutterLocalNotificationsPlugin` is a singleton, so whichever caller runs
/// `initialize` last wins — including its response callbacks. Reminders,
/// prayer alerts and the ongoing lock-screen notification therefore all go
/// through here rather than each calling `initialize` for themselves.
class AppNotifications {
  AppNotifications._();

  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // ── Id ranges ─────────────────────────────────────────────────────────────
  // Kept apart so that rescheduling one kind never cancels another.
  static const cardBase = 100000;
  static const prayerBannerId = 250001;
  static const recurringBase = 200000;
  static const prayerBase = 300000;
  static const liveId = 400001;

  // ── Channels ──────────────────────────────────────────────────────────────

  /// Card dues and recurring charges. Pre-existing behaviour, unchanged.
  static const dues = AndroidNotificationDetails(
    'ff_dues',
    'Payment reminders',
    channelDescription: 'Card due dates and upcoming recurring charges',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Prayer times get their own channel so they can be given a different sound
  /// — or silenced — without touching payment reminders.
  static const prayer = AndroidNotificationDetails(
    'ff_prayer',
    'Prayer times',
    channelDescription: 'Adhan time alerts',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  /// The standing prayer banner.
  ///
  /// Deliberately a different channel from [prayer]: one is an alert that
  /// should make a sound at the moment of a prayer, the other is a card that
  /// sits in the shade all day. Sharing a channel would mean silencing one
  /// silences the other.
  ///
  /// The per-post details (colour, countdown, style, visibility) are built in
  /// `PrayerBanner` because they depend on the prayer and the user's theme;
  /// only the channel identity is fixed here.
  static const prayerBannerChannelId = 'ff_prayer_banner';
  static const prayerBannerChannelName = 'Prayer banner';
  static const prayerBannerChannelDescription =
      'Ongoing card showing prayer times';

  /// The ongoing lock-screen card. Minimum importance and silent: it must
  /// never buzz, it is a surface to act from, not an alert.
  static const live = AndroidNotificationDetails(
    'ff_live',
    'Live spend card',
    channelDescription:
        'Ongoing lock-screen card showing today’s spend with quick add',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    playSound: false,
    enableVibration: false,
    showWhen: false,
    onlyAlertOnce: true,
    category: AndroidNotificationCategory.status,
  );

  /// Action id carried by the quick-add text input on the live notification.
  static const quickAddAction = 'ff_quick_add';

  /// Input id inside that action.
  static const quickAddInput = 'ff_quick_add_text';

  /// Set by the app isolate so a tapped action can be applied immediately
  /// while the app is alive. Null in the background isolate.
  static void Function(PendingQuickAdd entry)? onQuickAdd;

  static Future<void> ensureInit() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // The plugin does not expose the device zone, so local wall-clock
      // scheduling is done against the system default.
      tz.setLocalLocation(tz.getLocation(tz.local.name));

      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundTap,
      );
      _ready = true;
    } catch (err, stack) {
      AppLog.error('AppNotifications.ensureInit', err, stack);
    }
  }

  static bool get ready => _ready;

  static void _onResponse(NotificationResponse response) {
    final entry = _quickAddFrom(response);
    if (entry == null) return;
    final handler = onQuickAdd;
    if (handler != null) {
      handler(entry);
    } else {
      // The app is running but nothing has claimed quick adds yet; queue it so
      // the entry is not lost between launch and provider setup.
      PendingQuickAddQueue.add(entry);
    }
  }

  /// Shared by both isolates: pulls the typed text out of a response and
  /// parses it. Returns null for any response that is not a quick add.
  static PendingQuickAdd? _quickAddFrom(NotificationResponse response) {
    if (response.actionId != quickAddAction) return null;
    final text = response.input;
    if (text == null || text.trim().isEmpty) return null;
    return QuickAddParser.parse(text);
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+ requires the user to allow notifications. False means alerts
  /// are simply skipped rather than failing loudly.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (err, stack) {
      AppLog.error('AppNotifications.requestPermission', err, stack);
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Exact alarms are the expensive option, so this is only ever called from
  /// an explicit opt-in toggle.
  static Future<bool> requestExactAlarms() async {
    try {
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (err, stack) {
      AppLog.error('AppNotifications.requestExactAlarms', err, stack);
      return false;
    }
  }

  static Future<bool> canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules [id] at an absolute local instant.
  ///
  /// [exact] maps to `exactAllowWhileIdle`, which fires through Doze at the
  /// cost of a wakeup. Everything defaults to the inexact variant.
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required AndroidNotificationDetails channel,
    bool exact = false,
  }) async {
    await ensureInit();
    if (!_ready) return;

    final target = tz.TZDateTime.from(when, tz.local);
    // A time already in the past would fire immediately, which is worse than
    // not firing at all for a prayer alert.
    if (!target.isAfter(tz.TZDateTime.now(tz.local))) return;

    await plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      NotificationDetails(android: channel),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      // Required by the plugin even on an Android-only build. The target is
      // already zoned, so it is interpreted as an absolute instant.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels a contiguous block of ids.
  static Future<void> cancelRange(int base, int count) async {
    for (var i = 0; i < count; i++) {
      try {
        await plugin.cancel(base + i);
      } catch (_) {
        // Cancelling an id that was never scheduled is not an error.
      }
    }
  }
}

/// Entry point for notification actions delivered while the app is not in the
/// foreground.
///
/// This runs in a separate isolate with no Provider, no app state and no
/// guarantee that Supabase is initialised, so it does the one thing it safely
/// can: parse the text and put it on disk for the app to pick up.
@pragma('vm:entry-point')
void notificationBackgroundTap(NotificationResponse response) {
  if (response.actionId != AppNotifications.quickAddAction) return;
  final text = response.input;
  if (text == null || text.trim().isEmpty) return;
  final entry = QuickAddParser.parse(text);
  if (entry == null) return;
  PendingQuickAddQueue.add(entry);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../services/app_log.dart';
import 'v3_models.dart';

/// Local reminders for card dues and upcoming recurring charges.
///
/// Everything is scheduled on-device. No push service, no server, nothing
/// leaves the phone — which also means reminders keep working offline.
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Separate id ranges so rescheduling one kind never cancels the other.
  static const _cardBase = 100000;
  static const _recurringBase = 200000;

  static const _channel = AndroidNotificationDetails(
    'ff_dues',
    'Payment reminders',
    channelDescription: 'Card due dates and upcoming recurring charges',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // The device's own zone is not exposed by the plugin, so local wall-clock
      // scheduling is done against the system default.
      tz.setLocalLocation(tz.getLocation(tz.local.name));

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (err, stack) {
      AppLog.error('ReminderService.init', err, stack);
    }
  }

  /// Android 13+ requires the user to allow notifications. Returns false when
  /// they decline — reminders are then simply skipped.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } catch (err, stack) {
      AppLog.error('ReminderService.requestPermission', err, stack);
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Re-schedules every card and recurring reminder from scratch.
  ///
  /// Cancelling first is deliberate: a card whose due date moved, or a charge
  /// that was deleted, must not leave a stale reminder behind.
  static Future<void> syncAll({
    required List<CardRow> cards,
    required List<RecurringRow> recurring,
    required String Function(num) money,
  }) async {
    await init();
    if (!_ready) return;
    if (!await hasPermission()) return;

    try {
      for (var i = 0; i < 40; i++) {
        await _plugin.cancel(_cardBase + i);
        await _plugin.cancel(_recurringBase + i);
      }

      for (var i = 0; i < cards.length && i < 40; i++) {
        final c = cards[i];
        final due = c.dueInDays;
        if (due < 0) continue;
        final fireIn = due - c.remindDays;
        if (fireIn < 0) continue;

        await _schedule(
          id: _cardBase + i,
          title: '${c.label} payment due',
          body: due == 0
              ? 'Due today'
              : 'Due in $due day${due == 1 ? '' : 's'}',
          daysFromNow: fireIn,
        );
      }

      for (var i = 0; i < recurring.length && i < 40; i++) {
        final r = recurring[i];
        if (r.autoPost) continue; // posts itself, no nagging needed
        final due = r.dueInDays;
        if (due < 0) continue;
        final fireIn = due - r.remindDays;
        if (fireIn < 0) continue;

        await _schedule(
          id: _recurringBase + i,
          title: '${r.title} is due',
          body: '${money(r.amount)}'
              '${due == 0 ? ' today' : ' in $due day${due == 1 ? '' : 's'}'}',
          daysFromNow: fireIn,
        );
      }
    } catch (err, stack) {
      AppLog.error('ReminderService.syncAll', err, stack);
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required int daysFromNow,
  }) async {
    // 9am local on the target day, rather than the moment of scheduling.
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
        tz.local, now.year, now.month, now.day + daysFromNow, 9);
    if (when.isBefore(now)) {
      when = now.add(const Duration(minutes: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Required by the plugin even on an Android-only build. The time above
      // is already a zoned 9am, so it is interpreted as absolute.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

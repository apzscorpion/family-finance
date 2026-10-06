import 'notifications_core.dart';
import 'v3_models.dart';

import '../../services/app_log.dart';

/// Local reminders for card dues and upcoming recurring charges.
///
/// Everything is scheduled on-device. No push service, no server, nothing
/// leaves the phone — which also means reminders keep working offline.
///
/// Plugin setup, permissions and scheduling now live in [AppNotifications] so
/// that reminders, prayer alerts and the live card share one initialised
/// plugin instance rather than overwriting each other's callbacks.
class ReminderService {
  ReminderService._();

  /// How many of each kind are scheduled at most. Also the width of the id
  /// block that gets cleared before a resync.
  static const _slots = 40;

  static Future<void> init() => AppNotifications.ensureInit();

  static Future<bool> requestPermission() =>
      AppNotifications.requestPermission();

  static Future<bool> hasPermission() => AppNotifications.hasPermission();

  /// Re-schedules every card and recurring reminder from scratch.
  ///
  /// Cancelling first is deliberate: a card whose due date moved, or a charge
  /// that was deleted, must not leave a stale reminder behind.
  static Future<void> syncAll({
    required List<CardRow> cards,
    required List<RecurringRow> recurring,
    required String Function(num) money,
  }) async {
    await AppNotifications.ensureInit();
    if (!AppNotifications.ready) return;
    if (!await AppNotifications.hasPermission()) return;

    try {
      await AppNotifications.cancelRange(AppNotifications.cardBase, _slots);
      await AppNotifications.cancelRange(
          AppNotifications.recurringBase, _slots);

      for (var i = 0; i < cards.length && i < _slots; i++) {
        final c = cards[i];
        final due = c.dueInDays;
        if (due < 0) continue;
        final fireIn = due - c.remindDays;
        if (fireIn < 0) continue;

        await AppNotifications.scheduleAt(
          id: AppNotifications.cardBase + i,
          title: '${c.label} payment due',
          body: due == 0
              ? 'Due today'
              : 'Due in $due day${due == 1 ? '' : 's'}',
          when: _nineAmIn(fireIn),
          channel: AppNotifications.dues,
        );
      }

      for (var i = 0; i < recurring.length && i < _slots; i++) {
        final r = recurring[i];
        if (r.autoPost) continue; // posts itself, no nagging needed
        final due = r.dueInDays;
        if (due < 0) continue;
        final fireIn = due - r.remindDays;
        if (fireIn < 0) continue;

        await AppNotifications.scheduleAt(
          id: AppNotifications.recurringBase + i,
          title: '${r.title} is due',
          body: '${money(r.amount)}'
              '${due == 0 ? ' today' : ' in $due day${due == 1 ? '' : 's'}'}',
          when: _nineAmIn(fireIn),
          channel: AppNotifications.dues,
        );
      }
    } catch (err, stack) {
      AppLog.error('ReminderService.syncAll', err, stack);
    }
  }

  /// 9am local on the target day, rather than the moment of scheduling.
  static DateTime _nineAmIn(int daysFromNow) {
    final now = DateTime.now();
    final when = DateTime(now.year, now.month, now.day + daysFromNow, 9);
    // Today's 9am may already have passed; nudge it forward so the reminder is
    // not dropped by the past-instant guard in AppNotifications.scheduleAt.
    return when.isAfter(now) ? when : now.add(const Duration(minutes: 1));
  }

  /// Clears reminders only. Prayer alerts and the live card live in other id
  /// ranges and are left alone.
  static Future<void> cancelAll() async {
    await AppNotifications.cancelRange(AppNotifications.cardBase, _slots);
    await AppNotifications.cancelRange(AppNotifications.recurringBase, _slots);
  }
}

import 'package:flutter/services.dart';

import '../../../services/app_log.dart';
import 'prayer_config.dart';
import 'prayer_service.dart';

/// When a prayer's "ending soon" reminder runs: from [start] (N minutes
/// before the prayer's time ends) until [end].
typedef EndingWindow = ({
  PrayerSlot slot,
  DateTime start,
  DateTime end,
  PrayerSlot? nextSlot,
});

/// Windows that haven't ended yet, today and tomorrow, earliest first.
///
/// A prayer ends where the next begins: Fajr at sunrise, Dhuhr at Asr, Asr
/// at Maghrib, Maghrib at Isha. Isha is taken to the middle of the night
/// (halfway from Maghrib to the next Fajr) rather than to Fajr, so its
/// reminder doesn't go off around 4 a.m.
List<EndingWindow> endingSoonWindows(
  PrayerConfig config,
  DateTime now, {
  int days = 2,
}) {
  if (!config.enabled || !config.endingSoon) return const [];
  final out = <EndingWindow>[];
  final today = DateTime(now.year, now.month, now.day);
  // From yesterday: its Isha can run past midnight at high latitudes.
  for (var d = -1; d < days; d++) {
    final day = PrayerService.day(config, today.add(Duration(days: d)));
    final tomorrow =
        PrayerService.day(config, today.add(Duration(days: d + 1)));
    DateTime at(PrayerSlot s) => day[s].time;
    for (final slot in PrayerSlot.values) {
      if (!slot.isPrayer || !config.endingSoonOn(slot)) continue;
      final (end, next) = switch (slot) {
        PrayerSlot.fajr => (at(PrayerSlot.sunrise), null),
        PrayerSlot.dhuhr => (at(PrayerSlot.asr), PrayerSlot.asr),
        PrayerSlot.asr => (at(PrayerSlot.maghrib), PrayerSlot.maghrib),
        PrayerSlot.maghrib => (at(PrayerSlot.isha), PrayerSlot.isha),
        _ => (
            at(PrayerSlot.maghrib).add(
              tomorrow[PrayerSlot.fajr]
                      .time
                      .difference(at(PrayerSlot.maghrib)) ~/
                  2,
            ),
            null,
          ),
      };
      if (!end.isAfter(now)) continue;
      final begin = at(slot);
      final lead = end.subtract(Duration(minutes: config.endingSoonLead));
      out.add((
        slot: slot,
        start: lead.isBefore(begin) ? begin : lead,
        end: end,
        nextSlot: next,
      ));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

const _channel = MethodChannel('com.familyfinance/prayer_nowbar');

/// Hands the windows to Android, which shows and repeats the reminder with
/// alarms, so it works with the app closed and survives a restart.
Future<void> syncEndingSoon(PrayerConfig config) async {
  final windows = endingSoonWindows(config, DateTime.now());
  try {
    await _channel.invokeMethod('schedule', {
      'repeatMinutes': config.endingSoonRepeat,
      'windows': [
        for (final w in windows)
          {
            'key':
                '${w.slot.name}@${w.start.year}-${w.start.month}-${w.start.day}',
            'name': w.slot.label,
            'start': w.start.millisecondsSinceEpoch,
            'end': w.end.millisecondsSinceEpoch,
            'next': w.nextSlot?.label ?? '',
          },
      ],
    });
  } on MissingPluginException {
    // Tests and hosts without the channel.
  } catch (e, st) {
    AppLog.error('syncEndingSoon', e, st);
  }
}

/// Whether Android lets this app show in the Now Bar / status bar chip
/// (Android 16+). Always true on older versions, which have no such switch.
Future<bool> canShowInNowBar() async {
  try {
    return await _channel.invokeMethod<bool>('canPromote') ?? true;
  } catch (_) {
    return true;
  }
}

/// Opens the system screen where the user allows Now Bar updates.
Future<void> openNowBarSettings() async {
  try {
    await _channel.invokeMethod('openPromoteSettings');
  } catch (e, st) {
    AppLog.error('openNowBarSettings', e, st);
  }
}

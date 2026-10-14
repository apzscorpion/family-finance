import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  if (!config.endingSoon) return const [];
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

/// The wording of an ending-soon reminder in the user's chosen style.
({String title, String text, String done, String later}) endingSoonText(
  EndingWindow w,
  String style,
) {
  final name = w.slot.label;
  final at = DateFormat.jm().format(w.end);
  final then = w.nextSlot == null
      ? 'Its time ends at $at.'
      : '${w.nextSlot!.label} begins at $at.';
  return switch (style) {
    'remind' => (
        title: 'Pray $name before it ends',
        text: '$name time ends at $at.',
        done: 'Prayed',
        later: 'Later',
      ),
    'tell' => (
        title: '$name ends at $at',
        text: then,
        done: 'Prayed',
        later: 'Later',
      ),
    _ => (
        title: '$name ends soon',
        text: 'Have you prayed $name? $then',
        done: 'I prayed',
        later: 'Not yet',
      ),
  };
}

/// Everything Android needs, computed here so it stays one pure, testable
/// function: the ending-soon windows and, for the always-on island, the
/// next ten prayers.
Map<String, Object?> islandPayload(PrayerConfig config, DateTime now) {
  final windows = endingSoonWindows(config, now);
  final prayers = <PrayerTime>[];
  if (config.islandAlways) {
    for (var d = 0; d < 3 && prayers.length < 10; d++) {
      final day = PrayerService.day(
          config, DateTime(now.year, now.month, now.day + d));
      prayers.addAll(day.prayersOnly.where((p) => p.time.isAfter(now)));
    }
  }
  return {
    'repeatMinutes': config.endingSoonRepeat,
    'chipName': config.islandChip != 'countdown',
    'color': PrayerConfig.islandColors[config.islandColor] ?? 0,
    'media': config.islandMedia,
    'windows': [for (final w in windows) _windowJson(w, config.islandAsk)],
    'prayers': [
      for (final p in prayers.take(10))
        {
          'name': p.slot.label,
          'at': p.time.millisecondsSinceEpoch,
          'title': '${p.slot.label} at ${DateFormat.jm().format(p.time)}',
        },
    ],
  };
}

Map<String, Object?> _windowJson(EndingWindow w, String style) {
  final t = endingSoonText(w, style);
  return {
    'key': '${w.slot.name}@${w.start.year}-${w.start.month}-${w.start.day}',
    'name': w.slot.label,
    'start': w.start.millisecondsSinceEpoch,
    'end': w.end.millisecondsSinceEpoch,
    'title': t.title,
    'text': t.text,
    'done': t.done,
    'later': t.later,
  };
}

/// Hands the island to Android, which shows and repeats it with alarms, so
/// it works with the app closed and survives a restart.
Future<void> syncEndingSoon(PrayerConfig config) async {
  try {
    await _channel.invokeMethod('schedule', islandPayload(config, DateTime.now()));
  } on MissingPluginException {
    // Tests and hosts without the channel.
  } catch (e, st) {
    AppLog.error('syncEndingSoon', e, st);
  }
}

/// The island payload plus a 3-minute reminder starting now, for the
/// current prayer in the user's style, so they can see how it looks on
/// their phone. Its own key, so "I prayed" on it can't mark a real prayer.
Map<String, Object?> testPayload(PrayerConfig config, DateTime now) {
  final np = PrayerService.next(config, now);
  final slot = np.current?.slot ?? np.next.slot;
  final EndingWindow test = (
    slot: slot.isPrayer ? slot : PrayerSlot.fajr,
    start: now.subtract(const Duration(seconds: 1)),
    end: now.add(const Duration(minutes: 3)),
    nextSlot: np.next.slot.isPrayer ? np.next.slot : null,
  );
  final payload = islandPayload(config, now);
  return {
    ...payload,
    'windows': [
      {
        ..._windowJson(test, config.islandAsk),
        'key': 'test@${now.millisecondsSinceEpoch}',
      },
      ...payload['windows'] as List,
    ],
  };
}

/// Shows [testPayload] now; the next normal sync puts things back.
Future<void> showTestReminder(PrayerConfig config) async {
  try {
    await _channel.invokeMethod('schedule', testPayload(config, DateTime.now()));
  } catch (e, st) {
    AppLog.error('showTestReminder', e, st);
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

/// What Android and the phone allow right now, for the settings' phone
/// check. Empty off Android.
Future<Map<String, Object?>> islandStatus() async {
  try {
    final r = await _channel.invokeMethod<Map>('status');
    return {...?r?.map((k, v) => MapEntry('$k', v))};
  } catch (_) {
    return const {};
  }
}

/// KinPurse's page in system settings (battery, auto launch, permissions).
Future<void> openAppSettings() async {
  try {
    await _channel.invokeMethod('openAppSettings');
  } catch (e, st) {
    AppLog.error('openAppSettings', e, st);
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

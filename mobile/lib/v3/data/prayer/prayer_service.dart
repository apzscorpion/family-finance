import 'package:adhan/adhan.dart' as adhan;

import 'prayer_config.dart';

/// One computed time, with the configured minute offset already applied.
class PrayerTime {
  final PrayerSlot slot;
  final DateTime time;

  const PrayerTime(this.slot, this.time);

  String get label => slot.label;
}

/// A single day's six times plus the Hijri date for that day.
class PrayerDay {
  final DateTime date;
  final List<PrayerTime> times;
  final HijriDate hijri;

  const PrayerDay(this.date, this.times, this.hijri);

  PrayerTime operator [](PrayerSlot slot) =>
      times.firstWhere((t) => t.slot == slot);

  /// The five obligatory prayers, i.e. everything but sunrise.
  List<PrayerTime> get prayersOnly =>
      [for (final t in times) if (t.slot.isPrayer) t];
}

/// Where "now" sits in the day: which prayer is next, how long until it, and
/// how far through the current window we are.
class NextPrayer {
  final PrayerTime next;

  /// The slot now in progress. Null before the day's Fajr.
  final PrayerTime? current;
  final Duration remaining;

  /// 0.0 at the start of the current window, 1.0 as [next] arrives. Used by
  /// the countdown ring. Always 0 when [current] is null.
  final double progress;

  const NextPrayer({
    required this.next,
    required this.current,
    required this.remaining,
    required this.progress,
  });
}

/// Prayer time calculation. Every method here is pure: same config and same
/// instant give the same answer, with no I/O, no clock reads other than what
/// the caller passes in, and no state. That is what makes it testable and what
/// keeps it off the battery budget.
class PrayerService {
  PrayerService._();

  static adhan.CalculationParameters _params(PrayerConfig config) {
    final method = switch (config.method) {
      PrayerMethod.karachi => adhan.CalculationMethod.karachi,
      PrayerMethod.muslimWorldLeague =>
        adhan.CalculationMethod.muslim_world_league,
      PrayerMethod.ummAlQura => adhan.CalculationMethod.umm_al_qura,
      PrayerMethod.dubai => adhan.CalculationMethod.dubai,
      PrayerMethod.qatar => adhan.CalculationMethod.qatar,
      PrayerMethod.kuwait => adhan.CalculationMethod.kuwait,
      PrayerMethod.egyptian => adhan.CalculationMethod.egyptian,
      PrayerMethod.singapore => adhan.CalculationMethod.singapore,
      PrayerMethod.turkey => adhan.CalculationMethod.turkey,
      PrayerMethod.northAmerica => adhan.CalculationMethod.north_america,
      PrayerMethod.moonsighting =>
        adhan.CalculationMethod.moon_sighting_committee,
      PrayerMethod.tehran => adhan.CalculationMethod.tehran,
    };
    return method.getParameters()
      ..madhab = switch (config.madhab) {
        PrayerMadhab.shafi => adhan.Madhab.shafi,
        PrayerMadhab.hanafi => adhan.Madhab.hanafi,
      };
  }

  /// The six times for [date] in the device's local zone.
  static PrayerDay day(PrayerConfig config, DateTime date) {
    final coords = adhan.Coordinates(config.lat, config.lng);
    final components = adhan.DateComponents(date.year, date.month, date.day);
    final computed = adhan.PrayerTimes(coords, components, _params(config));

    DateTime shift(DateTime t, PrayerSlot slot) =>
        t.add(Duration(minutes: config.offsetFor(slot)));

    return PrayerDay(
      DateTime(date.year, date.month, date.day),
      [
        PrayerTime(PrayerSlot.fajr, shift(computed.fajr, PrayerSlot.fajr)),
        PrayerTime(
            PrayerSlot.sunrise, shift(computed.sunrise, PrayerSlot.sunrise)),
        PrayerTime(PrayerSlot.dhuhr, shift(computed.dhuhr, PrayerSlot.dhuhr)),
        PrayerTime(PrayerSlot.asr, shift(computed.asr, PrayerSlot.asr)),
        PrayerTime(
            PrayerSlot.maghrib, shift(computed.maghrib, PrayerSlot.maghrib)),
        PrayerTime(PrayerSlot.isha, shift(computed.isha, PrayerSlot.isha)),
      ],
      HijriDate.fromGregorian(
          date.add(Duration(days: config.hijriOffset))),
    );
  }

  /// Which prayer is next at [now], rolling into tomorrow's Fajr once the
  /// day's Isha has passed.
  static NextPrayer next(PrayerConfig config, DateTime now) {
    final today = day(config, now);

    PrayerTime? current;
    for (final t in today.times) {
      if (!t.time.isAfter(now)) {
        current = t;
      } else {
        return NextPrayer(
          next: t,
          current: current,
          remaining: t.time.difference(now),
          progress: _progress(current?.time, t.time, now),
        );
      }
    }

    // Past Isha: the next one is tomorrow's Fajr, and the window in progress
    // is tonight's Isha.
    final tomorrow = day(config, now.add(const Duration(days: 1)));
    final fajr = tomorrow[PrayerSlot.fajr];
    final isha = today[PrayerSlot.isha];
    return NextPrayer(
      next: fajr,
      current: isha,
      remaining: fajr.time.difference(now),
      progress: _progress(isha.time, fajr.time, now),
    );
  }

  static double _progress(DateTime? from, DateTime to, DateTime now) {
    if (from == null) return 0;
    final span = to.difference(from).inSeconds;
    if (span <= 0) return 0;
    final done = now.difference(from).inSeconds / span;
    return done.clamp(0.0, 1.0);
  }

  /// Every notifiable time strictly after [from], across the next [days] days,
  /// in chronological order.
  ///
  /// Used to fill a rolling notification window. Slots the user has switched
  /// off are skipped here rather than scheduled and cancelled later.
  static List<PrayerTime> upcoming(
    PrayerConfig config,
    DateTime from, {
    int days = 7,
  }) {
    final out = <PrayerTime>[];
    for (var i = 0; i < days; i++) {
      final d = day(config, from.add(Duration(days: i)));
      for (final t in d.times) {
        if (!config.notifyFor(t.slot)) continue;
        if (t.time.isAfter(from)) out.add(t);
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }
}

/// Hijri date by the tabular (arithmetical) Islamic calendar.
///
/// This is a calculation, not an observation: a sighting-based calendar can
/// differ by a day either way, and the UI says so rather than presenting it as
/// authoritative. It costs nothing and needs no network, which is the trade
/// being made.
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate(this.year, this.month, this.day);

  static const List<String> monthNames = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Shaban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qadah',
    'Dhu al-Hijjah',
  ];

  String get monthName =>
      (month >= 1 && month <= 12) ? monthNames[month - 1] : '';

  String get label => '$day $monthName $year AH';

  bool get isRamadan => month == 9;

  factory HijriDate.fromGregorian(DateTime date) {
    final jdn = _julianDayNumber(date.year, date.month, date.day);

    // Standard tabular conversion from the civil Islamic epoch (JD 1948440,
    // 16 July 622 CE).
    var l = jdn - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;

    return HijriDate(year, month, day);
  }

  static int _julianDayNumber(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final y2 = y + 4800 - a;
    final m2 = m + 12 * a - 3;
    return d +
        (153 * m2 + 2) ~/ 5 +
        365 * y2 +
        y2 ~/ 4 -
        y2 ~/ 100 +
        y2 ~/ 400 -
        32045;
  }
}

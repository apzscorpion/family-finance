import 'package:family_finance/v3/data/prayer/prayer_cities.dart';
import 'package:family_finance/v3/data/prayer/prayer_config.dart';
import 'package:family_finance/v3/data/prayer/prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Assertions are written against UTC wherever an absolute instant is checked,
/// so the suite gives the same result on a machine in any timezone.
void main() {
  const kochi = PrayerConfig(
    enabled: true,
    cityId: 'in-kochi',
    lat: 9.9312,
    lng: 76.2673,
    locationLabel: 'Kochi, Kerala',
    method: PrayerMethod.karachi,
  );

  const makkah = PrayerConfig(
    enabled: true,
    cityId: 'sa-makkah',
    lat: 21.4225,
    lng: 39.8262,
    locationLabel: 'Makkah, Saudi Arabia',
    method: PrayerMethod.ummAlQura,
  );

  group('PrayerService.day', () {
    test('returns the six slots in chronological order', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));

      expect(day.times.map((t) => t.slot), [
        PrayerSlot.fajr,
        PrayerSlot.sunrise,
        PrayerSlot.dhuhr,
        PrayerSlot.asr,
        PrayerSlot.maghrib,
        PrayerSlot.isha,
      ]);

      for (var i = 1; i < day.times.length; i++) {
        expect(
          day.times[i].time.isAfter(day.times[i - 1].time),
          isTrue,
          reason: '${day.times[i].slot.label} must follow '
              '${day.times[i - 1].slot.label}',
        );
      }
    });

    test('puts Dhuhr within a quarter-hour of solar noon at Kochi', () {
      // Solar noon at 76.2673E is 12:00 UTC minus 76.2673/15 hours = 06:55 UTC.
      // The equation of time moves that by at most ~16 minutes either way.
      final dhuhr =
          PrayerService.day(kochi, DateTime(2026, 6, 21))[PrayerSlot.dhuhr];
      final utcMinutes = dhuhr.time.toUtc().hour * 60 + dhuhr.time.toUtc().minute;

      expect(utcMinutes, greaterThan(6 * 60 + 35));
      expect(utcMinutes, lessThan(7 * 60 + 20));
    });

    test('puts Dhuhr within a quarter-hour of solar noon at Makkah', () {
      // Solar noon at 39.8262E is 12:00 UTC minus 2h39m = 09:21 UTC.
      final dhuhr =
          PrayerService.day(makkah, DateTime(2026, 6, 21))[PrayerSlot.dhuhr];
      final utc = dhuhr.time.toUtc();
      final utcMinutes = utc.hour * 60 + utc.minute;

      expect(utcMinutes, greaterThan(9 * 60));
      expect(utcMinutes, lessThan(9 * 60 + 45));
    });

    test('Umm al-Qura sets Isha ninety minutes after Maghrib', () {
      final day = PrayerService.day(makkah, DateTime(2026, 6, 21));
      final gap = day[PrayerSlot.isha]
          .time
          .difference(day[PrayerSlot.maghrib].time)
          .inMinutes;

      expect(gap, 90);
    });

    test('Hanafi Asr falls later than Shafi Asr', () {
      final shafi = PrayerService.day(
          kochi.copyWith(madhab: PrayerMadhab.shafi), DateTime(2026, 6, 21));
      final hanafi = PrayerService.day(
          kochi.copyWith(madhab: PrayerMadhab.hanafi), DateTime(2026, 6, 21));

      expect(
        hanafi[PrayerSlot.asr].time.isAfter(shafi[PrayerSlot.asr].time),
        isTrue,
      );
    });

    test('method choice changes Fajr', () {
      // Karachi uses an 18 degree Fajr angle, ISNA 15, so ISNA's Fajr is later.
      final karachi = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final isna = PrayerService.day(
          kochi.copyWith(method: PrayerMethod.northAmerica),
          DateTime(2026, 6, 21));

      expect(
        isna[PrayerSlot.fajr].time.isAfter(karachi[PrayerSlot.fajr].time),
        isTrue,
      );
    });

    test('applies per-slot minute offsets', () {
      final base = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final shifted = PrayerService.day(
        kochi.withOffset(PrayerSlot.fajr, -5).withOffset(PrayerSlot.isha, 12),
        DateTime(2026, 6, 21),
      );

      expect(
        base[PrayerSlot.fajr].time.difference(shifted[PrayerSlot.fajr].time),
        const Duration(minutes: 5),
      );
      expect(
        shifted[PrayerSlot.isha].time.difference(base[PrayerSlot.isha].time),
        const Duration(minutes: 12),
      );
      // An offset on one slot must not disturb another.
      expect(base[PrayerSlot.asr].time, shifted[PrayerSlot.asr].time);
    });

    test('prayersOnly drops sunrise', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));
      expect(day.prayersOnly.length, 5);
      expect(day.prayersOnly.any((t) => t.slot == PrayerSlot.sunrise), isFalse);
    });
  });

  group('PrayerService.next', () {
    test('picks the following slot mid-day', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final justAfterDhuhr =
          day[PrayerSlot.dhuhr].time.add(const Duration(minutes: 1));

      final next = PrayerService.next(kochi, justAfterDhuhr);

      expect(next.next.slot, PrayerSlot.asr);
      expect(next.current?.slot, PrayerSlot.dhuhr);
      expect(next.remaining, greaterThan(Duration.zero));
    });

    test('rolls over to tomorrow Fajr once Isha has passed', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final afterIsha = day[PrayerSlot.isha].time.add(const Duration(hours: 1));

      final next = PrayerService.next(kochi, afterIsha);

      expect(next.next.slot, PrayerSlot.fajr);
      expect(next.current?.slot, PrayerSlot.isha);
      expect(next.next.time.day, 22);
      expect(next.remaining, greaterThan(Duration.zero));
    });

    test('before Fajr there is no current window', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final beforeFajr =
          day[PrayerSlot.fajr].time.subtract(const Duration(minutes: 30));

      final next = PrayerService.next(kochi, beforeFajr);

      expect(next.next.slot, PrayerSlot.fajr);
      expect(next.current, isNull);
      expect(next.progress, 0);
    });

    test('progress runs from zero to one across a window', () {
      final day = PrayerService.day(kochi, DateTime(2026, 6, 21));
      final dhuhr = day[PrayerSlot.dhuhr].time;
      final asr = day[PrayerSlot.asr].time;
      final midpoint = dhuhr.add(asr.difference(dhuhr) ~/ 2);

      final atStart =
          PrayerService.next(kochi, dhuhr.add(const Duration(seconds: 1)));
      final atMiddle = PrayerService.next(kochi, midpoint);
      final atEnd =
          PrayerService.next(kochi, asr.subtract(const Duration(seconds: 1)));

      expect(atStart.progress, lessThan(0.01));
      expect(atMiddle.progress, closeTo(0.5, 0.01));
      expect(atEnd.progress, greaterThan(0.99));
    });
  });

  group('PrayerService.upcoming', () {
    test('returns only enabled slots, in order, after the given instant', () {
      final config = kochi.copyWith(notify: const {
        'fajr': true,
        'sunrise': false,
        'dhuhr': false,
        'asr': false,
        'maghrib': true,
        'isha': false,
      });
      final from = DateTime(2026, 6, 21, 0, 1);

      final times = PrayerService.upcoming(config, from, days: 3);

      expect(times.every((t) => t.time.isAfter(from)), isTrue);
      expect(
        times.map((t) => t.slot).toSet(),
        {PrayerSlot.fajr, PrayerSlot.maghrib},
      );
      expect(times.length, 6); // two slots across three days
      for (var i = 1; i < times.length; i++) {
        expect(times[i].time.isAfter(times[i - 1].time), isTrue);
      }
    });

    test('is empty when every slot is switched off', () {
      final silent = kochi.copyWith(notify: const {
        'fajr': false,
        'sunrise': false,
        'dhuhr': false,
        'asr': false,
        'maghrib': false,
        'isha': false,
      });

      expect(PrayerService.upcoming(silent, DateTime(2026, 6, 21)), isEmpty);
    });
  });

  group('HijriDate', () {
    test('maps the calendar epoch to 1 Muharram 1', () {
      // The epoch is 16 July 622 CE in the *Julian* calendar, which is 19 July
      // 622 in the proleptic Gregorian calendar DateTime uses.
      final h = HijriDate.fromGregorian(DateTime(622, 7, 19));

      expect(h.year, 1);
      expect(h.month, 1);
      expect(h.day, 1);

      // The day before is the last of the preceding year.
      final before = HijriDate.fromGregorian(DateTime(622, 7, 18));
      expect(before.month, 12);
    });

    test('matches a known present-day conversion', () {
      // 1448 AH began on 16 June 2026 by the tabular calendar; 6 October is
      // 112 days later, which lands in the fourth month.
      final h = HijriDate.fromGregorian(DateTime(2026, 10, 6));

      expect(h.year, 1448);
      expect(h.month, 4);
      expect(h.day, 23);
    });

    test('produces in-range month and day values across a long span', () {
      var date = DateTime(2000, 1, 1);
      final end = DateTime(2050, 1, 1);
      while (date.isBefore(end)) {
        final h = HijriDate.fromGregorian(date);
        expect(h.month, inInclusiveRange(1, 12));
        expect(h.day, inInclusiveRange(1, 30));
        expect(h.monthName, isNotEmpty);
        date = date.add(const Duration(days: 17));
      }
    });

    test('advances by one Hijri day per Gregorian day', () {
      var date = DateTime(2026, 1, 1);
      var previous = HijriDate.fromGregorian(date);
      for (var i = 0; i < 400; i++) {
        date = date.add(const Duration(days: 1));
        final current = HijriDate.fromGregorian(date);
        final stepped = current.day == previous.day + 1;
        final rolledMonth = current.day == 1 && current.month != previous.month;
        expect(
          stepped || rolledMonth,
          isTrue,
          reason: '${previous.label} -> ${current.label} is not a single day',
        );
        previous = current;
      }
    });

    test('a Hijri year is roughly 354 days', () {
      final start = HijriDate.fromGregorian(DateTime(2026, 1, 1));
      final later = HijriDate.fromGregorian(DateTime(2026, 1, 1)
          .add(const Duration(days: 354)));

      expect(later.year, start.year + 1);
    });

    test('flags Ramadan', () {
      expect(const HijriDate(1447, 9, 1).isRamadan, isTrue);
      expect(const HijriDate(1447, 8, 1).isRamadan, isFalse);
    });
  });

  group('PrayerCities', () {
    test('ids are unique', () {
      final ids = PrayerCities.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('coordinates are in range', () {
      for (final c in PrayerCities.all) {
        expect(c.lat, inInclusiveRange(-90, 90), reason: c.label);
        expect(c.lng, inInclusiveRange(-180, 180), reason: c.label);
      }
    });

    test('search ranks a name prefix above a region match', () {
      final results = PrayerCities.search('ko');
      expect(results.first.name.toLowerCase().startsWith('ko'), isTrue);
    });

    test('search matches on region too', () {
      final kerala = PrayerCities.search('Kerala');
      expect(kerala, isNotEmpty);
      expect(kerala.every((c) => c.region == 'Kerala'), isTrue);
    });

    test('empty search returns everything', () {
      expect(PrayerCities.search('   ').length, PrayerCities.all.length);
    });

    test('nearest resolves a fix to the expected city', () {
      // A point a few kilometres from the centre of Kochi.
      final near = PrayerCities.nearest(9.95, 76.30);
      expect(near.id, 'in-kochi');
    });

    test('byId round-trips, and is null for an unknown id', () {
      expect(PrayerCities.byId('sa-makkah')?.name, 'Makkah');
      expect(PrayerCities.byId('nope'), isNull);
      expect(PrayerCities.byId(null), isNull);
    });
  });

  group('PrayerConfig', () {
    test('survives a JSON round-trip', () {
      final config = kochi
          .copyWith(madhab: PrayerMadhab.hanafi, exactAlarms: true)
          .withOffset(PrayerSlot.fajr, -3)
          .withNotify(PrayerSlot.sunrise, true);

      final restored = PrayerConfig.fromJson(config.toJson());

      expect(restored.enabled, config.enabled);
      expect(restored.cityId, config.cityId);
      expect(restored.lat, config.lat);
      expect(restored.method, config.method);
      expect(restored.madhab, PrayerMadhab.hanafi);
      expect(restored.exactAlarms, isTrue);
      expect(restored.offsetFor(PrayerSlot.fajr), -3);
      expect(restored.notifyFor(PrayerSlot.sunrise), isTrue);
    });

    test('falls back to safe defaults on a malformed blob', () {
      final restored = PrayerConfig.fromJson({
        'enabled': 'yes',
        'method': 'not_a_method',
        'notify': 'broken',
        'offsets': 42,
      });

      expect(restored.enabled, isFalse);
      expect(restored.method, PrayerMethod.karachi);
      expect(restored.notifyFor(PrayerSlot.fajr), isTrue);
      expect(restored.offsetFor(PrayerSlot.fajr), 0);
    });

    test('clamps an out-of-range Hijri offset', () {
      expect(PrayerConfig.fromJson({'hijri_offset': 9}).hijriOffset, 2);
      expect(PrayerConfig.fromJson({'hijri_offset': -9}).hijriOffset, -2);
    });

    test('Hijri offset shifts the displayed date', () {
      final plain = PrayerService.day(kochi, DateTime(2026, 10, 6));
      final nudged = PrayerService.day(
          kochi.copyWith(hijriOffset: -1), DateTime(2026, 10, 6));

      expect(plain.hijri.day, 23);
      expect(nudged.hijri.day, 22);
    });

    test('withCity adopts the city and clears a device fix', () {
      final city = PrayerCities.byId('ae-dubai')!;
      final config = kochi.withFix(25.0, 55.0).withCity(city);

      expect(config.cityId, 'ae-dubai');
      expect(config.lat, city.lat);
      expect(config.fromDeviceLocation, isFalse);
      expect(config.locationLabel, 'Dubai, UAE');
    });

    test('withFix keeps exact coordinates and labels by nearest city', () {
      final config = kochi.withFix(9.95, 76.30);

      expect(config.cityId, isNull);
      expect(config.lat, 9.95);
      expect(config.lng, 76.30);
      expect(config.fromDeviceLocation, isTrue);
      expect(config.locationLabel, 'Near Kochi');
    });

    test('anyNotifications tracks the master switch and the slots', () {
      expect(kochi.anyNotifications, isTrue);
      expect(kochi.copyWith(enabled: false).anyNotifications, isFalse);

      final silent = kochi.copyWith(notify: const {
        'fajr': false,
        'sunrise': false,
        'dhuhr': false,
        'asr': false,
        'maghrib': false,
        'isha': false,
      });
      expect(silent.anyNotifications, isFalse);
    });
  });
}

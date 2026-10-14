import 'package:family_finance/v3/data/prayer/prayer_config.dart';
import 'package:family_finance/v3/data/prayer/prayer_ending_soon.dart';
import 'package:family_finance/v3/data/prayer/prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = PrayerConfig(enabled: true); // Kochi defaults, 20 / 5 min
  final morning = DateTime(2026, 10, 14, 0, 30);
  final today = PrayerService.day(config, DateTime(2026, 10, 14));
  final tomorrow = PrayerService.day(config, DateTime(2026, 10, 15));

  EndingWindow todays(PrayerSlot slot, List<EndingWindow> ws) => ws.firstWhere(
      (w) => w.slot == slot && w.end.day == 14 && w.end.month == 10);

  test('each prayer ends where the next begins; reminder starts 20 min before',
      () {
    final ws = endingSoonWindows(config, morning);
    final dhuhr = todays(PrayerSlot.dhuhr, ws);
    expect(dhuhr.end, today[PrayerSlot.asr].time);
    expect(dhuhr.start,
        today[PrayerSlot.asr].time.subtract(const Duration(minutes: 20)));
    expect(dhuhr.nextSlot, PrayerSlot.asr);

    expect(todays(PrayerSlot.fajr, ws).end, today[PrayerSlot.sunrise].time);
    expect(todays(PrayerSlot.asr, ws).end, today[PrayerSlot.maghrib].time);
    expect(todays(PrayerSlot.maghrib, ws).end, today[PrayerSlot.isha].time);
  });

  test('Isha runs to the middle of the night, not to Fajr', () {
    final ws = endingSoonWindows(config, morning);
    final isha = ws.firstWhere((w) =>
        w.slot == PrayerSlot.isha &&
        w.start.isAfter(today[PrayerSlot.isha].time.subtract(
            const Duration(seconds: 1))));
    final maghrib = today[PrayerSlot.maghrib].time;
    final fajr = tomorrow[PrayerSlot.fajr].time;
    expect(isha.end, maghrib.add(fajr.difference(maghrib) ~/ 2));
    expect(isha.end.isBefore(fajr), isTrue);
  });

  test('switched-off prayers and ended windows are left out', () {
    final noAsr = config.copyWith(
      endingSoonFor: {...config.endingSoonFor, 'asr': false},
    );
    final afternoon = today[PrayerSlot.asr].time.add(const Duration(hours: 1));
    final ws = endingSoonWindows(noAsr, afternoon);
    expect(ws.any((w) => w.slot == PrayerSlot.asr), isFalse);
    // Today's Fajr and Dhuhr are over; the first left is today's Maghrib.
    expect(ws.first.slot, PrayerSlot.maghrib);
    expect(ws.every((w) => w.end.isAfter(afternoon)), isTrue);
    expect(ws, orderedEquals([...ws]..sort((a, b) => a.start.compareTo(b.start))));
  });

  test('a lead longer than the prayer starts at the prayer itself', () {
    final ws = endingSoonWindows(config.copyWith(endingSoonLead: 90), morning);
    final maghrib = todays(PrayerSlot.maghrib, ws);
    expect(maghrib.start, today[PrayerSlot.maghrib].time);
  });

  test('off, or prayer times off: no windows', () {
    expect(endingSoonWindows(config.copyWith(endingSoon: false), morning),
        isEmpty);
    expect(endingSoonWindows(const PrayerConfig(), morning), isEmpty);
  });

  test('settings survive a save and load', () {
    final c = config.copyWith(
      endingSoonLead: 30,
      endingSoonRepeat: 3,
      endingSoonFor: {...config.endingSoonFor, 'isha': false},
    );
    final back = PrayerConfig.fromJson(c.toJson());
    expect(back.endingSoonLead, 30);
    expect(back.endingSoonRepeat, 3);
    expect(back.endingSoonOn(PrayerSlot.isha), isFalse);
    expect(back.endingSoonOn(PrayerSlot.asr), isTrue);
  });
}

import 'package:family_finance/v3/data/prayer/prayer_banner.dart';
import 'package:family_finance/v3/data/prayer/prayer_config.dart';
import 'package:family_finance/v3/data/prayer/prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kochi = PrayerConfig(
    enabled: true,
    cityId: 'in-kochi',
    lat: 9.9312,
    lng: 76.2673,
    locationLabel: 'Kochi, Kerala',
  );

  // Mid-afternoon: Dhuhr has been and gone, Asr is next.
  final afternoon = DateTime(2026, 10, 7, 15, 20);
  final day = PrayerService.day(kochi, afternoon);
  final next = PrayerService.next(kochi, afternoon);

  // Pre-dawn: nothing is in progress, which is the edge case that breaks
  // naive "current prayer" formatting.
  final predawn = DateTime(2026, 10, 7, 3, 30);
  final earlyDay = PrayerService.day(kochi, predawn);
  final earlyNext = PrayerService.next(kochi, predawn);

  group('showBanner', () {
    test('requires both the feature and the banner to be on', () {
      expect(kochi.showBanner, isTrue, reason: 'banner defaults on');
      expect(kochi.copyWith(bannerEnabled: false).showBanner, isFalse);
      expect(kochi.copyWith(enabled: false).showBanner, isFalse);
    });
  });

  group('titleFor', () {
    test('names the next prayer and its time', () {
      final title = PrayerBanner.titleFor(kochi, next);

      expect(title, contains('Asr'));
      expect(title, contains('PM'));
    });

    test('currentEnds phrases the title around the current window', () {
      final title = PrayerBanner.titleFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.currentEnds),
        next,
      );

      expect(title, 'Dhuhr ends at ${_clock(next.next.time)}');
    });

    test('currentEnds falls back before Fajr, when nothing is in progress', () {
      expect(earlyNext.current, isNull, reason: 'test premise');

      final title = PrayerBanner.titleFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.currentEnds),
        earlyNext,
      );

      expect(title, startsWith('Fajr at'));
      expect(title, isNot(contains('ends')));
    });
  });

  group('bodyFor', () {
    test('nextOnly shows the Arabic name', () {
      expect(PrayerBanner.bodyFor(kochi, day, next), next.next.slot.arabic);
    });

    test('allTimes lists every prayer of the day', () {
      final body = PrayerBanner.bodyFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.allTimes),
        day,
        next,
      );

      for (final slot in PrayerSlot.values) {
        expect(body, contains(slot.label));
      }
    });

    test('nextAndCurrent names both', () {
      final body = PrayerBanner.bodyFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.nextAndCurrent),
        day,
        next,
      );

      expect(body, contains('Now Dhuhr'));
      expect(body, contains('Next Asr'));
    });

    test('nextAndCurrent before Fajr says so rather than naming nothing', () {
      final body = PrayerBanner.bodyFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.nextAndCurrent),
        earlyDay,
        earlyNext,
      );

      expect(body, 'Before Fajr');
    });

    test('currentEnds before Fajr does not claim a prayer is running', () {
      final body = PrayerBanner.bodyFor(
        kochi.copyWith(bannerContent: PrayerBannerContent.currentEnds),
        earlyDay,
        earlyNext,
      );

      expect(body, 'Fajr has not started yet');
    });

    test('every content mode produces non-empty text at both times of day', () {
      for (final content in PrayerBannerContent.values) {
        final config = kochi.copyWith(bannerContent: content);

        expect(PrayerBanner.titleFor(config, next).trim(), isNotEmpty);
        expect(PrayerBanner.bodyFor(config, day, next).trim(), isNotEmpty);
        expect(PrayerBanner.titleFor(config, earlyNext).trim(), isNotEmpty);
        expect(
          PrayerBanner.bodyFor(config, earlyDay, earlyNext).trim(),
          isNotEmpty,
          reason: '${content.name} produced an empty body before Fajr',
        );
      }
    });
  });

  group('banner settings survive storage', () {
    test('round-trip through JSON', () {
      final config = kochi.copyWith(
        bannerEnabled: false,
        bannerContent: PrayerBannerContent.allTimes,
        bannerTheme: PrayerBannerTheme.emerald,
        bannerTint: false,
        bannerOnLockScreen: false,
      );

      final restored = PrayerConfig.fromJson(config.toJson());

      expect(restored.bannerEnabled, isFalse);
      expect(restored.bannerContent, PrayerBannerContent.allTimes);
      expect(restored.bannerTheme, PrayerBannerTheme.emerald);
      expect(restored.bannerTint, isFalse);
      expect(restored.bannerOnLockScreen, isFalse);
    });

    test('a blob written before the banner existed keeps the defaults', () {
      // Upgrading from 1.9.1 must not land the user with a broken banner.
      final legacy = PrayerConfig.fromJson({
        'enabled': true,
        'city_id': 'in-kochi',
        'method': 'karachi',
      });

      expect(legacy.bannerEnabled, isTrue);
      expect(legacy.bannerContent, PrayerBannerContent.nextOnly);
      expect(legacy.bannerTheme, PrayerBannerTheme.aurora);
      expect(legacy.bannerTint, isTrue);
      expect(legacy.bannerOnLockScreen, isTrue);
    });

    test('a malformed banner blob degrades to the defaults', () {
      final broken = PrayerConfig.fromJson({
        'banner_enabled': 'yes',
        'banner_content': 'not_a_mode',
        'banner_theme': 42,
      });

      expect(broken.bannerEnabled, isTrue);
      expect(broken.bannerContent, PrayerBannerContent.nextOnly);
      expect(broken.bannerTheme, PrayerBannerTheme.aurora);
    });
  });

  group('theme metadata', () {
    test('only aurora follows the prayer colour', () {
      expect(PrayerBannerTheme.aurora.followsPrayer, isTrue);
      for (final t in PrayerBannerTheme.values.where((t) => t != PrayerBannerTheme.aurora)) {
        expect(t.followsPrayer, isFalse, reason: t.name);
      }
    });

    test('every theme and content mode has a label', () {
      for (final t in PrayerBannerTheme.values) {
        expect(t.label.trim(), isNotEmpty);
      }
      for (final c in PrayerBannerContent.values) {
        expect(c.label.trim(), isNotEmpty);
        expect(c.description.trim(), isNotEmpty);
      }
    });
  });
}

String _clock(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

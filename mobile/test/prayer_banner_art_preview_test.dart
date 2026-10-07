import 'dart:io';

import 'package:family_finance/v3/data/prayer/prayer_config.dart';
import 'package:family_finance/v3/data/prayer/prayer_service.dart';
import 'package:family_finance/v3/widgets/prayer_banner_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the banner art to `build/banner_preview/` so the design can be
/// looked at, and asserts the renderer produces a real PNG for every
/// combination rather than silently returning null.
///
/// The bundled Inter faces are loaded explicitly: `flutter_test` otherwise
/// substitutes a placeholder font that draws every glyph as a box, which would
/// make the previews useless for judging the layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final weight in ['400', '500', '600', '700']) {
      loader.addFont(
        File('assets/fonts/Inter-$weight.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();

    // Inter has no Arabic, and the test harness has none of the Noto faces an
    // Android device would fall back to. Registering a system font that does
    // carry Arabic under the first fallback name makes the preview represent
    // what a device actually draws, instead of a row of empty boxes.
    for (final candidate in const [
      r'C:\Windows\Fonts\arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]) {
      final file = File(candidate);
      if (!file.existsSync()) continue;
      final arabic = FontLoader('Noto Naskh Arabic')
        ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await arabic.load();
      break;
    }
  });

  const base = PrayerConfig(
    enabled: true,
    cityId: 'in-kochi',
    lat: 9.9312,
    lng: 76.2673,
    locationLabel: 'Kochi, Kerala',
  );

  // Mid-afternoon, so there is both a current and a next prayer to draw.
  final at = DateTime(2026, 10, 7, 15, 20);
  final day = PrayerService.day(base, at);
  final next = PrayerService.next(base, at);

  final outDir = Directory('build/banner_preview');

  setUpAll(() {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
  });

  Future<void> renderTo(String name, PrayerConfig config) async {
    final bytes =
        await PrayerBannerArt.render(config: config, day: day, next: next);

    expect(bytes, isNotNull, reason: '$name produced no image');
    expect(bytes!.length, greaterThan(2000),
        reason: '$name produced a suspiciously small image');
    // PNG magic number, so a truncated or mis-encoded buffer fails loudly.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

    File('${outDir.path}/$name.png').writeAsBytesSync(bytes);
  }

  group('every theme renders', () {
    for (final theme in PrayerBannerTheme.values) {
      test(theme.name, () async {
        await renderTo('theme_${theme.name}', base.copyWith(bannerTheme: theme));
      });
    }
  });

  group('every content mode renders', () {
    for (final content in PrayerBannerContent.values) {
      test(content.name, () async {
        await renderTo(
          'content_${content.name}',
          base.copyWith(bannerContent: content),
        );
      });
    }
  });

  test('renders before Fajr, when there is no current prayer', () async {
    final dawn = DateTime(2026, 10, 7, 3, 30);
    final earlyDay = PrayerService.day(base, dawn);
    final earlyNext = PrayerService.next(base, dawn);

    expect(earlyNext.current, isNull, reason: 'test premise');

    for (final content in PrayerBannerContent.values) {
      final bytes = await PrayerBannerArt.render(
        config: base.copyWith(bannerContent: content),
        day: earlyDay,
        next: earlyNext,
      );
      expect(bytes, isNotNull, reason: 'null current broke ${content.name}');
    }
  });

  test('a very long location label does not overflow the render', () async {
    await renderTo(
      'long_location',
      base.copyWith(
        locationLabel: 'Thiruvananthapuram, Kerala, India, Somewhere Far',
      ),
    );
  });
}

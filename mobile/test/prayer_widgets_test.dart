import 'package:family_finance/v3/data/prayer/prayer_config.dart';
import 'package:family_finance/v3/data/prayer/prayer_controller.dart';
import 'package:family_finance/v3/screens/prayer_settings_v3.dart';
import 'package:family_finance/v3/screens/prayer_v3.dart';
import 'package:family_finance/v3/v3_nav.dart';
import 'package:family_finance/v3/widgets/prayer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the prayer surfaces to prove they build and show the right thing.
///
/// The notification plugin is not available under `flutter test`, so the
/// scheduling calls these screens make throw `MissingPluginException`
/// internally. That is caught and logged by design, which is exactly what
/// should happen on a device where the user has denied notifications — so
/// these tests also cover that path.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const kochi = PrayerConfig(
    enabled: true,
    cityId: 'in-kochi',
    lat: 9.9312,
    lng: 76.2673,
    locationLabel: 'Kochi, Kerala',
  );

  /// Builds a controller in a known state and guarantees its minute timer is
  /// cancelled before the test ends.
  ///
  /// The setup runs inside [WidgetTester.runAsync] because enabling the
  /// feature reaches the notification plugin, and those platform-channel
  /// replies are delivered on the real event loop — which the fake-async zone
  /// `testWidgets` normally installs would never pump.
  Future<PrayerController> controllerWith(
    WidgetTester tester,
    PrayerConfig config,
  ) async {
    late PrayerController controller;
    await tester.runAsync(() async {
      controller = PrayerController();
      await controller.update(config);
    });
    addTearDown(controller.dispose);
    await tester.pump();
    return controller;
  }

  Widget host(PrayerController controller, Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider(create: (_) => V3Nav()),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  group('PrayerCard', () {
    testWidgets('builds nothing while the feature is off', (tester) async {
      final controller =
          await controllerWith(tester, const PrayerConfig(enabled: false));

      await tester.pumpWidget(host(controller, const PrayerCard()));

      expect(find.byType(PrayerCard), findsOneWidget);
      // The card collapses entirely rather than rendering a hidden shell.
      expect(tester.getSize(find.byType(PrayerCard)), Size.zero);
    });

    testWidgets('builds nothing when show-on-home is off', (tester) async {
      final controller =
          await controllerWith(tester, kochi.copyWith(showOnHome: false));

      await tester.pumpWidget(host(controller, const PrayerCard()));

      expect(tester.getSize(find.byType(PrayerCard)), Size.zero);
    });

    testWidgets('shows the next prayer, a countdown and the location',
        (tester) async {
      final controller = await controllerWith(tester, kochi);
      await tester.pumpWidget(host(controller, const PrayerCard()));

      final next = controller.next!;
      expect(find.text(next.next.slot.label), findsWidgets);
      expect(find.text('Kochi, Kerala'), findsOneWidget);

      // Every slot is labelled along the rail beneath the card.
      for (final slot in PrayerSlot.values) {
        expect(find.text(slot.label), findsWidgets,
            reason: '${slot.label} should appear on the rail');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the card invokes the callback', (tester) async {
      final controller = await controllerWith(tester, kochi);
      var taps = 0;

      await tester.pumpWidget(
          host(controller, PrayerCard(onTap: () => taps++)));
      await tester.tap(find.byType(PrayerCard));

      expect(taps, 1);
    });
  });

  group('PrayerV3 page', () {
    testWidgets('lists all six times with the next one marked',
        (tester) async {
      final controller = await controllerWith(tester, kochi);

      await tester.pumpWidget(host(controller, const PrayerV3()));
      await tester.pump();

      for (final slot in PrayerSlot.values) {
        expect(find.text(slot.label), findsWidgets);
      }
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state while the feature is off',
        (tester) async {
      final controller =
          await controllerWith(tester, const PrayerConfig(enabled: false));

      await tester.pumpWidget(host(controller, const PrayerV3()));

      expect(find.text('Prayer times are off'), findsOneWidget);
      expect(find.text('Set up prayer times'), findsOneWidget);
    });

    testWidgets('renders a Hanafi configuration without error',
        (tester) async {
      final controller = await controllerWith(
          tester, kochi.copyWith(madhab: PrayerMadhab.hanafi));

      await tester.pumpWidget(host(controller, const PrayerV3()));
      await tester.pump();

      // The Calculation section sits below the fold and the list builds
      // lazily, so it has to be scrolled into view before it exists.
      await tester.scrollUntilVisible(find.text('Hanafi'), 200,
          scrollable: find.byType(Scrollable).first);

      expect(find.text('Hanafi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PrayerSettingsV3', () {
    testWidgets('collapses to just the master switch when off',
        (tester) async {
      final controller =
          await controllerWith(tester, const PrayerConfig(enabled: false));

      await tester.pumpWidget(host(controller, const PrayerSettingsV3()));

      expect(find.text('Prayer times'), findsOneWidget);
      // None of the configuration sections exist while it is off.
      expect(find.text('Location'), findsNothing);
      expect(find.text('Calculation'), findsNothing);
      expect(find.text('Alerts'), findsNothing);
    });

    testWidgets('reveals every section once enabled', (tester) async {
      final controller = await controllerWith(tester, kochi);

      await tester.pumpWidget(host(controller, const PrayerSettingsV3()));
      await tester.pump();

      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('CALCULATION'), findsOneWidget);
      expect(find.text('ALERTS'), findsOneWidget);
      expect(find.text('Kochi, Kerala'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls through the whole settings list without overflow',
        (tester) async {
      final controller = await controllerWith(tester, kochi);

      await tester.pumpWidget(host(controller, const PrayerSettingsV3()));
      await tester.pump();

      await tester.drag(
          find.byType(ListView).first, const Offset(0, -600));
      await tester.pump();

      // A RenderFlex overflow surfaces here if any row is too wide.
      expect(tester.takeException(), isNull);
    });
  });
}

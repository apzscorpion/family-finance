import 'package:geolocator/geolocator.dart';

import '../../../services/app_log.dart';

enum PrayerFixStatus {
  ok,

  /// Location is switched off device-wide.
  serviceOff,

  /// Declined this time; asking again is allowed.
  denied,

  /// Declined permanently — only Settings can undo it.
  blocked,

  /// Timed out or the platform returned an error.
  failed,
}

class PrayerFix {
  final PrayerFixStatus status;
  final double? lat;
  final double? lng;

  const PrayerFix(this.status, {this.lat, this.lng});

  bool get ok => status == PrayerFixStatus.ok && lat != null && lng != null;

  String get message => switch (status) {
        PrayerFixStatus.ok => 'Location updated',
        PrayerFixStatus.serviceOff =>
          'Turn on location on your device, or pick a city instead',
        PrayerFixStatus.denied =>
          'Location permission denied — pick a city instead',
        PrayerFixStatus.blocked =>
          'Location is blocked in system settings — pick a city instead',
        PrayerFixStatus.failed =>
          'Could not get a location — pick a city instead',
      };
}

/// A single coarse location read, used only when the user taps "Use my
/// location".
///
/// There is no stream, no background tracking and no repeat polling: the fix
/// is taken once, converted to coordinates and stored. Prayer times shift by
/// under a minute across a whole city, so there is nothing to gain from
/// following the device around — and a great deal of battery to lose.
class PrayerLocation {
  PrayerLocation._();

  /// Low accuracy is deliberate: it lets Android answer from the network
  /// provider instead of waking the GPS chip.
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 15),
  );

  static Future<PrayerFix> fetch() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PrayerFix(PrayerFixStatus.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const PrayerFix(PrayerFixStatus.blocked);
      }
      if (permission == LocationPermission.denied) {
        return const PrayerFix(PrayerFixStatus.denied);
      }

      // A cached fix is free and good enough for a city-level answer, so it is
      // preferred over waking the radio.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        return PrayerFix(PrayerFixStatus.ok,
            lat: cached.latitude, lng: cached.longitude);
      }

      final position =
          await Geolocator.getCurrentPosition(locationSettings: _settings);
      return PrayerFix(PrayerFixStatus.ok,
          lat: position.latitude, lng: position.longitude);
    } catch (err, stack) {
      AppLog.error('PrayerLocation.fetch', err, stack);
      return const PrayerFix(PrayerFixStatus.failed);
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_log.dart';
import 'prayer_cities.dart';

/// The six rows the prayer screens show. Sunrise is not a prayer — it is the
/// end of Fajr's window — but it is displayed and can be alerted on, so it
/// carries the same shape as the rest.
enum PrayerSlot { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerSlotLabel on PrayerSlot {
  String get key => name;

  String get label => switch (this) {
        PrayerSlot.fajr => 'Fajr',
        PrayerSlot.sunrise => 'Sunrise',
        PrayerSlot.dhuhr => 'Dhuhr',
        PrayerSlot.asr => 'Asr',
        PrayerSlot.maghrib => 'Maghrib',
        PrayerSlot.isha => 'Isha',
      };

  String get arabic => switch (this) {
        PrayerSlot.fajr => 'الفجر',
        PrayerSlot.sunrise => 'الشروق',
        PrayerSlot.dhuhr => 'الظهر',
        PrayerSlot.asr => 'العصر',
        PrayerSlot.maghrib => 'المغرب',
        PrayerSlot.isha => 'العشاء',
      };

  bool get isPrayer => this != PrayerSlot.sunrise;

  static PrayerSlot? fromKey(String? key) {
    for (final s in PrayerSlot.values) {
      if (s.name == key) return s;
    }
    return null;
  }
}

/// How Asr is derived. Mirrors adhan's `Madhab` without leaking the package
/// into the UI layer.
enum PrayerMadhab { shafi, hanafi }

/// The calculation authority. These map 1:1 onto adhan's `CalculationMethod`,
/// restricted to the ones that are actually in use somewhere — offering all
/// fourteen with no guidance is worse than offering nine with labels.
enum PrayerMethod {
  karachi,
  muslimWorldLeague,
  ummAlQura,
  dubai,
  qatar,
  kuwait,
  egyptian,
  singapore,
  turkey,
  northAmerica,
  moonsighting,
  tehran,
}

extension PrayerMethodLabel on PrayerMethod {
  String get label => switch (this) {
        PrayerMethod.karachi => 'University of Islamic Sciences, Karachi',
        PrayerMethod.muslimWorldLeague => 'Muslim World League',
        PrayerMethod.ummAlQura => 'Umm al-Qura, Makkah',
        PrayerMethod.dubai => 'Dubai',
        PrayerMethod.qatar => 'Qatar',
        PrayerMethod.kuwait => 'Kuwait',
        PrayerMethod.egyptian => 'Egyptian General Authority',
        PrayerMethod.singapore => 'Singapore (MUIS)',
        PrayerMethod.turkey => 'Diyanet, Türkiye',
        PrayerMethod.northAmerica => 'ISNA, North America',
        PrayerMethod.moonsighting => 'Moonsighting Committee',
        PrayerMethod.tehran => 'Institute of Geophysics, Tehran',
      };

  /// The short form used in the summary line under the card.
  String get short => switch (this) {
        PrayerMethod.karachi => 'Karachi',
        PrayerMethod.muslimWorldLeague => 'MWL',
        PrayerMethod.ummAlQura => 'Umm al-Qura',
        PrayerMethod.dubai => 'Dubai',
        PrayerMethod.qatar => 'Qatar',
        PrayerMethod.kuwait => 'Kuwait',
        PrayerMethod.egyptian => 'Egyptian',
        PrayerMethod.singapore => 'Singapore',
        PrayerMethod.turkey => 'Diyanet',
        PrayerMethod.northAmerica => 'ISNA',
        PrayerMethod.moonsighting => 'Moonsighting',
        PrayerMethod.tehran => 'Tehran',
      };
}

/// What the ongoing banner shows.
enum PrayerBannerContent {
  /// Just the upcoming prayer and a live countdown.
  nextOnly,

  /// The upcoming prayer plus the one currently in.
  nextAndCurrent,

  /// Every prayer of the day, expanded.
  allTimes,

  /// Only when the current window closes.
  currentEnds,
}

extension PrayerBannerContentInfo on PrayerBannerContent {
  String get label => switch (this) {
        PrayerBannerContent.nextOnly => 'Next prayer only',
        PrayerBannerContent.nextAndCurrent => 'Next and current',
        PrayerBannerContent.allTimes => 'All prayer times',
        PrayerBannerContent.currentEnds => 'Current prayer ends at',
      };

  String get description => switch (this) {
        PrayerBannerContent.nextOnly =>
          'Which prayer is next, with a live countdown',
        PrayerBannerContent.nextAndCurrent =>
          'The next prayer and the one you are in',
        PrayerBannerContent.allTimes =>
          "All six of today's times when expanded",
        PrayerBannerContent.currentEnds =>
          'How long the current prayer window has left',
      };
}

/// Background art for the expanded banner image.
///
/// Android cannot blur what sits behind a notification, so the frosted look is
/// drawn into this image rather than sampled from the wallpaper.
enum PrayerBannerTheme { aurora, dusk, emerald, midnight, sand, minimal }

extension PrayerBannerThemeInfo on PrayerBannerTheme {
  String get label => switch (this) {
        PrayerBannerTheme.aurora => 'Aurora',
        PrayerBannerTheme.dusk => 'Dusk',
        PrayerBannerTheme.emerald => 'Emerald',
        PrayerBannerTheme.midnight => 'Midnight',
        PrayerBannerTheme.sand => 'Sand',
        PrayerBannerTheme.minimal => 'Minimal',
      };

  /// Follows the time of day rather than a fixed palette.
  bool get followsPrayer => this == PrayerBannerTheme.aurora;
}

/// Device-local prayer settings.
///
/// Deliberately *not* stored in `user_preferences`: that table is family
/// scoped, so a toggle there would push one member's Fajr alert onto every
/// other member's phone. These belong to the person holding the device.
class PrayerConfig {
  /// Master switch. Everything — the card, the page, the timers and the
  /// scheduled notifications — is inert while this is false.
  final bool enabled;

  /// `null` once a GPS fix has been used, since the coordinates then no longer
  /// correspond to a bundled entry.
  final String? cityId;
  final double lat;
  final double lng;
  final String locationLabel;

  /// True when [lat]/[lng] came from a device fix rather than the picker.
  final bool fromDeviceLocation;

  final PrayerMethod method;
  final PrayerMadhab madhab;

  /// Per-slot notification switches, keyed by [PrayerSlot.name].
  final Map<String, bool> notify;

  /// Per-slot minute offsets, keyed by [PrayerSlot.name]. Negative fires early.
  /// Local mosques often run a few minutes off the computed time.
  final Map<String, int> offsets;

  /// Exact alarms need `SCHEDULE_EXACT_ALARM`, which is the single biggest
  /// battery lever here, so it is opt-in rather than the default.
  final bool exactAlarms;

  /// Show the next prayer inside the ongoing lock-screen notification.
  final bool showInLiveNotification;

  /// Show the card on the home screen. Off means the feature still runs
  /// notifications but stays out of the finance view.
  final bool showOnHome;

  /// Show the ongoing banner in the shade and on the lock screen.
  final bool bannerEnabled;

  /// What the banner shows.
  final PrayerBannerContent bannerContent;

  /// Background art for the expanded image.
  final PrayerBannerTheme bannerTheme;

  /// Tint the collapsed banner with the prayer's colour. Android only honours
  /// this on ongoing notifications.
  final bool bannerTint;

  /// Show the banner's detail on the lock screen rather than hiding it behind
  /// "contents hidden".
  final bool bannerOnLockScreen;

  /// Days to add to the computed Hijri date, −2 to +2.
  ///
  /// The tabular calendar is arithmetic, so it routinely lands a day away from
  /// the locally announced month. Rather than claim the computed date is
  /// authoritative, this lets the date be nudged to match the local mosque.
  final int hijriOffset;

  const PrayerConfig({
    this.enabled = false,
    this.cityId,
    this.lat = 9.9312,
    this.lng = 76.2673,
    this.locationLabel = 'Kochi, Kerala',
    this.fromDeviceLocation = false,
    this.method = PrayerMethod.karachi,
    this.madhab = PrayerMadhab.shafi,
    this.notify = const {
      'fajr': true,
      'sunrise': false,
      'dhuhr': true,
      'asr': true,
      'maghrib': true,
      'isha': true,
    },
    this.offsets = const {},
    this.exactAlarms = false,
    this.showInLiveNotification = true,
    this.showOnHome = true,
    this.bannerEnabled = true,
    this.bannerContent = PrayerBannerContent.nextOnly,
    this.bannerTheme = PrayerBannerTheme.aurora,
    this.bannerTint = true,
    this.bannerOnLockScreen = true,
    this.hijriOffset = 0,
  });

  bool notifyFor(PrayerSlot slot) => notify[slot.name] ?? false;
  int offsetFor(PrayerSlot slot) => offsets[slot.name] ?? 0;

  /// True when at least one slot would produce an alert.
  bool get anyNotifications =>
      enabled && PrayerSlot.values.any((s) => notifyFor(s));

  /// True when the ongoing banner should currently be posted.
  bool get showBanner => enabled && bannerEnabled;

  PrayerConfig copyWith({
    bool? enabled,
    String? cityId,
    bool clearCityId = false,
    double? lat,
    double? lng,
    String? locationLabel,
    bool? fromDeviceLocation,
    PrayerMethod? method,
    PrayerMadhab? madhab,
    Map<String, bool>? notify,
    Map<String, int>? offsets,
    bool? exactAlarms,
    bool? showInLiveNotification,
    bool? showOnHome,
    bool? bannerEnabled,
    PrayerBannerContent? bannerContent,
    PrayerBannerTheme? bannerTheme,
    bool? bannerTint,
    bool? bannerOnLockScreen,
    int? hijriOffset,
  }) =>
      PrayerConfig(
        enabled: enabled ?? this.enabled,
        cityId: clearCityId ? null : (cityId ?? this.cityId),
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        locationLabel: locationLabel ?? this.locationLabel,
        fromDeviceLocation: fromDeviceLocation ?? this.fromDeviceLocation,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        notify: notify ?? this.notify,
        offsets: offsets ?? this.offsets,
        exactAlarms: exactAlarms ?? this.exactAlarms,
        showInLiveNotification:
            showInLiveNotification ?? this.showInLiveNotification,
        showOnHome: showOnHome ?? this.showOnHome,
        bannerEnabled: bannerEnabled ?? this.bannerEnabled,
        bannerContent: bannerContent ?? this.bannerContent,
        bannerTheme: bannerTheme ?? this.bannerTheme,
        bannerTint: bannerTint ?? this.bannerTint,
        bannerOnLockScreen: bannerOnLockScreen ?? this.bannerOnLockScreen,
        hijriOffset: hijriOffset ?? this.hijriOffset,
      );

  /// Applies a bundled city, dropping any previous device fix.
  PrayerConfig withCity(PrayerCity city) => copyWith(
        cityId: city.id,
        lat: city.lat,
        lng: city.lng,
        locationLabel: city.label,
        fromDeviceLocation: false,
      );

  /// Applies a one-shot device fix, labelled with the nearest bundled city.
  PrayerConfig withFix(double lat, double lng) {
    final near = PrayerCities.nearest(lat, lng);
    return copyWith(
      clearCityId: true,
      lat: lat,
      lng: lng,
      locationLabel: 'Near ${near.name}',
      fromDeviceLocation: true,
    );
  }

  PrayerConfig withNotify(PrayerSlot slot, bool on) =>
      copyWith(notify: {...notify, slot.name: on});

  PrayerConfig withOffset(PrayerSlot slot, int minutes) =>
      copyWith(offsets: {...offsets, slot.name: minutes});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'city_id': cityId,
        'lat': lat,
        'lng': lng,
        'location_label': locationLabel,
        'from_device': fromDeviceLocation,
        'method': method.name,
        'madhab': madhab.name,
        'notify': notify,
        'offsets': offsets,
        'exact_alarms': exactAlarms,
        'live_notification': showInLiveNotification,
        'show_on_home': showOnHome,
        'banner_enabled': bannerEnabled,
        'banner_content': bannerContent.name,
        'banner_theme': bannerTheme.name,
        'banner_tint': bannerTint,
        'banner_lock_screen': bannerOnLockScreen,
        'hijri_offset': hijriOffset,
      };

  /// Every field is read defensively. This blob is on disk across upgrades and
  /// is also written by the background notification isolate, so a value of the
  /// wrong shape has to degrade to the default rather than throw during
  /// startup.
  factory PrayerConfig.fromJson(Map<String, dynamic> j) {
    const fallback = PrayerConfig();
    return PrayerConfig(
      enabled: _bool(j['enabled']) ?? false,
      cityId: j['city_id'] is String ? j['city_id'] as String : null,
      lat: _double(j['lat']) ?? fallback.lat,
      lng: _double(j['lng']) ?? fallback.lng,
      locationLabel: j['location_label'] is String
          ? j['location_label'] as String
          : fallback.locationLabel,
      fromDeviceLocation: _bool(j['from_device']) ?? false,
      method: _enumByName(PrayerMethod.values, j['method']) ??
          PrayerMethod.karachi,
      madhab:
          _enumByName(PrayerMadhab.values, j['madhab']) ?? PrayerMadhab.shafi,
      notify: _boolMap(j['notify']) ?? fallback.notify,
      offsets: _intMap(j['offsets']) ?? const {},
      exactAlarms: _bool(j['exact_alarms']) ?? false,
      showInLiveNotification: _bool(j['live_notification']) ?? true,
      showOnHome: _bool(j['show_on_home']) ?? true,
      bannerEnabled: _bool(j['banner_enabled']) ?? true,
      bannerContent:
          _enumByName(PrayerBannerContent.values, j['banner_content']) ??
              PrayerBannerContent.nextOnly,
      bannerTheme: _enumByName(PrayerBannerTheme.values, j['banner_theme']) ??
          PrayerBannerTheme.aurora,
      bannerTint: _bool(j['banner_tint']) ?? true,
      bannerOnLockScreen: _bool(j['banner_lock_screen']) ?? true,
      hijriOffset: (_int(j['hijri_offset']) ?? 0).clamp(-2, 2),
    );
  }

  static bool? _bool(Object? raw) => raw is bool ? raw : null;

  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw == null) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static Map<String, bool>? _boolMap(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final e in raw.entries)
        if (e.value is bool) e.key.toString(): e.value as bool,
    };
  }

  static Map<String, int>? _intMap(Object? raw) {
    if (raw is! Map) return null;
    return {
      for (final e in raw.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
  }
}

/// Reads and writes [PrayerConfig] as a single JSON blob.
///
/// One key rather than a dozen so that a background isolate — which has no
/// Provider and no app state — can load the whole configuration in one hop.
class PrayerConfigStore {
  PrayerConfigStore._();

  static const _key = 'ff_prayer_config';

  static Future<PrayerConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const PrayerConfig();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const PrayerConfig();
      return PrayerConfig.fromJson(decoded);
    } catch (err, stack) {
      // A malformed blob must not take the app down on launch; the defaults
      // leave the feature off, which is the safe resting state.
      AppLog.error('PrayerConfigStore.load', err, stack);
      return const PrayerConfig();
    }
  }

  static Future<void> save(PrayerConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(config.toJson()));
    } catch (err, stack) {
      AppLog.error('PrayerConfigStore.save', err, stack);
    }
  }
}

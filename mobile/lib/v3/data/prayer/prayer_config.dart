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

  /// At prayer time, show the prayer's name full screen, over the lock screen.
  final bool fullScreenAlert;

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

  /// "Ending soon" reminder: shown in the Now Bar / as a live notification
  /// [endingSoonLead] minutes before a prayer's time runs out, re-alerting
  /// every [endingSoonRepeat] minutes until marked prayed.
  final bool endingSoon;
  final int endingSoonLead;
  final int endingSoonRepeat;

  /// Per prayer, keyed by [PrayerSlot.name].
  final Map<String, bool> endingSoonFor;

  /// The "prayer island": the next prayer and a countdown, standing in the
  /// Now Bar / status bar all day. Independent of [enabled] (the alerts).
  final bool islandAlways;

  /// What the status-bar chip shows: 'name' (Asr) or 'countdown' (25min).
  final String islandChip;

  /// How the ending-soon reminder words it: 'ask', 'remind' or 'tell'.
  final String islandAsk;

  /// The chip's background, a key of [islandColors].
  final String islandColor;

  /// Samsung Now Bar fallback, used only where Android won't promote a
  /// Live Update: show as a media card 'off', for the 'ending' question
  /// only, or 'always' (the all-day island too).
  final String islandMedia;

  /// Chip backgrounds on offer; 'none' leaves the system's plain chip.
  static const islandColors = {
    'gold': 0xFFC9963F,
    'teal': 0xFF1E8C99,
    'purple': 0xFF6E5FC8,
    'green': 0xFF2E8B57,
    'rose': 0xFFC0506A,
    'none': 0,
  };

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
    this.fullScreenAlert = true,
    this.showInLiveNotification = true,
    this.showOnHome = true,
    this.bannerEnabled = true,
    this.bannerContent = PrayerBannerContent.nextOnly,
    this.bannerTheme = PrayerBannerTheme.aurora,
    this.bannerTint = true,
    this.bannerOnLockScreen = true,
    this.hijriOffset = 0,
    this.endingSoon = true,
    this.endingSoonLead = 20,
    this.endingSoonRepeat = 5,
    this.endingSoonFor = const {
      'fajr': true,
      'dhuhr': true,
      'asr': true,
      'maghrib': true,
      'isha': true,
    },
    this.islandAlways = true,
    this.islandChip = 'name',
    this.islandAsk = 'ask',
    this.islandColor = 'gold',
    this.islandMedia = 'ending',
  });

  bool notifyFor(PrayerSlot slot) => notify[slot.name] ?? false;
  int offsetFor(PrayerSlot slot) => offsets[slot.name] ?? 0;
  bool endingSoonOn(PrayerSlot slot) => endingSoonFor[slot.name] ?? false;

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
    bool? fullScreenAlert,
    bool? showInLiveNotification,
    bool? showOnHome,
    bool? bannerEnabled,
    PrayerBannerContent? bannerContent,
    PrayerBannerTheme? bannerTheme,
    bool? bannerTint,
    bool? bannerOnLockScreen,
    int? hijriOffset,
    bool? endingSoon,
    int? endingSoonLead,
    int? endingSoonRepeat,
    Map<String, bool>? endingSoonFor,
    bool? islandAlways,
    String? islandChip,
    String? islandAsk,
    String? islandColor,
    String? islandMedia,
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
        fullScreenAlert: fullScreenAlert ?? this.fullScreenAlert,
        showInLiveNotification:
            showInLiveNotification ?? this.showInLiveNotification,
        showOnHome: showOnHome ?? this.showOnHome,
        bannerEnabled: bannerEnabled ?? this.bannerEnabled,
        bannerContent: bannerContent ?? this.bannerContent,
        bannerTheme: bannerTheme ?? this.bannerTheme,
        bannerTint: bannerTint ?? this.bannerTint,
        bannerOnLockScreen: bannerOnLockScreen ?? this.bannerOnLockScreen,
        hijriOffset: hijriOffset ?? this.hijriOffset,
        endingSoon: endingSoon ?? this.endingSoon,
        endingSoonLead: endingSoonLead ?? this.endingSoonLead,
        endingSoonRepeat: endingSoonRepeat ?? this.endingSoonRepeat,
        endingSoonFor: endingSoonFor ?? this.endingSoonFor,
        islandAlways: islandAlways ?? this.islandAlways,
        islandChip: islandChip ?? this.islandChip,
        islandAsk: islandAsk ?? this.islandAsk,
        islandColor: islandColor ?? this.islandColor,
        islandMedia: islandMedia ?? this.islandMedia,
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
        'full_screen_alert': fullScreenAlert,
        'live_notification': showInLiveNotification,
        'show_on_home': showOnHome,
        'banner_enabled': bannerEnabled,
        'banner_content': bannerContent.name,
        'banner_theme': bannerTheme.name,
        'banner_tint': bannerTint,
        'banner_lock_screen': bannerOnLockScreen,
        'hijri_offset': hijriOffset,
        'ending_soon': endingSoon,
        'ending_soon_lead': endingSoonLead,
        'ending_soon_repeat': endingSoonRepeat,
        'ending_soon_for': endingSoonFor,
        'island_always': islandAlways,
        'island_chip': islandChip,
        'island_ask': islandAsk,
        'island_color': islandColor,
        'island_media': islandMedia,
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
      fullScreenAlert: _bool(j['full_screen_alert']) ?? true,
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
      endingSoon: _bool(j['ending_soon']) ?? true,
      endingSoonLead: (_int(j['ending_soon_lead']) ?? 20).clamp(5, 90),
      endingSoonRepeat: (_int(j['ending_soon_repeat']) ?? 5).clamp(1, 30),
      endingSoonFor: _boolMap(j['ending_soon_for']) ??
          const {
            'fajr': true,
            'dhuhr': true,
            'asr': true,
            'maghrib': true,
            'isha': true,
          },
      islandAlways: _bool(j['island_always']) ?? true,
      islandChip: j['island_chip'] == 'countdown' ? 'countdown' : 'name',
      islandAsk: const ['ask', 'remind', 'tell'].contains(j['island_ask'])
          ? j['island_ask'] as String
          : 'ask',
      islandColor: islandColors.containsKey(j['island_color'])
          ? j['island_color'] as String
          : 'gold',
      islandMedia: const ['off', 'ending', 'always'].contains(j['island_media'])
          ? j['island_media'] as String
          : 'ending',
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

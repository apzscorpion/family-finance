import 'dart:async';

import 'package:flutter/widgets.dart';

import '../notifications_core.dart';
import 'prayer_banner.dart';
import 'prayer_cities.dart';
import 'prayer_config.dart';
import 'prayer_location.dart';
import 'prayer_notifier.dart';
import 'prayer_service.dart';

/// Holds the prayer configuration and the derived "what is next" state.
///
/// The cost model matters more than the code here:
///
/// * While the feature is off, nothing is computed and no timer exists.
/// * While it is on, exactly one timer runs, aligned to the minute boundary,
///   and only while the app is in the foreground.
/// * Going to the background cancels that timer; coming back recomputes once
///   and re-aligns. Nothing ticks behind a locked screen.
///
/// The notification window is rebuilt on resume and on every config change,
/// which is what lets the feature work with no background service at all.
class PrayerController extends ChangeNotifier with WidgetsBindingObserver {
  PrayerController() {
    WidgetsBinding.instance.addObserver(this);
  }

  PrayerConfig _config = const PrayerConfig();
  PrayerConfig get config => _config;

  PrayerDay? _today;
  NextPrayer? _next;
  Timer? _tick;
  bool _loaded = false;
  bool _foreground = true;
  bool _locating = false;

  /// Today's six times, or null while the feature is off or still loading.
  PrayerDay? get today => _today;

  /// Which prayer is next and how long until it.
  NextPrayer? get next => _next;

  bool get loaded => _loaded;
  bool get enabled => _config.enabled;
  bool get locating => _locating;

  /// True when there is something to draw on the home screen.
  bool get showOnHome => _config.enabled && _config.showOnHome && _next != null;

  Future<void> load() async {
    _config = await PrayerConfigStore.load();
    _loaded = true;
    _recompute();
    notifyListeners();
    // Reconcile the alert window with whatever was restored from disk.
    if (_config.enabled) {
      await PrayerNotifier.sync(_config);
      await _postBanner();
    }
  }

  /// Posts or clears the standing banner for the current state.
  ///
  /// [force] re-posts even when nothing the banner shows has changed, which is
  /// what a settings change needs — the user expects to see their choice take
  /// effect immediately.
  Future<void> _postBanner({bool force = false}) async {
    final day = _today;
    final next = _next;
    if (!_config.showBanner || day == null || next == null) {
      await PrayerBanner.cancel();
      return;
    }
    await PrayerBanner.post(
      config: _config,
      day: day,
      next: next,
      force: force,
    );
  }

  /// Persists [next], recomputes and rebuilds the notification window.
  Future<void> update(PrayerConfig next) async {
    final wasEnabled = _config.enabled;
    _config = next;
    _recompute();
    notifyListeners();

    await PrayerConfigStore.save(next);

    if (!next.enabled) {
      if (wasEnabled) await PrayerNotifier.cancelAll();
      await PrayerBanner.cancel();
      return;
    }
    await PrayerNotifier.sync(next);
    // Forced: a settings change must be visible in the shade at once, even
    // though the prayer it shows has not changed.
    await _postBanner(force: true);
  }

  Future<void> setEnabled(bool on) => update(_config.copyWith(enabled: on));

  Future<void> setCity(PrayerCity city) => update(_config.withCity(city));

  Future<void> setMethod(PrayerMethod method) =>
      update(_config.copyWith(method: method));

  Future<void> setMadhab(PrayerMadhab madhab) =>
      update(_config.copyWith(madhab: madhab));

  Future<void> setNotify(PrayerSlot slot, bool on) =>
      update(_config.withNotify(slot, on));

  Future<void> setOffset(PrayerSlot slot, int minutes) =>
      update(_config.withOffset(slot, minutes.clamp(-30, 30)));

  Future<void> setHijriOffset(int days) =>
      update(_config.copyWith(hijriOffset: days.clamp(-2, 2)));

  Future<void> setBannerEnabled(bool on) =>
      update(_config.copyWith(bannerEnabled: on));

  Future<void> setBannerContent(PrayerBannerContent content) =>
      update(_config.copyWith(bannerContent: content));

  Future<void> setBannerTheme(PrayerBannerTheme theme) =>
      update(_config.copyWith(bannerTheme: theme));

  Future<void> setBannerTint(bool on) =>
      update(_config.copyWith(bannerTint: on));

  Future<void> setBannerOnLockScreen(bool on) =>
      update(_config.copyWith(bannerOnLockScreen: on));

  Future<void> setShowOnHome(bool on) =>
      update(_config.copyWith(showOnHome: on));

  Future<void> setShowInLiveNotification(bool on) =>
      update(_config.copyWith(showInLiveNotification: on));

  /// Exact alarms need an OS grant; if it is refused the setting stays off
  /// rather than silently claiming precision it will not deliver.
  Future<bool> setExactAlarms(bool on) async {
    if (!on) {
      await update(_config.copyWith(exactAlarms: false));
      return false;
    }
    final granted = await AppNotifications.requestExactAlarms();
    await update(_config.copyWith(exactAlarms: granted));
    return granted;
  }

  /// One-shot device fix. Returns the outcome so the caller can message it.
  Future<PrayerFix> useDeviceLocation() async {
    _locating = true;
    notifyListeners();
    try {
      final fix = await PrayerLocation.fetch();
      if (fix.ok) {
        await update(_config.withFix(fix.lat!, fix.lng!));
      }
      return fix;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;

    if (foreground) {
      // The clock moved while we were away and the window may have drained.
      _recompute();
      notifyListeners();
      if (_config.enabled) {
        PrayerNotifier.sync(_config);
        // The prayer may well have rolled over while the app was away, and
        // the banner is the one surface the user sees without opening the app.
        _postBanner();
      }
    } else {
      _stopTick();
    }
  }

  // ── Derived state ─────────────────────────────────────────────────────────

  void _recompute() {
    if (!_config.enabled) {
      _today = null;
      _next = null;
      _stopTick();
      return;
    }
    final now = DateTime.now();
    _today = PrayerService.day(_config, now);
    _next = PrayerService.next(_config, now);
    _startTick();
  }

  /// One minute-aligned timer. The countdown is displayed to the minute, so
  /// ticking any faster would burn frames to show the same string.
  void _startTick() {
    if (!_foreground || !_config.enabled) return;
    _stopTick();

    final now = DateTime.now();
    final toNextMinute = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );

    _tick = Timer(toNextMinute, () {
      _onMinute();
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => _onMinute());
    });
  }

  void _onMinute() {
    if (!_foreground || !_config.enabled) {
      _stopTick();
      return;
    }
    final now = DateTime.now();
    final previous = _next?.next.slot;
    _next = PrayerService.next(_config, now);

    // Recompute the day only when it actually rolled over, rather than every
    // minute: the six times are fixed for a given date.
    if (_today == null || _today!.date.day != now.day) {
      _today = PrayerService.day(_config, now);
    } else if (previous != null && previous != _next!.next.slot) {
      // A prayer just came in; the window the UI draws has changed.
      _today = PrayerService.day(_config, now);
    }
    notifyListeners();

    // Only when the prayer actually rolled over. Android redraws the banner's
    // countdown itself, so posting every minute would buy nothing and make the
    // shade flicker.
    if (previous != null && previous != _next!.next.slot) {
      _postBanner();
    }
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _stopTick();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/notifications_core.dart';
import '../data/prayer/prayer_cities.dart';
import '../data/prayer/prayer_config.dart';
import '../data/prayer/prayer_ending_soon.dart';
import '../data/prayer/prayer_controller.dart';
import '../phosphor_icons.dart';
import '../widgets/prayer_ring.dart';
import 'settings_v3.dart' show V3SettingsSwitch;

/// Everything that drives the prayer feature: the master switch, where you
/// are, which authority's method to use, and what gets an alert.
class PrayerSettingsV3 extends StatelessWidget {
  const PrayerSettingsV3({super.key});

  @override
  Widget build(BuildContext context) {
    final prayer = context.watch<PrayerController>();
    final config = prayer.config;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Card(
          child: _Row(
            icon: PhRegular.mosque,
            label: 'Prayer times',
            sub: 'Calculated on this device · works offline',
            trailing: V3SettingsSwitch(
              value: config.enabled,
              onChanged: (on) => _toggle(context, on),
            ),
            last: true,
          ),
        ),

        const _Kicker('Now Bar'),
        _Card(
          child: Column(
            children: [
              _Row(
                icon: PhRegular.moonStars,
                label: 'Prayer island',
                sub: 'The next prayer and a countdown in the Now Bar, status '
                    'bar and lock screen · ${config.locationLabel}',
                trailing: V3SettingsSwitch(
                  value: config.islandAlways,
                  onChanged: (on) =>
                      prayer.update(config.copyWith(islandAlways: on)),
                ),
              ),
              _Row(
                icon: PhRegular.circle,
                label: 'Chip shows',
                sub: 'The small pill next to the clock',
                trailing: _MiniSeg(
                  options: const ['Prayer', 'Countdown'],
                  selected: config.islandChip == 'countdown' ? 1 : 0,
                  onChanged: (i) => prayer.update(config.copyWith(
                      islandChip: i == 1 ? 'countdown' : 'name')),
                ),
              ),
              _Row(
                icon: PhRegular.circle,
                label: 'Chip colour',
                sub: 'Its background, where your phone supports it',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in PrayerConfig.islandColors.entries)
                      GestureDetector(
                        onTap: () => prayer
                            .update(config.copyWith(islandColor: e.key)),
                        child: Semantics(
                          label: '${e.key} chip',
                          selected: config.islandColor == e.key,
                          child: Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e.value == 0 ? null : Color(e.value),
                              border: Border.all(
                                color: config.islandColor == e.key
                                    ? Nocturne.palette.text
                                    : Nocturne.palette.faint,
                                width: config.islandColor == e.key ? 2 : 1,
                              ),
                            ),
                            child: e.value == 0
                                ? Icon(PhRegular.x,
                                    size: 12, color: Nocturne.palette.muted)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _Row(
                icon: PhRegular.playCircle,
                label: 'Samsung Now Bar',
                sub: 'Experimental, off by default: shows the reminder as a '
                    'media card. Samsung may still keep it out of the Now Bar; '
                    'it has music-style controls and runs a background service '
                    '(a little more battery) while shown.',
                trailing: _MiniSeg(
                  options: const ['Off', 'Ending', 'All day'],
                  selected: switch (config.islandMedia) {
                    'off' => 0,
                    'always' => 2,
                    _ => 1,
                  },
                  onChanged: (i) => prayer.update(config.copyWith(
                      islandMedia: const ['off', 'ending', 'always'][i])),
                ),
              ),
              _Row(
                icon: PhRegular.bellRinging,
                label: 'Ask before a prayer ends',
                sub: 'Pops up until you mark it prayed',
                trailing: V3SettingsSwitch(
                  value: config.endingSoon,
                  onChanged: (on) =>
                      prayer.update(config.copyWith(endingSoon: on)),
                ),
                last: !config.endingSoon,
              ),
              if (config.endingSoon) ...[
                _Row(
                  icon: PhRegular.clock,
                  label: 'When to show',
                  sub: 'Minutes before the prayer time ends',
                  trailing: _Stepper(
                    value: config.endingSoonLead,
                    min: 5,
                    max: 90,
                    step: 5,
                    suffix: 'm',
                    onChanged: (v) =>
                        prayer.update(config.copyWith(endingSoonLead: v)),
                  ),
                ),
                _Row(
                  icon: PhRegular.arrowsClockwise,
                  label: 'Snooze gap',
                  sub: 'Asks again after this long, until you mark it prayed',
                  trailing: _Stepper(
                    value: config.endingSoonRepeat,
                    min: 1,
                    max: 30,
                    step: 1,
                    suffix: 'm',
                    onChanged: (v) =>
                        prayer.update(config.copyWith(endingSoonRepeat: v)),
                  ),
                ),
                _Row(
                  icon: PhRegular.chatCircleDots,
                  label: 'Question',
                  sub: switch (config.islandAsk) {
                    'remind' => '"Pray Asr before it ends"',
                    'tell' => '"Asr ends at 3:35 PM"',
                    _ => '"Have you prayed Asr?"',
                  },
                  trailing: _MiniSeg(
                    options: const ['Ask', 'Remind', 'Tell'],
                    selected: switch (config.islandAsk) {
                      'remind' => 1,
                      'tell' => 2,
                      _ => 0,
                    },
                    onChanged: (i) => prayer.update(config.copyWith(
                        islandAsk: const ['ask', 'remind', 'tell'][i])),
                  ),
                ),
                for (final slot in PrayerSlot.values.where((s) => s.isPrayer))
                  _Row(
                    icon: PhRegular.dotOutline,
                    label: slot.label,
                    sub: switch (slot) {
                      PrayerSlot.fajr => 'Ends at sunrise',
                      PrayerSlot.isha => 'Ends at the middle of the night',
                      _ => null,
                    },
                    trailing: V3SettingsSwitch(
                      value: config.endingSoonOn(slot),
                      onChanged: (on) => prayer.update(config.copyWith(
                        endingSoonFor: {
                          ...config.endingSoonFor,
                          slot.name: on,
                        },
                      )),
                    ),
                    last: slot == PrayerSlot.isha,
                  ),
              ],
            ],
          ),
        ),
        _Card(
          child: _Row(
            icon: PhRegular.clock,
            label: 'Exact alerts',
            sub: config.exactAlarms
                ? 'Alerts and Now Bar reminders arrive on the exact minute. '
                    'Battery: the phone wakes for a moment at each one, '
                    'about 30 times a day: well under 1%.'
                : 'Off: Android may deliver them a few minutes late, '
                    'grouped with other apps\' wake-ups. Slightly less '
                    'battery, but less punctual.',
            trailing: V3SettingsSwitch(
              value: config.exactAlarms,
              onChanged: (on) => _setExact(context, on),
            ),
            last: true,
          ),
        ),
        _Card(
          child: _Row(
            icon: PhRegular.playCircle,
            label: 'Test it now',
            sub: 'Shows a 3-minute reminder for the current prayer, the way '
                'it will look on this phone',
            trailing: Icon(PhRegular.caretRight,
                size: 16, color: Nocturne.palette.muted),
            onTap: () async {
              await showTestReminder(config);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Test reminder sent: check the status bar, '
                    'Now Bar and lock screen'),
              ));
            },
            last: true,
          ),
        ),
        const _PhoneCheck(),

        if (config.enabled) ...[
          const _Kicker('Location'),
          _Card(
            child: Column(
              children: [
                _Row(
                  icon: PhRegular.mapPin,
                  label: config.locationLabel,
                  sub: config.fromDeviceLocation
                      ? 'From your device location'
                      : 'Chosen from the city list',
                  trailing: Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.palette.faint),
                  onTap: () => _pickCity(context),
                ),
                _Row(
                  icon: PhRegular.crosshair,
                  label: 'Use my location',
                  sub: 'Read once and stored — never tracked',
                  trailing: prayer.locating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Nocturne.palette.accentMuted),
                        )
                      : Icon(PhRegular.caretRight,
                          size: 14, color: Nocturne.palette.faint),
                  onTap:
                      prayer.locating ? null : () => _useLocation(context),
                  last: true,
                ),
              ],
            ),
          ),

          const _Kicker('Calculation'),
          _Card(
            child: Column(
              children: [
                _Row(
                  icon: PhRegular.compass,
                  label: 'Method',
                  sub: config.method.label,
                  trailing: Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.palette.faint),
                  onTap: () => _pickMethod(context),
                ),
                _Row(
                  icon: PhRegular.sunDim,
                  label: 'Asr calculation',
                  sub: config.madhab == PrayerMadhab.hanafi
                      ? 'Hanafi — later Asr'
                      : 'Shafi, Maliki, Hanbali — earlier Asr',
                  trailing: _MiniSeg(
                    options: const ['Shafi', 'Hanafi'],
                    selected: config.madhab == PrayerMadhab.hanafi ? 1 : 0,
                    onChanged: (i) => prayer.setMadhab(
                        i == 1 ? PrayerMadhab.hanafi : PrayerMadhab.shafi),
                  ),
                  last: true,
                ),
              ],
            ),
          ),

          const _Kicker('Alerts'),
          _Card(
            child: Column(
              children: [
                for (final slot in PrayerSlot.values)
                  _SlotAlertRow(
                    slot: slot,
                    on: config.notifyFor(slot),
                    offset: config.offsetFor(slot),
                    onToggle: (v) => prayer.setNotify(slot, v),
                    onOffset: (v) => prayer.setOffset(slot, v),
                    last: slot == PrayerSlot.values.last,
                  ),
              ],
            ),
          ),

          _Card(
            child: _Row(
              icon: PhRegular.moonStars,
              label: 'Full-screen alert',
              sub: 'Shows the prayer name full screen, even when locked',
              trailing: V3SettingsSwitch(
                value: config.fullScreenAlert,
                onChanged: prayer.setFullScreenAlert,
              ),
              last: true,
            ),
          ),

          const _Kicker('Banner'),
          _Card(
            child: Column(
              children: [
                _Row(
                  icon: PhRegular.tray,
                  label: 'Prayer banner',
                  sub: 'A standing card in the notification shade',
                  trailing: V3SettingsSwitch(
                    value: config.bannerEnabled,
                    onChanged: prayer.setBannerEnabled,
                  ),
                  last: !config.bannerEnabled,
                ),
                if (config.bannerEnabled) ...[
                  _Row(
                    icon: PhRegular.listBullets,
                    label: 'Shows',
                    sub: config.bannerContent.description,
                    trailing: Icon(PhRegular.caretRight,
                        size: 14, color: Nocturne.palette.faint),
                    onTap: () => _pickBannerContent(context),
                  ),
                  _Row(
                    icon: PhRegular.image,
                    label: 'Background',
                    sub: config.bannerTheme.label,
                    trailing: Icon(PhRegular.caretRight,
                        size: 14, color: Nocturne.palette.faint),
                    onTap: () => _pickBannerTheme(context),
                  ),
                  _Row(
                    icon: PhRegular.sparkle,
                    label: 'Tint by prayer',
                    sub: 'Colours the icon and app name, shifting through '
                        'the day',
                    trailing: V3SettingsSwitch(
                      value: config.bannerTint,
                      onChanged: prayer.setBannerTint,
                    ),
                  ),
                  _Row(
                    icon: PhRegular.lockSimple,
                    label: 'Show on lock screen',
                    sub: config.bannerOnLockScreen
                        ? 'Times are visible without unlocking'
                        : 'Hidden until you unlock',
                    trailing: V3SettingsSwitch(
                      value: config.bannerOnLockScreen,
                      onChanged: prayer.setBannerOnLockScreen,
                    ),
                    last: true,
                  ),
                ],
              ],
            ),
          ),

          const _Kicker('Display'),
          _Card(
            child: Column(
              children: [
                _Row(
                  icon: PhRegular.house,
                  label: 'Show on home',
                  sub: 'A card above your spending',
                  trailing: V3SettingsSwitch(
                    value: config.showOnHome,
                    onChanged: prayer.setShowOnHome,
                  ),
                ),
                _Row(
                  icon: PhRegular.bell,
                  label: 'Show in live card',
                  sub: 'Next prayer on the lock-screen card',
                  trailing: V3SettingsSwitch(
                    value: config.showInLiveNotification,
                    onChanged: prayer.setShowInLiveNotification,
                  ),
                ),
                _Row(
                  icon: PhRegular.calendar,
                  label: 'Hijri date',
                  sub: _hijriSub(context, config.hijriOffset),
                  trailing: _Stepper(
                    value: config.hijriOffset,
                    min: -2,
                    max: 2,
                    onChanged: prayer.setHijriOffset,
                  ),
                  last: true,
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Nothing here is shared with your family — these settings '
              'stay on this device. Times are computed locally, so no '
              'location or prayer data ever leaves your phone.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.5, color: Nocturne.palette.faint),
            ),
          ),
        ],
      ],
    );
  }

  static String _hijriSub(BuildContext context, int offset) {
    final today = context.read<PrayerController>().today;
    final date = today?.hijri.label ?? 'Adjust by a day if needed';
    if (offset == 0) return date;
    return '$date · ${offset > 0 ? '+' : ''}$offset day';
  }

  /// Turning the feature on is also the moment to ask for notification
  /// permission — asking at launch for a feature nobody enabled is noise.
  static Future<void> _toggle(BuildContext context, bool on) async {
    final prayer = context.read<PrayerController>();
    final messenger = ScaffoldMessenger.of(context);

    if (!on) {
      await prayer.setEnabled(false);
      return;
    }

    await prayer.setEnabled(true);

    if (!await AppNotifications.hasPermission()) {
      final granted = await AppNotifications.requestPermission();
      if (!granted) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Times will show in the app, but alerts need notification '
              'permission'),
        ));
      } else {
        // Permission arrived after the first sync attempt, so schedule again.
        await prayer.update(prayer.config);
      }
    }
  }

  static Future<void> _setExact(BuildContext context, bool on) async {
    final prayer = context.read<PrayerController>();
    final messenger = ScaffoldMessenger.of(context);
    final granted = await prayer.setExactAlarms(on);

    if (on && !granted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Android did not allow exact alarms — alerts will '
            'still fire, within a few minutes'),
      ));
    }
  }

  static Future<void> _useLocation(BuildContext context) async {
    final prayer = context.read<PrayerController>();
    final messenger = ScaffoldMessenger.of(context);
    final fix = await prayer.useDeviceLocation();

    messenger.showSnackBar(SnackBar(content: Text(fix.message)));
  }

  static Future<void> _pickCity(BuildContext context) async {
    final prayer = context.read<PrayerController>();
    final city = await showModalBottomSheet<PrayerCity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CityPicker(),
    );
    if (city != null) await prayer.setCity(city);
  }

  static Future<void> _pickBannerContent(BuildContext context) async {
    final prayer = context.read<PrayerController>();
    final picked = await showModalBottomSheet<PrayerBannerContent>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionPicker<PrayerBannerContent>(
        title: 'What the banner shows',
        blurb: 'The countdown is drawn by Android, so none of these cost '
            'battery.',
        options: PrayerBannerContent.values,
        current: prayer.config.bannerContent,
        labelOf: (v) => v.label,
        subOf: (v) => v.description,
      ),
    );
    if (picked != null) await prayer.setBannerContent(picked);
  }

  static Future<void> _pickBannerTheme(BuildContext context) async {
    final prayer = context.read<PrayerController>();
    final picked = await showModalBottomSheet<PrayerBannerTheme>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionPicker<PrayerBannerTheme>(
        title: 'Banner background',
        blurb: 'Android cannot blur your wallpaper behind a notification, so '
            'the frosted look is drawn into the card itself.',
        options: PrayerBannerTheme.values,
        current: prayer.config.bannerTheme,
        labelOf: (v) => v.label,
        subOf: (v) =>
            v.followsPrayer ? 'Follows the time of day' : null,
      ),
    );
    if (picked != null) await prayer.setBannerTheme(picked);
  }

  static Future<void> _pickMethod(BuildContext context) async {
    final prayer = context.read<PrayerController>();
    final current = prayer.config.method;
    final picked = await showModalBottomSheet<PrayerMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MethodPicker(current: current),
    );
    if (picked != null) await prayer.setMethod(picked);
  }
}

// ── Alerts row ──────────────────────────────────────────────────────────────

/// One prayer's alert switch, with the minute adjustment revealed only once
/// the alert is on — an offset on a silent prayer still shifts the displayed
/// time, but it is a far less common thing to want.
class _SlotAlertRow extends StatelessWidget {
  final PrayerSlot slot;
  final bool on;
  final int offset;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onOffset;
  final bool last;

  const _SlotAlertRow({
    required this.slot,
    required this.on,
    required this.offset,
    required this.onToggle,
    required this.onOffset,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final colour = PrayerVisuals.color(slot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: last
          ? null
          : BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Nocturne.palette.line))),
      child: Row(
        children: [
          Icon(PrayerVisuals.icon(slot), size: 18, color: colour),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.label,
                  style: TextStyle(fontSize: 14, color: Nocturne.palette.text),
                ),
                if (slot == PrayerSlot.sunrise)
                  Text(
                    'End of the Fajr window',
                    style:
                        TextStyle(fontSize: 11, color: Nocturne.palette.faint),
                  ),
              ],
            ),
          ),
          _Stepper(
            value: offset,
            min: -30,
            max: 30,
            step: 1,
            suffix: 'm',
            onChanged: onOffset,
          ),
          const SizedBox(width: 10),
          V3SettingsSwitch(value: on, onChanged: onToggle),
        ],
      ),
    );
  }
}

// ── Pickers ─────────────────────────────────────────────────────────────────

class _CityPicker extends StatefulWidget {
  const _CityPicker();

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  final _controller = TextEditingController();
  List<PrayerCity> _results = PrayerCities.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) =>
      setState(() => _results = PrayerCities.search(q));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: Nocturne.palette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose your city',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.palette.text)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _search,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: Nocturne.palette.text),
                decoration: InputDecoration(
                  hintText: 'Search city or state',
                  hintStyle: TextStyle(
                      fontSize: 14, color: Nocturne.palette.faint),
                  prefixIcon: Icon(PhRegular.magnifyingGlass,
                      size: 17, color: Nocturne.palette.muted),
                  filled: true,
                  fillColor: Nocturne.palette.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No match. Try a nearby large city — prayer '
                          'times barely change across a region.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5, color: Nocturne.palette.muted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemExtent: 54,
                      itemBuilder: (_, i) {
                        final c = _results[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, c),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Nocturne.palette.text)),
                                      Text(c.region,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: Nocturne.palette.faint)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  final PrayerMethod current;

  const _MethodPicker({required this.current});

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: Nocturne.palette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Calculation method',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.palette.text)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick whichever your local mosque follows. It mainly '
                  'changes Fajr and Isha.',
                  style: TextStyle(
                      fontSize: 12, color: Nocturne.palette.faint),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in PrayerMethod.values)
                    InkWell(
                      onTap: () => Navigator.pop(context, m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: m == current
                                      ? Nocturne.palette.accentMuted
                                      : Nocturne.palette.text,
                                ),
                              ),
                            ),
                            if (m == current)
                              Icon(PhRegular.check,
                                  size: 16, color: Nocturne.palette.accentMuted),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
}

/// A generic single-choice sheet.
///
/// The method picker predates this and has its own copy; this one exists
/// because the banner adds two more pickers and a third hand-rolled sheet
/// would be the point at which they start drifting apart.
class _OptionPicker<T> extends StatelessWidget {
  final String title;
  final String? blurb;
  final List<T> options;
  final T current;
  final String Function(T) labelOf;
  final String? Function(T)? subOf;

  const _OptionPicker({
    required this.title,
    required this.options,
    required this.current,
    required this.labelOf,
    this.blurb,
    this.subOf,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: Nocturne.palette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.palette.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.palette.text)),
              ),
            ),
            if (blurb != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(blurb!,
                      style: TextStyle(
                          fontSize: 12, color: Nocturne.palette.faint)),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => Navigator.pop(context, option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    labelOf(option),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: option == current
                                          ? Nocturne.palette.accentMuted
                                          : Nocturne.palette.text,
                                    ),
                                  ),
                                  if (subOf?.call(option) case final sub?) ...[
                                    const SizedBox(height: 2),
                                    Text(sub,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Nocturne.palette.faint)),
                                  ],
                                ],
                              ),
                            ),
                            if (option == current)
                              Icon(PhRegular.check,
                                  size: 16, color: Nocturne.palette.accentMuted),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
}

// ── Small shared pieces ─────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: PhRegular.minus,
            enabled: value > min,
            onTap: () => onChanged(value - step),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${value > 0 ? '+' : ''}$value$suffix',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: value == 0 ? Nocturne.palette.faint : Nocturne.palette.text,
              ),
            ),
          ),
          _StepButton(
            icon: PhRegular.plus,
            enabled: value < max,
            onTap: () => onChanged(value + step),
          ),
        ],
      );
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Nocturne.palette.line,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 12,
              color: enabled ? Nocturne.palette.neutral300 : Nocturne.palette.faint),
        ),
      );
}

class _MiniSeg extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _MiniSeg({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Nocturne.palette.line,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: i == selected ? Nocturne.palette.switchOn : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w400,
                      color: i == selected
                          ? Nocturne.palette.accentLight
                          : Nocturne.palette.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        decoration: BoxDecoration(
          color: Nocturne.palette.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );
}

class _Kicker extends StatelessWidget {
  final String text;

  const _Kicker(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Nocturne.palette.faint,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool last;

  const _Row({
    required this.icon,
    required this.label,
    required this.trailing,
    this.sub,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: last
              ? null
              : BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Nocturne.palette.line))),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Nocturne.palette.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14, color: Nocturne.palette.text)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!,
                          style: TextStyle(
                              fontSize: 11.5, color: Nocturne.palette.faint)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      );
}

/// What Android or the phone is blocking, each with a tap to fix it.
/// Re-checks when the user comes back from system settings.
class _PhoneCheck extends StatefulWidget {
  const _PhoneCheck();

  @override
  State<_PhoneCheck> createState() => _PhoneCheckState();
}

class _PhoneCheckState extends State<_PhoneCheck> with WidgetsBindingObserver {
  Map<String, Object?> _status = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final s = await islandStatus();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_status.isEmpty) return const SizedBox.shrink();
    final prayer = context.watch<PrayerController>();
    final config = prayer.config;
    final sdk = _status['sdk'] as int? ?? 0;
    final maker = '${_status['maker']}'.toLowerCase();
    // realme, OPPO and OnePlus (ColorOS) stop sideloaded apps in the
    // background unless "Auto launch" is on.
    final colorOs = ['realme', 'oppo', 'oneplus'].any(maker.contains);
    final samsung = maker.contains('samsung');
    final caret =
        Icon(PhRegular.caretRight, size: 16, color: Nocturne.palette.muted);

    final problems = <({IconData icon, String label, String sub, VoidCallback? fix})>[
      if (sdk < 36)
        (
          icon: PhRegular.info,
          label: 'Now Bar needs Android 16',
          sub: 'This phone runs Android ${_status['release']}, so the island '
              'shows as a normal notification.',
          fix: null,
        ),
      // Samsung (One UI 8) only lets apps it has approved post Live
      // notifications, unless Developer options → "Live notifications for
      // all apps" is on; there is nothing the app itself can request.
      if (sdk >= 36 && _status['promote'] == false && samsung)
        (
          icon: PhRegular.info,
          label: 'Now Bar: Samsung-approved apps only',
          sub: 'Until Samsung opens it to all apps, the prayer island shows '
              'as a pinned notification with the countdown. Optional: '
              'Developer options → "Live notifications for all apps" puts it '
              'in the Now Bar now.',
          fix: null,
        ),
      if (sdk >= 36 && _status['promote'] == false && !samsung)
        (
          icon: PhRegular.warning,
          label: 'Now Bar not allowed',
          sub: 'Tap, then allow live notifications for KinPurse.',
          fix: openNowBarSettings,
        ),
      if (_status['unrestricted'] == false)
        (
          icon: PhRegular.batteryHigh,
          label: 'Battery restriction',
          sub: colorOs
              ? 'Tap → Battery: allow background activity, and turn on '
                  'Auto launch. Without it the Prayed / Not yet buttons and '
                  'the repeats can stop working.'
              : 'Tap → Battery → Unrestricted. Without it the buttons and '
                  'repeats can stop working.',
          fix: openAppSettings,
        ),
      if (config.fullScreenAlert && _status['fullScreen'] == false)
        (
          icon: PhRegular.moonStars,
          label: 'Full-screen alert not allowed',
          sub: 'Tap to let KinPurse show prayer alerts full screen.',
          fix: () => prayer.setFullScreenAlert(true),
        ),
      if (config.exactAlarms && _status['exact'] == false)
        (
          icon: PhRegular.clock,
          label: 'Exact alarms not allowed',
          sub: 'Tap to allow, so reminders arrive on the minute.',
          fix: () => prayer.setExactAlarms(true),
        ),
    ];

    return _Card(
      child: Column(
        children: [
          if (problems.isEmpty)
            const _Row(
              icon: PhRegular.checkCircle,
              label: 'Phone check: all set',
              sub: 'Android allows the Now Bar, alerts and background '
                  'reminders for KinPurse.',
              trailing: SizedBox.shrink(),
              last: true,
            )
          else
            for (var i = 0; i < problems.length; i++)
              _Row(
                icon: problems[i].icon,
                label: problems[i].label,
                sub: problems[i].sub,
                trailing: problems[i].fix == null
                    ? const SizedBox.shrink()
                    : caret,
                onTap: problems[i].fix,
                last: i == problems.length - 1,
              ),
        ],
      ),
    );
  }
}

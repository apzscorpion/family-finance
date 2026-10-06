import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/notifications_core.dart';
import '../data/prayer/prayer_cities.dart';
import '../data/prayer/prayer_config.dart';
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
                  trailing: const Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.neutral600),
                  onTap: () => _pickCity(context),
                ),
                _Row(
                  icon: PhRegular.crosshair,
                  label: 'Use my location',
                  sub: 'Read once and stored — never tracked',
                  trailing: prayer.locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Nocturne.accent300),
                        )
                      : const Icon(PhRegular.caretRight,
                          size: 14, color: Nocturne.neutral600),
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
                  trailing: const Icon(PhRegular.caretRight,
                      size: 14, color: Nocturne.neutral600),
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
              icon: PhRegular.clock,
              label: 'Exact alerts',
              sub: config.exactAlarms
                  ? 'Fires at the exact minute'
                  : 'Fires within a few minutes — easier on battery',
              trailing: V3SettingsSwitch(
                value: config.exactAlarms,
                onChanged: (on) => _setExact(context, on),
              ),
              last: true,
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

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Nothing here is shared with your family — these settings '
              'stay on this device. Times are computed locally, so no '
              'location or prayer data ever leaves your phone.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.5, color: Nocturne.neutral600),
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
          : const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Nocturne.neutral900))),
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
                  style: const TextStyle(fontSize: 14, color: Nocturne.text),
                ),
                if (slot == PrayerSlot.sunrise)
                  const Text(
                    'End of the Fajr window',
                    style:
                        TextStyle(fontSize: 11, color: Nocturne.neutral600),
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
        decoration: const BoxDecoration(
          color: Nocturne.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Nocturne.neutral700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose your city',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _search,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: Nocturne.text),
                decoration: InputDecoration(
                  hintText: 'Search city or state',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: Nocturne.neutral600),
                  prefixIcon: const Icon(PhRegular.magnifyingGlass,
                      size: 17, color: Nocturne.neutral500),
                  filled: true,
                  fillColor: Nocturne.surface,
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
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No match. Try a nearby large city — prayer '
                          'times barely change across a region.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5, color: Nocturne.neutral500),
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
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Nocturne.text)),
                                      Text(c.region,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Nocturne.neutral600)),
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
        decoration: const BoxDecoration(
          color: Nocturne.bg,
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
                color: Nocturne.neutral700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Calculation method',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick whichever your local mosque follows. It mainly '
                  'changes Fajr and Isha.',
                  style: TextStyle(
                      fontSize: 12, color: Nocturne.neutral600),
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
                                      ? Nocturne.accent300
                                      : Nocturne.text,
                                ),
                              ),
                            ),
                            if (m == current)
                              const Icon(PhRegular.check,
                                  size: 16, color: Nocturne.accent300),
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
                color: value == 0 ? Nocturne.neutral600 : Nocturne.text,
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
            color: Nocturne.neutral900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 12,
              color: enabled ? Nocturne.neutral300 : Nocturne.neutral700),
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
          color: Nocturne.neutral900,
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
                    color: i == selected ? Nocturne.accent700 : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w400,
                      color: i == selected
                          ? Nocturne.accent100
                          : Nocturne.neutral500,
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
          color: Nocturne.surface,
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
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Nocturne.neutral600,
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
              : const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Nocturne.neutral900))),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Nocturne.neutral500),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14, color: Nocturne.text)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub!,
                          style: const TextStyle(
                              fontSize: 11.5, color: Nocturne.neutral600)),
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

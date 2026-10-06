import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/prayer/prayer_config.dart';
import '../data/prayer/prayer_controller.dart';
import '../data/prayer/prayer_service.dart';
import '../phosphor_icons.dart';
import '../v3_nav.dart';
import '../widgets/prayer_ring.dart';
import '../widgets/v3_primitives.dart';

/// The full prayer page: a hero countdown, the day's six times, and the
/// settings summary that produced them.
class PrayerV3 extends StatelessWidget {
  const PrayerV3({super.key});

  @override
  Widget build(BuildContext context) {
    final prayer = context.watch<PrayerController>();

    if (!prayer.enabled || prayer.today == null || prayer.next == null) {
      return const _PrayerOff();
    }

    final day = prayer.today!;
    final next = prayer.next!;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Hero(day: day, next: next),
        V3SectionHeader(
          title: 'Today',
          meta: '${day.hijri.label} · approx.',
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Nocturne.neutral900),
          ),
          child: Column(
            children: [
              for (var i = 0; i < day.times.length; i++)
                _SlotRow(
                  time: day.times[i],
                  isNext: day.times[i].slot == next.next.slot &&
                      day.times[i].time.isAfter(now),
                  passed: !day.times[i].time.isAfter(now),
                  notifies: prayer.config.notifyFor(day.times[i].slot),
                  offset: prayer.config.offsetFor(day.times[i].slot),
                  last: i == day.times.length - 1,
                ),
            ],
          ),
        ),
        const V3SectionHeader(title: 'Calculation'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Nocturne.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: PhRegular.mapPin,
                label: 'Location',
                value: prayer.config.locationLabel,
              ),
              _InfoRow(
                icon: PhRegular.compass,
                label: 'Method',
                value: prayer.config.method.short,
              ),
              _InfoRow(
                icon: PhRegular.sunDim,
                label: 'Asr',
                value: prayer.config.madhab == PrayerMadhab.hanafi
                    ? 'Hanafi'
                    : 'Shafi',
              ),
              _InfoRow(
                icon: PhRegular.gear,
                label: 'Prayer settings',
                value: '',
                onTap: () =>
                    context.read<V3Nav>().goPage(V3Page.prayerSettings),
                last: true,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Text(
            'Times are calculated on this device from your location and the '
            'selected method, so they work offline. They may differ by a '
            'minute or two from your local mosque — use the per-prayer '
            'adjustments in settings to match it.',
            style: TextStyle(
                fontSize: 11.5, height: 1.5, color: Nocturne.neutral600),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final PrayerDay day;
  final NextPrayer next;

  const _Hero({required this.day, required this.next});

  @override
  Widget build(BuildContext context) {
    final slot = next.next.slot;
    final colour = PrayerVisuals.color(slot);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Nocturne.neutral900),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(Nocturne.surface, colour, 0.22)!,
            Nocturne.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          PrayerRing(slot: slot, progress: next.progress, size: 92, stroke: 5),
          const SizedBox(height: 14),
          Text(
            next.remaining.inSeconds <= 0
                ? 'It is time for ${slot.label}'
                : '${slot.label} in '
                    '${PrayerVisuals.countdown(next.remaining)}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Nocturne.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${slot.arabic}  ·  ${PrayerVisuals.clock(next.next.time)}',
            style: TextStyle(fontSize: 13, color: colour),
          ),
          const SizedBox(height: 16),
          PrayerDayRail(day: day, now: DateTime.now()),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final PrayerTime time;
  final bool isNext;
  final bool passed;
  final bool notifies;
  final int offset;
  final bool last;

  const _SlotRow({
    required this.time,
    required this.isNext,
    required this.passed,
    required this.notifies,
    required this.offset,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final colour = PrayerVisuals.color(time.slot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? Nocturne.mix(colour, 10) : null,
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Nocturne.neutral900)),
      ),
      child: Row(
        children: [
          V3IconTile(
            icon: PrayerVisuals.icon(time.slot),
            color: colour,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      time.slot.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            isNext ? FontWeight.w600 : FontWeight.w400,
                        color: passed ? Nocturne.neutral500 : Nocturne.text,
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Nocturne.mix(colour, 22),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Next',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: colour),
                        ),
                      ),
                    ],
                  ],
                ),
                if (offset != 0)
                  Text(
                    '${offset > 0 ? '+' : ''}$offset min adjustment',
                    style: const TextStyle(
                        fontSize: 11, color: Nocturne.neutral600),
                  ),
              ],
            ),
          ),
          Icon(
            notifies ? PhRegular.bellRinging : PhRegular.bell,
            size: 14,
            color: notifies ? colour : Nocturne.neutral700,
          ),
          const SizedBox(width: 10),
          V3Num(
            PrayerVisuals.clock(time.time),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isNext ? FontWeight.w600 : FontWeight.w500,
              color: passed ? Nocturne.neutral500 : Nocturne.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: last
              ? null
              : const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Nocturne.neutral900))),
          child: Row(
            children: [
              Icon(icon, size: 17, color: Nocturne.neutral500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: Nocturne.text)),
              ),
              if (value.isNotEmpty)
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13, color: Nocturne.neutral500),
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(PhRegular.caretRight,
                    size: 14, color: Nocturne.neutral600),
              ],
            ],
          ),
        ),
      );
}

/// Shown when the page is reached with the feature switched off.
class _PrayerOff extends StatelessWidget {
  const _PrayerOff();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhRegular.mosque, size: 40, color: Nocturne.neutral700),
              const SizedBox(height: 14),
              const Text(
                'Prayer times are off',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Nocturne.text),
              ),
              const SizedBox(height: 6),
              const Text(
                'Turn them on to see today’s times and get an alert at '
                'each prayer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: Nocturne.neutral500),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () =>
                    context.read<V3Nav>().goPage(V3Page.prayerSettings),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Nocturne.accent600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Set up prayer times',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Nocturne.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

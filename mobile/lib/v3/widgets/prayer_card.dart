import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/nocturne.dart';
import '../data/prayer/prayer_config.dart';
import '../data/prayer/prayer_controller.dart';
import '../phosphor_icons.dart';
import 'prayer_ring.dart';

/// The home-screen prayer card.
///
/// Returns a zero-size box whenever the feature is off, rather than being
/// wrapped in a `Visibility`: a disabled feature should build nothing, hold no
/// state and cost nothing.
class PrayerCard extends StatelessWidget {
  final VoidCallback? onTap;

  const PrayerCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final prayer = context.watch<PrayerController>();
    if (!prayer.showOnHome) return const SizedBox.shrink();

    final next = prayer.next!;
    final day = prayer.today!;
    final slot = next.next.slot;
    final colour = PrayerVisuals.color(slot);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Nocturne.neutral900),
            // A wash of the upcoming prayer's colour across the surface, so
            // the card shifts tone through the day without changing layout.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Nocturne.surface, colour, 0.14)!,
                Nocturne.surface,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PrayerRing(slot: slot, progress: next.progress),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              slot.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Nocturne.text,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              slot.arabic,
                              style: TextStyle(
                                fontSize: 13,
                                color: colour.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next.remaining.inSeconds <= 0
                              ? 'It is time'
                              : 'in ${PrayerVisuals.countdown(next.remaining)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Nocturne.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        PrayerVisuals.clock(next.next.time),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Nocturne.text,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhRegular.mapPin,
                              size: 11, color: Nocturne.neutral600),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              prayer.config.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Nocturne.neutral600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              PrayerDayRail(day: day, now: DateTime.now()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final t in day.times)
                    Text(
                      t.slot.label,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1,
                        color: t.slot == slot
                            ? PrayerVisuals.color(t.slot)
                            : Nocturne.neutral700,
                        fontWeight: t.slot == slot
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

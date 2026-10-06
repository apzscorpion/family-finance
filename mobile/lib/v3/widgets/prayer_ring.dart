import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';
import '../data/prayer/prayer_config.dart';
import '../data/prayer/prayer_service.dart';
import '../phosphor_icons.dart';

/// Colour and icon per slot, following the arc of the day: night blue at Fajr,
/// warming through the middle of the day and cooling back to violet at Isha.
///
/// These are not Nocturne roles, so like the category hues they are declared
/// once here rather than inline in each widget.
class PrayerVisuals {
  PrayerVisuals._();

  static Color color(PrayerSlot slot) => switch (slot) {
        PrayerSlot.fajr => const Color(0xFF7E8CE0),
        PrayerSlot.sunrise => const Color(0xFFE8B45E),
        PrayerSlot.dhuhr => const Color(0xFFE2C06D),
        PrayerSlot.asr => const Color(0xFFEE9A69),
        PrayerSlot.maghrib => const Color(0xFFE2849A),
        PrayerSlot.isha => const Color(0xFF8A80CB),
      };

  static IconData icon(PrayerSlot slot) => switch (slot) {
        PrayerSlot.fajr => PhRegular.moonStars,
        PrayerSlot.sunrise => PhRegular.sunHorizon,
        PrayerSlot.dhuhr => PhRegular.sun,
        PrayerSlot.asr => PhRegular.sunDim,
        PrayerSlot.maghrib => PhRegular.cloudSun,
        PrayerSlot.isha => PhRegular.moon,
      };

  /// The deeper stop used by the ring gradient, so the arc reads as a sweep
  /// rather than a flat band.
  static Color deep(PrayerSlot slot) =>
      Color.lerp(color(slot), Nocturne.bg, 0.45)!;

  /// 12-hour clock, matching the rest of the app's time formatting.
  static String clock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "1h 24m", "8m", "now". Deliberately coarse — the ring only ever repaints
  /// once a minute, so seconds would be a lie.
  static String countdown(Duration d) {
    if (d.inSeconds <= 0) return 'now';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// A circular countdown: a track, a swept progress arc in the colour of the
/// prayer being counted down to, and the slot's icon at the centre.
class PrayerRing extends StatelessWidget {
  final PrayerSlot slot;

  /// 0.0 at the start of the current window, 1.0 as the prayer arrives.
  final double progress;
  final double size;
  final double stroke;

  const PrayerRing({
    super.key,
    required this.slot,
    required this.progress,
    this.size = 56,
    this.stroke = 4,
  });

  @override
  Widget build(BuildContext context) {
    final color = PrayerVisuals.color(slot);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          deep: PrayerVisuals.deep(slot),
          stroke: stroke,
        ),
        child: Center(
          child: Icon(
            PrayerVisuals.icon(slot),
            size: size * 0.4,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color deep;
  final double stroke;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.deep,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final arcRect = Rect.fromCircle(center: centre, radius: radius);
    const start = -math.pi / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Nocturne.neutral800,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      arcRect,
      start,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [deep, color],
          transform: const GradientRotation(start),
        ).createShader(arcRect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.deep != deep ||
      old.stroke != stroke;
}

/// A horizontal rail of the day's six slots: a track with a filled portion up
/// to now, and a marker per prayer. The marker for the prayer in progress is
/// drawn larger and in its own colour.
class PrayerDayRail extends StatelessWidget {
  final PrayerDay day;
  final DateTime now;
  final double height;

  const PrayerDayRail({
    super.key,
    required this.day,
    required this.now,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(
          painter: _RailPainter(day: day, now: now),
          size: Size.infinite,
        ),
      );
}

class _RailPainter extends CustomPainter {
  final PrayerDay day;
  final DateTime now;

  const _RailPainter({required this.day, required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    final times = day.times;
    if (times.length < 2) return;

    // The rail spans Fajr to Isha; anything outside that is clamped to an end.
    final first = times.first.time;
    final last = times.last.time;
    final span = last.difference(first).inSeconds;
    if (span <= 0) return;

    double xFor(DateTime t) {
      final at = t.difference(first).inSeconds / span;
      // Inset so the end markers are not clipped by the rail's edge.
      const pad = 7.0;
      return pad + (size.width - pad * 2) * at.clamp(0.0, 1.0);
    }

    final y = size.height / 2;
    final trackPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Nocturne.neutral800;

    canvas.drawLine(Offset(7, y), Offset(size.width - 7, y), trackPaint);

    final elapsed = xFor(now);
    if (now.isAfter(first)) {
      canvas.drawLine(
        Offset(7, y),
        Offset(elapsed, y),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            colors: [Color(0xFF7E8CE0), Color(0xFFE2C06D)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    // The most recent slot that has started is the one in progress.
    final currentIndex = times.lastIndexWhere((e) => !e.time.isAfter(now));

    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final x = xFor(t.time);
      final passed = !t.time.isAfter(now);
      final colour = PrayerVisuals.color(t.slot);
      final isCurrent = i == currentIndex;

      if (isCurrent) {
        canvas.drawCircle(
          Offset(x, y),
          6.5,
          Paint()..color = colour.withValues(alpha: 0.25),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        isCurrent ? 4 : 3,
        Paint()..color = passed ? colour : Nocturne.neutral700,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      // Minute resolution: the rail is redrawn when the displayed minute
      // changes, not on every frame.
      old.now.minute != now.minute ||
      old.now.hour != now.hour ||
      old.day.date != day.date;
}

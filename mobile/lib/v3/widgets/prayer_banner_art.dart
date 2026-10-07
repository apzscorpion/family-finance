import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/prayer/prayer_config.dart';
import '../data/prayer/prayer_service.dart';
import 'prayer_ring.dart';

/// Draws the image shown when the prayer banner is expanded.
///
/// Android cannot blur what sits behind a notification — there is no backdrop
/// filter, and from API 31 the system wraps custom layouts in its own template.
/// So the frosted-glass look is *drawn here* rather than sampled from the
/// wallpaper: a gradient ground, soft light blooms, and translucent panels with
/// a bright top edge. Because we own every pixel, the theme is genuinely
/// selectable.
///
/// The result is a PNG handed to `BigPictureStyleInformation`.
class PrayerBannerArt {
  PrayerBannerArt._();

  /// 2:1 is the aspect Android gives the expanded big-picture area. Drawing at
  /// this size keeps text crisp without producing a needlessly large file —
  /// the bitmap crosses a Binder transaction, so it has to stay modest.
  static const int width = 1024;
  static const int height = 512;

  /// Renders the banner image and returns the encoded PNG bytes.
  static Future<Uint8List?> render({
    required PrayerConfig config,
    required PrayerDay day,
    required NextPrayer next,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(width.toDouble(), height.toDouble());

      _paintGround(canvas, size, config, next);
      _paintBlooms(canvas, size, config, next);
      _paintContent(canvas, size, config, day, next);

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      // A failed render must not cost the user their banner; the caller falls
      // back to a text-only notification.
      return null;
    }
  }

  // ── Ground ────────────────────────────────────────────────────────────────

  /// The two gradient stops for a theme. Aurora follows the prayer's own
  /// colour so the banner shifts through the day.
  static (Color, Color) _palette(PrayerConfig config, NextPrayer next) {
    final slot = next.next.slot;
    return switch (config.bannerTheme) {
      PrayerBannerTheme.aurora => (
          Color.lerp(PrayerVisuals.deep(slot), const Color(0xFF12142A), 0.35)!,
          Color.lerp(PrayerVisuals.color(slot), const Color(0xFF161826), 0.55)!,
        ),
      PrayerBannerTheme.dusk => (
          const Color(0xFF2A1B3D),
          const Color(0xFF6B3F5E),
        ),
      PrayerBannerTheme.emerald => (
          const Color(0xFF07251F),
          const Color(0xFF1E6F5C),
        ),
      PrayerBannerTheme.midnight => (
          const Color(0xFF070A18),
          const Color(0xFF1B2347),
        ),
      PrayerBannerTheme.sand => (
          const Color(0xFF2B2113),
          const Color(0xFF8A6A3B),
        ),
      PrayerBannerTheme.minimal => (
          const Color(0xFF161826),
          const Color(0xFF232532),
        ),
    };
  }

  static void _paintGround(
      Canvas canvas, Size size, PrayerConfig config, NextPrayer next) {
    final (top, bottom) = _palette(config, next);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width * 0.35, size.height),
          [top, bottom],
        ),
    );
  }

  /// Soft radial light. This is what sells the glass: the panels below pick up
  /// a gradient that is not uniform, so they read as translucent rather than
  /// as flat grey boxes.
  static void _paintBlooms(
      Canvas canvas, Size size, PrayerConfig config, NextPrayer next) {
    if (config.bannerTheme == PrayerBannerTheme.minimal) return;

    final accent = PrayerVisuals.color(next.next.slot);
    void bloom(Offset centre, double radius, Color colour) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(centre, radius, [
            colour.withValues(alpha: 0.42),
            colour.withValues(alpha: 0.0),
          ]),
      );
    }

    bloom(Offset(size.width * 0.80, size.height * 0.18), size.height * 0.75,
        accent);
    bloom(Offset(size.width * 0.12, size.height * 0.92), size.height * 0.60,
        Colors.white);
  }

  // ── Glass ─────────────────────────────────────────────────────────────────

  /// A translucent panel with a bright upper edge and a hairline border — the
  /// standard recipe for a frosted surface when real blur is unavailable.
  static void _glassPanel(Canvas canvas, RRect rect) {
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.outerRect.topLeft,
          rect.outerRect.bottomLeft,
          [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  static void _paintContent(
    Canvas canvas,
    Size size,
    PrayerConfig config,
    PrayerDay day,
    NextPrayer next,
  ) {
    const pad = 44.0;

    _text(
      canvas,
      config.locationLabel.toUpperCase(),
      Offset(pad, pad - 4),
      size: 20,
      weight: FontWeight.w600,
      colour: Colors.white.withValues(alpha: 0.62),
      letterSpacing: 2.0,
    );

    _text(
      canvas,
      day.hijri.label,
      Offset(size.width - pad, pad - 4),
      size: 20,
      weight: FontWeight.w500,
      colour: Colors.white.withValues(alpha: 0.62),
      align: TextAlign.right,
      maxWidth: size.width * 0.5,
    );

    switch (config.bannerContent) {
      case PrayerBannerContent.allTimes:
        _paintAllTimes(canvas, size, day, next, pad);
      case PrayerBannerContent.currentEnds:
        _paintCurrentEnds(canvas, size, next, pad);
      case PrayerBannerContent.nextAndCurrent:
        _paintNextAndCurrent(canvas, size, next, pad);
      case PrayerBannerContent.nextOnly:
        _paintNextOnly(canvas, size, next, pad);
    }
  }

  static void _paintNextOnly(
      Canvas canvas, Size size, NextPrayer next, double pad) {
    final slot = next.next.slot;
    final accent = PrayerVisuals.color(slot);

    _glassPanel(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, 120, size.width - pad * 2, size.height - 120 - pad),
        const Radius.circular(36),
      ),
    );

    _text(canvas, slot.label, Offset(pad + 44, 168),
        size: 76, weight: FontWeight.w700, colour: Colors.white);
    _text(canvas, slot.arabic, Offset(pad + 44, 262),
        size: 40, weight: FontWeight.w500, colour: accent);

    _text(
      canvas,
      PrayerVisuals.clock(next.next.time),
      Offset(size.width - pad - 44, 172),
      size: 68,
      weight: FontWeight.w700,
      colour: Colors.white,
      align: TextAlign.right,
      maxWidth: size.width * 0.45,
    );
    _text(
      canvas,
      next.remaining.inSeconds <= 0
          ? 'now'
          : 'in ${PrayerVisuals.countdown(next.remaining)}',
      Offset(size.width - pad - 44, 262),
      size: 34,
      weight: FontWeight.w500,
      colour: Colors.white.withValues(alpha: 0.70),
      align: TextAlign.right,
      maxWidth: size.width * 0.45,
    );

    _progressRail(canvas, size, next, y: size.height - pad - 34, pad: pad + 44);
  }

  static void _paintNextAndCurrent(
      Canvas canvas, Size size, NextPrayer next, double pad) {
    final half = (size.width - pad * 2 - 20) / 2;

    void card(double left, String kicker, String name, String time,
        String sub, Color accent) {
      _glassPanel(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 120, half, size.height - 120 - pad),
          const Radius.circular(32),
        ),
      );
      _text(canvas, kicker, Offset(left + 32, 150),
          size: 20,
          weight: FontWeight.w600,
          colour: Colors.white.withValues(alpha: 0.55),
          letterSpacing: 1.6);
      _text(canvas, name, Offset(left + 32, 186),
          size: 52, weight: FontWeight.w700, colour: Colors.white);
      _text(canvas, time, Offset(left + 32, 258),
          size: 44, weight: FontWeight.w600, colour: accent);
      _text(canvas, sub, Offset(left + 32, 320),
          size: 26,
          weight: FontWeight.w500,
          colour: Colors.white.withValues(alpha: 0.65),
          maxWidth: half - 64);
    }

    final current = next.current;
    card(
      pad,
      'NOW',
      current?.slot.label ?? '—',
      current == null ? '' : PrayerVisuals.clock(current.time),
      current == null ? 'Before Fajr' : 'Started',
      current == null
          ? Colors.white
          : PrayerVisuals.color(current.slot),
    );
    card(
      pad + half + 20,
      'NEXT',
      next.next.slot.label,
      PrayerVisuals.clock(next.next.time),
      next.remaining.inSeconds <= 0
          ? 'now'
          : 'in ${PrayerVisuals.countdown(next.remaining)}',
      PrayerVisuals.color(next.next.slot),
    );
  }

  static void _paintCurrentEnds(
      Canvas canvas, Size size, NextPrayer next, double pad) {
    final current = next.current;
    final accent = PrayerVisuals.color(current?.slot ?? next.next.slot);

    _glassPanel(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, 120, size.width - pad * 2, size.height - 120 - pad),
        const Radius.circular(36),
      ),
    );

    _text(
      canvas,
      current == null ? 'Fajr has not started' : '${current.slot.label} ends in',
      Offset(pad + 44, 170),
      size: 40,
      weight: FontWeight.w500,
      colour: Colors.white.withValues(alpha: 0.72),
    );
    _text(
      canvas,
      next.remaining.inSeconds <= 0
          ? 'now'
          : PrayerVisuals.countdown(next.remaining),
      Offset(pad + 44, 224),
      size: 92,
      weight: FontWeight.w700,
      colour: Colors.white,
    );
    _text(
      canvas,
      '${next.next.slot.label} at ${PrayerVisuals.clock(next.next.time)}',
      Offset(pad + 44, 340),
      size: 32,
      weight: FontWeight.w500,
      colour: accent,
    );

    _progressRail(canvas, size, next, y: size.height - pad - 34, pad: pad + 44);
  }

  static void _paintAllTimes(Canvas canvas, Size size, PrayerDay day,
      NextPrayer next, double pad) {
    _glassPanel(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, 112, size.width - pad * 2, size.height - 112 - pad),
        const Radius.circular(32),
      ),
    );

    final times = day.times;
    final slotWidth = (size.width - pad * 2 - 48) / times.length;

    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final isNext = t.slot == next.next.slot;
      final centre = pad + 24 + slotWidth * i + slotWidth / 2;
      final accent = PrayerVisuals.color(t.slot);

      if (isNext) {
        _glassPanel(
          canvas,
          RRect.fromRectAndRadius(
            Rect.fromLTWH(centre - slotWidth / 2 + 6, 136, slotWidth - 12,
                size.height - 136 - pad - 16),
            const Radius.circular(24),
          ),
        );
      }

      // Six columns across 1024px is tight, so these are deliberately smaller
      // than the single-prayer layouts and clamped inside the column: at the
      // previous sizes "12:14 PM" ran into its neighbour.
      final columnText = slotWidth - 20;

      _text(canvas, t.slot.label, Offset(centre, 178),
          size: 24,
          weight: isNext ? FontWeight.w700 : FontWeight.w500,
          colour: isNext ? Colors.white : Colors.white.withValues(alpha: 0.62),
          align: TextAlign.center,
          maxWidth: columnText);
      _text(canvas, PrayerVisuals.clock(t.time), Offset(centre, 226),
          size: 28,
          weight: FontWeight.w700,
          colour: isNext ? accent : Colors.white.withValues(alpha: 0.80),
          align: TextAlign.center,
          maxWidth: columnText);
      _text(canvas, t.slot.arabic, Offset(centre, 276),
          size: 24,
          weight: FontWeight.w500,
          colour: accent.withValues(alpha: isNext ? 0.95 : 0.55),
          align: TextAlign.center,
          maxWidth: columnText);
    }

    _progressRail(canvas, size, next, y: size.height - pad - 30, pad: pad + 24);
  }

  /// A thin rail showing how far through the current window we are.
  static void _progressRail(Canvas canvas, Size size, NextPrayer next,
      {required double y, required double pad}) {
    final right = size.width - pad;
    final paintTrack = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawLine(Offset(pad, y), Offset(right, y), paintTrack);

    final done = pad + (right - pad) * next.progress.clamp(0.0, 1.0);
    if (done <= pad) return;
    canvas.drawLine(
      Offset(pad, y),
      Offset(done, y),
      Paint()
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          Offset(pad, y),
          Offset(right, y),
          [
            PrayerVisuals.color(next.current?.slot ?? next.next.slot),
            PrayerVisuals.color(next.next.slot),
          ],
        ),
    );
  }

  // ── Text helper ───────────────────────────────────────────────────────────

  /// Draws text anchored by [align]: left edge, centre, or right edge at
  /// [at].dx. Canvas has no text alignment of its own, so the offset is
  /// computed from the laid-out width.
  static void _text(
    Canvas canvas,
    String value,
    Offset at, {
    required double size,
    required FontWeight weight,
    required Color colour,
    TextAlign align = TextAlign.left,
    double letterSpacing = 0,
    double? maxWidth,
  }) {
    if (value.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          // Inter is bundled; naming it keeps the banner's type consistent
          // with the rest of the app.
          fontFamily: 'Inter',
          // Inter carries no Arabic, so the prayer names in Arabic would draw
          // as empty boxes without an explicit fallback. Android ships the
          // Noto Arabic faces; the generic names cover other vendors.
          fontFamilyFallback: const [
            'Noto Naskh Arabic',
            'Noto Sans Arabic',
            'Droid Arabic Naskh',
            'Roboto',
          ],
          fontSize: size,
          fontWeight: weight,
          color: colour,
          letterSpacing: letterSpacing,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);

    final dx = switch (align) {
      TextAlign.right => at.dx - painter.width,
      TextAlign.center => at.dx - painter.width / 2,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy));
    painter.dispose();
  }

  /// Unused today, kept because the ring is the obvious next embellishment and
  /// the maths is easy to get wrong.
  static double sweepFor(double progress) => 2 * math.pi * progress;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';

/// One wedge of the spending doughnut.
class V3DonutSlice {
  final String label;
  final double value;
  final Color color;

  const V3DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// The "Where it went" doughnut.
///
/// The design builds it as a CSS `conic-gradient` inside a 128×128 circle with
/// `inset:15px` punched out for the centre label, plus
/// `box-shadow:0 0 28px color-mix(in oklch, var(--color-accent) 14%, transparent)`.
/// A conic gradient has hard stops between segments, so this paints flat arcs
/// rather than interpolating between slice colours.
class V3Donut extends StatefulWidget {
  final List<V3DonutSlice> slices;
  final double size;

  /// `inset:15px` — the gap between the outer circle and the centre well.
  final double thickness;

  /// Fills the hole, matching whatever panel the doughnut sits on.
  final Color centerColor;
  final Widget? center;

  /// Animates the sweep on first build and whenever the data changes.
  final bool animate;

  const V3Donut({
    super.key,
    required this.slices,
    this.size = 128,
    this.thickness = 15,
    this.centerColor = Nocturne.surface,
    this.center,
    this.animate = true,
  });

  @override
  State<V3Donut> createState() => _V3DonutState();
}

class _V3DonutState extends State<V3Donut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    widget.animate ? _c.forward() : _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant V3Donut old) {
    super.didUpdateWidget(old);
    if (widget.animate && old.slices != widget.slices) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // 0 0 28px color-mix(in oklch, var(--color-accent) 14%, transparent)
            BoxShadow(
              color: Nocturne.mix(Nocturne.accent, 14),
              blurRadius: 28,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) => CustomPaint(
            painter: _DonutPainter(
              slices: widget.slices,
              thickness: widget.thickness,
              centerColor: widget.centerColor,
              progress: _a.value,
            ),
            child: Center(child: widget.center),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<V3DonutSlice> slices;
  final double thickness;
  final Color centerColor;
  final double progress;

  _DonutPainter({
    required this.slices,
    required this.thickness,
    required this.centerColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.shortestSide / 2;
    final center = rect.center;

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Nocturne.neutral900,
      );
      canvas.drawCircle(
        center,
        radius - thickness,
        Paint()..color = centerColor,
      );
      return;
    }

    // conic-gradient starts at 12 o'clock; Flutter's 0 radians is 3 o'clock.
    var start = -math.pi / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi * progress;
      if (sweep <= 0) continue;
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        // A hairline overlap stops seams showing between adjacent wedges.
        sweep + 0.004,
        true,
        paint,
      );
      start += sweep;
    }

    // Punch the centre well: `position:absolute; inset:15px; border-radius:50%`.
    canvas.drawCircle(
      center,
      radius - thickness,
      Paint()..color = centerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.slices != slices ||
      old.thickness != thickness ||
      old.centerColor != centerColor;
}

/// The stacked label inside the doughnut: SPENT / amount / N categories.
class V3DonutCenter extends StatelessWidget {
  final String amount;
  final int categoryCount;

  const V3DonutCenter({
    super.key,
    required this.amount,
    required this.categoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SPENT',
          style: TextStyle(
            fontSize: 10,
            color: Nocturne.neutral500,
            letterSpacing: 0.6, // .06em at 10px
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Nocturne.text,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '$categoryCount categories',
          style: const TextStyle(fontSize: 10, color: Nocturne.neutral500),
        ),
      ],
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/nocturne.dart';

/// Shared building blocks for the v3 screens, each matching a repeated pattern
/// in `Family Spend Tracker v3.dc.html`.

/// A section heading row: a 14px/500 title on the left and either muted meta
/// text or an accent action on the right.
///   `margin:24px 16px 8px; display:flex; align-items:baseline; …`
class V3SectionHeader extends StatelessWidget {
  final String title;
  final String? meta;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? badge;
  final EdgeInsets margin;

  const V3SectionHeader({
    super.key,
    required this.title,
    this.meta,
    this.actionLabel,
    this.onAction,
    this.badge,
    this.margin = const EdgeInsets.fromLTRB(16, 24, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: badge != null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.baseline,
        textBaseline: badge != null ? null : TextBaseline.alphabetic,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Nocturne.text)),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
          const Spacer(),
          if (meta != null)
            Text(meta!,
                style: const TextStyle(fontSize: 12, color: Nocturne.neutral500)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 12, color: Nocturne.accent300)),
            ),
        ],
      ),
    );
  }
}

/// `background:var(--color-surface); border:1px solid var(--color-neutral-900)`
/// — the standard panel used by nearly every list block.
class V3Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double radius;
  final Color? background;
  final Color? border;

  const V3Panel({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.background,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? Nocturne.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? Nocturne.neutral900, width: 1),
      ),
      child: child,
    );
  }
}

/// The 1px `border-bottom:1px solid var(--color-neutral-900)` the design puts
/// between rows inside a panel. The design leaves it on the final row too.
class V3RowDivider extends StatelessWidget {
  const V3RowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: Nocturne.neutral900);
}

/// A rounded square icon tile: `width/height`, `border-radius`, a tinted
/// background and the category colour as foreground.
class V3IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;
  final Color? background;

  const V3IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.radius = 12,
    this.iconSize = 18,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? Nocturne.mix(color, 22),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Circular member avatar. The design draws the selected state as a double ring
/// — `box-shadow:0 0 0 2px <ground>, 0 0 0 3px <ring>` — which is a 1px ring
/// separated from the avatar by 2px of the page ground.
class V3Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  final double size;
  final double fontSize;
  final Color? ringColor;
  final Color ringGround;
  final double opacity;
  final IconData? icon;

  const V3Avatar({
    super.key,
    required this.initial,
    required this.color,
    this.size = 40,
    this.fontSize = 15,
    this.ringColor,
    this.ringGround = Nocturne.bg,
    this.opacity = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, size: fontSize + 1, color: Nocturne.text)
          : Text(initial,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Nocturne.text)),
    );

    final avatar = ringColor == null
        ? inner
        : Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor!, width: 1),
              color: ringGround,
            ),
            child: inner,
          );

    return opacity == 1 ? avatar : Opacity(opacity: opacity, child: avatar);
  }
}

/// A thin progress bar with an optional threshold tick, as used by the hero
/// budget bar, money-source cards and the budget list.
class V3ProgressBar extends StatelessWidget {
  final double fraction;
  final Color fill;
  final double height;
  final Color track;

  /// 0..1 position of the dashed alert marker, or null for none.
  final double? threshold;

  const V3ProgressBar({
    super.key,
    required this.fraction,
    required this.fill,
    this.height = 6,
    this.track = Nocturne.neutral900,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: threshold == null ? height : math.max(height, 12),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              height: height,
              width: w * f,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            if (threshold != null)
              Positioned(
                left: (w * threshold!.clamp(0.0, 1.0)) - 1,
                child: Container(
                  width: 2,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Nocturne.neutral400,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// A pill chip: optional leading avatar or icon, a label, optional trailing
/// count. Used for scope chips, category filters, sources and methods.
class V3Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String? trailing;
  final double height;

  const V3Chip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.icon,
    this.iconColor,
    this.trailing,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: EdgeInsets.only(left: leading != null ? 4 : 12, right: 12),
        decoration: BoxDecoration(
          color: selected ? Nocturne.accent900 : Nocturne.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: selected ? Nocturne.accent600 : Nocturne.neutral800,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 7)],
            if (icon != null) ...[
              Icon(icon, size: 14, color: iconColor ?? Nocturne.neutral400),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: selected ? Nocturne.accent100 : Nocturne.neutral300)),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Text(trailing!,
                  style: const TextStyle(
                      fontSize: 10.5, color: Nocturne.neutral500)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two-up segmented control used for 7D/30D and Expense/Income.
class V3Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;
  final Color ground;
  final EdgeInsets padding;

  const V3Segmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 26,
    this.ground = const Color(0x47000000),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: i == selected ? Nocturne.accent700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        i == selected ? Nocturne.accent100 : Nocturne.neutral400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tabular-figure text. The design sets `font-variant-numeric:tabular-nums` on
/// every amount so columns of numbers line up.
class V3Num extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? align;

  const V3Num(this.text, {super.key, required this.style, this.align});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

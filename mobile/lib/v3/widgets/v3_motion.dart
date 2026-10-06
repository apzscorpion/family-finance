import 'package:flutter/material.dart';

/// Motion primitives transcribed from the design's keyframes.
///
///   @keyframes ftRise { from{opacity:0;transform:translateY(10px)} to{...} }
///   @keyframes ftIn   { from{opacity:0;transform:translateX(28px)} to{...} }
///   @keyframes ftUp   { from{transform:translateY(100%)}           to{...} }
///   @keyframes ftFade { from{opacity:0}                            to{...} }
///   @keyframes fnBlink{ 0%,50%{opacity:1} 51%,100%{opacity:0} }
///   style-active="transform:scale(.94)"
///
/// The design's easing for entrances is `cubic-bezier(.2,.8,.2,1)`.
const Cubic kV3Ease = Cubic(.2, .8, .2, 1);

/// `animation: ftRise .25s ease-out` — the entrance used by note cards,
/// detected-payment cards, the shared-with panel and the split panel.
///
/// [index] staggers a list so rows arrive in sequence rather than together.
class V3Rise extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  /// Vertical travel. The design uses 10px for ftRise and 8px for fnRise.
  final double offset;

  const V3Rise({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 250),
    this.offset = 10,
  });

  @override
  State<V3Rise> createState() => _V3RiseState();
}

class _V3RiseState extends State<V3Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    // A short per-item delay reads as the list settling into place; beyond a
    // handful of rows it would just feel slow, so the stagger is capped.
    final delay = Duration(milliseconds: (widget.index.clamp(0, 8)) * 35);
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// `style-active="transform:scale(.94)"` — the press feedback on quick
/// actions, the keypad and the floating add buttons.
class V3Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const V3Press({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.94,
  });

  @override
  State<V3Press> createState() => _V3PressState();
}

class _V3PressState extends State<V3Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// `@keyframes fnBlink { 0%,50%{opacity:1} 51%,100%{opacity:0} }` — the
/// remote-collaborator caret in the note editor. The step at 51% is a hard
/// switch, not a fade, so the opacity is toggled rather than tweened.
class V3Blink extends StatefulWidget {
  final Color color;
  final double height;

  const V3Blink({super.key, required this.color, this.height = 15});

  @override
  State<V3Blink> createState() => _V3BlinkState();
}

class _V3BlinkState extends State<V3Blink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: _c.value < 0.5 ? 1 : 0,
          child: Container(
            width: 2,
            height: widget.height,
            color: widget.color,
          ),
        ),
      );
}

/// Sheet transition matching `animation: ftUp .3s cubic-bezier(.2,.8,.2,1)`,
/// which is springier than Flutter's default sheet curve.
class V3SheetRoute<T> extends ModalBottomSheetRoute<T> {
  V3SheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.backgroundColor,
    // ModalBottomSheetRoute spells this one `modalBarrierColor`; `barrierColor`
    // is the read-only getter it inherits from ModalRoute.
    super.modalBarrierColor,
  }) : super(useSafeArea: false);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: kV3Ease);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

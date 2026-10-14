import 'package:flutter/material.dart';

/// "KinPurse" in the logo's colours: "Kin" (family) in its warm gold,
/// "Purse" (money) in its teal, each with the logo's top-to-bottom shading.
class KinPurseWordmark extends StatelessWidget {
  final double size;
  const KinPurseWordmark({super.key, this.size = 26});

  static const gold = [Color(0xFFFFE595), Color(0xFFC0933F)];
  static const teal = [Color(0xFF45C3CE), Color(0xFF1E7F8E)];

  Widget _part(String text, List<Color> colors, FontWeight weight) =>
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
        child: Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'KinPurse',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _part('Kin', gold, FontWeight.w700),
              _part('Purse', teal, FontWeight.w600),
            ],
          ),
        ),
      );
}

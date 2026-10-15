import 'package:flutter/material.dart';

/// "KinPurse" in the logo's blue: "Kin" lighter, "Purse" deeper, each with
/// a top-to-bottom shading.
class KinPurseWordmark extends StatelessWidget {
  final double size;
  const KinPurseWordmark({super.key, this.size = 26});

  static const kin = [Color(0xFF7DB4FF), Color(0xFF0169FE)]; // "Kin", logo blue
  static const purse = [Color(0xFF0169FE), Color(0xFF0050C8)]; // "Purse"

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
              _part('Kin', kin, FontWeight.w700),
              _part('Purse', purse, FontWeight.w600),
            ],
          ),
        ),
      );
}

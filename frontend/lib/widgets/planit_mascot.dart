import 'package:flutter/material.dart';

class PlanitMascot extends StatelessWidget {
  const PlanitMascot({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/planit_mascot.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: 192,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );
}

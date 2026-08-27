import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FnosLogo extends StatelessWidget {
  const FnosLogo({
    super.key,
    this.width = 24,
    this.height = 24,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo-B-Z1b4kd.svg',
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: 'fnOS',
    );
  }
}

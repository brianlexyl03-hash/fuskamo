import 'dart:ui';
import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius borderRadius;
  final Color tint;
  final EdgeInsetsGeometry? padding;

  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.14,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.tint = Colors.white,
    this.padding,
  });

  factory GlassSurface.circle({
    Key? key,
    required Widget child,
    double size = 44,
    double blur = 16,
    double opacity = 0.16,
  }) {
    return GlassSurface(
      key: key,
      blur: blur,
      opacity: opacity,
      borderRadius: BorderRadius.circular(size / 2),
      padding: EdgeInsets.zero,
      child: SizedBox(width: size, height: size, child: Center(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: opacity),
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: child,
      ),
    ),
  );
}

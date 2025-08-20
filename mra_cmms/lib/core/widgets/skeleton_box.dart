import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadiusGeometry borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.50);
    final highlight = scheme.surfaceContainerHighest.withValues(alpha: 0.25);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        final bg = Color.lerp(base, highlight, (t * 2 % 1))!;
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: borderRadius,
          ),
        );
      },
    );
  }
}

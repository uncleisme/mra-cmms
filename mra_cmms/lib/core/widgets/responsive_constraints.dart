import 'package:flutter/material.dart';

/// A simple wrapper that centers content and constrains max width on wide screens,
/// while keeping natural full-width behavior on phones.
class ResponsiveConstraints extends StatelessWidget {
  const ResponsiveConstraints({
    super.key,
    required this.child,
    this.maxWidth = 1000,
    this.breakpoint = 900,
    this.horizontalMarginWide = 20,
    this.horizontalMarginNarrow = 12,
  });

  final Widget child;
  final double maxWidth;
  final double breakpoint;
  final double horizontalMarginWide;
  final double horizontalMarginNarrow;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= breakpoint;
    final horizontal = isWide ? horizontalMarginWide : horizontalMarginNarrow;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? maxWidth : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}

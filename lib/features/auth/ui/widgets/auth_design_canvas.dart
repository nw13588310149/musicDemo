import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthDesignCanvas extends StatelessWidget {
  const AuthDesignCanvas({
    required this.builder,
    this.backgroundColor = const Color(0xFFF2ECFF),
    super.key,
  });

  static const Size designSize = Size(1180, 820);

  final Widget Function(double scale) builder;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / designSize.width,
            constraints.maxHeight / designSize.height,
          );

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: designSize.width * scale,
              height: designSize.height * scale,
              child: RepaintBoundary(child: builder(scale)),
            ),
          );
        },
      ),
    );
  }
}


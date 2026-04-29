import 'package:flutter/material.dart';

import 'shell_layout.dart';

class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    required this.sidebar,
    required this.topBar,
    required this.child,
    super.key,
    this.floatingChild,
    this.sidebarWidth = 178,
    this.backgroundColor = const Color(0xFFEFF3FC),
    this.contentPadding = const EdgeInsets.all(16),
    this.contentGap = 16,
  });

  final Widget sidebar;
  final Widget topBar;
  final Widget child;
  final Widget? floatingChild;
  final double sidebarWidth;
  final Color backgroundColor;
  final EdgeInsets contentPadding;
  final double contentGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = DashboardScaleScope.fromSize(constraints.biggest);
        final scaledSidebarWidth = scale.ui(sidebarWidth);
        final scaledContentPadding = EdgeInsets.fromLTRB(
          scale.ui(contentPadding.left),
          scale.ui(contentPadding.top),
          scale.ui(contentPadding.right),
          scale.ui(contentPadding.bottom),
        );

        return DashboardScaleScope(
          data: scale,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: ColoredBox(
              color: backgroundColor,
              child: SafeArea(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          width: scaledSidebarWidth,
                          child: sidebar,
                        ),
                        Expanded(
                          child: Padding(
                            padding: scaledContentPadding,
                            child: Column(
                              children: [
                                topBar,
                                SizedBox(height: scale.ui(contentGap)),
                                Expanded(child: child),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (floatingChild != null)
                      Positioned(
                        right: scale.ui(16),
                        bottom: scale.ui(18),
                        child: floatingChild!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

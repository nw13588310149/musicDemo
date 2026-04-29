import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/shell_controller.dart';
import 'dashboard_scaffold.dart';
import 'shell_layout.dart';
import 'widgets/shell_left_nav.dart';
import 'widgets/shell_top_bar.dart';

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({
    required this.currentRoute,
    required this.child,
    super.key,
  });

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shellControllerProvider);
    final controller = ref.read(shellControllerProvider.notifier);

    return DashboardScaffold(
      sidebarWidth: state.collapsed
          ? ShellLayoutSpec.collapsedSidebarWidth
          : ShellLayoutSpec.sidebarWidth,
      sidebar: RepaintBoundary(
        child: ShellLeftNav(
          state: state,
          currentRoute: currentRoute,
          onToggleCollapse: controller.toggleCollapse,
          onNavigate: (route) => _navigate(context, route),
        ),
      ),
      topBar: ShellTopBar(
        state: state,
        onNavigate: (route) => _navigate(context, route),
        onLogout: controller.logout,
        onMarkAllRead: controller.markAllNoticeRead,
        onLoadProvinces: controller.loadProvinces,
        onUpdateProvince: controller.updateProvince,
      ),
      child: RepaintBoundary(child: child),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (route == currentRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

}

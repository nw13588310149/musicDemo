import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../recording_system/state/recording_system_controller.dart';
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
          onNavigate: (route) => _navigate(context, ref, route),
        ),
      ),
      topBar: ShellTopBar(
        state: state,
        onNavigate: (route) => _navigate(context, ref, route),
        onLogout: controller.logout,
        onMarkAllRead: controller.markAllNoticeRead,
        onLoadProvinces: controller.loadProvinces,
        onUpdateProvince: controller.updateProvince,
      ),
      child: RepaintBoundary(child: child),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    if (route == currentRoute) {
      // 录音系统的导航项再次点击时，直接调用 controller 把视图归位到列表
      // 首页（同时停掉在跑的录音 / 试听）。其他模块再点同一项保持原有"啥
      // 也不做"的行为，避免影响它们的页内 UI 状态。
      if (route == RoutePaths.recording) {
        ref
            .read(recordingSystemControllerProvider.notifier)
            .enterListHome();
      }
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }
}

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
      // 应用户要求：在带音频播放器的页面，弹出底部钢琴键盘时不要让播放器
      // 跟着上推。Scaffold 默认会因 viewInsets 把 body 收缩——这里对播放
      // 类路由把 resizeToAvoidBottomInset 关掉，整个 body 保持原高度，
      // 钢琴/小键盘自然以"覆盖层"的姿态浮在播放区域之上。
      // 其它路由（AI 聊天、注册表单等）保持默认的 resize=true，避免输入框
      // 被键盘挡住。
      resizeToAvoidBottomInset: !_routeLocksLayoutForKeyboard(currentRoute),
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

  /// 路由白名单：键盘弹起时这些页面整页保持不动（Scaffold 不 resize）。
  /// 当前都是"页面里塞了播放器 + 钢琴键盘"的入口，且页内本身没有需要避让
  /// 系统软键盘的输入框（评论 / 分享 dialog 由各自的 dialog 自行处理布局）：
  ///   - `/musicPlay`：通用音频播放页（听写、节奏、和弦…）；
  ///   - `/answerEnd2`：试题模块"听写 / 视唱 / 乐理"的播放变体；
  /// 其它路由（AI 聊天、注册表单、个人资料等）保持默认 resize=true。
  bool _routeLocksLayoutForKeyboard(String route) {
    return route == RoutePaths.musicPlay || route == RoutePaths.answerEnd2;
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

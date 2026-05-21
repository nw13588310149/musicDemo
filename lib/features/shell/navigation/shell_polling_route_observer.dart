import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../state/shell_controller.dart';

/// 根据当前路由暂停 / 恢复 Shell 层的 myInfo / schoolList / 未读消息轮询。
///
/// 登出或 401 会清 token 并主动 [ShellController.pausePolling]；本观察器
/// 作为兜底，确保用户停留在登录 / 注册 / 找回密码页时不会继续打接口。
class ShellPollingRouteObserver extends NavigatorObserver {
  ShellPollingRouteObserver(this._ref);

  final WidgetRef _ref;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncPollingForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _syncPollingForRoute(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _syncPollingForRoute(previousRoute);
    }
  }

  void _syncPollingForRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null || !_ref.exists(shellControllerProvider)) {
      return;
    }
    final controller = _ref.read(shellControllerProvider.notifier);
    if (AppRouter.isAuthRoute(routeName)) {
      controller.pausePolling();
    } else {
      controller.resumePolling();
    }
  }
}

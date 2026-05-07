import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config_repository.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 已经登录过的用户冷启动时，异步刷新一次文件服务器配置；游客 token
    // （如 "youke"）也走相同路径，确保拿到最新的 fileBaseUrl。
    final storage = ref.read(appStorageProvider);
    if (storage.token.isNotEmpty) {
      final repo = ref.read(appConfigRepositoryProvider);
      unawaited(repo.refreshFileBaseUrl());
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(appStorageProvider);
    final initialRoute = storage.token.isEmpty
        ? RoutePaths.login
        : RoutePaths.home;

    return MaterialApp(
      title: '音乐之路',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // 全局文本行为：
      // 1. 锁定 textScaler = 1.0：禁用 iOS/Android 系统的 "Display & Text Size"
      //    缩放，保证 Web 与平板上同一个 fontSize 渲染出相同的逻辑像素，
      //    避免 iPad 上文字"莫名偏小"。
      // 2. DefaultTextHeightBehavior：让首/末行不再应用 height leading，
      //    与 CSS/Figma 行为一致，解决全局"文字偏下、上下间距偏宽"。
      // 3. 根级 _TapOutsideToDismissKeyboard：点击非可交互空白区域自动收起
      //    软键盘，解决 iPad/iOS 上多行 TextField（Return 键变换行）+ 没有
      //    "收起键盘"按钮时无法关闭键盘的问题。
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: DefaultTextHeightBehavior(
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            child: _TapOutsideToDismissKeyboard(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

/// 应用根级"点外面收键盘"包装。
///
/// 实现原理：
/// - 用 [GestureDetector] 监听 `onTap`，配合 `HitTestBehavior.translucent`
///   让自己加入命中测试但不挡住下层；
/// - 子树内的按钮 / TextField 自带 GestureDetector / Listener，会在手势
///   竞技场中胜出，所以正常点按交互不会被打断；
/// - 只有真正"点到没有任何手势消费者的空白区域"时，根级 `onTap` 才会
///   触发，调用 `FocusManager.instance.primaryFocus?.unfocus()` 收起软
///   键盘。
///
/// 用 `unfocus(disposition: UnfocusDisposition.scope)` 而不是默认的
/// `previouslyFocusedChild`，避免焦点回到链路中的某个父 FocusScope 时
/// 部分 TextField 仍维持 IME 连接、键盘不下去。
class _TapOutsideToDismissKeyboard extends StatelessWidget {
  const _TapOutsideToDismissKeyboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // 不能用 onTapDown：那会立刻触发，干扰按钮的 splash / 按下态。
      // onTap 只在确认是"轻点"且没人抢走手势时才回调。
      onTap: () {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;
        focus.unfocus(disposition: UnfocusDisposition.scope);
      },
      child: child,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config_repository.dart';
import '../features/music_companion/audio/music_companion_audio_engine.dart';
import '../core/network/chat_socket_service.dart';
import '../features/ai_chat/state/ai_chat_socket_dispatcher.dart';
import '../core/permissions/first_launch_permission_host.dart';
import '../core/providers/app_providers.dart' show appStorageProvider, bindApiUnauthorizedSessionCleanup;
import '../core/push/push_notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/keyboard_dismisser.dart';
import '../features/auth/data/auth_repository.dart';
import 'router/app_navigator.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<String>? _cidSubscription;

  @override
  void initState() {
    super.initState();
    bindApiUnauthorizedSessionCleanup(ref);
    // ────────────────────────────────────────────────────────────────────
    // 启动稳健化：所有"可能触发原生 / 同步抛错"的副作用都挪到首帧后再执行。
    //
    // 历史教训：
    //   • commit afc74d7（fix:修复闪退）把 GeTui startSdk / SoLoud 预热
    //     从 main() 推迟到首帧后，治掉了一次 iPad 冷启动闪退。
    //   • 之后又在 initState 同步阶段新增 `chatSocketServiceProvider.connect()`
    //     + `aiChatSocketDispatcherProvider` 的 read，会在 Flutter Engine
    //     渲染第一帧前同步建 TCP/TLS。iPad 在弱网 / VPN / 代理 / 企业网络
    //     栈下，`WebSocketChannel.connect` 的同步前置握手有概率把 Dart
    //     异常抛在 main-isolate 启动阶段，表现为应用图标点开"立马闪退"。
    //
    // 解决：把 WebSocket / 流式 dispatcher / fileBaseUrl 刷新统一放进
    // postFrameCallback，并在内部 try-catch 兜底；启动期 dart 代码尽量
    // 只做纯字段读 / 字符串拼接。
    // ────────────────────────────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(ref.read(pushNotificationServiceProvider).initialize());
      } catch (e, st) {
        debugPrint('pushNotificationService.initialize failed: $e\n$st');
      }
      try {
        unawaited(warmupMusicCompanionPianoAudio());
      } catch (e, st) {
        debugPrint('warmupMusicCompanionPianoAudio failed: $e\n$st');
      }

      final storage = ref.read(appStorageProvider);
      if (storage.token.isNotEmpty) {
        try {
          final repo = ref.read(appConfigRepositoryProvider);
          unawaited(repo.refreshFileBaseUrl());
        } catch (e, st) {
          debugPrint('refreshFileBaseUrl failed: $e\n$st');
        }
        try {
          // 全局 WebSocket 长连接：承担 AI 助手 + 系统事件 + 群聊推送。
          ref.read(chatSocketServiceProvider).connect();
        } catch (e, st) {
          debugPrint('chatSocketService.connect failed: $e\n$st');
        }
        try {
          // 预热 AI WS 分发器，确保登录后流式帧不会因页面未挂载而丢失。
          ref.read(aiChatSocketDispatcherProvider);
        } catch (e, st) {
          debugPrint('aiChatSocketDispatcher init failed: $e\n$st');
        }
      }

      // GeTui CID 监听同样推迟到首帧后挂载，避免 push service 构造与 stream
      // 订阅落在启动期同步阶段。
      try {
        _cidSubscription = ref
            .read(pushNotificationServiceProvider)
            .clientIdStream
            .listen((cid) async {
              if (cid.isEmpty) return;
              final token = ref.read(appStorageProvider).token;
              if (token.isEmpty) return;
              final authRepo = ref.read(authRepositoryProvider);
              try {
                await authRepo.reportCid(cid);
              } catch (_) {
                // 接口失败不影响业务。
              }
            });
      } catch (e, st) {
        debugPrint('clientIdStream listen failed: $e\n$st');
      }
    });
  }

  @override
  void dispose() {
    unawaited(_cidSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(appStorageProvider);
    final initialRoute = storage.token.isEmpty
        ? RoutePaths.login
        : RoutePaths.home;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: '音乐之路',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // 本地化：强制 zh-CN，并注入 Material / Cupertino / Widgets 三套
      // LocalizationsDelegates。修复 iPadOS 输入框长按 / Live Text 弹出的
      // 系统编辑菜单（Scan Text、Copy、Paste 等）显示英文的问题。
      // supportedLocales 列了 zh-CN 和 en-US 两条：前者命中后所有 Cupertino
      // 文案走中文；保留 en 是为了在系统语言为英文且用户清掉本地缓存时
      // 仍有兜底，不至于回退到 ARB 缺失的 Locale 报错。
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      // 全局文本行为：
      // 1. 锁定 textScaler = 1.0：禁用 iOS/Android 系统的 "Display & Text Size"
      //    缩放，保证 Web 与平板上同一个 fontSize 渲染出相同的逻辑像素，
      //    避免 iPad 上文字"莫名偏小"。
      // 2. DefaultTextHeightBehavior：让首/末行不再应用 height leading，
      //    与 CSS/Figma 行为一致，解决全局"文字偏下、上下间距偏宽"。
      // 3. [GlobalKeyboardFocusSentinel]：监听 FocusManager，焦点离开
      //    EditableText 时再发一次 `TextInput.hide` + Web 端 blur，治掉
      //    iPadOS 浮动小键盘"输入框失焦后还赖在屏幕上"的顽固 bug。
      // 4. 根级 [_TapOutsideToDismissKeyboard]：点击非可交互空白区域自动
      //    收起软键盘，解决 iPad/iOS 上多行 TextField（Return 键变换行）
      //    + 没有"收起键盘"按钮时无法关闭键盘的问题。
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: DefaultTextHeightBehavior(
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            child: FirstLaunchPermissionHost(
              child: GlobalKeyboardFocusSentinel(
                child: _TapOutsideToDismissKeyboard(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
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
        // 双保险：iPadOS 浮动小键盘有时不响应 unfocus 触发的 IME hide，
        // 这里再显式调一次平台原生 / 浏览器层的收键盘逻辑。
        dismissPlatformKeyboard();
      },
      child: child,
    );
  }
}

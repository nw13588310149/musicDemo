/// 全应用截屏 / 录屏防护（iOS / Android）。
///
/// Web / 桌面走 stub no-op；移动端在 [MyApp] 首帧渲染后调用 [enableAppScreenGuard]。
library;

export 'app_screen_guard_stub.dart'
    if (dart.library.io) 'app_screen_guard_io.dart';

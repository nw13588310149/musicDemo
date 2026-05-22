import 'package:flutter/foundation.dart';

/// 移动端截屏防护由原生层负责，Dart 侧保持 no-op：
/// - iOS：`ScreenCaptureGuard` 在首帧后启用 secure layer + 录屏遮罩
/// - Android：`MainActivity` 设置 `FLAG_SECURE`
Future<void> enableAppScreenGuard() async {
  if (kDebugMode) {
    debugPrint('enableAppScreenGuard: handled natively on iOS/Android');
  }
}

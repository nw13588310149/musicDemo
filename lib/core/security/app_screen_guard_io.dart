import 'package:flutter/foundation.dart';

/// 移动端截屏防护由原生层负责，Dart 侧保持 no-op：
/// - iOS：ScreenProtectorKit（与 screen_protector 同源，view 就绪后 native 启用）
/// - Android：`MainActivity` 设置 `FLAG_SECURE`
Future<void> enableAppScreenGuard() async {
  if (kDebugMode) {
    debugPrint('enableAppScreenGuard: handled natively on iOS/Android');
  }
}

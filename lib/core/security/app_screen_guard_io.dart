import 'package:flutter/foundation.dart';

/// 移动端截屏防护由原生层负责，Dart 侧保持 no-op：
/// - iOS：`SceneDelegate` 切后台时黑色遮罩（多任务预览防泄漏）
/// - Android：`MainActivity` 设置 `FLAG_SECURE`（截屏/录屏/多任务预览）
Future<void> enableAppScreenGuard() async {
  if (kDebugMode) {
    debugPrint('enableAppScreenGuard: handled natively on iOS/Android');
  }
}

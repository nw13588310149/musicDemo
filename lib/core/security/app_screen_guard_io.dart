import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// 启用全应用截屏防护，对齐 1.0 移动端安全策略：
/// - Android：`protectDataLeakageOn` + `preventScreenshotOn`
/// - iOS：`preventScreenshotOn` + `protectDataLeakageWithColor`（切后台 / 多任务预览遮罩）
Future<void> enableAppScreenGuard() async {
  if (kIsWeb) {
    return;
  }
  try {
    if (Platform.isAndroid) {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
      return;
    }
    if (Platform.isIOS) {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageWithColor(Colors.black);
    }
  } catch (error, stack) {
    debugPrint('enableAppScreenGuard failed: $error\n$stack');
  }
}

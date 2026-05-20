import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/network/media_url.dart';
import 'core/providers/app_providers.dart';
import 'core/storage/app_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20;
  try {
    MediaKit.ensureInitialized();
  } catch (error, stack) {
    debugPrint('MediaKit.ensureInitialized failed: $error\n$stack');
  }
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 与 iOS Info.plist / Android sensorLandscape 一致；请勿在其他页面恢复 portrait。
  // 沉浸式：隐藏系统状态栏和导航栏。
  // - Android：immersiveSticky 模式下用户从屏幕边缘下拉时系统栏会临时显示，几秒后自动隐藏。
  // - iOS：状态栏由 Info.plist + RootFlutterViewController 控制；这里调用是无副作用的兜底。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final storage = await AppStorage.create();
  final cid = Uri.base.queryParameters['cid'];
  if (cid != null && cid.isNotEmpty) {
    await storage.savePushId(cid);
  }
  // 启动时立即把上次缓存的「文件服务器域名」注入 MediaUrl，让首屏就能正常
  // 解析图片/音频路径，登录后再通过 configList 异步刷新。
  final cachedFileBase = storage.fileBaseUrl;
  if (cachedFileBase.isNotEmpty) {
    MediaUrl.setFileBaseUrl(cachedFileBase);
  }

  // 根容器注入 [appStorageProvider]；推送 / 音频预热在 [MyApp] 首帧后执行。
  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(storage)],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}

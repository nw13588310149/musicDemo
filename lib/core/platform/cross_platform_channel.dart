import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 跨平台原生通道的统一入口（预留鸿蒙 HarmonyOS NEXT 等扩展）。
///
/// 设计原则：
/// 1. **单一通道名**：Android / iOS / 未来鸿蒙侧使用同一 `MethodChannel` 名称注册，
///    避免 Dart 层出现平台分支爆炸；各平台在原生层实现相同方法表即可。
/// 2. **类型安全**：对外暴露异步方法，内部将异常转为 [PlatformException] 或业务错误。
/// 3. **可测试**：通过注入 [MethodChannel] 可在单元测试中 Mock（测试时可选）。
///
/// 鸿蒙接入提示：在 OpenHarmony / HarmonyOS NEXT 的 Flutter 插件工程中，
/// 使用与 Android 类似的 `BinaryMessenger` 注册同名 channel，并实现下列 [NativeMethod]。
class CrossPlatformChannel {
  CrossPlatformChannel._();

  /// 与所有宿主约定好的通道名（请与 Android MainActivity、iOS AppDelegate、未来鸿蒙插件保持一致）。
  static const String kChannelName = 'com.music_exam.perf_demo/native';

  static const MethodChannel _channel = MethodChannel(kChannelName);

  /// 当前使用的通道实例（便于测试替换）。
  static MethodChannel get channel => _channel;

  // —— 方法名常量：原生侧需实现同名调用 —— //

  /// 示例：获取宿主平台标识（android / ios / ohos 等），用于遥测或特性开关。
  static const String kGetHostPlatform = 'getHostPlatform';

  /// 示例：由原生告知是否支持某能力（如低延迟音频路由、大页内存等）。
  static const String kGetCapability = 'getCapability';

  /// 调用原生无参方法并返回 Map（失败时抛出 [PlatformException]）。
  static Future<Map<String, dynamic>?> invokeMap(String method,
      [dynamic arguments]) async {
    final Object? result = await _channel.invokeMethod<Object?>(method, arguments);
    if (result == null) return null;
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw PlatformException(
      code: 'INVALID_RESULT',
      message: '方法 $method 返回值不是 Map，实际类型: ${result.runtimeType}',
    );
  }

  /// 获取宿主平台字符串；若原生尚未实现，返回 [defaultTargetPlatform] 的近似描述（不抛错）。
  static Future<String> getHostPlatformLabel() async {
    try {
      final String? v =
          await _channel.invokeMethod<String>(kGetHostPlatform);
      if (v != null && v.isNotEmpty) return v;
    } on PlatformException catch (e, st) {
      debugPrint('CrossPlatformChannel.getHostPlatformLabel: $e\n$st');
    } on MissingPluginException catch (e, st) {
      // 插件未注册或桌面/Web 等无实现时常见
      debugPrint('CrossPlatformChannel: MissingPlugin $e\n$st');
    }
    return defaultTargetPlatform.name;
  }

  /// 查询某项能力是否可用；原生未实现时返回 `null` 表示「未知」。
  static Future<bool?> getCapability(String key) async {
    try {
      final bool? v = await _channel.invokeMethod<bool>(
        kGetCapability,
        <String, dynamic>{'key': key},
      );
      return v;
    } on PlatformException catch (e, st) {
      debugPrint('CrossPlatformChannel.getCapability: $e\n$st');
      return null;
    } on MissingPluginException catch (e, st) {
      debugPrint('CrossPlatformChannel.getCapability MissingPlugin: $e\n$st');
      return null;
    }
  }
}

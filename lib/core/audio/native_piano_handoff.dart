import 'dart:async';

import 'package:flutter/foundation.dart';

/// iOS 全应用共用的原生钢琴 MethodChannel 操作串行合并。
///
/// 避免视唱离开、音乐伴侣进入、听写 reclaim 等在原生队列里叠两次，
/// 导致迟播或无声。
///
/// 关键安全约束：**任何一次 handoff 都必须在有限时间内结束**。
/// 早期实现没有超时——一旦某次原生 reclaim / prepare 的 MethodChannel
/// 永远不返回，`_task` 会被永久占用，之后所有等待 handoff 的页面
/// （musicPlay 详情、听写 bootstrap 等）会一起转圈卡死。这里用
/// [_kTimeout] 兜底：超时即放行并清空 `_task`，让后续调用能重新发起。
abstract final class NativePianoHandoff {
  static Future<void>? _task;

  /// 单次 handoff 的最长等待。内部的 AVAudioSession 配置已各带 4s 超时，
  /// 这里取一个比「会话切换最坏串行耗时」更大的上限，既不误伤正常慢启动，
  /// 又能在原生通道真正卡死时把整条链路解开。
  static const Duration _kTimeout = Duration(seconds: 15);

  static Future<void> run(Future<void> Function() action) async {
    if (kIsWeb) {
      await action();
      return;
    }
    final pending = _task;
    if (pending != null) {
      // 复用进行中的 handoff；它已被 [_guarded] 限时，不会无限等待。
      await pending;
      return;
    }
    final task = _guarded(action);
    _task = task;
    try {
      await task;
    } finally {
      if (identical(_task, task)) {
        _task = null;
      }
    }
  }

  /// 包裹 action：吞掉异常并强制超时，保证返回的 Future 一定会在
  /// [_kTimeout] 内完成，从而 `_task` 总能被及时清空。
  static Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action().timeout(_kTimeout);
    } catch (error, stack) {
      debugPrint('NativePianoHandoff action failed/timed out: $error\n$stack');
    }
  }
}

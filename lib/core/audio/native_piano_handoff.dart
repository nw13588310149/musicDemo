import 'dart:async';

import 'package:flutter/foundation.dart';

/// iOS 全应用共用的原生钢琴 MethodChannel 操作串行合并。
///
/// 避免视唱离开、音乐伴侣进入、听写 reclaim 等在原生队列里叠两次，
/// 导致迟播或无声。
abstract final class NativePianoHandoff {
  static Future<void>? _task;

  static Future<void> run(Future<void> Function() action) async {
    if (kIsWeb) {
      await action();
      return;
    }
    if (_task != null) {
      await _task;
      return;
    }
    final task = action();
    _task = task;
    try {
      await task;
    } finally {
      if (identical(_task, task)) {
        _task = null;
      }
    }
  }
}

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// 全应用唯一的 AVAudioSession / Android 音频会话协调器（业界专业方案重构版）。
///
/// 设计原则（解决 iPad 上「钢琴无声 / 迟播」「长音频杂音」的根因）：
/// 1. **单一会话，配置 + 激活只发生一次，导航期间绝不 `setActive(false)`。**
///    旧实现每次进页都 `setActive(false) → configure → setActive(true)`，
///    这会把常驻 `AVAudioEngine`（钢琴）的 IO 静默掐断、`isRunning` 陈旧为
///    true，表现为「假运行、实际无声」或要等数秒重建才出声。
/// 2. 默认类别 `playback`（与 media_kit 长音频、SoLoud 解码、节拍器一致）。
///    录音 / 调音器 / 视唱采集时**就地升级**为 `playAndRecord`（在活动会话上
///    切类别，不 deactivate），离开时再降回 `playback`。
/// 3. 类别 / 模式切换会让 iOS 给 `AVAudioEngine` 发 `ConfigurationChange`
///    通知，原生侧据此**重启**（不重建图）。这里只负责会话，不碰引擎。
///
/// 所有 platform channel 调用都带超时兜底：iOS 偶发不返回，绝不让整条
/// 音频初始化链 hang 死。
abstract final class NativePlaybackAudioSession {
  /// iOS 共享钢琴原生图：类别 / 模式切换后置位，提示原生侧在下次按键前
  /// 确认引擎已重启（与原生 `ConfigurationChange` 观察者互为兜底）。
  static bool nativePianoGraphNeedsReclaim = false;

  static void markNativePianoGraphStale() {
    if (kIsWeb) return;
    nativePianoGraphNeedsReclaim = true;
  }

  static void markNativePianoGraphFresh() {
    nativePianoGraphNeedsReclaim = false;
  }

  /// 单次 platform channel 操作的最长等待，避免 iOS 不响应时永久阻塞。
  static const Duration _kChannelTimeout = Duration(seconds: 4);

  static _SessionProfile _current = _SessionProfile.none;
  static bool _activated = false;

  /// in-flight 串行：同一时刻只允许一个会话配置在跑，避免并发 configure 互相打架。
  static Future<void>? _inflight;

  // ── 对外 API（保持与旧版一致，便于上层不改动）─────────────────────

  /// 钢琴 / 节拍器 / SoLoud 解码：默认播放会话。
  static Future<void> ensurePlaybackActive() => _ensure(_SessionProfile.playback);

  /// media_kit 长音频：与钢琴共用同一个 `playback` 会话。
  ///
  /// [releaseOthersFirst] 保留以兼容旧调用，但**不再** `setActive(false)`——
  /// 单一会话模型下不存在「先让出再抢回」，那正是掐断常驻引擎的根源。
  static Future<void> ensureMediaKitPlaybackActive({
    bool releaseOthersFirst = true,
  }) => _ensure(_SessionProfile.playback);

  /// 录音系统 / 视唱实时采集：playAndRecord + 默认模式。
  static Future<void> ensureRecordActive() =>
      _ensure(_SessionProfile.record);

  /// 调音器：playAndRecord + measurement（低延迟音高检测）。
  static Future<void> ensurePlayAndRecordActive() =>
      _ensure(_SessionProfile.measurement);

  /// 智能视唱采音：measurement + mixWithOthers（与钢琴伴奏并行，不用 AEC）。
  static Future<void> ensureSightSingingCaptureActive() =>
      _ensure(_SessionProfile.measurement);

  /// 与上面相同：单一会话模型下不再区分 soft / hard（都不 deactivate）。
  static Future<void> ensureSightSingingCaptureActiveSoft() =>
      _ensure(_SessionProfile.measurement);

  /// 让缓存失效，下一次 ensure 会重新 configure（不 deactivate）。
  /// 用于错误重试 / 应用恢复前强制重做一次 session 自检。
  static void invalidatePlaybackCache() {
    _current = _SessionProfile.none;
  }

  // ── 内部实现 ──────────────────────────────────────────────────────

  static Future<void> _ensure(_SessionProfile profile) {
    if (kIsWeb) return Future<void>.value();
    // 已处于目标 profile 且已激活：直接复用，零 platform 往返。
    if (_current == profile && _activated) {
      return Future<void>.value();
    }
    final previous = _inflight;
    Future<void> run() => _applyBestEffort(profile);
    final task = previous != null
        ? previous.then((_) => run()).catchError((_) => run())
        : run();
    _inflight = task.whenComplete(() {
      if (identical(_inflight, task)) {
        _inflight = null;
      }
    });
    return task;
  }

  static Future<void> _applyBestEffort(_SessionProfile profile) async {
    // 已被前一个排队任务切到目标 profile：跳过。
    if (_current == profile && _activated) return;
    try {
      await _apply(profile);
    } catch (error, stack) {
      // 配置失败不抛：原生引擎仍可尝试在已有会话上渲染；最坏情况只是这次
      // 没切成，下次 ensure 会再试。iPad 上唯一更糟的就是整段 await 卡死，
      // 所以这里只记日志。
      debugPrint(
        'NativePlaybackAudioSession apply($profile) failed: $error\n$stack',
      );
    }
  }

  static Future<void> _apply(_SessionProfile profile) async {
    final session = await AudioSession.instance.timeout(
      _kChannelTimeout,
      onTimeout: () => throw TimeoutException(
        'AudioSession.instance hung > ${_kChannelTimeout.inSeconds}s',
      ),
    );

    // 在**活动**会话上切类别 / 模式：configure 不会 deactivate；绝不调
    // setActive(false)。这是「不杀引擎」的关键。
    await session
        .configure(_configFor(profile))
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.configure($profile) hung > '
            '${_kChannelTimeout.inSeconds}s',
          ),
        );

    // 激活会话。**只** setActive(true)，永不 setActive(false)：在已活动的会话上
    // 重新 setActive(true) 是安全幂等的，且能确保刚 configure 的新类别在 iPad 上
    // 真正生效（旧实现靠 setActive(false) 强制生效，正是掐断常驻引擎的根因）。
    await session
        .setActive(true)
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.setActive(true) hung > '
            '${_kChannelTimeout.inSeconds}s',
          ),
        );
    _activated = true;

    final categoryChanged = _categoryDiffers(_current, profile);
    _current = profile;
    // 类别 / 模式变化会触发 AVAudioEngine ConfigurationChange；提示钢琴图
    // 在下次按键前确认已重启（原生观察者通常已自动重启，这里只是兜底）。
    if (categoryChanged) {
      markNativePianoGraphStale();
    }
  }

  static bool _categoryDiffers(_SessionProfile a, _SessionProfile b) {
    bool isRecordLike(_SessionProfile p) =>
        p == _SessionProfile.record || p == _SessionProfile.measurement;
    return isRecordLike(a) != isRecordLike(b);
  }

  static AudioSessionConfiguration _configFor(_SessionProfile profile) {
    switch (profile) {
      case _SessionProfile.playback:
      case _SessionProfile.none:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
      case _SessionProfile.record:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
      case _SessionProfile.measurement:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.measurement,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
    }
  }
}

enum _SessionProfile {
  none,
  playback,
  record,
  measurement,
}

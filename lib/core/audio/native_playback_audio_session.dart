import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// iOS / Android 短音频（SoLoud 钢琴、节拍器）共用的播放会话配置。
///
/// 关键点（iPad 上吃过的亏）：
/// 1. `media_kit` 长音频、`record` 录音、人脸相机都会把 AVAudioSession 切到
///    `playAndRecord` / `record` / `soloAmbient`，SoLoud 底层 miniaudio 一旦
///    在这个时点 init() 就会拿不到 CoreAudio 输出 → 页面卡在「加载中」。
/// 2. `audio_session.configure()` / `setActive()` 是 platform channel 调用，
///    iOS 偶发整体不返回，不加 timeout 整个 engine init 会跟着 hang 死。
/// 3. 切回 playback 前必须先 `setActive(false)`，把上一个 owner（mpv / 录音器）
///    显式让出来，否则 setActive(true) 在 iPad 上有时不会真正生效。
abstract final class NativePlaybackAudioSession {
  static Future<void>? _playbackTask;

  /// 单次 platform channel 操作的最长等待时间，避免 iOS 不响应时永久阻塞。
  static const Duration _kChannelTimeout = Duration(seconds: 4);

  /// 钢琴 / 节拍器：纯播放，允许与其它模块混音。
  ///
  /// 多个调用方在 in-flight 期间复用同一个 Future，结束后清空缓存——
  /// 下次任意模块再次需要 playback 时仍能重新走完 release → configure
  /// → setActive 的完整序列。
  static Future<void> ensurePlaybackActive() {
    if (kIsWeb) return Future<void>.value();
    return _playbackTask ??= _configurePlaybackBestEffort().whenComplete(() {
      _playbackTask = null;
    });
  }

  static Future<void> _configurePlaybackBestEffort() async {
    try {
      await _configurePlayback();
    } catch (error, stack) {
      // Session 配置失败时不抛——SoLoud / WebAudio 仍然可以尝试初始化。
      // iPad 上唯一比这更糟糕的情况就是整段 await 卡死，所以这里只记日志。
      debugPrint(
        'NativePlaybackAudioSession playback setup failed: $error\n$stack',
      );
    }
  }

  static Future<void> _configurePlayback() async {
    final session = await AudioSession.instance.timeout(
      _kChannelTimeout,
      onTimeout: () => throw TimeoutException(
        'AudioSession.instance hung > ${_kChannelTimeout.inSeconds}s',
      ),
    );

    // Step 1：先让出当前会话所有权。media_kit / 录音器活跃时直接 configure
    // 经常会被静默忽略；先 setActive(false) 是 iPad 上必须的步骤。
    try {
      await session
          .setActive(false)
          .timeout(_kChannelTimeout, onTimeout: () => false);
    } catch (error, stack) {
      // 没人持有会话时 setActive(false) 会直接抛——这里属于预期路径，
      // 仅在 debug 日志里记一笔以便排查 iPad 的 session 流向。
      debugPrint(
        'NativePlaybackAudioSession.setActive(false) ignored: $error\n$stack',
      );
    }

    // Step 2：把 category 切到 playback + mixWithOthers，
    // 与 SoLoud miniaudio / WebAudio 的输出语义一致。
    await session
        .configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.mixWithOthers,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.media,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          ),
        )
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.configure hung > ${_kChannelTimeout.inSeconds}s',
          ),
        );

    // Step 3：claim 新的 playback 所有权。
    await session
        .setActive(true)
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.setActive(true) hung > ${_kChannelTimeout.inSeconds}s',
          ),
        );
  }

  /// 录音系统 / 视唱实时采集：麦克风录入，不用 measurement（调音器专用）。
  ///
  /// iOS 上若沿用调音器的 `measurement` 或纯 `playback`，`record` 录到的
  /// AAC 电平会明显偏低。
  static Future<void> ensureRecordActive() {
    return _ensurePlayAndRecordMode(AVAudioSessionMode.defaultMode);
  }

  /// 调音器：需要麦克风输入，measurement 利于低延迟音高检测。
  static Future<void> ensurePlayAndRecordActive() {
    return _ensurePlayAndRecordMode(AVAudioSessionMode.measurement);
  }

  static Future<void> _ensurePlayAndRecordMode(
    AVAudioSessionMode avAudioSessionMode,
  ) async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance.timeout(_kChannelTimeout);
      try {
        await session
            .setActive(false)
            .timeout(_kChannelTimeout, onTimeout: () => false);
      } catch (_) {}
      await session
          .configure(
            AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.defaultToSpeaker |
                  AVAudioSessionCategoryOptions.allowBluetooth,
              avAudioSessionMode: avAudioSessionMode,
              androidAudioAttributes: const AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                usage: AndroidAudioUsage.voiceCommunication,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
            ),
          )
          .timeout(_kChannelTimeout);
      await session.setActive(true).timeout(_kChannelTimeout);
    } catch (error, stack) {
      debugPrint(
        'NativePlaybackAudioSession._ensurePlayAndRecordMode($avAudioSessionMode) '
        'failed: $error\n$stack',
      );
    } finally {
      // 切到 playAndRecord 后，下次切回 playback 必须走完整的 release →
      // configure → claim 序列，不能复用旧的"已配置 playback"的缓存。
      _playbackTask = null;
    }
  }

  static void invalidatePlaybackCache() {
    _playbackTask = null;
  }
}

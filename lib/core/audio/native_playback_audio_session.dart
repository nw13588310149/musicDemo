import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// iOS / Android 短音频（SoLoud 钢琴、节拍器）共用的播放会话配置。
///
/// media_kit 长音频、调音器麦克风会切换 AVAudioSession；进入音乐伴侣前
/// 必须显式切回 playback 并 activate，否则 SoLoud.play 会静默失败。
abstract final class NativePlaybackAudioSession {
  static Future<void>? _playbackTask;

  /// 钢琴 / 节拍器：纯播放，允许与其它模块混音。
  static Future<void> ensurePlaybackActive() {
    if (kIsWeb) return Future<void>.value();
    // AVAudioSession can be changed later by media_kit, recorder, or the
    // tuner. Cache only concurrent calls, not the completed state, otherwise
    // short sounds may become silent after another module switches category.
    return _playbackTask ??= _configurePlaybackBestEffort().whenComplete(() {
      _playbackTask = null;
    });
  }

  static Future<void> _configurePlaybackBestEffort() async {
    try {
      await _configurePlayback();
    } catch (error, stack) {
      // Playback session setup is helpful after media/recording modules switch
      // categories, but it must not block SoLoud initialization. The last known
      // stable iPad path initialized SoLoud without audio_session at all.
      debugPrint('NativePlaybackAudioSession playback setup failed: $error\n$stack');
    }
  }

  static Future<void> _configurePlayback() async {
    final session = await AudioSession.instance;
    await session.configure(
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
    );
    await session.setActive(true);
  }

  /// 调音器：需要麦克风输入。
  static Future<void> ensurePlayAndRecordActive() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
    await session.setActive(true);
    _playbackTask = null;
  }

  static void invalidatePlaybackCache() {
    _playbackTask = null;
  }
}

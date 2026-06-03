import 'low_latency_note_player_stub.dart'
    if (dart.library.io) 'low_latency_note_player_io.dart';

/// 低延迟短音频播放器。
///
/// 用途：钢琴键、节拍器、智能听写题目音这类「短、小、频繁触发」的声音。
/// 不用于长音频播放，长音频仍走 media_kit / just_audio。
abstract interface class LowLatencyNotePlayer {
  bool get isReady;

  bool get supportsImmediatePlay;

  Future<void> prepare(Map<String, String> assetByKey);

  bool hasPrepared(String key);

  bool tryPlay(String key, {double volume = 1, bool metronome = false});

  Future<void> play(
    String key, {
    double volume = 1,
    bool metronome = false,
    bool waitUntilFinished = false,
  });

  /// iOS：AVAudioSession 切换后重建 AVAudioEngine，避免 play() 闪退。
  Future<void> reclaimEngine();

  /// 仅淡出节拍器发声，不截断钢琴延音（iOS 原生池）。
  Future<void> stopMetronomePlaybacks();

  Future<void> stopAll();

  Future<void> dispose();
}

LowLatencyNotePlayer createLowLatencyNotePlayer() {
  return createPlatformLowLatencyNotePlayer();
}

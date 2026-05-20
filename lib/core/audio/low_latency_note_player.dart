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

  bool tryPlay(String key, {double volume = 1});

  Future<void> play(String key, {double volume = 1});

  Future<void> stopAll();

  Future<void> dispose();
}

LowLatencyNotePlayer createLowLatencyNotePlayer() {
  return createPlatformLowLatencyNotePlayer();
}

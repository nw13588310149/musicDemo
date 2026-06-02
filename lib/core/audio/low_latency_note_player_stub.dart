import 'low_latency_note_player.dart';

LowLatencyNotePlayer createPlatformLowLatencyNotePlayer() {
  return _StubLowLatencyNotePlayer();
}

class _StubLowLatencyNotePlayer implements LowLatencyNotePlayer {
  final Set<String> _keys = <String>{};
  bool _disposed = false;

  @override
  bool get isReady => !_disposed;

  @override
  bool get supportsImmediatePlay => false;

  @override
  Future<void> prepare(Map<String, String> assetByKey) async {
    if (_disposed) return;
    _keys.addAll(assetByKey.keys);
  }

  @override
  bool hasPrepared(String key) => _keys.contains(key);

  @override
  bool tryPlay(String key, {double volume = 1, bool metronome = false}) =>
      false;

  @override
  Future<void> play(String key, {double volume = 1, bool metronome = false}) async {}

  @override
  Future<void> reclaimEngine() async {}

  @override
  Future<void> stopMetronomePlaybacks() async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    _keys.clear();
  }
}

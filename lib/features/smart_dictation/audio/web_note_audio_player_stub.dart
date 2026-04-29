import 'dart:async';

import 'web_note_audio_player_base.dart';

WebNoteAudioPlayer createWebNoteAudioPlayer() => _StubWebNoteAudioPlayer();

class _StubWebNoteAudioPlayer implements WebNoteAudioPlayer {
  @override
  bool get isReady => true;

  @override
  Future<void> prepare(Iterable<String> assets) async {}

  @override
  Future<void> activateByUserGesture() async {}

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

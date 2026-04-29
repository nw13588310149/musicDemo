// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'web_note_audio_player_base.dart';

WebNoteAudioPlayer createWebNoteAudioPlayer() => _WebNoteAudioPlayer();

class _WebNoteAudioPlayer implements WebNoteAudioPlayer {
  bool _ready = false;
  final List<html.AudioElement> _active = <html.AudioElement>[];

  @override
  bool get isReady => _ready;

  @override
  Future<void> prepare(Iterable<String> assets) async {
    _ready = true;
  }

  @override
  Future<void> activateByUserGesture() async {
    // Must be called from a user gesture; this primes browser audio pipeline.
    final probe = html.AudioElement()
      ..src = 'assets/audio/smart_dictation/piano/a80.wav'
      ..preload = 'auto'
      ..volume = 0.0001;
    try {
      await probe.play();
      probe.pause();
    } catch (_) {
      rethrow;
    } finally {
      probe.removeAttribute('src');
      probe.load();
    }
  }

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {
    final audio = html.AudioElement()
      ..src = asset
      ..preload = 'auto'
      ..volume = volume.clamp(0.0, 1.0).toDouble();
    _active.add(audio);
    audio.onEnded.first.then((_) => _active.remove(audio));
    try {
      await audio.play();
    } catch (_) {
      _active.remove(audio);
      rethrow;
    }
  }

  @override
  Future<void> stopAll() async {
    for (final audio in List<html.AudioElement>.from(_active)) {
      audio.pause();
      audio.currentTime = 0;
    }
    _active.clear();
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _ready = false;
  }
}

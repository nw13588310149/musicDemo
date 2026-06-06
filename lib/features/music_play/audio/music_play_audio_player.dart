import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:media_kit/media_kit.dart' as mk;

import '../../../core/audio/app_audio_service.dart';

class MusicPlayAudioPlayerState {
  const MusicPlayAudioPlayerState({
    required this.playing,
    required this.volume,
  });

  final bool playing;
  final double volume;
}

class MusicPlayAudioPlayerStreams {
  const MusicPlayAudioPlayerStreams({
    required this.position,
    required this.duration,
    required this.playing,
    required this.completed,
  });

  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<bool> playing;
  final Stream<bool> completed;
}

/// MusicPlay backend adapter.
///
/// Normal iOS playback uses AVPlayer through just_audio, avoiding mpv session
/// and seek churn. When pitch shifting is explicitly enabled, media_kit remains
/// available because AVPlayer does not provide independent pitch shifting.
class MusicPlayAudioPlayer {
  MusicPlayAudioPlayer({required bool enablePitch})
    : _usesNativeIosPlayback =
          !kIsWeb && Platform.isIOS && !enablePitch {
    if (_usesNativeIosPlayback) {
      final player = ja.AudioPlayer();
      _justAudio = player;
      _position = player.positionStream;
      _duration = player.durationStream
          .where((value) => value != null)
          .cast<Duration>();
      _playing = player.playerStateStream.map(
        (value) =>
            value.playing &&
            value.processingState != ja.ProcessingState.completed,
      );
      _completed = player.playerStateStream.map(
        (value) => value.processingState == ja.ProcessingState.completed,
      );
      return;
    }

    final player = mk.Player(
      configuration: mk.PlayerConfiguration(pitch: enablePitch),
    );
    _mediaKit = player;
    _position = player.stream.position;
    _duration = player.stream.duration;
    _playing = player.stream.playing;
    _completed = player.stream.completed;
  }

  final bool _usesNativeIosPlayback;
  ja.AudioPlayer? _justAudio;
  mk.Player? _mediaKit;
  late final Stream<Duration> _position;
  late final Stream<Duration> _duration;
  late final Stream<bool> _playing;
  late final Stream<bool> _completed;
  double _volume = 100;

  bool get usesNativeIosPlayback => _usesNativeIosPlayback;

  MusicPlayAudioPlayerState get state => MusicPlayAudioPlayerState(
    playing: _usesNativeIosPlayback
        ? (_justAudio?.playing ?? false)
        : (_mediaKit?.state.playing ?? false),
    volume: _volume,
  );

  MusicPlayAudioPlayerStreams get stream => MusicPlayAudioPlayerStreams(
    position: _position,
    duration: _duration,
    playing: _playing,
    completed: _completed,
  );

  Future<void> open(String url, {required bool play}) async {
    if (_usesNativeIosPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      final player = _justAudio!;
      await player.setUrl(url);
      if (play) unawaited(player.play());
      return;
    }
    await _mediaKit!.open(mk.Media(url), play: play);
  }

  Future<void> play() async {
    if (_usesNativeIosPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      unawaited(_justAudio!.play());
      return;
    }
    await _mediaKit!.play();
  }

  Future<void> pause() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.pause();
      return;
    }
    await _mediaKit!.pause();
  }

  Future<void> stop() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.stop();
      return;
    }
    await _mediaKit!.stop();
  }

  Future<void> seek(Duration position) async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.seek(position);
      return;
    }
    await _mediaKit!.seek(position);
  }

  Future<void> setRate(double rate) async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.setSpeed(rate);
      return;
    }
    await _mediaKit!.setRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    if (_usesNativeIosPlayback) return;
    await _mediaKit!.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 100);
    if (_usesNativeIosPlayback) {
      await _justAudio!.setVolume(_volume / 100);
      return;
    }
    await _mediaKit!.setVolume(_volume);
  }

  Future<void> dispose() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.dispose();
      _justAudio = null;
      return;
    }
    await _mediaKit!.dispose();
    _mediaKit = null;
  }
}

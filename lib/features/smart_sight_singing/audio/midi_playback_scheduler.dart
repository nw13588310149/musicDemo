import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../music_companion/audio/music_companion_audio_catalog.dart';
import '../../music_companion/audio/music_companion_audio_engine.dart';
import 'midi_sight_singing_service.dart';

/// 基于现有钢琴短音资源，按 MIDI 事件时间轴播放。
class MidiPlaybackScheduler {
  MidiPlaybackScheduler({MusicCompanionAudioEngine? audioEngine})
      : _audio = audioEngine ?? MusicCompanionAudioEngine();

  final MusicCompanionAudioEngine _audio;
  final StreamController<int> _positionController =
      StreamController<int>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  List<MidiPlaybackEvent> _events = const [];
  int _totalMs = 0;
  Stopwatch? _stopwatch;
  Timer? _timer;
  var _eventIndex = 0;
  var _lastMs = -1;
  var _running = false;

  /// 为 true 时只推进时间轴，不触发钢琴短音（iPad 无声跟唱）。
  bool muteAudioOutput = false;

  /// 当前时刻正在播放的 MIDI 音高（供串音过滤）；无声模式下恒为 null。
  int? _activePlaybackPitch;
  int? get activePlaybackPitch => muteAudioOutput ? null : _activePlaybackPitch;

  Stream<int> get positionMs => _positionController.stream;
  Stream<void> get completed => _completedController.stream;

  int get totalMs => _totalMs;

  Future<void> prepare(List<MidiPlaybackEvent> events, {required int totalMs}) async {
    await stop();
    _events = List<MidiPlaybackEvent>.from(events)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _totalMs = totalMs;
    _eventIndex = 0;
    _lastMs = -1;
    _activePlaybackPitch = null;
  }

  /// 倒计时阶段预加载钢琴采样，避免跟唱开始时 native 会话与录音争抢。
  Future<void> warmupAudioEngine() async {
    if (muteAudioOutput) return;
    await _audio.ensurePianoInitialized();
  }

  Future<void> start({bool? muteAudio}) async {
    if (muteAudio != null) {
      muteAudioOutput = muteAudio;
    }
    if (_running || _events.isEmpty) return;
    if (!muteAudioOutput && !_audio.isPianoReady) {
      await _audio.ensurePianoInitialized();
    }
    _running = true;
    _eventIndex = 0;
    _lastMs = -1;
    _activePlaybackPitch = null;
    _stopwatch = Stopwatch()..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _activePlaybackPitch = null;
    await _audio.stopAll();
  }

  Future<void> pause() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    await _audio.stopAll();
  }

  void _onTick(Timer timer) {
    if (!_running || _stopwatch == null) return;
    final ms = _stopwatch!.elapsedMilliseconds;
    if (ms == _lastMs) return;
    _lastMs = ms;

    while (_eventIndex < _events.length && _events[_eventIndex].timeMs <= ms) {
      final event = _events[_eventIndex];
      _eventIndex += 1;
      unawaited(_playEvent(event));
    }

    if (!_positionController.isClosed) {
      _positionController.add(ms);
    }

    if (ms >= _totalMs && _eventIndex >= _events.length) {
      unawaited(_finish());
    }
  }

  Future<void> _playEvent(MidiPlaybackEvent event) async {
    if (muteAudioOutput) return;
    _activePlaybackPitch = event.pitch;
    final token = _pitchToToken(event.pitch);
    if (token == null) return;
    final volume = (event.velocity / 127.0).clamp(0.0, 1.0);
    try {
      await _audio.playNote(token, volume: volume);
    } catch (error, stack) {
      debugPrint('MidiPlaybackScheduler.playNote($token) failed: $error\n$stack');
    }
  }

  Future<void> _finish() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    if (!_completedController.isClosed) {
      _completedController.add(null);
    }
  }

  static String? _pitchToToken(int pitch) {
    if (pitch < 0 || pitch > 127) return null;
    const names = <String>[
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final octave = (pitch ~/ 12) - 1;
    final name = names[pitch % 12];
    final token = '$name$octave';
    return kMusicCompanionPianoAssetByNote.containsKey(token) ? token : null;
  }

  Future<void> dispose() async {
    await stop();
    await _positionController.close();
    await _completedController.close();
    await _audio.dispose();
  }
}

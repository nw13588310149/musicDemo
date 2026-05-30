import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../music_companion/audio/music_companion_audio_catalog.dart';
import '../../music_companion/audio/music_companion_audio_engine.dart';
import '../config/smart_sight_singing_config.dart';
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
  int _leadInDurationMs = 0;
  Stopwatch? _stopwatch;
  Timer? _timer;
  var _eventIndex = 0;
  var _lastMs = -1;
  var _running = false;
  var _finishing = false;
  Future<void>? _audioChain;

  /// 为 true 时不播放旋律伴奏；若 [prepare] 传入 [leadInDurationMs] > 0，
  /// 预备段内的标准音与节拍器仍会出声（考试模式）。
  bool muteAudioOutput = false;

  /// 当前时刻正在播放的 MIDI 音高（供串音过滤）。
  int? _activePlaybackPitch;
  int? get activePlaybackPitch {
    if (muteAudioOutput && _elapsedMs >= _leadInDurationMs) {
      return null;
    }
    return _activePlaybackPitch;
  }

  int get _elapsedMs => _stopwatch?.elapsedMilliseconds ?? 0;

  bool get _hasLeadInAudio => _leadInDurationMs > 0;

  bool get _allowsAnyAudioOutput => !muteAudioOutput || _hasLeadInAudio;

  bool get _hasMetronomeEvents =>
      _events.any((event) => event.metronomeCue != null);

  Stream<int> get positionMs => _positionController.stream;
  Stream<void> get completed => _completedController.stream;

  int get totalMs => _totalMs;

  Future<void> prepare(
    List<MidiPlaybackEvent> events, {
    required int totalMs,
    int leadInDurationMs = 0,
  }) async {
    await stop();
    _events = List<MidiPlaybackEvent>.from(events)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _totalMs = _resolvePlaybackTotalMs(_events, totalMs);
    _leadInDurationMs = leadInDurationMs.clamp(0, _totalMs);
    _eventIndex = 0;
    _lastMs = -1;
    _activePlaybackPitch = null;
    _audioChain = null;
    _finishing = false;
  }

  static int _resolvePlaybackTotalMs(
    List<MidiPlaybackEvent> events,
    int totalMs,
  ) {
    if (events.isEmpty) return math.max(0, totalMs);
    final lastEventMs = events.last.timeMs;
    return math.max(
      totalMs,
      lastEventMs + SmartSightSingingMidiConfig.playbackTailMs,
    );
  }

  bool _shouldPlayEvent(MidiPlaybackEvent event) {
    if (!muteAudioOutput) return true;
    return event.timeMs < _leadInDurationMs;
  }

  /// 倒计时阶段预加载钢琴采样，避免跟唱开始时 native 会话与录音争抢。
  Future<void> warmupAudioEngine() async {
    if (!_allowsAnyAudioOutput) return;
    await _audio.ensurePianoInitialized();
    if (_hasMetronomeEvents) {
      await _audio.ensureMetronomeInitialized();
    }
  }

  /// AVAudioSession 变更后（试听结束、开始跟唱等）按需重建 iOS 钢琴引擎。
  Future<void> reclaimNativeEngine() async {
    await _audio.reclaimNativeEngineAfterSessionChange();
  }

  Future<void> start({bool? muteAudio}) async {
    if (muteAudio != null) {
      muteAudioOutput = muteAudio;
    }
    if (_running || (_events.isEmpty && _totalMs <= 0)) return;
    if (_allowsAnyAudioOutput) {
      if (_hasMetronomeEvents) {
        await _audio.ensureMetronomeInitialized();
      }
      if (!_audio.isPianoReady) {
        await _audio.ensurePianoInitialized();
      }
    }
    _running = true;
    _eventIndex = 0;
    _lastMs = -1;
    _activePlaybackPitch = null;
    _audioChain = null;
    _finishing = false;
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
      _enqueuePlayEvent(event);
    }

    if (!_positionController.isClosed) {
      _positionController.add(ms);
    }

    if (ms >= _totalMs && _eventIndex >= _events.length) {
      unawaited(_finishWhenReady());
    }
  }

  Future<void> _finishWhenReady() async {
    if (_finishing || !_running) return;
    _finishing = true;
    try {
      final chain = _audioChain;
      if (chain != null) {
        await chain;
      }
      await _finish();
    } finally {
      _finishing = false;
    }
  }

  void _enqueuePlayEvent(MidiPlaybackEvent event) {
    _audioChain = (_audioChain ?? Future<void>.value()).then(
      (_) => _playEvent(event),
    );
  }

  Future<void> _playEvent(MidiPlaybackEvent event) async {
    if (!_shouldPlayEvent(event)) return;
    final cue = event.metronomeCue;
    if (cue != null) {
      _activePlaybackPitch = null;
      try {
        await _audio.playMetronomeCue(cue, volume: event.velocity / 127.0);
      } catch (error, stack) {
        debugPrint(
          'MidiPlaybackScheduler.playMetronomeCue($cue) failed: '
          '$error\n$stack',
        );
      }
      return;
    }

    _activePlaybackPitch = event.pitch;
    final token = _pitchToToken(event.pitch);
    if (token == null) return;
    final volume = (event.velocity / 127.0).clamp(0.0, 1.0);
    try {
      await _audio.playNote(token, volume: volume);
    } catch (error, stack) {
      debugPrint(
        'MidiPlaybackScheduler.playNote($token) failed: $error\n$stack',
      );
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

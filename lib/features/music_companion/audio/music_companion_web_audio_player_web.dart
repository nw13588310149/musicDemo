import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'music_companion_web_audio_player_base.dart';

MusicCompanionWebAudioPlayer createMusicCompanionWebAudioPlayer() {
  return _MusicCompanionWebAudioPlayer();
}

class _MusicCompanionWebAudioPlayer implements MusicCompanionWebAudioPlayer {
  web.AudioContext? _audioContext;
  final Map<String, web.AudioBuffer> _buffersByAsset =
      <String, web.AudioBuffer>{};
  final Set<_ActivePlayback> _activePlaybacks = <_ActivePlayback>{};
  final Set<String> _requestedAssets = <String>{};

  bool _ready = false;
  Future<void>? _prepareTask;

  @override
  bool get isReady => _ready;

  web.AudioContext _ensureContext() {
    return _audioContext ??= web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
  }

  @override
  Future<void> prepare(Iterable<String> assets) {
    _requestedAssets.addAll(assets);
    if (_requestedAssets.every(_buffersByAsset.containsKey)) {
      _ready = true;
      return Future<void>.value();
    }

    return _prepareTask ??= _prepareRequestedAssets().whenComplete(() {
      _prepareTask = null;
    });
  }

  Future<void> _prepareRequestedAssets() async {
    final context = _ensureContext();
    while (_requestedAssets.any((asset) => !_buffersByAsset.containsKey(asset))) {
      final pending = _requestedAssets
          .where((asset) => !_buffersByAsset.containsKey(asset))
          .toList(growable: false);
      await Future.wait(
        pending.map((asset) => _decodeAsset(context, asset)),
      );
    }
    _ready = true;
  }

  Future<void> _decodeAsset(web.AudioContext context, String asset) async {
    final byteData = await rootBundle.load(asset);
    final bytes = Uint8List.fromList(Uint8List.sublistView(byteData));
    final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
    _buffersByAsset[asset] = buffer;
  }

  @override
  Future<void> activateByUserGesture() async {
    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {
    final buffer = _buffersByAsset[asset];
    if (buffer == null) {
      return;
    }

    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }

    final source = context.createBufferSource()..buffer = buffer;
    final gain = context.createGain()
      ..gain.value = volume.clamp(0.0, 1.0).toDouble();

    source.connect(gain);
    gain.connect(context.destination);
    source.start();

    final playback = _ActivePlayback(source: source, gain: gain);
    _activePlaybacks.add(playback);

    final cleanupDelay = Duration(
      milliseconds: (buffer.duration * 1000).ceil() + 48,
    );
    playback.cleanupTimer = Timer(cleanupDelay, () {
      _cleanupPlayback(playback);
    });
  }

  @override
  Future<void> stopAll() async {
    final playbacks = List<_ActivePlayback>.from(_activePlaybacks);
    await Future.wait(playbacks.map(_fadeOutAndCleanup));
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _buffersByAsset.clear();
    _requestedAssets.clear();
    _ready = false;

    final context = _audioContext;
    _audioContext = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }

  Future<void> _fadeOutAndCleanup(_ActivePlayback playback) async {
    if (!_activePlaybacks.contains(playback)) {
      return;
    }
    playback.cleanupTimer?.cancel();
    playback.cleanupTimer = null;

    const steps = 10;
    const stepMs = 10;
    final startGain = playback.gain.gain.value;
    for (var step = 1; step <= steps; step++) {
      if (!_activePlaybacks.contains(playback)) {
        return;
      }
      final scale = (steps - step) / steps;
      playback.gain.gain.value = startGain * scale;
      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }
    _cleanupPlayback(playback, stopSource: true);
  }

  void _cleanupPlayback(_ActivePlayback playback, {bool stopSource = false}) {
    if (!_activePlaybacks.remove(playback)) {
      return;
    }

    playback.cleanupTimer?.cancel();
    playback.cleanupTimer = null;

    if (stopSource) {
      try {
        playback.source.stop();
      } catch (_) {}
    }

    try {
      playback.source.disconnect();
    } catch (_) {}
    try {
      playback.gain.disconnect();
    } catch (_) {}
  }
}

class _ActivePlayback {
  _ActivePlayback({required this.source, required this.gain});

  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  Timer? cleanupTimer;
}

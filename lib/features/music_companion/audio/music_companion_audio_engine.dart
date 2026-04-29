import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';

class MusicCompanionAudioEngine {
  MusicCompanionAudioEngine({SoLoud? soLoud})
    : _soLoud = soLoud ?? SoLoud.instance;

  final SoLoud _soLoud;
  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();

  final Map<String, AudioSource> _pianoSourcesByNote = <String, AudioSource>{};
  final Map<MusicCompanionMetronomeCue, AudioSource> _metronomeSourcesByCue =
      <MusicCompanionMetronomeCue, AudioSource>{};
  final List<SoundHandle> _activeHandles = <SoundHandle>[];

  Future<void>? _initTask;
  Future<void>? _pianoInitTask;
  Future<void>? _metronomeInitTask;

  bool get isReady =>
      kIsWeb ? _webPlayer.isReady : _pianoSourcesByNote.isNotEmpty;

  Future<void> ensureInitialized() {
    return _initTask ??= () async {
      try {
        await Future.wait<void>(<Future<void>>[
          ensurePianoInitialized(),
          ensureMetronomeInitialized(),
        ]);
      } catch (_) {
        // 一旦失败，清空缓存，允许下次调用重新尝试初始化（例如用户重新点击）。
        _initTask = null;
        rethrow;
      }
    }();
  }

  Future<void> ensurePianoInitialized() {
    return _pianoInitTask ??= () async {
      try {
        await _initializePianoAssets();
      } catch (_) {
        _pianoInitTask = null;
        rethrow;
      }
    }();
  }

  Future<void> ensureMetronomeInitialized() {
    return _metronomeInitTask ??= () async {
      try {
        await _initializeMetronomeAssets();
      } catch (_) {
        _metronomeInitTask = null;
        rethrow;
      }
    }();
  }

  Future<void> _initializePianoAssets() async {
    final allAssets = <String>{...kMusicCompanionPianoAssetByNote.values};

    if (kIsWeb) {
      await _webPlayer.prepare(allAssets);
      return;
    }

    if (!_soLoud.isInitialized) {
      await _soLoud.init();
    }
    _soLoud.setMaxActiveVoiceCount(256);

    for (final source in _pianoSourcesByNote.values) {
      await _soLoud.disposeSource(source);
    }
    _pianoSourcesByNote.clear();

    for (final entry in kMusicCompanionPianoAssetByNote.entries) {
      final source = await _soLoud.loadAsset(
        entry.value,
        mode: LoadMode.memory,
      );
      _pianoSourcesByNote[entry.key] = source;
    }
  }

  Future<void> _initializeMetronomeAssets() async {
    final allAssets = <String>{...kMusicCompanionMetronomeAssetByCue.values};

    if (kIsWeb) {
      await _webPlayer.prepare(allAssets);
      return;
    }

    if (!_soLoud.isInitialized) {
      await _soLoud.init();
    }
    _soLoud.setMaxActiveVoiceCount(256);

    for (final entry in kMusicCompanionMetronomeAssetByCue.entries) {
      final existing = _metronomeSourcesByCue[entry.key];
      if (existing != null) {
        await _soLoud.disposeSource(existing);
      }
      final source = await _soLoud.loadAsset(
        entry.value,
        mode: LoadMode.memory,
      );
      _metronomeSourcesByCue[entry.key] = source;
    }
  }

  Future<void> activateByUserGesture() async {
    await ensurePianoInitialized();
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
    }
  }

  Future<void> playNote(String rawNote, {double volume = 1}) async {
    await ensurePianoInitialized();
    final note = _normalizeNote(rawNote);
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _pianoSourcesByNote[note];
    if (source == null) {
      return;
    }
    _registerHandle(_soLoud.play(source, volume: volume));
  }

  Future<void> playNotes(Iterable<String> notes, {double volume = 1}) async {
    await ensurePianoInitialized();
    await Future.wait(notes.map((note) => playNote(note, volume: volume)));
  }

  Future<void> playMetronomeCue(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) async {
    await ensureMetronomeInitialized();
    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _metronomeSourcesByCue[cue];
    if (source == null) {
      return;
    }
    _registerHandle(_soLoud.play(source, volume: volume));
  }

  void _registerHandle(SoundHandle handle) {
    _activeHandles.add(handle);
    if (_activeHandles.length > 1024) {
      _activeHandles.removeRange(0, _activeHandles.length - 512);
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }

    if (!_soLoud.isInitialized) {
      return;
    }

    for (final handle in List<SoundHandle>.from(_activeHandles)) {
      try {
        await _soLoud.stop(handle);
      } catch (_) {}
    }
    _activeHandles.clear();
  }

  Future<void> dispose() async {
    await stopAll();

    if (kIsWeb) {
      await _webPlayer.dispose();
      _initTask = null;
      return;
    }

    for (final source in _pianoSourcesByNote.values) {
      await _soLoud.disposeSource(source);
    }
    for (final source in _metronomeSourcesByCue.values) {
      await _soLoud.disposeSource(source);
    }
    _pianoSourcesByNote.clear();
    _metronomeSourcesByCue.clear();
    _activeHandles.clear();
    _initTask = null;
    _pianoInitTask = null;
    _metronomeInitTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }
}

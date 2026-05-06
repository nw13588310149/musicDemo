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

  /// 设置为 true 后，本引擎会拒绝任何后续的 `playNote` / `playMetronomeCue`。
  ///
  /// 这是修复 iPad 上"退出 musicPlay 页面后还会响一声 ding"的关键：
  /// `pressPianoKey` 的异步链可能在页面 dispose 之后才走到 `_soLoud.play(...)`，
  /// 这里多一层守卫可以阻止那一声"漏播"。
  bool _disposed = false;

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
    if (_disposed) return;
    await ensurePianoInitialized();
    if (_disposed) return;
    final note = _normalizeNote(rawNote);
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      if (_disposed) return;
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _pianoSourcesByNote[note];
    if (source == null || _disposed) {
      return;
    }
    _registerHandle(_soLoud.play(source, volume: volume));
  }

  Future<void> playNotes(Iterable<String> notes, {double volume = 1}) async {
    if (_disposed) return;
    await ensurePianoInitialized();
    if (_disposed) return;
    await Future.wait(notes.map((note) => playNote(note, volume: volume)));
  }

  Future<void> playMetronomeCue(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    await ensureMetronomeInitialized();
    if (_disposed) return;
    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) {
      return;
    }

    if (kIsWeb) {
      if (_disposed) return;
      await _webPlayer.playAsset(asset, volume: volume);
      return;
    }

    final source = _metronomeSourcesByCue[cue];
    if (source == null || _disposed) {
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

  /// 同步、尽力而为地停掉所有当前正在响的声音。
  ///
  /// 用于 [Disposable] 的 widget / controller 在 `dispose()` 中需要在 super
  /// 之前立刻让声音消失的场景：[stopAll] 是 async 的，调用方一旦 unawaited
  /// 它，声音会再延迟若干帧才停止，听感上就是"退出页面后还有 ding 一声"。
  ///
  /// 这里：
  /// - `_soLoud.stop(handle)` 虽然返回 Future，但底层在被调用瞬间就把 stop
  ///   命令推给 audio 线程，几乎是即刻静音；我们 fire-and-forget 即可。
  /// - 同步把 `_activeHandles` 清空，避免后续异步 [stopAll] 重复 stop。
  void stopAllImmediately() {
    if (kIsWeb) {
      unawaited(_webPlayer.stopAll());
      return;
    }
    if (!_soLoud.isInitialized) {
      _activeHandles.clear();
      return;
    }
    for (final handle in List<SoundHandle>.from(_activeHandles)) {
      try {
        if (_soLoud.getIsValidVoiceHandle(handle)) {
          unawaited(_soLoud.stop(handle));
        }
      } catch (_) {}
    }
    _activeHandles.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    // 注意：`_disposed = true` 必须放在第一个 await 之前。
    // 这样调用方即便用 `unawaited(engine.dispose())`，这一句也会同步执行，
    // 之后任何还在 await 中的 [playNote] / [playMetronomeCue] 都会被 short-circuit。
    _disposed = true;
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

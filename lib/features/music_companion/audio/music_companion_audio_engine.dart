import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/low_latency_note_player.dart';
import '../../../core/audio/native_piano_handoff.dart';
import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';

/// 启动预热占位：iOS 低延迟通道在页面进入时 prepare，保留 no-op 兼容旧调用。
Future<void> warmupMusicCompanionPianoAudio() async {}

/// 音乐伴侣 / musicPlay 钢琴共用的音频引擎。
///
/// native/iOS 使用 AVAudioEngine buffer pool；Web 继续使用 WebAudio。
class MusicCompanionAudioEngine {
  MusicCompanionAudioEngine();

  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();
  final LowLatencyNotePlayer _nativePlayer = createLowLatencyNotePlayer();

  Future<void>? _pianoInitTask;
  Future<void>? _metronomeInitTask;
  bool _disposed = false;

  bool get isReady => kIsWeb ? _webPlayer.isReady : !_disposed;

  bool get isPianoReady => kIsWeb ? _webPlayer.isReady : _nativePlayer.isReady;

  /// 从智能视唱 / 智能听写等模块返回后，重建共享 iOS 钢琴引擎并清空排队音符。
  ///
  /// 须在打开音乐伴侣键盘或 musicPlay 钢琴条之前调用，避免「过一会才响
  /// 之前按的音」。
  static Future<void> primeAfterForeignAudioSession(
    MusicCompanionAudioEngine engine,
  ) async {
    if (engine._disposed) return;
    if (kIsWeb) {
      await engine.ensurePianoInitialized();
      return;
    }
    await NativePianoHandoff.run(() async {
      NativePlaybackAudioSession.invalidatePlaybackCache();
      await NativePlaybackAudioSession.ensurePlaybackActive();
      await engine.reclaimNativeGraphAfterSessionChange();
      if (!engine.isPianoReady) {
        await engine.ensurePianoInitialized();
      }
    });
  }

  /// musicPlay：长音频与钢琴混播时，刷新会话（可选软刷新）并重建原生钢琴图。
  ///
  /// [softMediaKitSession] 为 true 时不先 setActive(false)，与正在播的 mpv 共存。
  static Future<void> recoverNativePianoAfterMediaKit(
    MusicCompanionAudioEngine engine, {
    bool softMediaKitSession = false,
  }) async {
    if (engine._disposed || kIsWeb) return;
    await NativePianoHandoff.run(() async {
      if (softMediaKitSession) {
        await NativePlaybackAudioSession.ensureMediaKitPlaybackActive(
          releaseOthersFirst: false,
        );
      } else {
        await NativePlaybackAudioSession.ensureMediaKitPlaybackActive();
      }
      await engine.reclaimNativeGraphAfterSessionChange();
      if (!engine.isPianoReady) {
        await engine.ensurePianoInitialized();
      }
    });
  }

  Future<void> ensureInitialized() async {
    await ensurePianoInitialized();
  }

  Future<void> ensurePianoInitialized() {
    return _pianoInitTask ??= _runEnsurePianoInitialized();
  }

  /// iOS：playAndRecord ↔ playback 切换后重建原生钢琴图（与 handoff 合并排队）。
  Future<void> reclaimNativeEngineAfterSessionChange() async {
    return reclaimNativeGraphAfterSessionChange();
  }

  Future<void> reclaimNativeGraphAfterSessionChange() async {
    if (_disposed || kIsWeb) return;
    await NativePianoHandoff.run(_reclaimNativeGraphOnly);
  }

  Future<void> _reclaimNativeGraphOnly() async {
    if (_disposed || kIsWeb) return;
    await _nativePlayer.reclaimEngine();
    NativePlaybackAudioSession.markNativePianoGraphFresh();
  }

  Future<void> _runEnsurePianoInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(kMusicCompanionPianoAssetByNote.values);
        return;
      }
      await _nativePlayer.prepare(kMusicCompanionPianoAssetByNote);
    } catch (error, stack) {
      _pianoInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensurePianoInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  Future<void> ensureMetronomeInitialized() {
    return _metronomeInitTask ??= _runEnsureMetronomeInitialized();
  }

  Future<void> _runEnsureMetronomeInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(kMusicCompanionMetronomeAssetByCue.values);
        return;
      }
      await _nativePlayer.prepare(_metronomeAssetByKey);
    } catch (error, stack) {
      _metronomeInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensureMetronomeInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  bool tryPlayNoteFromUserGesture(String rawNote, {double volume = 1}) {
    if (_disposed || kIsWeb) return false;
    return _nativePlayer.tryPlay(_normalizeNote(rawNote), volume: volume);
  }

  bool tryPlayMetronomeCueFromUserGesture(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) {
    if (_disposed || kIsWeb) return false;
    return _nativePlayer.tryPlay(_metronomeKey(cue), volume: volume);
  }

  Future<void> activateByUserGesture() async {
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    try {
      await ensurePianoInitialized();
    } catch (_) {
      return;
    }
  }

  Future<void> playNote(String rawNote, {double volume = 1}) async {
    if (_disposed) return;
    final note = _normalizeNote(rawNote);
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return;

    if (kIsWeb) {
      try {
        await ensurePianoInitialized();
      } catch (_) {
        return;
      }
      if (_disposed) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume, metronome: false);
      } catch (error, stack) {
        debugPrint(
          'MusicCompanionAudioEngine.playNote web $note failed: $error\n$stack',
        );
      }
      return;
    }

    try {
      await ensurePianoInitialized();
      if (_disposed) return;
      if (_nativePlayer.tryPlay(note, volume: volume, metronome: false)) {
        return;
      }
      await _nativePlayer.play(note, volume: volume, metronome: false);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playNote $note failed: $error\n$stack',
      );
    }
  }

  Future<void> playNotes(Iterable<String> notes, {double volume = 1}) async {
    if (_disposed) return;
    await Future.wait(notes.map((note) => playNote(note, volume: volume)));
  }

  Future<void> playMetronomeCue(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) return;

    if (kIsWeb) {
      try {
        await ensureMetronomeInitialized();
      } catch (_) {
        return;
      }
      if (_disposed) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume, metronome: true);
      } catch (error, stack) {
        debugPrint(
          'MusicCompanionAudioEngine.playMetronomeCue web $cue failed: '
          '$error\n$stack',
        );
      }
      return;
    }

    try {
      await ensureMetronomeInitialized();
      if (_disposed) return;
      final key = _metronomeKey(cue);
      if (_nativePlayer.tryPlay(key, volume: volume, metronome: true)) {
        return;
      }
      await _nativePlayer.play(key, volume: volume, metronome: true);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playMetronomeCue $cue failed: $error\n$stack',
      );
    }
  }

  /// 仅停止节拍器，不截断虚拟钢琴正在发声的音符。
  Future<void> stopMetronomePlaybacks() async {
    if (_disposed) return;
    if (kIsWeb) {
      await _webPlayer.stopMetronomePlaybacks();
      return;
    }
    if (!kIsWeb) {
      await _nativePlayer.stopMetronomePlaybacks();
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    await _nativePlayer.stopAll();
  }

  /// 与 [stopAll] 相同：短音停止走淡出，避免截断杂音。
  void stopAllImmediately() {
    unawaited(stopAll());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopAll();

    if (kIsWeb) {
      await _webPlayer.dispose();
      _pianoInitTask = null;
      _metronomeInitTask = null;
      return;
    }
    await _nativePlayer.dispose();
    _pianoInitTask = null;
    _metronomeInitTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }

  static Map<String, String> get _metronomeAssetByKey {
    return <String, String>{
      for (final entry in kMusicCompanionMetronomeAssetByCue.entries)
        _metronomeKey(entry.key): entry.value,
    };
  }

  static String _metronomeKey(MusicCompanionMetronomeCue cue) {
    return 'metronome.${cue.name}';
  }
}

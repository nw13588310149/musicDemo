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
  MusicCompanionAudioEngine() {
    debugLastInstance = this;
  }

  /// 屏幕诊断面板用：最近创建的钢琴引擎实例（musicPlay / 音乐伴侣各自一个）。
  static MusicCompanionAudioEngine? debugLastInstance;

  /// 屏幕诊断面板用：返回钢琴播放器 + 原生引擎/会话状态快照。
  Future<Map<String, Object?>> diagnostics() => _nativePlayer.diagnostics();

  /// 屏幕诊断面板用：强制激活播放会话 → 重建图 → 播一个中央音区测试音，
  /// 用于在面板上观察「按下后是否真的出声 / busyVoices 是否递增」。
  Future<void> debugPlayTestNote() async {
    if (_disposed) return;
    if (!kIsWeb) {
      await NativePlaybackAudioSession.ensurePlaybackActive();
      await reclaimNativeGraphAfterSessionChange();
    }
    await playNote('C4', volume: 1);
  }

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
      await _nativePlayer.prepare(_initialPianoAssetByNote);
      // 首次只 prepare 中央音区（C4..C5）以最快进入可弹状态，随后在后台补全
      // 其余音域。原生 prepare 内部把解码放后台串行队列，因此这一步不会阻塞
      // 首音，但能避免「首次按非中央音区琴键时同步解码」造成的迟播。
      unawaited(_warmUpRemainingPianoRange());
    } catch (error, stack) {
      _pianoInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensurePianoInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  /// 后台补全整张钢琴采样（除已 prepare 的中央音区外）。失败静默——
  /// 真正按到未预热的键时 [playNote] 仍会按需 prepare 兜底。
  Future<void> _warmUpRemainingPianoRange() async {
    if (_disposed || kIsWeb) return;
    final remaining = <String, String>{
      for (final entry in kMusicCompanionPianoAssetByNote.entries)
        if (!_nativePlayer.hasPrepared(entry.key)) entry.key: entry.value,
    };
    if (remaining.isEmpty) return;
    try {
      await _nativePlayer.prepare(remaining);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine._warmUpRemainingPianoRange failed: '
        '$error\n$stack',
      );
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
      await _ensureNativePianoNotePrepared(note);
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
    if (!kIsWeb) {
      final normalized = notes.map(_normalizeNote).toList(growable: false);
      await ensurePianoInitialized();
      await _ensureNativePianoNotesPrepared(normalized);
      if (_disposed) return;
      await Future.wait(
        normalized.map((note) => playNote(note, volume: volume)),
      );
      return;
    }
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

  Future<void> _ensureNativePianoNotePrepared(String note) async {
    if (kIsWeb || _nativePlayer.hasPrepared(note)) return;
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return;
    await _nativePlayer.prepare(<String, String>{note: asset});
  }

  Future<void> _ensureNativePianoNotesPrepared(Iterable<String> notes) async {
    if (kIsWeb) return;
    final assets = <String, String>{};
    for (final note in notes) {
      if (_nativePlayer.hasPrepared(note)) continue;
      final asset = kMusicCompanionPianoAssetByNote[note];
      if (asset != null) {
        assets[note] = asset;
      }
    }
    if (assets.isEmpty) return;
    await _nativePlayer.prepare(assets);
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

  static Map<String, String> get _initialPianoAssetByNote {
    return <String, String>{
      for (final entry in kMusicCompanionPianoAssetByNote.entries)
        if (_isInitialPianoNote(entry.key)) entry.key: entry.value,
    };
  }

  static bool _isInitialPianoNote(String note) {
    final midi = _noteMidi(note);
    return midi >= 60 && midi <= 72; // C4..C5: central first-touch range.
  }

  static int _noteMidi(String note) {
    final match = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(note);
    if (match == null) return -1;
    final name = match.group(1);
    final octave = int.tryParse(match.group(2) ?? '');
    if (name == null || octave == null) return -1;
    const pitchClass = <String, int>{
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11,
    };
    final pc = pitchClass[name];
    if (pc == null) return -1;
    return (octave + 1) * 12 + pc;
  }
}

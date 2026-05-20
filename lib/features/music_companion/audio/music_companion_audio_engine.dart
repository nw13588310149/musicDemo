import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_audio_bootstrap.dart';
import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';

/// 启动预热占位：现在由 [NativeAudioBootstrap] 统一在用户进任一音频页面时拉起。
/// main() 不再在这里阻塞，保留这个 no-op 仅是为了对外签名兼容。
Future<void> warmupMusicCompanionPianoAudio() async {}

/// 音乐伴侣 / musicPlay 钢琴共用的音频引擎。
///
/// 重构后的策略（与 [SmartDictationAudioEngine] 一致）：
/// - SoLoud 的 init / AVAudioSession 全部委托给 [NativeAudioBootstrap]，
///   引擎本身只持有钢琴 / 节拍器的 [AudioSource]。
/// - 钢琴 60+ 个 wav 不再启动时一次性加载，改成「懒加载 + 后台预热」：
///   首次点琴键的那个音同步走 SoLoud.play，剩余音在后台串行加载。
/// - 节拍器音源（17 个 mp3）首次播放时按需加载。
/// - 任何一步失败都不会让缓存的 Future 永远卡住——`_pianoInitTask` 会在异常时
///   置空，UI 层可以提示重试或直接再次按键。
class MusicCompanionAudioEngine {
  MusicCompanionAudioEngine({SoLoud? soLoud})
    : _soLoud = soLoud ?? SoLoud.instance;

  final SoLoud _soLoud;
  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();

  final Map<String, AudioSource> _pianoSourcesByNote = <String, AudioSource>{};
  final Map<String, Future<AudioSource?>> _inflightPianoLoads =
      <String, Future<AudioSource?>>{};
  final Map<MusicCompanionMetronomeCue, AudioSource> _metronomeSourcesByCue =
      <MusicCompanionMetronomeCue, AudioSource>{};
  final Map<MusicCompanionMetronomeCue, Future<AudioSource?>>
  _inflightMetronomeLoads =
      <MusicCompanionMetronomeCue, Future<AudioSource?>>{};
  final List<SoundHandle> _activeHandles = <SoundHandle>[];

  Future<void>? _pianoInitTask;
  Future<void>? _metronomeInitTask;
  Future<void>? _pianoWarmupTask;
  bool _disposed = false;

  /// 与 7d9da87 时的语义保持一致：只要任一类音源加载过就算 ready。
  bool get isReady => kIsWeb
      ? _webPlayer.isReady
      : (NativeAudioBootstrap.isReady &&
            (_pianoSourcesByNote.isNotEmpty ||
                _metronomeSourcesByCue.isNotEmpty));

  /// 钢琴可用判定：Bootstrap 已就绪即可点琴键——具体音 wav 的懒加载在 [playNote]
  /// 里完成。这样 UI 不会因为 60 个 wav 没解完一直停在「加载中」。
  bool get isPianoReady =>
      kIsWeb ? _webPlayer.isReady : NativeAudioBootstrap.isReady;

  Future<void> ensureInitialized() async {
    await ensurePianoInitialized();
  }

  Future<void> ensurePianoInitialized() {
    return _pianoInitTask ??= _runEnsurePianoInitialized();
  }

  Future<void> _runEnsurePianoInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(kMusicCompanionPianoAssetByNote.values);
        return;
      }
      await NativeAudioBootstrap.ensureReady();
      // SoLoud 一旦可用就开始后台预热剩余音；任何琴键事件可以走懒加载分支
      // 立刻播放，不需要等预热结束。
      _pianoWarmupTask ??= _warmupAllPianoAssets();
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
      await NativeAudioBootstrap.ensureReady();
      // 节拍器只有 17 个小 mp3，整体并行加载也很快——一次性加载完，
      // 后续每拍都能用 tryPlayMetronomeCueFromUserGesture 同步触发。
      await _loadAllMetronomeAssets();
    } catch (error, stack) {
      _metronomeInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensureMetronomeInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  Future<void> _warmupAllPianoAssets() async {
    for (final entry in kMusicCompanionPianoAssetByNote.entries) {
      if (_disposed) return;
      if (_pianoSourcesByNote.containsKey(entry.key)) continue;
      try {
        await _loadPianoSource(entry.key);
      } catch (error, stack) {
        debugPrint(
          'MusicCompanionAudioEngine piano warmup ${entry.key} failed: '
          '$error\n$stack',
        );
      }
    }
  }

  Future<void> _loadAllMetronomeAssets() async {
    for (final cue in kMusicCompanionMetronomeAssetByCue.keys) {
      if (_disposed) return;
      if (_metronomeSourcesByCue.containsKey(cue)) continue;
      await _loadMetronomeSource(cue);
    }
  }

  Future<AudioSource?> _loadPianoSource(String note) async {
    final cached = _pianoSourcesByNote[note];
    if (cached != null) return cached;
    final inflight = _inflightPianoLoads[note];
    if (inflight != null) return inflight;

    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return null;

    final future = _soLoud
        .loadAsset(asset, mode: LoadMode.memory)
        .then((source) {
          if (!_disposed) {
            _pianoSourcesByNote[note] = source;
          }
          return source;
        })
        .whenComplete(() {
          _inflightPianoLoads.remove(note);
        });
    _inflightPianoLoads[note] = future;
    return future;
  }

  Future<AudioSource?> _loadMetronomeSource(
    MusicCompanionMetronomeCue cue,
  ) async {
    final cached = _metronomeSourcesByCue[cue];
    if (cached != null) return cached;
    final inflight = _inflightMetronomeLoads[cue];
    if (inflight != null) return inflight;

    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) return null;

    final future = _soLoud
        .loadAsset(asset, mode: LoadMode.memory)
        .then((source) {
          if (!_disposed) {
            _metronomeSourcesByCue[cue] = source;
          }
          return source;
        })
        .whenComplete(() {
          _inflightMetronomeLoads.remove(cue);
        });
    _inflightMetronomeLoads[cue] = future;
    return future;
  }

  /// iOS：在用户手势同栈内同步播放——只有该音的 AudioSource 已经在内存里时
  /// 才能成功。预热未到该音时返回 false，调用方应当 fallback 到 `playNote`
  /// 的 await 分支等待加载。
  bool tryPlayNoteFromUserGesture(String rawNote, {double volume = 1}) {
    if (_disposed || kIsWeb || !_soLoud.isInitialized) {
      return false;
    }
    final source = _pianoSourcesByNote[_normalizeNote(rawNote)];
    if (source == null) {
      return false;
    }
    try {
      _registerHandle(_soLoud.play(source, volume: volume));
      return true;
    } catch (error, stack) {
      debugPrint('tryPlayNoteFromUserGesture($rawNote): $error\n$stack');
      return false;
    }
  }

  bool tryPlayMetronomeCueFromUserGesture(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) {
    if (_disposed || kIsWeb || !_soLoud.isInitialized) {
      return false;
    }
    final source = _metronomeSourcesByCue[cue];
    if (source == null) {
      return false;
    }
    try {
      _registerHandle(_soLoud.play(source, volume: volume));
      return true;
    } catch (error, stack) {
      debugPrint(
        'tryPlayMetronomeCueFromUserGesture($cue): $error\n$stack',
      );
      return false;
    }
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
    // 走轻探针：C4 一旦在池里就同步弹一下；没在池里就让 playNote 的懒加载
    // 自然把它拉进来。
    tryPlayNoteFromUserGesture('C4', volume: 0.02);
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
        await _webPlayer.playAsset(asset, volume: volume);
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
      final source = await _loadPianoSource(note);
      if (source == null || _disposed) return;
      _registerHandle(_soLoud.play(source, volume: volume));
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
        await _webPlayer.playAsset(asset, volume: volume);
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
      final source = await _loadMetronomeSource(cue);
      if (source == null || _disposed) return;
      _registerHandle(_soLoud.play(source, volume: volume));
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playMetronomeCue $cue failed: $error\n$stack',
      );
    }
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
    if (!_soLoud.isInitialized) return;
    for (final handle in List<SoundHandle>.from(_activeHandles)) {
      try {
        await _soLoud.stop(handle);
      } catch (_) {}
    }
    _activeHandles.clear();
  }

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
    _disposed = true;
    await stopAll();

    if (kIsWeb) {
      await _webPlayer.dispose();
      _pianoInitTask = null;
      _metronomeInitTask = null;
      _pianoWarmupTask = null;
      return;
    }
    // 同样不再 deinit SoLoud——这是全局共享的实例，参见 [NativeAudioBootstrap]。
    for (final source in _pianoSourcesByNote.values) {
      try {
        await _soLoud.disposeSource(source);
      } catch (_) {}
    }
    for (final source in _metronomeSourcesByCue.values) {
      try {
        await _soLoud.disposeSource(source);
      } catch (_) {}
    }
    _pianoSourcesByNote.clear();
    _metronomeSourcesByCue.clear();
    _inflightPianoLoads.clear();
    _inflightMetronomeLoads.clear();
    _activeHandles.clear();
    _pianoInitTask = null;
    _metronomeInitTask = null;
    _pianoWarmupTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }
}

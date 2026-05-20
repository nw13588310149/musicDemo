import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

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
  MusicCompanionAudioEngine();

  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();

  final Map<String, AudioPlayer> _pianoPlayersByNote = <String, AudioPlayer>{};
  final Map<String, Future<AudioPlayer?>> _inflightPianoPlayers =
      <String, Future<AudioPlayer?>>{};
  final Map<MusicCompanionMetronomeCue, AudioPlayer> _metronomePlayersByCue =
      <MusicCompanionMetronomeCue, AudioPlayer>{};
  final Map<MusicCompanionMetronomeCue, Future<AudioPlayer?>>
  _inflightMetronomePlayers =
      <MusicCompanionMetronomeCue, Future<AudioPlayer?>>{};
  final Set<AudioPlayer> _activeOneShotPlayers = <AudioPlayer>{};

  Future<void>? _pianoInitTask;
  Future<void>? _metronomeInitTask;
  bool _disposed = false;

  bool get isReady => kIsWeb ? _webPlayer.isReady : !_disposed;

  /// native/iOS 现在走 just_audio 懒加载，不需要等待 SoLoud.init。
  bool get isPianoReady => kIsWeb ? _webPlayer.isReady : !_disposed;

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
      // native/iOS: no-op. Each note is prepared lazily by just_audio.
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
      // native/iOS: no-op. Cues are prepared lazily by just_audio.
    } catch (error, stack) {
      _metronomeInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensureMetronomeInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  Future<AudioPlayer?> _loadPianoPlayer(String note) async {
    final cached = _pianoPlayersByNote[note];
    if (cached != null) return cached;
    final inflight = _inflightPianoPlayers[note];
    if (inflight != null) return inflight;

    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return null;

    final future = _createAssetPlayer(asset).then((player) {
      if (_disposed) {
        unawaited(player.dispose());
        return null;
      }
      _pianoPlayersByNote[note] = player;
      return player;
    }).whenComplete(() {
      _inflightPianoPlayers.remove(note);
    });
    _inflightPianoPlayers[note] = future;
    return future;
  }

  Future<AudioPlayer?> _loadMetronomePlayer(
    MusicCompanionMetronomeCue cue,
  ) async {
    final cached = _metronomePlayersByCue[cue];
    if (cached != null) return cached;
    final inflight = _inflightMetronomePlayers[cue];
    if (inflight != null) return inflight;

    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) return null;

    final future = _createAssetPlayer(asset).then((player) {
      if (_disposed) {
        unawaited(player.dispose());
        return null;
      }
      _metronomePlayersByCue[cue] = player;
      return player;
    }).whenComplete(() {
      _inflightMetronomePlayers.remove(cue);
    });
    _inflightMetronomePlayers[cue] = future;
    return future;
  }

  Future<AudioPlayer> _createAssetPlayer(String asset) async {
    final player = AudioPlayer();
    await player.setAsset(asset);
    await player.setVolume(1);
    return player;
  }

  Future<void> _playPreparedPlayer(AudioPlayer player, {double volume = 1}) async {
    await player.setVolume(volume.clamp(0.0, 1.0));
    await player.seek(Duration.zero);
    await player.play();
  }

  /// iOS：在用户手势同栈内同步播放——只有该音的 AudioSource 已经在内存里时
  /// 才能成功。预热未到该音时返回 false，调用方应当 fallback 到 `playNote`
  /// 的 await 分支等待加载。
  bool tryPlayNoteFromUserGesture(String rawNote, {double volume = 1}) {
    // just_audio 的 asset prepare/play 都是 async，无法在同一手势栈同步发声。
    // 调用方会 fallback 到 [playNote]。
    return false;
  }

  bool tryPlayMetronomeCueFromUserGesture(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) {
    return false;
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
    await playNote('C4', volume: 0.02);
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
      final player = await _loadPianoPlayer(note);
      if (player == null || _disposed) return;
      if (player.playing) {
        final oneShot = await _createAssetPlayer(asset);
        _activeOneShotPlayers.add(oneShot);
        unawaited(
          _playPreparedPlayer(oneShot, volume: volume).whenComplete(() async {
            _activeOneShotPlayers.remove(oneShot);
            await oneShot.dispose();
          }),
        );
        return;
      }
      await _playPreparedPlayer(player, volume: volume);
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
      final player = await _loadMetronomePlayer(cue);
      if (player == null || _disposed) return;
      await _playPreparedPlayer(player, volume: volume);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playMetronomeCue $cue failed: $error\n$stack',
      );
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    final players = <AudioPlayer>{
      ..._pianoPlayersByNote.values,
      ..._metronomePlayersByCue.values,
      ..._activeOneShotPlayers,
    };
    await Future.wait(players.map((player) => player.stop().catchError((_) {})));
  }

  void stopAllImmediately() {
    if (kIsWeb) {
      unawaited(_webPlayer.stopAll());
      return;
    }
    for (final player in <AudioPlayer>{
      ..._pianoPlayersByNote.values,
      ..._metronomePlayersByCue.values,
      ..._activeOneShotPlayers,
    }) {
      unawaited(player.stop().catchError((_) {}));
    }
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
    for (final player in <AudioPlayer>{
      ..._pianoPlayersByNote.values,
      ..._metronomePlayersByCue.values,
      ..._activeOneShotPlayers,
    }) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _pianoPlayersByNote.clear();
    _metronomePlayersByCue.clear();
    _inflightPianoPlayers.clear();
    _inflightMetronomePlayers.clear();
    _activeOneShotPlayers.clear();
    _pianoInitTask = null;
    _metronomeInitTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }
}

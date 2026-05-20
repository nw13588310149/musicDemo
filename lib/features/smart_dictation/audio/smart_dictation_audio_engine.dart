import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'web_note_audio_player_base.dart';
import 'web_note_audio_player_stub.dart'
    if (dart.library.html) 'web_note_audio_player_web.dart';

/// 智能听写音频引擎。
///
/// 重构后的核心策略（iPad 修复版）：
/// - SoLoud 的 init / AVAudioSession 全部委托给 [NativeAudioBootstrap]，
///   引擎自己只关心音源（AudioSource）的加载和播放；
/// - 不再启动时一次性加载 30 个 wav，改为「懒加载 + 后台预热」：
///   * `ensureInitialized()` 只保证 SoLoud 可用，然后立刻返回 `audioReady`；
///   * 首次 `playToken(...)` 时按需加载真正用到的那一个 wav；
///   * 同时在后台串行预热剩余 wav，让后续点击零延迟。
/// - 任何一步失败都会清空当次缓存的 Future，下一次调用即可重试。
class SmartDictationAudioEngine {
  SmartDictationAudioEngine();

  final WebNoteAudioPlayer _webPlayer = createWebNoteAudioPlayer();
  final Map<String, AudioPlayer> _playersByCanonical = <String, AudioPlayer>{};
  final Map<String, Future<AudioPlayer?>> _inflightLoads =
      <String, Future<AudioPlayer?>>{};
  final Set<AudioPlayer> _activeOneShotPlayers = <AudioPlayer>{};
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();
  Future<void>? _initTask;
  bool _disposed = false;

  bool get isReady => kIsWeb ? _webPlayer.isReady : !_disposed;

  Stream<List<double>> get frequencyBands =>
      kIsWeb ? _webPlayer.frequencyBands : _frequencyController.stream;

  /// Web 端准备 WebAudio；native/iOS 走 just_audio 懒加载，不再等待 SoLoud。
  Future<void> ensureInitialized() {
    return _initTask ??= _runEnsureInitialized();
  }

  Future<void> _runEnsureInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(_assetByCanonical.values);
        return;
      }
      // native/iOS: no-op. Each note is prepared lazily by just_audio.
    } catch (error, stack) {
      _initTask = null;
      debugPrint(
        'SmartDictationAudioEngine.ensureInitialized failed: $error\n$stack',
      );
      rethrow;
    }
  }

  Future<AudioPlayer?> _loadPlayerForCanonical(String canonical) async {
    final cached = _playersByCanonical[canonical];
    if (cached != null) return cached;
    final inflight = _inflightLoads[canonical];
    if (inflight != null) return inflight;

    final asset = _assetByCanonical[canonical];
    if (asset == null) return null;

    final future = _createAssetPlayer(asset).then((player) {
      if (_disposed) {
        unawaited(player.dispose());
        return null;
      }
      _playersByCanonical[canonical] = player;
      return player;
    }).whenComplete(() {
      _inflightLoads.remove(canonical);
    });
    _inflightLoads[canonical] = future;
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
    _emitNativeVisualPulse();
  }

  Future<void> playToken(String token, {double volume = 1}) async {
    if (_disposed) return;
    final canonical = canonicalFromToken(token);
    if (canonical.isEmpty) return;

    if (kIsWeb) {
      final asset = _assetByCanonical[canonical];
      if (asset == null) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume);
      } catch (error, stack) {
        debugPrint(
          'SmartDictationAudioEngine.playToken web $canonical failed: '
          '$error\n$stack',
        );
      }
      return;
    }

    try {
      await ensureInitialized();
      if (_disposed) return;
      final asset = _assetByCanonical[canonical];
      final player = await _loadPlayerForCanonical(canonical);
      if (asset == null || player == null || _disposed) return;
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
        'SmartDictationAudioEngine.playToken $canonical failed: $error\n$stack',
      );
    }
  }

  Future<void> activateByUserGesture() async {
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      // 这里允许失败：UI 层的「重试」会再次走一次。
      return;
    }
    await playToken('a1', volume: 0.02);
  }

  Future<void> playTokensHarmonic(
    List<String> tokens, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    if (kIsWeb) {
      for (final token in tokens) {
        await playToken(token, volume: volume);
      }
      return;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return;
    }
    for (final token in tokens) {
      if (_disposed) return;
      final canonical = canonicalFromToken(token);
      if (canonical.isEmpty) continue;
      final asset = _assetByCanonical[canonical];
      final player = await _loadPlayerForCanonical(canonical);
      if (asset == null || player == null || _disposed) continue;
      try {
        if (player.playing) {
          final oneShot = await _createAssetPlayer(asset);
          _activeOneShotPlayers.add(oneShot);
          unawaited(
            _playPreparedPlayer(oneShot, volume: volume).whenComplete(() async {
              _activeOneShotPlayers.remove(oneShot);
              await oneShot.dispose();
            }),
          );
        } else {
          await _playPreparedPlayer(player, volume: volume);
        }
      } catch (error, stack) {
        debugPrint(
          'SmartDictationAudioEngine harmonic $canonical failed: '
          '$error\n$stack',
        );
      }
    }
  }

  Future<void> playTokensMelodic(
    List<String> tokens, {
    Duration gap = const Duration(milliseconds: 320),
    double volume = 1,
  }) async {
    if (_disposed) return;
    for (var i = 0; i < tokens.length; i++) {
      if (_disposed) return;
      await playToken(tokens[i], volume: volume);
      if (i < tokens.length - 1) {
        await Future<void>.delayed(gap);
      }
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    final players = <AudioPlayer>{
      ..._playersByCanonical.values,
      ..._activeOneShotPlayers,
    };
    await Future.wait(players.map((player) => player.stop().catchError((_) {})));
    _frequencyController.add(const <double>[]);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (kIsWeb) {
      await _webPlayer.dispose();
      _initTask = null;
      return;
    }
    for (final player in <AudioPlayer>{
      ..._playersByCanonical.values,
      ..._activeOneShotPlayers,
    }) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _playersByCanonical.clear();
    _inflightLoads.clear();
    _activeOneShotPlayers.clear();
    if (!_frequencyController.isClosed) {
      await _frequencyController.close();
    }
    _initTask = null;
  }

  void _emitNativeVisualPulse() {
    if (_frequencyController.isClosed) return;
    const bands = 46;
    final result = List<double>.filled(bands, 0);
    for (var i = 0; i < bands; i++) {
      final wave = math.sin(i / bands * math.pi);
      result[i] = (wave * 0.85).clamp(0.0, 1.0);
    }
    _frequencyController.add(result);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!_frequencyController.isClosed) {
        _frequencyController.add(const <double>[]);
      }
    });
  }

  static List<String> splitTokenGroup(String raw) {
    final cleaned = raw.replaceAll('，', ',').replaceAll('、', ',').trim();
    if (cleaned.isEmpty) {
      return const <String>[];
    }
    return cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String canonicalFromToken(String rawToken) {
    if (rawToken.isEmpty) {
      return '';
    }
    final normalized = _normalizeToken(rawToken);
    if (normalized.isEmpty) {
      return '';
    }

    final direct = _tokenToCanonical[normalized];
    if (direct != null) {
      return direct;
    }

    final upper = normalized.toUpperCase();
    if (_assetByCanonical.containsKey(upper)) {
      return upper;
    }
    return '';
  }

  static String _normalizeToken(String raw) {
    return raw
        .trim()
        .replaceAll('<sup>#</sup>', '#')
        .replaceAll('<sup>b</sup>', 'b')
        .replaceAll('<sup>', '')
        .replaceAll('</sup>', '')
        .replaceAll('♯', '#')
        .replaceAll('＃', '#')
        .replaceAll('♭', 'b')
        .replaceAll('Ｂ', 'b')
        .replaceAll('，', ',')
        .replaceAll('。', '')
        .replaceAll('鹿', '1')
        .replaceAll('虏', '2')
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^a-zA-Z0-9#,]'), '')
        .toLowerCase();
  }

  static const Map<String, String> _assetByCanonical = <String, String>{
    'F3': 'assets/audio/smart_dictation/piano/a81.wav',
    'F#3': 'assets/audio/smart_dictation/piano/b81.wav',
    'G3': 'assets/audio/smart_dictation/piano/a87.wav',
    'G#3': 'assets/audio/smart_dictation/piano/b87.wav',
    'A3': 'assets/audio/smart_dictation/piano/a69.wav',
    'A#3': 'assets/audio/smart_dictation/piano/b69.wav',
    'B3': 'assets/audio/smart_dictation/piano/a82.wav',
    'C4': 'assets/audio/smart_dictation/piano/a84.wav',
    'C#4': 'assets/audio/smart_dictation/piano/b84.wav',
    'D4': 'assets/audio/smart_dictation/piano/a89.wav',
    'D#4': 'assets/audio/smart_dictation/piano/b89.wav',
    'E4': 'assets/audio/smart_dictation/piano/a85.wav',
    'F4': 'assets/audio/smart_dictation/piano/a73.wav',
    'F#4': 'assets/audio/smart_dictation/piano/b73.wav',
    'G4': 'assets/audio/smart_dictation/piano/a79.wav',
    'G#4': 'assets/audio/smart_dictation/piano/b79.wav',
    'A4': 'assets/audio/smart_dictation/piano/a80.wav',
    'A#4': 'assets/audio/smart_dictation/piano/b80.wav',
    'B4': 'assets/audio/smart_dictation/piano/a65.wav',
    'C5': 'assets/audio/smart_dictation/piano/a83.wav',
    'C#5': 'assets/audio/smart_dictation/piano/b83.wav',
    'D5': 'assets/audio/smart_dictation/piano/a68.wav',
    'D#5': 'assets/audio/smart_dictation/piano/b68.wav',
    'E5': 'assets/audio/smart_dictation/piano/a70.wav',
    'F5': 'assets/audio/smart_dictation/piano/a71.wav',
    'F#5': 'assets/audio/smart_dictation/piano/b71.wav',
    'G5': 'assets/audio/smart_dictation/piano/a72.wav',
    'G#5': 'assets/audio/smart_dictation/piano/b72.wav',
    'A5': 'assets/audio/smart_dictation/piano/a74.wav',
    'A#5': 'assets/audio/smart_dictation/piano/b74.wav',
  };

  static const Map<String, String> _tokenToCanonical = <String, String>{
    'f': 'F3',
    '#f': 'F#3',
    'g': 'G3',
    '#g': 'G#3',
    'a': 'A3',
    'bb': 'A#3',
    'a#': 'A#3',
    'b': 'B3',
    'c': 'C4',
    'c1': 'C4',
    '#c1': 'C#4',
    'd1': 'D4',
    'be1': 'D#4',
    'd#1': 'D#4',
    'e1': 'E4',
    'f1': 'F4',
    '#f1': 'F#4',
    'g1': 'G4',
    '#g1': 'G#4',
    'a1': 'A4',
    'bb1': 'A#4',
    'a#1': 'A#4',
    'b1': 'B4',
    'c2': 'C5',
    '#c2': 'C#5',
    'd2': 'D5',
    'be2': 'D#5',
    'd#2': 'D#5',
    'e2': 'E5',
    'f2': 'F5',
    '#f2': 'F#5',
    'g2': 'G5',
    '#g2': 'G#5',
    'a2': 'A5',
    'bb2': 'A#5',
    'a#2': 'A#5',
    'f3': 'F3',
    'f#3': 'F#3',
    'g3': 'G3',
    'g#3': 'G#3',
    'a3': 'A3',
    'a#3': 'A#3',
    'b3': 'B3',
    'c4': 'C4',
    'c#4': 'C#4',
    'd4': 'D4',
    'd#4': 'D#4',
    'e4': 'E4',
    'f4': 'F4',
    'f#4': 'F#4',
    'g4': 'G4',
    'g#4': 'G#4',
    'a4': 'A4',
    'a#4': 'A#4',
    'b4': 'B4',
    'c5': 'C5',
    'c#5': 'C#5',
    'd5': 'D5',
    'd#5': 'D#5',
    'e5': 'E5',
    'f5': 'F5',
    'f#5': 'F#5',
    'g5': 'G5',
    'g#5': 'G#5',
    'a5': 'A5',
    'a#5': 'A#5',
  };
}

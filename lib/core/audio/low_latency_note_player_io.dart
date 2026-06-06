import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'low_latency_note_player.dart';

LowLatencyNotePlayer createPlatformLowLatencyNotePlayer() {
  return _IoLowLatencyNotePlayer();
}

class _IoLowLatencyNotePlayer implements LowLatencyNotePlayer {
  static const MethodChannel _channel = MethodChannel(
    'com.yyzl.music/low_latency_notes',
  );

  /// 原生引擎重建 / 采样解码的最长等待。iOS 上 AVAudioEngine 重连偶发不返回，
  /// 不加超时会让上层 handoff 永久卡住、整页转圈。
  static const Duration _kHeavyChannelTimeout = Duration(seconds: 6);

  final Map<String, String> _assetByKey = <String, String>{};
  final Map<String, AudioPlayer> _fallbackPlayers = <String, AudioPlayer>{};
  final Map<String, Future<AudioPlayer?>> _fallbackLoads =
      <String, Future<AudioPlayer?>>{};
  final Set<AudioPlayer> _fallbackOneShots = <AudioPlayer>{};

  bool _nativeReady = false;
  bool _fallbackMode = false;
  bool _disposed = false;

  /// 诊断用：最近一次原生通道失败信息（屏幕诊断面板读取）。
  String? _lastNativeError;

  @override
  bool get isReady => !_disposed && (_nativeReady || _fallbackMode);

  @override
  bool get supportsImmediatePlay => _nativeReady;

  @override
  Future<Map<String, Object?>> diagnostics() async {
    final base = <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'nativeReady': _nativeReady,
      'fallbackMode': _fallbackMode,
      'registeredKeys': _assetByKey.length,
      'fallbackPlayers': _fallbackPlayers.length,
      'lastNativeError': _lastNativeError,
    };
    if (defaultTargetPlatform == TargetPlatform.iOS && !_disposed) {
      try {
        final native = await _channel
            .invokeMapMethod<String, Object?>('diagnostics')
            .timeout(const Duration(seconds: 3));
        if (native != null) {
          native.forEach((key, value) => base['native_$key'] = value);
        }
      } on TimeoutException {
        base['native_error'] = 'diagnostics timed out';
      } on PlatformException catch (e) {
        base['native_error'] = 'diagnostics failed: ${e.message}';
      } on MissingPluginException {
        base['native_error'] = 'channel missing (handler not registered)';
      }
    }
    return base;
  }

  @override
  Future<void> prepare(Map<String, String> assetByKey) async {
    if (_disposed) return;
    _assetByKey.addAll(assetByKey);

    if (assetByKey.isEmpty && _assetByKey.isEmpty) {
      _nativeReady = true;
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel
            .invokeMethod<void>('prepare', <String, Object>{
              'assets': assetByKey,
            })
            .timeout(_kHeavyChannelTimeout);
        _nativeReady = true;
        _fallbackMode = false;
        return;
      } on TimeoutException catch (error, stack) {
        _lastNativeError = 'prepare timed out: $error';
        debugPrint(
          'LowLatencyNotePlayer native prepare timed out: $error\n$stack',
        );
      } on MissingPluginException catch (error, stack) {
        _lastNativeError = 'channel missing: $error';
        debugPrint(
          'LowLatencyNotePlayer native channel missing: $error\n$stack',
        );
      } on PlatformException catch (error, stack) {
        _lastNativeError = 'prepare failed: $error';
        debugPrint(
          'LowLatencyNotePlayer native prepare failed: $error\n$stack',
        );
      }
    }

    // Android / desktop / iOS channel failure fallback. This is not intended for
    // piano latency, but keeps non-iOS builds functional while iPad uses native.
    _fallbackMode = true;
    _nativeReady = false;
  }

  @override
  bool hasPrepared(String key) {
    if (!_assetByKey.containsKey(key)) return false;
    if (_nativeReady) return true;
    return _fallbackPlayers.containsKey(key);
  }

  @override
  bool tryPlay(String key, {double volume = 1, bool metronome = false}) {
    if (_disposed || !_assetByKey.containsKey(key) || !_nativeReady) {
      return false;
    }
    unawaited(play(key, volume: volume, metronome: metronome));
    return true;
  }

  @override
  Future<void> reclaimEngine() async {
    if (_disposed || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('reclaimEngine')
          .timeout(_kHeavyChannelTimeout);
    } on TimeoutException catch (error, stack) {
      debugPrint(
        'LowLatencyNotePlayer reclaimEngine timed out: $error\n$stack',
      );
    } on PlatformException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer reclaimEngine failed: $error\n$stack');
    } on MissingPluginException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer reclaimEngine missing: $error\n$stack');
    }
  }

  @override
  Future<void> play(
    String key, {
    double volume = 1,
    bool metronome = false,
    bool waitUntilFinished = false,
  }) async {
    if (_disposed || !_assetByKey.containsKey(key)) return;
    final safeVolume = volume.clamp(0.0, 1.0).toDouble();

    if (_nativeReady) {
      try {
        await _channel.invokeMethod<void>('play', <String, Object>{
          'key': key,
          'volume': safeVolume,
          'metronome': metronome,
          'waitUntilFinished': waitUntilFinished,
        });
        return;
      } on PlatformException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native play failed: $error\n$stack');
      } on MissingPluginException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native play missing: $error\n$stack');
      }
    }

    final player = await _loadFallbackPlayer(key);
    if (player == null || _disposed) return;
    final asset = _assetByKey[key];
    if (asset == null) return;

    if (player.playing) {
      final oneShot = await _createFallbackPlayer(asset);
      _fallbackOneShots.add(oneShot);
      unawaited(
        _playFallback(oneShot, volume: safeVolume).whenComplete(() async {
          _fallbackOneShots.remove(oneShot);
          await oneShot.dispose();
        }),
      );
      return;
    }

    await _playFallback(player, volume: safeVolume);
  }

  Future<AudioPlayer?> _loadFallbackPlayer(String key) async {
    final cached = _fallbackPlayers[key];
    if (cached != null) return cached;
    final inflight = _fallbackLoads[key];
    if (inflight != null) return inflight;

    final asset = _assetByKey[key];
    if (asset == null) return null;
    final future = _createFallbackPlayer(asset)
        .then((player) {
          if (_disposed) {
            unawaited(player.dispose());
            return null;
          }
          _fallbackPlayers[key] = player;
          return player;
        })
        .whenComplete(() {
          _fallbackLoads.remove(key);
        });
    _fallbackLoads[key] = future;
    return future;
  }

  Future<AudioPlayer> _createFallbackPlayer(String asset) async {
    final player = AudioPlayer();
    await player.setAsset(asset);
    await player.setVolume(1);
    return player;
  }

  Future<void> _playFallback(
    AudioPlayer player, {
    required double volume,
  }) async {
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    await player.play();
  }

  @override
  Future<void> stopMetronomePlaybacks() async {
    if (!_nativeReady) return;
    try {
      await _channel.invokeMethod<void>('stopMetronome');
    } catch (_) {}
  }

  @override
  Future<void> stopAll() async {
    if (_nativeReady) {
      try {
        await _channel.invokeMethod<void>('stopAll');
      } catch (_) {}
    }

    final players = <AudioPlayer>{
      ..._fallbackPlayers.values,
      ..._fallbackOneShots,
    };
    await Future.wait(
      players.map((player) => player.stop().catchError((_) {})),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_nativeReady) {
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // iOS 的 AVAudioEngine + decoded sample buffers 是 App 级短音频资源。
          // 页面离开只停声，不销毁原生图；下一页 prepare 同一批 key 时原生层会复用
          // buffers，避免 musicPlay / 音乐伴侣反复冷解码整张钢琴。
          await _channel.invokeMethod<void>('stopAll');
        } else {
          await _channel.invokeMethod<void>('dispose');
        }
      } catch (_) {}
    }

    final players = <AudioPlayer>{
      ..._fallbackPlayers.values,
      ..._fallbackOneShots,
    };
    for (final player in players) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _fallbackPlayers.clear();
    _fallbackLoads.clear();
    _fallbackOneShots.clear();
    _assetByKey.clear();
    _nativeReady = false;
    _fallbackMode = false;
  }
}

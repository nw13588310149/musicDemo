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

  final Map<String, String> _assetByKey = <String, String>{};
  final Map<String, AudioPlayer> _fallbackPlayers = <String, AudioPlayer>{};
  final Map<String, Future<AudioPlayer?>> _fallbackLoads =
      <String, Future<AudioPlayer?>>{};
  final Set<AudioPlayer> _fallbackOneShots = <AudioPlayer>{};

  bool _nativeReady = false;
  bool _fallbackMode = false;
  bool _disposed = false;

  @override
  bool get isReady => !_disposed && (_nativeReady || _fallbackMode);

  @override
  bool get supportsImmediatePlay => _nativeReady;

  @override
  Future<void> prepare(Map<String, String> assetByKey) async {
    if (_disposed) return;
    _assetByKey.addAll(assetByKey);

    if (_assetByKey.isEmpty) {
      _nativeReady = true;
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod<void>('prepare', <String, Object>{
          'assets': _assetByKey,
        });
        _nativeReady = true;
        _fallbackMode = false;
        return;
      } on MissingPluginException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native channel missing: $error\n$stack');
      } on PlatformException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native prepare failed: $error\n$stack');
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
  bool tryPlay(String key, {double volume = 1}) {
    if (_disposed || !_assetByKey.containsKey(key) || !_nativeReady) {
      return false;
    }
    unawaited(play(key, volume: volume));
    return true;
  }

  @override
  Future<void> reclaimEngine() async {
    if (_disposed ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (!_nativeReady) return;
    try {
      await _channel.invokeMethod<void>('reclaimEngine');
    } on PlatformException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer reclaimEngine failed: $error\n$stack');
    } on MissingPluginException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer reclaimEngine missing: $error\n$stack');
    }
  }

  @override
  Future<void> play(String key, {double volume = 1}) async {
    if (_disposed || !_assetByKey.containsKey(key)) return;
    final safeVolume = volume.clamp(0.0, 1.0).toDouble();

    if (_nativeReady) {
      try {
        await _channel.invokeMethod<void>('play', <String, Object>{
          'key': key,
          'volume': safeVolume,
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
    final future = _createFallbackPlayer(asset).then((player) {
      if (_disposed) {
        unawaited(player.dispose());
        return null;
      }
      _fallbackPlayers[key] = player;
      return player;
    }).whenComplete(() {
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

  Future<void> _playFallback(AudioPlayer player, {required double volume}) async {
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    await player.play();
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
    await Future.wait(players.map((player) => player.stop().catchError((_) {})));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_nativeReady) {
      try {
        await _channel.invokeMethod<void>('dispose');
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

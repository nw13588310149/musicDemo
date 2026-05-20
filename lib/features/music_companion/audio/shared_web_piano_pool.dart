import 'dart:async';

import 'package:flutter/foundation.dart';

import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';

/// Web 端全应用共享的钢琴 AudioBuffer 池（页面退出不销毁，避免反复解码 60+ wav）。
class SharedWebPianoPool implements MusicCompanionWebAudioPlayer {
  SharedWebPianoPool._();

  static final SharedWebPianoPool instance = SharedWebPianoPool._();

  final MusicCompanionWebAudioPlayer _player =
      createMusicCompanionWebAudioPlayer();

  Future<void>? _pianoLoadTask;

  @override
  bool get isReady => _player.isReady;

  /// 仅加载虚拟钢琴音源；失败会清空 [ _pianoLoadTask ] 以便重试。
  Future<void> ensurePianoLoaded() {
    if (_player.isReady) {
      return Future<void>.value();
    }
    return _pianoLoadTask ??= _loadPiano();
  }

  Future<void> _loadPiano() async {
    try {
      await _player
          .prepare(kMusicCompanionPianoAssetByNote.values)
          .timeout(const Duration(seconds: 90));
    } catch (error, stack) {
      _pianoLoadTask = null;
      debugPrint('SharedWebPianoPool.ensurePianoLoaded failed: $error\n$stack');
      rethrow;
    }
  }

  @override
  Future<void> prepare(Iterable<String> assets) => _player.prepare(assets);

  @override
  Future<void> activateByUserGesture() => _player.activateByUserGesture();

  @override
  Future<void> playAsset(String asset, {double volume = 1}) =>
      _player.playAsset(asset, volume: volume);

  @override
  Future<void> stopAll() => _player.stopAll();

  /// 应用级常驻池，一般不在页面 dispose 时调用。
  @override
  Future<void> dispose() => _player.dispose();
}

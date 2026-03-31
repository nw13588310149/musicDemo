import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../data/piano_notes.dart';

/// 钢琴音频单例：
/// 1) 统一初始化 SoLoud 引擎
/// 2) 预加载所有琴键采样到内存
/// 3) 支持高频并发触发（每次 play 都是一个独立 voice）
class PianoAudioManager {
  PianoAudioManager._();

  static final PianoAudioManager instance = PianoAudioManager._();

  final Map<String, AudioSource> _cache = <String, AudioSource>{};

  bool _initialized = false;
  bool _preloaded = false;

  bool get isReady => _initialized && _preloaded;

  Future<void> init() async {
    if (_initialized) return;
    await SoLoud.instance.init();
    SoLoud.instance.setMaxActiveVoiceCount(64);
    _initialized = true;
  }

  Future<void> preloadAll() async {
    if (_preloaded) return;
    await init();

    final List<Future<void>> jobs = <Future<void>>[];
    for (final String file in PianoNotes.allSampleFiles()) {
      jobs.add(_loadOne(file));
    }
    await Future.wait(jobs);
    _preloaded = true;
  }

  Future<void> playByFileName(String fileName) async {
    await init();
    final AudioSource? source = _cache[fileName];
    if (source == null) {
      // 避免首击 miss：若漏预加载，按需补齐。
      await _loadOne(fileName);
    }
    final AudioSource? finalSource = _cache[fileName];
    if (finalSource == null) return;
    await SoLoud.instance.play(finalSource);
  }

  Future<void> dispose() async {
    _cache.clear();
    _initialized = false;
    _preloaded = false;
    SoLoud.instance.deinit();
  }

  Future<void> _loadOne(String fileName) async {
    if (_cache.containsKey(fileName)) return;
    final String assetPath = 'assets/audio/piano/$fileName';
    try {
      final AudioSource source = await SoLoud.instance.loadAsset(assetPath);
      _cache[fileName] = source;
    } catch (e, st) {
      debugPrint('PianoAudioManager preload failed: $assetPath -> $e\n$st');
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_catalog.dart';

/// 全应用唯一的 SoLoud 钢琴音源池（页面退出不销毁 wav）。
///
/// iPad：先 [ensurePlayable]（初始化 + C4），尽快去掉「加载中」遮罩；
/// 全量 wav 在后台串行加载，避免并发 [loadAsset] 卡死。
class SharedSoLoudPianoPool {
  SharedSoLoudPianoPool._();

  static final SharedSoLoudPianoPool instance = SharedSoLoudPianoPool._();

  static const String _unlockNote = 'C4';

  final SoLoud _soLoud = SoLoud.instance;
  final Map<String, AudioSource> _sourcesByNote = <String, AudioSource>{};

  Future<void>? _playableTask;
  Future<void>? _fullLoadTask;

  /// 已可弹奏（至少解锁音 + SoLoud 已初始化）。
  bool get isPlayable =>
      !kIsWeb &&
      _soLoud.isInitialized &&
      _sourcesByNote.containsKey(_unlockNote);

  /// 虚拟钢琴全键盘 + 目录内额外音（如 C7）均已加载。
  bool get isLoaded =>
      _sourcesByNote.length >= kMusicCompanionPianoAssetByNote.length;

  AudioSource? sourceForNote(String note) => _sourcesByNote[note];

  /// 音乐伴侣进页：快速可弹，不等待 60+ wav 全部进内存。
  Future<void> ensurePlayable() {
    return _playableTask ??= _loadPlayable();
  }

  /// 智能听写等：需要完整音源表时调用。
  Future<void> ensureLoaded() {
    return _fullLoadTask ??= _loadAllNotes();
  }

  /// 单键懒加载（后台批量尚未完成时）。
  Future<void> ensureNote(String note) async {
    await ensurePlayable();
    if (_sourcesByNote.containsKey(note)) {
      return;
    }
    await _loadNote(note);
  }

  Future<void> _loadPlayable() async {
    try {
      await _ensureSoLoudInitialized();
      if (!_sourcesByNote.containsKey(_unlockNote)) {
        await _loadNote(_unlockNote);
      }
      unawaited(ensureLoaded());
    } catch (error, stack) {
      _playableTask = null;
      debugPrint('SharedSoLoudPianoPool.ensurePlayable failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _loadAllNotes() async {
    try {
      await _loadAllNotesImpl().timeout(const Duration(seconds: 180));
    } catch (error, stack) {
      _fullLoadTask = null;
      debugPrint('SharedSoLoudPianoPool.ensureLoaded failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _ensureSoLoudInitialized() async {
    await NativePlaybackAudioSession.ensurePlaybackActive();
    if (!_soLoud.isInitialized) {
      await _soLoud.init(
        sampleRate: 44100,
        bufferSize: 2048,
        channels: Channels.stereo,
      );
    }
    _soLoud.setMaxActiveVoiceCount(256);
  }

  Future<void> _loadAllNotesImpl() async {
    await _ensureSoLoudInitialized();

    final pending = kMusicCompanionPianoAssetByNote.entries
        .where((entry) => !_sourcesByNote.containsKey(entry.key))
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }

    final batchSize = defaultTargetPlatform == TargetPlatform.iOS ? 1 : 4;
    for (var i = 0; i < pending.length; i += batchSize) {
      final batch = pending.skip(i).take(batchSize);
      if (batchSize == 1) {
        for (final entry in batch) {
          await _loadNote(entry.key);
        }
      } else {
        await Future.wait(batch.map((entry) => _loadNote(entry.key)));
      }
    }
  }

  Future<void> _loadNote(String note) async {
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null || _sourcesByNote.containsKey(note)) {
      return;
    }
    final source = await _soLoud
        .loadAsset(asset, mode: LoadMode.memory)
        .timeout(const Duration(seconds: 30));
    _sourcesByNote[note] = source;
  }

  /// 在用户点击的**同一调用栈**内同步发声（iOS 必须，不能先 await 再 play）。
  bool tryPlayNote(String note, {double volume = 1}) {
    if (kIsWeb || !_soLoud.isInitialized) {
      return false;
    }
    final source = _sourcesByNote[note];
    if (source == null) {
      return false;
    }
    try {
      _soLoud.play(source, volume: volume);
      return true;
    } catch (error, stack) {
      debugPrint('SharedSoLoudPianoPool.tryPlayNote($note): $error\n$stack');
      return false;
    }
  }

  /// 手势链上的解锁：同步播放极轻音，不 await stop。
  bool tryUnlockProbe({String probeNote = _unlockNote}) {
    return tryPlayNote(probeNote, volume: 0.02);
  }
}

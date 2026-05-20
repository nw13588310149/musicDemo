import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_catalog.dart';

/// 全应用唯一的 SoLoud 钢琴音源池（页面退出不销毁 wav）。
///
/// iPad 冷启动稳健性（相对 commit c3f7d2e 稳定版）：
/// • [ensurePlayable] 只做 init + 解锁音 C4，供启动预热 / 进页快速可弹。
/// • **不在** [ensurePlayable] 内触发全量加载——05b4715 曾在此
///   `unawaited(ensureLoaded())`，与 C4 加载并发打 flutter_soloud 原生层，
///   iPad 冷启动即闪退。
/// • 全量 wav 仅在用户进入音乐伴侣等页面时，由 [ensureLoaded] 串行拉取。
/// • 所有 SoLoud 原生调用经 [_enqueue] 串行，避免 loadAsset 竞态。
class SharedSoLoudPianoPool {
  SharedSoLoudPianoPool._();

  static final SharedSoLoudPianoPool instance = SharedSoLoudPianoPool._();

  static const String _unlockNote = 'C4';

  final SoLoud _soLoud = SoLoud.instance;
  final Map<String, AudioSource> _sourcesByNote = <String, AudioSource>{};

  Future<void>? _playableTask;
  Future<void>? _fullLoadTask;

  /// SoLoud 原生 API 串行队列（init / loadAsset 不可并发）。
  Future<void> _nativeQueue = Future<void>.value();

  /// 已可弹奏（至少解锁音 + SoLoud 已初始化）。
  bool get isPlayable =>
      !kIsWeb &&
      _soLoud.isInitialized &&
      _sourcesByNote.containsKey(_unlockNote);

  /// 虚拟钢琴全键盘 + 目录内额外音（如 C7）均已加载。
  bool get isLoaded =>
      _sourcesByNote.length >= kMusicCompanionPianoAssetByNote.length;

  AudioSource? sourceForNote(String note) => _sourcesByNote[note];

  /// 启动预热 / 进页：快速可弹，不拉全量 wav。
  Future<void> ensurePlayable() {
    return _playableTask ??= _loadPlayable();
  }

  /// 智能听写 / 音乐伴侣进页后：后台串行加载剩余音源。
  Future<void> ensureLoaded() {
    return _fullLoadTask ??= _loadAllNotes();
  }

  /// 单键懒加载（全量批量尚未完成时）。
  Future<void> ensureNote(String note) async {
    await ensurePlayable();
    if (_sourcesByNote.containsKey(note)) {
      return;
    }
    await _enqueue(() => _loadNoteImpl(note));
  }

  Future<void> _loadPlayable() async {
    try {
      await _enqueue(_ensureSoLoudInitializedImpl);
      if (!_sourcesByNote.containsKey(_unlockNote)) {
        await _enqueue(() => _loadNoteImpl(_unlockNote));
      }
      // 注意：此处 deliberately 不触发 ensureLoaded()。
      // 全量加载交给 MusicCompanionAudioEngine.ensurePianoInitialized。
    } catch (error, stack) {
      _playableTask = null;
      debugPrint('SharedSoLoudPianoPool.ensurePlayable failed: $error\n$stack');
      rethrow;
    }
  }

  Future<void> _loadAllNotes() async {
    try {
      await _enqueue(
        () => _loadAllNotesImpl().timeout(const Duration(seconds: 180)),
      );
    } catch (error, stack) {
      _fullLoadTask = null;
      debugPrint('SharedSoLoudPianoPool.ensureLoaded failed: $error\n$stack');
      rethrow;
    }
  }

  /// 把 fn 排进 SoLoud 原生调用队列，保证同一时刻只有一个 init/load 在执行。
  Future<T> _enqueue<T>(Future<T> Function() fn) {
    final task = _nativeQueue.then((_) => fn());
    _nativeQueue = task.then((_) {}, onError: (_) {});
    return task;
  }

  Future<void> _ensureSoLoudInitializedImpl() async {
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
    await _ensureSoLoudInitializedImpl();

    final pending = kMusicCompanionPianoAssetByNote.entries
        .where((entry) => !_sourcesByNote.containsKey(entry.key))
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }

    // iOS：严格串行 loadAsset（与 c3f7d2e 稳定版一致，避免并发 native 崩溃）。
    for (final entry in pending) {
      await _loadNoteImpl(entry.key);
    }
  }

  Future<void> _loadNoteImpl(String note) async {
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

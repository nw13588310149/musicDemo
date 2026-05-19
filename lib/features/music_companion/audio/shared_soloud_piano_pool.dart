import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'music_companion_audio_catalog.dart';

/// 全应用唯一的 SoLoud 钢琴音源池。
///
/// iPad 上「音乐伴侣 / musicPlay / 智能听写」各自 new 一个
/// [MusicCompanionAudioEngine] 或 [SmartDictationAudioEngine]，却共用
/// [SoLoud.instance]。若页面 dispose 时 `disposeSource` 钢琴采样，其它
/// 页面持有的 [AudioSource] 会立刻失效，表现为：
/// - 刚进音乐伴侣：初始化失败；
/// - 偶尔弹奏：音频尚未解锁 / 无声。
///
/// 钢琴 wav 只在此池里加载一次，页面退出时仅 stop 正在播放的 voice，
/// 不在页面生命周期内销毁音源。
class SharedSoLoudPianoPool {
  SharedSoLoudPianoPool._();

  static final SharedSoLoudPianoPool instance = SharedSoLoudPianoPool._();

  final SoLoud _soLoud = SoLoud.instance;
  final Map<String, AudioSource> _sourcesByNote = <String, AudioSource>{};

  Future<void>? _loadTask;
  bool _gestureUnlocked = false;

  bool get isLoaded => _sourcesByNote.isNotEmpty;

  AudioSource? sourceForNote(String note) => _sourcesByNote[note];

  Future<void> ensureLoaded() {
    return _loadTask ??= _loadAllNotes();
  }

  Future<void> _loadAllNotes() async {
    try {
      if (!_soLoud.isInitialized) {
        await _soLoud.init();
      }
      _soLoud.setMaxActiveVoiceCount(256);

      if (_sourcesByNote.isNotEmpty) {
        return;
      }

      for (final entry in kMusicCompanionPianoAssetByNote.entries) {
        final source = await _soLoud.loadAsset(
          entry.value,
          mode: LoadMode.memory,
        );
        _sourcesByNote[entry.key] = source;
      }
    } catch (error, stack) {
      _loadTask = null;
      debugPrint('SharedSoLoudPianoPool.ensureLoaded failed: $error\n$stack');
      rethrow;
    }
  }

  /// iOS 要求在用户手势回调链上有一次实际播放，后续按键才稳定出声。
  Future<void> unlockByUserGesture() async {
    if (kIsWeb || _gestureUnlocked) {
      return;
    }
    await ensureLoaded();
    if (!_soLoud.isInitialized || _sourcesByNote.isEmpty) {
      return;
    }
    try {
      final probe = _sourcesByNote.values.first;
      final handle = _soLoud.play(probe, volume: 0.0001);
      if (_soLoud.getIsValidVoiceHandle(handle)) {
        await _soLoud.stop(handle);
      }
      _gestureUnlocked = true;
    } catch (error, stack) {
      debugPrint('SharedSoLoudPianoPool.unlockByUserGesture failed: $error\n$stack');
      rethrow;
    }
  }

  void resetGestureUnlock() {
    _gestureUnlocked = false;
  }
}

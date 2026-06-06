import 'dart:async';

import 'package:flutter/foundation.dart';

import 'low_latency_note_player.dart';
import 'native_piano_handoff.dart';
import 'native_playback_audio_session.dart';

/// 全应用 iOS 音频统一协调器（彻底重构版）。
///
/// 职责收敛：
/// 1. **唯一**原生短音频播放器实例（钢琴 / 节拍器 / 听写共用同一 AVAudioEngine）。
/// 2. **唯一**对外会话入口：按键前 [prepareForPianoKeypress] 强制 reconcile playback
///    （对抗 media_kit 把 mode 改成 moviePlayback）。
/// 3. 重操作（prepare / 整表预热）走 [NativePianoHandoff]；发声走 fire-and-forget，
///    不再在按键路径上 await reclaim / handoff。
abstract final class AppAudioService {
  static final LowLatencyNotePlayer _player = createLowLatencyNotePlayer();

  /// 全应用共享的原生短音频播放器（禁止各页面 new 自己的实例）。
  static LowLatencyNotePlayer get sharedNativePlayer => _player;

  static bool _pianoCoreWarmed = false;
  static Future<void>? _pianoWarmTask;

  static bool get isNativePianoReady => _player.isReady;

  // ── 会话 ──────────────────────────────────────────────────────────

  /// 强制把 AVAudioSession 拉回 playback/default（幂等，无缓存短路）。
  /// media_kit 播放后须调用；钢琴按键前亦会调用。
  static Future<void> reconcilePlaybackSession() {
    if (kIsWeb) return Future<void>.value();
    return NativePlaybackAudioSession.reconcilePlayback();
  }

  /// 录音 / 调音器 / 视唱采集。
  static Future<void> enterRecordSession() =>
      NativePlaybackAudioSession.ensureRecordActive();

  static Future<void> enterMeasurementSession() =>
      NativePlaybackAudioSession.ensurePlayAndRecordActive();

  static Future<void> enterSightSingingCapture({bool soft = false}) {
    if (soft) {
      return NativePlaybackAudioSession.ensureSightSingingCaptureActiveSoft();
    }
    return NativePlaybackAudioSession.ensureSightSingingCaptureActive();
  }

  // ── 钢琴热路径 ────────────────────────────────────────────────────

  /// 按键 / 测试音前：reconcile 会话 + 确保引擎 ping + 中央音区已 prepare。
  /// 不含 reclaim 整链 handoff，避免 operationGeneration 丢弃排队音符。
  static Future<void> prepareForPianoKeypress() async {
    if (kIsWeb) return;
    await reconcilePlaybackSession();
    await _player.pingEngine();
    if (!_pianoCoreWarmed) {
      await warmupPianoCore();
    }
  }

  /// 用户手势栈内同步发声（fire-and-forget，不 await MethodChannel）。
  static bool playPianoFromGesture(
    String note, {
    double volume = 1,
    bool metronome = false,
  }) {
    if (kIsWeb || !_player.isReady) return false;
    return _player.tryPlay(note, volume: volume, metronome: metronome);
  }

  /// 后台预热中央音区；页面进入时调用，不阻塞 UI。
  static Future<void> warmupPianoCore() {
    return _pianoWarmTask ??= _runWarmPianoCore();
  }

  static Future<void> _runWarmPianoCore() async {
    if (kIsWeb) return;
    try {
      await NativePianoHandoff.run(() async {
        await reconcilePlaybackSession();
        if (!_player.isReady) {
          // 由具体引擎在 enter 时传入 asset map；此处仅 ping。
          await _player.pingEngine();
        }
      });
      _pianoCoreWarmed = _player.isReady;
    } catch (error, stack) {
      _pianoWarmTask = null;
      debugPrint('AppAudioService.warmupPianoCore failed: $error\n$stack');
    }
  }

  /// 页面进入：会话 + handoff prepare（由引擎提供 asset map）。
  static Future<void> enterPianoPage({
    required Future<void> Function() prepareAssets,
    bool invalidateSession = false,
  }) async {
    if (kIsWeb) {
      await prepareAssets();
      return;
    }
    await NativePianoHandoff.run(() async {
      if (invalidateSession) {
        NativePlaybackAudioSession.invalidatePlaybackCache();
      }
      await reconcilePlaybackSession();
      await prepareAssets();
      await _player.pingEngine();
      _pianoCoreWarmed = _player.isReady;
    });
  }

  /// musicPlay：长音频已 open，软 reconcile + ping（不 invalidate）。
  static Future<void> recoverPianoAfterMediaKit({
    required Future<void> Function() ensurePrepared,
  }) async {
    if (kIsWeb) {
      await ensurePrepared();
      return;
    }
    await NativePianoHandoff.run(() async {
      await reconcilePlaybackSession();
      await _player.pingEngine();
      if (!_player.isReady) {
        await ensurePrepared();
      }
      _pianoCoreWarmed = _player.isReady;
    });
  }

  /// 离开带钢琴的页面：停短音；下一页 enter 时 reconcile。
  static Future<void> leavePianoPage() async {
    await _player.stopAll();
    _pianoWarmTask = null;
    _pianoCoreWarmed = false;
    if (!kIsWeb) {
      NativePlaybackAudioSession.invalidatePlaybackCache();
    }
  }

  /// 类别从 playAndRecord 回到 playback（视唱 / 调音器离开）。
  static Future<void> restorePlaybackAfterCapture({
    required Future<void> Function() ensurePrepared,
  }) async {
    if (kIsWeb) {
      await ensurePrepared();
      return;
    }
    await NativePianoHandoff.run(() async {
      await reconcilePlaybackSession();
      await _player.pingEngine();
      await ensurePrepared();
      _pianoCoreWarmed = _player.isReady;
    });
  }

  static Future<Map<String, Object?>> diagnostics() => _player.diagnostics();

  static void registerDebugEngine(Object? engine) {
    // 由 MusicCompanionAudioEngine 构造时注册，供诊断面板读取。
    _debugEngine = engine;
  }

  static Object? _debugEngine;
  static Object? get debugEngine => _debugEngine;
}

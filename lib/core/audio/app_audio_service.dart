import 'dart:async';

import 'package:flutter/foundation.dart';

import 'low_latency_note_player.dart';
import 'native_piano_handoff.dart';
import 'native_playback_audio_session.dart';

/// 全应用 iOS 音频统一协调器。
abstract final class AppAudioService {
  static final LowLatencyNotePlayer _player = createLowLatencyNotePlayer();

  static LowLatencyNotePlayer get sharedNativePlayer => _player;

  static bool _pianoCoreWarmed = false;
  static Future<void>? _pianoWarmTask;
  static DateTime? _lastReconcileAt;
  static const Duration _reconcileMinInterval = Duration(milliseconds: 350);

  static bool get isNativePianoReady => _player.isReady;

  static Future<void> reconcilePlaybackSession() {
    if (kIsWeb) return Future<void>.value();
    _lastReconcileAt = DateTime.now();
    return NativePlaybackAudioSession.reconcilePlayback();
  }

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

  /// 按键前准备。已预热时仅 ping（快）；否则完整 reconcile。
  static Future<void> prepareForPianoKeypress({bool force = false}) async {
    if (kIsWeb) return;

    if (!force && _pianoCoreWarmed && _player.isReady) {
      unawaited(_reconcileIfDue());
      await _player.pingEngine();
      return;
    }

    await reconcilePlaybackSession();
    await _player.pingEngine();
    if (!_pianoCoreWarmed || !_player.isReady) {
      await warmupPianoCore();
    }
  }

  static Future<void> _reconcileIfDue() async {
    final last = _lastReconcileAt;
    if (last != null &&
        DateTime.now().difference(last) < _reconcileMinInterval) {
      return;
    }
    try {
      await reconcilePlaybackSession();
    } catch (_) {}
  }

  static bool playPianoFromGesture(
    String note, {
    double volume = 1,
    bool metronome = false,
  }) {
    if (kIsWeb || !_player.isReady) return false;
    return _player.tryPlay(note, volume: volume, metronome: metronome);
  }

  static Future<void> warmupPianoCore() {
    return _pianoWarmTask ??= _runWarmPianoCore();
  }

  static Future<void> _runWarmPianoCore() async {
    if (kIsWeb) return;
    try {
      await NativePianoHandoff.run(() async {
        await reconcilePlaybackSession();
        await _player.pingEngine();
      });
      _pianoCoreWarmed = _player.isReady;
    } catch (error, stack) {
      _pianoWarmTask = null;
      debugPrint('AppAudioService.warmupPianoCore failed: $error\n$stack');
    }
  }

  static Future<void> enterPianoPage({
    required Future<void> Function() prepareAssets,
    bool invalidateSession = false,
  }) async {
    if (kIsWeb) {
      await prepareAssets();
      return;
    }
    // 已有缓冲：轻量恢复，避免从 musicPlay 返回时数秒 handoff。
    if (_player.isReady && _pianoCoreWarmed && !invalidateSession) {
      await reconcilePlaybackSession();
      await _player.pingEngine();
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

  static Future<void> recoverPianoAfterMediaKit({
    required Future<void> Function() ensurePrepared,
  }) async {
    if (kIsWeb) {
      await ensurePrepared();
      return;
    }
    if (_player.isReady && _pianoCoreWarmed) {
      await reconcilePlaybackSession();
      await _player.pingEngine();
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

  /// 离开页面：停短音，保留原生缓冲与 warm 状态。
  static Future<void> onPageLeave() async {
    await _player.stopAll();
    if (!kIsWeb) {
      unawaited(_reconcileIfDue());
    }
  }

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
    _debugEngine = engine;
  }

  static Object? _debugEngine;
  static Object? get debugEngine => _debugEngine;

  /// 首次 prepare 成功后由引擎调用。
  static void markPianoCoreWarmed() {
    _pianoCoreWarmed = true;
  }
}

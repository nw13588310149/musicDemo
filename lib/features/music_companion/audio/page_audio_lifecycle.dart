import 'package:flutter/foundation.dart';

import '../../../core/audio/native_audio_bootstrap.dart';
import '../../../core/audio/native_piano_handoff.dart';
import '../../../core/audio/native_playback_audio_session.dart';
import 'music_companion_audio_engine.dart';

/// 以「页面进入 / 离开」为边界的音频生命周期（iOS 钢琴 + AVAudioSession）。
///
/// 原则：
/// - **进入页**：配置本会话 + 一次 handoff（prepare / reclaim）。
/// - **离开页**：停短音 + 标记共享原生图 stale（不在此 reclaim，交给下一页 enter）。
/// - **页内**：长音频与钢琴混播用 [recoverPianoDuringMediaKit]，勿反复 setActive(false)。
abstract final class PageAudioLifecycle {
  /// 音乐伴侣：playback + 钢琴（完整 handoff）。
  static Future<void> enterPlaybackPiano(MusicCompanionAudioEngine engine) {
    return MusicCompanionAudioEngine.primeAfterForeignAudioSession(engine);
  }

  /// 智能听写等使用独立 [MusicCompanionAudioEngine] 以外引擎时的进入逻辑。
  static Future<void> enterPlaybackPianoNative({
    required Future<void> Function() prepareEngine,
  }) {
    if (kIsWeb) {
      return prepareEngine();
    }
    return NativePianoHandoff.run(() async {
      NativePlaybackAudioSession.invalidatePlaybackCache();
      await NativePlaybackAudioSession.ensurePlaybackActive();
      await prepareEngine();
      NativePlaybackAudioSession.markNativePianoGraphFresh();
    });
  }

  /// musicPlay 首次进入：media_kit 会话 + 钢琴（可强释放旧会话）。
  static Future<void> enterMediaKitPiano(
    MusicCompanionAudioEngine engine, {
    bool forceSessionRelease = true,
  }) {
    if (kIsWeb) {
      return engine.ensurePianoInitialized();
    }
    return NativePianoHandoff.run(() async {
      if (forceSessionRelease) {
        NativePlaybackAudioSession.invalidatePlaybackCache();
      }
      await NativePlaybackAudioSession.ensureMediaKitPlaybackActive(
        releaseOthersFirst: forceSessionRelease,
      );
      await engine.reclaimNativeGraphAfterSessionChange();
      if (!engine.isPianoReady) {
        await engine.ensurePianoInitialized();
      }
    });
  }

  /// musicPlay 长音频已 open：软会话 + reclaim，不掐 mpv。
  static Future<void> recoverPianoDuringMediaKit(
    MusicCompanionAudioEngine engine,
  ) {
    return MusicCompanionAudioEngine.recoverNativePianoAfterMediaKit(
      engine,
      softMediaKitSession: true,
    );
  }

  /// 按键 / 开曲前：图 stale 或引擎未 prepare 时做一次 enter。
  static Future<void> ensurePianoReady(MusicCompanionAudioEngine engine) async {
    if (kIsWeb) {
      if (!engine.isPianoReady) {
        await engine.ensurePianoInitialized();
      }
      return;
    }
    if (NativePlaybackAudioSession.nativePianoGraphNeedsReclaim ||
        !engine.isPianoReady) {
      await enterPlaybackPiano(engine);
    }
  }

  /// 离开带钢琴/节拍器/听写短音的页面（引擎 dispose 前或后均可调 stopAll）。
  static Future<void> leavePage({MusicCompanionAudioEngine? pianoEngine}) async {
    if (pianoEngine != null) {
      await pianoEngine.stopAll();
    }
    if (kIsWeb) {
      return;
    }
    NativePlaybackAudioSession.markNativePianoGraphStale();
    NativePlaybackAudioSession.invalidatePlaybackCache();
  }

  /// 离开智能视唱：恢复 playback，标记钢琴图待下一页 handoff。
  static Future<void> leaveSightSinging() async {
    if (kIsWeb) {
      return;
    }
    await NativeAudioBootstrap.reactivatePlaybackSession();
    NativePlaybackAudioSession.markNativePianoGraphStale();
  }

  /// 智能视唱跟唱 / 试听采集。
  static Future<void> enterSightSingingCapture({bool soft = false}) async {
    if (kIsWeb) {
      return;
    }
    if (soft) {
      await NativePlaybackAudioSession.ensureSightSingingCaptureActiveSoft();
    } else {
      await NativePlaybackAudioSession.ensureSightSingingCaptureActive();
    }
  }

  /// 音乐伴侣调音器 tab。
  static Future<void> enterTuner() {
    return NativePlaybackAudioSession.ensurePlayAndRecordActive();
  }

  /// 调音器 tab 切回钢琴 / 节拍器。
  static Future<void> leaveTunerToPlaybackPiano(
    MusicCompanionAudioEngine engine,
  ) async {
    if (kIsWeb) {
      return;
    }
    await NativePlaybackAudioSession.ensurePlaybackActive();
    await engine.reclaimNativeGraphAfterSessionChange();
  }
}

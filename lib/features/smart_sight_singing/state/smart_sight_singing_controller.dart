import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../audio/pitch_analysis.dart';
import '../audio/realtime_pitch_capture.dart';
import 'smart_sight_singing_state.dart';

final smartSightSingingControllerProvider =
    StateNotifierProvider.autoDispose<
      SmartSightSingingController,
      SightSingingState
    >((ref) {
      final ctrl = SmartSightSingingController();
      ref.onDispose(ctrl.shutdown);
      return ctrl;
    });

class SmartSightSingingController extends StateNotifier<SightSingingState> {
  SmartSightSingingController() : super(const SightSingingState()) {
    _player = Player();
    _positionSub = _player.stream.position.listen(_onPlaybackPosition);
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_handlePlaybackEnded());
      }
    });
  }

  late final Player _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<RealtimePitchEvent>? _pitchSub;
  RealtimePitchCapture? _capture;

  /// 用户实时音高点的最大保留数（用于 KTV 拖尾绘制 + 内存上限）。
  static const int _userPointsCap = 720;

  bool _shuttingDown = false;

  /// 选择并导入本地 MP3（也支持 m4a/wav/aac），离线分析音高。
  Future<void> importAudio() async {
    if (state.stage == SightSingingStage.analyzing ||
        state.stage == SightSingingStage.singing) {
      return;
    }

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: '选择音频失败：$e');
      return;
    }
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final picked0 = picked.files.first;
    final localPath = picked0.path;
    final Uint8List? bytes = picked0.bytes;
    if (localPath == null && bytes == null) {
      state = state.copyWith(errorMessage: '无法读取所选音频文件');
      return;
    }

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: localPath,
      audioName: picked0.name,
      analyzingProgress: 0.05,
      track: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    // 解码 + 切帧 + YIN（在 isolate 中）。
    try {
      final track = localPath != null
          ? await SightSingingPitchAnalyzer.analyzeFile(localPath)
          : await SightSingingPitchAnalyzer.analyzeBytes(
              bytes!,
              formatHint: _inferExt(picked0.name),
            );
      if (!mounted) return;
      if (track.isEmpty) {
        state = state.copyWith(
          stage: SightSingingStage.idle,
          errorMessage: '音频时长过短或无法识别有效音高，请尝试其他歌曲。',
          analyzingProgress: 0,
        );
        return;
      }
      state = state.copyWith(
        stage: SightSingingStage.ready,
        analyzingProgress: 1,
        track: track,
      );

      // 准备 media_kit 播放器（不自动播放）。
      try {
        await _player.open(Media(localPath ?? picked0.identifier ?? ''),
            play: false);
      } catch (e) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: '音频加载失败：$e');
      }
    } on PitchAnalysisException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: e.message,
        analyzingProgress: 0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: '分析失败：$e',
        analyzingProgress: 0,
      );
    }
  }

  /// 开始跟唱：开启录音 + 实时音高，并播放 MP3。
  Future<void> startSinging() async {
    if (state.stage != SightSingingStage.ready &&
        state.stage != SightSingingStage.finished) {
      return;
    }
    if (state.track == null) return;

    final capture = createRealtimePitchCapture();
    _capture = capture;
    try {
      final hasPermission = await capture.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: '请先在系统设置中开启麦克风权限。');
        return;
      }
      final pitchStream = await capture.start();
      _pitchSub = pitchStream.listen(_onUserPitch, onError: (Object e, _) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: '录音异常：$e');
      });
    } catch (e) {
      _capture = null;
      if (!mounted) return;
      state = state.copyWith(errorMessage: '麦克风启动失败：$e');
      return;
    }

    if (!mounted) {
      await capture.stop();
      return;
    }

    state = state.copyWith(
      stage: SightSingingStage.singing,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (e) {
      await _stopCaptureSilently();
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        errorMessage: '音频播放失败：$e',
      );
    }
  }

  /// 提前停止跟唱（用户手动结束）。
  Future<void> stopSinging({bool reset = false}) async {
    if (state.stage != SightSingingStage.singing) return;
    await _stopCaptureSilently();
    try {
      await _player.pause();
    } catch (_) {}
    if (!mounted) return;
    state = state.copyWith(
      stage: reset ? SightSingingStage.ready : SightSingingStage.finished,
    );
  }

  void dismissError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(errorMessage: null);
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    await _stopCaptureSilently();
    await _positionSub?.cancel();
    await _completedSub?.cancel();
    _positionSub = null;
    _completedSub = null;
    try {
      await _player.dispose();
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────────
  // internals
  // ───────────────────────────────────────────────────────────────────────

  void _onPlaybackPosition(Duration position) {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing) return;
    state = state.copyWith(playbackMs: position.inMilliseconds);
  }

  Future<void> _handlePlaybackEnded() async {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing) return;
    await _stopCaptureSilently();
    if (!mounted) return;
    state = state.copyWith(stage: SightSingingStage.finished);
  }

  void _onUserPitch(RealtimePitchEvent event) {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing) return;

    final track = state.track;
    final timeMs = state.playbackMs;
    final refFrame = track?.sampleAt(timeMs);
    double cents = double.nan;
    int newScore = state.currentScore;
    int newHits = state.hitCount;
    int newScored = state.scoredCount;
    if (refFrame != null && event.pitched) {
      cents = (event.midi - refFrame.midi) * 100;
      newScored += 1;
      final absCents = cents.abs();
      // 评分窗口：≤ 50 cents 命中；50~100 半分；> 100 不计分。
      if (absCents <= 50) {
        newHits += 1;
      }
      final framePoints = absCents <= 50
          ? 100
          : absCents <= 100
              ? 60
              : 0;
      // 滚动加权（最新帧权重 5%）。
      newScore = ((newScore * 0.95) + framePoints * 0.05).round().clamp(0, 100);
    }

    final newPoint = UserPitchPoint(
      timeMs: timeMs,
      midi: event.pitched ? event.midi : -1,
      amplitude: event.amplitude,
      cents: cents,
    );

    final next = List<UserPitchPoint>.from(state.userPoints)..add(newPoint);
    if (next.length > _userPointsCap) {
      next.removeRange(0, next.length - _userPointsCap);
    }

    state = state.copyWith(
      userPoints: next,
      currentUserMidi: event.pitched ? event.midi : -1,
      currentUserAmplitude: event.amplitude,
      currentScore: newScore,
      hitCount: newHits,
      scoredCount: newScored,
    );
  }

  Future<void> _stopCaptureSilently() async {
    await _pitchSub?.cancel();
    _pitchSub = null;
    try {
      await _capture?.stop();
    } catch (_) {}
    _capture = null;
  }

  String _inferExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return 'mp3';
    return name.substring(dot + 1).toLowerCase();
  }
}


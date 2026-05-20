import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

  static const String _demoAssetPath = 'assets/audio/demo.mp3';
  static const String _demoDisplayName = '青花';
  static const String _demoMediaUri = 'asset:///assets/audio/demo.mp3';
  static const int _maxOnlineAudioBytes = 50 * 1024 * 1024;

  late final Player _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<RealtimePitchEvent>? _pitchSub;
  RealtimePitchCapture? _capture;

  /// 用户实时音高点的最大保留数（用于 KTV 拖尾绘制 + 内存上限）。
  static const int _userPointsCap = 720;

  bool _shuttingDown = false;

  /// 解析内置 demo 曲目《青花》，离线生成参考音高。
  Future<void> importAudio() async {
    if (state.stage == SightSingingStage.analyzing ||
        state.stage == SightSingingStage.singing) {
      return;
    }

    try {
      final bytes = await rootBundle.load(_demoAssetPath);
      await _analyzeBytesAndPreparePlayback(
        bytes: Uint8List.sublistView(bytes),
        formatHint: 'mp3',
        displayName: _demoDisplayName,
        mediaUri: _demoMediaUri,
      );
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
        errorMessage: '解析《青花》失败：$e',
        analyzingProgress: 0,
      );
    }
  }

  /// 下载并解析在线音频地址，随后用同一 URL 进行跟唱播放。
  Future<void> analyzeOnlineAudio(String rawUrl) async {
    if (state.stage == SightSingingStage.analyzing ||
        state.stage == SightSingingStage.singing) {
      return;
    }

    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      state = state.copyWith(errorMessage: '请输入有效的 http/https 音频地址。');
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      state = state.copyWith(errorMessage: '在线音频地址仅支持 http/https。');
      return;
    }

    final displayName = _nameFromUri(uri);
    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: url,
      audioName: displayName,
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

    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 45),
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      ).get<List<int>>(url);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw PitchAnalysisException('在线音频为空，请换一个地址试试。');
      }
      if (data.length > _maxOnlineAudioBytes) {
        throw PitchAnalysisException('在线音频过大，请使用 50MB 以内的音频。');
      }

      await _analyzeBytesAndPreparePlayback(
        bytes: Uint8List.fromList(data),
        formatHint: _inferExt(displayName),
        displayName: displayName,
        mediaUri: url,
      );
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
        errorMessage: '在线音频解析失败：$e',
        analyzingProgress: 0,
      );
    }
  }

  Future<void> _analyzeBytesAndPreparePlayback({
    required Uint8List bytes,
    required String formatHint,
    required String displayName,
    required String mediaUri,
  }) async {
    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: mediaUri,
      audioName: displayName,
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

    // 解码 + 切帧 + YIN。
    try {
      final track = await SightSingingPitchAnalyzer.analyzeBytes(
        bytes,
        formatHint: formatHint,
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
        await _player.open(Media(mediaUri), play: false);
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

  static String _nameFromUri(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(last).trim();
    return decoded.isEmpty ? '在线音频' : decoded;
  }

  static String _inferExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'mp3';
    return name.substring(dot + 1).toLowerCase();
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
}


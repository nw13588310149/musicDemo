import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import '../audio/ktv_scoring.dart';
import '../audio/midi_file_parser.dart';
import '../audio/midi_playback_scheduler.dart';
import '../audio/midi_sight_singing_service.dart';
import '../audio/pitch_voice_gate.dart';
import '../audio/realtime_pitch_capture.dart';
import '../data/midi_file_picker.dart';
import 'sight_singing_platform.dart';
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
  SmartSightSingingController()
      : super(
          SightSingingState(
            visualOnlyMode: SightSingingPlatform.defaultsToVisualOnlyMode,
          ),
        ) {
    _playback = MidiPlaybackScheduler();
    _playback.muteAudioOutput = SightSingingPlatform.defaultsToVisualOnlyMode;
    _positionSub = _playback.positionMs.listen(_onPlaybackPosition);
    _completedSub = _playback.completed.listen((_) {
      if (_isPreviewSession) {
        unawaited(_stopPreview());
        return;
      }
      unawaited(_handlePlaybackEnded());
    });
  }

  static const String _demoAssetPath = 'assets/audio/demo.mid';
  static const String _demoDisplayName = 'demo';
  static const int _maxOnlineMidiBytes = 8 * 1024 * 1024;
  static const int _countdownStart = 3;

  late final MidiPlaybackScheduler _playback;
  StreamSubscription<int>? _positionSub;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<RealtimePitchEvent>? _pitchSub;
  RealtimePitchCapture? _capture;
  KtvScoringSession? _scoringSession;
  MidiSightSingingBundle? _midiBundle;
  ParsedMidiFile? _parsedMidi;
  Timer? _countdownTimer;
  Timer? _previewTimer;
  var _isPreviewSession = false;

  static const int _previewMaxMs = 20000;

  static const int _userPointsCap = 720;
  bool _shuttingDown = false;

  static String _formatDebugError(
    String headline,
    Object error, [
    StackTrace? stack,
  ]) {
    final buffer = StringBuffer(headline);
    buffer.writeln();
    buffer.writeln('错误: $error');
    if (stack != null) {
      buffer.writeln();
      buffer.writeln('Stack trace:');
      buffer.write(stack);
    }
    return buffer.toString();
  }

  void reportError(String message) {
    if (!mounted) return;
    state = state.copyWith(errorMessage: message);
  }

  /// 从本地文件系统选择 MIDI 并解析。
  Future<void> importLocalMidi() async {
    if (_blocksImport()) return;

    try {
      final picked = await pickLocalMidiFile();
      if (picked == null) return;
      await _prepareFromMidiBytes(
        bytes: picked.bytes,
        displayName: picked.name,
        sourceLabel: picked.path ?? picked.name,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: e.message);
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MIDI 解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MIDI 读取失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  /// 解析内置 demo.mid，进入选轨界面（曲目名 demo）。
  Future<void> importAudio() async {
    if (_blocksImport()) return;

    try {
      final bytes = await rootBundle.load(_demoAssetPath);
      await _prepareFromMidiBytes(
        bytes: Uint8List.sublistView(bytes),
        displayName: _demoDisplayName,
        sourceLabel: _demoAssetPath,
      );
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('解析 demo MIDI 失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('解析 demo 失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  /// 下载并解析在线 MIDI 地址。
  Future<void> analyzeOnlineAudio(String rawUrl) async {
    if (_blocksImport()) return;

    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      state = state.copyWith(errorMessage: '请输入有效的 http/https MIDI 地址。');
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      state = state.copyWith(errorMessage: '在线地址仅支持 http/https。');
      return;
    }

    final displayName = _nameFromUri(uri);
    final ext = _inferExt(displayName);
    if (ext != 'mid' && ext != 'midi') {
      state = state.copyWith(errorMessage: '在线解析仅支持 .mid / .midi 文件。');
      return;
    }

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: url,
      audioName: displayName,
      analyzingProgress: 0.05,
      track: null,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      melodyTrackIndex: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
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
        throw MidiSightSingingException('在线 MIDI 为空，请换一个地址试试。');
      }
      if (data.length > _maxOnlineMidiBytes) {
        throw MidiSightSingingException('在线 MIDI 过大，请使用 8MB 以内的文件。');
      }

      await _prepareFromMidiBytes(
        bytes: Uint8List.fromList(data),
        displayName: displayName,
        sourceLabel: url,
      );
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('在线 MIDI 解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('在线 MIDI 解析失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  Future<void> _prepareFromMidiBytes({
    required Uint8List bytes,
    required String displayName,
    required String sourceLabel,
  }) async {
    _parsedMidi = null;
    _midiBundle = null;
    await _playback.stop();

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: sourceLabel,
      audioName: displayName,
      analyzingProgress: 0.2,
      track: null,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      melodyTrackIndex: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    final preview = MidiSightSingingService.parsePreview(bytes);
    if (!mounted) return;

    _parsedMidi = preview.parsed;
    state = state.copyWith(
      stage: SightSingingStage.selectTrack,
      analyzingProgress: 1,
      trackSummaries: preview.summaries,
      selectedTrackIndex: preview.suggestedTrackIndex,
    );
  }

  void setSelectedTrack(int trackIndex) {
    if (state.stage != SightSingingStage.selectTrack) return;
    if (trackIndex < 1 || trackIndex > state.trackSummaries.length) return;
    state = state.copyWith(selectedTrackIndex: trackIndex);
  }

  /// 用户确认主旋律轨，生成参考轨并进入就绪状态。
  Future<void> confirmSelectedTrack() async {
    if (state.stage != SightSingingStage.selectTrack) return;
    final parsed = _parsedMidi;
    final trackIndex = state.selectedTrackIndex;
    if (parsed == null || trackIndex == null) return;

    MidiTrackSummary? summary;
    for (final s in state.trackSummaries) {
      if (s.trackIndex == trackIndex) {
        summary = s;
        break;
      }
    }
    if (summary == null || !summary.hasNotes) {
      state = state.copyWith(errorMessage: '请选择包含音符的轨道。');
      return;
    }

    try {
      final bundle = MidiSightSingingService.buildBundle(parsed, trackIndex);
      _midiBundle = bundle;
      await _playback.prepare(
        bundle.playbackEvents,
        totalMs: bundle.totalMs,
      );

      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        track: bundle.track,
        melodyTrackIndex: trackIndex,
        trackSummaries: const <MidiTrackSummary>[],
        selectedTrackIndex: null,
        playbackMs: 0,
        userPoints: const <UserPitchPoint>[],
        currentScore: 0,
        hitCount: 0,
        scoredCount: 0,
        combo: 0,
        currentUserMidi: -1,
        currentUserAmplitude: 0,
        errorMessage: null,
      );
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: _formatDebugError('构建参考轨失败', e.message, stack),
      );
    }
  }

  void cancelTrackSelection() {
    if (state.stage != SightSingingStage.selectTrack) return;
    _parsedMidi = null;
    state = state.copyWith(
      stage: SightSingingStage.idle,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      analyzingProgress: 0,
    );
  }

  void setVisualOnlyMode(bool enabled) {
    if (state.visualOnlyMode == enabled) return;
    _playback.muteAudioOutput = enabled;
    state = state.copyWith(visualOnlyMode: enabled);
  }

  /// iPad 无声模式下试听旋律（会短暂开启扬声器伴奏）。
  Future<void> previewMelody() async {
    if (state.stage != SightSingingStage.ready || _midiBundle == null) return;
    if (state.isPreviewPlaying) {
      await stopPreview();
      return;
    }

    final bundle = _midiBundle!;
    await _playback.stop();
    _isPreviewSession = true;
    _playback.muteAudioOutput = false;

    if (!kIsWeb) {
      await NativePlaybackAudioSession.ensurePlaybackActive();
    }

    await _playback.prepare(
      bundle.playbackEvents,
      totalMs: bundle.totalMs,
    );

    try {
      await _playback.start(muteAudio: false);
    } catch (e) {
      _isPreviewSession = false;
      _playback.muteAudioOutput = state.visualOnlyMode;
      if (!mounted) return;
      state = state.copyWith(errorMessage: '旋律试听失败：$e');
      return;
    }

    if (!mounted) return;
    state = state.copyWith(isPreviewPlaying: true, playbackMs: 0);

    _previewTimer?.cancel();
    final previewMs = bundle.totalMs < _previewMaxMs
        ? bundle.totalMs
        : _previewMaxMs;
    _previewTimer = Timer(Duration(milliseconds: previewMs), () {
      unawaited(_stopPreview());
    });
  }

  Future<void> stopPreview() async {
    if (!state.isPreviewPlaying && !_isPreviewSession) return;
    await _stopPreview();
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    _isPreviewSession = false;
    await _playback.stop();
    _playback.muteAudioOutput = state.visualOnlyMode;
    if (!kIsWeb) {
      NativePlaybackAudioSession.invalidatePlaybackCache();
      await NativePlaybackAudioSession.ensureSightSingingCaptureActive();
    }
    if (!mounted) return;
    state = state.copyWith(isPreviewPlaying: false, playbackMs: 0);
  }

  PitchVoiceGatePolicy get _voiceGatePolicy => state.visualOnlyMode
      ? PitchVoiceGate.visualOnly
      : PitchVoiceGate.withAccompaniment;

  RealtimePitchCaptureProfile get _captureProfile => state.visualOnlyMode
      ? RealtimePitchCaptureProfile.visualOnly
      : RealtimePitchCaptureProfile.sightSinging;

  Future<void> startSinging() async {
    if (state.stage != SightSingingStage.ready &&
        state.stage != SightSingingStage.finished) {
      return;
    }
    if (state.track == null || _midiBundle == null) return;

    if (state.isPreviewPlaying) {
      await stopPreview();
    }

    final capture = createRealtimePitchCapture(profile: _captureProfile);
    _capture = capture;
    try {
      var hasPermission = await capture.hasPermission();
      if (!hasPermission) {
        hasPermission = await capture.requestPermission();
      }
      if (!hasPermission) {
        _capture = null;
        if (!mounted) return;
        final status = await Permission.microphone.status;
        state = state.copyWith(
          errorMessage: status.isPermanentlyDenied
              ? '麦克风权限被拒绝，请在系统「设置 → 音乐之路 → 麦克风」中开启。'
              : '请允许麦克风权限后再开始跟唱。',
        );
        return;
      }

      if (!kIsWeb) {
        NativePlaybackAudioSession.invalidatePlaybackCache();
      }

      final pitchStream = await capture.start();
      _pitchSub = pitchStream.listen(_onUserPitch, onError: (Object e, _) {
        if (!mounted) return;
        state = state.copyWith(errorMessage: '录音异常：$e');
      });

      if (!state.visualOnlyMode) {
        unawaited(_warmupAccompanimentPlayback());
      }
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

    _scoringSession = KtvScoringSession(track: state.track!);
    _heldUserMidi = -1;
    _heldUserMidiUntilMs = 0;

    state = state.copyWith(
      stage: SightSingingStage.countdown,
      countdownSeconds: _countdownStart,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _shuttingDown) {
        timer.cancel();
        return;
      }
      if (state.stage != SightSingingStage.countdown) {
        timer.cancel();
        return;
      }
      if (state.countdownSeconds <= 1) {
        timer.cancel();
        unawaited(_beginSingingPlayback());
        return;
      }
      state = state.copyWith(countdownSeconds: state.countdownSeconds - 1);
    });
  }

  Future<void> _warmupAccompanimentPlayback() async {
    if (state.visualOnlyMode || _midiBundle == null || kIsWeb) return;
    try {
      await _playback.prepare(
        _midiBundle!.playbackEvents,
        totalMs: _midiBundle!.totalMs,
      );
      await _playback.warmupAudioEngine();
      await NativePlaybackAudioSession.ensureSightSingingCaptureActiveSoft();
    } catch (e) {
      debugPrint('SmartSightSinging warmup accompaniment failed: $e');
    }
  }

  Future<void> _beginSingingPlayback() async {
    if (!mounted || _shuttingDown) return;
    if (_midiBundle == null) return;

    state = state.copyWith(
      stage: SightSingingStage.singing,
      countdownSeconds: 0,
    );

    _playback.muteAudioOutput = state.visualOnlyMode;
    await _playback.prepare(
      _midiBundle!.playbackEvents,
      totalMs: _midiBundle!.totalMs,
    );
    try {
      await _playback.start(muteAudio: state.visualOnlyMode);
      if (!kIsWeb && !state.visualOnlyMode) {
        await NativePlaybackAudioSession.ensureSightSingingCaptureActiveSoft();
      }
    } catch (e) {
      await _stopCaptureSilently();
      _scoringSession = null;
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        errorMessage: 'MIDI 播放失败：$e',
      );
    }
  }

  Future<void> cancelCountdown() async {
    if (state.stage != SightSingingStage.countdown) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _scoringSession = null;
    await _stopCaptureSilently();
    if (!mounted) return;
    state = state.copyWith(
      stage: SightSingingStage.ready,
      countdownSeconds: 0,
    );
  }

  Future<void> stopSinging({bool reset = false}) async {
    if (state.stage != SightSingingStage.singing) return;
    final tick = _scoringSession?.finalize();
    _scoringSession = null;
    await _stopCaptureSilently();
    await _playback.pause();
    if (!mounted) return;
    state = state.copyWith(
      stage: reset ? SightSingingStage.ready : SightSingingStage.finished,
      currentScore: tick?.totalScore ?? state.currentScore,
      hitCount: tick?.hitCount ?? state.hitCount,
      scoredCount: tick?.scoredCount ?? state.scoredCount,
      combo: tick?.combo ?? state.combo,
    );
  }

  Future<void> returnToHome() async {
    if (state.stage == SightSingingStage.analyzing) {
      return;
    }
    if (state.stage == SightSingingStage.countdown) {
      await cancelCountdown();
      return;
    }
    if (state.stage == SightSingingStage.singing) {
      await stopSinging(reset: true);
      return;
    }
    if (state.stage == SightSingingStage.selectTrack) {
      cancelTrackSelection();
      return;
    }
    if (state.isPreviewPlaying) {
      await stopPreview();
    }
    await _playback.stop();
    if (!mounted) return;
    if (state.stage == SightSingingStage.finished) {
      state = state.copyWith(
        stage: SightSingingStage.ready,
        playbackMs: 0,
        userPoints: const <UserPitchPoint>[],
        currentScore: 0,
        hitCount: 0,
        scoredCount: 0,
        combo: 0,
        currentUserMidi: -1,
        currentUserAmplitude: 0,
      );
    }
  }

  void dismissError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(errorMessage: null);
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _previewTimer?.cancel();
    _previewTimer = null;
    _isPreviewSession = false;
    await _stopCaptureSilently();
    await _positionSub?.cancel();
    await _completedSub?.cancel();
    _positionSub = null;
    _completedSub = null;
    await _playback.dispose();
  }

  bool _blocksImport() {
    return state.stage == SightSingingStage.analyzing ||
        state.stage == SightSingingStage.singing ||
        state.stage == SightSingingStage.countdown;
  }

  static String _nameFromUri(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(last).trim();
    return decoded.isEmpty ? '在线 MIDI' : decoded;
  }

  static String _inferExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  void _onPlaybackPosition(int positionMs) {
    if (_shuttingDown || !mounted) return;
    if (_isPreviewSession) {
      state = state.copyWith(playbackMs: positionMs);
      return;
    }
    if (state.stage != SightSingingStage.singing) return;
    state = state.copyWith(playbackMs: positionMs);
  }

  Future<void> _handlePlaybackEnded() async {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing) return;
    final tick = _scoringSession?.finalize();
    _scoringSession = null;
    await _stopCaptureSilently();
    await _playback.stop();
    if (!mounted) return;
    state = state.copyWith(
      stage: SightSingingStage.finished,
      currentScore: tick?.totalScore ?? state.currentScore,
      hitCount: tick?.hitCount ?? state.hitCount,
      scoredCount: tick?.scoredCount ?? state.scoredCount,
      combo: tick?.combo ?? state.combo,
    );
  }

  double _heldUserMidi = -1;
  int _heldUserMidiUntilMs = 0;

  void _onUserPitch(RealtimePitchEvent event) {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing &&
        state.stage != SightSingingStage.countdown) {
      return;
    }

    final timeMs = state.playbackMs;
    final session = _scoringSession;
    if (session == null) return;

    final refFrame = state.track?.sampleAt(
      state.playbackMs - KtvScoringConfig.micLatencyMs,
    );
    final refMidi = refFrame?.pitched == true ? refFrame!.midi : null;
    final playbackMidi = _playback.activePlaybackPitch?.toDouble();
    final filtered = PitchVoiceGate.filterForScoring(
      event: event,
      refMidi: refMidi,
      playbackMidi: playbackMidi,
      policy: _voiceGatePolicy,
    );

    // UI / 绘制始终用原始检测结果；串音过滤仅作用于打分。
    var displayMidi =
        event.pitched && event.midi >= 0 ? event.midi : -1.0;
    if (displayMidi >= 0) {
      _heldUserMidi = displayMidi;
      _heldUserMidiUntilMs = timeMs + 220;
    } else if (_heldUserMidi >= 0 && timeMs <= _heldUserMidiUntilMs) {
      displayMidi = _heldUserMidi;
    }

    // 倒计时阶段只预热麦克风，不计分。
    if (state.stage == SightSingingStage.countdown) {
      state = state.copyWith(
        currentUserMidi: displayMidi >= 0 ? displayMidi : -1,
        currentUserAmplitude: event.amplitude,
      );
      return;
    }

    final tick = session.onPitch(playbackMs: timeMs, event: filtered);
    final cents = tick.cents;

    final newPoint = UserPitchPoint(
      timeMs: timeMs,
      midi: displayMidi >= 0 ? displayMidi : -1,
      amplitude: event.amplitude,
      cents: cents,
    );

    final next = List<UserPitchPoint>.from(state.userPoints)..add(newPoint);
    if (next.length > _userPointsCap) {
      next.removeRange(0, next.length - _userPointsCap);
    }

    state = state.copyWith(
      userPoints: next,
      currentUserMidi: displayMidi >= 0 ? displayMidi : -1,
      currentUserAmplitude: event.amplitude,
      currentScore: tick.totalScore,
      hitCount: tick.hitCount,
      scoredCount: tick.scoredCount,
      combo: tick.combo,
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

import 'package:flutter/foundation.dart';

import '../audio/midi_sight_singing_service.dart';
import '../audio/pitch_track.dart';

enum SightSingingStage {
  /// 初始：尚未导入音频。
  idle,

  /// 正在解码 + 离线分析音高。
  analyzing,

  /// 解析完成，等待用户选择主旋律轨。
  selectTrack,

  /// 分析完成，等待开始跟唱。
  ready,

  /// 跟唱前倒计时（3→2→1）。
  countdown,

  /// 正在跟唱（播放 + 录音）。
  singing,

  /// 演唱结束，等待用户重听 / 重唱。
  finished,
}

/// 演唱过程中沿时间轴累积的实测音高点（用于绘制 KTV 拖尾）。
class UserPitchPoint {
  const UserPitchPoint({
    required this.timeMs,
    required this.midi,
    required this.amplitude,
    required this.cents,
  });

  /// 相对曲目开始的时间（毫秒）。
  final int timeMs;

  /// 用户实测 MIDI。-1 表示无音高（静音/未达阈值）。
  final double midi;

  /// 该帧响度（0~1），UI 可作圆点大小映射。
  final double amplitude;

  /// 与参考音的偏离 cents；无参考音时为 `double.nan`。
  final double cents;

  bool get pitched => midi >= 0;
}

@immutable
class SightSingingState {
  const SightSingingState({
    this.stage = SightSingingStage.idle,
    this.audioPath,
    this.audioName,
    this.analyzingProgress = 0,
    this.errorMessage,
    this.track,
    this.trackSummaries = const <MidiTrackSummary>[],
    this.selectedTrackIndex,
    this.melodyTrackIndex,
    this.countdownSeconds = 0,
    this.playbackMs = 0,
    this.userPoints = const <UserPitchPoint>[],
    this.currentUserMidi = -1,
    this.currentUserAmplitude = 0,
    this.currentScore = 0,
    this.hitCount = 0,
    this.scoredCount = 0,
    this.combo = 0,
  });

  final SightSingingStage stage;

  /// 当前导入的音频路径（本地/缓存）。
  final String? audioPath;

  /// 用户友好的曲目名（取文件名）。
  final String? audioName;

  /// 0~1，离线分析进度（暂用粗略阶段，UI 可绑动画）。
  final double analyzingProgress;

  /// 可视化的错误消息（同时驱动 toast）。
  final String? errorMessage;

  /// 离线分析结果。
  final PitchTrack? track;

  /// 解析后各轨摘要（`selectTrack` 阶段使用）。
  final List<MidiTrackSummary> trackSummaries;

  /// 用户在选轨界面高亮的轨道（1-based）。
  final int? selectedTrackIndex;

  /// 已确认的主旋律轨（1-based）。
  final int? melodyTrackIndex;

  /// 跟唱前倒计时剩余秒数（`countdown` 阶段）。
  final int countdownSeconds;

  /// 当前播放进度（毫秒）。
  final int playbackMs;

  /// 已记录的用户音高点（按时间升序，最多保留最近 600 个 ≈ 14s）。
  final List<UserPitchPoint> userPoints;

  /// 当前用户最新一帧 MIDI。
  final double currentUserMidi;

  /// 当前用户最新一帧响度（0~1）。
  final double currentUserAmplitude;

  /// 实时累计得分（0~100）。
  final int currentScore;

  /// 已结算音符中 Good 及以上次数。
  final int hitCount;

  /// 已结算音符总数。
  final int scoredCount;

  /// 当前连击（连续 Good 及以上）。
  final int combo;

  bool get hasTrack => track != null && !(track!.isEmpty);

  bool get isBusy =>
      stage == SightSingingStage.analyzing ||
      stage == SightSingingStage.countdown;

  bool get isSinging => stage == SightSingingStage.singing;

  bool get isSelectingTrack => stage == SightSingingStage.selectTrack;

  SightSingingState copyWith({
    SightSingingStage? stage,
    Object? audioPath = _sentinel,
    Object? audioName = _sentinel,
    double? analyzingProgress,
    Object? errorMessage = _sentinel,
    Object? track = _sentinel,
    List<MidiTrackSummary>? trackSummaries,
    Object? selectedTrackIndex = _sentinel,
    Object? melodyTrackIndex = _sentinel,
    int? countdownSeconds,
    int? playbackMs,
    List<UserPitchPoint>? userPoints,
    double? currentUserMidi,
    double? currentUserAmplitude,
    int? currentScore,
    int? hitCount,
    int? scoredCount,
    int? combo,
  }) {
    return SightSingingState(
      stage: stage ?? this.stage,
      audioPath:
          identical(audioPath, _sentinel) ? this.audioPath : audioPath as String?,
      audioName:
          identical(audioName, _sentinel) ? this.audioName : audioName as String?,
      analyzingProgress: analyzingProgress ?? this.analyzingProgress,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      track: identical(track, _sentinel) ? this.track : track as PitchTrack?,
      trackSummaries: trackSummaries ?? this.trackSummaries,
      selectedTrackIndex: identical(selectedTrackIndex, _sentinel)
          ? this.selectedTrackIndex
          : selectedTrackIndex as int?,
      melodyTrackIndex: identical(melodyTrackIndex, _sentinel)
          ? this.melodyTrackIndex
          : melodyTrackIndex as int?,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      playbackMs: playbackMs ?? this.playbackMs,
      userPoints: userPoints ?? this.userPoints,
      currentUserMidi: currentUserMidi ?? this.currentUserMidi,
      currentUserAmplitude: currentUserAmplitude ?? this.currentUserAmplitude,
      currentScore: currentScore ?? this.currentScore,
      hitCount: hitCount ?? this.hitCount,
      scoredCount: scoredCount ?? this.scoredCount,
      combo: combo ?? this.combo,
    );
  }
}

const Object _sentinel = Object();

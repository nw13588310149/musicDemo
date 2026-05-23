import '../config/smart_sight_singing_config.dart';
import 'pitch_track.dart';
import 'realtime_pitch_capture.dart';
import 'ktv_pitch_guide.dart';

/// 评分音准容差。standardCents 是 Good/命中的标准区间。
class KtvScoringTolerance {
  const KtvScoringTolerance({
    required this.perfectCents,
    required this.goodCents,
    required this.okCents,
  });

  factory KtvScoringTolerance.fromStandardCents(double standardCents) {
    final good = SmartSightSingingScoringConfig.normalizeStandardCents(
      standardCents,
    );
    return KtvScoringTolerance(
      perfectCents:
          good *
          SmartSightSingingScoringConfig.perfectCentsAtDefault /
          SmartSightSingingScoringConfig.defaultStandardCents,
      goodCents: good,
      okCents:
          good *
          SmartSightSingingScoringConfig.okCentsAtDefault /
          SmartSightSingingScoringConfig.defaultStandardCents,
    );
  }

  final double perfectCents;
  final double goodCents;
  final double okCents;
}

/// 单个音符的评分结果。
class KtvNoteScore {
  const KtvNoteScore({
    required this.noteIndex,
    required this.startMs,
    required this.endMs,
    required this.refMidi,
    required this.userMidi,
    required this.cents,
    required this.points,
    required this.hitLevel,
  });

  final int noteIndex;
  final int startMs;
  final int endMs;
  final double refMidi;
  final double userMidi;
  final double cents;
  final int points;

  /// perfect / good / ok / miss
  final String hitLevel;

  bool get isHit => points >= SmartSightSingingScoringConfig.goodPoints;
}

/// KTV 打分会话：在用户跟唱过程中按音符结算。
class KtvScoringSession {
  KtvScoringSession({
    required PitchTrack track,
    double standardCents = SmartSightSingingScoringConfig.defaultStandardCents,
  }) : _track = track,
       _tolerance = KtvScoringTolerance.fromStandardCents(standardCents);

  final PitchTrack _track;
  final KtvScoringTolerance _tolerance;

  int? _activeNoteIndex;
  final List<double> _userMidis = <double>[];
  final List<KtvNoteScore> _completed = <KtvNoteScore>[];
  int _combo = 0;
  int _maxCombo = 0;

  List<KtvNoteScore> get completedScores =>
      List<KtvNoteScore>.unmodifiable(_completed);

  int get combo => _combo;
  int get maxCombo => _maxCombo;

  /// 当前累计得分 0~100（已完成音符平均分）。
  int get totalScore {
    if (_completed.isEmpty) return 0;
    final sum = _completed.fold<int>(0, (a, s) => a + s.points);
    return (sum / _completed.length).round().clamp(0, 100);
  }

  int get hitCount => _completed.where((s) => s.isHit).length;
  int get scoredCount => _completed.length;

  /// 处理一帧实时音高；返回当前应展示给用户的信息。
  KtvScoringTick onPitch({
    required int playbackMs,
    required RealtimePitchEvent event,
  }) {
    final evalMs = playbackMs - SmartSightSingingScoringConfig.micLatencyMs;
    final noteIndex = _track.noteIndexAt(
      evalMs,
      earlyMs: SmartSightSingingScoringConfig.earlySingMs,
      lateMs: SmartSightSingingScoringConfig.lateSingMs,
    );
    final note = noteIndex == null ? null : _track.notes[noteIndex];

    if (_activeNoteIndex != noteIndex) {
      _finalizeActiveNote();
      _activeNoteIndex = noteIndex;
      _userMidis.clear();
    }

    if (event.pitched && note != null) {
      _userMidis.add(event.midi);
    }

    final refFrame = _track.sampleAt(evalMs);
    final refMidi = refFrame?.midi ?? -1;
    double cents = double.nan;
    if (event.pitched && refFrame != null && refFrame.pitched) {
      cents = PitchUtils.octaveNormalizedCents(event.midi, refFrame.midi);
    }

    return KtvScoringTick(
      totalScore: totalScore,
      hitCount: hitCount,
      scoredCount: scoredCount,
      combo: _combo,
      cents: cents,
      refMidi: refMidi,
      userMidi: event.pitched ? event.midi : -1,
    );
  }

  /// 演唱结束或切歌时，结算最后一个音符。
  KtvScoringTick finalize() {
    _finalizeActiveNote();
    return KtvScoringTick(
      totalScore: totalScore,
      hitCount: hitCount,
      scoredCount: scoredCount,
      combo: _combo,
      cents: double.nan,
      refMidi: -1,
      userMidi: -1,
    );
  }

  void _finalizeActiveNote() {
    final index = _activeNoteIndex;
    if (index == null || index < 0 || index >= _track.notes.length) {
      return;
    }
    final note = _track.notes[index];
    final score = _gradeNote(
      note: note,
      noteIndex: index,
      userMidis: _userMidis,
      tolerance: _tolerance,
    );
    _completed.add(score);
    if (score.isHit) {
      _combo += 1;
      if (_combo > _maxCombo) _maxCombo = _combo;
    } else {
      _combo = 0;
    }
    _userMidis.clear();
  }

  static KtvNoteScore _gradeNote({
    required KtvNoteSegment note,
    required int noteIndex,
    required List<double> userMidis,
    required KtvScoringTolerance tolerance,
  }) {
    if (userMidis.isEmpty) {
      return KtvNoteScore(
        noteIndex: noteIndex,
        startMs: note.startMs,
        endMs: note.endMs,
        refMidi: note.midi,
        userMidi: -1,
        cents: double.nan,
        points: 0,
        hitLevel: 'miss',
      );
    }

    final sorted = List<double>.from(userMidis)..sort();
    final userMidi = sorted[sorted.length ~/ 2];
    final cents = PitchUtils.octaveNormalizedCents(userMidi, note.midi);
    final absCents = cents.abs();

    late int points;
    late String level;
    if (absCents <= tolerance.perfectCents) {
      points = SmartSightSingingScoringConfig.perfectPoints;
      level = 'perfect';
    } else if (absCents <= tolerance.goodCents) {
      points = SmartSightSingingScoringConfig.goodPoints;
      level = 'good';
    } else if (absCents <= tolerance.okCents) {
      points = SmartSightSingingScoringConfig.okPoints;
      level = 'ok';
    } else {
      points = 0;
      level = 'miss';
    }

    return KtvNoteScore(
      noteIndex: noteIndex,
      startMs: note.startMs,
      endMs: note.endMs,
      refMidi: note.midi,
      userMidi: userMidi,
      cents: cents,
      points: points,
      hitLevel: level,
    );
  }
}

class KtvScoringTick {
  const KtvScoringTick({
    required this.totalScore,
    required this.hitCount,
    required this.scoredCount,
    required this.combo,
    required this.cents,
    required this.refMidi,
    required this.userMidi,
  });

  final int totalScore;
  final int hitCount;
  final int scoredCount;
  final int combo;
  final double cents;
  final double refMidi;
  final double userMidi;
}

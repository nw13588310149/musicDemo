import 'realtime_pitch_capture.dart';

/// 过滤扬声器伴奏被麦克风录入导致的「假跟唱」。
abstract final class PitchVoiceGate {
  /// 无声跟唱：不外放伴奏，不做串音过滤。
  static const PitchVoiceGatePolicy visualOnly = PitchVoiceGatePolicy(
    minAmplitude: 0.012,
    bleedMatchMaxAmplitude: 0,
    bleedMatchMaxCents: 0,
    rejectPlaybackPitchMatch: false,
    rejectRefMidiMatch: false,
  );

  /// 有伴奏跟唱：仅过滤「极低响度 + 与当前钢琴音完全一致」的扬声器串音。
  /// 唱准参考音不应被过滤——用户本来就要对准旋律。
  static const PitchVoiceGatePolicy withAccompaniment =
      PitchVoiceGatePolicy(
    minAmplitude: 0.018,
    bleedMatchMaxAmplitude: 0.075,
    bleedMatchMaxCents: 10,
    rejectPlaybackPitchMatch: true,
    rejectRefMidiMatch: false,
  );

  static bool isLikelyUserVoice({
    required RealtimePitchEvent event,
    double? refMidi,
    double? playbackMidi,
    PitchVoiceGatePolicy policy = withAccompaniment,
  }) {
    if (!event.pitched) return false;
    if (event.amplitude < policy.minAmplitude) return false;

    if (!policy.rejectRefMidiMatch && !policy.rejectPlaybackPitchMatch) {
      return true;
    }

    if (policy.rejectPlaybackPitchMatch &&
        playbackMidi != null &&
        playbackMidi > 0) {
      final playbackDiff = (event.midi - playbackMidi).abs() * 100;
      // 响度明显高于串音水平时，视为用户发声（即使音高与伴奏一致）。
      if (event.amplitude > policy.bleedMatchMaxAmplitude + 0.045) {
        return true;
      }
      if (playbackDiff <= policy.bleedMatchMaxCents &&
          event.amplitude <= policy.bleedMatchMaxAmplitude) {
        return false;
      }
    }

    if (policy.rejectRefMidiMatch && refMidi != null && refMidi > 0) {
      final diffCents = (event.midi - refMidi).abs() * 100;
      if (diffCents <= policy.bleedMatchMaxCents &&
          event.amplitude <= policy.bleedMatchMaxAmplitude) {
        return false;
      }
    }
    return true;
  }

  static RealtimePitchEvent filterForScoring({
    required RealtimePitchEvent event,
    double? refMidi,
    double? playbackMidi,
    PitchVoiceGatePolicy policy = withAccompaniment,
  }) {
    if (!isLikelyUserVoice(
      event: event,
      refMidi: refMidi,
      playbackMidi: playbackMidi,
      policy: policy,
    )) {
      return RealtimePitchEvent(
        frequencyHz: 0,
        midi: -1,
        confidence: event.confidence,
        amplitude: event.amplitude,
        pitched: false,
      );
    }
    return event;
  }
}

class PitchVoiceGatePolicy {
  const PitchVoiceGatePolicy({
    required this.minAmplitude,
    required this.bleedMatchMaxAmplitude,
    required this.bleedMatchMaxCents,
    required this.rejectPlaybackPitchMatch,
    required this.rejectRefMidiMatch,
  });

  final double minAmplitude;
  final double bleedMatchMaxAmplitude;
  final double bleedMatchMaxCents;
  final bool rejectPlaybackPitchMatch;
  final bool rejectRefMidiMatch;
}

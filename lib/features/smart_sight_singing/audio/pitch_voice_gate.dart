import 'realtime_pitch_capture.dart';

/// 过滤扬声器伴奏被麦克风录入导致的「假跟唱」。
abstract final class PitchVoiceGate {
  /// 无声跟唱（iPad 默认）：几乎无外放串音，阈值更宽松。
  static const PitchVoiceGatePolicy visualOnly = PitchVoiceGatePolicy(
    minAmplitude: 0.045,
    bleedMatchMaxAmplitude: 0.08,
    bleedMatchMaxCents: 12,
    rejectPlaybackPitchMatch: false,
  );

  /// 有伴奏跟唱：严格过滤与参考音一致的低响度检测。
  static const PitchVoiceGatePolicy withAccompaniment =
      PitchVoiceGatePolicy(
    minAmplitude: 0.065,
    bleedMatchMaxAmplitude: 0.11,
    bleedMatchMaxCents: 18,
    rejectPlaybackPitchMatch: true,
  );

  static bool isLikelyUserVoice({
    required RealtimePitchEvent event,
    double? refMidi,
    double? playbackMidi,
    PitchVoiceGatePolicy policy = withAccompaniment,
  }) {
    if (!event.pitched) return false;
    if (event.amplitude < policy.minAmplitude) return false;

    if (policy.rejectPlaybackPitchMatch &&
        playbackMidi != null &&
        playbackMidi > 0) {
      final playbackDiff = (event.midi - playbackMidi).abs() * 100;
      if (playbackDiff <= policy.bleedMatchMaxCents &&
          event.amplitude <= policy.bleedMatchMaxAmplitude + 0.03) {
        return false;
      }
    }

    if (refMidi != null && refMidi > 0) {
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
  });

  final double minAmplitude;
  final double bleedMatchMaxAmplitude;
  final double bleedMatchMaxCents;
  final bool rejectPlaybackPitchMatch;
}

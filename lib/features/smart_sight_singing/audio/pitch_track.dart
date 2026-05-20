import 'dart:math' as math;

/// 单帧音高分析结果。
class PitchFrame {
  const PitchFrame({
    required this.timeMs,
    required this.frequencyHz,
    required this.midi,
    required this.confidence,
  });

  /// 帧中点对应的时间（毫秒）。
  final int timeMs;

  /// 检测到的基频（Hz）。0 表示该帧无音高（静音/噪声）。
  final double frequencyHz;

  /// 对应的 MIDI 音高（69 + 12·log2(f/440)），无音高时为 -1。
  final double midi;

  /// YIN 概率（0~1），越高越可信。
  final double confidence;

  bool get pitched => frequencyHz > 0 && confidence > 0.4 && midi.isFinite;
}

/// 参考音高曲线 + 元数据。
class PitchTrack {
  const PitchTrack({
    required this.frames,
    required this.totalMs,
    required this.frameStepMs,
    required this.minMidi,
    required this.maxMidi,
  });

  /// 按时间升序排列的全部帧（含无音高帧）。
  final List<PitchFrame> frames;

  /// 曲目总长度（毫秒）。
  final int totalMs;

  /// 帧步长（毫秒，与 isolate 分析一致）。
  final int frameStepMs;

  /// 有效音高范围（用于 UI 纵轴居中），无有效帧时为合理默认。
  final double minMidi;
  final double maxMidi;

  bool get isEmpty => frames.isEmpty;

  /// 在时间 [ms] 附近返回参考音高帧（取最近的有效帧；找不到时回 `null`）。
  PitchFrame? sampleAt(int ms, {int searchHalfWindowMs = 60}) {
    if (frames.isEmpty) return null;
    if (frameStepMs <= 0) return null;
    var idx = (ms / frameStepMs).round();
    idx = idx.clamp(0, frames.length - 1);
    // 优先返回 idx 本身；若该帧不可信，向两侧扩展找最近 pitched 帧。
    final center = frames[idx];
    if (center.pitched) return center;
    final maxOffset = (searchHalfWindowMs / frameStepMs).ceil();
    for (var off = 1; off <= maxOffset; off++) {
      final left = idx - off;
      final right = idx + off;
      if (left >= 0 && frames[left].pitched) return frames[left];
      if (right < frames.length && frames[right].pitched) return frames[right];
    }
    return null;
  }
}

/// MIDI ↔ Hz 互转 + 中文唱名。
class PitchUtils {
  PitchUtils._();

  static double hzToMidi(double hz) {
    if (hz <= 0) return double.nan;
    return 69 + 12 * (math.log(hz / 440.0) / math.ln2);
  }

  static double midiToHz(double midi) {
    return 440.0 * math.pow(2, (midi - 69) / 12.0).toDouble();
  }

  /// 计算两个频率之间的偏差（音分），ref<=0 时返回 NaN。
  static double centsBetween(double real, double ref) {
    if (ref <= 0 || real <= 0) return double.nan;
    return 1200 * (math.log(real / ref) / math.ln2);
  }

  /// 例如 midi=60 -> "C4"。
  static String midiToNoteName(double midi) {
    if (midi.isNaN || midi.isInfinite) return '--';
    const names = <String>[
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final rounded = midi.round();
    final octave = (rounded ~/ 12) - 1;
    final n = ((rounded % 12) + 12) % 12;
    return '${names[n]}$octave';
  }
}

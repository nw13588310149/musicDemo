import 'dart:math' as math;

import 'pitch_track.dart';

/// KTV 参考「音符条」：由连续帧合并、量化后得到，用于 UI 绘制与打分。
class KtvNoteSegment {
  const KtvNoteSegment({
    required this.startMs,
    required this.endMs,
    required this.midi,
  });

  final int startMs;
  final int endMs;
  final double midi;

  int get durationMs => math.max(0, endMs - startMs);

  bool contains(int ms) => ms >= startMs && ms <= endMs;
}

/// 将 YIN 帧序列整理为 KTV 风格音符条。
///
/// 商业 KTV 的参考音高来自伴奏 MIDI / 人工标注，而不是对混音做 YIN。
/// 这里在无法拿到 MIDI 时，对离线 YIN 结果做：八度连续量化、合并、去毛刺。
abstract final class KtvPitchGuideBuilder {
  static const int _minNoteMs = 140;
  static const int _mergeGapMs = 160;
  static const double _minConfidence = 0.52;

  static List<KtvNoteSegment> fromFrames(
    List<PitchFrame> frames, {
    int frameStepMs = 23,
  }) {
    if (frames.isEmpty) return const [];

    final quantized = <({int timeMs, double midi})>[];
    double? prevMidi;
    for (final frame in frames) {
      if (!frame.pitched || frame.confidence < _minConfidence) continue;
      final midi = _quantizeWithContinuity(frame.midi, prevMidi);
      if (!midi.isFinite) continue;
      prevMidi = midi;
      quantized.add((timeMs: frame.timeMs, midi: midi));
    }
    if (quantized.isEmpty) return const [];

    final raw = <KtvNoteSegment>[];
    var segStart = quantized.first.timeMs;
    var segEnd = quantized.first.timeMs + frameStepMs;
    var segMidi = quantized.first.midi;

    for (var i = 1; i < quantized.length; i++) {
      final q = quantized[i];
      final gap = q.timeMs - segEnd;
      final sameNote = (q.midi - segMidi).abs() < 0.5;
      if (sameNote && gap <= _mergeGapMs) {
        segEnd = q.timeMs + frameStepMs;
      } else {
        raw.add(KtvNoteSegment(startMs: segStart, endMs: segEnd, midi: segMidi));
        segStart = q.timeMs;
        segEnd = q.timeMs + frameStepMs;
        segMidi = q.midi;
      }
    }
    raw.add(KtvNoteSegment(startMs: segStart, endMs: segEnd, midi: segMidi));

    final merged = _mergeAdjacentSameNotes(raw);
    return _dropSpuriousBlips(merged);
  }

  static double _quantizeWithContinuity(double raw, double? prev) {
    if (!raw.isFinite) return double.nan;
    final base = raw.round();
    if (prev == null || !prev.isFinite) return base.toDouble();
    final candidates = <double>[
      base - 24.0,
      base - 12.0,
      base.toDouble(),
      base + 12.0,
      base + 24.0,
    ];
    candidates.sort(
      (a, b) => (a - prev).abs().compareTo((b - prev).abs()),
    );
    return candidates.first;
  }

  static List<KtvNoteSegment> _mergeAdjacentSameNotes(
    List<KtvNoteSegment> segments,
  ) {
    if (segments.length < 2) return segments;
    final out = <KtvNoteSegment>[segments.first];
    for (var i = 1; i < segments.length; i++) {
      final prev = out.last;
      final cur = segments[i];
      final same = (prev.midi - cur.midi).abs() < 0.5;
      final gap = cur.startMs - prev.endMs;
      if (same && gap <= _mergeGapMs) {
        out[out.length - 1] = KtvNoteSegment(
          startMs: prev.startMs,
          endMs: cur.endMs,
          midi: prev.midi,
        );
      } else {
        out.add(cur);
      }
    }
    return out;
  }

  static List<KtvNoteSegment> _dropSpuriousBlips(List<KtvNoteSegment> segments) {
    if (segments.isEmpty) return segments;
    final out = <KtvNoteSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.durationMs >= _minNoteMs) {
        out.add(seg);
        continue;
      }
      final prev = i > 0 ? segments[i - 1] : null;
      final next = i + 1 < segments.length ? segments[i + 1] : null;
      final jumpPrev =
          prev == null ? 0.0 : (seg.midi - prev.midi).abs();
      final jumpNext =
          next == null ? 0.0 : (seg.midi - next.midi).abs();
      // 极短且与前后都相差超过 4 半音 → 视为伴奏毛刺。
      if (jumpPrev > 4 && jumpNext > 4) {
        continue;
      }
      out.add(seg);
    }
    return out.where((s) => s.durationMs >= 80).toList(growable: false);
  }

  static ({double minMidi, double maxMidi}) rangeForNotes(
    List<KtvNoteSegment> notes,
  ) {
    if (notes.isEmpty) {
      return (minMidi: 48.0, maxMidi: 72.0);
    }
    var minM = double.infinity;
    var maxM = -double.infinity;
    for (final n in notes) {
      if (n.midi < minM) minM = n.midi;
      if (n.midi > maxM) maxM = n.midi;
    }
    return (
      minMidi: (minM - 2).clamp(24, 96).toDouble(),
      maxMidi: (maxM + 2).clamp(minM + 6, 100).toDouble(),
    );
  }
}

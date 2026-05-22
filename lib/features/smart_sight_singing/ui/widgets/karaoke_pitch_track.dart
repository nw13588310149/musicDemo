import 'package:flutter/material.dart';

import '../../audio/pitch_track.dart';
import '../../state/smart_sight_singing_state.dart';

/// KTV 风格音高滚动轨道：
/// - 横轴时间（当前 ± [windowMs] / 2），中央有一根「Now」竖线。
/// - 纵轴 MIDI，按 [PitchTrack.minMidi] / [PitchTrack.maxMidi] 自适应。
/// - 参考音高用横向胶囊段绘制；用户演唱音高沿时间轴留下拖尾。
class KaraokePitchTrack extends StatelessWidget {
  const KaraokePitchTrack({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    this.windowMs = 6000,
    super.key,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _KaraokePainter(
            track: track,
            playbackMs: playbackMs,
            userPoints: userPoints,
            currentUserMidi: currentUserMidi,
            windowMs: windowMs,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KaraokePainter extends CustomPainter {
  _KaraokePainter({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    required this.windowMs,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final int windowMs;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景：深紫到深蓝渐变（KTV 风）。
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B1340), Color(0xFF0E1A36)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // 纵轴音高范围。
    final minMidi = track.minMidi;
    final maxMidi = track.maxMidi;
    final midiRange = (maxMidi - minMidi).clamp(6, 60).toDouble();

    final centerX = size.width * 0.32; // Now 竖线靠左 1/3。
    final pxPerMs = size.width / windowMs;

    double xFromTime(int ms) => centerX + (ms - playbackMs) * pxPerMs;
    double yFromMidi(double midi) {
      final t = (midi - minMidi) / midiRange;
      return size.height * (1 - t.clamp(0, 1));
    }

    // 横向网格：每个半音一条暗线。
    final gridPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.5;
    for (var m = minMidi.ceil(); m <= maxMidi.floor(); m++) {
      final y = yFromMidi(m.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // 整 C 标注。
      if (((m % 12) + 12) % 12 == 0) {
        final name = PitchUtils.midiToNoteName(m.toDouble());
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              color: Color(0x88FFFFFF),
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height - 1));
      }
    }

    // 参考音高（小段彩色胶囊）。
    final refPaint = Paint()
      ..color = const Color(0xFF6AB3FF)
      ..style = PaintingStyle.fill;
    final refOutline = Paint()
      ..color = const Color(0xAA1E90FF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final visibleStartMs = playbackMs - windowMs ~/ 2;
    final visibleEndMs = playbackMs + windowMs ~/ 2;

    // 参考音高：优先 KTV 音符条，否则回退到原始帧。
    final notes = track.notes;
    if (notes.isNotEmpty) {
      for (final note in notes) {
        if (note.endMs < visibleStartMs || note.startMs > visibleEndMs) {
          continue;
        }
        final x0 = xFromTime(note.startMs);
        final x1 = xFromTime(note.endMs);
        final y = yFromMidi(note.midi);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y - 5, x1, y + 5),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    } else {
      final frames = track.frames;
      final stepMs = track.frameStepMs <= 0 ? 23 : track.frameStepMs;
      final startIdx = ((visibleStartMs - 2 * stepMs) / stepMs)
          .floor()
          .clamp(0, frames.length - 1);
      final endIdx = ((visibleEndMs + 2 * stepMs) / stepMs)
          .ceil()
          .clamp(0, frames.length - 1);

      for (var i = startIdx; i <= endIdx; i++) {
        final f = frames[i];
        if (!f.pitched) continue;
        final x0 = xFromTime(f.timeMs - stepMs ~/ 2);
        final x1 = xFromTime(f.timeMs + stepMs ~/ 2);
        final y = yFromMidi(f.midi);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y - 3, x1, y + 3),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    }

    // 用户拖尾。
    if (userPoints.isNotEmpty) {
      for (var i = 0; i < userPoints.length; i++) {
        final p = userPoints[i];
        if (!p.pitched) continue;
        final x = xFromTime(p.timeMs);
        if (x < -8 || x > size.width + 8) continue;
        final y = yFromMidi(p.midi);
        // 距当前时间越近、点越亮。
        final age = (playbackMs - p.timeMs).clamp(0, windowMs);
        final alpha = (255 * (1 - age / windowMs)).clamp(40, 255).toInt();
        final hit = !p.cents.isNaN && p.cents.abs() <= 45;
        final near = !p.cents.isNaN && p.cents.abs() <= 90;
        final color = hit
            ? Color.fromARGB(alpha, 88, 234, 132)
            : near
                ? Color.fromARGB(alpha, 255, 184, 76)
                : Color.fromARGB(alpha, 255, 110, 110);
        final radius = (1.5 + p.amplitude * 4).clamp(1.5, 6).toDouble();
        canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      }
    }

    // 当前用户实测音 — 大光点 + 发光环。
    if (currentUserMidi > 0) {
      final y = yFromMidi(currentUserMidi);
      final ref = track.sampleAt(playbackMs);
      final on = ref != null && (currentUserMidi - ref.midi).abs() < 0.45;
      final color = on ? const Color(0xFF58EA84) : const Color(0xFFFFB84C);
      canvas.drawCircle(
        Offset(centerX, y),
        14,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        Offset(centerX, y),
        7,
        Paint()..color = color.withValues(alpha: 0.4),
      );
      canvas.drawCircle(Offset(centerX, y), 4, Paint()..color = color);
    }

    // Now 竖线。
    final nowPaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centerX, 6),
      Offset(centerX, size.height - 6),
      nowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KaraokePainter old) {
    return old.playbackMs != playbackMs ||
        old.track != track ||
        !identical(old.userPoints, userPoints) ||
        old.currentUserMidi != currentUserMidi ||
        old.windowMs != windowMs;
  }
}

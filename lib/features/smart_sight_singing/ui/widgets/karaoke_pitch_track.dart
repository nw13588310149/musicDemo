import 'package:flutter/material.dart';

import '../../config/smart_sight_singing_config.dart';
import '../../audio/pitch_track.dart';
import '../../state/smart_sight_singing_state.dart';

/// KTV 风格音高滚动轨道（demo 中性浅色）：
/// - 横轴时间（当前 ± [windowMs] / 2），中央有一根「Now」竖线。
/// - 纵轴 MIDI，按 [PitchTrack.minMidi] / [PitchTrack.maxMidi] 自适应。
/// - 参考音高用横向胶囊段绘制；用户演唱音高沿时间轴留下拖尾。
class KaraokePitchTrack extends StatelessWidget {
  const KaraokePitchTrack({
    required this.track,
    required this.playbackMs,
    required this.userPoints,
    required this.currentUserMidi,
    this.currentUserAmplitude = 0,
    this.windowMs = SmartSightSingingViewConfig.karaokeWindowMs,
    super.key,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final double currentUserAmplitude;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _KaraokePainter(
              track: track,
              playbackMs: playbackMs,
              userPoints: userPoints,
              currentUserMidi: currentUserMidi,
              currentUserAmplitude: currentUserAmplitude,
              windowMs: windowMs,
            ),
            child: const SizedBox.expand(),
          ),
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
    required this.currentUserAmplitude,
    required this.windowMs,
  });

  final PitchTrack track;
  final int playbackMs;
  final List<UserPitchPoint> userPoints;
  final double currentUserMidi;
  final double currentUserAmplitude;
  final int windowMs;

  static const _bg = Color(0xFFF5F6F8);
  static const _grid = Color(0xFFD8DCE3);
  static const _label = Color(0xFF788698);
  static const _accent = Color(0xFF8741FF);
  static const _refFill = Color(0x268741FF);
  static const _refStroke = _accent;
  static const _nowLine = _accent;
  static const _userOn = Color(0xFF4A5568);
  static const _userNear = Color(0xFF9CA3AF);
  static const _userOff = Color(0xFFC4C9D1);

  /// 参考音符条高度（设计稿 20px）。
  static const _noteBarHeight = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    canvas.drawRect(bgRect, Paint()..color = _bg);

    final minMidi = track.minMidi;
    final maxMidi = track.maxMidi;
    final midiRange = (maxMidi - minMidi).clamp(6, 60).toDouble();
    final rangeCenter = (minMidi + maxMidi) / 2;

    final centerX =
        size.width * SmartSightSingingViewConfig.karaokeNowLineFraction;
    final pxPerMs = size.width / windowMs;

    double xFromTime(int ms) => centerX + (ms - playbackMs) * pxPerMs;
    double yFromMidi(double midi) {
      final t = (midi - minMidi) / midiRange;
      return size.height * (1 - t.clamp(0, 1));
    }

    // 用户演唱可能跨八度（男生唱女高音谱、童声唱男低音谱…），原始 MIDI
    // 会落在显示音域之外被钉到顶/底。这里把用户音高沿八度方向"折叠"到
    // 离参考音（或音域中心）最近的同名八度，再交给 yFromMidi 绘制；
    // 与 octaveNormalizedCents 评分逻辑保持一致。
    double octaveSnap(double midi, double target) {
      if (midi < 0 || !midi.isFinite) return midi;
      final delta = midi - target;
      final octaves = (delta / 12).round();
      return midi - octaves * 12;
    }

    double displayMidiAt(double midi, int timeMs) {
      if (midi < 0 || !midi.isFinite) return midi;
      final ref = track.sampleAt(timeMs);
      final target = (ref != null && ref.pitched) ? ref.midi : rangeCenter;
      return octaveSnap(midi, target);
    }

    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 0.5;
    for (var m = minMidi.ceil(); m <= maxMidi.floor(); m++) {
      final y = yFromMidi(m.toDouble());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      if (((m % 12) + 12) % 12 == 0) {
        final name = PitchUtils.midiToNoteName(m.toDouble());
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              color: _label,
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height - 1));
      }
    }

    final refPaint = Paint()
      ..color = _refFill
      ..style = PaintingStyle.fill;
    final refOutline = Paint()
      ..color = _refStroke
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final visibleStartMs = playbackMs - windowMs ~/ 2;
    final visibleEndMs = playbackMs + windowMs ~/ 2;

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
          Rect.fromLTRB(x0, y - _noteBarHeight / 2, x1, y + _noteBarHeight / 2),
          const Radius.circular(_noteBarHeight / 2),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    } else {
      final frames = track.frames;
      final stepMs = track.frameStepMs <= 0
          ? SmartSightSingingMidiConfig.referenceFrameStepMs
          : track.frameStepMs;
      final startIdx = ((visibleStartMs - 2 * stepMs) / stepMs).floor().clamp(
        0,
        frames.length - 1,
      );
      final endIdx = ((visibleEndMs + 2 * stepMs) / stepMs).ceil().clamp(
        0,
        frames.length - 1,
      );

      for (var i = startIdx; i <= endIdx; i++) {
        final f = frames[i];
        if (!f.pitched) continue;
        final x0 = xFromTime(f.timeMs - stepMs ~/ 2);
        final x1 = xFromTime(f.timeMs + stepMs ~/ 2);
        final y = yFromMidi(f.midi);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y - _noteBarHeight / 2, x1, y + _noteBarHeight / 2),
          const Radius.circular(_noteBarHeight / 2),
        );
        canvas.drawRRect(rect, refPaint);
        canvas.drawRRect(rect, refOutline);
      }
    }

    if (userPoints.isNotEmpty) {
      for (var i = 0; i < userPoints.length; i++) {
        final p = userPoints[i];
        if (!p.pitched) continue;
        final x = xFromTime(p.timeMs);
        if (x < -8 || x > size.width + 8) continue;
        final y = yFromMidi(displayMidiAt(p.midi, p.timeMs));
        final age = (playbackMs - p.timeMs).clamp(0, windowMs);
        final alpha = (255 * (1 - age / windowMs)).clamp(40, 255).toInt();
        final hit = !p.cents.isNaN && p.cents.abs() <= 45;
        final near = !p.cents.isNaN && p.cents.abs() <= 90;
        final base = hit
            ? _userOn
            : near
            ? _userNear
            : _userOff;
        final color = base.withValues(alpha: alpha / 255);
        final radius = (1.5 + p.amplitude * 4).clamp(1.5, 6).toDouble();
        canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      }
    }

    if (currentUserMidi >= 0) {
      // 唱得标准时（与参考音同八度且零偏差），displayMidiAt 会把用户音高
      // 折叠到参考音本身，y 即等于参考矩形中线 → 气泡上下居中。
      final y = yFromMidi(displayMidiAt(currentUserMidi, playbackMs));
      canvas.drawCircle(
        Offset(centerX, y),
        7,
        Paint()..color = _accent.withValues(alpha: 0.8),
      );
    } else if (currentUserAmplitude >
        SmartSightSingingViewConfig.micActivityIndicatorMinAmplitude) {
      // 有响度但未识别音高：在 Now 线底部显示麦克风活动指示。
      final barW = (8 + currentUserAmplitude * 40).clamp(8.0, 36.0);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height - 18),
          width: barW,
          height: 6,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = _userNear.withValues(
            alpha: 0.35 + currentUserAmplitude * 0.4,
          ),
      );
    }

    final nowPaint = Paint()
      ..color = _nowLine.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, 6),
      Offset(centerX, size.height - 6),
      nowPaint,
    );

    _drawNowGlow(canvas, centerX, _glowCenterY);
  }

  /// 紫色竖线顶部的扩散圆：由外到内 5 层同心圆，半径与透明度对齐设计稿
  /// （34/28.09/22.17/16.26/10.35 直径，alpha 0.2/0.3/0.5/0.7/1.0）。
  static const _glowCenterY = 48.0;

  void _drawNowGlow(Canvas canvas, double cx, double cy) {
    const layers = <(double, double)>[
      (17.0, 0.20),
      (14.045, 0.30),
      (11.085, 0.50),
      (8.13, 0.70),
      (5.175, 1.0),
    ];
    for (final (radius, alpha) in layers) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..color = _accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KaraokePainter old) {
    return old.playbackMs != playbackMs ||
        old.track != track ||
        !identical(old.userPoints, userPoints) ||
        old.currentUserMidi != currentUserMidi ||
        old.currentUserAmplitude != currentUserAmplitude ||
        old.windowMs != windowMs;
  }
}

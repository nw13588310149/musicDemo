import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/ktv_pitch_guide.dart';
import '../../audio/pitch_track.dart';
import '../../config/smart_sight_singing_config.dart';

/// 谱例视唱视图：把 MIDI 主旋律轨绘制成五线谱滚动谱例。
class ScoreSightReadingTrack extends StatelessWidget {
  const ScoreSightReadingTrack({
    required this.track,
    required this.playbackMs,
    required this.currentUserMidi,
    this.currentUserAmplitude = 0,
    this.windowMs = SmartSightSingingViewConfig.scoreWindowMs,
    super.key,
  });

  final PitchTrack track;
  final int playbackMs;
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
            painter: _ScoreSightReadingPainter(
              track: track,
              playbackMs: playbackMs,
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

class _ScoreSightReadingPainter extends CustomPainter {
  _ScoreSightReadingPainter({
    required this.track,
    required this.playbackMs,
    required this.currentUserMidi,
    required this.currentUserAmplitude,
    required this.windowMs,
  });

  final PitchTrack track;
  final int playbackMs;
  final double currentUserMidi;
  final double currentUserAmplitude;
  final int windowMs;

  static const _bg = Color(0xFFF5F6F8);
  static const _staff = Color(0xFF6B7280);
  static const _note = Color(0xFF4A5568);
  static const _noteMuted = Color(0xFF9CA3AF);
  static const _notePast = Color(0xFFC4C9D1);
  static const _active = Color(0xFF1A1A1A);
  static const _user = Color(0xFF4A5568);

  static const int _e4Step = SmartSightSingingViewConfig.trebleStaffBottomStep;
  static const int _f5Step = SmartSightSingingViewConfig.trebleStaffTopStep;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final notes = track.notes;
    if (notes.isEmpty || size.isEmpty) return;

    final lineSpacing =
        (size.height *
                SmartSightSingingViewConfig.scoreLineSpacingHeightFraction)
            .clamp(12.0, 20.0)
            .toDouble();
    final halfStep = lineSpacing / 2;
    final staffTop = (size.height - lineSpacing * 4) / 2;
    final staffBottom = staffTop + lineSpacing * 4;
    final centerX =
        size.width * SmartSightSingingViewConfig.scoreNowLineFraction;
    final pxPerMs = size.width / windowMs;
    final visibleStartMs = playbackMs - windowMs ~/ 2;
    final visibleEndMs = playbackMs + windowMs ~/ 2;

    double xFromTime(int ms) => centerX + (ms - playbackMs) * pxPerMs;
    double yFromStep(int step) => staffBottom - (step - _e4Step) * halfStep;
    double yFromMidi(double midi) => yFromStep(_spell(midi).step);

    final staffPaint = Paint()
      ..color = _staff
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), staffPaint);
    }

    _drawClef(canvas, Offset(18, staffTop - lineSpacing * 0.35), lineSpacing);

    for (final note in notes) {
      if (note.endMs < visibleStartMs || note.startMs > visibleEndMs) {
        continue;
      }
      final x0 = xFromTime(note.startMs);
      final x1 = xFromTime(note.endMs).clamp(x0 + 12, size.width + 48);
      final y = yFromMidi(note.midi);
      final active = playbackMs >= note.startMs && playbackMs <= note.endMs;
      final past = note.endMs < playbackMs;
      final color = active
          ? _active
          : past
          ? _notePast
          : _note;

      _drawDurationGuide(canvas, x0, x1, y, color, active);
      _drawLedgerLines(canvas, x0, yFromStep, _spell(note.midi).step, color);
      _drawNote(canvas, note, Offset(x0, y), color, active);
    }

    final nowPaint = Paint()
      ..color = _active
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(centerX, 8),
      Offset(centerX, size.height - 8),
      nowPaint,
    );

    if (currentUserMidi >= 0) {
      final ref = track.sampleAt(playbackMs);
      final displayMidi = _displayUserMidi(currentUserMidi, ref?.midi);
      final y = yFromMidi(displayMidi);
      canvas.drawCircle(
        Offset(centerX, y),
        13,
        Paint()
          ..color = _user.withValues(
            alpha: (0.10 + currentUserAmplitude * 0.22).clamp(0.10, 0.30),
          ),
      );
      canvas.drawCircle(
        Offset(centerX, y),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _user.withValues(alpha: 0.75),
      );
    } else if (currentUserAmplitude >
        SmartSightSingingViewConfig.micActivityIndicatorMinAmplitude) {
      final barW = (8 + currentUserAmplitude * 40).clamp(8.0, 36.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height - 18),
          width: barW,
          height: 6,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = _noteMuted.withValues(
            alpha: 0.35 + currentUserAmplitude * 0.4,
          ),
      );
    }
  }

  void _drawClef(Canvas canvas, Offset offset, double lineSpacing) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          color: _staff.withValues(alpha: 0.78),
          fontSize: lineSpacing * 3.0,
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawDurationGuide(
    Canvas canvas,
    double x0,
    double x1,
    double y,
    Color color,
    bool active,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.28 : 0.16)
      ..strokeWidth = active ? 5 : 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
  }

  void _drawNote(
    Canvas canvas,
    KtvNoteSegment note,
    Offset center,
    Color color,
    bool active,
  ) {
    final spelling = _spell(note.midi);
    if (spelling.accidental != null) {
      _drawAccidental(canvas, spelling.accidental!, center, color);
    }

    final notePaint = Paint()
      ..color = active ? _active : color
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = active ? _active : color
      ..strokeWidth = active ? 1.8 : 1.3
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 11),
      notePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 11),
      outline,
    );
    canvas.restore();

    final stemUp = spelling.step < 34;
    final stemStart = stemUp
        ? Offset(center.dx + 7, center.dy)
        : Offset(center.dx - 7, center.dy);
    final stemEnd = stemUp
        ? Offset(center.dx + 7, center.dy - 34)
        : Offset(center.dx - 7, center.dy + 34);
    canvas.drawLine(
      stemStart,
      stemEnd,
      Paint()
        ..color = active ? _active : color
        ..strokeWidth = 1.5,
    );
  }

  void _drawAccidental(
    Canvas canvas,
    String accidental,
    Offset noteCenter,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: accidental,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(noteCenter.dx - 23, noteCenter.dy - painter.height / 2),
    );
  }

  void _drawLedgerLines(
    Canvas canvas,
    double x,
    double Function(int step) yFromStep,
    int step,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    if (step < _e4Step) {
      var ledger = _e4Step - 2;
      while (ledger >= step) {
        final y = yFromStep(ledger);
        canvas.drawLine(Offset(x - 13, y), Offset(x + 13, y), paint);
        ledger -= 2;
      }
      return;
    }
    if (step > _f5Step) {
      var ledger = _f5Step + 2;
      while (ledger <= step) {
        final y = yFromStep(ledger);
        canvas.drawLine(Offset(x - 13, y), Offset(x + 13, y), paint);
        ledger += 2;
      }
    }
  }

  double _displayUserMidi(double userMidi, double? refMidi) {
    if (refMidi == null || refMidi < 0) return userMidi;
    final cents = PitchUtils.octaveNormalizedCents(userMidi, refMidi);
    if (!cents.isFinite) return userMidi;
    return refMidi + cents / 100;
  }

  _StaffSpelling _spell(double midi) {
    final rounded = midi.round();
    final octave = (rounded ~/ 12) - 1;
    final pc = ((rounded % 12) + 12) % 12;
    return switch (pc) {
      0 => _StaffSpelling(step: octave * 7, accidental: null),
      1 => _StaffSpelling(step: octave * 7, accidental: '#'),
      2 => _StaffSpelling(step: octave * 7 + 1, accidental: null),
      3 => _StaffSpelling(step: octave * 7 + 1, accidental: '#'),
      4 => _StaffSpelling(step: octave * 7 + 2, accidental: null),
      5 => _StaffSpelling(step: octave * 7 + 3, accidental: null),
      6 => _StaffSpelling(step: octave * 7 + 3, accidental: '#'),
      7 => _StaffSpelling(step: octave * 7 + 4, accidental: null),
      8 => _StaffSpelling(step: octave * 7 + 4, accidental: '#'),
      9 => _StaffSpelling(step: octave * 7 + 5, accidental: null),
      10 => _StaffSpelling(step: octave * 7 + 5, accidental: '#'),
      _ => _StaffSpelling(step: octave * 7 + 6, accidental: null),
    };
  }

  @override
  bool shouldRepaint(covariant _ScoreSightReadingPainter old) {
    return old.track != track ||
        old.playbackMs != playbackMs ||
        old.currentUserMidi != currentUserMidi ||
        old.currentUserAmplitude != currentUserAmplitude ||
        old.windowMs != windowMs;
  }
}

class _StaffSpelling {
  const _StaffSpelling({required this.step, required this.accidental});

  final int step;
  final String? accidental;
}

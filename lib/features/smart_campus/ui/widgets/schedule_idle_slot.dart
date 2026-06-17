import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 课表空格占位：白底 + 灰边圆角框 +「空闲」文案，固定显示在顶部标准高度，
/// 不因同节次有小课叠高整行而纵向拉伸。
class ScheduleIdleSlot extends StatelessWidget {
  const ScheduleIdleSlot({super.key});

  static const double _designCellLeft = 12;
  static const double _designCellTop = 14;
  static const double _designContentWidth = 176;
  static const double _designContentHeight = 96;
  static const double _designBoxTop = 9;
  static const double _designBoxHeight = 78;
  static const double _designTextLeft = 74;
  static const double _designTextTop = 40;
  static const Color _borderColor = Color(0xFFCECED1);
  static const Color _textColor = Color(0xFFB6B5BB);

  /// 14 顶距 + 96 内容区，与有课格视觉高度对齐。
  static const double designSlotHeight = _designCellTop + _designContentHeight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ColoredBox(
      color: Colors.white,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: ui(designSlotHeight),
          child: Padding(
            padding: EdgeInsets.only(
              left: ui(_designCellLeft),
              top: ui(_designCellTop),
            ),
            child: SizedBox(
              width: ui(_designContentWidth),
              height: ui(_designContentHeight),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: ui(_designBoxTop),
                    width: ui(_designContentWidth),
                    height: ui(_designBoxHeight),
                    child: CustomPaint(
                      painter: _DashedRoundedRectPainter(
                        color: _borderColor,
                        radius: ui(8),
                        strokeWidth: 1,
                        dashLength: ui(4),
                        gapLength: ui(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(_designTextLeft),
                    top: ui(_designTextTop),
                    child: Text(
                      '空闲',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _textColor,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 16 / 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final half = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(half, half, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      gapLength != oldDelegate.gapLength;
}

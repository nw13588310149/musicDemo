import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

/// 统计卡数值字族：`assets/fonts/Barlow-SemiBold.ttf`
const smartCampusStatValueFontFamily = 'Barlow SemiBold';

/// 统计卡数值样式：Barlow SemiBold 24 / w600。
TextStyle smartCampusStatValueTextStyle(
  double Function(double) ui, {
  Color color = const Color(0xFF0B081A),
}) {
  return TextStyle(
    fontSize: ui(24),
    color: color,
    fontFamily: smartCampusStatValueFontFamily,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );
}

final _smartCampusHomeStatChineseValuePattern = RegExp(r'[\u4e00-\u9fff]');
final _smartCampusHomeStatDaysValuePattern = RegExp(r'^(\d+)天$');

/// 首页中文数值字号：PingFang 同 pt 比 Barlow 数字显大，用 18 对齐数字 24 的视觉体量。
const smartCampusHomeStatChineseFontSize = 18.0;

/// 首页 6 格统计卡数值：纯数字 Barlow 24；中文（周几、今天、已过）PingFang 18。
TextStyle smartCampusHomeStatValueTextStyle(
  double Function(double) ui, {
  required String value,
  Color color = const Color(0xFF0B081A),
}) {
  if (_smartCampusHomeStatChineseValuePattern.hasMatch(value)) {
    return TextStyle(
      fontSize: ui(smartCampusHomeStatChineseFontSize),
      color: color,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w600,
      height: 1.0,
    );
  }
  return smartCampusStatValueTextStyle(ui, color: color);
}

TextStyle _smartCampusHomeStatChineseSuffixTextStyle(
  double Function(double) ui, {
  Color color = const Color(0xFF0B081A),
}) {
  return TextStyle(
    fontSize: ui(smartCampusHomeStatChineseFontSize),
    color: color,
    fontFamily: 'PingFang SC',
    fontWeight: AppFont.w600,
    height: 1.0,
  );
}

/// 「180天」：数字 Barlow 24 + 「天」PingFang 18，避免整段中文样式偏大。
Widget smartCampusHomeStatValue({
  required String value,
  required double Function(double) ui,
  Color color = const Color(0xFF0B081A),
  TextAlign textAlign = TextAlign.center,
}) {
  final daysMatch = _smartCampusHomeStatDaysValuePattern.firstMatch(value);
  if (daysMatch != null) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: daysMatch.group(1),
            style: smartCampusStatValueTextStyle(ui, color: color),
          ),
          TextSpan(
            text: '天',
            style: _smartCampusHomeStatChineseSuffixTextStyle(ui, color: color),
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  return Text(
    value,
    textAlign: textAlign,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: smartCampusHomeStatValueTextStyle(ui, value: value, color: color),
  );
}

/// 智慧校园二级页顶部统计卡（背景图 + 标题 + 数值）。
class SmartCampusStatCard extends StatelessWidget {
  const SmartCampusStatCard({
    super.key,
    required this.backgroundAsset,
    required this.label,
    required this.value,
    this.rightPadding = 56,
  });

  final String backgroundAsset;
  final String label;
  final int value;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final borderRadius = BorderRadius.circular(ui(12));

    // Container.clipBehavior 只裁剪 child，不会裁剪 BoxDecoration 里的背景图；
    // 第 4 张卡右上角渐变更饱和，容易在圆角处溢出白边，因此外层 ClipRRect 硬裁切。
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: ui(100),
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                ui(16),
                ui(14),
                ui(rightPadding),
                ui(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: ui(8)),
                  Text(
                    '$value',
                    style: smartCampusStatValueTextStyle(ui),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

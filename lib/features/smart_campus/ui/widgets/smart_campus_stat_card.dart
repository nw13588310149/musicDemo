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
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        image: DecorationImage(
          image: AssetImage(backgroundAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(rightPadding), ui(14)),
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
    );
  }
}

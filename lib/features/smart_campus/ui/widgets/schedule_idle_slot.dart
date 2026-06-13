import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';

/// 课表空格占位：铺满格子宽度，斜线背景图固定显示在顶部标准高度，
/// 不因同节次有小课叠高整行而纵向拉伸。
class ScheduleIdleSlot extends StatelessWidget {
  const ScheduleIdleSlot({super.key});

  /// 与单课格内容区一致：96 课卡 + 上下各 12 padding。
  static const double designContentHeight = 120;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ColoredBox(
      color: Colors.white,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: ui(designContentHeight),
          child: Image.asset(
            AppAssets.smartCampusIdleSlot,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}

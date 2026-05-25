import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';

/// 课表空格占位：铺满格子，使用斜线背景图，不展示「空闲」文案与描边。
class ScheduleIdleSlot extends StatelessWidget {
  const ScheduleIdleSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.smartCampusIdleSlot,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';

/// 智慧校园二级页统一顶栏背景（与请假审批页 [AppAssets.xiaoquanHeaderBg] 一致）。
BoxDecoration smartCampusPageBannerDecoration(
  double Function(double) ui, {
  double borderRadius = 16,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(ui(borderRadius)),
    image: const DecorationImage(
      image: AssetImage(AppAssets.xiaoquanHeaderBg),
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    ),
  );
}

/// 课表页顶栏壳层：固定 [AppAssets.authBgTop] 背景图 + 仅顶部圆角裁剪。
class SmartCampusScheduleTopBar extends StatelessWidget {
  const SmartCampusScheduleTopBar({
    super.key,
    required this.child,
    this.height = 68,
    this.borderRadius = 16,
  });

  final Widget child;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(height),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(borderRadius)),
          topRight: Radius.circular(ui(borderRadius)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.authBgTop,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.fill,
            alignment: Alignment.centerRight,
          ),
          child,
        ],
      ),
    );
  }
}

/// 课表页外层白卡：圆角固定不随内容滚动，内部仅 [body] 区域滚动。
class SmartCampusSchedulePageShell extends StatelessWidget {
  const SmartCampusSchedulePageShell({
    super.key,
    required this.header,
    required this.body,
    this.backgroundColor = Colors.white,
  });

  final Widget header;
  final Widget body;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: ui(20)),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

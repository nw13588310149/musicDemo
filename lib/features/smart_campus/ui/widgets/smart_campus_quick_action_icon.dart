import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';

/// 智慧校园首页快捷入口图标展示尺寸（各端统一）。
const double kSmartCampusQuickActionIconSize = 43;

/// 智慧校园各端首页快捷入口图标：43×43 展示，图片等比适配。
class SmartCampusQuickActionIcon extends StatelessWidget {
  const SmartCampusQuickActionIcon({
    super.key,
    required this.assetPath,
    this.badgeLabel,
    this.size = kSmartCampusQuickActionIconSize,
  });

  final String assetPath;

  /// 右上角红色角标文案（如 `10+`）；为空时不展示。
  final String? badgeLabel;

  /// 图标展示边长（逻辑像素，经 [DashboardScaleScope] 缩放）。
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = ui(this.size);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
          if (badgeLabel != null && badgeLabel!.isNotEmpty)
            Positioned(
              right: -ui(2),
              top: -ui(2),
              child: Container(
                height: ui(15),
                padding: EdgeInsets.symmetric(horizontal: ui(5)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF04545),
                  borderRadius: BorderRadius.circular(ui(20)),
                ),
                child: Text(
                  badgeLabel!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui(10),
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

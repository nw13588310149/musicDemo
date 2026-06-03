import 'package:flutter/material.dart';

import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';

/// 智能视唱底部操作条整图按钮（试听 / 开始跟唱 / 停止 / 取消）。
///
/// 高度固定 36（随 [DashboardScaleScope] 缩放），宽度按切图宽高比自适应。
class SightSingingImageActionButton extends StatelessWidget {
  const SightSingingImageActionButton({
    required this.asset,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final String asset;
  final VoidCallback? onTap;

  /// 为 true 时在按钮上叠小号 loading（会话切换等中间态）。
  final bool loading;

  /// 与 `assets/images/sightsing/3.png`（开始跟唱）一致的设计稿高度。
  static const double designHeight = 36;

  /// 与 `assets/images/sightsing/3.png` 一致的设计稿宽高比（276×108）。
  static const double designAspectRatio = 276 / 108;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final height = ui(designHeight);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                asset,
                height: height,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.medium,
              ),
              if (loading)
                SizedBox(
                  width: ui(18),
                  height: ui(18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8741FF),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与 [SightSingingImageActionButton] 同尺寸、同渐变胶囊风格的文字按钮。
class SightSingingGradientActionButton extends StatelessWidget {
  const SightSingingGradientActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final height = ui(SightSingingImageActionButton.designHeight);
    final width = ui(
      SightSingingImageActionButton.designHeight *
          SightSingingImageActionButton.designAspectRatio,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
              ),
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: ui(19)),
                SizedBox(width: ui(6)),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

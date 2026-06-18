import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

/// 智慧校园各端首页头像下方身份徽章。
///
/// 标签左缘对齐头像竖向中线；样式：#8741FF 底 + 白字 + 白描边。
class SmartCampusAvatarRoleBadge extends StatelessWidget {
  const SmartCampusAvatarRoleBadge({
    super.key,
    required this.label,
    this.avatarSize = 72,
  });

  final String label;

  /// 侧栏头像直径（设计稿 px）。
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Positioned(
      left: ui(avatarSize / 2),
      top: ui(avatarSize - 12),
      child: Container(
        padding: EdgeInsets.fromLTRB(ui(3), ui(2), ui(3), ui(2)),
        decoration: BoxDecoration(
          color: const Color(0xFF8741FF),
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(11),
            height: 11 / 11,
            color: Colors.white,
            fontFamily: 'Source Han Sans SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ),
    );
  }
}

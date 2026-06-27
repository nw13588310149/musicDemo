import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../data/smart_campus_role_theme.dart';
import '../../state/smart_campus_state.dart';

/// 智慧校园各端首页右侧栏：头像下方身份徽章（仅此块使用五身份主题色）。
///
/// 标签左缘对齐头像竖向中线；配色与教师管理身份标签一致（设计稿实色浅底 + 深色字）+ 白描边。
class SmartCampusAvatarRoleBadge extends StatelessWidget {
  const SmartCampusAvatarRoleBadge({
    super.key,
    required this.label,
    required this.role,
    this.avatarSize = 72,
  });

  final String label;
  final SmartCampusRole role;

  /// 侧栏头像直径（设计稿 px）。
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tag = smartCampusRoleTagStyle(role);
    return Positioned(
      left: ui(avatarSize / 2),
      top: ui(avatarSize - 12),
      child: Container(
        padding: EdgeInsets.fromLTRB(ui(3), ui(2), ui(3), ui(2)),
        decoration: BoxDecoration(
          color: tag.bg,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(11),
            height: 11 / 11,
            color: tag.fg,
            fontFamily: 'Source Han Sans SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ),
    );
  }
}

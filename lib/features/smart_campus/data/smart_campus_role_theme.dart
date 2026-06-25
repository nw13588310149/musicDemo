import 'package:flutter/material.dart';

import '../state/smart_campus_state.dart';

/// 智慧校园五身份主题色。
///
/// 仅用于：① 各端首页右侧栏头像下方身份徽章；
/// ② 管理员「教师管理」卡片左下身份标签。
const Color kSmartCampusStudentColor = Color(0xFF8741FF);
const Color kSmartCampusTeacherColor = Color(0xFF6AC3FF);
const Color kSmartCampusHeadTeacherColor = Color(0xFFDA639F);
const Color kSmartCampusDormManagerColor = Color(0xFF74D2AB);
const Color kSmartCampusAdminColor = Color(0xFFEFB065);

extension SmartCampusRoleThemeX on SmartCampusRole {
  Color get accentColor {
    switch (this) {
      case SmartCampusRole.student:
      case SmartCampusRole.principal:
        return kSmartCampusStudentColor;
      case SmartCampusRole.teacher:
        return kSmartCampusTeacherColor;
      case SmartCampusRole.headTeacher:
        return kSmartCampusHeadTeacherColor;
      case SmartCampusRole.dormManager:
        return kSmartCampusDormManagerColor;
      case SmartCampusRole.admin:
        return kSmartCampusAdminColor;
    }
  }

  /// 身份标签浅底：主色 40% 叠在白底上的不透明色（与设计稿一致，避免透底）。
  Color get accentSoftColor =>
      Color.lerp(Colors.white, accentColor, 0.4) ?? accentColor;
}

/// 身份标签统一配色：浅底 [accentSoftColor] + 主色字 [accentColor]。
({Color bg, Color fg}) smartCampusRoleTagStyle(SmartCampusRole role) {
  return (bg: role.accentSoftColor, fg: role.accentColor);
}

SmartCampusRole smartCampusRoleFromLabel(String label) {
  if (label.contains('班主任')) {
    return SmartCampusRole.headTeacher;
  }
  if (label.contains('校长')) {
    return SmartCampusRole.principal;
  }
  if (label.contains('管理')) {
    return SmartCampusRole.admin;
  }
  if (label.contains('宿管')) {
    return SmartCampusRole.dormManager;
  }
  if (label.contains('任课') || label.contains('教师') || label.contains('老师')) {
    return SmartCampusRole.teacher;
  }
  if (label.contains('学生')) {
    return SmartCampusRole.student;
  }
  return SmartCampusRole.teacher;
}

/// 教师管理页等中文身份标签 → 主题色（含 soft 底）。
({Color bg, Color fg}) smartCampusRoleTagColors(String label) =>
    smartCampusRoleTagStyle(smartCampusRoleFromLabel(label));

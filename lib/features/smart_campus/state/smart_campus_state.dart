enum SmartCampusRole { student, teacher, headTeacher, dormManager, admin }

enum SmartCampusMainView {
  dashboard,
  principalMailbox,
  myClass,
  mySchedule,
  classWorkbench,
}

enum TeacherScheduleMode { view, edit }

enum PrincipalMailboxMessageType { report, suggestion, other }

extension SmartCampusRoleX on SmartCampusRole {
  String get label {
    switch (this) {
      case SmartCampusRole.student:
        return '学生端';
      case SmartCampusRole.teacher:
        return '任课老师';
      case SmartCampusRole.headTeacher:
        return '班主任';
      case SmartCampusRole.dormManager:
        return '宿管';
      case SmartCampusRole.admin:
        return '管理员';
    }
  }

  String get shortLabel {
    switch (this) {
      case SmartCampusRole.student:
        return '学生';
      case SmartCampusRole.teacher:
        return '任课';
      case SmartCampusRole.headTeacher:
        return '班主任';
      case SmartCampusRole.dormManager:
        return '宿管';
      case SmartCampusRole.admin:
        return '管理';
    }
  }
}

/// 把后端 `myInfo` 接口返回的 `role` / `identity` 字段映射到智慧校园
/// 当前支持的五种身份。`role` 为英文标识符（优先级更高），`identity`
/// 为中文身份名（用作兜底）。
///
/// 已知后端取值示例：
/// - role: `student` / `teacher` / `headTeacher` / `head_teacher` /
///   `class_teacher` / `dorm` / `dormManager` / `admin` / `principal` 等
/// - identity: 「学生 / 老师 / 班主任 / 宿管 / 管理员 / 校长」等
SmartCampusRole mapBackendRoleToCampus(String role, [String identity = '']) {
  final r = role.trim().toLowerCase();
  // 1. 通过 role 标识符精确匹配（去掉下划线/连字符方便对齐）
  final normalized = r.replaceAll(RegExp(r'[_\-]'), '');
  switch (normalized) {
    case 'student':
    case 'stu':
    case 'pupil':
      return SmartCampusRole.student;
    case 'headteacher':
    case 'classteacher':
    case 'classmaster':
    case 'banzhuren':
      return SmartCampusRole.headTeacher;
    case 'teacher':
    case 'subjectteacher':
    case 'instructor':
      return SmartCampusRole.teacher;
    case 'dormmanager':
    case 'dorm':
    case 'dormitory':
    case 'sushe':
      return SmartCampusRole.dormManager;
    case 'admin':
    case 'administrator':
    case 'manager':
    case 'principal':
    case 'headmaster':
    case 'super':
    case 'superadmin':
    case 'schooladmin':
      return SmartCampusRole.admin;
  }

  // 2. 中文 identity 兜底（注意：班主任要先于「老师」，校长/管理员要先于「教」）
  if (identity.contains('班主任')) {
    return SmartCampusRole.headTeacher;
  }
  if (identity.contains('校长') || identity.contains('管理')) {
    return SmartCampusRole.admin;
  }
  if (identity.contains('宿管') || identity.contains('宿舍')) {
    return SmartCampusRole.dormManager;
  }
  if (identity.contains('老师') || identity.contains('教师')) {
    return SmartCampusRole.teacher;
  }
  if (identity.contains('学生') || identity.contains('同学')) {
    return SmartCampusRole.student;
  }

  // 3. 兜底：未识别身份按学生处理（功能最完整、最安全的视图）
  return SmartCampusRole.student;
}

extension PrincipalMailboxMessageTypeX on PrincipalMailboxMessageType {
  String get label {
    switch (this) {
      case PrincipalMailboxMessageType.report:
        return '举报';
      case PrincipalMailboxMessageType.suggestion:
        return '建议';
      case PrincipalMailboxMessageType.other:
        return '其他';
    }
  }
}

class SmartCampusState {
  const SmartCampusState({
    this.selectedRole = SmartCampusRole.student,
    this.mainView = SmartCampusMainView.dashboard,
    this.selectedMailboxMessageType = PrincipalMailboxMessageType.suggestion,
    this.isMailboxAnonymous = true,
    this.teacherScheduleMode = TeacherScheduleMode.view,
    this.availableRoles = const [
      SmartCampusRole.student,
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
      SmartCampusRole.dormManager,
      SmartCampusRole.admin,
    ],
  });

  final SmartCampusRole selectedRole;
  final SmartCampusMainView mainView;
  final PrincipalMailboxMessageType selectedMailboxMessageType;
  final bool isMailboxAnonymous;
  final TeacherScheduleMode teacherScheduleMode;
  final List<SmartCampusRole> availableRoles;

  SmartCampusState copyWith({
    SmartCampusRole? selectedRole,
    SmartCampusMainView? mainView,
    PrincipalMailboxMessageType? selectedMailboxMessageType,
    bool? isMailboxAnonymous,
    TeacherScheduleMode? teacherScheduleMode,
    List<SmartCampusRole>? availableRoles,
  }) {
    return SmartCampusState(
      selectedRole: selectedRole ?? this.selectedRole,
      mainView: mainView ?? this.mainView,
      selectedMailboxMessageType:
          selectedMailboxMessageType ?? this.selectedMailboxMessageType,
      isMailboxAnonymous: isMailboxAnonymous ?? this.isMailboxAnonymous,
      teacherScheduleMode: teacherScheduleMode ?? this.teacherScheduleMode,
      availableRoles: availableRoles ?? this.availableRoles,
    );
  }
}

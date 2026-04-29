import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/state/shell_controller.dart';
import 'smart_campus_state.dart';

final smartCampusControllerProvider =
    StateNotifierProvider.autoDispose<SmartCampusController, SmartCampusState>(
      (ref) {
        final controller = SmartCampusController();

        // 立即拿一次 shell user，并在变化时（仅 role/identity 变化触发）
        // 重新应用后端身份。这里用 select 避免每次 ShellState.copyWith 都触发，
        // 配合 record 的相等性比较，做到 idempotent。
        ref.listen<({String role, String identity})>(
          shellControllerProvider.select(
            (s) => (role: s.user.role, identity: s.user.identity),
          ),
          (prev, next) {
            controller.applyBackendRole(
              role: next.role,
              identity: next.identity,
            );
          },
          fireImmediately: true,
        );

        return controller;
      },
    );

class SmartCampusController extends StateNotifier<SmartCampusState> {
  SmartCampusController() : super(const SmartCampusState());

  /// 管理员/校长可在所有身份间切换；其他角色只允许查看自己的视图。
  static const List<SmartCampusRole> _allRoles = [
    SmartCampusRole.student,
    SmartCampusRole.teacher,
    SmartCampusRole.headTeacher,
    SmartCampusRole.dormManager,
    SmartCampusRole.admin,
  ];

  /// 根据后端返回的 `role` / `identity` 重新计算当前可用身份与默认身份。
  ///
  /// - 管理员：保留 5 个身份的切换能力，已选身份保持不变（首次进入默认 admin）。
  /// - 其他：`availableRoles` 锁定为唯一身份，强制 `selectedRole` 与之一致。
  void applyBackendRole({required String role, required String identity}) {
    final mapped = mapBackendRoleToCampus(role, identity);
    final isAdmin = mapped == SmartCampusRole.admin;
    final available = isAdmin ? _allRoles : <SmartCampusRole>[mapped];

    // 管理员：保留用户当前选择的身份（如果合法）；否则回到管理员视图。
    // 非管理员：强制锁定到自己的身份。
    final keepCurrent =
        isAdmin && available.contains(state.selectedRole) ? state.selectedRole : null;
    final nextSelected = keepCurrent ?? mapped;

    if (state.selectedRole == nextSelected &&
        _sameRoleList(state.availableRoles, available)) {
      return;
    }

    state = state.copyWith(
      selectedRole: nextSelected,
      availableRoles: available,
    );
  }

  void selectRole(SmartCampusRole role) {
    if (!state.availableRoles.contains(role)) {
      // 未授权切换：直接忽略，避免普通用户被串改身份。
      return;
    }
    if (state.selectedRole == role) {
      return;
    }
    state = state.copyWith(selectedRole: role);
  }

  void openPrincipalMailbox() {
    if (state.mainView == SmartCampusMainView.principalMailbox) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.principalMailbox);
  }

  void openMyClass() {
    if (state.mainView == SmartCampusMainView.myClass) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.myClass);
  }

  /// 班主任端「班级工作台」独立入口：不再复用学生「我的班级」的 mainView，
  /// 进入后强制走 [TeacherClassWorkbenchView]，与 selectedRole 解耦，避免
  /// admin / 测试账号切换到班主任视角后误落入学生 _MyClassView。
  void openClassWorkbench() {
    if (state.mainView == SmartCampusMainView.classWorkbench) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.classWorkbench);
  }

  void openMySchedule() {
    if (state.mainView == SmartCampusMainView.mySchedule) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.mySchedule);
  }

  void backToDashboard() {
    if (state.mainView == SmartCampusMainView.dashboard) {
      return;
    }
    state = state.copyWith(mainView: SmartCampusMainView.dashboard);
  }

  void selectMailboxMessageType(PrincipalMailboxMessageType type) {
    if (state.selectedMailboxMessageType == type) {
      return;
    }
    state = state.copyWith(selectedMailboxMessageType: type);
  }

  void toggleMailboxAnonymous() {
    state = state.copyWith(isMailboxAnonymous: !state.isMailboxAnonymous);
  }

  void setTeacherScheduleMode(TeacherScheduleMode mode) {
    if (state.teacherScheduleMode == mode) {
      return;
    }
    state = state.copyWith(teacherScheduleMode: mode);
  }

  bool _sameRoleList(List<SmartCampusRole> a, List<SmartCampusRole> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

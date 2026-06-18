import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/smooth_circle_network_avatar.dart';
import '../../school/data/school_repository.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/course_sign_data.dart';
import '../data/course_teacher_index_data.dart';
import '../data/head_teacher_index_data.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/smart_campus_dashboard_data.dart';
import '../data/student_dormitory_data.dart';
import '../data/student_repository.dart';
import '../data/teacher_notice_data.dart';
import '../data/teacher_repository.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

part 'student_dashboard.dart';

/// 用于尚未迁移完成的快捷按钮：弹一个轻提示，避免"点了没反应"。
/// 真实视图迁移到 Flutter 后再把对应 onTap 替换成具体回调。
void _showActionPending(BuildContext context, String label) {
  AppToast.show(context, '「$label」页面迁移中');
}

/// 任课老师 / 班主任端的智慧校园首页布局。
///
/// 与学生端 / 管理员端走的是不同的视觉系统：
/// - 顶部 6 张统计卡（4 个数值 + 「本周课时」 + 紫色「下一节」）
/// - 中间为 `#EFF3FC` 浅紫面板，承载 8 宫功能矩阵
/// - 右栏 256 宽白底面板：头像 + 运行中胶囊 + 岗位/权限/职责 +
///   任课老师 / 班主任 tab 切换 + 通知列表
///
/// `selectedRole` 来自全局 `smartCampusControllerProvider`，dashboard 内
/// 「任课老师 ↔ 班主任」tab 走 **本地 `_localTab` + 全局 `onSelectRole`** 双轨：
///   - 本地 `_localTab`：负责立刻切换 UI（任何账号都能点），由 `_selectTab`
///     的 `setState` 立即写入。
///   - 全局 `onSelectRole = controller.selectRole`：负责持久化身份。
///     - admin：`availableRoles` 含 5 个，`selectRole` 写入 state，从而
///       进出「班级工作台 / 学生名册 / 作业批改 / 考评管理」等子页再
///       返回 dashboard 时，依靠 controller 的 `hasUserSelectedRole`
///       标记保持「班主任」视角不被 `applyBackendRole` 覆盖。
///     - 普通教师：`selectRole` 会被 ignore，`state.selectedRole` 保持不变，
///       但本地 `_localTab` 已经切到 headTeacher，UI 仍然给出班主任视图的
///       本地预览（一次性，重新进入 dashboard 后会回到自身角色）。
///   - `didUpdateWidget` 仅在 `widget.selectedRole` 真正发生变化时才把
///     `_localTab` 同步为 `widget.selectedRole`，避免没变化时把已经切到的
///     本地预览打回去。
class TeacherDashboardLayout extends ConsumerStatefulWidget {
  const TeacherDashboardLayout({
    super.key,
    required this.selectedRole,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
    this.onSelectRole,
    this.roleSwitcher,
  });

  final SmartCampusRole selectedRole;

  /// 当前用户实际可用的全部身份。由 `SmartCampusState.availableRoles`
  /// 提供，来自 `myInfo.role` + `/teacher/teacherRole` 的合并解析结果。
  /// 决定右栏「身份切换」按钮组渲染哪些按钮（默认兜底为「任课老师 +
  /// 班主任」两枚，保持以前的演示行为）。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;

  /// 班主任专属：进入「班级工作台」三 Tab 页面（与学生「我的班级」分开）。
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;

  /// 学生端「课堂签到」入口；老师端没这个按钮，传 null 即可，
  /// `_TeacherActionPanel` 会在 label 命中但回调为空时走兜底 SnackBar。
  final VoidCallback? onOpenCheckIn;

  /// 学生端「我的作业」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyHomework;

  /// 学生端「我的考试」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyGrades;

  /// 「群聊」入口（学生 / 教师 / 班主任 共用同一个聊天页面）。
  final VoidCallback? onOpenGroupChat;

  /// 「校圈」入口：学生 / 教师 / 班主任 / 宿管 共用，跳转到首页同名校圈
  /// 详情（CirclePage / RoutePaths.circle）。
  final VoidCallback? onOpenSchoolCircle;

  /// 学生端「请假管理」入口（"请假补课"页面）；其他角色入口名为
  /// "请假审批" / "宿管请假"，走各自独立路由。
  final VoidCallback? onOpenLeaveManagement;

  /// 学生端「查寝管理」入口：仅展示本人查寝记录 + 申请补卡。
  final VoidCallback? onOpenDormCheck;

  /// 任课老师 / 班主任「签课管理」入口：进入签到总览页（5 项统计 +
  /// 最近签课记录 + 今日课程 + 大课/小课签到操作面板）。
  final VoidCallback? onOpenClassAttendance;

  /// 任课老师 / 班主任「学生名册」入口：进入名册总览页（班级 dropdown +
  /// 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
  final VoidCallback? onOpenStudentRoster;

  /// 任课老师 / 班主任「作业批改」入口：进入"作业与批改"总览页（4 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业列表 + 右
  /// 当前作业的提交学生表，并通过右抽屉发布作业 / 查看历史发布记录 /
  /// 进入作业点评）。
  final VoidCallback? onOpenHomeworkReview;

  /// 任课老师 / 班主任「考评管理」入口：进入"考评管理"总览页（5 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表（N/M 提交比）+
  /// 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)，仅查看不可新建考试，
  /// 通过右抽屉查看历史月考 / 进入评分点评）。
  final VoidCallback? onOpenExamReview;

  /// 任课老师 / 班主任「我的请假」入口：查看本人请假记录并发起申请。
  final VoidCallback? onOpenMyTeacherLeave;

  /// 班主任「请假审批」入口：进入审批本班学生请假申请的页面（4 张统计卡 +
  /// 提示与备案说明 + 6 状态 tabs + 搜索框 + 双列申请卡片，审批中卡片
  /// 底部"通过 / 驳回"按钮，"驳回"打开 `GradientHeaderDialog` 弹窗）。
  final VoidCallback? onOpenLeaveApproval;

  /// 班主任「查寝动态」入口：进入掌握本班住宿生归宿与晨检结果的页面
  /// （4 张统计卡 + tabs「本班查纪 / 补卡审核」+ 学生口径 / 宿舍口径
  /// 卡片网格 + 全部 / 异常 toggle）。
  final VoidCallback? onOpenDormDynamic;

  /// 班主任「查寝历史」入口：按自然日查看本班住宿生晚查寝/晨查寝打卡
  /// 汇总（顶部 banner + 14 天日期条 + 4 张统计卡 + 晚查寝/晨查寝 tabs +
  /// 宿舍口径 / 学生口径混合卡片网格）。
  final VoidCallback? onOpenDormHistory;

  /// 班主任「家校沟通」入口：与本班学生家长就请假、成绩、心理等进行
  /// 文字沟通（banner + 3 张统计卡 + 全部/未读/待回复 tabs + 搜索 +
  /// 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
  final VoidCallback? onOpenHomeSchool;

  /// 切换 dashboard 中「任课老师 / 班主任」tab 时的回调：通常由
  /// [SmartCampusPage] 传 `controller.selectRole`，让管理员的切换持久化到
  /// 全局 state；普通教师没有班主任权限时 `selectRole` 会被忽略，UI 也
  /// 不会切换——这是合理的业务约束。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 管理员等多身份用户使用的悬浮身份切换器；教师/班主任传 null。
  final Widget? roleSwitcher;

  @override
  ConsumerState<TeacherDashboardLayout> createState() =>
      _TeacherDashboardLayoutState();
}

class _TeacherDashboardLayoutState
    extends ConsumerState<TeacherDashboardLayout> {
  late SmartCampusRole _localTab;
  List<SmartCampusStatCardData> _stats = const [];
  List<SmartCampusQuickActionData> _actions = const [];
  CourseTeacherIndexRes? _courseTeacherIndex;
  List<_BoardItemData> _headTeacherTodos = const [];
  List<_BoardItemData> _headTeacherRecent = const [];

  @override
  void initState() {
    super.initState();
    _localTab = _coerceRole(widget.selectedRole);
    _syncPlaceholderData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeData());
  }

  void _syncPlaceholderData() {
    final data = smartCampusDashboardDataForRole(_localTab);
    _stats = data.stats;
    _actions = data.actions;
    _headTeacherTodos = const [];
    _headTeacherRecent = const [];
    _courseTeacherIndex = null;
  }

  @override
  void didUpdateWidget(covariant TeacherDashboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      _localTab = _coerceRole(widget.selectedRole);
      _syncPlaceholderData();
      _loadHomeData();
    }
  }

  // 仅允许 tab 在 teacher / headTeacher 之间切换；其他角色容错回退到 teacher。
  SmartCampusRole _coerceRole(SmartCampusRole role) {
    if (role == SmartCampusRole.teacher ||
        role == SmartCampusRole.headTeacher) {
      return role;
    }
    return SmartCampusRole.teacher;
  }

  void _selectTab(SmartCampusRole role) {
    // 跨端身份（admin / dormManager / student）：本地预览没意义（教师
    // dashboard 不能渲染管理员视图），直接交给 controller 切换 state，
    // SmartCampusPage 会重新路由到目标身份的大 dashboard，本 widget 卸载。
    if (role != SmartCampusRole.teacher &&
        role != SmartCampusRole.headTeacher) {
      widget.onSelectRole?.call(role);
      return;
    }
    if (_localTab == role) {
      return;
    }
    // 立刻给 UI 一个回应（任何账号都能点）；
    // 同时把切换持久化给 controller：admin / 多身份教师会写入 state，
    // 单身份的普通教师被 ignore（仅保留本地预览效果）。
    setState(() {
      _localTab = role;
      _syncPlaceholderData();
    });
    widget.onSelectRole?.call(role);
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (_localTab == SmartCampusRole.headTeacher) {
      await _loadHeadTeacherHome();
    } else {
      await _loadCourseTeacherHome();
    }
  }

  Future<void> _loadCourseTeacherHome() async {
    if (!mounted) return;
    final repo = ref.read(teacherRepositoryProvider);
    final now = DateTime.now();
    final weekRange = _currentWeekDateRange(now);

    try {
      final results = await Future.wait([
        repo.courseTeacherIndex(),
        repo.courseList(beginDate: weekRange.$1, endDate: weekRange.$2),
      ]);
      if (!mounted) return;

      final indexResp = results[0];
      final weekResp = results[1];
      final weekCount = weekResp.isSuccess
          ? countWeekCoursesFromCourseList(weekResp.data)
          : null;

      if (!indexResp.isSuccess) {
        if (indexResp.msg.isNotEmpty) {
          AppToast.show(context, indexResp.msg);
        }
        return;
      }

      final index = parseCourseTeacherIndexRes(indexResp.data);
      final base = smartCampusDashboardDataForRole(SmartCampusRole.teacher);
      setState(() {
        _courseTeacherIndex = index;
        _stats = buildCourseTeacherStats(
          index: index,
          weekCourseCount: weekCount,
        );
        _actions = _applyActionBadges(
          base.actions,
          buildCourseTeacherActionBadges(index),
        );
      });
    } catch (_) {
      // 保留占位统计，避免首页空白。
    }
  }

  Future<void> _loadHeadTeacherHome() async {
    if (!mounted) return;
    try {
      final resp =
          await ref.read(teacherRepositoryProvider).headTeacherIndex();
      if (!mounted) return;
      if (!resp.isSuccess) {
        if (resp.msg.isNotEmpty) {
          AppToast.show(context, resp.msg);
        }
        return;
      }

      final index = parseHeadTeacherIndexRes(resp.data);
      final base = smartCampusDashboardDataForRole(SmartCampusRole.headTeacher);
      setState(() {
        _stats = buildHeadTeacherStats(index);
        _actions = _applyActionBadges(
          base.actions,
          buildHeadTeacherActionBadges(index),
        );
        _headTeacherTodos = _mapHeadTeacherBoardItems(
          buildHeadTeacherTodoBoardItems(index),
        );
        _headTeacherRecent = _mapHeadTeacherBoardItems(
          buildHeadTeacherRecentBoardItems(index),
        );
      });
    } catch (_) {
      // 保留占位统计，避免首页空白。
    }
  }

  List<SmartCampusQuickActionData> _applyActionBadges(
    List<SmartCampusQuickActionData> base,
    Map<String, int> badges,
  ) {
    return [
      for (final item in base)
        SmartCampusQuickActionData(
          label: item.label,
          icon: item.icon,
          background: item.background,
          foreground: item.foreground,
          badge: badges[item.label] ?? item.badge,
          imagePath: item.imagePath,
        ),
    ];
  }

  List<_BoardItemData> _mapHeadTeacherBoardItems(
    List<HeadTeacherBoardItem> items,
  ) {
    return [
      for (final item in items)
        _BoardItemData(
          time: item.time,
          title: item.title,
          tag: item.tag,
          tagForeground: _kBoardTagPurple,
          tagBackground: _kBoardTagPurpleSoft,
        ),
    ];
  }

  (String, String) _currentWeekDateRange(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    final sunday = monday.add(const Duration(days: 6));
    return (_isoDate(monday), _isoDate(sunday));
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(_localTab);

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.roleSwitcher != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.roleSwitcher,
                  ),
                  SizedBox(height: ui(12)),
                ],
                _TeacherMainColumn(
                  data: data,
                  stats: _stats,
                  actions: _actions,
                  courseTeacherIndex: _courseTeacherIndex,
                  headTeacherTodos: _headTeacherTodos,
                  headTeacherRecent: _headTeacherRecent,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  onOpenMyClass: widget.onOpenMyClass,
                  onOpenClassWorkbench: widget.onOpenClassWorkbench,
                  onOpenMySchedule: widget.onOpenMySchedule,
                  onOpenCheckIn: widget.onOpenCheckIn,
                  onOpenMyHomework: widget.onOpenMyHomework,
                  onOpenMyGrades: widget.onOpenMyGrades,
                  onOpenGroupChat: widget.onOpenGroupChat,
                  onOpenSchoolCircle: widget.onOpenSchoolCircle,
                  onOpenLeaveManagement: widget.onOpenLeaveManagement,
                  onOpenDormCheck: widget.onOpenDormCheck,
                  onOpenClassAttendance: widget.onOpenClassAttendance,
                  onOpenStudentRoster: widget.onOpenStudentRoster,
                  onOpenHomeworkReview: widget.onOpenHomeworkReview,
                  onOpenExamReview: widget.onOpenExamReview,
                  onOpenMyTeacherLeave: widget.onOpenMyTeacherLeave,
                  onOpenLeaveApproval: widget.onOpenLeaveApproval,
                  onOpenDormDynamic: widget.onOpenDormDynamic,
                  onOpenDormHistory: widget.onOpenDormHistory,
                  onOpenHomeSchool: widget.onOpenHomeSchool,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  width: cw,
                  selectedTab: _localTab,
                  onTabSelected: _selectTab,
                  availableRoles: widget.availableRoles,
                  shellDisplayName: widget.shellDisplayName,
                  avatarUrl: widget.avatarUrl,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _TeacherMainColumn(
                data: data,
                stats: _stats,
                actions: _actions,
                courseTeacherIndex: _courseTeacherIndex,
                headTeacherTodos: _headTeacherTodos,
                headTeacherRecent: _headTeacherRecent,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                onOpenMyClass: widget.onOpenMyClass,
                onOpenClassWorkbench: widget.onOpenClassWorkbench,
                onOpenMySchedule: widget.onOpenMySchedule,
                onOpenCheckIn: widget.onOpenCheckIn,
                onOpenMyHomework: widget.onOpenMyHomework,
                onOpenMyGrades: widget.onOpenMyGrades,
                onOpenGroupChat: widget.onOpenGroupChat,
                onOpenSchoolCircle: widget.onOpenSchoolCircle,
                onOpenLeaveManagement: widget.onOpenLeaveManagement,
                onOpenDormCheck: widget.onOpenDormCheck,
                onOpenClassAttendance: widget.onOpenClassAttendance,
                onOpenStudentRoster: widget.onOpenStudentRoster,
                onOpenHomeworkReview: widget.onOpenHomeworkReview,
                onOpenExamReview: widget.onOpenExamReview,
                onOpenMyTeacherLeave: widget.onOpenMyTeacherLeave,
                onOpenLeaveApproval: widget.onOpenLeaveApproval,
                onOpenDormDynamic: widget.onOpenDormDynamic,
                onOpenDormHistory: widget.onOpenDormHistory,
                onOpenHomeSchool: widget.onOpenHomeSchool,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                width: sidebarWidth,
                selectedTab: _localTab,
                onTabSelected: _selectTab,
                availableRoles: widget.availableRoles,
                shellDisplayName: widget.shellDisplayName,
                avatarUrl: widget.avatarUrl,
                fillHeight: true,
              ),
            ),
            if (widget.roleSwitcher != null)
              Positioned(
                top: ui(6),
                right: sidebarWidth + ui(8),
                child: widget.roleSwitcher!,
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 主区：顶部统计行 + 中间浅紫面板（功能矩阵）
// =============================================================================

class _TeacherMainColumn extends StatelessWidget {
  const _TeacherMainColumn({
    required this.data,
    required this.stats,
    required this.actions,
    this.courseTeacherIndex,
    this.headTeacherTodos = const [],
    this.headTeacherRecent = const [],
    required this.width,
    required this.fillRemaining,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final SmartCampusDashboardData data;
  final List<SmartCampusStatCardData> stats;
  final List<SmartCampusQuickActionData> actions;
  final CourseTeacherIndexRes? courseTeacherIndex;
  final List<_BoardItemData> headTeacherTodos;
  final List<_BoardItemData> headTeacherRecent;
  final double width;
  final bool fillRemaining;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenMyTeacherLeave;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormDynamic;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final actionPanel = _TeacherActionPanel(
      data: data,
      actions: actions,
      onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      onOpenMyClass: onOpenMyClass,
      onOpenClassWorkbench: onOpenClassWorkbench,
      onOpenMySchedule: onOpenMySchedule,
      onOpenCheckIn: onOpenCheckIn,
      onOpenMyHomework: onOpenMyHomework,
      onOpenMyGrades: onOpenMyGrades,
      onOpenGroupChat: onOpenGroupChat,
      onOpenSchoolCircle: onOpenSchoolCircle,
      onOpenLeaveManagement: onOpenLeaveManagement,
      onOpenDormCheck: onOpenDormCheck,
      onOpenClassAttendance: onOpenClassAttendance,
      onOpenStudentRoster: onOpenStudentRoster,
      onOpenHomeworkReview: onOpenHomeworkReview,
      onOpenExamReview: onOpenExamReview,
      onOpenMyTeacherLeave: onOpenMyTeacherLeave,
      onOpenLeaveApproval: onOpenLeaveApproval,
      onOpenDormDynamic: onOpenDormDynamic,
      onOpenDormHistory: onOpenDormHistory,
      onOpenHomeSchool: onOpenHomeSchool,
    );

    // 任课老师：当前课程 + 今日课表；班主任：待办提醒 + 近期动态。
    Widget bottomSection({required bool fill}) {
      if (data.role == SmartCampusRole.headTeacher) {
        return _HeadTeacherBoardSection(
          fillRemaining: fill,
          todoItems: headTeacherTodos,
          recentItems: headTeacherRecent,
        );
      }
      return _TeacherScheduleSection(
        fillRemaining: fill,
        onOpenSchedule: onOpenMySchedule,
        courseTeacherIndex: courseTeacherIndex,
      );
    }

    if (fillRemaining) {
      // 父级 (Stack > Positioned(top:0,bottom:0)) 提供了有界高度。
      // 让底部双卡 Expanded 撑满剩余空间。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          Expanded(child: bottomSection(fill: true)),
        ],
      );
    }

    // 紧凑模式（compact）：父级高度无界，整个主列交给滚动容器承载。
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          bottomSection(fill: false),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _TeacherStatRow extends StatelessWidget {
  const _TeacherStatRow({required this.stats, required this.width});

  final List<SmartCampusStatCardData> stats;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    final ui = DashboardScaleScope.of(context).ui;
    // 父级（Column / ScrollView）纵向高度通常无界；这里先用 SizedBox 给一个
    // 有界高度（67），Row 内部就可以安全使用 stretch 让 6 张卡等高铺满。
    return SizedBox(
      width: width.isFinite && width > 0 ? width : null,
      height: ui(67),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            Expanded(child: _TeacherStatCard(item: stats[i])),
          ],
        ],
      ),
    );
  }
}

class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard({required this.item});

  final SmartCampusStatCardData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

  // 紫色「下一节 15:30」卡 / 班主任端「待办 9」卡：紫字在上、灰色标签在下。
    final isNextLesson = item.label == '下一节' || item.label == '待办';
    final valueColor = isNextLesson
        ? const Color(0xFF8741FF)
        : const Color(0xFF0B081A);
    // 含中文的值（如「周三」「今天」「已过」）回退到系统字体后，同字号下视觉
    // 比 Barlow 数字大很多；改用 PingFang SC 并下调字号，使其与数字视觉接近。
    final isTextValue = RegExp(r'[\u4e00-\u9fff]').hasMatch(item.value);
    final value = Text(
      item.value,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: isTextValue
          ? TextStyle(
              fontSize: ui(18),
              color: valueColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1.0,
            )
          : smartCampusStatValueTextStyle(ui, color: valueColor),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.07),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(child: value),
          ),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF6D6B75),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionPanel extends StatelessWidget {
  const _TeacherActionPanel({
    required this.data,
    required this.actions,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormDynamic,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final SmartCampusDashboardData data;
  final List<SmartCampusQuickActionData> actions;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenMyTeacherLeave;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormDynamic;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  VoidCallback? _onTapForLabel(String label) {
    switch (label) {
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '我的班级':
        return onOpenMyClass;
      case '班级工作台':
        // 班主任专属入口：进入独立三 Tab 工作台（概况 / 学生管理 / 成绩），
        // 与学生「我的班级」简版页面分开，避免 selectedRole 误判路由到学生页。
        return onOpenClassWorkbench;
      // "授课课表"是老师端 label，"我的课表"是学生端 label，
      // 但都对应同一个 mainView 切换 (`openMySchedule`)。
      case '授课课表':
      case '我的课表':
        return onOpenMySchedule;
      // 学生端独有：课堂签到。老师端没这个按钮，回调可能为 null，由
      // _TeacherActionTile 兜底弹"页面迁移中"SnackBar。
      case '课堂签到':
        return onOpenCheckIn;
      // 学生端独有：我的作业。老师端的 "作业批改" 是另一条入口，单独处理。
      case '我的作业':
        return onOpenMyHomework;
      // 学生端独有：我的考试，进入「我的考试」总览页（全部考试 + 我的成绩）。
      case '我的考试':
        return onOpenMyGrades;
      // 五端共用：群聊（任一角色点击都进入同一聊天主界面）。
      case '群聊':
        return onOpenGroupChat;
      // 学生 / 教师 / 班主任 / 宿管 共用：「校圈」按钮 → 跳转到首页同名校圈
      // 全屏页（CirclePage / RoutePaths.circle）。学生历史 label 是 "校园"，
      // 数据层已统一改为 "校圈"。
      case '校圈':
        return onOpenSchoolCircle;
      // 学生端「我的请假」与教师端同名；学生传 onOpenLeaveManagement，教师传
      // onOpenMyTeacherLeave，按非空回调区分。
      case '我的请假':
        return onOpenLeaveManagement ?? onOpenMyTeacherLeave;
      // 学生端独有：「我的查寝」→ 进入个人查寝/补卡页面。
      case '我的查寝':
        return onOpenDormCheck;
      // 任课老师/班主任专属：「签课管理」→ 进入授课签到总览页（5 项统计 +
      // 最近签课记录 + 今日课程 + 大课/小课双模签到操作面板）。
      case '签课管理':
        return onOpenClassAttendance;
      // 任课老师/班主任专属：「学生名册」→ 进入名册总览页（班级 dropdown +
      // 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
      case '学生名册':
        return onOpenStudentRoster;
      // 任课老师/班主任专属：「作业批改」→ 进入"作业与批改"总览页（4 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业
      // 列表 + 右当前作业的提交学生表，支持发布作业 / 历史发布记录 /
      // 作业点评 3 个右抽屉）。
      case '作业批改':
        return onOpenHomeworkReview;
      // 任课老师/班主任专属：「考评管理」→ 进入"考评管理"总览页（5 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表
      // (N/M 提交比) + 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)；
      // 仅可查看与评分，不可新建考试，通过右抽屉历史月考 / 评分 进入操作）。
      case '考评管理':
        return onOpenExamReview;
      // 班主任专属：「请假审批」→ 进入审批本班学生请假申请的总览页（4 张
      // 统计卡 + 提示与备案说明 + 6 状态 tabs + 搜索 + 双列申请卡片，审批中
      // 卡片底部"通过 / 驳回"按钮，"驳回"打开 GradientHeaderDialog 弹窗）。
      case '请假审批':
        return onOpenLeaveApproval;
      // 班主任专属：「查寝动态」→ 进入掌握本班住宿生归宿与晨检结果、协同
      // 处理补卡与异常跟进的总览页（4 张统计卡 + 「本班查纪 / 补卡审核」
      // tabs + 搜索 + 「全部异常记录 N 条」+ 全部 / 异常 toggle + 学生口径
      // 与宿舍口径两类卡片网格）。
      case '查寝动态':
        return onOpenDormDynamic;
      // 班主任专属：「查寝历史」→ 进入按自然日查看本班住宿生晚查寝/晨查寝
      // 打卡汇总的总览页（顶部 banner + 14 天日期条 + 4 张统计卡 +
      // 晚查寝 / 晨查寝 tabs + 宿舍口径 / 学生口径混合卡片网格）。
      case '查寝历史':
        return onOpenDormHistory;
      // 班主任专属：「家校沟通」→ 进入与本班学生家长就请假/成绩/心理等
      // 进行文字沟通的总览页（banner + 3 张统计卡 + 全部/未读/待回复 tabs
      // + 搜索 + 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
      case '家校沟通':
        return onOpenHomeSchool;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Figma：容器 H 255、padding 38/24/38/24；按钮 82×70；一行 5 个。
    // 老师端共 8 个 → 2 行（5 + 3）。横向间距由 spaceBetween 在剩余空间内
    // 均分（标准设计宽下 ≈ 21px）；纵向两行间距由 Column.spaceBetween
    // 在剩余 (255 − 76 − 70×2) = 39px 内分配。
    const cross = 5;
    final rowsCount = actions.isEmpty ? 0 : ((actions.length - 1) ~/ cross) + 1;
    final rows = <Widget>[
      for (var r = 0; r < rowsCount; r++)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var c = 0; c < cross; c++)
              SizedBox(
                width: ui(82),
                height: ui(70),
                child: _buildSlot(r * cross + c, actions),
              ),
          ],
        ),
    ];

    return Container(
      width: double.infinity,
      height: ui(255),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(38)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: rowsCount > 1
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildSlot(int idx, List<SmartCampusQuickActionData> actions) {
    if (idx >= actions.length) {
      return const SizedBox.shrink();
    }
    final item = actions[idx];
    return _TeacherActionTile(item: item, onTap: _onTapForLabel(item.label));
  }
}

class _TeacherActionTile extends StatelessWidget {
  const _TeacherActionTile({required this.item, this.onTap});

  final SmartCampusQuickActionData item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final box = ui(38);

    Widget iconBox;
    if (item.imagePath != null) {
      iconBox = Image.asset(
        item.imagePath!,
        width: box,
        height: box,
        fit: BoxFit.contain,
      );
    } else {
      iconBox = Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: item.background,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Icon(item.icon, size: ui(22), color: item.foreground),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(ui(12)),
      // 没有具体跳转的按钮也要给反馈，避免"点了没反应"。
      onTap: onTap ?? () => _showActionPending(context, item.label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              iconBox,
              if (item.badge > 0 && item.label != '群聊')
                Positioned(
                  right: ui(-10),
                  top: ui(-4),
                  child: Container(
                    constraints: BoxConstraints(minWidth: ui(24)),
                    height: ui(16),
                    padding: EdgeInsets.symmetric(horizontal: ui(5)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF04545),
                      borderRadius: BorderRadius.circular(ui(20)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.badge > 99 ? '99+' : '${item.badge}+',
                      style: TextStyle(
                        fontSize: ui(9),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 右栏：头像 + 运行中 + 岗位信息 + Tab + 通知
// =============================================================================

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.data,
    required this.width,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.fillHeight,
    this.shellUser = const ShellUser(),
    this.studentDormBedLabel,
    this.selectedTab,
    this.onTabSelected,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
  });

  final SmartCampusDashboardData data;
  final double width;
  // 学生端无身份切换：两者均为 null 时整个切换区不渲染。
  final SmartCampusRole? selectedTab;
  final ValueChanged<SmartCampusRole>? onTabSelected;

  /// 来自 [TeacherDashboardLayout.availableRoles]。当包含 teacher /
  /// headTeacher 之外的身份（admin / dormManager / student）时，使用通
  /// 用的 [RoleSwitcherButtons]；只剩任课老师 + 班主任两枚时退回原先的
  /// 固定 2 Tab，保留单身份教师"本地预览"的演示体验。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final ShellUser shellUser;

  /// 学生端侧栏「宿舍床位」文案；`null` 表示尚未加载。
  final String? studentDormBedLabel;
  final bool fillHeight;

  /// 判断是否需要走"通用多身份"切换器：只要 availableRoles 出现 teacher /
  /// headTeacher 之外的成员（典型场景：管理员账户、跨端老师），就升级到
  /// 全量按钮列表。
  bool get _hasExtraRoles {
    for (final role in availableRoles) {
      if (role != SmartCampusRole.teacher &&
          role != SmartCampusRole.headTeacher) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final card = Container(
      width: width.isFinite && width > 0 ? width : ui(256),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.06),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeacherProfileBlock(
              data: data,
              shellDisplayName: shellDisplayName,
              avatarUrl: avatarUrl,
              shellUser: shellUser,
              studentDormBedLabel: studentDormBedLabel,
            ),
            SizedBox(height: ui(20)),
            if (selectedTab != null && onTabSelected != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                // 多身份用户（admin / 跨端教师）走通用按钮组，按 availableRoles
                // 渲染；普通"任课老师 + 班主任"仍走原 2 Tab 以保留单身份
                // 教师在演示账号下"本地预览"班主任视图的体验。
                child: _hasExtraRoles
                    ? RoleSwitcherButtons(
                        availableRoles: availableRoles,
                        selectedRole: selectedTab!,
                        onSelectRole: onTabSelected!,
                      )
                    : _TeacherRoleTabs(
                        selected: selectedTab!,
                        onChanged: onTabSelected!,
                      ),
              ),
              SizedBox(height: ui(28)),
            ],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              child: Text(
                '通知',
                style: TextStyle(
                  fontSize: ui(16),
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            if (fillHeight)
              Expanded(
                child: _TeacherNoticePanel(
                  role: selectedTab ?? data.role,
                  fallbackNotices: data.notices,
                  scrollable: true,
                ),
              )
            else
              _TeacherNoticePanel(
                role: selectedTab ?? data.role,
                fallbackNotices: data.notices,
                scrollable: false,
              ),
            SizedBox(height: ui(16)),
          ],
        ),
      ),
    );
    return card;
  }
}

class _TeacherProfileBlock extends StatelessWidget {
  const _TeacherProfileBlock({
    required this.data,
    required this.shellDisplayName,
    required this.avatarUrl,
    this.shellUser = const ShellUser(),
    this.studentDormBedLabel,
  });

  final SmartCampusDashboardData data;
  final String shellDisplayName;
  final String avatarUrl;
  final ShellUser shellUser;
  final String? studentDormBedLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final profile = data.profile;
    final displayName = shellDisplayName.isNotEmpty
        ? shellDisplayName
        : profile.name;
    final isStudent = data.role == SmartCampusRole.student;
    final isHeadTeacher = data.role == SmartCampusRole.headTeacher;
    final roleFallback = isStudent
        ? '学生'
        : (isHeadTeacher ? '班主任' : '任课老师');
    final statusLabel = isStudent ? '在校' : '运行中';
    final infoLines = isStudent
        ? _studentInfoLines(
            shellUser,
            dormBedLabel: studentDormBedLabel,
          )
        : (isHeadTeacher
            ? _headTeacherInfoLines()
            : _courseTeacherInfoLines());

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TeacherAvatar(
                    avatarUrl: avatarUrl,
                    size: ui(72),
                    fallbackName: displayName,
                  ),
                  SizedBox(width: ui(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: ui(8)),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName.isEmpty ? roleFallback : displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(16),
                                  height: 1.2,
                                  fontWeight: AppFont.w500,
                                  color: const Color(0xFF0B081A),
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ),
                            SizedBox(width: ui(6)),
                            _TeacherStatusChip(
                              label: statusLabel,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(20)),
              _TeacherDetailLines(lines: infoLines),
            ],
          ),
          Positioned(
            left: ui(18),
            top: ui(60),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(7),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE5FF),
                borderRadius: BorderRadius.circular(ui(10)),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                profile.badgeLabel.isNotEmpty ? profile.badgeLabel : roleFallback,
                style: TextStyle(
                  fontSize: ui(11),
                  height: 1.2,
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 学生侧栏信息行（来自 myInfo.user + myDormitoryInfo）。
List<String> _studentInfoLines(
  ShellUser user, {
  String? dormBedLabel,
}) {
  String display(String value) =>
      value.trim().isEmpty ? '—' : value.trim();
  final lines = <String>[
    '性别：${display(user.gender)}',
    '学校：${display(user.school)}',
    '目标院校：${display(user.targetSchool)}',
  ];
  if (dormBedLabel != null) {
    lines.add('宿舍床位：${display(dormBedLabel)}');
  }
  return lines;
}

/// 班主任侧栏信息行（不依赖班级接口，对齐管理员「岗位 / 权限 / 职责」结构）。
List<String> _headTeacherInfoLines() {
  return const [
    '岗位：班主任',
    '权限：本班班务管理',
    '职责：请假查寝、班务协同与家校沟通',
  ];
}

/// 任课老师侧栏信息行（与班主任同一结构，文案按授课场景）。
List<String> _courseTeacherInfoLines() {
  return const [
    '岗位：任课老师',
    '权限：授课与课堂管理',
    '职责：按课表授课，负责签到、批改与课堂反馈',
  ];
}

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({
    required this.avatarUrl,
    required this.size,
    this.fallbackName,
  });

  final String avatarUrl;
  final double size;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget child;
    if (avatarUrl.isNotEmpty) {
      child = Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(ui),
      );
    } else {
      child = _fallback(ui);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: child),
    );
  }

  Widget _fallback(double Function(double) ui) {
    final name = fallbackName?.trim() ?? '';
    if (name.isNotEmpty) {
      return Container(
        color: const Color(0xFFEAE5FF),
        alignment: Alignment.center,
        child: Text(
          name.characters.first,
          style: TextStyle(
            fontSize: ui(28),
            height: 1.0,
            color: const Color(0xFF8741FF),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFEAE5FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(36),
        color: const Color(0xFF8F63FF),
      ),
    );
  }
}

class _TeacherStatusChip extends StatelessWidget {
  const _TeacherStatusChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui(compact ? 6 : 8),
        vertical: ui(compact ? 3 : 6),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(
          color: const Color(0xFFF3F2F3),
          width: compact ? 0.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: const BoxDecoration(
              color: Color(0xFF12C58A),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(compact ? 11 : 12),
              color: const Color(0xFF0B081A),
              fontWeight: compact ? AppFont.w400 : FontWeight.w400,
              height: 1.0,
              fontFamily: compact ? 'PingFang SC' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDetailLines extends StatelessWidget {
  const _TeacherDetailLines({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) ...[
          _TeacherDetailLine(line: line),
          SizedBox(height: ui(4)),
        ],
      ],
    );
  }
}

class _TeacherDetailLine extends StatelessWidget {
  const _TeacherDetailLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final idx = line.indexOf('：');
    final label = idx >= 0 ? line.substring(0, idx + 1) : '';
    final value = idx >= 0 ? line.substring(idx + 1) : line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabs extends StatelessWidget {
  const _TeacherRoleTabs({required this.selected, required this.onChanged});

  final SmartCampusRole selected;
  final ValueChanged<SmartCampusRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _TeacherRoleTabButton(
            label: '任课老师',
            active: selected == SmartCampusRole.teacher,
            onTap: () => onChanged(SmartCampusRole.teacher),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _TeacherRoleTabButton(
            label: '班主任',
            active: selected == SmartCampusRole.headTeacher,
            onTap: () => onChanged(SmartCampusRole.headTeacher),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabButton extends StatelessWidget {
  const _TeacherRoleTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : const Color(0xFF0B081A),
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TeacherNoticePanel extends ConsumerStatefulWidget {
  const _TeacherNoticePanel({
    required this.role,
    required this.fallbackNotices,
    required this.scrollable,
  });

  final SmartCampusRole role;
  final List<SmartCampusNoticeData> fallbackNotices;
  final bool scrollable;

  @override
  ConsumerState<_TeacherNoticePanel> createState() =>
      _TeacherNoticePanelState();
}

class _TeacherNoticePanelState extends ConsumerState<_TeacherNoticePanel> {
  List<TeacherNoticeListItem> _notices = const [];

  bool get _usesNoticeApi =>
      widget.role == SmartCampusRole.teacher ||
      widget.role == SmartCampusRole.headTeacher ||
      widget.role == SmartCampusRole.student;

  @override
  void initState() {
    super.initState();
    if (_usesNoticeApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotices());
    }
  }

  @override
  void didUpdateWidget(covariant _TeacherNoticePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role && _usesNoticeApi) {
      _loadNotices();
    }
  }

  Future<void> _loadNotices() async {
    if (!_usesNoticeApi) return;
    try {
      final ApiResponse resp;
      if (widget.role == SmartCampusRole.student) {
        resp = await ref.read(studentRepositoryProvider).noticeList(size: 20);
      } else {
        final repo = ref.read(teacherRepositoryProvider);
        resp = widget.role == SmartCampusRole.headTeacher
            ? await repo.headTeacherNoticeList(size: 20)
            : await repo.courseTeacherNoticeList(size: 20);
      }
      if (!mounted) return;
      if (!resp.isSuccess) {
        setState(() {
          _notices = const [];
        });
        return;
      }
      setState(() {
        _notices = parseTeacherNoticeList(resp.data);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notices = const [];
      });
    }
  }

  Future<void> _openNoticeDetail(TeacherNoticeListItem item) async {
    final ApiResponse resp;
    if (widget.role == SmartCampusRole.student) {
      resp = await ref.read(studentRepositoryProvider).noticeDetail(id: item.id);
    } else {
      resp = await ref.read(teacherRepositoryProvider).noticeDetail(id: item.id);
    }
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isNotEmpty ? resp.msg : '通知详情加载失败',
      );
      return;
    }
    final detail = parseTeacherNoticeDetail(resp.data);
    if (detail == null) {
      AppToast.show(context, '通知详情加载失败');
      return;
    }
    await showNoticeDetailDialog<void>(
      context: context,
      builder: (ctx) => GradientHeaderDialog(
        title: '通知详情',
        width: 460,
        child: _TeacherSchoolNoticeDetailBody(notice: detail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usesNoticeApi) {
      return _TeacherNoticeList(
        items: _notices,
        scrollable: widget.scrollable,
        onTap: _openNoticeDetail,
      );
    }
    return _TeacherNoticeFallbackList(
      notices: widget.fallbackNotices,
      scrollable: widget.scrollable,
    );
  }
}

class _TeacherNoticeFallbackList extends StatelessWidget {
  const _TeacherNoticeFallbackList({
    required this.notices,
    required this.scrollable,
  });

  final List<SmartCampusNoticeData> notices;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final children = <Widget>[];
    for (var i = 0; i < notices.length; i++) {
      if (i > 0) children.add(SizedBox(height: ui(8)));
      children.add(_TeacherNoticeCard(item: notices[i]));
    }
    final list = Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
    if (scrollable) {
      return SingleChildScrollView(child: list);
    }
    return list;
  }
}

class _TeacherNoticeList extends StatelessWidget {
  const _TeacherNoticeList({
    required this.items,
    required this.scrollable,
    required this.onTap,
  });

  final List<TeacherNoticeListItem> items;
  final bool scrollable;
  final ValueChanged<TeacherNoticeListItem> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Text(
          '暂无通知',
          style: TextStyle(
            fontSize: ui(12),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(SizedBox(height: ui(8)));
      final item = items[i];
      final style = item.tagStyle;
      children.add(
        _TeacherNoticeCard(
          item: SmartCampusNoticeData(
            tag: item.tag,
            title: item.title,
            time: item.time,
            tagForeground: style.foreground,
            tagBackground: style.background,
            unread: item.priority.isNotEmpty && item.priority != '普通',
          ),
          onTap: () => onTap(item),
        ),
      );
    }
    final list = Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
    if (scrollable) {
      return SingleChildScrollView(child: list);
    }
    return list;
  }
}

class _TeacherSchoolNoticeDetailBody extends StatelessWidget {
  const _TeacherSchoolNoticeDetailBody({required this.notice});

  final TeacherNoticeListItem notice;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = notice.tagStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          notice.title,
          style: TextStyle(
            fontSize: ui(15),
            color: const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: ui(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(6),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: tagStyle.background,
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                notice.tag,
                style: TextStyle(
                  fontSize: ui(12),
                  color: tagStyle.foreground,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (notice.author.isNotEmpty && notice.author != '—') ...[
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  notice.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ui(16)),
        _TeacherNoticeDetailRow(label: '类型', value: notice.type),
        if (notice.priority.isNotEmpty)
          _TeacherNoticeDetailRow(label: '优先级', value: notice.priority),
        if (notice.scopeLabel.isNotEmpty && notice.scopeLabel != '—')
          _TeacherNoticeDetailRow(label: '推送范围', value: notice.scopeLabel),
        _TeacherNoticeDetailRow(
          label: '时间',
          value: notice.publishedAt.isNotEmpty ? notice.publishedAt : notice.time,
          isLast: true,
        ),
        SizedBox(height: ui(12)),
        Text(
          '内容',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            notice.content.isEmpty ? '（暂无正文）' : notice.content,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherNoticeDetailRow extends StatelessWidget {
  const _TeacherNoticeDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : ui(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(64),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherNoticeCard extends StatelessWidget {
  const _TeacherNoticeCard({required this.item, this.onTap});

  final SmartCampusNoticeData item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(16), ui(10)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: item.tagBackground,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: ui(10),
                        color: item.tagForeground,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF0B081A),
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(4)),
              SizedBox(
                width: double.infinity,
                child: Text(
                  item.time,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFCECED1),
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 当前课程 + 今日课表（白色双卡区）
//
// 视觉与班主任端 `_HeadTeacherBoardSection` 保持一致：
//   - 标题在白卡之外（"当前课程" / "今日课表"），无额外操作按钮
//   - 顶部 ui(12) 间距 + 标题→白卡 ui(20)
//   - 数据来自 `/app/school/v2/teacher/courseList`（当日）+ `schoolTimeConfigList`（节次时间）
//   - 白卡 padding 12 / radius 16 / 浅阴影
//   - 白卡内部为灰底（#F5F6FA, radius 12）子卡，子卡右上 L 型角标承载状态色
//   - 子卡时段用 Text.rich 三段式（起 #1A1A1A 600 / "- " #B6B5BB 600 / 止 #0B081A 600）
//   - 老师行：渐变首字头像 + 姓名 14 600 + 课程标签（颜色背景）+ 圆点+大小课白底标签
//   - 数据为空时白卡保留，并展示占位文案
// =============================================================================

class _LessonRowData {
  const _LessonRowData({
    required this.avatarSeed,
    required this.logoUrl,
    required this.teacherName,
    required this.courseName,
    required this.courseColor,
    required this.courseBg,
    required this.tag,
    required this.tagDotColor,
    required this.hint,
    this.avatarUrl = '',
    this.preferLogoOverAvatar = false,
  });

  final String avatarSeed;
  final String logoUrl;
  /// 任课老师头像；学生端课表优先展示；教师端在无 logo 时作回退。
  final String avatarUrl;
  /// true：先 [logoUrl] 再 [avatarUrl]；false：先 [avatarUrl] 再 [logoUrl]。
  final bool preferLogoOverAvatar;
  final String teacherName;
  final String courseName;
  final Color courseColor;
  final Color courseBg;
  final String tag;
  final Color tagDotColor;
  final String hint;
}

class _LessonScheduleData {
  const _LessonScheduleData({
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.teachers,
    this.isPast = false,
  });

  final String time;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final List<_LessonRowData> teachers;
  final bool isPast;
}

class _DashboardTimeConfig {
  const _DashboardTimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<_DashboardTimeConfig> _kDefaultDashboardTimeConfigs = [
  _DashboardTimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _DashboardTimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _DashboardTimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _DashboardTimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _DashboardTimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

enum _LessonSlotPhase { inProgress, upcoming, ended }

class _TeacherScheduleSection extends ConsumerStatefulWidget {
  const _TeacherScheduleSection({
    this.fillRemaining = false,
    this.onOpenSchedule,
    this.courseTeacherIndex,
  });

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;
  final VoidCallback? onOpenSchedule;
  final CourseTeacherIndexRes? courseTeacherIndex;

  @override
  ConsumerState<_TeacherScheduleSection> createState() =>
      _TeacherScheduleSectionState();
}

class _TeacherScheduleSectionState extends ConsumerState<_TeacherScheduleSection> {
  _LessonScheduleData? _currentLesson;
  List<_LessonScheduleData> _todayLessons = const [];
  int _scheduleLoadGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.courseTeacherIndex != null) {
        _applyCourseTeacherIndex(widget.courseTeacherIndex);
      }
      // 任课老师首页由父级统一拉 courseTeacherIndex；此处不再并行请求
      // courseList，避免两路数据短暂不一致。
    });
  }

  Future<void> _applyCourseTeacherIndex(CourseTeacherIndexRes? index) async {
    if (!mounted || index == null) return;
    final gen = ++_scheduleLoadGen;
    final teacherRepo = ref.read(teacherRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);
    try {
      final built = await _buildScheduleFromCourseTeacherIndex(
        index: index,
        schoolRepo: schoolRepo,
        teacherRepo: teacherRepo,
        timeConfigs: _kDefaultDashboardTimeConfigs,
        now: DateTime.now(),
      );
      if (!mounted || gen != _scheduleLoadGen) return;
      setState(() {
        _currentLesson = built.current;
        _todayLessons = built.today;
      });
    } catch (_) {
      if (!mounted || gen != _scheduleLoadGen) return;
      setState(() {
        _currentLesson = null;
        _todayLessons = const [];
      });
    }
  }

  @override
  void didUpdateWidget(covariant _TeacherScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseTeacherIndex != widget.courseTeacherIndex) {
      _applyCourseTeacherIndex(widget.courseTeacherIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );

    Widget tappableSectionTitle(String title) {
      final child = sectionTitle(title);
      final onTap = widget.onOpenSchedule;
      if (onTap == null) return child;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    final currentPanel = _CurrentLessonPanel(
      lesson: _currentLesson,
      fillHeight: widget.fillRemaining,
      onTap: widget.onOpenSchedule,
    );
    final todayPanel = _TodaySchedulePanel(
      lessons: _todayLessons,
      fillHeight: widget.fillRemaining,
      onTap: widget.onOpenSchedule,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          return Padding(
            padding: EdgeInsets.only(top: ui(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                tappableSectionTitle('当前课程'),
                SizedBox(height: ui(20)),
                currentPanel,
                SizedBox(height: ui(20)),
                tappableSectionTitle('今日课表'),
                SizedBox(height: ui(20)),
                todayPanel,
              ],
            ),
          );
        }

        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: currentPanel),
            SizedBox(width: ui(16)),
            Expanded(child: todayPanel),
          ],
        );

        return Padding(
          padding: EdgeInsets.only(top: ui(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: widget.fillRemaining ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tappableSectionTitle('当前课程')),
                  SizedBox(width: ui(16)),
                  Expanded(child: tappableSectionTitle('今日课表')),
                ],
              ),
              SizedBox(height: ui(20)),
              if (widget.fillRemaining)
                Expanded(child: cardsRow)
              else
                IntrinsicHeight(child: cardsRow),
            ],
          ),
        );
      },
    );
  }
}

class _BuiltDashboardSchedule {
  const _BuiltDashboardSchedule({this.current, required this.today});

  final _LessonScheduleData? current;
  final List<_LessonScheduleData> today;
}

Future<_BuiltDashboardSchedule> _buildScheduleFromCourseTeacherIndex({
  required CourseTeacherIndexRes index,
  required SchoolRepository schoolRepo,
  required TeacherRepository teacherRepo,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) async {
  var configs = timeConfigs;
  final classResp = await teacherRepo.classList(isClassTeacher: 1);
  if (classResp.isSuccess) {
    String? classId;
    for (final m in _scheduleExtractList(classResp)) {
      final id = _schedulePickString(m, ['id', 'classId'], '');
      if (id.isNotEmpty) {
        classId = id;
        break;
      }
    }
    if (classId != null && classId.isNotEmpty) {
      final tcResp = await schoolRepo.schoolTimeConfigList(classId: classId);
      if (tcResp.isSuccess) {
        final parsed = _parseDashboardTimeConfigs(tcResp);
        if (parsed.isNotEmpty) configs = parsed;
      }
    }
  }

  return _buildDashboardScheduleFromIndex(
    index: index,
    timeConfigs: configs,
    now: now,
  );
}

_BuiltDashboardSchedule _buildDashboardScheduleFromIndex({
  required CourseTeacherIndexRes index,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) {
  _LessonScheduleData lessonFromRow(
    Map<String, dynamic> row,
    _LessonSlotPhase phase,
  ) {
    final times = _resolveRowTimes(row, timeConfigs);
    final style = _statusStyle(phase);
    final start = times.start;
    final end = times.end;
    return _LessonScheduleData(
      time: start.isNotEmpty && end.isNotEmpty ? '$start - $end' : '—',
      status: style.label,
      statusColor: style.foreground,
      statusBg: style.background,
      isPast: phase == _LessonSlotPhase.ended,
      teachers: [_lessonRowFromCourse(row, start, end)],
    );
  }

  final currentId = index.currentCourse?['id']?.toString();
  final nextId = index.nextCourse?['id']?.toString();
  // 仅排除「当前课程」卡已展示的那一节；有 currentCourse 时 nextCourse 仍应出现在今日课表。
  final shownInCurrentId =
      index.currentCourse != null ? currentId : nextId;

  _LessonScheduleData? current;
  if (index.currentCourse != null) {
    current = lessonFromRow(
      index.currentCourse!,
      _LessonSlotPhase.inProgress,
    );
  } else if (index.nextCourse != null) {
    current = lessonFromRow(index.nextCourse!, _LessonSlotPhase.upcoming);
  }

  final todayEntries = <({int sortKey, _LessonScheduleData lesson})>[];
  for (final row in index.todayCourseList) {
    final id = row['id']?.toString();
    if (id != null &&
        id.isNotEmpty &&
        shownInCurrentId != null &&
        id == shownInCurrentId) {
      continue;
    }
    final times = _resolveRowTimes(row, timeConfigs);
    final phase = _slotPhase(now, times.start, times.end);
    todayEntries.add((
      sortKey: _dashboardCourseSortKey(row, times.start),
      lesson: lessonFromRow(row, phase),
    ));
  }
  todayEntries.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  final today = todayEntries.map((e) => e.lesson).toList(growable: false);

  return _BuiltDashboardSchedule(current: current, today: today);
}

class _ResolvedRowTimes {
  const _ResolvedRowTimes({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

class _DashboardSlotGroup {
  _DashboardSlotGroup({
    required this.lineNum,
    required this.start,
    required this.end,
    required this.sortKey,
  });

  final int lineNum;
  final String start;
  final String end;
  final int sortKey;
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
}

int _dashboardCourseSortKey(Map<String, dynamic> row, String startHm) {
  final startDt = parseCourseDateTime(
    _schedulePickString(row, ['courseStartTime'], ''),
  );
  if (startDt != null) return startDt.millisecondsSinceEpoch;
  return _hmSortKey(startHm);
}

_ResolvedRowTimes _resolveRowTimes(
  Map<String, dynamic> row,
  List<_DashboardTimeConfig> configs,
) {
  final lineNumRaw = row['lineNum'];
  final lineNum = lineNumRaw is int
      ? lineNumRaw
      : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);

  var start = pickCourseClock(
        _schedulePickString(row, [
          'courseStartTime',
          'timeBegin',
          'startTime',
          'beginTime',
          'start',
        ], ''),
      ) ??
      '';
  var end = pickCourseClock(
        _schedulePickString(row, [
          'courseEndTime',
          'timeEnd',
          'endTime',
          'finishTime',
          'end',
        ], ''),
      ) ??
      '';

  _DashboardTimeConfig? configForLineNum() {
    if (lineNum <= 0) return null;
    for (final c in configs) {
      if (c.lineNum == lineNum) return c;
    }
    if (lineNum <= configs.length) return configs[lineNum - 1];
    return null;
  }

  if (end.isEmpty) {
    final matched = configForLineNum();
    if (matched != null) {
      end = matched.end;
      if (start.isEmpty) start = matched.start;
    }
  }

  if (start.isEmpty) {
    final matched = configForLineNum();
    if (matched != null) {
      start = matched.start;
      if (end.isEmpty) end = matched.end;
    }
  }

  return _ResolvedRowTimes(
    lineNum: lineNum,
    start: _trimDashboardHm(start),
    end: _trimDashboardHm(end),
  );
}

_LessonRowData _lessonRowFromCourse(
  Map<String, dynamic> row,
  String start,
  String end,
) {
  final typeRaw = row['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

  final className = _schedulePickString(row, ['className', 'class'], '');
  final teacher = _schedulePickString(row, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ], '');
  final subjectName = _schedulePickString(row, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ], '—');
  final classroom = _schedulePickString(row, [
    'classroomName',
    'roomName',
    'classroom',
  ], '');

  final displayName = className.isNotEmpty
      ? className
      : (teacher.isNotEmpty ? teacher : '—');
  final avatarSeed = displayName.isEmpty ? '?' : displayName;

  var courseColor = isSmall
      ? const Color(0xFF0CAC40)
      : const Color(0xFF8741FF);
  var courseBg = isSmall
      ? const Color(0xFFDFFCF0)
      : const Color(0xFFEAE5FF);
  var tagDotColor = courseColor;

  final hex = _schedulePickString(row, ['color'], '');
  final parsed = _parseDashboardHexColor(hex);
  if (parsed != null) {
    courseColor = parsed;
    courseBg = parsed.withValues(alpha: 0.14);
    tagDotColor = parsed;
  }

  final mins = _minutesBetweenHm(start, end);
  final hintParts = <String>[];
  if (mins > 0) hintParts.add('$mins分钟');
  if (classroom.isNotEmpty) hintParts.add(classroom);
  final hint = hintParts.isEmpty ? '—' : hintParts.join('·');

  return _LessonRowData(
    avatarSeed: avatarSeed,
    logoUrl: resolveScheduleLogoUrl(row),
    avatarUrl: resolveScheduleTeacherHeadUrl(row),
    preferLogoOverAvatar: true,
    teacherName: displayName,
    courseName: subjectName,
    courseColor: courseColor,
    courseBg: courseBg,
    tag: isSmall ? '小课' : '大课',
    tagDotColor: tagDotColor,
    hint: hint,
  );
}

List<_DashboardTimeConfig> _parseDashboardTimeConfigs(ApiResponse resp) {
  final list = <_DashboardTimeConfig>[];
  for (final m in _scheduleExtractList(resp)) {
    final lineNumRaw = m['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
    if (lineNum < 1) continue;
    final start = _trimDashboardHm(
      _schedulePickString(m, [
        'timeBegin',
        'startTime',
        'beginTime',
        'start',
      ], ''),
    );
    final end = _trimDashboardHm(
      _schedulePickString(m, [
        'timeEnd',
        'endTime',
        'finishTime',
        'end',
      ], ''),
    );
    if (start.isEmpty || end.isEmpty) continue;
    list.add(_DashboardTimeConfig(lineNum: lineNum, start: start, end: end));
  }
  list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
  return list;
}

List<Map<String, dynamic>> _scheduleExtractList(ApiResponse resp) {
  dynamic raw = resp.data;
  if (raw is Map && raw.containsKey('data')) {
    final d = raw['data'];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = d;
    }
  }
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : const []));
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _schedulePickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String _trimDashboardHm(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return s;
}

int _hmSortKey(String hm) {
  final dt = _parseTodayHm(hm);
  if (dt == null) return 0;
  return dt.hour * 60 + dt.minute;
}

DateTime? _parseTodayHm(String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
}

int _minutesBetweenHm(String start, String end) {
  final s = _parseTodayHm(start);
  final e = _parseTodayHm(end);
  if (s == null || e == null) return 0;
  return e.difference(s).inMinutes;
}

_LessonSlotPhase _slotPhase(DateTime now, String startHm, String endHm) {
  final start = _parseTodayHm(startHm);
  final end = _parseTodayHm(endHm);
  if (start == null || end == null) return _LessonSlotPhase.upcoming;
  if (now.isBefore(start)) return _LessonSlotPhase.upcoming;
  if (now.isAfter(end)) return _LessonSlotPhase.ended;
  return _LessonSlotPhase.inProgress;
}

({String label, Color foreground, Color background}) _statusStyle(
  _LessonSlotPhase phase,
) {
  switch (phase) {
    case _LessonSlotPhase.inProgress:
      return (
        label: '正在进行',
        foreground: const Color(0xFF0B081A),
        background: const Color(0xFFEAE5FF),
      );
    case _LessonSlotPhase.upcoming:
      return (
        label: '即将开始',
        foreground: const Color(0xFF0B081A),
        background: const Color(0xFFEAE5FF),
      );
    case _LessonSlotPhase.ended:
      return (
        label: '已结束',
        foreground: const Color(0xFFB6B5BB),
        background: const Color(0xFFE6E9F1),
      );
  }
}

Color? _parseDashboardHexColor(String hex) {
  var s = hex.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

class _CurrentLessonPanel extends StatelessWidget {
  const _CurrentLessonPanel({
    this.lesson,
    this.fillHeight = false,
    this.onTap,
  });

  final _LessonScheduleData? lesson;
  final bool fillHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final panel = Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: _wrapScrollable(
        fillHeight: fillHeight,
        child: lesson == null
            ? const _LessonEmptyHint(text: '暂无当前课程')
            : _LessonScheduleCard(data: lesson!),
      ),
    );
    final wrapped = onTap == null
        ? panel
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: panel,
          );
    return fillHeight ? SizedBox.expand(child: wrapped) : wrapped;
  }
}

class _TodaySchedulePanel extends StatelessWidget {
  const _TodaySchedulePanel({
    required this.lessons,
    this.fillHeight = false,
    this.onTap,
  });

  final List<_LessonScheduleData> lessons;
  final bool fillHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final panel = Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: _wrapScrollable(
        fillHeight: fillHeight,
        child: lessons.isEmpty
            ? const _LessonEmptyHint(text: '今日暂无课表')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lessons.length; i++) ...[
                    if (i > 0) SizedBox(height: ui(8)),
                    _LessonScheduleCard(data: lessons[i]),
                  ],
                ],
              ),
      ),
    );
    final wrapped = onTap == null
        ? panel
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: panel,
          );
    return fillHeight ? SizedBox.expand(child: wrapped) : wrapped;
  }
}

/// 宽屏撑满剩余高度时，白卡内部可滚动，避免课表条目过多导致 BOTTOM OVERFLOW。
Widget _wrapScrollable({required bool fillHeight, required Widget child}) {
  if (!fillHeight) return child;
  return Column(
    mainAxisSize: MainAxisSize.max,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    ],
  );
}

class _LessonEmptyHint extends StatelessWidget {
  const _LessonEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(36)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: ui(28),
            color: const Color(0xFFB6B5BB),
          ),
          SizedBox(height: ui(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF9A99A1),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonScheduleCard extends StatelessWidget {
  const _LessonScheduleCard({required this.data});

  final _LessonScheduleData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(12);
    final cardBg = data.isPast
        ? const Color(0xFFE6E9F1)
        : const Color(0xFFF5F6FA);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: _splitTime(data.time, ui, muted: data.isPast)),
              ),
              SizedBox(height: ui(14)),
              for (var i = 0; i < data.teachers.length; i++) ...[
                _LessonTeacherRow(data: data.teachers[i], muted: data.isPast),
                if (i != data.teachers.length - 1) SizedBox(height: ui(14)),
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            height: ui(22),
            padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(2)),
            decoration: BoxDecoration(
              color: data.statusBg,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              data.status,
              style: TextStyle(
                fontSize: ui(12),
                color: data.statusColor,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _splitTime(
    String time,
    double Function(double) ui, {
    bool muted = false,
  }) {
    final primary = muted ? const Color(0xFFB6B5BB) : const Color(0xFF1A1A1A);
    final secondary = muted ? const Color(0xFFB6B5BB) : const Color(0xFF0B081A);
    final parts = time.split('-');
    if (parts.length != 2) {
      return [
        TextSpan(
          text: time,
          style: TextStyle(
            fontSize: ui(18),
            color: primary,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ];
    }
    final start = parts[0].trim();
    final end = parts[1].trim();
    return [
      TextSpan(
        text: '$start ',
        style: TextStyle(
          fontSize: ui(18),
          color: primary,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: '- ',
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFFB6B5BB),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: end,
        style: TextStyle(
          fontSize: ui(18),
          color: secondary,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
}

class _LessonTeacherRow extends StatelessWidget {
  const _LessonTeacherRow({required this.data, this.muted = false});

  final _LessonRowData data;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const mutedColor = Color(0xFFB6B5BB);
    final nameColor = muted ? mutedColor : const Color(0xFF0B081A);
    final courseColor = muted ? mutedColor : data.courseColor;
    final courseBg = muted ? const Color(0xFFE6E9F1) : data.courseBg;
    final tagDotColor = muted ? mutedColor : data.tagDotColor;
    final tagTextColor = muted ? mutedColor : const Color(0xFF0B081A);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Opacity(
          opacity: muted ? 0.72 : 1,
          child: _LessonSeedAvatar(
            seed: data.avatarSeed,
            logoUrl: data.logoUrl,
            avatarUrl: data.avatarUrl,
            preferLogoOverAvatar: data.preferLogoOverAvatar,
            size: ui(40),
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      data.teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: nameColor,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(3),
                    ),
                    decoration: BoxDecoration(
                      color: courseBg,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      data.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: courseColor,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(3),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(4)),
                      border: Border.all(color: const Color(0xFFF3F2F3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: ui(6),
                          height: ui(6),
                          decoration: BoxDecoration(
                            color: tagDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Text(
                          data.tag,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: tagTextColor,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                data.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFFB6B5BB),
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 与学生端 `_SeedAvatar` 视觉一致的渐变首字头像。
/// 各取首字 `seed.codeUnitAt(0)` 在 5 套调色盘中循环。
class _LessonSeedAvatar extends StatelessWidget {
  const _LessonSeedAvatar({
    required this.seed,
    required this.logoUrl,
    required this.size,
    this.avatarUrl = '',
    this.preferLogoOverAvatar = false,
  });

  final String seed;
  final String logoUrl;
  final String avatarUrl;
  final bool preferLogoOverAvatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = preferLogoOverAvatar
        ? (logoUrl.isNotEmpty ? logoUrl : avatarUrl)
        : (avatarUrl.isNotEmpty ? avatarUrl : logoUrl);
    return SmoothCircleNetworkAvatar(
      url: url,
      size: size,
      placeholder: _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final palettes = <List<Color>>[
      const [Color(0xFFFFD9E3), Color(0xFFFFBFD0)],
      const [Color(0xFFD8E4FF), Color(0xFFB9D0FF)],
      const [Color(0xFFE8DCFF), Color(0xFFD5BCFF)],
      const [Color(0xFFE6FFF6), Color(0xFFB7F0DC)],
      const [Color(0xFFFFF0D9), Color(0xFFFFD09B)],
    ];
    final index = seed.isEmpty ? 0 : (seed.codeUnitAt(0) % palettes.length);
    final palette = palettes[index];
    final initial = seed.isEmpty ? '?' : seed.substring(0, 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          color: const Color(0xFF5B536D),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 班主任端：待办提醒 + 近期动态（白色双卡区）
//
// 与「当前课程 / 今日课表」共用同一外层布局（标题行 + 白卡 + Expanded 撑满）。
// 左卡聚焦需处理事项（请假审批 / 查寝异常 / 家校未读）；右卡展示班级侧最新动态。
// =============================================================================

class _BoardItemData {
  const _BoardItemData({
    required this.time,
    required this.title,
    required this.tag,
    required this.tagForeground,
    required this.tagBackground,
  });

  final String time;
  final String title;
  final String tag;
  final Color tagForeground;
  final Color tagBackground;
}

const Color _kBoardTagPurple = Color(0xFF8741FF);
const Color _kBoardTagPurpleSoft = Color(0xFFDAD2FF);

class _HeadTeacherBoardSection extends StatelessWidget {
  const _HeadTeacherBoardSection({
    this.fillRemaining = false,
    this.todoItems = const [],
    this.recentItems = const [],
  });

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;
  final List<_BoardItemData> todoItems;
  final List<_BoardItemData> recentItems;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          return Padding(
            padding: EdgeInsets.only(top: ui(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                sectionTitle('待办提醒'),
                SizedBox(height: ui(20)),
                _BoardPanel(
                  items: todoItems,
                  emptyHint: '暂无待办',
                ),
                SizedBox(height: ui(20)),
                sectionTitle('近期动态'),
                SizedBox(height: ui(20)),
                _BoardPanel(
                  items: recentItems,
                  emptyHint: '暂无近期动态',
                ),
              ],
            ),
          );
        }

        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _BoardPanel(
                items: todoItems,
                emptyHint: '暂无待办',
              ),
            ),
            SizedBox(width: ui(16)),
            Expanded(
              child: _BoardPanel(
                items: recentItems,
                emptyHint: '暂无近期动态',
              ),
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.only(top: ui(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: fillRemaining ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: sectionTitle('待办提醒')),
                  SizedBox(width: ui(16)),
                  Expanded(child: sectionTitle('近期动态')),
                ],
              ),
              SizedBox(height: ui(20)),
              if (fillRemaining)
                Expanded(child: cardsRow)
              else
                IntrinsicHeight(child: cardsRow),
            ],
          ),
        );
      },
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.items, this.emptyHint = '暂无事项'});

  final List<_BoardItemData> items;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: items.isEmpty
          ? _LessonEmptyHint(text: emptyHint)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(8)),
                  _BoardItemCard(data: items[i]),
                ],
              ],
            ),
    );
  }
}

class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({required this.data});

  final _BoardItemData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(TextSpan(children: _splitBoardTime(data.time, ui))),
          SizedBox(height: ui(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: data.tagBackground,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  data.tag,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: data.tagForeground,
                    fontWeight: FontWeight.w400,
                    height: 15.24 / 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 复用 `_LessonScheduleCard._splitTime` 同款时间三段式样式，
/// 提到顶层方便 `_BoardItemCard` 直接使用。
List<InlineSpan> _splitBoardTime(String time, double Function(double) ui) {
  final parts = time.split('-');
  if (parts.length != 2) {
    return [
      TextSpan(
        text: time,
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
  final start = parts[0].trim();
  final end = parts[1].trim();
  return [
    TextSpan(
      text: '$start ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: '- ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFFB6B5BB),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: end,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF0B081A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
  ];
}

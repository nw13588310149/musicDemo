import '../data/admin_home_data.dart';

class AdminHomeState {
  const AdminHomeState({
    this.summary = const AdminHomeSummary(),
    this.loginChart = const AdminHomeLoginChart(),
    this.notices = const [],
    this.workReminders = const [],
    this.pendingSmallCourseApplyCount = 0,
    this.loading = false,
    this.summaryError = '',
    this.loginChartError = '',
    this.noticeError = '',
    this.workRemindersError = '',
  });

  final AdminHomeSummary summary;
  final AdminHomeLoginChart loginChart;
  final List<AdminHomeNotice> notices;
  final List<AdminHomeWorkReminder> workReminders;

  /// 「排课与课表」快捷入口角标：`schoolSmallCourseApplyList` status=0 分页 total。
  final int pendingSmallCourseApplyCount;
  final bool loading;
  final String summaryError;
  final String loginChartError;
  final String noticeError;
  final String workRemindersError;

  AdminHomeState copyWith({
    AdminHomeSummary? summary,
    AdminHomeLoginChart? loginChart,
    List<AdminHomeNotice>? notices,
    List<AdminHomeWorkReminder>? workReminders,
    int? pendingSmallCourseApplyCount,
    bool? loading,
    String? summaryError,
    String? loginChartError,
    String? noticeError,
    String? workRemindersError,
  }) {
    return AdminHomeState(
      summary: summary ?? this.summary,
      loginChart: loginChart ?? this.loginChart,
      notices: notices ?? this.notices,
      workReminders: workReminders ?? this.workReminders,
      pendingSmallCourseApplyCount:
          pendingSmallCourseApplyCount ?? this.pendingSmallCourseApplyCount,
      loading: loading ?? this.loading,
      summaryError: summaryError ?? this.summaryError,
      loginChartError: loginChartError ?? this.loginChartError,
      noticeError: noticeError ?? this.noticeError,
      workRemindersError: workRemindersError ?? this.workRemindersError,
    );
  }
}

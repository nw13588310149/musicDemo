import '../data/admin_home_data.dart';

class AdminHomeState {
  const AdminHomeState({
    this.summary = const AdminHomeSummary(),
    this.loginChart = const AdminHomeLoginChart(),
    this.notices = const [],
    this.loading = false,
    this.summaryError = '',
    this.loginChartError = '',
    this.noticeError = '',
  });

  final AdminHomeSummary summary;
  final AdminHomeLoginChart loginChart;
  final List<AdminHomeNotice> notices;
  final bool loading;
  final String summaryError;
  final String loginChartError;
  final String noticeError;

  AdminHomeState copyWith({
    AdminHomeSummary? summary,
    AdminHomeLoginChart? loginChart,
    List<AdminHomeNotice>? notices,
    bool? loading,
    String? summaryError,
    String? loginChartError,
    String? noticeError,
  }) {
    return AdminHomeState(
      summary: summary ?? this.summary,
      loginChart: loginChart ?? this.loginChart,
      notices: notices ?? this.notices,
      loading: loading ?? this.loading,
      summaryError: summaryError ?? this.summaryError,
      loginChartError: loginChartError ?? this.loginChartError,
      noticeError: noticeError ?? this.noticeError,
    );
  }
}

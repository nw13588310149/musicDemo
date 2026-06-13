import '../data/admin_home_data.dart';

class AdminHomeState {
  const AdminHomeState({
    this.summary = const AdminHomeSummary(),
    this.notices = const [],
    this.loading = false,
    this.summaryError = '',
    this.noticeError = '',
  });

  final AdminHomeSummary summary;
  final List<AdminHomeNotice> notices;
  final bool loading;
  final String summaryError;
  final String noticeError;

  AdminHomeState copyWith({
    AdminHomeSummary? summary,
    List<AdminHomeNotice>? notices,
    bool? loading,
    String? summaryError,
    String? noticeError,
  }) {
    return AdminHomeState(
      summary: summary ?? this.summary,
      notices: notices ?? this.notices,
      loading: loading ?? this.loading,
      summaryError: summaryError ?? this.summaryError,
      noticeError: noticeError ?? this.noticeError,
    );
  }
}

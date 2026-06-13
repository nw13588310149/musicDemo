import '../data/dormitory_check_data.dart';

class DormitoryManagerState {
  const DormitoryManagerState({
    this.loadingHome = false,
    this.loadingHistory = false,
    this.loadingMakeup = false,
    this.exporting = false,
    this.error = '',
    this.index = DormitoryIndexOverview.zero,
    this.historyItems = const [],
    this.historyStat = DormitoryCheckStat.zero,
    this.makeupItems = const [],
    this.submittingMakeupIds = const {},
    this.submittingExceptionIds = const {},
  });

  final bool loadingHome;
  final bool loadingHistory;
  final bool loadingMakeup;
  final bool exporting;
  final String error;
  final DormitoryIndexOverview index;
  final List<DormitoryCheckHistoryItem> historyItems;
  final DormitoryCheckStat historyStat;
  final List<DormitoryMakeupItem> makeupItems;
  final Set<String> submittingMakeupIds;
  final Set<String> submittingExceptionIds;

  DormitoryManagerState copyWith({
    bool? loadingHome,
    bool? loadingHistory,
    bool? loadingMakeup,
    bool? exporting,
    String? error,
    DormitoryIndexOverview? index,
    List<DormitoryCheckHistoryItem>? historyItems,
    DormitoryCheckStat? historyStat,
    List<DormitoryMakeupItem>? makeupItems,
    Set<String>? submittingMakeupIds,
    Set<String>? submittingExceptionIds,
  }) {
    return DormitoryManagerState(
      loadingHome: loadingHome ?? this.loadingHome,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      loadingMakeup: loadingMakeup ?? this.loadingMakeup,
      exporting: exporting ?? this.exporting,
      error: error ?? this.error,
      index: index ?? this.index,
      historyItems: historyItems ?? this.historyItems,
      historyStat: historyStat ?? this.historyStat,
      makeupItems: makeupItems ?? this.makeupItems,
      submittingMakeupIds: submittingMakeupIds ?? this.submittingMakeupIds,
      submittingExceptionIds:
          submittingExceptionIds ?? this.submittingExceptionIds,
    );
  }
}

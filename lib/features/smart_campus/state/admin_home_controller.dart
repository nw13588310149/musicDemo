import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_home_data.dart';
import '../data/admin_repository.dart';
import '../data/teacher_notice_data.dart';
import 'admin_home_state.dart';

final adminHomeControllerProvider =
    StateNotifierProvider.autoDispose<AdminHomeController, AdminHomeState>(
      (ref) =>
          AdminHomeController(repository: ref.watch(adminRepositoryProvider)),
    );

class AdminHomeController extends StateNotifier<AdminHomeState> {
  AdminHomeController({required AdminRepository repository})
    : _repository = repository,
      super(const AdminHomeState());

  final AdminRepository _repository;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, summaryError: '', noticeError: '');
    final responses = await Future.wait([
      _repository.indexSum(),
      _repository.noticeManageList(current: 1, size: 20, status: 1),
    ]);
    final summaryResponse = responses[0];
    final noticeResponse = responses[1];
    state = state.copyWith(
      loading: false,
      summary: summaryResponse.isSuccess
          ? AdminHomeSummary.fromJson(summaryResponse.data)
          : state.summary,
      notices: noticeResponse.isSuccess
          ? parseAdminHomeNotices(noticeResponse.data)
          : state.notices,
      summaryError: summaryResponse.isSuccess ? '' : summaryResponse.displayMsg,
      noticeError: noticeResponse.isSuccess ? '' : noticeResponse.displayMsg,
    );
  }

  Future<TeacherNoticeListItem?> loadNoticeDetail(String id) async {
    if (id.isEmpty) return null;
    final response = await _repository.noticeDetail(id: id);
    if (!response.isSuccess) {
      state = state.copyWith(noticeError: response.displayMsg);
      return null;
    }
    return parseTeacherNoticeDetail(response.data);
  }
}

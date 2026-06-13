import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/dormitory_check_data.dart';
import '../data/dormitory_repository.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailField;
import 'dormitory_manager_state.dart';

final dormitoryManagerControllerProvider =
    StateNotifierProvider.autoDispose<
      DormitoryManagerController,
      DormitoryManagerState
    >((ref) {
      return DormitoryManagerController(
        repository: ref.watch(dormitoryRepositoryProvider),
      );
    });

class DormitoryManagerController extends StateNotifier<DormitoryManagerState> {
  DormitoryManagerController({required DormitoryRepository repository})
    : _repository = repository,
      super(const DormitoryManagerState());

  final DormitoryRepository _repository;

  Future<void> loadHome() async {
    state = state.copyWith(loadingHome: true, error: '');
    final response = await _repository.index();
    state = state.copyWith(
      loadingHome: false,
      index: response.isSuccess
          ? parseDormitoryIndexOverview(response.data)
          : state.index,
      error: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<void> loadHistory({
    String? buildingId,
    String? floorId,
    required String date,
  }) async {
    state = state.copyWith(loadingHistory: true, error: '');
    final responses = await Future.wait([
      _repository.dormitoryCheckStat(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      ),
      _repository.dormitoryCheckHistory(
        buildingId: buildingId,
        floorId: floorId,
        beginDate: date,
        endDate: date,
      ),
    ]);
    final errors = responses
        .where((response) => !response.isSuccess)
        .map((response) => response.displayMsg)
        .where((message) => message.isNotEmpty)
        .toSet()
        .join('；');
    state = state.copyWith(
      loadingHistory: false,
      historyStat: responses[0].isSuccess
          ? parseDormitoryCheckStat(responses[0].data)
          : DormitoryCheckStat.zero,
      historyItems: responses[1].isSuccess
          ? parseDormitoryCheckHistoryList(responses[1].data)
          : const [],
      error: errors,
    );
  }

  Future<ApiResponse> exportHistory({
    String? buildingId,
    String? floorId,
    required String date,
  }) async {
    if (state.exporting) return ApiResponse.failure('导出任务进行中');
    state = state.copyWith(exporting: true, error: '');
    final response = await _repository.dormitoryCheckExport(
      buildingId: buildingId,
      floorId: floorId,
      beginDate: date,
      endDate: date,
    );
    state = state.copyWith(exporting: false);
    if (!response.isSuccess) {
      state = state.copyWith(error: response.displayMsg);
    }
    return response;
  }

  Future<ApiResponse> handleException({
    required DormitoryCheckHistoryItem item,
    required int handleStatus,
    String remark = '',
  }) async {
    final key = '${item.id}:${item.userId}';
    if (item.id.isEmpty ||
        item.userId.isEmpty ||
        state.submittingExceptionIds.contains(key)) {
      return ApiResponse.failure('异常记录正在处理中');
    }
    state = state.copyWith(
      submittingExceptionIds: {...state.submittingExceptionIds, key},
    );
    final response = await _repository.dormitoryCheckExceptionHandle(
      checkId: item.id,
      studentId: item.userId,
      handleStatus: handleStatus,
      remark: remark,
    );
    if (response.isSuccess) {
      final updated = [
        for (final record in state.historyItems)
          if (record.id == item.id && record.userId == item.userId)
            DormitoryCheckHistoryItem(
              id: record.id,
              userId: record.userId,
              studentName: record.studentName,
              studentNo: record.studentNo,
              dormName: record.dormName,
              checkDate: record.checkDate,
              checkType: record.checkType,
              deadline: record.deadline,
              checkTime: record.checkTime,
              status: record.status,
              remark: remark.isEmpty ? record.remark : remark,
              handleStatus: handleStatus,
            )
          else
            record,
      ];
      state = state.copyWith(historyItems: updated);
    }
    state = state.copyWith(
      submittingExceptionIds: {...state.submittingExceptionIds}..remove(key),
    );
    return response;
  }

  Future<void> loadMakeups({String? buildingId}) async {
    state = state.copyWith(loadingMakeup: true, error: '');
    final response = await _repository.dormitoryMakeupList(
      buildingId: buildingId,
      status: 0,
    );
    state = state.copyWith(
      loadingMakeup: false,
      makeupItems: response.isSuccess
          ? parseDormitoryMakeupList(response.data)
          : state.makeupItems,
      error: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<ApiResponse> auditMakeup({
    required String id,
    required bool approve,
    String auditReason = '',
  }) async {
    if (id.isEmpty || state.submittingMakeupIds.contains(id)) {
      return ApiResponse.failure('补卡申请正在处理中');
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds, id},
    );
    final response = await _repository.dormitoryMakeupAudit(
      id: id,
      status: approve ? 1 : 2,
      auditReason: auditReason,
    );
    if (response.isSuccess) {
      await Future.wait([loadMakeups(), loadHome()]);
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds}..remove(id),
    );
    return response;
  }

  Future<List<DormitoryDetailField>> loadCheckDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryCheckDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseDormitoryCheckDetailFields(response.data);
  }

  Future<List<DormitoryDetailField>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseDormitoryMakeupDetailFields(response.data);
  }
}

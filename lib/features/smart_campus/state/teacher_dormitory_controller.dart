import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/teacher_dormitory_data.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailField;
import '../data/teacher_repository.dart';
import 'teacher_dormitory_state.dart';

final teacherDormitoryControllerProvider =
    StateNotifierProvider.autoDispose<
      TeacherDormitoryController,
      TeacherDormitoryState
    >((ref) {
      return TeacherDormitoryController(
        repository: ref.watch(teacherRepositoryProvider),
      );
    });

class TeacherDormitoryController extends StateNotifier<TeacherDormitoryState> {
  TeacherDormitoryController({required TeacherRepository repository})
    : _repository = repository,
      super(
        TeacherDormitoryState(
          selectedDate: teacherDormitoryIsoDate(DateTime.now()),
        ),
      );

  final TeacherRepository _repository;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    state = state.copyWith(loading: true, error: '');
    final response = await _repository.headTeacherIndex();
    if (!response.isSuccess) {
      state = state.copyWith(loading: false, error: response.displayMsg);
      return;
    }
    final classes = parseTeacherDormitoryClasses(response.data);
    if (classes.isEmpty) {
      state = state.copyWith(
        loading: false,
        classes: classes,
        error: '当前账号暂无班主任班级',
      );
      return;
    }
    state = state.copyWith(
      classes: classes,
      selectedClassId: classes.first.classId,
    );
    await refresh();
  }

  Future<void> selectClass(String classId) async {
    if (classId.isEmpty || classId == state.selectedClassId) return;
    state = state.copyWith(selectedClassId: classId);
    await refresh();
  }

  Future<void> refresh() async {
    final classId = state.selectedClassId;
    if (classId.isEmpty) return;
    state = state.copyWith(loading: true, error: '');
    final date = state.selectedDate;
    final responses = await Future.wait([
      _repository.headTeacherClassOverview(classId: classId),
      _repository.classDormitoryDynamicList(classId: classId),
      _repository.classDormitoryMakeupList(classId: classId),
      _repository.classDormitoryCheckStat(
        classId: classId,
        beginDate: date,
        endDate: date,
      ),
      _repository.classDormitoryCheckHistory(
        classId: classId,
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
      loading: false,
      overview: responses[0].isSuccess
          ? TeacherDormitoryOverview.fromJson(responses[0].data)
          : state.overview,
      dynamicItems: responses[1].isSuccess
          ? parseTeacherDormitoryDynamicList(responses[1].data)
          : state.dynamicItems,
      makeupItems: responses[2].isSuccess
          ? parseTeacherDormitoryMakeupList(responses[2].data)
          : state.makeupItems,
      stat: responses[3].isSuccess
          ? TeacherDormitoryStat.fromJson(responses[3].data)
          : state.stat,
      historyItems: responses[4].isSuccess
          ? parseTeacherDormitoryHistoryList(responses[4].data)
          : state.historyItems,
      error: errors,
    );
  }

  Future<void> selectHistoryDate(DateTime date) async {
    final value = teacherDormitoryIsoDate(date);
    if (value == state.selectedDate || state.selectedClassId.isEmpty) return;
    state = state.copyWith(
      selectedDate: value,
      loadingHistory: true,
      error: '',
    );
    final responses = await Future.wait([
      _repository.classDormitoryCheckStat(
        classId: state.selectedClassId,
        beginDate: value,
        endDate: value,
      ),
      _repository.classDormitoryCheckHistory(
        classId: state.selectedClassId,
        beginDate: value,
        endDate: value,
      ),
    ]);
    state = state.copyWith(
      loadingHistory: false,
      stat: responses[0].isSuccess
          ? TeacherDormitoryStat.fromJson(responses[0].data)
          : state.stat,
      historyItems: responses[1].isSuccess
          ? parseTeacherDormitoryHistoryList(responses[1].data)
          : state.historyItems,
      error: {
        for (final response in responses)
          if (!response.isSuccess && response.displayMsg.isNotEmpty)
            response.displayMsg,
      }.join('；'),
    );
  }

  Future<ApiResponse> auditMakeup({
    required String id,
    required bool approve,
  }) async {
    if (id.isEmpty || state.submittingMakeupIds.contains(id)) {
      return ApiResponse.failure('补卡申请正在处理中');
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds, id},
    );
    final response = await _repository.classDormitoryMakeupAudit(
      id: id,
      status: approve ? 1 : 2,
    );
    if (response.isSuccess) {
      await _reloadMakeups();
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds}..remove(id),
    );
    return response;
  }

  Future<List<DormitoryDetailField>> loadCheckDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.classDormitoryCheckDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseTeacherDormitoryCheckDetailFields(response.data);
  }

  Future<List<DormitoryDetailField>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.classDormitoryMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseTeacherDormitoryMakeupDetailFields(response.data);
  }

  Future<void> _reloadMakeups() async {
    final classId = state.selectedClassId;
    if (classId.isEmpty) return;
    final responses = await Future.wait([
      _repository.classDormitoryMakeupList(classId: classId),
      _repository.headTeacherClassOverview(classId: classId),
    ]);
    state = state.copyWith(
      makeupItems: responses[0].isSuccess
          ? parseTeacherDormitoryMakeupList(responses[0].data)
          : state.makeupItems,
      overview: responses[1].isSuccess
          ? TeacherDormitoryOverview.fromJson(responses[1].data)
          : state.overview,
    );
  }
}

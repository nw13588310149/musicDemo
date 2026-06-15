import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../school/data/school_repository.dart';
import '../data/student_check_in_data.dart';
import '../data/student_repository.dart';
import 'student_check_in_state.dart';

final studentCheckInControllerProvider =
    StateNotifierProvider.autoDispose<
      StudentCheckInController,
      StudentCheckInState
    >((ref) {
      final controller = StudentCheckInController(
        studentRepository: ref.watch(studentRepositoryProvider),
        schoolRepository: ref.watch(schoolRepositoryProvider),
      );
      ref.onDispose(controller.stopLiveSync);
      return controller;
    });

class StudentCheckInController extends StateNotifier<StudentCheckInState> {
  StudentCheckInController({
    required StudentRepository studentRepository,
    required SchoolRepository schoolRepository,
  }) : _studentRepository = studentRepository,
       _schoolRepository = schoolRepository,
       super(const StudentCheckInState());

  final StudentRepository _studentRepository;
  final SchoolRepository _schoolRepository;
  bool _initialized = false;
  Timer? _liveSyncTimer;
  bool _liveSyncActive = false;

  static const _liveSyncInterval = Duration(seconds: 5);

  /// 页面可见时启动：周期性拉取当前选中课的签到详情，便于感知对方操作。
  void startLiveSync() {
    if (_liveSyncActive) return;
    _liveSyncActive = true;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(_liveSyncInterval, (_) {
      unawaited(pollActiveCourseDetail());
    });
  }

  void stopLiveSync() {
    _liveSyncActive = false;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
  }

  /// App 回到前台时立即同步一次当前课详情。
  Future<void> resumeSync() async {
    await pollActiveCourseDetail(force: true);
  }

  Future<void> pollActiveCourseDetail({bool force = false}) async {
    if (!_liveSyncActive && !force) return;
    if (state.submitting || state.loading) return;
    final courseId = state.selectedCourseId;
    if (courseId == null || courseId.isEmpty) return;
    final course = state.selectedCourse;
    if (!_shouldKeepLiveSync(course)) return;
    await loadCourseDetail(courseId, silent: true);
  }

  bool _shouldKeepLiveSync(StudentTodayCourse? course) {
    if (course == null) return true;
    if (course.phase == StudentCourseSlotPhase.ended &&
        course.courseSignStatus >= CourseSignFlowStatus.studentEval.code) {
      return false;
    }
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: '');
    final today = DateTime.now();
    final todayIso = todayIsoDate();
    final semester = studentCheckInSemesterDates(today);

    var timeConfigs = kDefaultStudentTimeConfigs;
    String? classId;

    final classResp = await _studentRepository.mySchoolClass();
    if (classResp.isSuccess) {
      final map = classResp.data;
      if (map is Map) {
        final schoolClass = map['schoolClass'];
        if (schoolClass is Map) {
          classId = schoolClass['id']?.toString() ??
              schoolClass['classId']?.toString();
        }
      }
    }

    if (classId != null && classId.isNotEmpty) {
      final tcResp = await _schoolRepository.schoolTimeConfigList(
        classId: classId,
      );
      if (tcResp.isSuccess) {
        final parsed = parseStudentTimeConfigs(tcResp.data);
        if (parsed.isNotEmpty) timeConfigs = parsed;
      }
    }

    final responses = await Future.wait([
      _studentRepository.courseList(beginDate: todayIso, endDate: todayIso),
      _studentRepository.courseSignStat(
        beginDate: semester.beginDate,
        endDate: semester.endDate,
      ),
      _studentRepository.courseSignRecentList(size: 6),
    ]);

    final courseResp = responses[0];
    final statResp = responses[1];
    final recentResp = responses[2];

    final courses = courseResp.isSuccess
        ? attachSignRecordIdsToCourses(
            parseStudentTodaySmallCourses(
              raw: courseResp.data,
              timeConfigs: timeConfigs,
              now: today,
              todayIso: todayIso,
            ),
            recentResp.isSuccess
                ? parseStudentSignRecordList(recentResp.data)
                : const <StudentSignRecordItem>[],
          )
        : state.todayCourses;

    final active = pickActiveStudentCourse(courses);
    final selectedId = state.selectedCourseId ?? active?.courseId;

    state = state.copyWith(
      loading: false,
      todayCourses: courses,
      selectedCourseId: selectedId,
      todayTitle: formatChineseDateTitle(today),
      stats: statResp.isSuccess
          ? StudentCheckInStat.fromJson(statResp.data)
          : state.stats,
      recentRecords: recentResp.isSuccess
          ? parseStudentSignRecordList(recentResp.data)
          : state.recentRecords,
      error: courseResp.isSuccess ? '' : courseResp.displayMsg,
    );

    if (selectedId != null && selectedId.isNotEmpty) {
      await loadCourseDetail(selectedId);
    }
  }

  Future<void> selectCourse(String courseId) async {
    if (state.selectedCourseId == courseId) return;
    state = state.copyWith(selectedCourseId: courseId);
    await loadCourseDetail(courseId);
  }

  Future<void> loadCourseDetail(String courseId, {bool silent = false}) async {
    if (courseId.isEmpty) return;
    if (state.loadingDetailCourseId == courseId) return;
    if (!silent) {
      state = state.copyWith(loadingDetailCourseId: courseId);
    }
    var signRecordId = findSignRecordIdForCourse(
      courseId,
      courses: state.todayCourses,
      recentRecords: state.recentRecords,
      historyRecords: state.historyRecords,
    );
    if (signRecordId == null || signRecordId.isEmpty) {
      final todayIso = todayIsoDate();
      final historyResp = await _studentRepository.courseSignHistory(
        beginDate: todayIso,
        endDate: todayIso,
        current: 1,
        size: 200,
      );
      if (historyResp.isSuccess) {
        final todayRecords = parseStudentSignRecordList(historyResp.data);
        signRecordId = findSignRecordIdForCourse(
          courseId,
          courses: state.todayCourses,
          recentRecords: state.recentRecords,
          historyRecords: todayRecords,
        );
      }
    }
    if (signRecordId == null || signRecordId.isEmpty) {
      if (!silent) {
        state = state.copyWith(loadingDetailCourseId: '');
      }
      return;
    }
    final response = await _studentRepository.courseSignDetail(id: signRecordId);
    if (response.isSuccess) {
      final detail = StudentCourseSignDetail.fromJson(response.data);
      state = state.copyWith(
        todayCourses: [
          for (final course in state.todayCourses)
            if (course.courseId == courseId)
              detail.applyTo(course)
            else
              course,
        ],
      );
    }
    if (!silent) {
      state = state.copyWith(loadingDetailCourseId: '');
    }
  }

  Future<ApiResponse> signIn(String courseId) async {
    if (state.submitting) {
      return ApiResponse.failure('正在提交，请稍候');
    }
    state = state.copyWith(submitting: true);
    final response = await _studentRepository.courseStudentSignIn(
      courseId: courseId,
    );
    if (response.isSuccess) {
      await refresh();
    }
    state = state.copyWith(submitting: false);
    return response;
  }

  Future<ApiResponse> signOut(String courseId) async {
    if (state.submitting) {
      return ApiResponse.failure('正在提交，请稍候');
    }
    state = state.copyWith(submitting: true);
    final response = await _studentRepository.courseStudentSignOut(
      courseId: courseId,
    );
    if (response.isSuccess) {
      await refresh();
    }
    state = state.copyWith(submitting: false);
    return response;
  }

  Future<ApiResponse> submitComment({
    required String courseId,
    required String comment,
    required int score,
  }) async {
    if (state.submitting) {
      return ApiResponse.failure('正在提交，请稍候');
    }
    state = state.copyWith(submitting: true);
    final response = await _studentRepository.courseStudentComment(
      courseId: courseId,
      comment: comment,
      score: score,
    );
    if (response.isSuccess) {
      await refresh();
    }
    state = state.copyWith(submitting: false);
    return response;
  }

  Future<void> loadHistory({
    required StudentCheckInHistoryRange range,
    int? status,
  }) async {
    if (state.loadingHistory) return;
    state = state.copyWith(loadingHistory: true, historyError: '');
    final dates = range.dates(DateTime.now());
    final response = await _studentRepository.courseSignHistory(
      beginDate: dates.beginDate,
      endDate: dates.endDate,
      status: status,
      current: 1,
      size: 200,
    );
    state = state.copyWith(
      loadingHistory: false,
      historyRecords: response.isSuccess
          ? parseStudentSignRecordList(response.data)
          : state.historyRecords,
      historyError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<ApiResponse> submitMakeup({
    required String courseId,
    required int signType,
    required String reason,
  }) async {
    if (state.submitting) {
      return ApiResponse.failure('正在提交，请稍候');
    }
    state = state.copyWith(submitting: true);
    final response = await _studentRepository.courseSignMakeupSave(
      courseId: courseId,
      signType: signType,
      reason: reason,
    );
    if (response.isSuccess) {
      await refresh();
      await loadMakeupList();
    }
    state = state.copyWith(submitting: false);
    return response;
  }

  Future<void> loadMakeupList({int? status}) async {
    if (state.loadingMakeup) return;
    state = state.copyWith(loadingMakeup: true, makeupError: '');
    final response = await _studentRepository.courseSignMakeupList(
      status: status,
      current: 1,
      size: 200,
    );
    state = state.copyWith(
      loadingMakeup: false,
      makeupRecords: response.isSuccess
          ? parseStudentCourseSignMakeupList(response.data)
          : state.makeupRecords,
      makeupError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<List<({String label, String value})>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _studentRepository.courseSignMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseStudentCourseSignMakeupDetailRows(response.data);
  }
}

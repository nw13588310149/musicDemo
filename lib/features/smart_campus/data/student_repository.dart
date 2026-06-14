import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';
import 'student_leave_data.dart';

/// 智慧校园 **学生端** `POST /app/school/v2/student/*`。
///
/// 与 [TeacherRepository] 中任课老师调用的 `teacher/...` 路径不同。
/// 学生首页概览 [index]、我的课表 [courseList]、「我的作业」等均走本类。
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return StudentRepository(client: client);
});

class StudentRepository {
  StudentRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/student';

  /// 学生首页概览：今日课程、待交作业、学期均分、班级未读通知、月考/统考时间等。
  Future<ApiResponse> index() {
    return client.post('$_base/index');
  }

  /// 考试统计概览：均分、排名、最佳考试、趋势和分数段分布。
  Future<ApiResponse> examOverview({int? subjectId}) {
    return client.post(
      '$_base/examOverview',
      data: subjectId == null
          ? null
          : <String, dynamic>{'subjectId': subjectId},
    );
  }

  /// 已发布成绩的考试记录与各科成绩。
  Future<ApiResponse> examRecordList() {
    return client.post('$_base/examRecordList');
  }

  /// 我的课表。`beginDate` / `endDate` 为 `yyyy-MM-dd`；后端按 token 过滤当前学生。
  Future<ApiResponse> courseList({
    required String beginDate,
    required String endDate,
    String? classId,
    List<String>? classIdList,
    String? teacherId,
    int? type,
  }) {
    final body = <String, dynamic>{'beginDate': beginDate, 'endDate': endDate};
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    if (classIdList != null && classIdList.isNotEmpty) {
      body['classIdList'] = classIdList;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      body['teacherId'] = teacherId;
    }
    if (type != null) {
      body['type'] = type;
    }
    return client.post('$_base/courseList', data: body);
  }

  /// 我的班级：班级信息、班主任、任课老师、同班同学等。
  Future<ApiResponse> mySchoolClass() {
    return client.post('$_base/mySchoolClass');
  }

  /// 班级公告列表（分页）。
  Future<ApiResponse> schoolClassNoticeList({int current = 1, int size = 10}) {
    return client.post(
      '$_base/schoolClassNotice/list',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 我的作业列表（分页）。
  ///
  /// - [status]：`0` 待提交、`1` 已提交、`2` 已评分；不传则不限状态（全部）。
  Future<ApiResponse> studentHomeworkList({
    int current = 1,
    int size = 10,
    int? status,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    return client.post('$_base/studentHomeworkList', data: body);
  }

  /// 学生作业数据统计：科目均分与分数段分布。
  Future<ApiResponse> studentHomeworkSum() {
    return client.post('$_base/studentHomeworkSum');
  }

  /// 作业详情。`id` 须传列表项的 **`homeworkStudentId`**（学生作业记录 id），勿用作业 `id`。
  Future<ApiResponse> studentHomeworkDetail({required String id}) {
    return client.post(
      '$_base/studentHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 提交作业。`id` 为 **`homeworkStudentId`**；`studentParam1`～`3` 预留给附件路径、
  /// 文件名、提交类型等扩展（与上传通道对齐）。
  Future<ApiResponse> studentHomeworkSubmit({
    required String id,
    required String description,
    String studentParam1 = '',
    String studentParam2 = '',
    String studentParam3 = '',
  }) {
    return client.post(
      '$_base/studentHomeworkSubmit',
      data: <String, dynamic>{
        'id': id,
        'description': description,
        'studentParam1': studentParam1,
        'studentParam2': studentParam2,
        'studentParam3': studentParam3,
      },
    );
  }

  /// 学生首页通知列表。
  Future<ApiResponse> noticeList({int current = 1, int size = 20}) {
    return client.post(
      '$_base/noticeList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 学生端通知详情。`id` 为雪花 long 字符串。
  Future<ApiResponse> noticeDetail({required String id}) {
    return client.post(
      '$_base/noticeDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 学生小课上课签到。App 端请求体仅包含 `courseId`。
  Future<ApiResponse> courseStudentSignIn({required String courseId}) {
    return client.post(
      '$_base/courseStudentSignIn',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
      },
    );
  }

  /// 学生小课下课签到。App 端请求体仅包含 `courseId`。
  Future<ApiResponse> courseStudentSignOut({required String courseId}) {
    return client.post(
      '$_base/courseStudentSignOut',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
      },
    );
  }

  /// 小课学生评价。
  Future<ApiResponse> courseStudentComment({
    required String courseId,
    required String comment,
    required int score,
  }) {
    return client.post(
      '$_base/courseStudentComment',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
        'comment': comment,
        'score': score,
      },
    );
  }

  /// 学生请假列表（分页）。
  Future<ApiResponse> studentLeaveList({int current = 1, int size = 50}) {
    return client.post(
      '$_base/studentLeaveList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 学生请假详情。
  Future<ApiResponse> studentLeaveDetail({required String id}) {
    return client.post(
      '$_base/studentLeaveDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  // ============== 学生 · 查寝 / 补卡 ==============

  /// 当前学生宿舍信息。
  Future<ApiResponse> myDormitoryInfo() {
    return client.post('$_base/myDormitoryInfo');
  }

  /// 学生查寝统计。
  Future<ApiResponse> dormitoryCheckStat({String? beginDate, String? endDate}) {
    return client.post(
      '$_base/dormitoryCheckStat',
      data: <String, dynamic>{
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
    );
  }

  /// 学生历史查寝记录。
  Future<ApiResponse> dormitoryCheckHistory({
    String? beginDate,
    String? endDate,
    String? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/dormitoryCheckHistory',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// 单次查寝详情。
  Future<ApiResponse> dormitoryCheckDetail({required String id}) {
    return client.post(
      '$_base/dormitoryCheckDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 提交查寝补卡申请。
  Future<ApiResponse> dormitoryMakeupSave({
    required String date,
    required String checkType,
    required String reason,
    String attachment = '',
  }) {
    return client.post(
      '$_base/dormitoryMakeupSave',
      data: <String, dynamic>{
        'date': date,
        'checkType': checkType,
        'reason': reason,
        if (attachment.isNotEmpty) 'attachment': attachment,
      },
    );
  }

  /// 本人补卡申请列表。
  Future<ApiResponse> dormitoryMakeupList({
    int? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/dormitoryMakeupList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        'status': ?status,
      },
    );
  }

  /// 补卡申请详情。
  Future<ApiResponse> dormitoryMakeupDetail({required String id}) {
    return client.post(
      '$_base/dormitoryMakeupDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 撤销待审批补卡申请。
  Future<ApiResponse> dormitoryMakeupCancel({required String id}) {
    return client.post(
      '$_base/dormitoryMakeupCancel',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 学生发起请假。
  Future<ApiResponse> studentLeaveSave({
    required DateTime startTime,
    required DateTime endTime,
    required String leaveDuration,
    required String leaveReason,
    required int type,
  }) {
    return client.post(
      '$_base/studentLeaveSave',
      data: <String, dynamic>{
        'startTime': formatStudentLeaveDateTime(startTime),
        'endTime': formatStudentLeaveDateTime(endTime),
        'leaveDuration': leaveDuration,
        'leaveReason': leaveReason,
        'type': type,
      },
    );
  }
}

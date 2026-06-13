import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';

/// 管理员（教务管理端）相关接口的 Repository。
///
/// 全部为 `POST /app/school1/v2/manager/*`，对应后端 Swagger 中的
/// **v2 智慧校园-教务管理端 (App School V2 Manager Controller)** 一组：
///   - `campusList`                校区下拉列表
///   - `classList`                 班级列表
///   - `classroomList`             教室下拉列表
///   - `classSave`                 班级新增
///   - `classUpdate`               班级编辑
///   - `courseBatchSave`           课表-大班课批量保存课表
///   - `courseDelete`              课表-批量删除
///   - `courseList`                班级课表
///   - `schoolSmallCourseApplyAudit` 小班课申请审核
///   - `schoolSmallCourseApplyDetail` 小班课申请详情
///   - `schoolSmallCourseApplyList`  小班课申请列表
///   - `indexSum`                  管理员首页统计汇总
///   - `studentList`               学生下拉列表
///   - `teacherList`               教师下拉列表
///
/// 头部 `app-token` / `schoolId` 由 [ApiClient] 统一注入；调用方只需传业务
/// 字段。所有方法返回 [ApiResponse]，由调用方按 `isSuccess` + `data` 处理。
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AdminRepository(client: client);
});

class AdminRepository {
  AdminRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/manager';

  // ============== 首页统计 ==============

  /// 管理员智慧校园首页统计汇总（`IndexSumRes`）。
  ///
  /// 返回数据结构：
  /// ```json
  /// {
  ///   "data": {
  ///     "studentCount": 0,                    // 在籍学生
  ///     "teacherCount": 0,                    // 老师数量
  ///     "classCount": 0,                      // 班级数量
  ///     "leaveStatus0Count": 0,               // 教职工待审批请假
  ///     "postStatus0Count": 0,                // 校圈待审核数量
  ///     "smallCourseSignStatus5Count": 0,     // 小班课待审核数量
  ///     "userFaceNotRecordedCount": 0,        // 人脸待补录
  ///     "toDoTodayCount": 0                   // 今日待办
  ///   }
  /// }
  /// ```
  Future<ApiResponse> indexSum() {
    return client.post('$_base/indexSum');
  }

  // ============== 下拉 / 列表 ==============

  /// 校区下拉列表。
  Future<ApiResponse> campusList() {
    return client.post('$_base/campusList');
  }

  /// 班级列表。可按 `campusId` / `keyword` / `type` 过滤；空 body 拉全量。
  ///
  /// - `type`: 班级类型，`0 = 大班`，`1 = 小班`；不传 = 全量。
  ///   主要给「编辑大课」抽屉用，过滤掉小班避免误选。
  Future<ApiResponse> classList({int? campusId, String? keyword, int? type}) {
    final body = <String, dynamic>{};
    if (campusId != null) body['campusId'] = campusId;
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    if (type != null) body['type'] = type;
    return client.post('$_base/classList', data: body);
  }

  /// 班级总览统计：大班、小班、学生、教师及未分配学生数量。
  Future<ApiResponse> classSum() {
    return client.post('$_base/classSum');
  }

  /// 群聊 / 班级详情。
  Future<ApiResponse> classDetail({required String classId}) {
    return client.post(
      '$_base/classDetail',
      data: <String, dynamic>{'classId': readSnowflakeId(classId) ?? classId},
    );
  }

  /// 教室下拉列表。
  Future<ApiResponse> classroomList({int? campusId}) {
    final body = <String, dynamic>{};
    if (campusId != null) body['campusId'] = campusId;
    return client.post('$_base/classroomList', data: body);
  }

  /// 学生下拉 / 名册列表（`SchoolStudentSearchReq`）。
  ///
  /// - [classId]：具体班级传雪花 id 字符串；`null` / 空串 = 全部班级（body 里写 `""`）
  /// - [studentStatus]：在籍 / 休学 / 转学 / 毕业
  Future<ApiResponse> studentList({
    String? classId,
    int current = 1,
    int size = 200,
    String? keyword,
    String? studentStatus,
  }) {
    final body = <String, dynamic>{
      // 全部班级必须传空串，不能省略也不能传 "0"。
      'classId': (classId != null && classId.isNotEmpty)
          ? (readSnowflakeId(classId) ?? classId)
          : '',
      'current': current,
      'size': size,
    };
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    if (studentStatus != null && studentStatus.isNotEmpty) {
      body['studentStatus'] = studentStatus;
    }
    return client.post('$_base/studentList', data: body);
  }

  /// 学生详情。
  ///
  /// `id` 为 `studentList` 响应中每条记录的 `id` 字段（数据库主键，雪花 long），
  /// 以字符串形态传输，避免 web 端 JS number 精度丢失。
  Future<ApiResponse> studentDetail({required String id}) {
    return client.post(
      '$_base/studentDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 学生考试成绩详情。
  Future<ApiResponse> studentExamRecordList({required String studentId}) {
    return client.post(
      '$_base/studentExamRecordList',
      data: <String, dynamic>{
        'studentId': readSnowflakeId(studentId) ?? studentId,
      },
    );
  }

  /// 学生总览统计。`schoolId` 已由 [ApiClient] 通过 header 自动注入，
  /// 不需要在 body 里再传。
  ///
  /// 返回数据结构：
  /// ```json
  /// {
  ///   "data": {
  ///     "abnormalCount": 0,    // 非在籍 / 异动
  ///     "normalCount": 0,      // 在籍
  ///     "residentCount": 0,    // 住校人数
  ///     "totalCount": 0        // 名册总数
  ///   }
  /// }
  /// ```
  Future<ApiResponse> studentSum() {
    return client.post('$_base/studentSum');
  }

  /// 教师列表。
  ///
  /// `classId` 为空串表示全部班级；具体班级传雪花 id 字符串。
  Future<ApiResponse> teacherList({String? classId, String? keyword}) {
    final body = <String, dynamic>{
      'classId': (classId != null && classId.isNotEmpty)
          ? (readSnowflakeId(classId) ?? classId)
          : '',
    };
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/teacherList', data: body);
  }

  /// 教师详情。`id` 为教师 userId（雪花 long 字符串）。
  Future<ApiResponse> teacherDetail({required String id}) {
    return client.post(
      '$_base/teacherDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 教师总览统计（全校口径）。
  ///
  /// 返回数据结构：
  /// ```json
  /// {
  ///   "data": {
  ///     "headTeacherCount": 0,  // 班主任数量
  ///     "onDutyCount":      0,  // 在岗数量
  ///     "onLeaveCount":     0,  // 请假人数
  ///     "totalCount":       0   // 名册总数
  ///   }
  /// }
  /// ```
  Future<ApiResponse> teacherSum() {
    return client.post('$_base/teacherSum');
  }

  // ============== 班级管理 ==============

  /// 新增班级。
  ///
  /// 期望字段（与后端 swagger 对齐，调用方需自行组装）：
  /// ```json
  /// {
  ///   "campusId": 0,
  ///   "classCode": "A00001",
  ///   "classroomId": 1,
  ///   "headTeacherId": "1788178798952914945",
  ///   "name": "一班",
  ///   "studentIds": [0],
  ///   "teacherIds": "1788178798952914945",
  ///   "type": 0
  /// }
  /// ```
  ///
  /// 注：`headTeacherId` / `teacherIds` 后端实际接收 string；
  /// `studentIds` 是 int 数组；`type` 数字标识大班(1) / 小班(2) 等。
  Future<ApiResponse> classSave(Map<String, dynamic> body) {
    return client.post('$_base/classSave', data: body);
  }

  /// 编辑班级。
  ///
  /// 期望字段（与后端 swagger 对齐）：
  /// ```json
  /// {
  ///   "campusId": 0,
  ///   "classCode": "string",
  ///   "classroomId": 0,
  ///   "headTeacherId": 0,
  ///   "id": 1,
  ///   "name": "一班",
  ///   "studentIds": [0],
  ///   "teacherIds": "string"
  /// }
  /// ```
  ///
  /// `id` 必填；其它字段允许部分更新（调用方按需传）。
  Future<ApiResponse> classUpdate(Map<String, dynamic> body) {
    return client.post('$_base/classUpdate', data: body);
  }

  // ============== 课表 ==============

  /// 班级课表查询。
  ///
  /// 对齐后端最新签名：
  /// ```json
  /// {
  ///   "beginDate": "2026-05-01",
  ///   "classId": "1798658711795392514",
  ///   "classIdList": ["1798658711795392514"],
  ///   "endDate": "2026-06-01",
  ///   "teacherId": "1788178798952914945",
  ///   "type": 0
  /// }
  /// ```
  ///
  /// 雪花 id（`classId` / `classIdList` / `teacherId`）必须以字符串形式传输，
  /// 否则在 web 端会因 JS number 53bit 精度而被截断。
  Future<ApiResponse> courseList({
    String? beginDate,
    String? endDate,
    String? classId,
    List<String>? classIdList,
    String? teacherId,
    int? type,
  }) {
    final body = <String, dynamic>{};
    if (beginDate != null && beginDate.isNotEmpty) {
      body['beginDate'] = beginDate;
    }
    if (endDate != null && endDate.isNotEmpty) body['endDate'] = endDate;
    if (classId != null && classId.isNotEmpty) body['classId'] = classId;
    if (classIdList != null && classIdList.isNotEmpty) {
      body['classIdList'] = classIdList;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      body['teacherId'] = teacherId;
    }
    if (type != null) body['type'] = type;
    return client.post('$_base/courseList', data: body);
  }

  /// 大班课批量保存课表。
  ///
  /// 期望字段（与后端 swagger 对齐，调用方需自行组装）：
  /// ```json
  /// [
  ///   {
  ///     "classId": "1798658711795392514",
  ///     "classroomId": 1,
  ///     "color": "#A773FF",
  ///     "date": "2026-05-30T00:00:00.000+00:00",
  ///     "lineNum": 1,
  ///     "subjectId": 1,
  ///     "teacherId": "1788178798952914945"
  ///   }
  /// ]
  /// ```
  ///
  /// `classId` / `teacherId` 必须以 String 形式提交。
  Future<ApiResponse> courseBatchSave(List<Map<String, dynamic>> rows) {
    return client.post('$_base/courseBatchSave', data: rows);
  }

  /// 课表批量删除。后端入参：`{ "id": [2065017767469707300, ...] }`（int64 数组）。
  Future<ApiResponse> courseDelete(List<String> ids) {
    final body = encodeNumericIdArrayRequestBody(ids);
    if (body == null) {
      return Future.value(ApiResponse.failure('缺少有效的课程 id'));
    }
    return client.post(
      '$_base/courseDelete',
      data: body,
    );
  }

  // ============== 小班课申请 ==============

  /// 小班课申请列表。
  ///
  /// 对齐后端 BO（`AppSchoolSmallCourseApplyListBO`）：
  /// ```
  /// classId    int64   班级 id
  /// current    int64   当前页, 默认 1
  /// schoolId   int64   学校 id（由 ApiClient header 注入，不在 body）
  /// size       int64   每页条数, 默认 10
  /// status     int32   0-待审核 / 1-通过 / 2-不通过
  /// teacherId  int64   老师 id
  /// ```
  ///
  /// 调用约定：除 `current` / `size` 外，未传值的字段统一以空串 `""`
  /// 占位发送（后端把空串当作「不过滤」），保证 body 永远是完整的 6 字
  /// 段（`schoolId` 走 header 不算）。`classId` / `teacherId` 是雪花 long
  /// 必须以 String 形式承载，避免 web 端 JS Number 精度截断。
  Future<ApiResponse> schoolSmallCourseApplyList({
    int current = 1,
    int size = 10,
    int? status,
    String? classId,
    String? teacherId,
  }) {
    final body = <String, dynamic>{
      'current': current,
      'size': size,
      'classId': (classId == null || classId.isEmpty) ? '' : classId,
      'teacherId': (teacherId == null || teacherId.isEmpty) ? '' : teacherId,
      'status': status ?? '',
    };
    return client.post('$_base/schoolSmallCourseApplyList', data: body);
  }

  /// 小班课申请详情。`id` 直接传后端原始字符串，兼容雪花 long。
  Future<ApiResponse> schoolSmallCourseApplyDetail(String id) {
    return client.post(
      '$_base/schoolSmallCourseApplyDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 小班课申请审核：`status` 1=通过 / 2=驳回（驳回必填 reason）。
  Future<ApiResponse> schoolSmallCourseApplyAudit({
    required String id,
    required bool pass,
    String? reason,
  }) {
    return client.post(
      '$_base/schoolSmallCourseApplyAudit',
      data: <String, dynamic>{
        'id': id,
        'status': pass ? 1 : 2,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  // ============== 人脸库 ==============

  /// 人脸库底库记录列表（`AppSchoolUserFaceListBO`）。
  ///
  /// `status`: 0=待审核 / 1=审核通过 / 2=审核失败；不传 = 全部。
  Future<ApiResponse> schoolUserFaceList({
    int current = 1,
    int size = 200,
    String? keyword,
    int? status,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    if (status != null) body['status'] = status;
    return client.post('$_base/schoolUserFaceList', data: body);
  }

  /// 人脸库统计：`status0Count` / `status1Count` / `status2Count`。
  Future<ApiResponse> schoolUserFaceSum() {
    return client.post('$_base/schoolUserFaceSum');
  }

  /// 人脸库详情。`id` 为雪花 long，用字符串承载。
  Future<ApiResponse> schoolUserFaceDetail(String id) {
    return client.post(
      '$_base/schoolUserFaceDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 人脸库审核：`status` 1=通过 / 2=不通过。
  Future<ApiResponse> schoolUserFaceAudit({
    required String id,
    required int status,
    String? reason,
  }) {
    return client.post(
      '$_base/schoolUserFaceAudit',
      data: <String, dynamic>{
        'id': id,
        'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// 人脸库提交。`faceImg` 为上传接口返回的相对路径；`userId` 雪花 long。
  Future<ApiResponse> schoolUserFaceSubmit({
    required String faceImg,
    required String userId,
  }) {
    return client.post(
      '$_base/schoolUserFaceSubmit',
      data: <String, dynamic>{'faceImg': faceImg, 'userId': userId},
    );
  }

  // ============== 签课管理 ==============

  /// 签课列表（大课 type=0 / 小课 type=1）。
  ///
  /// `classId` 雪花 long，必须以字符串传输。
  Future<ApiResponse> courseSignManager({
    required String classId,
    required String date,
    required int type,
  }) {
    return client.post(
      '$_base/courseSignManager',
      data: <String, dynamic>{'classId': classId, 'date': date, 'type': type},
    );
  }

  /// 大课签到统计（type=0）。
  Future<ApiResponse> courseSignSum0({
    required String classId,
    required String date,
  }) {
    return client.post(
      '$_base/courseSignSum0',
      data: <String, dynamic>{'classId': classId, 'date': date, 'type': 0},
    );
  }

  /// 小课签到统计（type=1）。
  Future<ApiResponse> courseSignSum1({
    required String classId,
    required String date,
  }) {
    return client.post(
      '$_base/courseSignSum1',
      data: <String, dynamic>{'classId': classId, 'date': date, 'type': 1},
    );
  }

  /// 修改单个学生签到状态。
  ///
  /// `status`: 0-出勤 1-缺勤 2-迟到 3-请假
  Future<ApiResponse> courseSignUpdateSignStatus({
    required String courseId,
    required String studentId,
    required int status,
  }) {
    return client.post(
      '$_base/courseSignUpdateSignStatus',
      data: <String, dynamic>{
        'courseId': courseId,
        'studentId': studentId,
        'status': status,
      },
    );
  }

  /// 小班课查看学生评价。
  Future<ApiResponse> courseCommentList({required String courseId}) {
    return client.post(
      '$_base/courseCommentList',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
      },
    );
  }

  /// 小班课管理员确认完成。`signStatus`: 6-确认 / 7-驳回。
  Future<ApiResponse> courseSignConfirm({
    required String courseId,
    int signStatus = 6,
    String remark = '',
  }) {
    return client.post(
      '$_base/courseSignConfirm',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
        'signStatus': signStatus,
        if (remark.isNotEmpty) 'remark': remark,
      },
    );
  }

  // ============== 教师请假审批 ==============

  /// 教师请假列表（`AppSchoolTeacherLeaveListBO`）。
  ///
  /// `status`: 0-待审批 / 1-已批准 / 2-已拒绝；不传 = 全部。
  Future<ApiResponse> teacherLeaveList({
    int current = 1,
    int size = 200,
    int? status,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    return client.post('$_base/teacherLeaveList', data: body);
  }

  /// 教师请假详情。`id` 为雪花 long 字符串。
  Future<ApiResponse> teacherLeaveDetail({required String id}) {
    return client.post(
      '$_base/teacherLeaveDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 教师请假审批：`status` 1=批准 / 2=拒绝。
  Future<ApiResponse> teacherLeaveAudit({
    required String id,
    required int status,
    String? auditReason,
  }) {
    return client.post(
      '$_base/teacherLeaveAudit',
      data: <String, dynamic>{
        'id': readSnowflakeId(id) ?? id,
        'status': status,
        if (auditReason != null && auditReason.isNotEmpty)
          'auditReason': auditReason,
      },
    );
  }

  // ============== 通知管理 ==============

  /// 通知管理列表。`status`：0=草稿 1=已发布 2=定时中 3=已撤回。
  Future<ApiResponse> noticeManageList({
    int current = 1,
    int size = 200,
    int? status,
    String? type,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    if (type != null && type.isNotEmpty) body['type'] = type;
    return client.post('$_base/noticeManageList', data: body);
  }

  /// 发布 / 保存通知（新建或编辑时传 `id`）。
  Future<ApiResponse> noticeSave(Map<String, dynamic> body) {
    return client.post('$_base/noticeSave', data: body);
  }

  /// 通知详情。`id` 为雪花 long 字符串。
  Future<ApiResponse> noticeDetail({required String id}) {
    return client.post(
      '$_base/noticeDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 删除通知。
  Future<ApiResponse> noticeDelete({required String id}) {
    return client.post(
      '$_base/noticeDelete',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }
}

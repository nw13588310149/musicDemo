import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
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

  // ============== 下拉 / 列表 ==============

  /// 校区下拉列表。
  Future<ApiResponse> campusList() {
    return client.post('$_base/campusList');
  }

  /// 班级列表。可按 `campusId` / `keyword` 过滤；空 body 拉全量。
  Future<ApiResponse> classList({int? campusId, String? keyword}) {
    final body = <String, dynamic>{};
    if (campusId != null) body['campusId'] = campusId;
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/classList', data: body);
  }

  /// 教室下拉列表。
  Future<ApiResponse> classroomList({int? campusId}) {
    final body = <String, dynamic>{};
    if (campusId != null) body['campusId'] = campusId;
    return client.post('$_base/classroomList', data: body);
  }

  /// 学生下拉 / 名册列表。
  ///
  /// 对齐后端最新签名：
  /// ```json
  /// {
  ///   "archiveId": "0",
  ///   "classId": "0",
  ///   "current": 1,
  ///   "keyword": "张三",
  ///   "size": 10,
  ///   "studentStatus": "string"
  /// }
  /// ```
  ///
  /// `archiveId` / `classId` 均为雪花 long，必须以 **字符串** 形式传输，
  /// 否则在 web 端经 JS number(53bit) 转换会丢精度。
  ///
  /// 各参数均可选；空值不会被序列化进 body。`current` / `size` 默认
  /// 1 / 200，需要分页时由调用方覆盖。
  Future<ApiResponse> studentList({
    String? archiveId,
    String? classId,
    int current = 1,
    int size = 200,
    String? keyword,
    String? studentStatus,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (archiveId != null && archiveId.isNotEmpty) {
      body['archiveId'] = archiveId;
    }
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    if (studentStatus != null && studentStatus.isNotEmpty) {
      body['studentStatus'] = studentStatus;
    }
    return client.post('$_base/studentList', data: body);
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

  /// 教师下拉列表。
  Future<ApiResponse> teacherList({String? keyword}) {
    final body = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/teacherList', data: body);
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

  /// 课表批量删除。后端入参格式：`{ "id": ["...","..."] }`，
  /// `id` 同为雪花 long → 用 `List<String>` 透传。
  Future<ApiResponse> courseDelete(List<String> ids) {
    return client.post(
      '$_base/courseDelete',
      data: <String, dynamic>{'id': ids},
    );
  }

  // ============== 小班课申请 ==============

  /// 小班课申请列表。
  ///
  /// 对齐后端最新签名：
  /// ```json
  /// {
  ///   "classId": "1798658711795392514",
  ///   "current": 1,
  ///   "size": 10,
  ///   "status": 0,
  ///   "teacherId": "1788178798952914945"
  /// }
  /// ```
  ///
  /// `schoolId` 由 [ApiClient] 通过 header 注入，不再手动传。
  /// `classId` / `teacherId` 雪花 long → String。
  Future<ApiResponse> schoolSmallCourseApplyList({
    int current = 1,
    int size = 20,
    int? status,
    String? classId,
    String? teacherId,
    String? keyword,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    if (classId != null && classId.isNotEmpty) body['classId'] = classId;
    if (teacherId != null && teacherId.isNotEmpty) {
      body['teacherId'] = teacherId;
    }
    if (keyword != null && keyword.isNotEmpty) body['keyword'] = keyword;
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
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

/// 任课老师端相关接口的 Repository。
///
/// 全部为 `POST /app/school/v2/teacher/*`，对应后端 Swagger 中的
/// **v2 智慧校园-任课老师端 (App School V2 Teacher Controller)**。
/// 头部 `app-token` / `schoolId` 由 [ApiClient] 注入。
///
/// 与教师视图相关的几个核心接口：
///   - [courseList]                      我的课表（按 begin/end 日期过滤）
///   - [schoolSmallCourseApplySave]      提交"申请小课"
///   - [schoolSmallCourseApplyList]      我的小课申请列表
///   - [schoolSmallCourseApplyDetail]    我的小课申请详情
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TeacherRepository(client: client);
});

class TeacherRepository {
  TeacherRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/teacher';

  // ============== 课表 ==============

  /// 任课老师"我的课表"。后端会基于 token 自动定位到当前老师的全部排课。
  /// `beginDate` / `endDate` 为 `yyyy-MM-dd` 字符串（与 admin courseList 一致），
  /// 不传时返回全量。
  Future<ApiResponse> courseList({String? beginDate, String? endDate}) {
    final body = <String, dynamic>{};
    if (beginDate != null && beginDate.isNotEmpty) {
      body['beginDate'] = beginDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['endDate'] = endDate;
    }
    return client.post('$_base/courseList', data: body);
  }

  // ============== 小班课申请 ==============

  /// 提交"申请小课"。
  ///
  /// 期望字段（与后端 swagger 对齐，调用方需自行组装）：
  /// ```json
  /// {
  ///   "classId": "1788178798952914945",
  ///   "classroomId": 1,
  ///   "color": "#ff0000",
  ///   "courseList": [
  ///     {
  ///       "classId": "1798658711795392514",
  ///       "classroomId": 1,
  ///       "color": "#ff0000",
  ///       "date": "2026-05-30",
  ///       "lineNum": 1,
  ///       "subjectId": 1,
  ///       "teacherId": "1788178798952914945"
  ///     }
  ///   ],
  ///   "endDate": "2026-05-08",
  ///   "lineNum": 1,
  ///   "startDate": "2026-05-08",
  ///   "subjectId": 1
  /// }
  /// ```
  ///
  /// 雪花 long（`classId` / `teacherId`）必须以字符串形式提交，避免在 web 端
  /// 因 JS Number 53bit 精度丢失。日期字段统一使用 `yyyy-MM-dd`。
  Future<ApiResponse> schoolSmallCourseApplySave(Map<String, dynamic> body) {
    return client.post('$_base/schoolSmallCourseApplySave', data: body);
  }

  /// 我的小班课申请列表。`current` / `size` 默认 1 / 10，与 swagger 一致。
  Future<ApiResponse> schoolSmallCourseApplyList({
    int current = 1,
    int size = 10,
  }) {
    return client.post(
      '$_base/schoolSmallCourseApplyList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 我的小班课申请详情。`id` 直接用后端原始字符串，兼容雪花 long。
  Future<ApiResponse> schoolSmallCourseApplyDetail(String id) {
    return client.post(
      '$_base/schoolSmallCourseApplyDetail',
      data: <String, dynamic>{'id': id},
    );
  }
}

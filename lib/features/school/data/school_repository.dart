import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SchoolRepository(client: client);
});

class SchoolRepository {
  SchoolRepository({required this.client});

  final ApiClient client;

  /// v2: 同一用户可能绑定多所学校，返回的是 `List<Map>`，调用方按首项取用
  /// 即可（旧版 `/app/user/mySchool` 返回单 Map，已停用）。
  Future<ApiResponse> getSchoolInfo() {
    return client.post('/app/school/v2/user/schoolList');
  }

  Future<ApiResponse> getLearningProgress() {
    return client.post(
      '/app/user/schoolHomeLearningProgress',
      data: const <String, dynamic>{'province': '甘肃省'},
    );
  }

  Future<ApiResponse> getLatestInfo() {
    return client.post(
      '/app/user/homeLatestInfo',
      data: const <String, dynamic>{'province': '甘肃省'},
    );
  }

  /// 课表-左侧时间列表（节次 + 起止时间）。
  ///
  /// 入参：
  /// ```json
  /// { "classId": "1798658711795392514" }
  /// ```
  ///
  /// 不同班级可能采用不同的作息表（中学 / 小学 / 艺考特训等）；不传或空字符
  /// 时按全校默认配置返回。`classId` 雪花 long → String。
  ///
  /// 通常返回结构：
  /// ```json
  /// {
  ///   "data": [
  ///     {"lineNum": 1, "startTime": "08:00", "endTime": "08:40"},
  ///     ...
  ///   ]
  /// }
  /// ```
  ///
  /// 用于课表网格左侧时间冻结列。
  Future<ApiResponse> schoolTimeConfigList({String? classId}) {
    final body = <String, dynamic>{};
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    return client.post('/app/school/v2/user/schoolTimeConfigList', data: body);
  }

  /// 科目下拉列表。`classId` 雪花 long → String；为空时返回全部科目，
  /// 传入班级 id 后返回该班级可选科目。
  Future<ApiResponse> subjectList({String? classId}) {
    final body = <String, dynamic>{};
    if (classId != null && classId.isNotEmpty) {
      body['classId'] = classId;
    }
    return client.post('/app/school/v2/user/subjectList', data: body);
  }
}

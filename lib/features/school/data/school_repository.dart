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
}

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

  Future<ApiResponse> getSchoolInfo() {
    return client.post('/app/user/mySchool');
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

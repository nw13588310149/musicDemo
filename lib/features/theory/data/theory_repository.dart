import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final theoryRepositoryProvider = Provider<TheoryRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TheoryRepository(client: client);
});

class TheoryRepository {
  TheoryRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getDetail(int id) {
    return client.post(
      '/app/user/textbookDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  Future<ApiResponse> saveStudyRecord(int textbookId) {
    return client.post(
      '/app/user/textbookRecordSave',
      data: <String, dynamic>{'textbookId': textbookId},
    );
  }
}

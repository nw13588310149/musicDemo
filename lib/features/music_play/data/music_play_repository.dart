import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final musicPlayRepositoryProvider = Provider<MusicPlayRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return MusicPlayRepository(client: client);
});

class MusicPlayRepository {
  MusicPlayRepository({required this.client});

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

  Future<ApiResponse> setFavorite({
    required int targetId,
    required int type,
    required bool favorite,
  }) {
    return client.post(
      '/app/user/favoriteSave',
      data: <String, dynamic>{
        'favorite': favorite ? 1 : 0,
        'targetId': targetId,
        'type': type,
      },
    );
  }

  Future<ApiResponse> saveStudyRecord(int textbookId) {
    return client.post(
      '/app/user/textbookRecordSave',
      data: <String, dynamic>{'textbookId': textbookId},
    );
  }
}

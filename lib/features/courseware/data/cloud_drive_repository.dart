import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final cloudDriveRepositoryProvider = Provider<CloudDriveRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return CloudDriveRepository(client: client);
});

class CloudDriveRepository {
  CloudDriveRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getCategoryList() {
    return client.post('/app/user/coursewareCategoryList');
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '/app/user/coursewareCategorySave',
      data: <String, dynamic>{'id': '0', 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '/app/user/coursewareCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getCoursewareList(int categoryId) {
    return client.post(
      '/app/user/coursewareList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'current': 1,
        'size': 1000,
      },
    );
  }

  Future<ApiResponse> addCourseware({
    required int categoryId,
    required String title,
    required int type,
    required String audioUrl,
    required String imageJson,
  }) {
    return client.post(
      '/app/user/coursewareSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'title': title,
        'param1': '$type',
        'param2': audioUrl,
        'param3': imageJson,
      },
    );
  }

  Future<ApiResponse> deleteCourseware(int id) {
    return client.post(
      '/app/user/coursewareDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/chat/classList');
  }

  Future<ApiResponse> sendShareMessage({
    required int classId,
    required String content,
  }) {
    return client.post(
      '/app/school/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': content,
        'param1': 'kj',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}

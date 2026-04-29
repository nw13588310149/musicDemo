import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final recordingSystemRepositoryProvider = Provider<RecordingSystemRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return RecordingSystemRepository(client: client);
});

class RecordingSystemRepository {
  RecordingSystemRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getCategories() {
    return client.post('/app/user/recordingCategoryList');
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '/app/user/recordingCategorySave',
      data: <String, dynamic>{'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '/app/user/recordingCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getRecordings(int categoryId) {
    return client.post(
      '/app/user/recordingList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'current': 1,
        'size': 1000,
      },
    );
  }

  Future<ApiResponse> uploadRecording({
    required Uint8List bytes,
    required String filename,
  }) {
    return client.postFormData(
      '/app/user/fileUpload',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
  }

  Future<ApiResponse> saveRecording({
    required int categoryId,
    required String name,
    required String duration,
    required String url,
  }) {
    return client.post(
      '/app/user/recordingSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'duration': duration,
        'id': 0,
        'name': name,
        'param1': 'string',
        'param2': 'string',
        'param3': 'string',
        'url': url,
      },
    );
  }

  Future<ApiResponse> deleteRecording(int id) {
    return client.post(
      '/app/user/recordingDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/chat/classList');
  }

  Future<ApiResponse> shareRecording({
    required int classId,
    required Map<String, dynamic> payload,
  }) {
    return client.post(
      '/app/school/chat/sendMsg',
      data: <String, dynamic>{
        'classId': classId,
        'content': jsonEncode(payload),
        'param1': 'voice',
        'param2': '',
        'param3': '',
        'param4': '',
        'param5': '',
        'type': 3,
      },
    );
  }
}

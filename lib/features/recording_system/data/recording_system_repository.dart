import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

// 录音系统 v2 测试接口地址（与课件云盘保持一致；切换正式环境时修改此常量即可）
const _kRecordingBase = 'https://test-api.yyzl0931.com:9443';

final recordingSystemRepositoryProvider = Provider<RecordingSystemRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return RecordingSystemRepository(client: client);
});

class RecordingSystemRepository {
  RecordingSystemRepository({required this.client});

  final ApiClient client;

  // ── Upload ─────────────────────────────────────────────────────────────────

  // 候选上传端点（按优先级排列，首个成功即返回，与云盘保持一致）。
  static const _kUploadCandidates = <String>[
    '/app/common/v2/fileUpload',
    '/app/user/fileUpload',
    '/app/common/fileUpload',
  ];

  Future<ApiResponse> uploadRecording({
    required Uint8List bytes,
    required String filename,
  }) async {
    ApiResponse last = ApiResponse.failure('上传失败');
    for (final path in _kUploadCandidates) {
      // FormData 是流，每次重试都必须重新构造。
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final resp = await client.postFormData(path, data: form);
      last = resp;
      if (resp.isSuccess) {
        return resp;
      }
    }
    return last;
  }

  // ── Category ───────────────────────────────────────────────────────────────

  Future<ApiResponse> getCategories() {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategoryList',
    );
  }

  Future<ApiResponse> addCategory(String name) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategorySave',
      data: <String, dynamic>{'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameCategory(int id, String name) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategorySave',
      data: <String, dynamic>{'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteCategory(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingCategoryDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Folder ─────────────────────────────────────────────────────────────────

  Future<ApiResponse> getFolderList({
    required int categoryId,
    int current = 1,
    int size = 100,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> addFolder({
    required int categoryId,
    required String name,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': 0, 'name': name},
    );
  }

  Future<ApiResponse> renameFolder({
    required int categoryId,
    required int id,
    required String name,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderSave',
      data: <String, dynamic>{'categoryId': categoryId, 'id': id, 'name': name},
    );
  }

  Future<ApiResponse> deleteFolder(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingFolderDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Recording file ────────────────────────────────────────────────────────

  Future<ApiResponse> getRecordings(
    int categoryId, {
    int folderId = 0,
    String keyword = '',
    int current = 1,
    int size = 1000,
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingList',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'folderId': folderId,
        'keyword': keyword,
        'current': current,
        'size': size,
      },
    );
  }

  /// 新增 / 修改录音作品。后端约定同一个 `recordingSave` 接口：
  /// `id == 0` 时表示新增、`id > 0` 时按 id 更新。请求体形如：
  /// ```json
  /// {
  ///   "categoryId": 2,
  ///   "duration": "01:02:03",
  ///   "filePath": "app/upload/.../xxx.png",
  ///   "folderId": 0,
  ///   "id": 0,
  ///   "name": "作品名称",
  ///   "param1": "string",
  ///   "param2": "string",
  ///   "param3": "string"
  /// }
  /// ```
  Future<ApiResponse> saveRecording({
    required int categoryId,
    required String name,
    required String duration,
    required String filePath,
    int id = 0,
    int folderId = 0,
    String param1 = '',
    String param2 = '',
    String param3 = '',
  }) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingSave',
      data: <String, dynamic>{
        'categoryId': categoryId,
        'duration': duration,
        'filePath': filePath,
        'folderId': folderId,
        'id': id,
        'name': name,
        'param1': param1,
        'param2': param2,
        'param3': param3,
      },
    );
  }

  Future<ApiResponse> deleteRecording(int id) {
    return client.post(
      '$_kRecordingBase/app/recording/v2/recordingDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  // ── Share (班级分享，沿用旧接口) ────────────────────────────────────────────

  Future<ApiResponse> getClassList() {
    return client.post('/app/school/v2/chat/classList');
  }

  Future<ApiResponse> shareRecording({
    required String classId,
    required Map<String, dynamic> payload,
  }) {
    return client.post(
      '/app/school/v2/chat/sendMsg',
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

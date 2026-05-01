import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

final shellRepositoryProvider = Provider<ShellRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(appStorageProvider);
  return ShellRepository(storage: storage, client: client);
});

class ShellRepository {
  ShellRepository({required this.storage, required this.client});

  final AppStorage storage;
  final ApiClient client;

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  /// v2: 同一用户可能绑定多所学校，返回的是 `List<Map>`，调用方按首项取用
  /// 即可（旧版 `/app/user/mySchool` 返回单 Map，已停用）。
  Future<ApiResponse> getSchoolInfo() {
    return client.post('/app/school/v2/user/schoolList');
  }

  Future<ApiResponse> getUnreadCount() {
    return client.post('/app/msg/getUnReadMsgCount');
  }

  Future<ApiResponse> getMessageList() {
    return client.post(
      '/app/msg/list',
      data: const <String, dynamic>{'current': 1, 'size': 10},
    );
  }

  Future<ApiResponse> markRead(List<int> ids) {
    return client.post(
      '/app/msg/updateRead',
      data: <String, dynamic>{'ids': ids},
    );
  }

  Future<ApiResponse> logout() {
    return client.post('/app/user/logout');
  }

  /// 省份地区列表（对齐 1.0 `getCity`）。
  Future<ApiResponse> provinceCityList() => client.post(
    '/app/common/provinceCityList',
    data: const <String, dynamic>{},
  );

  /// 仅更新「所在地区」字段，对应 1.0 顶部下拉中的省份切换。
  Future<ApiResponse> updateProvince(String province) => client.post(
    '/app/user/userinfoUpdate',
    data: <String, dynamic>{'province': province},
  );
}

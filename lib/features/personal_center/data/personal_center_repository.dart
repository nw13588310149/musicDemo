import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final personalCenterRepositoryProvider = Provider<PersonalCenterRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return PersonalCenterRepository(client: client);
});

/// 个人中心相关接口（对齐 1.0 `api/home.js`）。
class PersonalCenterRepository {
  PersonalCenterRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<ApiResponse> getMyInfo() => _client.post('/app/user/myInfo');

  Future<ApiResponse> vipList() =>
      _client.post('/app/user/vipList', data: const <String, dynamic>{});

  Future<ApiResponse> myQrcode() =>
      _client.post('/app/user/myQrcode', data: const <String, dynamic>{});

  Future<ApiResponse> vipCardRedeem(String cardNumber) => _client.post(
        '/app/user/vipCardRedeem',
        data: <String, dynamic>{'cardNumber': cardNumber},
      );
}

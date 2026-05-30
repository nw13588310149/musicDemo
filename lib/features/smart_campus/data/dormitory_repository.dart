import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';

/// 宿管端 `POST /app/school/v2/dormitory/*`。
final dormitoryRepositoryProvider = Provider<DormitoryRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return DormitoryRepository(client: client);
});

class DormitoryRepository {
  DormitoryRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/dormitory';

  /// 宿管首页通知列表。
  Future<ApiResponse> noticeList({
    int current = 1,
    int size = 20,
  }) {
    return client.post(
      '$_base/noticeList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 宿管端通知详情。`id` 为雪花 long 字符串。
  Future<ApiResponse> noticeDetail({required String id}) {
    return client.post(
      '$_base/noticeDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  // ============== 按宿舍查寝 ==============

  /// 查寝顶部统计。
  Future<ApiResponse> dormitoryCheckStat({
    String? buildingId,
    String? floorId,
    String? date,
  }) {
    return client.post(
      '$_base/dormitoryCheckStat',
      data: _checkFilterBody(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      ),
    );
  }

  /// 宿管管辖宿舍楼列表。
  Future<ApiResponse> dormitoryManagedBuildingList() {
    return client.post('$_base/dormitoryManagedBuildingList');
  }

  /// 指定宿舍楼的楼层列表。
  Future<ApiResponse> dormitoryFloorList({required String buildingId}) {
    return client.post(
      '$_base/dormitoryFloorList',
      data: <String, dynamic>{
        'buildingId': readSnowflakeId(buildingId) ?? buildingId,
      },
    );
  }

  /// 查寝寝室列表。
  Future<ApiResponse> dormitoryCheckRoomList({
    String? buildingId,
    String? floorId,
    String? date,
  }) {
    return client.post(
      '$_base/dormitoryCheckRoomList',
      data: _checkFilterBody(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      ),
    );
  }

  /// 查寝房间一键打卡。
  Future<ApiResponse> dormitoryCheckRoomOneClick({
    required String roomId,
    String? date,
  }) {
    final body = <String, dynamic>{
      'roomId': readSnowflakeId(roomId) ?? roomId,
    };
    if (date != null && date.isNotEmpty) body['date'] = date;
    return client.post('$_base/dormitoryCheckRoomOneClick', data: body);
  }

  /// 单个学生查寝状态修改。
  Future<ApiResponse> dormitoryCheckUserUpdate({
    required String userId,
    required String status,
    String? date,
  }) {
    final body = <String, dynamic>{
      'userId': readSnowflakeId(userId) ?? userId,
      'status': status,
    };
    if (date != null && date.isNotEmpty) body['date'] = date;
    return client.post('$_base/dormitoryCheckUserUpdate', data: body);
  }

  Map<String, dynamic> _checkFilterBody({
    String? buildingId,
    String? floorId,
    String? date,
  }) {
    final body = <String, dynamic>{};
    if (buildingId != null && buildingId.isNotEmpty) {
      body['buildingId'] = readSnowflakeId(buildingId) ?? buildingId;
    }
    if (floorId != null && floorId.isNotEmpty) {
      body['floorId'] = readSnowflakeId(floorId) ?? floorId;
    }
    if (date != null && date.isNotEmpty) body['date'] = date;
    return body;
  }
}

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

  // ============== 宿管首页 / 历史 / 异常 / 补卡 ==============

  /// 宿管首页工作台汇总。
  Future<ApiResponse> index() {
    return client.post('$_base/index');
  }

  /// 查寝历史记录。
  Future<ApiResponse> dormitoryCheckHistory({
    String? buildingId,
    String? floorId,
    String? roomId,
    String? beginDate,
    String? endDate,
    String? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/dormitoryCheckHistory',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': readSnowflakeId(buildingId) ?? buildingId,
        if (floorId != null && floorId.isNotEmpty)
          'floorId': readSnowflakeId(floorId) ?? floorId,
        if (roomId != null && roomId.isNotEmpty)
          'roomId': readSnowflakeId(roomId) ?? roomId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// 单次查寝详情。
  Future<ApiResponse> dormitoryCheckDetail({required String id}) {
    return client.post(
      '$_base/dormitoryCheckDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 查寝异常处理。
  Future<ApiResponse> dormitoryCheckExceptionHandle({
    required String checkId,
    required String studentId,
    required int handleStatus,
    String remark = '',
  }) {
    return client.post(
      '$_base/dormitoryCheckExceptionHandle',
      data: <String, dynamic>{
        'checkId': readSnowflakeId(checkId) ?? checkId,
        'studentId': readSnowflakeId(studentId) ?? studentId,
        'handleStatus': handleStatus,
        if (remark.isNotEmpty) 'remark': remark,
      },
    );
  }

  /// 导出查寝记录。
  Future<ApiResponse> dormitoryCheckExport({
    String? buildingId,
    String? floorId,
    String? roomId,
    String? beginDate,
    String? endDate,
    String? status,
  }) {
    return client.post(
      '$_base/dormitoryCheckExport',
      data: <String, dynamic>{
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': readSnowflakeId(buildingId) ?? buildingId,
        if (floorId != null && floorId.isNotEmpty)
          'floorId': readSnowflakeId(floorId) ?? floorId,
        if (roomId != null && roomId.isNotEmpty)
          'roomId': readSnowflakeId(roomId) ?? roomId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// 宿管端补卡申请列表。
  Future<ApiResponse> dormitoryMakeupList({
    String? buildingId,
    int? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/dormitoryMakeupList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': readSnowflakeId(buildingId) ?? buildingId,
        if (status != null) 'status': status,
      },
    );
  }

  /// 补卡申请详情。
  Future<ApiResponse> dormitoryMakeupDetail({required String id}) {
    return client.post(
      '$_base/dormitoryMakeupDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 审批补卡申请。`status`: 1-通过 / 2-拒绝。
  Future<ApiResponse> dormitoryMakeupAudit({
    required String id,
    required int status,
    String auditReason = '',
  }) {
    return client.post(
      '$_base/dormitoryMakeupAudit',
      data: <String, dynamic>{
        'id': readSnowflakeId(id) ?? id,
        'status': status,
        if (auditReason.isNotEmpty) 'auditReason': auditReason,
      },
    );
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

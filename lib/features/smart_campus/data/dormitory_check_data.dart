/// 宿管端「按宿舍查寝」API 数据模型与 JSON 解析。
library;

import '../../../core/network/snowflake_id.dart';

class DormitoryCheckStat {
  const DormitoryCheckStat({
    required this.bedCount,
    required this.normalCount,
    required this.lateCount,
    required this.notCheckedCount,
  });

  final int bedCount;
  final int normalCount;
  final int lateCount;
  final int notCheckedCount;

  static const zero = DormitoryCheckStat(
    bedCount: 0,
    normalCount: 0,
    lateCount: 0,
    notCheckedCount: 0,
  );
}

class DormitoryBuildingOption {
  const DormitoryBuildingOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  static const all = DormitoryBuildingOption(id: '', label: '全部宿舍楼');
}

class DormitoryFloorOption {
  const DormitoryFloorOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  static const all = DormitoryFloorOption(id: '', label: '全部楼层');
}

enum DormitoryStudentCheckStatus {
  unchecked('未打卡'),
  normal('正常'),
  lateReturn('晚归');

  const DormitoryStudentCheckStatus(this.apiValue);
  final String apiValue;

  static DormitoryStudentCheckStatus fromApi(String raw) {
    final v = raw.trim();
    if (v == '正常' || v == '已打卡') {
      return DormitoryStudentCheckStatus.normal;
    }
    if (v == '晚归') return DormitoryStudentCheckStatus.lateReturn;
    return DormitoryStudentCheckStatus.unchecked;
  }
}

class DormitoryRoomStudent {
  const DormitoryRoomStudent({
    required this.userId,
    required this.name,
    required this.studentNo,
    required this.avatarUrl,
    required this.status,
  });

  final String userId;
  final String name;
  final String studentNo;
  final String avatarUrl;
  final DormitoryStudentCheckStatus status;
}

class DormitoryRoomCheck {
  const DormitoryRoomCheck({
    required this.roomId,
    required this.roomName,
    required this.buildingDesc,
    required this.session,
    required this.deadline,
    required this.allChecked,
    required this.students,
  });

  final String roomId;
  final String roomName;
  final String buildingDesc;
  final String session;
  final String deadline;
  final bool allChecked;
  final List<DormitoryRoomStudent> students;
}

DormitoryCheckStat parseDormitoryCheckStat(dynamic raw) {
  if (raw is! Map) return DormitoryCheckStat.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  return DormitoryCheckStat(
    bedCount: _asInt(m['bedCount']) ?? 0,
    normalCount: _asInt(m['normalCount']) ?? 0,
    lateCount: _asInt(m['lateCount']) ?? 0,
    notCheckedCount: _asInt(m['notCheckedCount']) ?? 0,
  );
}

List<DormitoryBuildingOption> parseDormitoryManagedBuildingList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryBuildingOption>[DormitoryBuildingOption.all];
  for (final m in rows) {
    final id =
        readSnowflakeId(m['buildingId']) ?? m['buildingId']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(
      DormitoryBuildingOption(
        id: id,
        label: _pickString(m, ['buildingName'], '未命名宿舍楼'),
      ),
    );
  }
  return parsed;
}

List<DormitoryFloorOption> parseDormitoryFloorList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryFloorOption>[DormitoryFloorOption.all];
  for (final m in rows) {
    final id = readSnowflakeId(m['floorId']) ?? m['floorId']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(
      DormitoryFloorOption(
        id: id,
        label: _pickString(m, ['floorName'], '未命名楼层'),
      ),
    );
  }
  return parsed;
}

List<DormitoryRoomCheck> parseDormitoryCheckRoomList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryRoomCheck>[];
  for (final m in rows) {
    final roomId =
        readSnowflakeId(m['roomId']) ?? m['roomId']?.toString() ?? '';
    if (roomId.isEmpty) continue;
    final buildingName = _pickString(m, ['buildingName'], '');
    final floorName = _pickString(m, ['floorName'], '');
    final buildingDesc = [
      if (buildingName.isNotEmpty) buildingName,
      if (floorName.isNotEmpty) floorName,
    ].join('·');
    final students = _parseUserList(m['userList']);
    parsed.add(
      DormitoryRoomCheck(
        roomId: roomId,
        roomName: _pickString(m, ['roomName'], '宿舍'),
        buildingDesc: buildingDesc.isEmpty ? '—' : buildingDesc,
        session: _pickString(m, ['checkType'], '查寝'),
        deadline: _pickString(m, ['checkDeadline'], '—'),
        allChecked: m['allChecked'] == true ||
            m['allChecked']?.toString() == 'true' ||
            m['allChecked'] == 1,
        students: students,
      ),
    );
  }
  return parsed;
}

List<DormitoryRoomStudent> _parseUserList(dynamic raw) {
  if (raw is! List) return const [];
  final parsed = <DormitoryRoomStudent>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final userId =
        readSnowflakeId(m['userId']) ??
        readSnowflakeId(m['studentId']) ??
        m['userId']?.toString() ??
        m['studentId']?.toString() ??
        '';
    if (userId.isEmpty) continue;
    parsed.add(
      DormitoryRoomStudent(
        userId: userId,
        name: _pickString(m, ['studentName', 'name', 'userName'], '未命名'),
        studentNo: _pickString(m, ['studentNo', 'userNo'], '—'),
        avatarUrl: _pickString(m, ['studentHeadUrl', 'headUrl', 'avatar'], ''),
        status: DormitoryStudentCheckStatus.fromApi(
          _pickString(m, ['status', 'checkStatus'], '未打卡'),
        ),
      ),
    );
  }
  return parsed;
}

List<Map<String, dynamic>> _coerceList(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = raw.cast<String, dynamic>();
    if (m['data'] is List) return _coerceList(m['data']);
    if (m['records'] is List) return _coerceList(m['records']);
  }
  return const [];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

int? _asInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

String dormitoryCheckDateParam([DateTime? date]) {
  final d = date ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

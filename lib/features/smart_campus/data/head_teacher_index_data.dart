/// 班主任端「班级工作台 / 首页」`headTeacherIndex` 数据模型。
library;

import '../../../core/network/snowflake_id.dart';

class HeadTeacherClassItem {
  const HeadTeacherClassItem({
    required this.classId,
    required this.className,
    required this.studentCount,
  });

  final String classId;
  final String className;
  final int studentCount;

  factory HeadTeacherClassItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['classId'] ?? json['id'];
    final id = rawId == null ? '' : readSnowflakeId(rawId) ?? rawId.toString();
    return HeadTeacherClassItem(
      classId: id,
      className: _pickString(json, ['className', 'name'], '未命名班级'),
      studentCount: _asInt(json['studentCount']) ?? 0,
    );
  }
}

class HeadTeacherIndexRes {
  const HeadTeacherIndexRes({
    required this.chatUnreadCount,
    required this.chatWaitingCount,
    required this.classList,
    required this.pendingLeaveCount,
    required this.pendingMakeupCount,
    required this.todayAbnormalDormCount,
  });

  final int chatUnreadCount;
  final int chatWaitingCount;
  final List<HeadTeacherClassItem> classList;
  final int pendingLeaveCount;
  final int pendingMakeupCount;
  final int todayAbnormalDormCount;

  static const zero = HeadTeacherIndexRes(
    chatUnreadCount: 0,
    chatWaitingCount: 0,
    classList: [],
    pendingLeaveCount: 0,
    pendingMakeupCount: 0,
    todayAbnormalDormCount: 0,
  );

  int get totalStudentCount =>
      classList.fold<int>(0, (sum, c) => sum + c.studentCount);

  String get classNamesLabel {
    if (classList.isEmpty) return '—';
    return classList.map((c) => c.className).join('、');
  }

  int get pendingTodoCount =>
      pendingLeaveCount + pendingMakeupCount + todayAbnormalDormCount;
}

HeadTeacherIndexRes parseHeadTeacherIndexRes(dynamic raw) {
  if (raw is! Map) return HeadTeacherIndexRes.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }

  final classRaw = m['classList'];
  final classes = classRaw is List
      ? classRaw
            .whereType<Map>()
            .map((e) => HeadTeacherClassItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
      : const <HeadTeacherClassItem>[];

  return HeadTeacherIndexRes(
    chatUnreadCount: _asInt(m['chatUnreadCount']) ?? 0,
    chatWaitingCount: _asInt(m['chatWaitingCount']) ?? 0,
    classList: classes,
    pendingLeaveCount: _asInt(m['pendingLeaveCount']) ?? 0,
    pendingMakeupCount: _asInt(m['pendingMakeupCount']) ?? 0,
    todayAbnormalDormCount: _asInt(m['todayAbnormalDormCount']) ?? 0,
  );
}

int? _asInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString());
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

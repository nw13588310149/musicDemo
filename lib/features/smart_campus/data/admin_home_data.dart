import 'admin_notice_data.dart';

class AdminHomeSummary {
  const AdminHomeSummary({
    this.studentCount = 0,
    this.teacherCount = 0,
    this.classCount = 0,
    this.toDoTodayCount = 0,
    this.leaveStatus0Count = 0,
    this.smallCourseSignStatus5Count = 0,
    this.userFaceNotRecordedCount = 0,
    this.postStatus0Count = 0,
  });

  final int studentCount;
  final int teacherCount;
  final int classCount;
  final int toDoTodayCount;
  final int leaveStatus0Count;
  final int smallCourseSignStatus5Count;
  final int userFaceNotRecordedCount;
  final int postStatus0Count;

  factory AdminHomeSummary.fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return AdminHomeSummary(
      studentCount: _readInt(json['studentCount']),
      teacherCount: _readInt(json['teacherCount']),
      classCount: _readInt(json['classCount']),
      toDoTodayCount: _readInt(json['toDoTodayCount']),
      leaveStatus0Count: _readInt(json['leaveStatus0Count']),
      smallCourseSignStatus5Count: _readInt(
        json['smallCourseSignStatus5Count'],
      ),
      userFaceNotRecordedCount: _readInt(json['userFaceNotRecordedCount']),
      postStatus0Count: _readInt(json['postStatus0Count']),
    );
  }
}

class AdminHomeNotice {
  const AdminHomeNotice({
    required this.id,
    required this.tag,
    required this.text,
    required this.time,
    required this.highlighted,
  });

  final String id;
  final String tag;
  final String text;
  final String time;
  final bool highlighted;

  factory AdminHomeNotice.fromRecord(AdminNoticeRecord record) {
    final text = record.content.trim().isEmpty
        ? record.title
        : '${record.title}：${record.content.trim()}';
    return AdminHomeNotice(
      id: record.id,
      tag: record.type.trim().isEmpty ? '通知' : record.type,
      text: text,
      time: _shortDisplayTime(record.time),
      highlighted: record.priority != AdminNoticePriority.normal,
    );
  }
}

List<AdminHomeNotice> parseAdminHomeNotices(dynamic raw) {
  return parseAdminNoticeList(raw)
      .where((record) => record.status == AdminNoticeStatus.published)
      .map(AdminHomeNotice.fromRecord)
      .toList(growable: false);
}

int _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String _shortDisplayTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '—') return '—';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

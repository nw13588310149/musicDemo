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
    final text = formatNoticePreviewText(record.title, record.content);
    return AdminHomeNotice(
      id: record.id,
      tag: record.type.trim().isEmpty ? '通知' : record.type,
      text: text,
      time: record.time,
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

/// 管理员首页「数据看板」近 7 日登录曲线。
class AdminHomeLoginChart {
  const AdminHomeLoginChart({this.points = const []});

  final List<AdminHomeLoginChartPoint> points;

  List<double> get values =>
      points.map((point) => point.count.toDouble()).toList(growable: false);

  List<String> get xLabels =>
      points.map((point) => point.weekdayLabel).toList(growable: false);
}

class AdminHomeLoginChartPoint {
  const AdminHomeLoginChartPoint({
    required this.loginDate,
    required this.count,
    required this.weekdayLabel,
  });

  final String loginDate;
  final int count;
  final String weekdayLabel;
}

const _adminHomeWeekdayLabels = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

AdminHomeLoginChart parseAdminHomeLoginChart(
  dynamic raw, {
  required String startDate,
  required String endDate,
}) {
  final start = _parseAdminHomeIsoDate(startDate);
  final end = _parseAdminHomeIsoDate(endDate);
  if (start == null || end == null || start.isAfter(end)) {
    return const AdminHomeLoginChart();
  }

  final countByDate = <String, int>{};
  for (final row in _coerceLoginChartRows(raw)) {
    final date = row['loginDate']?.toString().trim() ?? '';
    if (date.isEmpty) continue;
    countByDate[date] = _readInt(row['count']);
  }

  final points = <AdminHomeLoginChartPoint>[];
  for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
    final iso = formatAdminHomeIsoDate(day);
    points.add(
      AdminHomeLoginChartPoint(
        loginDate: iso,
        count: countByDate[iso] ?? 0,
        weekdayLabel: _adminHomeWeekdayLabels[day.weekday - 1],
      ),
    );
  }
  return AdminHomeLoginChart(points: points);
}

/// 登录人数 Y 轴上限：全 0 时默认 10，否则向上取整到 5 的倍数。
double adminHomeLoginChartMaxY(List<double> values) {
  if (values.isEmpty) return 10;
  final max = values.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return 10;
  return ((max / 5).ceil() * 5).toDouble();
}

List<String> buildAdminHomeLoginChartYLabels(double maxY) {
  final top = maxY <= 0 ? 10 : maxY;
  final step = top / 5;
  return [
    for (var i = 5; i >= 0; i--)
      i == 0 ? '0' : (step * i).round().toString(),
  ];
}

List<Map<String, dynamic>> _coerceLoginChartRows(dynamic raw) {
  dynamic list = raw;
  if (list is Map && list['data'] is List) {
    list = list['data'];
  }
  if (list is! List) return const [];

  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

DateTime? _parseAdminHomeIsoDate(String raw) {
  final parts = raw.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatAdminHomeIsoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 数据看板查询区间：含今天在内共 7 天（`startDate` … `endDate`）。
({String startDate, String endDate}) adminHomeLast7DaysDateRange({
  DateTime? anchor,
}) {
  final end = anchor ?? DateTime.now();
  final endDate = DateTime(end.year, end.month, end.day);
  final startDate = endDate.subtract(const Duration(days: 6));
  return (
    startDate: formatAdminHomeIsoDate(startDate),
    endDate: formatAdminHomeIsoDate(endDate),
  );
}

int _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}


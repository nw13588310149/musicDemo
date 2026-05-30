/// 学生端「课堂签到」：今日小课解析与签到状态推导。
library;

import '../../../core/network/snowflake_id.dart';

enum StudentCourseSlotPhase { inProgress, upcoming, ended }

class StudentTimeConfig {
  const StudentTimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<StudentTimeConfig> kDefaultStudentTimeConfigs = [
  StudentTimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  StudentTimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  StudentTimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  StudentTimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  StudentTimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

class StudentTodayCourse {
  const StudentTodayCourse({
    required this.courseId,
    required this.subjectName,
    required this.teacherName,
    required this.location,
    required this.timeStart,
    required this.timeEnd,
    required this.durationLabel,
    required this.lineNum,
    required this.phase,
    this.teacherSignInTime,
    this.teacherSignOutTime,
    this.studentSignInTime,
    this.studentSignOutTime,
    this.signMethod = '按键打卡',
    this.fenceLabel,
    this.evaluationScore,
    this.evaluationComment,
  });

  final String courseId;
  final String subjectName;
  final String teacherName;
  final String location;
  final String timeStart;
  final String timeEnd;
  final String durationLabel;
  final int lineNum;
  final StudentCourseSlotPhase phase;
  final String? teacherSignInTime;
  final String? teacherSignOutTime;
  final String? studentSignInTime;
  final String? studentSignOutTime;
  final String signMethod;
  final String? fenceLabel;
  final double? evaluationScore;
  final String? evaluationComment;

  String get periodLabel =>
      lineNum > 0 ? '第$lineNum节' : '今日课程';

  String get timeRange => '$timeStart-$timeEnd';

  bool get canCheckIn =>
      _hasTime(teacherSignInTime) &&
      !_hasTime(studentSignInTime);

  bool get canCheckOut =>
      _hasTime(studentSignInTime) &&
      _hasTime(teacherSignOutTime) &&
      !_hasTime(studentSignOutTime);

  bool get canComment =>
      _hasTime(studentSignOutTime) &&
      (evaluationScore == null && (evaluationComment?.isEmpty ?? true));

  bool _hasTime(String? value) =>
      value != null && value.trim().isNotEmpty && value.trim() != '-';
}

List<StudentTodayCourse> parseStudentTodaySmallCourses({
  required dynamic raw,
  required List<StudentTimeConfig> timeConfigs,
  required DateTime now,
  String todayIso = '',
}) {
  final configs =
      timeConfigs.isNotEmpty ? timeConfigs : kDefaultStudentTimeConfigs;
  final rows = _extractCourseRows(raw);
  final courses = <StudentTodayCourse>[];

  for (final row in rows) {
    final flat = _flattenCourseRow(row);
    if (!_isSmallCourse(flat)) continue;

    final dateStr = _pickString(flat, ['date', 'classDate', 'courseDate'], '');
    if (todayIso.isNotEmpty &&
        dateStr.isNotEmpty &&
        !_sameDay(dateStr, todayIso)) {
      continue;
    }

    final courseId = readSnowflakeId(flat['id'] ?? flat['courseId']) ?? '';
    if (courseId.isEmpty) continue;

    final times = _resolveRowTimes(flat, configs);
    if (times.start.isEmpty || times.end.isEmpty) continue;

    final subjectName = _pickString(flat, [
      'subjectName',
      'courseName',
      'subject',
      'name',
    ], '—');
    final teacherName = _pickString(flat, [
      'teacherRealname',
      'teacherName',
      'realname',
      'realName',
      'teacherNickname',
      'teacher',
    ], '—');
    final location = _pickString(flat, [
      'classroomName',
      'roomName',
      'classroom',
    ], '—');

    final mins = _minutesBetweenHm(times.start, times.end);
    final durationLabel = mins > 0 ? '$mins分钟' : '—';

    final scoreRaw = flat['score'] ?? flat['commentScore'] ?? flat['studentScore'];
    final score = scoreRaw == null
        ? null
        : double.tryParse(scoreRaw.toString());

    courses.add(
      StudentTodayCourse(
        courseId: courseId,
        subjectName: subjectName,
        teacherName: teacherName,
        location: location,
        timeStart: times.start,
        timeEnd: times.end,
        durationLabel: durationLabel,
        lineNum: times.lineNum,
        phase: _slotPhase(now, times.start, times.end),
        teacherSignInTime: _pickNullable(flat, [
          'teacherSignInTime',
          'teacherCheckInTime',
          'teacherSignTime',
        ]),
        teacherSignOutTime: _pickNullable(flat, [
          'teacherSignOutTime',
          'teacherCheckOutTime',
        ]),
        studentSignInTime: _pickNullable(flat, [
          'studentSignInTime',
          'studentCheckInTime',
          'signInTime',
          'checkInTime',
        ]),
        studentSignOutTime: _pickNullable(flat, [
          'studentSignOutTime',
          'studentCheckOutTime',
          'signOutTime',
          'checkOutTime',
        ]),
        signMethod: _pickString(flat, [
          'signMethod',
          'signTypeName',
          'checkMethod',
          'method',
        ], '按键打卡'),
        fenceLabel: _pickNullable(flat, [
          'fenceLabel',
          'fenceName',
          'locationTip',
        ]),
        evaluationScore: score,
        evaluationComment: _pickNullable(flat, [
          'comment',
          'studentComment',
          'evaluation',
          'evaluate',
        ]),
      ),
    );
  }

  courses.sort((a, b) {
    final byStart = _hmSortKey(a.timeStart).compareTo(_hmSortKey(b.timeStart));
    if (byStart != 0) return byStart;
    return a.lineNum.compareTo(b.lineNum);
  });
  return courses;
}

StudentTodayCourse? pickActiveStudentCourse(List<StudentTodayCourse> courses) {
  if (courses.isEmpty) return null;
  for (final c in courses) {
    if (c.phase == StudentCourseSlotPhase.inProgress) return c;
  }
  for (final c in courses) {
    if (c.phase == StudentCourseSlotPhase.upcoming) return c;
  }
  return courses.last;
}

List<StudentTimeConfig> parseStudentTimeConfigs(dynamic raw) {
  final list = _extractList(raw);
  final configs = <StudentTimeConfig>[];
  for (final m in list) {
    final lineNumRaw = m['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
    if (lineNum < 1) continue;
    final start = _trimHm(
      _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
    );
    final end = _trimHm(
      _pickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
    );
    if (start.isEmpty || end.isEmpty) continue;
    configs.add(StudentTimeConfig(lineNum: lineNum, start: start, end: end));
  }
  configs.sort((a, b) => a.lineNum.compareTo(b.lineNum));
  return configs;
}

String formatChineseDateTitle(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${date.year}年${date.month}月${date.day}日 '
      '${weekdays[date.weekday - 1]}';
}

String todayIsoDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _ResolvedRowTimes {
  const _ResolvedRowTimes({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

_ResolvedRowTimes _resolveRowTimes(
  Map<String, dynamic> row,
  List<StudentTimeConfig> configs,
) {
  final lineNumRaw = row['lineNum'];
  final lineNum = lineNumRaw is int
      ? lineNumRaw
      : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);

  if (lineNum > 0) {
    for (final c in configs) {
      if (c.lineNum == lineNum) {
        return _ResolvedRowTimes(lineNum: lineNum, start: c.start, end: c.end);
      }
    }
    if (lineNum <= configs.length) {
      final c = configs[lineNum - 1];
      return _ResolvedRowTimes(lineNum: lineNum, start: c.start, end: c.end);
    }
  }

  final start = _trimHm(
    _pickString(row, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
  );
  final end = _trimHm(
    _pickString(row, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
  );
  return _ResolvedRowTimes(lineNum: lineNum, start: start, end: end);
}

bool _isSmallCourse(Map<String, dynamic> json) {
  final typeRaw = json['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  return type == 1 || type == 2;
}

StudentCourseSlotPhase _slotPhase(DateTime now, String startHm, String endHm) {
  final start = _dateAtHm(now, startHm);
  final end = _dateAtHm(now, endHm);
  if (start == null || end == null) return StudentCourseSlotPhase.upcoming;
  if (now.isBefore(start)) return StudentCourseSlotPhase.upcoming;
  if (now.isAfter(end)) return StudentCourseSlotPhase.ended;
  return StudentCourseSlotPhase.inProgress;
}

DateTime? _dateAtHm(DateTime day, String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

int _hmSortKey(String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

int _minutesBetweenHm(String start, String end) {
  final a = _hmSortKey(start);
  final b = _hmSortKey(end);
  if (a <= 0 || b <= 0 || b <= a) return 0;
  return b - a;
}

bool _sameDay(String dateStr, String todayIso) {
  final d = DateTime.tryParse(dateStr.split('T').first);
  if (d == null) return dateStr.startsWith(todayIso);
  final iso =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return iso == todayIso;
}

Map<String, dynamic> _flattenCourseRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(String key, List<MapEntry<String, String>> fieldMap) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      flat.putIfAbsent(entry.value, () => s);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
  ]);

  return flat;
}

List<Map<String, dynamic>> _extractCourseRows(dynamic raw) {
  final list = <Map<String, dynamic>>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is List) {
        for (final item in v) {
          if (item is Map) {
            list.add(_flattenCourseRow(Map<String, dynamic>.from(item)));
          }
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        list.add(_flattenCourseRow(Map<String, dynamic>.from(item)));
      }
    }
  }
  return list;
}

List<Map<String, dynamic>> _extractList(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
  if (map == null) return const [];
  for (final key in ['records', 'list', 'data', 'rows']) {
    final inner = map[key];
    if (inner is List) {
      return [
        for (final item in inner)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
  }
  return const [];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}

String? _pickNullable(Map<String, dynamic> json, List<String> keys) {
  final value = _pickString(json, keys, '');
  return value.isEmpty ? null : value;
}

String _trimHm(String value) {
  if (value.isEmpty) return value;
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return value;
}

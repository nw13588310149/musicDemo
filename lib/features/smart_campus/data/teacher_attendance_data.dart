import '../../../core/network/snowflake_id.dart';
import 'course_sign_data.dart';

enum TeacherAttendanceRange { total, term, month }

extension TeacherAttendanceRangeX on TeacherAttendanceRange {
  ({String? beginDate, String? endDate}) dates(DateTime now) {
    switch (this) {
      case TeacherAttendanceRange.total:
        return (beginDate: null, endDate: null);
      case TeacherAttendanceRange.term:
        final beginsInPreviousYear = now.month < 8;
        final begin = beginsInPreviousYear
            ? DateTime(now.year - 1, 8)
            : DateTime(now.year, 8);
        final end = beginsInPreviousYear
            ? DateTime(now.year, 7, 31)
            : DateTime(now.year + 1, 7, 31);
        return (beginDate: _isoDate(begin), endDate: _isoDate(end));
      case TeacherAttendanceRange.month:
        final begin = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1, 0);
        return (beginDate: _isoDate(begin), endDate: _isoDate(end));
    }
  }
}

class TeacherAttendanceSummary {
  const TeacherAttendanceSummary({
    this.signedCourseCount = 0,
    this.bigClassSignCount = 0,
    this.smallClassCompleteCount = 0,
    this.lateCount = 0,
    this.absentCount = 0,
  });

  final int signedCourseCount;
  final int bigClassSignCount;
  final int smallClassCompleteCount;
  final int lateCount;
  final int absentCount;

  factory TeacherAttendanceSummary.fromJson(dynamic raw) {
    final map = _unwrapMap(raw);
    if (map == null) return const TeacherAttendanceSummary();
    return TeacherAttendanceSummary(
      signedCourseCount: _pickInt(map, [
        'signedCourseCount',
        'courseSignCount',
        'signCourseCount',
        'courseCount',
        'totalCount',
      ]),
      bigClassSignCount: _pickInt(map, [
        'bigClassSignCount',
        'classSignCount',
        'bigCourseSignCount',
        'oneClickSignCount',
      ]),
      smallClassCompleteCount: _pickInt(map, [
        'smallClassCompleteCount',
        'smallCourseCompleteCount',
        'smallClassSignCount',
        'smallCourseSignCount',
      ]),
      lateCount: _pickInt(map, [
        'lateCount',
        'studentLateCount',
        'lateStudentCount',
      ]),
      absentCount: _pickInt(map, [
        'absentCount',
        'studentAbsentCount',
        'absenceCount',
      ]),
    );
  }
}

class TeacherSignHistoryItem {
  const TeacherSignHistoryItem({
    required this.courseId,
    required this.date,
    required this.time,
    required this.courseName,
    required this.courseType,
    required this.lineNum,
    required this.teacherName,
    required this.classroom,
    required this.shouldCount,
    required this.presentCount,
    required this.method,
  });

  final String courseId;
  final String date;
  final String time;
  final String courseName;
  final int courseType;
  final int lineNum;
  final String teacherName;
  final String classroom;
  final int shouldCount;
  final int presentCount;
  final String method;

  factory TeacherSignHistoryItem.fromJson(Map<String, dynamic> json) {
    final flat = _flattenHistoryMap(json);
    final type = _pickInt(flat, ['type', 'courseType', 'classType']);
    return TeacherSignHistoryItem(
      courseId: pickFirstSnowflakeId(flat, ['courseId', 'id']) ?? '',
      date: _pickString(flat, ['date', 'courseDate', 'signDate', 'createTime']),
      time: _clock(
        _pickString(flat, [
          'signInTime',
          'teacherSignInTime',
          'timeBegin',
          'beginTime',
          'createTime',
        ]),
      ),
      courseName: _pickString(flat, [
        'courseName',
        'subjectName',
        'name',
        'title',
      ], fallback: '未命名课程'),
      courseType: type,
      lineNum: _pickInt(flat, ['lineNum', 'periodIndex', 'sectionNum']),
      teacherName: _pickString(flat, [
        'teacherName',
        'teacherRealname',
        'realname',
      ], fallback: '任课老师'),
      classroom: _pickString(flat, [
        'classroomName',
        'roomName',
        'classroom',
        'address',
      ], fallback: '--'),
      shouldCount: _pickInt(flat, [
        'shouldCount',
        'studentShouldCount',
        'studentCount',
        'expectedCount',
      ]),
      presentCount: _pickInt(flat, [
        'presentCount',
        'studentPresentCount',
        'signedCount',
        'actualCount',
      ]),
      method: _pickString(flat, [
        'method',
        'signMethod',
        'signTypeName',
      ], fallback: type == 0 ? '教师一键签到' : '教师上下课签'),
    );
  }
}

class TeacherClassSignDetail {
  const TeacherClassSignDetail({
    required this.courseId,
    required this.courseSignStatus,
    required this.shouldCount,
    required this.presentCount,
    required this.students,
  });

  final String courseId;
  final int courseSignStatus;
  final int shouldCount;
  final int presentCount;
  final List<CourseSignStudent> students;

  factory TeacherClassSignDetail.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return TeacherClassSignDetail(
      courseId: pickFirstSnowflakeId(map, ['courseId', 'id']) ?? '',
      courseSignStatus: _pickInt(map, ['courseSignStatus', 'signStatus']),
      shouldCount: _pickInt(map, ['shouldCount', 'studentCount']),
      presentCount: _pickInt(map, ['presentCount', 'signedCount']),
      students: parseCourseSignStudentList(
        map['studentList'] ?? map['students'] ?? map['list'],
      ),
    );
  }
}

List<TeacherSignHistoryItem> parseTeacherSignHistoryList(dynamic raw) {
  final rows = _unwrapList(raw);
  return rows
      .map((item) => TeacherSignHistoryItem.fromJson(item))
      .toList(growable: false);
}

Map<String, dynamic> _flattenHistoryMap(Map<String, dynamic> source) {
  final result = Map<String, dynamic>.from(source);
  void merge(dynamic raw, Map<String, String> aliases) {
    final nested = _asMap(raw);
    if (nested == null) return;
    for (final entry in nested.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
      final alias = aliases[entry.key];
      if (alias != null) result.putIfAbsent(alias, () => entry.value);
    }
  }

  merge(source['course'], const {
    'id': 'courseId',
    'date': 'courseDate',
    'type': 'courseType',
    'lineNum': 'lineNum',
    'timeBegin': 'timeBegin',
    'timeEnd': 'timeEnd',
  });
  merge(source['subject'], const {'name': 'subjectName'});
  merge(source['teacher'], const {'realname': 'teacherRealname'});
  merge(source['classroom'], const {'name': 'classroomName'});
  return result;
}

Map<String, dynamic>? _unwrapMap(dynamic raw) {
  final map = _asMap(raw);
  if (map == null) return null;
  for (final key in ['data', 'result', 'record']) {
    final nested = _asMap(map[key]);
    if (nested != null) return nested;
  }
  return map;
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  if (raw is List) {
    return raw.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }
  final map = _asMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final value = map[key];
    if (value is List) {
      return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
    }
    final nested = _asMap(value);
    if (nested != null) {
      final list = _unwrapList(nested);
      if (list.isNotEmpty) return list;
    }
  }
  return const [];
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = int.tryParse(map[key]?.toString() ?? '');
    if (value != null) return value;
  }
  return 0;
}

String _pickString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String _clock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

String _isoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

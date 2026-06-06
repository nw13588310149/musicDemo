/// 签课管理 API 数据模型与 JSON 解析（管理员端）。
///
/// 考勤状态与后端一致：`0` 出勤 / `1` 缺勤 / `2` 迟到 / `3` 请假。
library;

/// 后端 `status` 字段：0-出勤 1-缺勤 2-迟到 3-请假；null 表示尚未签到。
enum CourseSignStatus {
  present(0, '出勤'),
  absent(1, '缺勤'),
  late(2, '迟到'),
  leave(3, '请假');

  const CourseSignStatus(this.code, this.label);

  final int code;
  final String label;

  /// 弹窗内可选项（仅 0–3）。
  static const List<CourseSignStatus> selectable = [
    present,
    absent,
    late,
    leave,
  ];

  static CourseSignStatus? fromApi(dynamic raw) {
    if (raw == null) return null;
    final code = int.tryParse(raw.toString());
    if (code == null) return null;
    for (final s in selectable) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// 班级筛选项（`classList` / 签课查询共用）。
class CourseSignClassOption {
  const CourseSignClassOption({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;

  /// 0=大班 1=小班
  final int type;

  factory CourseSignClassOption.fromJson(Map<String, dynamic> json) {
    final id = _pickString(json, ['id', 'classId', 'cId'], '');
    final name = _pickString(json, [
      'name',
      'className',
      'class',
      'fullName',
    ], '未命名班级');
    final typeRaw = json['type'];
    final type = int.tryParse(typeRaw?.toString() ?? '') ?? 0;
    return CourseSignClassOption(id: id, name: name, type: type);
  }
}

/// `courseSignSum0` / `courseSignSum1` 统计卡片数据（字段名做多 key 兜底）。
class CourseSignStats {
  const CourseSignStats({
    this.courseCount = 0,
    this.signedCourseCount = 0,
    this.studentSignedCount = 0,
    this.studentShouldCount = 0,
    this.pendingMakeupCount = 0,
    this.inProgressCount = 0,
    this.pendingAdminCount = 0,
    this.completedCount = 0,
  });

  final int courseCount;
  final int signedCourseCount;
  final int studentSignedCount;
  final int studentShouldCount;
  final int pendingMakeupCount;
  final int inProgressCount;
  final int pendingAdminCount;
  final int completedCount;

  factory CourseSignStats.fromJson(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return const CourseSignStats();
    int pick(List<String> keys) {
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = int.tryParse(map[k]?.toString() ?? '');
        if (v != null) return v;
      }
      return 0;
    }

    return CourseSignStats(
      courseCount: pick([
        'courseCount',
        'courseNum',
        'totalCourseCount',
        'totalCount',
        'bigCourseCount',
        'smallCourseCount',
      ]),
      signedCourseCount: pick([
        'signedCourseCount',
        'completeCourseCount',
        'signedCount',
        'finishCount',
      ]),
      studentSignedCount: pick([
        'studentSignCount',
        'signedStudentCount',
        'signCount',
        'studentSignedCount',
      ]),
      studentShouldCount: pick([
        'studentShouldSignCount',
        'shouldSignCount',
        'studentCount',
        'shouldCount',
      ]),
      pendingMakeupCount: pick([
        'makeupPendingCount',
        'pendingMakeupCount',
        'makeupCount',
        'applyCount',
      ]),
      inProgressCount: pick([
        'inProgressCount',
        'doingCount',
        'progressCount',
      ]),
      pendingAdminCount: pick([
        'pendingAdminCount',
        'waitAdminCount',
        'adminConfirmCount',
      ]),
      completedCount: pick([
        'completedCount',
        'finishCount',
        'doneCount',
      ]),
    );
  }
}

class CourseSignStudent {
  CourseSignStudent({
    required this.studentId,
    required this.name,
    required this.studentNo,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.evaluationRating,
    this.evaluationMastery,
    this.evaluationNote,
  });

  final String studentId;
  final String name;
  final String studentNo;
  CourseSignStatus? status;
  String? checkInTime;
  String? checkOutTime;
  double? evaluationRating;
  String? evaluationMastery;
  String? evaluationNote;

  factory CourseSignStudent.fromJson(Map<String, dynamic> json) {
    final studentId = _pickString(json, [
      'studentId',
      'stuId',
      'userId',
      'id',
    ], '');
    final name = _pickString(json, [
      'realname',
      'realName',
      'nickname',
      'name',
      'stuName',
      'studentName',
    ], '未命名');
    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'stuNo',
      'studentIdNo',
    ], '--');
    final ratingRaw = json['score'] ?? json['rating'] ?? json['star'];
    final rating = ratingRaw == null
        ? null
        : double.tryParse(ratingRaw.toString());
    return CourseSignStudent(
      studentId: studentId,
      name: name,
      studentNo: studentNo,
      status: CourseSignStatus.fromApi(
        json['status'] ?? json['signStatus'] ?? json['attendanceStatus'],
      ),
      checkInTime: _pickStringNullable(json, [
        'checkInTime',
        'signInTime',
        'beginSignTime',
        'classBeginTime',
      ]),
      checkOutTime: _pickStringNullable(json, [
        'checkOutTime',
        'signOutTime',
        'endSignTime',
        'classEndTime',
      ]),
      evaluationRating: rating,
      evaluationMastery: _pickStringNullable(json, [
        'mastery',
        'masterLevel',
        'level',
      ]),
      evaluationNote: _pickStringNullable(json, [
        'evaluation',
        'evaluate',
        'comment',
        'remark',
        'note',
      ]),
    );
  }
}

/// 单节课程签到（大课 / 小课列表项）。
class CourseSignSession {
  CourseSignSession({
    required this.courseId,
    required this.courseName,
    required this.timeRange,
    required this.classroom,
    required this.students,
    this.teacherName = '',
    this.teacherCheckInTime,
    this.teacherCheckOutTime,
    this.adminConfirmed = false,
    this.signStep,
    this.courseType = 0,
  });

  final String courseId;
  final String courseName;
  final String timeRange;
  final String classroom;
  final List<CourseSignStudent> students;
  final String teacherName;
  final String? teacherCheckInTime;
  final String? teacherCheckOutTime;
  final bool adminConfirmed;

  /// 小课流程步骤（0–5），后端若下发 `signStep` / `step` 则直接使用。
  final int? signStep;
  final int courseType;

  factory CourseSignSession.fromJson(Map<String, dynamic> json) {
    final courseId = _pickString(json, ['courseId', 'id', 'cId'], '');
    final courseName = _pickString(json, [
      'courseName',
      'subjectName',
      'name',
      'title',
    ], '未命名课程');
    final begin = _pickString(json, ['beginTime', 'startTime', 'classBeginTime'], '');
    final end = _pickString(json, ['endTime', 'finishTime', 'classEndTime'], '');
    final date = _pickString(json, ['date', 'courseDate'], '');
    var timeRange = _pickString(json, ['timeRange', 'time', 'period'], '');
    if (timeRange.isEmpty && begin.isNotEmpty) {
      timeRange = end.isNotEmpty ? '$begin - $end' : begin;
    }
    if (timeRange.isEmpty && date.isNotEmpty) {
      timeRange = date;
    }
    final classroom = _pickString(json, [
      'classroomName',
      'classroom',
      'roomName',
      'address',
    ], '--');
    final teacherMap = _asMap(json['teacher'] ?? json['headTeacher']);
    final teacherName = teacherMap != null
        ? _pickString(teacherMap, ['realname', 'realName', 'name'], '')
        : _pickString(json, ['teacherName', 'teacherRealname'], '');

    final studentsRaw = json['studentList'] ??
        json['students'] ??
        json['signStudentList'] ??
        json['studentSignList'] ??
        json['list'];
    final students = _parseStudentList(studentsRaw);

    final stepRaw = json['signStep'] ?? json['step'] ?? json['flowStep'];
    final step = int.tryParse(stepRaw?.toString() ?? '');

    final adminConfirmedRaw =
        json['adminConfirm'] ?? json['adminConfirmed'] ?? json['confirmStatus'];
    final adminConfirmed = adminConfirmedRaw == true ||
        adminConfirmedRaw == 1 ||
        adminConfirmedRaw?.toString() == '1';

    return CourseSignSession(
      courseId: courseId,
      courseName: courseName,
      timeRange: timeRange,
      classroom: classroom,
      students: students,
      teacherName: teacherName,
      teacherCheckInTime: _pickStringNullable(json, [
        'teacherCheckInTime',
        'teacherSignInTime',
      ]),
      teacherCheckOutTime: _pickStringNullable(json, [
        'teacherCheckOutTime',
        'teacherSignOutTime',
      ]),
      adminConfirmed: adminConfirmed,
      signStep: step,
      courseType:
          int.tryParse((json['type'] ?? json['classType'] ?? 0).toString()) ??
          0,
    );
  }
}

List<CourseSignSession> parseCourseSignSessionList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => CourseSignSession.fromJson(_asMap(e) ?? {}))
        .where((s) => s.courseId.isNotEmpty || s.courseName.isNotEmpty)
        .toList(growable: false);
  }
  final map = _asMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final inner = map[key];
    if (inner is List) return parseCourseSignSessionList(inner);
  }
  return const [];
}

List<CourseSignStudent> _parseStudentList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => CourseSignStudent.fromJson(_asMap(e) ?? {}))
      .toList(growable: false);
}

List<CourseSignClassOption> parseCourseSignClassList(dynamic raw) {
  if (raw == null) return const [];
  List<dynamic> rows;
  if (raw is List) {
    rows = raw;
  } else {
    final map = _asMap(raw);
    if (map == null) return const [];
    final inner = map['records'] ?? map['list'] ?? map['rows'] ?? map['data'];
    if (inner is! List) return const [];
    rows = inner;
  }
  return rows
      .map((e) => CourseSignClassOption.fromJson(_asMap(e) ?? {}))
      .where((c) => c.id.isNotEmpty)
      .toList(growable: false);
}

String todayIsoDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

String? _pickStringNullable(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}

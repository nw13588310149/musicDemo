/// 任课老师「考评管理」API 数据解析。
library;

import '../../../core/network/snowflake_id.dart';

enum TeacherExamCornerKind { unpublished, published }

enum TeacherExamSubmissionState { pending, reviewed, missing, passed }

class TeacherExamSubmission {
  const TeacherExamSubmission({
    required this.studentId,
    required this.studentName,
    required this.state,
    required this.subject,
    required this.medium,
    required this.uploadAt,
    required this.action,
    this.score,
    this.comment = '',
    this.path = '',
  });

  final String studentId;
  final String studentName;
  final TeacherExamSubmissionState state;
  final String subject;
  final String medium;
  final String uploadAt;
  final String action;
  final num? score;
  final String comment;
  final String path;

  bool get canRemind =>
      state == TeacherExamSubmissionState.missing ||
      (state == TeacherExamSubmissionState.pending && path.isEmpty);
  bool get canScore =>
      state == TeacherExamSubmissionState.pending && path.isNotEmpty;
  bool get canView =>
      state == TeacherExamSubmissionState.reviewed ||
      (state == TeacherExamSubmissionState.pending && path.isNotEmpty);
}

class TeacherExamOverviewStats {
  const TeacherExamOverviewStats({
    this.pending = 0,
    this.subjects = 0,
    this.reviewed = 0,
    this.average,
    this.max,
    this.min,
  });

  final int pending;
  final int subjects;
  final int reviewed;
  final double? average;
  final double? max;
  final double? min;

  String get averageLabel => average?.toStringAsFixed(1) ?? '—';
  String get maxLabel => max?.toStringAsFixed(1) ?? '—';
  String get minLabel => min?.toStringAsFixed(1) ?? '—';

  factory TeacherExamOverviewStats.fromApi(dynamic raw) {
    final map = _unwrapApiMap(raw);
    return TeacherExamOverviewStats(
      pending: _pickInt(map, [
        'unscoredCount',
        'unScoreCount',
        'pendingCount',
        'notScoreCount',
        'waitScoreCount',
      ]),
      subjects: 1,
      reviewed: _pickInt(map, [
        'scoreCount',
        'reviewedCount',
        'scoredCount',
      ]),
      average: _pickDouble(map, ['avgScore', 'averageScore', 'scoreAvg']),
      max: _pickDouble(map, ['maxScore', 'highestScore']),
      min: _pickDouble(map, ['minScore', 'lowestScore']),
    );
  }

  static TeacherExamOverviewStats merge(List<TeacherExamOverviewStats> rows) {
    if (rows.isEmpty) return const TeacherExamOverviewStats();
    final reviewed = rows.fold<int>(0, (sum, item) => sum + item.reviewed);
    final averages = rows.where((item) => item.average != null).toList();
    return TeacherExamOverviewStats(
      pending: rows.fold<int>(0, (sum, item) => sum + item.pending),
      subjects: rows.length,
      reviewed: reviewed,
      average: averages.isEmpty
          ? null
          : reviewed == 0
          ? averages.fold<double>(0, (sum, item) => sum + item.average!) /
                averages.length
          : averages.fold<double>(
                  0,
                  (sum, item) => sum + item.average! * item.reviewed,
                ) /
                reviewed,
      max: _extreme(rows.map((item) => item.max), true),
      min: _extreme(rows.map((item) => item.min), false),
    );
  }

  static double? _extreme(Iterable<double?> values, bool highest) {
    final numbers = values.whereType<double>().toList();
    if (numbers.isEmpty) return null;
    return numbers.reduce(
      highest ? (a, b) => a > b ? a : b : (a, b) => a < b ? a : b,
    );
  }
}

class TeacherExamDetailMetrics {
  const TeacherExamDetailMetrics({
    this.attended = 0,
    this.unsubmitted = 0,
    this.pendingReview = 0,
    this.reviewed = 0,
    this.total = 0,
    this.submitted = 0,
  });

  final int attended;
  final int unsubmitted;
  final int pendingReview;
  final int reviewed;
  final int total;
  final int submitted;

  factory TeacherExamDetailMetrics.fromApi(
    dynamic raw, {
    required List<TeacherExamSubmission> submissions,
  }) {
    final map = _unwrapApiMap(raw);
    final total = _pickInt(map, [
      'totalCount',
      'studentCount',
      'shouldCount',
      'joinCount',
    ], fallback: submissions.length);
    final submitted = _pickInt(map, [
      'submitCount',
      'submittedCount',
      'joinCount',
    ], fallback: submissions.where((s) => s.path.isNotEmpty).length);
    final unsubmitted = _pickInt(map, [
      'unSubmitCount',
      'unsubmittedCount',
      'absentCount',
      'missingCount',
    ], fallback: total - submitted);
    final pending = _pickInt(map, [
      'unscoredCount',
      'unScoreCount',
      'pendingCount',
      'notScoreCount',
      'waitScoreCount',
    ], fallback: submissions
        .where((s) => s.state == TeacherExamSubmissionState.pending)
        .length);
    final reviewed = _pickInt(map, [
      'scoreCount',
      'reviewedCount',
      'scoredCount',
    ], fallback: submissions
        .where((s) => s.state == TeacherExamSubmissionState.reviewed)
        .length);
    return TeacherExamDetailMetrics(
      attended: _pickInt(map, ['attendCount', 'joinCount'], fallback: total),
      unsubmitted: unsubmitted < 0 ? 0 : unsubmitted,
      pendingReview: pending,
      reviewed: reviewed,
      total: total,
      submitted: submitted,
    );
  }
}

class TeacherExamItem {
  const TeacherExamItem({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.subject,
    required this.examLabel,
    required this.classLabel,
    required this.deadline,
    required this.syncNote,
    required this.officialDesc,
    required this.cornerLabel,
    required this.cornerKind,
    required this.attended,
    required this.unsubmitted,
    required this.pendingReview,
    required this.reviewed,
    required this.submissions,
    required this.publishedRatio,
    this.detailLoaded = false,
  });

  final String id;
  final int subjectId;
  final String title;
  final String subject;
  final String examLabel;
  final String classLabel;
  final String deadline;
  final String syncNote;
  final String officialDesc;
  final String cornerLabel;
  final TeacherExamCornerKind cornerKind;
  final int attended;
  final int unsubmitted;
  final int pendingReview;
  final int reviewed;
  final List<TeacherExamSubmission> submissions;
  final ({int submitted, int total}) publishedRatio;
  final bool detailLoaded;

  TeacherExamItem copyWith({
    int? attended,
    int? unsubmitted,
    int? pendingReview,
    int? reviewed,
    List<TeacherExamSubmission>? submissions,
    ({int submitted, int total})? publishedRatio,
    bool? detailLoaded,
  }) {
    return TeacherExamItem(
      id: id,
      subjectId: subjectId,
      title: title,
      subject: subject,
      examLabel: examLabel,
      classLabel: classLabel,
      deadline: deadline,
      syncNote: syncNote,
      officialDesc: officialDesc,
      cornerLabel: cornerLabel,
      cornerKind: cornerKind,
      attended: attended ?? this.attended,
      unsubmitted: unsubmitted ?? this.unsubmitted,
      pendingReview: pendingReview ?? this.pendingReview,
      reviewed: reviewed ?? this.reviewed,
      submissions: submissions ?? this.submissions,
      publishedRatio: publishedRatio ?? this.publishedRatio,
      detailLoaded: detailLoaded ?? this.detailLoaded,
    );
  }
}

List<Map<String, dynamic>> parseTeacherExamListRows(dynamic raw) {
  dynamic value = raw;
  if (value is Map) {
    value = value['records'] ?? value['list'] ?? value['rows'] ?? value['data'];
  }
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

List<TeacherExamItem> buildTeacherExamItemsFromListRow(
  Map<String, dynamic> row,
) {
  return [buildTeacherExamItemFromListRow(row)];
}

/// `examList` 一条记录对应左侧一张考试卡，不再按 `subjectIds` 展开。
TeacherExamItem buildTeacherExamItemFromListRow(Map<String, dynamic> row) {
  final subjectId = _resolveTeacherExamSubjectId(row);
  final subjectName = _resolveTeacherExamSubjectLabel(row, subjectId);
  return teacherExamItemSkeleton(
    row: row,
    subjectId: subjectId,
    subjectName: subjectName,
  );
}

int _resolveTeacherExamSubjectId(Map<String, dynamic> row) {
  final direct = _pickInt(row, ['subjectId']);
  if (direct > 0) return direct;
  final ids = _readIntList(row['subjectIds']);
  if (ids.isNotEmpty) return ids.first;
  return 0;
}

String _resolveTeacherExamSubjectLabel(Map<String, dynamic> row, int subjectId) {
  final direct = _pickString(row, ['subjectName']);
  if (direct.isNotEmpty) return direct;

  final ids = _readIntList(row['subjectIds']);
  final names = _readStringList(row['subjectNames']);
  if (subjectId > 0 && ids.isNotEmpty) {
    final idx = ids.indexOf(subjectId);
    if (idx >= 0 && idx < names.length) return names[idx];
  }
  if (names.length == 1) return names.first;
  if (names.isNotEmpty) return names.join('、');
  if (subjectId > 0) return '科目$subjectId';
  return '未设置科目';
}

TeacherExamItem teacherExamItemSkeleton({
  required Map<String, dynamic> row,
  required int subjectId,
  required String subjectName,
}) {
  final classes = row['classList'] is List
      ? (row['classList'] as List)
            .whereType<Map>()
            .map((e) => _stringValue(e['name']))
            .where((e) => e.isNotEmpty)
            .join('、')
      : '';
  final status = int.tryParse(_stringValue(row['status'])) ?? 0;
  final examDate = _stringValue(row['examDate'], fallback: '--');
  final examName = _stringValue(row['name'], fallback: '未命名考试');
  return TeacherExamItem(
    id: readSnowflakeId(row['id']) ?? _stringValue(row['id']),
    subjectId: subjectId,
    title: examName,
    subject: subjectName,
    examLabel: examDate.length >= 7 ? examDate.substring(0, 7) : '考试',
    classLabel: classes.isEmpty ? '全部关联班级' : classes,
    deadline: examDate,
    syncNote: '数据来自教务考试安排',
    officialDesc: _stringValue(row['remark'], fallback: '暂无考试说明'),
    cornerLabel: status == 0 ? '成绩未发布' : '成绩已发布',
    cornerKind: status == 0
        ? TeacherExamCornerKind.unpublished
        : TeacherExamCornerKind.published,
    attended: 0,
    unsubmitted: 0,
    pendingReview: 0,
    reviewed: 0,
    submissions: const [],
    publishedRatio: (submitted: 0, total: 0),
    detailLoaded: false,
  );
}

TeacherExamItem applyTeacherExamDetail({
  required TeacherExamItem item,
  required List<TeacherExamSubmission> submissions,
  required TeacherExamDetailMetrics metrics,
}) {
  return item.copyWith(
    attended: metrics.attended,
    unsubmitted: metrics.unsubmitted,
    pendingReview: metrics.pendingReview,
    reviewed: metrics.reviewed,
    submissions: submissions,
    publishedRatio: (
      submitted: metrics.submitted,
      total: metrics.total > 0 ? metrics.total : submissions.length,
    ),
    detailLoaded: true,
  );
}

List<TeacherExamSubmission> parseTeacherExamSubmissionList(
  dynamic raw, {
  required String subjectName,
}) {
  return parseTeacherExamListRows(raw)
      .map((row) => _submissionFromRow(row, subjectName: subjectName))
      .toList(growable: false);
}

TeacherExamSubmission _submissionFromRow(
  Map<String, dynamic> row, {
  required String subjectName,
}) {
  final path = _stringValue(row['path']);
  final scoreRaw = row['score'];
  final score = scoreRaw == null ? null : num.tryParse(scoreRaw.toString());
  final scoreStatus = _pickInt(row, ['scoreStatus', 'status']);
  final absent =
      row['absent'] == true ||
      row['isAbsent'] == true ||
      scoreStatus == 2 ||
      _pickInt(row, ['submitStatus']) == 0 && path.isEmpty;
  final scored =
      row['scored'] == true ||
      scoreStatus == 1 ||
      score != null;
  final missing = absent || (path.isEmpty && !scored);
  final state = missing
      ? TeacherExamSubmissionState.missing
      : scored
      ? TeacherExamSubmissionState.reviewed
      : TeacherExamSubmissionState.pending;
  final uploadAt = _formatUploadAt(_pickString(row, [
    'submitTime',
    'uploadTime',
    'createTime',
    'updateTime',
  ]));
  final action = switch (state) {
    TeacherExamSubmissionState.missing => '催交/详情',
    TeacherExamSubmissionState.reviewed => '查看',
    TeacherExamSubmissionState.pending =>
      path.isEmpty ? '催交/详情' : '试听/评分',
    TeacherExamSubmissionState.passed => '查看',
  };
  return TeacherExamSubmission(
    studentId: readSnowflakeId(row['studentId']) ?? _stringValue(row['studentId']),
    studentName: _pickString(row, ['realname', 'realName', 'studentName'], '未命名学生'),
    state: state,
    subject: subjectName,
    medium: _mediumFromPath(path),
    uploadAt: uploadAt,
    action: action,
    score: score,
    comment: _pickString(row, ['comment', 'remark']),
    path: path,
  );
}

Map<String, dynamic> _unwrapApiMap(dynamic raw) {
  dynamic value = raw;
  while (value is Map && value['data'] is Map) {
    value = value['data'];
  }
  return value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : const {};
}

int _pickInt(
  Map<String, dynamic> map,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return parsed;
  }
  return fallback;
}

double? _pickDouble(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    final parsed = double.tryParse(raw.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

String _pickString(
  Map<String, dynamic> map,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

List<String> _csvStrings(dynamic raw) => _stringValue(raw)
    .split(',')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList(growable: false);

List<int> _csvInts(dynamic raw) =>
    _csvStrings(raw).map(int.tryParse).whereType<int>().toList(growable: false);

List<String> _readStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty && e != 'null')
        .toList(growable: false);
  }
  return _csvStrings(raw);
}

List<int> _readIntList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => int.tryParse(e.toString())).whereType<int>().toList(
      growable: false,
    );
  }
  return _csvInts(raw);
}

String _stringValue(dynamic raw, {String fallback = ''}) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty || value == 'null' ? fallback : value;
}

String _formatUploadAt(String raw) {
  if (raw.isEmpty) return '—';
  final match = RegExp(r'(\d{2}-\d{2}\s+\d{2}:\d{2})').firstMatch(raw);
  if (match != null) return match.group(1)!;
  if (raw.length >= 16) return raw.substring(5, 16);
  return raw;
}

String _mediumFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.m4a')) {
    return '音频';
  }
  if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return '视频';
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png')) {
    return '图片';
  }
  return path.isEmpty ? '—' : '文件';
}

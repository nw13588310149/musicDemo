import '../../../core/network/snowflake_id.dart';

double _doubleOf(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('$value'.replaceAll('%', '').trim()) ?? 0;

int _intOf(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _stringOf(dynamic value) => value?.toString().trim() ?? '';

List<Map<dynamic, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<dynamic, dynamic>>().toList();
}

class StudentExamOverview {
  const StudentExamOverview({
    required this.avgScore,
    required this.bestExamName,
    required this.bestExamScore,
    required this.latestClassRank,
    required this.latestClassTotal,
    required this.latestSchoolRank,
    required this.latestSchoolTotal,
    required this.distribution,
    required this.trends,
  });

  factory StudentExamOverview.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    final best = map['bestExam'] is Map
        ? map['bestExam'] as Map
        : const <dynamic, dynamic>{};
    final classRank = map['latestClassRank'] is Map
        ? map['latestClassRank'] as Map
        : const <dynamic, dynamic>{};
    final schoolRank = map['latestSchoolRank'] is Map
        ? map['latestSchoolRank'] as Map
        : const <dynamic, dynamic>{};
    return StudentExamOverview(
      avgScore: _doubleOf(map['avgScore']),
      bestExamName: _stringOf(best['examName']),
      bestExamScore: _doubleOf(best['score']),
      latestClassRank: _intOf(classRank['rank']),
      latestClassTotal: _intOf(classRank['total']),
      latestSchoolRank: _intOf(schoolRank['rank']),
      latestSchoolTotal: _intOf(schoolRank['total']),
      distribution: _mapList(
        map['distribution'],
      ).map(StudentScoreDistribution.fromMap).toList(),
      trends: _mapList(map['trendList']).map(StudentExamTrend.fromMap).toList(),
    );
  }

  final double avgScore;
  final String bestExamName;
  final double bestExamScore;
  final int latestClassRank;
  final int latestClassTotal;
  final int latestSchoolRank;
  final int latestSchoolTotal;
  final List<StudentScoreDistribution> distribution;
  final List<StudentExamTrend> trends;
}

class StudentScoreDistribution {
  const StudentScoreDistribution({
    required this.range,
    required this.percent,
    required this.count,
  });

  factory StudentScoreDistribution.fromMap(Map<dynamic, dynamic> map) =>
      StudentScoreDistribution(
        range: _stringOf(map['range']),
        percent: _doubleOf(map['percent'] ?? map['percentage']),
        count: _intOf(map['count']),
      );

  final String range;
  final double percent;
  final int count;
}

class StudentExamTrend {
  const StudentExamTrend({
    required this.examName,
    required this.examDate,
    required this.totalScore,
    required this.classRank,
    required this.schoolRank,
  });

  factory StudentExamTrend.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamTrend(
        examName: _stringOf(map['examName']),
        examDate: _stringOf(map['examDate']),
        totalScore: _doubleOf(
          map['totalScore'] ?? map['avgScore'] ?? map['score'],
        ),
        classRank: _intOf(map['classRank'] ?? map['classSort']),
        schoolRank: _intOf(map['schoolRank'] ?? map['schoolSort']),
      );

  final String examName;
  final String examDate;
  final double totalScore;
  final int classRank;
  final int schoolRank;
}

class StudentExamRecord {
  const StudentExamRecord({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.totalScore,
    required this.passSubjectCount,
    required this.excellentSubjectCount,
    required this.classRank,
    required this.schoolRank,
    required this.subjectScores,
  });

  factory StudentExamRecord.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamRecord(
        examId: readSnowflakeId(map['examId']) ?? _stringOf(map['examId']),
        examName: _stringOf(map['examName']),
        examDate: _stringOf(map['examDate']),
        totalScore: _doubleOf(map['totalScore']),
        passSubjectCount: _intOf(map['passSubjectCount']),
        excellentSubjectCount: _intOf(map['excellentSubjectCount']),
        classRank: _intOf(map['classRank']),
        schoolRank: _intOf(map['schoolRank']),
        subjectScores: _mapList(
          map['subjectScores'],
        ).map(StudentExamSubjectScore.fromMap).toList(),
      );

  /// 考试 id（雪花 long，String 形式避免 Web 精度丢失），用于查询考场座位。
  final String examId;
  final String examName;
  final String examDate;
  final double totalScore;
  final int passSubjectCount;
  final int excellentSubjectCount;
  final int classRank;
  final int schoolRank;
  final List<StudentExamSubjectScore> subjectScores;
}

class StudentExamSubjectScore {
  const StudentExamSubjectScore({
    required this.subjectName,
    required this.score,
    required this.classRank,
    required this.schoolRank,
    required this.comment,
    required this.path,
  });

  factory StudentExamSubjectScore.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamSubjectScore(
        subjectName: _stringOf(map['subjectName']),
        score: _doubleOf(map['score']),
        classRank: _intOf(map['classSort']),
        schoolRank: _intOf(map['schoolSort']),
        comment: _stringOf(map['comment']),
        path: _stringOf(map['path']),
      );

  final String subjectName;
  final double score;
  final int classRank;
  final int schoolRank;
  final String comment;
  final String path;
}

class StudentHomeworkSummary {
  const StudentHomeworkSummary({
    required this.subjectAvgScores,
    required this.scoreRanges,
  });

  factory StudentHomeworkSummary.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    return StudentHomeworkSummary(
      subjectAvgScores: _mapList(
        map['subjectAvgScores'],
      ).map(StudentSubjectAverage.fromMap).toList(),
      scoreRanges: _mapList(
        map['scoreRanges'],
      ).map(StudentScoreDistribution.fromMap).toList(),
    );
  }

  final List<StudentSubjectAverage> subjectAvgScores;
  final List<StudentScoreDistribution> scoreRanges;
}

class StudentSubjectAverage {
  const StudentSubjectAverage({required this.subjectName, required this.score});

  factory StudentSubjectAverage.fromMap(Map<dynamic, dynamic> map) =>
      StudentSubjectAverage(
        subjectName: _stringOf(map['subjectName']),
        score: _doubleOf(map['avgScore']),
      );

  final String subjectName;
  final double score;
}

/// 学生「我的考场座位」（`student/examSeat` → `StudentExamSeatRes`）。
class StudentExamSeat {
  const StudentExamSeat({
    required this.examName,
    required this.examDate,
    required this.remark,
    required this.seats,
  });

  factory StudentExamSeat.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    return StudentExamSeat(
      examName: _stringOf(map['examName']),
      examDate: _stringOf(map['examDate']),
      remark: _stringOf(map['remark']),
      seats: _mapList(map['seats']).map(StudentExamSeatItem.fromMap).toList(),
    );
  }

  final String examName;
  final String examDate;
  final String remark;
  final List<StudentExamSeatItem> seats;
}

/// 单科目的考场座位（`SubjectSeat`）。未安排时 [classroomName] 为空、[seatNo] 为 null。
class StudentExamSeatItem {
  const StudentExamSeatItem({
    required this.subjectName,
    required this.classroomName,
    required this.seatNo,
  });

  factory StudentExamSeatItem.fromMap(Map<dynamic, dynamic> map) {
    final rawSeat = map['seatNo'];
    return StudentExamSeatItem(
      subjectName: _stringOf(map['subjectName']),
      classroomName: _stringOf(map['classroomName']),
      seatNo: rawSeat == null ? null : int.tryParse('$rawSeat'),
    );
  }

  final String subjectName;
  final String classroomName;
  final int? seatNo;

  /// 是否已编排考场（教室与座位号齐全）。
  bool get arranged => classroomName.isNotEmpty && seatNo != null;
}

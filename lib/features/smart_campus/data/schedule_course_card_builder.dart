import 'package:flutter/material.dart';

import 'schedule_color_palette.dart';

/// 课表网格内课程卡片的四种视觉主题（与管理员排课页一致）。
enum ScheduleCourseCardKind {
  smallOrange,
  smallBlue,
  bigStandard,
  bigExtended,
}

/// 课表课程卡展示数据（管理员 / 教师 / 学生共用）。
class ScheduleCourseCardData {
  const ScheduleCourseCardData({
    required this.kind,
    required this.location,
    required this.name,
    required this.subline,
    this.capacity,
    this.bgColor,
  });

  final ScheduleCourseCardKind kind;
  final String location;
  final String name;
  final String subline;
  final String? capacity;
  final Color? bgColor;
}

ScheduleCardThemeKind scheduleCourseCardThemeKind(ScheduleCourseCardKind kind) {
  return switch (kind) {
    ScheduleCourseCardKind.smallOrange => ScheduleCardThemeKind.smallOrange,
    ScheduleCourseCardKind.smallBlue => ScheduleCardThemeKind.smallBlue,
    ScheduleCourseCardKind.bigStandard => ScheduleCardThemeKind.bigStandard,
    ScheduleCourseCardKind.bigExtended => ScheduleCardThemeKind.bigExtended,
  };
}

/// 从 API `courseList` 单条记录构建课表课程卡展示数据。
/// 字段映射与管理员排课页 `_parseCourseCard` 保持一致。
ScheduleCourseCardData buildScheduleCourseCard(
  Map<String, dynamic> json,
  int smallIdxInCell,
) {
  final typeRaw = json['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

  final location = pickScheduleString(json, [
    'classroomName',
    'roomName',
    'classroom',
  ]);
  final name = pickScheduleString(json, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ]);
  final teacher = pickScheduleString(json, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ]);
  final className = pickScheduleString(json, ['className', 'class']);
  final colorOverride =
      parseScheduleHexColor(pickScheduleString(json, ['color']));

  if (isSmall) {
    final kind = smallIdxInCell.isEven
        ? ScheduleCourseCardKind.smallOrange
        : ScheduleCourseCardKind.smallBlue;
    return ScheduleCourseCardData(
      kind: kind,
      location: location,
      name: name,
      subline: className.isNotEmpty ? className : teacher,
      capacity: pickScheduleCapacityLabel(json),
      bgColor: colorOverride,
    );
  }
  return ScheduleCourseCardData(
    kind: ScheduleCourseCardKind.bigStandard,
    location: location,
    name: name,
    subline: teacher.isEmpty
        ? className
        : (className.isEmpty ? teacher : '$teacher-$className'),
    bgColor: colorOverride,
  );
}

String pickScheduleString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String? pickScheduleCapacityLabel(Map<String, dynamic> json) {
  final attendCount = json['attendCount'] ?? json['signCount'];
  final totalCount =
      json['totalCount'] ?? json['capacity'] ?? json['classSize'];
  if (attendCount != null && totalCount != null) {
    return '$attendCount/$totalCount人';
  }
  return null;
}

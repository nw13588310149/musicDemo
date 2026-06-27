import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../../core/widgets/course_class_kind_tag.dart';
import '../../../../core/widgets/course_subject_tag.dart';
import '../../../shell/ui/shell_layout.dart';

/// 任课老师首页「今日课表」与签课管理「今日课程」共用的 104 高课程卡。
enum TeacherTodayCourseRunState { ended, inProgress, upcoming }

class TeacherTodayCourseCard extends StatelessWidget {
  const TeacherTodayCourseCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.runState,
    required this.displayName,
    required this.courseName,
    required this.isSmallCourse,
    required this.subtitle,
    required this.avatar,
    this.isActive = false,
    this.onTap,
    this.muted = false,
    this.tagDotColor,
  });

  final String startTime;
  final String endTime;
  final TeacherTodayCourseRunState runState;
  final String displayName;
  final String courseName;
  final bool isSmallCourse;
  final String subtitle;
  final Widget avatar;
  final bool isActive;
  final VoidCallback? onTap;
  final bool muted;
  final Color? tagDotColor;

  static const Color _kInnerGray = Color(0xFFF5F6FA);
  static const Color _kInProgressCardBg = Color(0xFFF4F4FF);
  static const Color _kEndedTagBg = Color(0xFFE6E9F1);
  static const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
  static const Color _kTextDark = Color(0xFF0B081A);
  static const Color _kTextSection = Color(0xFF1A1A1A);
  static const Color _kTextHint = Color(0xFFB6B5BB);

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEnded = runState == TeacherTodayCourseRunState.ended;
    final isInProgress = runState == TeacherTodayCourseRunState.inProgress;
    final cardBg = isEnded
        ? _kInnerGray
        : (isInProgress ? _kInProgressCardBg : _kEndedTagBg);
    // 角标与首页 [DashboardCourseNoticeCard] 一致：非已结束均为淡紫底。
    final statusBg = isEnded ? _kEndedTagBg : _kPurpleSoftBg;
    final statusLabel = isEnded
        ? '已结束'
        : (isInProgress ? '进行中' : '待开始');
    final statusTextColor = isEnded ? _kTextHint : _kTextDark;
    final nameColor = muted ? _kTextHint : _kTextDark;

    final card = Container(
      width: double.infinity,
      height: ui(104),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: ui(6),
                  offset: Offset(0, ui(2)),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(68),
              height: ui(22),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(ui(12)),
                  bottomLeft: Radius.circular(ui(12)),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: ui(12),
                  color: statusTextColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(12),
            child: _CourseTimeLabel(
              startTime: startTime,
              endTime: endTime,
              muted: muted,
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(48),
            child: avatar,
          ),
          Positioned(
            left: ui(62),
            top: ui(50),
            right: ui(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(14),
                          color: nameColor,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w600,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    _CourseTagPair(
                      courseName: courseName,
                      isSmallCourse: isSmallCourse,
                      muted: muted,
                      tagDotColor: tagDotColor,
                    ),
                  ],
                ),
                SizedBox(height: ui(4)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: card,
      ),
    );
  }
}

class _CourseTimeLabel extends StatelessWidget {
  const _CourseTimeLabel({
    required this.startTime,
    required this.endTime,
    this.muted = false,
  });

  final String startTime;
  final String endTime;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasEnd = endTime.isNotEmpty && endTime != '--:--';
    final textColor = muted
        ? TeacherTodayCourseCard._kTextHint
        : TeacherTodayCourseCard._kTextSection;
    final baseStyle = TextStyle(
      fontSize: ui(18),
      fontFamily: 'Barlow',
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: textColor,
    );
    if (!hasEnd) {
      return Text(startTime, style: baseStyle);
    }
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '$startTime '),
          TextSpan(
            text: '- ',
            style: TextStyle(color: TeacherTodayCourseCard._kTextHint),
          ),
          TextSpan(text: endTime),
        ],
      ),
    );
  }
}

class _CourseTagPair extends StatelessWidget {
  const _CourseTagPair({
    required this.courseName,
    required this.isSmallCourse,
    this.muted = false,
    this.tagDotColor,
  });

  final String courseName;
  final bool isSmallCourse;
  final bool muted;
  final Color? tagDotColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CourseSubjectTag(name: courseName, muted: muted),
        SizedBox(width: ui(4)),
        CourseClassKindTag(
          isSmall: isSmallCourse,
          muted: muted,
          dotColor: tagDotColor,
        ),
      ],
    );
  }
}

// =============================================================================
// 学生端「课堂签到」独立页面
//
// 入口：学生 dashboard 快捷区「课堂签到」按钮 → controller.openCheckIn()
//      → mainView == checkIn + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：xiaoquanHeaderBg 背景图；左 32 返回；居中 "课堂签到"；
//      远右 32 高 "历史记录" 按钮
//   2. 5 项统计卡（一行平铺，padding 24/8，白底 12 圆角）：
//      6 小课应签课次 / 6 大课一键入册 / 86.5 小课打卡（合计） / 4 迟到 /
//      96.5% 小课准时率（96.5% 用 #8741FF 紫色）
//   3. 双列：左 340 "今日课程"（2 张 316×104 时间段卡，已结束/进行中），
//      右 614×274 "签到操作"（紫色渐变内嵌 #F5F6FA 灰底面板：当前学生 +
//      教师上下课签时间轴 + 上课/下课 2 个签到按钮）
//   4. "最近课堂记录" 6 张 312 宽白卡（3 张/行），状态正常/缺勤；前 3 张
//      课程 tag 走绿调（#DFFCF0）+ 行内排布；后 3 张走黄调（#DBEE49）+
//      独立一行
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #FF323C 缺勤红 / #0CAC40 出勤绿
//      / #DBEE49 黄 tag / #A773FF 状态紫 / #B6B5BB 提示灰 / #6D6B75 副字
// 字体：PingFang SC（标题 16~18 / 正文 12~14）+ Barlow（日期 18 / 时间 18）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_check_in_data.dart';
import '../state/student_check_in_controller.dart';
import 'course_sign_countdown.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
const Color _kPurpleSoftRing = Color(0xFFF7F2FF);
const Color _kStatusGreen = Color(0xFF0CAC40);
const Color _kStatusYellow = Color(0xFFDBEE49);
const Color _kAttendRed = Color(0xFFFF323C);
const Color _kCourseTagGreenBg = Color(0xFFDFFCF0);
const Color _kEndedTagBg = Color(0xFFE6E9F1);

class StudentCheckInView extends ConsumerStatefulWidget {
  const StudentCheckInView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentCheckInView> createState() => _StudentCheckInViewState();
}

class _StudentCheckInViewState extends ConsumerState<StudentCheckInView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(studentCheckInControllerProvider.notifier);
      await notifier.initialize();
      notifier.startLiveSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(studentCheckInControllerProvider.notifier).resumeSync(),
      );
    }
  }

  Future<void> _signIn(StudentTodayCourse course) async {
    final response = await ref
        .read(studentCheckInControllerProvider.notifier)
        .signIn(course.courseId);
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? '上课签到成功'
          : (response.msg.isNotEmpty ? response.msg : '上课签到失败'),
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _signOut(StudentTodayCourse course) async {
    final response = await ref
        .read(studentCheckInControllerProvider.notifier)
        .signOut(course.courseId);
    if (!mounted) return;
    if (!response.isSuccess) {
      AppToast.show(
        context,
        response.msg.isNotEmpty ? response.msg : '下课签到失败',
        type: AppToastType.error,
      );
      return;
    }
    AppToast.show(context, '下课签到成功');
    final updated = ref.read(studentCheckInControllerProvider).selectedCourse;
    if (updated != null && updated.canComment) {
      await _showCommentDialog(updated);
    }
  }

  Future<void> _showCommentDialog(StudentTodayCourse course) async {
    final result = await showScaledDialog<({int score, String comment})>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => _CourseCommentDialog(courseName: course.subjectName),
    );
    if (result == null || !mounted) return;

    final resp = await ref
        .read(studentCheckInControllerProvider.notifier)
        .submitComment(
          courseId: course.courseId,
          comment: result.comment,
          score: result.score,
        );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isNotEmpty ? resp.msg : '评价提交失败');
      return;
    }
    AppToast.show(context, '评价已提交');
  }

  Future<void> _applyMakeup(StudentSignRecordItem record) async {
    if (record.courseId.isEmpty) {
      AppToast.show(context, '缺少课程信息，无法申请补签', type: AppToastType.error);
      return;
    }
    final reason = await showScaledDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => _MakeupReasonDialog(courseName: record.subjectName),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final response = await ref
        .read(studentCheckInControllerProvider.notifier)
        .submitMakeup(
          courseId: record.courseId,
          signType: 1,
          reason: reason.trim(),
        );
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? '补签申请已提交'
          : (response.displayMsg.isNotEmpty
                ? response.displayMsg
                : '补签申请失败'),
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checkIn = ref.watch(studentCheckInControllerProvider);
    final selected = checkIn.selectedCourse;
    final recentRecords = checkIn.recentRecords
        .asMap()
        .entries
        .map((entry) => _recentRecordFromItem(entry.value, entry.key))
        .toList(growable: false);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckInBanner(
            onBack: widget.onBack,
            onOpenHistory: _openHistoryDrawer,
          ),
          SizedBox(height: ui(16)),
          MainContentLoadingShell(
            loading: checkIn.loading,
            preserveChrome: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(stats: _statsFromSummary(checkIn.stats)),
                SizedBox(height: ui(24)),
                // 双列：今日课程 + 签到操作
                LayoutBuilder(
                  builder: (context, c) {
                    final isCompact = c.maxWidth < ui(720);
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('今日课程'),
                          SizedBox(height: ui(12)),
                          _TodayClassesPanel(
                            title: checkIn.todayTitle,
                            courses: checkIn.todayCourses,
                            selectedCourseId: checkIn.selectedCourseId,
                            onSelect: (course) => ref
                                .read(studentCheckInControllerProvider.notifier)
                                .selectCourse(course.courseId),
                          ),
                          SizedBox(height: ui(20)),
                          _SectionTitle('签到操作'),
                          SizedBox(height: ui(12)),
                          _CheckInActionPanel(
                            course: selected,
                            submitting: checkIn.submitting,
                            onSignIn: selected == null
                                ? null
                                : () => _signIn(selected),
                            onSignOut: selected == null
                                ? null
                                : () => _signOut(selected),
                            onComment: selected == null || !selected.canComment
                                ? null
                                : () => _showCommentDialog(selected),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: ui(340),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('今日课程'),
                              SizedBox(height: ui(12)),
                              _TodayClassesPanel(
                                title: checkIn.todayTitle,
                                courses: checkIn.todayCourses,
                                selectedCourseId: checkIn.selectedCourseId,
                                onSelect: (course) => ref
                                    .read(
                                      studentCheckInControllerProvider.notifier,
                                    )
                                    .selectCourse(course.courseId),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ui(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('签到操作'),
                              SizedBox(height: ui(12)),
                              _CheckInActionPanel(
                                course: selected,
                                submitting: checkIn.submitting,
                                onSignIn: selected == null
                                    ? null
                                    : () => _signIn(selected),
                                onSignOut: selected == null
                                    ? null
                                    : () => _signOut(selected),
                                onComment:
                                    selected == null || !selected.canComment
                                    ? null
                                    : () => _showCommentDialog(selected),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: ui(28)),
                _SectionTitle('最近课堂记录'),
                SizedBox(height: ui(12)),
                if (recentRecords.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: ui(24)),
                    child: Center(
                      child: Text(
                        checkIn.error.isNotEmpty
                            ? checkIn.error
                            : '暂无最近课堂记录',
                        style: TextStyle(
                          fontSize: ui(14),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                        ),
                      ),
                    ),
                  )
                else
                  _RecentRecordsGrid(
                    records: recentRecords,
                    onApplyMakeup: (record) {
                      StudentSignRecordItem? item;
                      for (final r in checkIn.recentRecords) {
                        if (r.courseId == record.courseId) {
                          item = r;
                          break;
                        }
                      }
                      if (item == null) {
                        AppToast.show(
                          context,
                          '缺少课程信息，无法申请补签',
                          type: AppToastType.error,
                        );
                        return;
                      }
                      unawaited(_applyMakeup(item));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openHistoryDrawer() async {
    ref.read(studentCheckInControllerProvider.notifier).stopLiveSync();
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await Future.wait([
      ref
          .read(studentCheckInControllerProvider.notifier)
          .loadHistory(range: StudentCheckInHistoryRange.month),
      ref.read(studentCheckInControllerProvider.notifier).loadMakeupList(),
    ]);
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _CheckInHistoryDrawer(
                onClose: () => Navigator.of(ctx).maybePop(),
                onApplyMakeup: _applyMakeup,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
    if (mounted) {
      ref.read(studentCheckInControllerProvider.notifier).startLiveSync();
    }
  }
}

// =============================================================================
// 顶部 banner
// =============================================================================

class _CheckInBanner extends StatelessWidget {
  const _CheckInBanner({required this.onBack, required this.onOpenHistory});

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '课堂签到',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onOpenHistory,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                height: ui(32),
                padding: EdgeInsets.symmetric(horizontal: ui(12)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: ui(16), color: _kPurple),
                    SizedBox(width: ui(4)),
                    Text(
                      '历史记录',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 5 项统计卡
// =============================================================================

class _StatItem {
  const _StatItem({
    required this.value,
    required this.label,
    this.valueColor = _kTextDark,
  });

  final String value;
  final String label;
  final Color valueColor;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: ui(12)),
          Expanded(child: _StatCard(item: stats[i])),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        children: [
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              color: item.valueColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 今日课程面板（左侧 340 宽）
// =============================================================================

class _TodayClassesPanel extends StatelessWidget {
  const _TodayClassesPanel({
    required this.title,
    required this.courses,
    required this.selectedCourseId,
    required this.onSelect,
  });

  final String title;
  final List<StudentTodayCourse> courses;
  final String? selectedCourseId;
  final ValueChanged<StudentTodayCourse> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF9EEFF), Colors.white],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextSection,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(12)),
          if (courses.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ui(24)),
              child: Center(
                child: Text(
                  '今日暂无小课',
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 13,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < courses.length; i++) ...[
              if (i > 0) SizedBox(height: ui(8)),
              _TodayClassCard(
                course: courses[i],
                selected: courses[i].courseId == selectedCourseId,
                onTap: () => onSelect(courses[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({
    required this.course,
    required this.selected,
    required this.onTap,
  });

  final StudentTodayCourse course;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEnded = course.phase == StudentCourseSlotPhase.ended;
    final isInProgress = course.phase == StudentCourseSlotPhase.inProgress;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          width: double.infinity,
          height: ui(104),
          decoration: BoxDecoration(
            color: isEnded ? _kInnerGray : const Color(0xFFF4F4FF),
            borderRadius: BorderRadius.circular(ui(12)),
            border: selected ? Border.all(color: _kPurple, width: 1.5) : null,
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
                    color: isEnded
                        ? _kEndedTagBg
                        : (isInProgress ? _kPurpleSoftBg : _kEndedTagBg),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(ui(12)),
                      bottomLeft: Radius.circular(ui(12)),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isEnded ? '已结束' : (isInProgress ? '进行中' : '未开始'),
                    style: TextStyle(
                      fontSize: ui(12),
                      color: isEnded ? _kTextHint : _kTextDark,
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
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: ui(18),
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(
                        text: '${course.timeStart} ',
                        style: const TextStyle(color: _kTextSection),
                      ),
                      const TextSpan(
                        text: '- ',
                        style: TextStyle(color: _kTextHint),
                      ),
                      TextSpan(
                        text: course.timeEnd,
                        style: const TextStyle(color: _kTextSection),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: ui(16),
                top: ui(48),
                child: _Avatar(seed: course.teacherName, size: ui(40)),
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
                            course.teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        _CourseGreenTag(label: course.subjectName),
                        SizedBox(width: ui(4)),
                        const _SmallClassTag(palette: _TagPalette.green),
                      ],
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      '${course.durationLabel}·${course.location}',
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
        ),
      ),
    );
  }
}

// =============================================================================
// 签到操作面板（614×274）
// =============================================================================

class _CheckInActionPanel extends StatelessWidget {
  const _CheckInActionPanel({
    required this.course,
    required this.submitting,
    this.onSignIn,
    this.onSignOut,
    this.onComment,
  });

  final StudentTodayCourse? course;
  final bool submitting;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = course;
    return Container(
      width: double.infinity,
      height: ui(274),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF9EEFF), Colors.white],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: data == null
          ? Center(
              child: Text(
                '请选择左侧今日小课',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            )
          : Stack(
              children: [
                Positioned(
                  left: ui(12),
                  top: ui(12),
                  right: ui(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: ui(16),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(
                                text: '${data.periodLabel}·',
                                style: const TextStyle(color: _kTextSection),
                              ),
                              TextSpan(
                                text: data.timeRange,
                                style: const TextStyle(color: _kPurple),
                              ),
                            ],
                          ),
                        ),
                      ),
                      CourseSignCountdownBadge(
                        startTime: data.timeStart,
                        endTime: data.timeEnd,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: ui(12),
                  top: ui(51),
                  right: ui(12),
                  height: ui(211),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _kInnerGray,
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                      ),
                      if (data.fenceLabel != null &&
                          data.fenceLabel!.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            height: ui(22),
                            padding: EdgeInsets.symmetric(horizontal: ui(8)),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _kPurpleSoftBg,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(ui(12)),
                                bottomLeft: Radius.circular(ui(12)),
                              ),
                            ),
                            child: Text(
                              data.fenceLabel!,
                              style: TextStyle(
                                fontSize: ui(10),
                                color: _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: ui(12),
                        top: ui(11),
                        child: Row(
                          children: [
                            _Avatar(seed: data.teacherName, size: ui(40)),
                            SizedBox(width: ui(10)),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      data.teacherName,
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: _kTextDark,
                                        fontFamily: 'PingFang SC',
                                        fontWeight: AppFont.w600,
                                        height: 1,
                                      ),
                                    ),
                                    SizedBox(width: ui(4)),
                                    _CourseGreenTag(label: data.subjectName),
                                    SizedBox(width: ui(4)),
                                    const _SmallClassTag(
                                      palette: _TagPalette.green,
                                    ),
                                  ],
                                ),
                                SizedBox(height: ui(4)),
                                Text(
                                  '${data.durationLabel}·${data.location}',
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
                          ],
                        ),
                      ),
                      Positioned(
                        left: ui(12),
                        top: ui(64),
                        child: Row(
                          children: [
                            Text(
                              '教师指定的打卡方式：',
                              style: TextStyle(
                                fontSize: ui(12),
                                color: _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1,
                              ),
                            ),
                            SizedBox(width: ui(36)),
                            Text(
                              data.signMethod,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: ui(12),
                        top: ui(89),
                        child: Text(
                          '教师需先签，学生后签',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1,
                          ),
                        ),
                      ),
                      Positioned(
                        left: ui(170),
                        top: ui(89),
                        right: ui(12),
                        child: _TeacherSignTimeline(
                          startTime: data.teacherSignInTime ?? '—',
                          endTime: data.teacherSignOutTime ?? '—',
                        ),
                      ),
                      Positioned(
                        left: ui(12),
                        bottom: ui(0),
                        right: ui(12),
                        child: _CheckInButtons(
                          canCheckIn: data.canCheckIn && !submitting,
                          canCheckOut: data.canCheckOut && !submitting,
                          canComment: data.canComment && !submitting,
                          onSignIn: onSignIn,
                          onSignOut: onSignOut,
                          onComment: onComment,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TeacherSignTimeline extends StatelessWidget {
  const _TeacherSignTimeline({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 中间分割线 + 两个紫圆点
        SizedBox(
          height: ui(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: ui(8),
                right: ui(8),
                top: ui(7),
                child: Container(height: 1, color: _kBorderHair),
              ),
              Positioned(left: 0, top: 0, child: _TimelineDot()),
              Positioned(right: 0, top: 0, child: _TimelineDot()),
            ],
          ),
        ),
        SizedBox(height: ui(4)),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '教师上课签',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(8)),
                  _TimePill(time: startTime),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '教师下课签',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(8)),
                  _TimePill(time: endTime),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(14),
      height: ui(14),
      decoration: const BoxDecoration(
        color: _kPurpleSoftRing,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: ui(9),
        height: ui(9),
        decoration: BoxDecoration(
          color: _kPurple,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: ui(14), color: _kPurple),
          SizedBox(width: ui(4)),
          Text(
            time,
            style: TextStyle(
              fontSize: ui(12),
              color: _kPurple,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInButtons extends StatelessWidget {
  const _CheckInButtons({
    required this.canCheckIn,
    required this.canCheckOut,
    required this.canComment,
    this.onSignIn,
    this.onSignOut,
    this.onComment,
  });

  final bool canCheckIn;
  final bool canCheckOut;
  final bool canComment;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '上课签到',
              enabled: canCheckIn,
              onTap: onSignIn ?? () {},
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: _ActionButton(
              label: '下课签到',
              enabled: canCheckOut,
              onTap: onSignOut ?? () {},
            ),
          ),
          if (canComment) ...[
            SizedBox(width: ui(16)),
            Expanded(
              child: _ActionButton(
                label: '小课评价',
                enabled: true,
                onTap: onComment ?? () {},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final foreground = enabled ? Colors.white : _kTextDivider;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(12)),
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: enabled ? null : const Color(0xFFE6E9F1),
          border: enabled ? null : Border.all(color: _kBorderSoft),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint_rounded, size: ui(20), color: foreground),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(16),
                color: foreground,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 最近课堂记录卡（312 宽，3 列网格）
// =============================================================================

enum _AttendanceStatus { normal, absent }

enum _TagPalette { green, yellow }

class _RecentRecordData {
  const _RecentRecordData({
    this.courseId = '',
    required this.date,
    required this.status,
    required this.studentName,
    required this.duration,
    required this.location,
    required this.tagPalette,
    required this.tagInline,
    required this.startCard,
    required this.endCard,
    required this.method,
    required this.note,
  });

  final String courseId;
  final String date;
  final _AttendanceStatus status;
  final String studentName;
  final String duration;
  final String location;

  /// tag 颜色：前 3 张走绿、后 3 张走黄
  final _TagPalette tagPalette;

  /// tag 是否与姓名同行（true）或独立一行（false）
  final bool tagInline;

  /// 上课卡时间。null = "-"，"/" 这种特殊值原样展示
  final String? startCard;
  final String? endCard;

  /// 打卡方式（"签到" / "扫码" / "教师一键签到"）
  final String? method;

  /// 备注（不带前缀；展示时补 "备注：" 前缀）
  final String note;
}

class _RecentRecordsGrid extends StatelessWidget {
  const _RecentRecordsGrid({required this.records, this.onApplyMakeup});

  final List<_RecentRecordData> records;
  final ValueChanged<_RecentRecordData>? onApplyMakeup;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(16),
      runSpacing: ui(16),
      children: [
        for (final r in records)
          SizedBox(
            width: ui(312),
            child: _RecentRecordCard(
              data: r,
              onApplyMakeup: onApplyMakeup == null
                  ? null
                  : () => onApplyMakeup!(r),
            ),
          ),
      ],
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.data, this.onApplyMakeup});

  final _RecentRecordData data;
  final VoidCallback? onApplyMakeup;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isAbsent = data.status == _AttendanceStatus.absent;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 日期 + 状态
          Row(
            children: [
              Expanded(
                child: Text(
                  data.date,
                  style: TextStyle(
                    fontSize: ui(18),
                    color: _kTextSection,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(6),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: isAbsent ? _kAttendRed : _kPurpleLight,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  isAbsent ? '缺勤' : '正常',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 15.24 / 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          // tag 行（仅 tagInline == false 时单独占一行；否则与姓名同行）
          if (!data.tagInline) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CourseTag(palette: data.tagPalette),
                SizedBox(width: ui(4)),
                _SmallClassTag(palette: data.tagPalette),
              ],
            ),
            SizedBox(height: ui(12)),
          ],
          // 学生 + 头像
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(seed: data.studentName, size: ui(40)),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.tagInline)
                      Wrap(
                        spacing: ui(4),
                        runSpacing: ui(4),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            data.studentName,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w600,
                              height: 1,
                            ),
                          ),
                          _CourseTag(palette: data.tagPalette),
                          _SmallClassTag(palette: data.tagPalette),
                        ],
                      )
                    else
                      Text(
                        data.studentName,
                        style: TextStyle(
                          fontSize: ui(14),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w600,
                          height: 1,
                        ),
                      ),
                    SizedBox(height: ui(4)),
                    Text(
                      '${data.duration}·${data.location}',
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
          SizedBox(height: ui(12)),
          // 状态行：缺勤显示"申请补签"按钮，其他显示三列时间表
          if (isAbsent) ...[
            Container(
              width: double.infinity,
              height: ui(50),
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
            ),
            SizedBox(height: ui(8)),
            InkWell(
              onTap: onApplyMakeup,
              borderRadius: BorderRadius.circular(ui(6)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: ui(4)),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: ui(16),
                      color: const Color(0xFF1C274C),
                    ),
                    SizedBox(width: ui(8)),
                    Text(
                      '申请补签',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            _AttendStatsRow(
              startCard: data.startCard,
              endCard: data.endCard,
              method: data.method,
            ),
          SizedBox(height: ui(8)),
          Text(
            '备注：${data.note}',
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
    );
  }
}

class _AttendStatsRow extends StatelessWidget {
  const _AttendStatsRow({
    required this.startCard,
    required this.endCard,
    required this.method,
  });

  final String? startCard;
  final String? endCard;
  final String? method;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(11)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(label: '上课卡', value: startCard ?? '-'),
          ),
          Expanded(
            child: _StatColumn(label: '下课卡', value: endCard ?? '-'),
          ),
          Expanded(
            child: _StatColumn(label: '打卡方式', value: method ?? '-'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 通用：tag、头像、段标题
// =============================================================================

class _CourseGreenTag extends StatelessWidget {
  const _CourseGreenTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kCourseTagGreenBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(11),
          color: _kStatusGreen,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 14 / 11,
        ),
      ),
    );
  }
}

class _CourseTag extends StatelessWidget {
  const _CourseTag({required this.palette});

  final _TagPalette palette;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isGreen = palette == _TagPalette.green;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: isGreen ? _kCourseTagGreenBg : _kStatusYellow,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '古筝课',
        style: TextStyle(
          fontSize: isGreen ? ui(11) : ui(12),
          color: isGreen ? _kStatusGreen : _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: isGreen ? 14 / 11 : 15.24 / 12,
        ),
      ),
    );
  }
}

class _SmallClassTag extends StatelessWidget {
  const _SmallClassTag({required this.palette});

  final _TagPalette palette;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final dotColor = palette == _TagPalette.green
        ? _kStatusGreen
        : _kStatusYellow;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: ui(4)),
          Text(
            '小课',
            style: TextStyle(
              fontSize: ui(11),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final firstChar = seed.isNotEmpty ? seed.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFB98FFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

// =============================================================================
// 「签到历史」右侧抽屉
//
// 入口：顶部 banner 右上「历史记录」按钮 → _openHistoryDrawer →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 视觉：
//   - 宽 520，全高，白底，左上 16px 圆角（视觉上 align right 时左边露出）
//   - 顶部 62 高 _HistoryDrawerHeader（3×15 紫竖条 + 标题 + 关闭 X）
//   - 筛选区：
//       · 时间范围 pill 组：本周 / 本月 / 本学期（选中态 = 紫底白字）
//       · 状态 tabs：全部 / 正常 / 缺勤（选中态 = 白底加粗 + 紫色文字）
//   - 汇总条：「共 N 条 · 正常 m · 缺勤 k」，缺勤用红色突出
//   - 列表区：垂直列出 _RecentRecordCard，每张卡之间 12 间距
//   - 空态：居中"暂无签到记录"灰字
// =============================================================================

enum _HistoryDrawerTab { signHistory, makeup }

enum _HistoryTimeRange { week, month, semester }

_HistoryTimeRange _historyRangeOf(StudentCheckInHistoryRange range) {
  return switch (range) {
    StudentCheckInHistoryRange.week => _HistoryTimeRange.week,
    StudentCheckInHistoryRange.month => _HistoryTimeRange.month,
    StudentCheckInHistoryRange.semester => _HistoryTimeRange.semester,
  };
}

StudentCheckInHistoryRange _apiRangeOf(_HistoryTimeRange range) {
  return switch (range) {
    _HistoryTimeRange.week => StudentCheckInHistoryRange.week,
    _HistoryTimeRange.month => StudentCheckInHistoryRange.month,
    _HistoryTimeRange.semester => StudentCheckInHistoryRange.semester,
  };
}

enum _HistoryStatusFilter { all, normal, absent }

enum _MakeupStatusFilter { all, pending, approved, rejected }

class _CheckInHistoryDrawer extends ConsumerStatefulWidget {
  const _CheckInHistoryDrawer({
    required this.onClose,
    required this.onApplyMakeup,
  });

  final VoidCallback onClose;
  final Future<void> Function(StudentSignRecordItem record) onApplyMakeup;

  @override
  ConsumerState<_CheckInHistoryDrawer> createState() =>
      _CheckInHistoryDrawerState();
}

class _CheckInHistoryDrawerState extends ConsumerState<_CheckInHistoryDrawer> {
  _HistoryDrawerTab _tab = _HistoryDrawerTab.signHistory;
  StudentCheckInHistoryRange _range = StudentCheckInHistoryRange.month;
  _HistoryStatusFilter _status = _HistoryStatusFilter.all;
  _MakeupStatusFilter _makeupStatus = _MakeupStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadSignHistory());
  }

  int? get _apiStatusFilter => switch (_status) {
    _HistoryStatusFilter.all => null,
    _HistoryStatusFilter.normal => 0,
    _HistoryStatusFilter.absent => 1,
  };

  int? get _apiMakeupStatusFilter => switch (_makeupStatus) {
    _MakeupStatusFilter.all => null,
    _MakeupStatusFilter.pending => 0,
    _MakeupStatusFilter.approved => 1,
    _MakeupStatusFilter.rejected => 2,
  };

  Future<void> _reloadSignHistory() {
    return ref
        .read(studentCheckInControllerProvider.notifier)
        .loadHistory(range: _range, status: _apiStatusFilter);
  }

  Future<void> _reloadMakeupList() {
    return ref
        .read(studentCheckInControllerProvider.notifier)
        .loadMakeupList(status: _apiMakeupStatusFilter);
  }

  Future<void> _showMakeupDetail(StudentCourseSignMakeupItem item) async {
    final fields = await ref
        .read(studentCheckInControllerProvider.notifier)
        .loadMakeupDetail(item.id);
    if (!mounted) return;
    await _showCourseSignMakeupDetailDialog(
      context,
      title: '补签申请详情',
      fields: fields,
    );
  }

  List<_RecentRecordData> _mapRecords(List<StudentSignRecordItem> items) {
    return items
        .asMap()
        .entries
        .map((entry) => _recentRecordFromItem(entry.value, entry.key))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checkIn = ref.watch(studentCheckInControllerProvider);
    final filtered = _mapRecords(checkIn.historyRecords);
    final normalCount = filtered
        .where((r) => r.status == _AttendanceStatus.normal)
        .length;
    final absentCount = filtered.length - normalCount;
    final makeupItems = checkIn.makeupRecords;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          bottomLeft: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HistoryDrawerHeader(
            onClose: widget.onClose,
            tab: _tab,
            onTabChanged: (tab) {
              setState(() => _tab = tab);
              if (tab == _HistoryDrawerTab.makeup) {
                unawaited(_reloadMakeupList());
              }
            },
          ),
          if (_tab == _HistoryDrawerTab.signHistory) ...[
            _HistoryFilterBar(
              range: _historyRangeOf(_range),
              status: _status,
              onRangeChanged: (r) {
                setState(() => _range = _apiRangeOf(r));
                unawaited(_reloadSignHistory());
              },
              onStatusChanged: (s) {
                setState(() => _status = s);
                unawaited(_reloadSignHistory());
              },
            ),
            _HistorySummaryBar(
              total: filtered.length,
              normal: normalCount,
              absent: absentCount,
            ),
            Expanded(
              child: checkIn.loadingHistory
                  ? const Center(child: AppLoadingIndicator())
                  : filtered.isEmpty
                  ? _HistoryEmpty(
                      message: checkIn.historyError.isNotEmpty
                          ? checkIn.historyError
                          : '暂无签到记录',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        ui(16),
                        ui(12),
                        ui(16),
                        ui(20),
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                      itemBuilder: (ctx, i) {
                        final card = filtered[i];
                        final item = checkIn.historyRecords[i];
                        return _RecentRecordCard(
                          data: card,
                          onApplyMakeup: card.status == _AttendanceStatus.absent
                              ? () => widget.onApplyMakeup(item)
                              : null,
                        );
                      },
                    ),
            ),
          ] else ...[
            _MakeupFilterBar(
              status: _makeupStatus,
              onStatusChanged: (s) {
                setState(() => _makeupStatus = s);
                unawaited(_reloadMakeupList());
              },
            ),
            _MakeupSummaryBar(total: makeupItems.length),
            Expanded(
              child: checkIn.loadingMakeup
                  ? const Center(child: AppLoadingIndicator())
                  : makeupItems.isEmpty
                  ? _HistoryEmpty(
                      message: checkIn.makeupError.isNotEmpty
                          ? checkIn.makeupError
                          : '暂无补签申请',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        ui(16),
                        ui(12),
                        ui(16),
                        ui(20),
                      ),
                      itemCount: makeupItems.length,
                      separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                      itemBuilder: (ctx, i) {
                        final item = makeupItems[i];
                        return _CourseSignMakeupCard(
                          item: item,
                          onTap: () => unawaited(_showMakeupDetail(item)),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryDrawerHeader extends StatelessWidget {
  const _HistoryDrawerHeader({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
  });

  final VoidCallback onClose;
  final _HistoryDrawerTab tab;
  final ValueChanged<_HistoryDrawerTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(8)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: ui(3.25),
                height: ui(15),
                decoration: BoxDecoration(
                  color: _kPurple,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                '历史记录',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Padding(
                  padding: EdgeInsets.all(ui(8)),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(18),
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Container(
            height: ui(34),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            padding: EdgeInsets.all(ui(3)),
            child: Row(
              children: [
                _HistoryDrawerTabButton(
                  label: '签到历史',
                  selected: tab == _HistoryDrawerTab.signHistory,
                  onTap: () => onTabChanged(_HistoryDrawerTab.signHistory),
                ),
                _HistoryDrawerTabButton(
                  label: '补签申请',
                  selected: tab == _HistoryDrawerTab.makeup,
                  onTap: () => onTabChanged(_HistoryDrawerTab.makeup),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDrawerTabButton extends StatelessWidget {
  const _HistoryDrawerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(8)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: selected ? _kPurple : _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.range,
    required this.status,
    required this.onRangeChanged,
    required this.onStatusChanged,
  });

  final _HistoryTimeRange range;
  final _HistoryStatusFilter status;
  final ValueChanged<_HistoryTimeRange> onRangeChanged;
  final ValueChanged<_HistoryStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时间范围',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Row(
            children: [
              _HistoryRangePill(
                label: '本周',
                selected: range == _HistoryTimeRange.week,
                onTap: () => onRangeChanged(_HistoryTimeRange.week),
              ),
              SizedBox(width: ui(8)),
              _HistoryRangePill(
                label: '本月',
                selected: range == _HistoryTimeRange.month,
                onTap: () => onRangeChanged(_HistoryTimeRange.month),
              ),
              SizedBox(width: ui(8)),
              _HistoryRangePill(
                label: '本学期',
                selected: range == _HistoryTimeRange.semester,
                onTap: () => onRangeChanged(_HistoryTimeRange.semester),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          Container(
            height: ui(34),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            padding: EdgeInsets.all(ui(3)),
            child: Row(
              children: [
                _HistoryStatusTab(
                  label: '全部',
                  selected: status == _HistoryStatusFilter.all,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.all),
                ),
                _HistoryStatusTab(
                  label: '正常',
                  selected: status == _HistoryStatusFilter.normal,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.normal),
                ),
                _HistoryStatusTab(
                  label: '缺勤',
                  selected: status == _HistoryStatusFilter.absent,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.absent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRangePill extends StatelessWidget {
  const _HistoryRangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          height: ui(32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kPurple : Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: selected ? _kPurple : _kBorderSoft),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: selected ? Colors.white : _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryStatusTab extends StatelessWidget {
  const _HistoryStatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(8)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: selected ? _kPurple : _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySummaryBar extends StatelessWidget {
  const _HistorySummaryBar({
    required this.total,
    required this.normal,
    required this.absent,
  });

  final int total;
  final int normal;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
          children: [
            const TextSpan(
              text: '共 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$total',
              style: const TextStyle(color: _kTextDark),
            ),
            const TextSpan(
              text: ' 条',
              style: TextStyle(color: _kTextHint),
            ),
            const TextSpan(
              text: '   ·   ',
              style: TextStyle(color: _kTextDivider),
            ),
            const TextSpan(
              text: '正常 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$normal',
              style: const TextStyle(color: _kStatusGreen),
            ),
            const TextSpan(
              text: '   ·   ',
              style: TextStyle(color: _kTextDivider),
            ),
            const TextSpan(
              text: '缺勤 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$absent',
              style: const TextStyle(color: _kAttendRed),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({this.message = '暂无签到记录'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: ui(48),
            color: _kTextDivider,
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeupFilterBar extends StatelessWidget {
  const _MakeupFilterBar({
    required this.status,
    required this.onStatusChanged,
  });

  final _MakeupStatusFilter status;
  final ValueChanged<_MakeupStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '审批状态',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Container(
            height: ui(34),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            padding: EdgeInsets.all(ui(3)),
            child: Row(
              children: [
                _HistoryStatusTab(
                  label: '全部',
                  selected: status == _MakeupStatusFilter.all,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.all),
                ),
                _HistoryStatusTab(
                  label: '待审批',
                  selected: status == _MakeupStatusFilter.pending,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.pending),
                ),
                _HistoryStatusTab(
                  label: '已通过',
                  selected: status == _MakeupStatusFilter.approved,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.approved),
                ),
                _HistoryStatusTab(
                  label: '已驳回',
                  selected: status == _MakeupStatusFilter.rejected,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeupSummaryBar extends StatelessWidget {
  const _MakeupSummaryBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
          children: [
            const TextSpan(
              text: '共 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$total',
              style: const TextStyle(color: _kTextDark),
            ),
            const TextSpan(
              text: ' 条补签申请',
              style: TextStyle(color: _kTextHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseSignMakeupCard extends StatelessWidget {
  const _CourseSignMakeupCard({required this.item, required this.onTap});

  final StudentCourseSignMakeupItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (Color bg, Color fg) = switch (item.status) {
      0 => (const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
      1 => (const Color(0xFFE8F5E9), _kStatusGreen),
      2 => (const Color(0xFFFEE4E8), _kAttendRed),
      _ => (_kInnerGray, _kTextSecondary),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(15),
                      color: _kTextSection,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(6),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    item.displayStatus,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: fg,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(8)),
            Text(
              '${item.signTypeLabel} · ${item.createTime.isEmpty ? '—' : item.createTime}',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
            SizedBox(height: ui(6)),
            Text(
              item.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCourseSignMakeupDetailDialog(
  BuildContext context, {
  required String title,
  required List<({String label, String value})> fields,
}) {
  final ui = DashboardScaleScope.of(context).ui;
  return showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => GradientHeaderDialog(
      title: title,
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(6)),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(13),
                        height: 1.5,
                        fontFamily: 'PingFang SC',
                      ),
                      children: [
                        TextSpan(
                          text: '${fields[i].label}：',
                          style: TextStyle(
                            color: _kTextHint,
                            fontWeight: AppFont.w400,
                          ),
                        ),
                        TextSpan(
                          text: fields[i].value.isEmpty ? '—' : fields[i].value,
                          style: TextStyle(
                            color: _kTextDark,
                            fontWeight: AppFont.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: ui(16)),
          SizedBox(
            width: double.infinity,
            height: ui(44),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kBorderSoft),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '关闭',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// 小课评价弹窗
// =============================================================================

class _CourseCommentDialog extends StatefulWidget {
  const _CourseCommentDialog({required this.courseName});

  final String courseName;

  @override
  State<_CourseCommentDialog> createState() => _CourseCommentDialogState();
}

class _CourseCommentDialogState extends State<_CourseCommentDialog> {
  int _score = 5;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '小课评价',
      width: 460,
      actionBar: AppDialogActionBar(
        confirmLabel: '提交',
        cancelLabel: '取消',
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () {
          Navigator.of(
            context,
          ).pop((score: _score, comment: _commentCtrl.text.trim()));
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.courseName,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(16)),
          Text(
            '评分',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) SizedBox(width: ui(8)),
                InkWell(
                  onTap: () => setState(() => _score = i),
                  borderRadius: BorderRadius.circular(ui(4)),
                  child: Icon(
                    i <= _score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: ui(28),
                    color: i <= _score
                        ? const Color(0xFFFFB800)
                        : _kTextDivider,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: ui(16)),
          Text(
            '评价内容',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '请输入对本节课的评价',
              filled: true,
              fillColor: _kInnerGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ui(8)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(ui(12)),
            ),
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// API 数据映射
// =============================================================================

List<_StatItem> _statsFromSummary(StudentCheckInStat stat) {
  final rate = stat.smallCourseOnTimeRate;
  final rateLabel = rate > 0
      ? (rate % 1 == 0 ? '%' : '%')
      : '0%';
  return [
    _StatItem(value: '', label: '小课应签课次'),
    _StatItem(value: '', label: '大课一键入册'),
    _StatItem(value: '', label: '小课打卡（合计）'),
    _StatItem(value: '', label: '迟到'),
    _StatItem(value: rateLabel, label: '小课准时率', valueColor: _kPurple),
  ];
}

_RecentRecordData _recentRecordFromItem(StudentSignRecordItem item, int index) {
  final start = item.studentSignInTime;
  final end = item.studentSignOutTime;
  return _RecentRecordData(
    courseId: item.courseId,
    date: item.date,
    status: item.isAbsent ? _AttendanceStatus.absent : _AttendanceStatus.normal,
    studentName: item.subjectName,
    duration: item.durationLabel,
    location: item.location,
    tagPalette: index < 3 ? _TagPalette.green : _TagPalette.yellow,
    tagInline: index < 3,
    startCard: item.isAbsent
        ? null
        : (start == null || start.isEmpty ? '-' : start),
    endCard: item.isAbsent ? null : (end == null || end.isEmpty ? '-' : end),
    method: item.method.isEmpty ? null : item.method,
    note: item.note.isEmpty
        ? (item.isAbsent ? '未检测到上下课打卡，记为缺勤' : '无')
        : item.note,
  );
}

class _MakeupReasonDialog extends StatefulWidget {
  const _MakeupReasonDialog({required this.courseName});

  final String courseName;

  @override
  State<_MakeupReasonDialog> createState() => _MakeupReasonDialogState();
}

class _MakeupReasonDialogState extends State<_MakeupReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '申请补签',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              widget.courseName,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
            SizedBox(height: ui(12)),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '请填写补签原因',
                filled: true,
                fillColor: _kInnerGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ui(8)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(ui(12)),
              ),
            ),
            SizedBox(height: ui(16)),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(context).pop(text);
                    },
                    child: const Text('提交申请'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

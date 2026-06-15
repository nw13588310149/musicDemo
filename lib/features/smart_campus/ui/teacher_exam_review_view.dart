// =============================================================================
// 任课老师 / 班主任端「考评管理」独立页面
//
// 入口：教师 dashboard 快捷区「考评管理」按钮 → controller.openExamReview()
//      → mainView == examReview + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 与「作业批改」(teacher_homework_review_view.dart) 共用同款双列骨架，
// 但只读语义（不可新建考试），并在视觉/数据上有以下差异：
//
//   1. 整页底色：#EFF3FC（区别于作业批改的默认浅灰）。
//   2. Banner（62 高，白→#F9EDFF 渐变）：左返回 / 居中标题 "考评管理" 16/600
//      + 副标题 12/400 #B6B5BB「列表展示已关联到您任教的月考科目；教师仅可
//      查看学生提交并进行评分与点评，不可新建考试。」/ 右上仅一个 "历史月考"
//      胶囊按钮（紫色钟铃图标 + 白底 1px #F3F2F3 边）。
//   3. 状态 tabs：全部 / 成绩未发布 / 成绩已发布。
//   4. 统计面板（真实班级筛选 + 6 项统计）：
//      6 项统计 = 待评分人次 / 关联考试科目 / 已评人次 / 已评均分 / 最高分 /
//      最低分。
//   5. 左侧考试列表卡（白卡 + 灰底 #F5F6FA / 选中态紫底 #F4F4FF）：每张卡
//      左下显示 28/16 Barlow N/M 提交比（如 4/11），随后是截止时间 / 班级 /
//      tag(2026年4月 月考 + 科目 + 待评(N) 11px) / 标题 16/500，顶部右侧
//      68×22 圆角左下右上"已截止/进行中"角标。
//   6. 右侧考试详情：标题 + 截止 + 12/12 紫色 #8741FF 同步说明行 +
//      灰底【教务月考要求】+ 4 项 _ProgressMetricCell（参与人数 / 未交人数 /
//      待评人数 / 已评人数）+ 学生提交表（同作业批改）。
//   7. 右抽屉：
//        · 历史月考（344 宽）：与 _HistoryDrawer 视觉一致，标题改为"历史月考"。
//        · 评分（600 宽）：与 _ReviewDrawer 同款表单，标题"评分"，附件标
//          媒体类型按学生提交（音频）+ 分数/100 + 点评对象 + 点评形态 +
//          评语；底部紫色渐变"提交评分" CTA。
//
// 颜色：白卡 / #F5F6FA / #F4F4FF / #F3F2F3 / #8741FF / #FF6A00 / #12CE51 /
//      #71717A 表头灰 / #B6B5BB 提示灰 / #EFF3FC 页底
// 字体：PingFang SC（10/11/12/13/14/16/600）+ Barlow（28 数值 + 16 分母）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import '../data/teacher_exam_data.dart';
import '../state/teacher_exam_controller.dart';
import '../../shell/ui/shell_layout.dart';
import 'student_homework_submission_preview.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 配色 -------------------------------------------------------------------
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kPageGrey = Color(0xFFF5F6FA);
const Color _kPickGrey = Color(0xFFF4F4FF);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextBlack = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleEnd = Color(0xFFB68EFF);
const Color _kPurpleStart = Color(0xFF8640FF);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeBg = Color(0xFFFFEDD3);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenBg = Color(0xFFE4FFED);
const Color _kPillIconColor = Color(0xFF1C274C);

// ---- 数据模型 ---------------------------------------------------------------

enum _SubmissionState { passed, pending, missing, reviewed }

typedef _Submission = TeacherExamSubmission;
typedef _ExamItem = TeacherExamItem;
typedef _ExamOverviewStats = TeacherExamOverviewStats;
typedef _CornerKind = TeacherExamCornerKind;

extension _SubmissionStateCompat on TeacherExamSubmissionState {
  _SubmissionState get uiState => switch (this) {
    TeacherExamSubmissionState.passed => _SubmissionState.passed,
    TeacherExamSubmissionState.pending => _SubmissionState.pending,
    TeacherExamSubmissionState.missing => _SubmissionState.missing,
    TeacherExamSubmissionState.reviewed => _SubmissionState.reviewed,
  };
}

int _avatarSeedFor(String studentId, String studentName) {
  if (studentId.isNotEmpty) return studentId.hashCode.abs();
  return studentName.hashCode.abs();
}

String? _resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final resolved = MediaUrl.resolve(trimmed);
  return resolved.isEmpty ? null : resolved;
}

String _fileNameFromPath(String path, String fallback) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return fallback;
  return segments.last;
}

// ---- 数据模型（UI 层复用 [TeacherExamSubmission] 等 API 模型）---------------

const List<String> _kStatusTabs = ['全部', '成绩未发布', '成绩已发布'];

// ---- 入口 view --------------------------------------------------------------

class TeacherExamReviewView extends ConsumerStatefulWidget {
  const TeacherExamReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherExamReviewView> createState() =>
      _TeacherExamReviewViewState();
}

class _TeacherExamReviewViewState extends ConsumerState<TeacherExamReviewView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherExamControllerProvider.notifier).initialize();
    });
  }

  Future<void> _handleSubmissionAction(_ExamItem exam, _Submission submission) async {
    if (submission.canRemind) {
      final response = await ref
          .read(teacherExamControllerProvider.notifier)
          .remindStudent(
            examId: exam.id,
            subjectId: exam.subjectId,
            studentId: submission.studentId,
          );
      if (!mounted) return;
      AppToast.show(
        context,
        response.isSuccess ? '催交提醒已发送' : response.displayMsg,
        type: response.isSuccess ? AppToastType.success : AppToastType.error,
      );
      return;
    }
    _openScoreDrawer(exam, submission);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final examState = ref.watch(teacherExamControllerProvider);
    final visibleItems = examState.visibleExams;
    final activeIdx = visibleItems.isEmpty
        ? 0
        : examState.activeIdx.clamp(0, visibleItems.length - 1);
    final active = visibleItems.isEmpty ? null : visibleItems[activeIdx];
    final initialLoading = examState.loading && examState.exams.isEmpty;

    return Container(
      color: _kPageBg,
      padding: EdgeInsets.symmetric(horizontal: ui(0)),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExamBanner(
              onBack: widget.onBack,
              onOpenHistory: _openHistoryDrawer,
            ),
            SizedBox(height: ui(16)),
            MainContentLoadingShell(
              loading: initialLoading,
              preserveChrome: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusTabsRow(
                    tabs: _kStatusTabs,
                    activeIdx: examState.statusTab,
                    onTap: (i) => ref
                        .read(teacherExamControllerProvider.notifier)
                        .selectStatusTab(i),
                  ),
                  SizedBox(height: ui(12)),
                  _StatsPanel(
                    stats: examState.overviewStats,
                    classFilter: examState.classFilter,
                    classOptions: examState.classOptions,
                    onClassChanged: (value) => ref
                        .read(teacherExamControllerProvider.notifier)
                        .selectClass(value),
                  ),
                  SizedBox(height: ui(16)),
                  if (!initialLoading && active == null)
                    Center(
                      child: Text(
                        examState.error.isNotEmpty
                            ? examState.error
                            : '暂无可批改的考试',
                      ),
                    )
                  else if (!initialLoading)
                    _BodyRow(
                      items: visibleItems,
                      activeIdx: activeIdx,
                      loadingDetail: examState.loadingDetail,
                      onSelect: (i) => ref
                          .read(teacherExamControllerProvider.notifier)
                          .selectExam(i),
                      active: active!,
                      onOpenScore: (s) => unawaited(_handleSubmissionAction(active, s)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openHistoryDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭历史月考',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _HistoryDrawer(items: ref.read(teacherExamControllerProvider).exams),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _openScoreDrawer(_ExamItem item, _Submission submission) {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭评分',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _ScoreDrawer(
              item: item,
              submission: submission,
              onScored: () => ref
                  .read(teacherExamControllerProvider.notifier)
                  .refreshActiveExam(),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

// =============================================================================
// 顶部 banner（白→#F9EDFF 渐变；左返回 + 居中标题/副标题 + 右"历史月考"按钮）
// =============================================================================

class _ExamBanner extends StatelessWidget {
  const _ExamBanner({required this.onBack, required this.onOpenHistory});

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: smartCampusPageBannerDecoration(ui),
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
                  color: _kPillIconColor,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '考评管理',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '列表展示已关联到您任教的月考科目；教师仅可查看学生提交并进行评分与点评，不可新建考试。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: _BannerActionButton(
              icon: Icons.notifications_none_rounded,
              label: '历史月考',
              onTap: onOpenHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(16), color: _kPurple),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
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
// 状态 tabs（5 项）
// =============================================================================

class _StatusTabsRow extends StatelessWidget {
  const _StatusTabsRow({
    required this.tabs,
    required this.activeIdx,
    required this.onTap,
  });

  final List<String> tabs;
  final int activeIdx;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: ui(8)),
            _SegmentChip(
              label: tabs[i],
              active: i == activeIdx,
              onTap: () => onTap(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 统计面板（班级筛选 + 累计/本学期/本月 + 6 张 stat 卡）
// =============================================================================

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.stats,
    required this.classFilter,
    required this.classOptions,
    required this.onClassChanged,
  });

  final _ExamOverviewStats stats;
  final String classFilter;
  final List<String> classOptions;
  final ValueChanged<String> onClassChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
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
              SizedBox(
                width: ui(180),
                child: PopupSelectorField<String>(
                  value: classFilter,
                  items: classOptions,
                  itemLabel: (s) => s,
                  onChanged: onClassChanged,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Row(
            children: [
              Expanded(
                child: _StatCell(value: '${stats.pending}', label: '待评分人次'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: '${stats.subjects}', label: '关联考试科目'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: '${stats.reviewed}', label: '已评人次'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.averageLabel, label: '已评均分'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.maxLabel, label: '最高分'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.minLabel, label: '最低分'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGap extends StatelessWidget {
  const _StatGap();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(16));
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            label,
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
// 主体双列：左 340 考试列表 + 右 615 考试详情 / 提交表
// =============================================================================

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
    required this.active,
    required this.onOpenScore,
    this.loadingDetail = false,
  });

  final List<_ExamItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final _ExamItem active;
  final ValueChanged<_Submission> onOpenScore;
  final bool loadingDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(340),
            child: _ExamListPanel(
              items: items,
              activeIdx: activeIdx,
              onSelect: onSelect,
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: _ExamDetailPanel(
              item: active,
              onOpenScore: onOpenScore,
              loadingDetail: loadingDetail,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 左侧考试列表 -----------------------------------------------------------

class _ExamListPanel extends StatelessWidget {
  const _ExamListPanel({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
  });

  final List<_ExamItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(4)),
            child: Text(
              '考试列表',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextBlack,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(8)),
            _ExamListCard(
              item: items[i],
              active: i == activeIdx,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamListCard extends StatelessWidget {
  const _ExamListCard({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _ExamItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = active ? _kPickGrey : _kPageGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: ui(104)),
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.publishedRatio.submitted}',
                      style: TextStyle(
                        fontSize: ui(28),
                        color: _kTextDark,
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: ui(2)),
                    Padding(
                      padding: EdgeInsets.only(bottom: ui(4)),
                      child: Text(
                        '/${item.publishedRatio.total}',
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kTextHint,
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(2)),
                Text(
                  '截止 ${item.deadline}',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  item.classLabel,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(6)),
                Row(
                  children: [
                    _SubjectTag(label: item.examLabel),
                    SizedBox(width: ui(4)),
                    _SubjectTag(label: item.subject),
                    SizedBox(width: ui(4)),
                    if (item.pendingReview > 0)
                      _PendingReviewTag(count: item.pendingReview),
                  ],
                ),
                SizedBox(height: ui(6)),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _CornerLabel(label: item.cornerLabel, kind: item.cornerKind),
          ),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PendingReviewTag extends StatelessWidget {
  const _PendingReviewTag({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '待评($count)',
        style: TextStyle(
          fontSize: ui(11),
          color: _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  const _CornerLabel({required this.label, required this.kind});

  final String label;
  final _CornerKind kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = kind == TeacherExamCornerKind.published
        ? const Color(0xFFE6E9F1)
        : _kOrangeBg;
    final fg =
        kind == TeacherExamCornerKind.published ? _kTextHint : _kOrange;
    return Container(
      width: ui(68),
      height: ui(22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(ui(12)),
          bottomLeft: Radius.circular(ui(12)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// ---- 右侧考试详情 + 4 项指标 + 学生表格 -------------------------------------

class _ExamDetailPanel extends StatelessWidget {
  const _ExamDetailPanel({
    required this.item,
    required this.onOpenScore,
    this.loadingDetail = false,
  });

  final _ExamItem item;
  final ValueChanged<_Submission> onOpenScore;
  final bool loadingDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(12)),
              Text(
                '截止 ${item.deadline}',
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
          SizedBox(height: ui(8)),
          Text(
            item.syncNote,
            style: TextStyle(
              fontSize: ui(12),
              color: _kPurple,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(12)),
          _OfficialBlock(description: item.officialDesc),
          SizedBox(height: ui(12)),
          _ProgressMetrics(item: item),
          SizedBox(height: ui(12)),
          if (loadingDetail && item.submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: AppLoadingIndicator()),
            )
          else
            _SubmissionsTable(
              submissions: item.submissions,
              onOpenScore: onOpenScore,
            ),
        ],
      ),
    );
  }
}

class _OfficialBlock extends StatelessWidget {
  const _OfficialBlock({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '【教务月考要求】',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            description,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetrics extends StatelessWidget {
  const _ProgressMetrics({required this.item});

  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _ProgressMetricCell(
            label: '参与人数',
            value: '${item.attended}',
            icon: Icons.people_alt_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '未交人数',
            value: '${item.unsubmitted}',
            icon: Icons.person_off_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '待评人数',
            value: '${item.pendingReview}',
            icon: Icons.fact_check_outlined,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '已评人数',
            value: '${item.reviewed}',
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _ProgressMetricCell extends StatelessWidget {
  const _ProgressMetricCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(6)),
          Container(
            width: ui(28),
            height: ui(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kTextDark, _kPurple],
              ),
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            child: Icon(icon, size: ui(16), color: _kPageGrey),
          ),
        ],
      ),
    );
  }
}

// ---- 学生提交表格 -----------------------------------------------------------

class _SubmissionsTable extends StatelessWidget {
  const _SubmissionsTable({
    required this.submissions,
    required this.onOpenScore,
  });

  final List<_Submission> submissions;
  final ValueChanged<_Submission> onOpenScore;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(8)),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            children: const [
              SizedBox(width: 90 + 4, child: _ColHeader('学生')),
              Expanded(child: _ColHeader('状态')),
              Expanded(child: _ColHeader('科目')),
              Expanded(child: _ColHeader('介质')),
              Expanded(child: _ColHeader('上传时间')),
              SizedBox(width: 80, child: _ColHeader('操作')),
            ],
          ),
        ),
        for (final s in submissions)
          _SubmissionRow(item: s, onOpenScore: () => onOpenScore(s)),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.4,
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.item, required this.onOpenScore});

  final _Submission item;
  final VoidCallback onOpenScore;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(94),
            child: Row(
              children: [
                _AvatarCircle(
                  name: item.studentName,
                  seed: _avatarSeedFor(item.studentId, item.studentName),
                ),
                SizedBox(width: ui(4)),
                Flexible(
                  child: Text(
                    item.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(child: _StatusPill(state: item.state.uiState)),
          Expanded(child: _CellText(item.subject)),
          Expanded(child: _CellText(item.medium)),
          Expanded(child: _CellText(item.uploadAt)),
          SizedBox(
            width: ui(90),
            child: InkWell(
              onTap: onOpenScore,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kTextDark,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  item.action,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.4,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _SubmissionState state;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ({Color bg, Color fg, String text}) tone = switch (state) {
      _SubmissionState.passed => (bg: _kGreenBg, fg: _kGreen, text: '已通过'),
      _SubmissionState.pending => (bg: _kOrangeBg, fg: _kOrange, text: '待评'),
      _SubmissionState.missing => (
        bg: const Color(0xFFFFE5E5),
        fg: const Color(0xFFE54848),
        text: '未交',
      ),
      _SubmissionState.reviewed => (bg: _kGreenBg, fg: _kGreen, text: '已批改'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text(
          tone.text,
          style: TextStyle(
            fontSize: ui(12),
            color: tone.fg,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name, required this.seed, this.size = 32});

  final String name;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final palettes = const [
      [Color(0xFFB68EFF), Color(0xFF8741FF)],
      [Color(0xFFFFB68E), Color(0xFFFF8741)],
      [Color(0xFF8EE0FF), Color(0xFF418EFF)],
    ];
    final palette = palettes[seed.abs() % palettes.length];
    return Container(
      width: ui(size),
      height: ui(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: ui(13),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 历史月考右抽屉（344 宽，与作业批改"历史发布记录"同款视觉）
// =============================================================================

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({required this.items});

  final List<_ExamItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(344),
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(16), ui(20), ui(16), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: ui(3.25),
                    height: ui(14.85),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Text(
                    '历史月考',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Padding(
                    padding: EdgeInsets.only(top: ui(4)),
                    child: Text(
                      '共${items.length}条',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(20)),
              Container(height: 1, color: _kBorderSoft),
              SizedBox(height: ui(12)),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                  itemBuilder: (ctx, i) =>
                      _HistoryCard(item: items[i % items.length]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(104)),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.publishedRatio.submitted}',
                style: TextStyle(
                  fontSize: ui(28),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              SizedBox(width: ui(2)),
              Padding(
                padding: EdgeInsets.only(bottom: ui(4)),
                child: Text(
                  '/${item.publishedRatio.total}',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextHint,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(2)),
          Text(
            '截止 ${item.deadline}',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            item.classLabel,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(6)),
          Row(
            children: [
              _SubjectTag(label: item.examLabel),
              SizedBox(width: ui(4)),
              _SubjectTag(label: item.subject),
            ],
          ),
          SizedBox(height: ui(6)),
          Text(
            item.title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextBlack,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 评分右抽屉（600 宽，与作业批改"作业点评"同款表单）
// =============================================================================

class _ScoreDrawer extends ConsumerStatefulWidget {
  const _ScoreDrawer({
    required this.item,
    required this.submission,
    required this.onScored,
  });

  final _ExamItem item;
  final _Submission submission;
  final Future<void> Function() onScored;

  @override
  ConsumerState<_ScoreDrawer> createState() => _ScoreDrawerState();
}

class _ScoreDrawerState extends ConsumerState<_ScoreDrawer> {
  String _scope = '高三音乐实验班';
  String _form = '文字 + 评分';
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _commentCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(
      text: widget.submission.score?.toString() ?? '',
    );
    _commentCtrl = TextEditingController(text: widget.submission.comment);
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolvedUrl = _resolveMediaUrl(widget.submission.path) ?? '';
    final hasAttachment = resolvedUrl.isNotEmpty;
    final fileName = hasAttachment
        ? _fileNameFromPath(
            widget.submission.path,
            '${widget.submission.studentName}_${widget.item.title}.${_extOf(widget.submission.medium)}',
          )
        : '${widget.submission.studentName}_${widget.item.title}.${_extOf(widget.submission.medium)}';
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(80)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DrawerTitleBar(title: '评分'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(16)),
                    _ScoreProfileRow(
                      submission: widget.submission,
                      item: widget.item,
                    ),
                    SizedBox(height: ui(16)),
                    if (hasAttachment)
                      _AttachmentCard(
                        filename: fileName,
                        medium: widget.submission.medium,
                        onPreview: () => showStudentHomeworkSubmissionPreview(
                          context,
                          ref: ref,
                          fileUrl: resolvedUrl,
                          title: fileName,
                          typeTag: widget.submission.medium,
                          mediumLabel: widget.submission.medium,
                          attachmentName: fileName,
                        ),
                        onDownload: () => openCoursewareUrl(resolvedUrl),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(12),
                          vertical: ui(10),
                        ),
                        decoration: BoxDecoration(
                          color: _kPageGrey,
                          borderRadius: BorderRadius.circular(ui(8)),
                        ),
                        child: Text(
                          '该学生尚未提交考试文件',
                          style: TextStyle(
                            fontSize: ui(13),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '评分与点评',
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: ui(12)),
                        Expanded(
                          child: Container(height: 1, color: _kBorderSoft),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(16)),
                    _FieldLabel('分数/100'),
                    SizedBox(height: ui(8)),
                    _ScoreInput(controller: _scoreCtrl),
                    SizedBox(height: ui(16)),
                    _FieldLabel('点评对象'),
                    SizedBox(height: ui(8)),
                    PopupSelectorField<String>(
                      value: _scope,
                      items: const ['高三音乐实验班', '本人可见', '家长可见'],
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() => _scope = v),
                    ),
                    SizedBox(height: ui(16)),
                    _FieldLabel('点评形态'),
                    SizedBox(height: ui(8)),
                    PopupSelectorField<String>(
                      value: _form,
                      items: const ['文字 + 评分', '语音 + 评分', '仅评分'],
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() => _form = v),
                    ),
                    SizedBox(height: ui(16)),
                    _FieldLabel('评语/配文'),
                    SizedBox(height: ui(8)),
                    _PlainTextArea(
                      hint: '请输入对该次考试的评分依据与点评内容…',
                      height: ui(80),
                      controller: _commentCtrl,
                    ),
                  ],
                ),
              ),
            ),
            if (hasAttachment)
              Positioned(
                left: ui(20),
                right: ui(20),
                bottom: ui(20),
                child: _PrimaryGradientButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: _submitting ? '提交中...' : '提交评分',
                  onTap: _submit,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final score = num.tryParse(_scoreCtrl.text.trim());
    if (score == null || score < 0 || score > 100) {
      AppToast.show(context, '请输入 0-100 的分数', type: AppToastType.error);
      return;
    }
    if (widget.item.id.isEmpty ||
        widget.item.subjectId == 0 ||
        widget.submission.studentId.isEmpty) {
      AppToast.show(context, '考试或学生信息不完整', type: AppToastType.error);
      return;
    }
    setState(() => _submitting = true);
    final response = await ref
        .read(teacherExamControllerProvider.notifier)
        .submitScore(
          examId: widget.item.id,
          subjectId: widget.item.subjectId,
          studentId: widget.submission.studentId,
          score: score,
          comment: _commentCtrl.text.trim(),
          path: widget.submission.path,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!response.isSuccess) {
      AppToast.show(context, response.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '评分提交成功', type: AppToastType.success);
    await widget.onScored();
    if (mounted) Navigator.of(context).maybePop();
  }

  String _extOf(String medium) {
    switch (medium) {
      case '音频':
        return 'mp3';
      case '视频':
        return 'mp4';
      case '图片':
        return 'jpg';
      default:
        return 'pdf';
    }
  }
}

class _ScoreProfileRow extends StatelessWidget {
  const _ScoreProfileRow({required this.submission, required this.item});

  final _Submission submission;
  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarCircle(
          name: submission.studentName,
          seed: _avatarSeedFor(submission.studentId, submission.studentName),
          size: 40,
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      submission.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _StatusPill(state: submission.state.uiState),
                ],
              ),
              SizedBox(height: ui(4)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.examLabel} · ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Text(
                    submission.uploadAt,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.filename,
    required this.medium,
    required this.onPreview,
    required this.onDownload,
  });

  final String filename;
  final String medium;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final iconColors = switch (medium) {
      '音频' => const [Color(0xFFFFE3D7), Color(0xFFFFF8F4)],
      '视频' => const [Color(0xFFD7FFE9), Color(0xFFF4FFF8)],
      '图片' => const [Color(0xFFFFF1D7), Color(0xFFFFFCF4)],
      _ => const [Color(0xFFD7E2FF), Color(0xFFF9FBFF)],
    };
    final tagColor = switch (medium) {
      '音频' => const Color(0xFFFF8741),
      '视频' => const Color(0xFF12CE51),
      '图片' => const Color(0xFFE68D10),
      _ => const Color(0xFFFF5040),
    };
    final tagText = switch (medium) {
      '音频' => 'MP3',
      '视频' => 'MP4',
      '图片' => 'JPG',
      _ => 'PDF',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: iconColors,
              ),
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: const Color(0xFFE5EFFF)),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                tagText,
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.file_download_outlined,
            label: '下载',
            onTap: onDownload,
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: medium == '音频'
                ? Icons.headphones_rounded
                : Icons.remove_red_eye_outlined,
            label: medium == '音频' ? '试听' : '在线预览',
            onTap: onPreview,
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(14), color: _kPillIconColor),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '请输入分数',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
              ),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Text(
            ' / 100',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
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
// 抽屉里通用零件
// =============================================================================

class _DrawerTitleBar extends StatelessWidget {
  const _DrawerTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: _kPurple,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.4,
      ),
    );
  }
}

class _PlainTextArea extends StatefulWidget {
  const _PlainTextArea({
    required this.hint,
    required this.height,
    this.controller,
  });

  final String hint;
  final double height;
  final TextEditingController? controller;

  @override
  State<_PlainTextArea> createState() => _PlainTextAreaState();
}

class _PlainTextAreaState extends State<_PlainTextArea> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: AppTextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [_kPurpleEnd, _kPurpleStart],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: ui(16), color: Colors.white),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 任课老师 / 班主任端「作业批改」独立页面（"作业与批改"总览）
//
// 入口：教师 dashboard 快捷区「作业批改」按钮 → controller.openHomeworkReview()
//      → mainView == homeworkReview + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变；左 12 返回；居中 "作业与批改"
//      16/600；右上 "历史作业" + "发布作业" 两白底胶囊按钮（带紫色图标）。
//   2. 状态 tabs（44 高 4 tab）：白底圆角胶囊，命中黑底 #0B081A 白字。
//      tab：全部 / 待我批改 / 进行中 / 已截止/已收尾。
//   3. 统计面板（单白卡 12 圆角 16 内边）：
//      · 上行（spaceBetween）：左 120×44 「全部班级 ▾」白底 1px #F3F2F3 边
//        胶囊 → 点击 PopupSelectorField；右 累计/本学期/本月 toggle（黑底白字）。
//      · 下行：6 张 stat card 等宽 flex（灰底 #F5F6FA 12 圆角）：
//        待批改人次 / 发布作业数 / 已评阅人次 / 已评均分 / 最高分 / 最低分。
//   4. 主体双列：
//      · 左 340 白卡：标题 "作业列表" + 6 张 316×104 卡片（灰底/紫底 #F4F4FF
//        选中态），每张卡顶部右上 68×22 状态角标（已截止 / 待评(N)），主区
//        显示截止时间 / 班级 / 科目 tag / 标题。点击切换 active。
//      · 右 615 白卡：当前作业详情：
//          - 标题 + 截止时间（spaceBetween）
//          - 灰底卡：【建议提交：音频】+ 描述说明 12/24 行高
//          - 4 项数据指示（126×32 灰底胶囊：标签 + 数字 + 28×28 紫色渐变图标）
//          - 学生表格：表头 + N 行（32×32 头像 + 姓名 + 状态 tag + 科目 + 介质
//            + 上传时间 + 80×40 黑底操作按钮）
//
//   5. 三个右抽屉（showGeneralDialog + Align(centerRight) + SlideTransition）：
//      · 发布作业（600 宽）：作业标题输入 + 学科/期望提交格式双下拉 + 截止时间
//        picker + 发布对象（带紫色 checkbox 的班级列表）+ 作业要求 textarea
//        + 底部紫色渐变 "发布" CTA。
//      · 历史发布记录（344 宽）：标题 "历史发布记录 + 共12条" + 7+ 张 312×104
//        卡片，每张卡左下显示「N / 总数」提交比 + 截止时间 + 班级 + 科目 + 标题。
//      · 作业点评（600 宽）：标题 "作业点评" + 学生 profile（40 头像 + 姓名 +
//        课程 + 时间 + 待批改 tag）+ PDF 文件卡（封面 + 名称 + 大小 + 下载 +
//        在线预览）+ "批改与点评" 分组：分数/100 输入 + 班级（点评对象）下拉
//        + 点评形态下拉 + 评语 textarea + 底部紫色渐变 "发布批改" CTA。
//
// 颜色：白卡 / #F5F6FA 灰底 / #F4F4FF 选中态 / #F3F2F3 边 / #8741FF 主紫 /
//      #B68EFF→#8640FF 紫渐变 CTA / #FF6A00 待评橙 / #12CE51 已通过绿 /
//      #71717A 表头灰 / #B6B5BB 提示灰
// 字体：PingFang SC（10/11/12/13/14/16/600）+ Barlow（28 数值 + 16 分母）
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';

import '../../../core/widgets/app_text.dart';
// ---- 配色 -------------------------------------------------------------------
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
const Color _kSubjectBg = Colors.white;
const Color _kPillIconColor = Color(0xFF1C274C);

// ---- 数据模型 ---------------------------------------------------------------

enum _SubmissionState { passed, pending, missing, reviewed }

class _Submission {
  const _Submission({
    required this.studentName,
    required this.avatarSeed,
    required this.state,
    required this.subject,
    required this.medium,
    required this.uploadAt,
    required this.action,
  });

  final String studentName;
  final int avatarSeed;
  final _SubmissionState state;
  final String subject;
  final String medium;
  final String uploadAt;

  /// 操作按钮文案（试听/评分 · 查看 · 催交/详情）。
  final String action;
}

class _HomeworkItem {
  const _HomeworkItem({
    required this.title,
    required this.subject,
    required this.classLabel,
    required this.deadline,
    required this.suggested,
    required this.suggestedDesc,
    required this.cornerLabel,
    required this.cornerKind,
    required this.totalPeople,
    required this.unsubmitted,
    required this.pendingReview,
    required this.reviewed,
    required this.submissions,
    required this.publishedRatio,
  });

  final String title;
  final String subject;
  final String classLabel;
  final String deadline;
  final String suggested;
  final String suggestedDesc;

  /// 角标文案（已截止 / 待评(2) / 进行中 等）。
  final String cornerLabel;

  /// 角标颜色：closed / pending。
  final _CornerKind cornerKind;

  final int totalPeople;
  final int unsubmitted;
  final int pendingReview;
  final int reviewed;

  final List<_Submission> submissions;

  /// 历史发布抽屉里展示的 N/M 提交比，例 (4, 11)。
  final ({int submitted, int total}) publishedRatio;
}

enum _CornerKind { closed, pending }

const List<String> _kStatusTabs = ['全部', '待我批改', '进行中', '已截止/已收尾'];
const List<String> _kRangeTabs = ['累计', '本学期', '本月'];
const List<String> _kClassOptions = ['全部班级', '高三音乐实验班', '高三声乐回课', '高二音乐实验班'];

// ---- 入口 view --------------------------------------------------------------

class TeacherHomeworkReviewView extends StatefulWidget {
  const TeacherHomeworkReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TeacherHomeworkReviewView> createState() =>
      _TeacherHomeworkReviewViewState();
}

class _TeacherHomeworkReviewViewState extends State<TeacherHomeworkReviewView> {
  int _statusTab = 0;
  int _rangeTab = 0;
  String _classFilter = _kClassOptions.first;
  int _activeHomeworkIdx = 1; // 默认选中第 2 张（紫底 #F4F4FF）。

  late final List<_HomeworkItem> _all = _buildDemoHomework();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final active = _all[_activeHomeworkIdx];

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewBanner(
            onBack: widget.onBack,
            onOpenHistory: () => _openHistoryDrawer(),
            onOpenPublish: () => _openPublishDrawer(),
          ),
          SizedBox(height: ui(16)),
          _StatusTabsRow(
            tabs: _kStatusTabs,
            activeIdx: _statusTab,
            onTap: (i) => setState(() => _statusTab = i),
          ),
          SizedBox(height: ui(12)),
          _StatsPanel(
            classFilter: _classFilter,
            onClassChanged: (v) => setState(() => _classFilter = v),
            rangeIdx: _rangeTab,
            onRangeChanged: (i) => setState(() => _rangeTab = i),
          ),
          SizedBox(height: ui(16)),
          _BodyRow(
            items: _all,
            activeIdx: _activeHomeworkIdx,
            onSelect: (i) => setState(() => _activeHomeworkIdx = i),
            active: active,
            onOpenReview: (s) => _openReviewDrawer(active, s),
          ),
        ],
      ),
    );
  }

  void _openHistoryDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭历史发布记录',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _HistoryDrawer(items: _all),
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

  void _openPublishDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭发布作业',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: const _PublishDrawer(),
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

  void _openReviewDrawer(_HomeworkItem item, _Submission submission) {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭作业点评',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _ReviewDrawer(item: item, submission: submission),
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
// 顶部 banner（白→#F9EDFF 渐变；左返回 + 居中标题 + 右两按钮）
// =============================================================================

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({
    required this.onBack,
    required this.onOpenHistory,
    required this.onOpenPublish,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenPublish;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
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
                  color: _kPillIconColor,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: AppText(
                '作业与批改',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: Row(
              children: [
                _BannerActionButton(
                  icon: Icons.notifications_none_rounded,
                  label: '历史作业',
                  onTap: onOpenHistory,
                ),
                SizedBox(width: ui(8)),
                _BannerActionButton(
                  icon: Icons.edit_note_rounded,
                  label: '发布作业',
                  onTap: onOpenPublish,
                ),
              ],
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
            AppText(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 状态 tabs（4 项；命中黑底白字 6 圆角）
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
    this.compact = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  /// stats 面板里 toggle 用的紧凑型（更细 padding）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ui(compact ? 12 : 16),
          vertical: ui(10),
        ),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: AppText(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
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
    required this.classFilter,
    required this.onClassChanged,
    required this.rangeIdx,
    required this.onRangeChanged,
  });

  final String classFilter;
  final ValueChanged<String> onClassChanged;
  final int rangeIdx;
  final ValueChanged<int> onRangeChanged;

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
                  items: _kClassOptions,
                  itemLabel: (s) => s,
                  onChanged: onClassChanged,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(ui(4)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _kRangeTabs.length; i++) ...[
                      if (i > 0) SizedBox(width: ui(4)),
                      _SegmentChip(
                        label: _kRangeTabs[i],
                        active: i == rangeIdx,
                        onTap: () => onRangeChanged(i),
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Row(
            children: const [
              Expanded(
                child: _StatCell(value: '6', label: '待批改人次'),
              ),
              _StatGap(),
              Expanded(
                child: _StatCell(value: '6', label: '发布作业数'),
              ),
              _StatGap(),
              Expanded(
                child: _StatCell(value: '3', label: '已评阅人次'),
              ),
              _StatGap(),
              Expanded(
                child: _StatCell(value: '98', label: '已评均分'),
              ),
              _StatGap(),
              Expanded(
                child: _StatCell(value: '100', label: '最高分'),
              ),
              _StatGap(),
              Expanded(
                child: _StatCell(value: '99', label: '最低分'),
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
          AppText(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(2)),
          AppText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 主体双列：左 340 作业列表 + 右 615 作业详情 / 提交表
// =============================================================================

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
    required this.active,
    required this.onOpenReview,
  });

  final List<_HomeworkItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final _HomeworkItem active;
  final ValueChanged<_Submission> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(340),
            child: _HomeworkListPanel(
              items: items,
              activeIdx: activeIdx,
              onSelect: onSelect,
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: _HomeworkDetailPanel(
              item: active,
              onOpenReview: onOpenReview,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 左侧作业列表 -----------------------------------------------------------

class _HomeworkListPanel extends StatelessWidget {
  const _HomeworkListPanel({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
  });

  final List<_HomeworkItem> items;
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
            child: AppText(
              '作业列表',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextBlack,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(8)),
            _HomeworkListCard(
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

class _HomeworkListCard extends StatelessWidget {
  const _HomeworkListCard({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _HomeworkItem item;
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
                AppText(
                  '截止 ${item.deadline}',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                AppText(
                  item.classLabel,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(6)),
                Row(
                  children: [
                    _SubjectTag(label: item.subject),
                    SizedBox(width: ui(4)),
                    if (item.pendingReview > 0)
                      _PendingReviewTag(count: item.pendingReview),
                  ],
                ),
                SizedBox(height: ui(8)),
                AppText(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
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
        color: _kSubjectBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: AppText(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
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
      child: AppText(
        '待评($count)',
        style: TextStyle(
          fontSize: ui(12),
          color: _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
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
    final bg = kind == _CornerKind.closed
        ? const Color(0xFFE6E9F1)
        : _kOrangeBg;
    final fg = kind == _CornerKind.closed ? _kTextHint : _kOrange;
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
      child: AppText(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

// ---- 右侧作业详情 + 4 项指标 + 学生表格 -------------------------------------

class _HomeworkDetailPanel extends StatelessWidget {
  const _HomeworkDetailPanel({required this.item, required this.onOpenReview});

  final _HomeworkItem item;
  final ValueChanged<_Submission> onOpenReview;

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
                child: AppText(
                  item.title,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(12)),
              AppText(
                '截止 ${item.deadline}',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _SuggestedBlock(
            suggested: item.suggested,
            description: item.suggestedDesc,
          ),
          SizedBox(height: ui(12)),
          _ProgressMetrics(item: item),
          SizedBox(height: ui(12)),
          _SubmissionsTable(
            submissions: item.submissions,
            onOpenReview: onOpenReview,
          ),
        ],
      ),
    );
  }
}

class _SuggestedBlock extends StatelessWidget {
  const _SuggestedBlock({required this.suggested, required this.description});

  final String suggested;
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
          AppText(
            '【建议提交：$suggested】',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: ui(2)),
          AppText(
            description,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
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

  final _HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _ProgressMetricCell(
            label: '全班人数',
            value: '${item.totalPeople}',
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
            label: '待批人数',
            value: '${item.pendingReview}',
            icon: Icons.fact_check_outlined,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '已批人数',
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
                  child: AppText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: ui(4)),
                AppText(
                  value,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 1,
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
    required this.onOpenReview,
  });

  final List<_Submission> submissions;
  final ValueChanged<_Submission> onOpenReview;

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
          _SubmissionRow(item: s, onOpenReview: () => onOpenReview(s)),
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
    return AppText(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.item, required this.onOpenReview});

  final _Submission item;
  final VoidCallback onOpenReview;

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
                _AvatarCircle(name: item.studentName, seed: item.avatarSeed),
                SizedBox(width: ui(4)),
                Flexible(
                  child: AppText(
                    item.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(child: _StatusPill(state: item.state)),
          Expanded(child: _CellText(item.subject)),
          Expanded(child: _CellText(item.medium)),
          Expanded(child: _CellText(item.uploadAt)),
          SizedBox(
            width: ui(90),
            child: InkWell(
              onTap: onOpenReview,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kTextDark,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: AppText(
                  item.action,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
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
    return AppText(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w400,
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
        child: AppText(
          tone.text,
          style: TextStyle(
            fontSize: ui(12),
            color: tone.fg,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
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
      child: AppText(
        name.characters.first,
        style: TextStyle(
          fontSize: ui(13),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 发布作业右抽屉（600 宽）
// =============================================================================

class _PublishDrawer extends StatefulWidget {
  const _PublishDrawer();

  @override
  State<_PublishDrawer> createState() => _PublishDrawerState();
}

class _PublishDrawerState extends State<_PublishDrawer> {
  String _subject = '乐理';
  String _medium = '文档';
  String _deadline = '2026/03/12 12:32:02';
  final Set<int> _selectedClasses = {2}; // 默认勾中第 3 项（与 Figma 一致）

  static const _classes = [
    ('高三音乐实验班', '行政班', '8人', '大课'),
    ('高三音乐实验班', '行政班', '8人', '大课'),
    ('高三音乐实验班', '行政班', '8人', '大课'),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
                    const _DrawerTitleBar(title: '发布作业'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(20)),
                    _FieldLabel('作业标题'),
                    SizedBox(height: ui(12)),
                    _PlainInputField(hint: '请输入作业标题', initial: '高三音乐实验班'),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('学科'),
                              SizedBox(height: ui(12)),
                              PopupSelectorField<String>(
                                value: _subject,
                                items: const ['乐理', '声乐', '钢琴', '合唱'],
                                itemLabel: (v) => v,
                                onChanged: (v) => setState(() => _subject = v),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ui(32)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('期望提交格式'),
                              SizedBox(height: ui(12)),
                              PopupSelectorField<String>(
                                value: _medium,
                                items: const ['文档', '音频', '视频', '图片'],
                                itemLabel: (v) => v,
                                onChanged: (v) => setState(() => _medium = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('截止时间'),
                    SizedBox(height: ui(12)),
                    _DeadlinePicker(
                      value: _deadline,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 30)),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked == null) return;
                        if (!context.mounted) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t == null) return;
                        setState(() {
                          _deadline =
                              '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')} '
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
                        });
                      },
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('发布对象'),
                    SizedBox(height: ui(12)),
                    for (var i = 0; i < _classes.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(8)),
                      _ClassCheckRow(
                        title: _classes[i].$1,
                        kind: _classes[i].$2,
                        people: _classes[i].$3,
                        tag: _classes[i].$4,
                        checked: _selectedClasses.contains(i),
                        onTap: () => setState(() {
                          if (_selectedClasses.contains(i)) {
                            _selectedClasses.remove(i);
                          } else {
                            _selectedClasses.add(i);
                          }
                        }),
                      ),
                    ],
                    SizedBox(height: ui(20)),
                    _FieldLabel('作业要求'),
                    SizedBox(height: ui(12)),
                    _PlainTextArea(hint: '说明题目范围、命名规则、提交格式等', height: ui(56)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(20),
              right: ui(20),
              bottom: ui(20),
              child: _PrimaryGradientButton(
                icon: Icons.send_rounded,
                label: '发布',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassCheckRow extends StatelessWidget {
  const _ClassCheckRow({
    required this.title,
    required this.kind,
    required this.people,
    required this.tag,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String kind;
  final String people;
  final String tag;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPageGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CheckBox(checked: checked),
                SizedBox(width: ui(10)),
                Expanded(
                  child: AppText(
                    title,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(4),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(4)),
                    border: Border.all(color: _kBorderSoft, width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: ui(6),
                        height: ui(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFA773FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: ui(4)),
                      AppText(
                        tag,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(24)),
              child: Row(
                children: [
                  AppText(
                    kind,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  AppText(
                    people,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(14),
      height: ui(14),
      decoration: BoxDecoration(
        color: checked ? _kPurple : Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: _kPurple),
      ),
      alignment: Alignment.center,
      child: checked
          ? Icon(Icons.check, size: ui(10), color: Colors.white)
          : null,
    );
  }
}

class _DeadlinePicker extends StatelessWidget {
  const _DeadlinePicker({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPageGrey),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                value,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: ui(16), color: _kPurple),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 历史发布记录右抽屉（344 宽）
// =============================================================================

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({required this.items});

  final List<_HomeworkItem> items;

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
                  AppText(
                    '历史发布记录',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Padding(
                    padding: EdgeInsets.only(top: ui(4)),
                    child: AppText(
                      '共${items.length}条',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1,
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

  final _HomeworkItem item;

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
              AppText(
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
                child: AppText(
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
          AppText(
            '截止 ${item.deadline}',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(2)),
          AppText(
            item.classLabel,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(6)),
          _SubjectTag(label: item.subject),
          SizedBox(height: ui(6)),
          AppText(
            item.title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextBlack,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 作业点评右抽屉（600 宽）
// =============================================================================

class _ReviewDrawer extends StatefulWidget {
  const _ReviewDrawer({required this.item, required this.submission});

  final _HomeworkItem item;
  final _Submission submission;

  @override
  State<_ReviewDrawer> createState() => _ReviewDrawerState();
}

class _ReviewDrawerState extends State<_ReviewDrawer> {
  String _scope = '高三音乐实验班';
  String _form = '文字 + 评分';
  final _scoreCtrl = TextEditingController(text: '95');
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
                    const _DrawerTitleBar(title: '作业点评'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(16)),
                    _ReviewProfileRow(
                      submission: widget.submission,
                      item: widget.item,
                    ),
                    SizedBox(height: ui(16)),
                    _AttachmentCard(
                      filename: '上海音乐学院2026本科招生简章.pdf',
                      size: '3.32M',
                    ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppText(
                          '批改与点评',
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w600,
                            height: 1,
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
                      hint: '请输入对该次作业的点评内容…',
                      height: ui(80),
                      controller: _commentCtrl,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(20),
              right: ui(20),
              bottom: ui(20),
              child: _PrimaryGradientButton(
                icon: Icons.check_circle_outline_rounded,
                label: '发布批改',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewProfileRow extends StatelessWidget {
  const _ReviewProfileRow({required this.submission, required this.item});

  final _Submission submission;
  final _HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(40),
          height: ui(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: _AvatarCircle(
            name: submission.studentName,
            seed: submission.avatarSeed,
            size: 40,
          ),
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
                    child: AppText(
                      submission.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  const _StatusPill(state: _SubmissionState.pending),
                ],
              ),
              SizedBox(height: ui(4)),
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      '${item.subject} · ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  AppText(
                    submission.uploadAt,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
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
  const _AttachmentCard({required this.filename, required this.size});

  final String filename;
  final String size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD7E2FF), Color(0xFFF9FBFF)],
              ),
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: const Color(0xFFE5EFFF)),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5040),
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: AppText(
                'PDF',
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
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
                AppText(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                AppText(
                  size,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.file_download_outlined,
            label: '下载',
            onTap: () {},
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.remove_red_eye_outlined,
            label: '在线预览',
            onTap: () {},
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
            AppText(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
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
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
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
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          AppText(
            ' / 100',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
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
        AppText(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w600,
            height: 1,
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
    return AppText(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }
}

class _PlainInputField extends StatefulWidget {
  const _PlainInputField({required this.hint, this.initial});

  final String hint;
  final String? initial;

  @override
  State<_PlainInputField> createState() => _PlainInputFieldState();
}

class _PlainInputFieldState extends State<_PlainInputField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
      child: Center(
        child: TextField(
          controller: _ctrl,
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
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
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
      child: TextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
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
          fontWeight: FontWeight.w400,
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
            AppText(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Demo 数据：Figma 列表 4 张作业卡 + 1 张紫底选中态 + 1 张额外卡，统一示意。
// =============================================================================

List<_HomeworkItem> _buildDemoHomework() {
  const submissions = [
    _Submission(
      studentName: '吴振翰',
      avatarSeed: 0,
      state: _SubmissionState.pending,
      subject: '声乐',
      medium: '音频',
      uploadAt: '04-03 20:00',
      action: '试听/评分',
    ),
    _Submission(
      studentName: '何能',
      avatarSeed: 1,
      state: _SubmissionState.passed,
      subject: '声乐',
      medium: '音频',
      uploadAt: '04-03 20:00',
      action: '查看',
    ),
    _Submission(
      studentName: '郑文钡',
      avatarSeed: 2,
      state: _SubmissionState.missing,
      subject: '声乐',
      medium: '音频',
      uploadAt: '04-03 20:00',
      action: '催交/详情',
    ),
    _Submission(
      studentName: '钱丽红',
      avatarSeed: 0,
      state: _SubmissionState.pending,
      subject: '声乐',
      medium: '音频',
      uploadAt: '04-03 20:00',
      action: '试听/评分',
    ),
  ];

  _HomeworkItem makeItem({
    required String title,
    required _CornerKind kind,
    required String corner,
    int pending = 2,
    int submitted = 4,
    int total = 11,
  }) {
    return _HomeworkItem(
      title: title,
      subject: '声乐',
      classLabel: '高三音乐实验班',
      deadline: '04-12 21:00',
      suggested: '音频',
      suggestedDesc: '完成课内习题4-1~4-6，标出和弦功能与解决；可pdf、拍照或扫描文档提交。',
      cornerLabel: corner,
      cornerKind: kind,
      totalPeople: 12,
      unsubmitted: 12,
      pendingReview: pending,
      reviewed: 12,
      submissions: submissions,
      publishedRatio: (submitted: submitted, total: total),
    );
  }

  return [
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.closed, corner: '已截止'),
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.pending, corner: '进行中'),
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.closed, corner: '已截止'),
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.closed, corner: '已截止'),
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.closed, corner: '已截止'),
    makeItem(title: '声乐主项 · 录制提交', kind: _CornerKind.closed, corner: '已截止'),
  ];
}

// =============================================================================
// 学生端「我的作业」独立页面
//
// 入口：学生 dashboard 快捷区「我的作业」按钮 → controller.openMyHomework()
//      → mainView == myHomework + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 4deg 渐变，居中标题"我的作业" +
//      子标题"教师发布要求后提交视频、音频、照片或文档…"，左 32 返回。
//   2. 3 张 100 高统计卡（flex 1，gap 12）：
//      A. "学期考试均分" 32 + 进度条 + "各次月考/大考总均分平均"标签
//      B. 紫色渐变 "最近班级" 8 + "持平" 紫 tag
//      C. 绿色渐变 "最近年级" 62 + "上升3名" 绿 tag
//   3. 双列卡：
//      左 640 "均分柱形"（按科目/按老师 tabs + 4 根柱: 92/88/89/87
//                       + X 轴标签: 音乐/鉴赏/视唱/形体）
//      右 318 "分数段分布"（4 段 82 高灰底面板：90-100 33% 3场 / 80-90
//                        33% 3场 / 70-80 15% 1场 / <70 0% 0场）
//   4. 状态 tabs（全部 / 待提交 / 已提交 / 已批阅，44 高）
//   5. 作业卡 2 列网格（每行 2 张，紫色渐变 #FAF0FF→white，padding 12）
//      展示 6 张覆盖以下变体：
//        - 待提交 + 已逾期（橙红 tag、紫色截止时间 + 提交作业按钮）
//        - 已提交（批阅中：提交文件链接 + "教师批阅中"占位）
//        - 已批阅含语音点评（语音波形 + 点评卡）
//        - 已批阅含视频点评 + 88分
//        - 红色"声乐"tag + 语音 / 视频点评 ×2
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #325BFF 蓝（提交链接 / 分数）
//      / #0CAC40 绿（已提交）/ #FF6A00 橙（待提交）/ #FF323C 红（已逾期）
//      / #12CE51 绿（上升）/ #FF386B 玫红（特殊"声乐"tag）
// 字体：PingFang SC + Barlow（数值 32 / 18）
//
// 弹窗：
//   · "提交作业"（_showSubmitDialog）：复用 [GradientHeaderDialog]（紫渐变
//     顶部 + 装饰图 + 24/500 标题），内含作业标题、提交类型 chips（视频/音频
//     /照片/文档）、上传文件区（走 [cloudDriveControllerProvider] 与 courseware
//     共享同一上传通道）、备注 textarea。提交成功后把卡片状态切到「已提交·
//     批阅中」并填充提交文件名。
//   · "作业详情"（_showDetailDialog）：同款 GradientHeaderDialog，只读展示
//     发布老师 / 截止时间 / 作业要求 / 提交情况 / 教师反馈。
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../../shell/ui/shell_layout.dart';

const Color _kCardBg = Colors.white;
const Color _kPageBg = Color(0xFFEFF3FC);
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
const Color _kBlueLink = Color(0xFF325BFF);
const Color _kSubmittedGreen = Color(0xFF0CAC40);
const Color _kSubmittedGreenBg = Color(0xFFDFFCF0);
const Color _kPendingOrange = Color(0xFFFF6A00);
const Color _kPendingOrangeBg = Color(0xFFFFEDD3);
const Color _kOverdueRed = Color(0xFFFF323C);
const Color _kOverdueRedBg = Color(0xFFFFE4E5);
const Color _kRiseGreen = Color(0xFF12CE51);
const Color _kVocalTagBgRed = Color(0xFFFEE4E8);
const Color _kVocalTagFgRed = Color(0xFFFF386B);

class StudentMyHomeworkView extends ConsumerStatefulWidget {
  const StudentMyHomeworkView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyHomeworkView> createState() =>
      _StudentMyHomeworkViewState();
}

class _StudentMyHomeworkViewState extends ConsumerState<StudentMyHomeworkView> {
  _StatusTab _selectedTab = _StatusTab.all;
  _ChartGroup _chartGroup = _ChartGroup.bySubject;
  late List<_HomeworkData> _records;

  @override
  void initState() {
    super.initState();
    _records = List<_HomeworkData>.from(_kDemoHomework);
  }

  List<_HomeworkData> get _visible {
    switch (_selectedTab) {
      case _StatusTab.all:
        return _records;
      case _StatusTab.pending:
        return _records
            .where(
              (r) =>
                  r.status == _HomeworkStatus.pending ||
                  r.status == _HomeworkStatus.overdue,
            )
            .toList();
      case _StatusTab.submitted:
        return _records
            .where((r) => r.status == _HomeworkStatus.submitted)
            .toList();
      case _StatusTab.reviewed:
        return _records
            .where((r) => r.status == _HomeworkStatus.reviewed)
            .toList();
    }
  }

  Future<void> _onSubmit(_HomeworkData data) async {
    final result = await showScaledDialog<_SubmitHomeworkResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogCtx) => _SubmitHomeworkDialog(data: data),
    );
    if (!mounted || result == null) return;

    setState(() {
      _records = [
        for (final r in _records)
          if (identical(r, data) ||
              (r.title == data.title && r.deadline == data.deadline))
            r.copyWith(
              status: _HomeworkStatus.submitted,
              bodyType: _HomeworkBodyType.submittedReviewing,
              submittedFile: '${result.kindLabel} ·${result.fileName}',
            )
          else
            r,
      ];
    });

    AppToast.show(context, '作业已提交，等待教师批阅');
  }

  Future<void> _onDetail(_HomeworkData data) async {
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogCtx) => _HomeworkDetailDialog(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeworkBanner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _OverviewStatsRow(),
            SizedBox(height: ui(16)),
            _DualPanelRow(
              chartGroup: _chartGroup,
              onChartGroupChanged: (g) => setState(() => _chartGroup = g),
            ),
            SizedBox(height: ui(16)),
            _StatusTabsRow(
              selected: _selectedTab,
              onSelected: (t) => setState(() => _selectedTab = t),
            ),
            SizedBox(height: ui(10)),
            _HomeworkGrid(
              records: _visible,
              onSubmit: _onSubmit,
              onDetail: _onDetail,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

class _HomeworkBanner extends StatelessWidget {
  const _HomeworkBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
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
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(60)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '我的作业',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    '教师发布要求后提交视频、音频、照片或文档；批阅支持纯文字、语音、或视频/图片配合文字说明。',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3 张统计卡
// =============================================================================

class _OverviewStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _AverageScoreCard()),
        SizedBox(width: ui(12)),
        Expanded(child: _TrendCard.classRank()),
        SizedBox(width: ui(12)),
        Expanded(child: _TrendCard.gradeRank()),
      ],
    );
  }
}

class _AverageScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Text(
                '学期考试均分',
                style: TextStyle(
                  fontSize: ui(14),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: ui(28),
              child: Text(
                '32',
                style: TextStyle(
                  fontSize: ui(32),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: ui(70),
              top: ui(36),
              right: 0,
              child: Text(
                '各次月考/大考总均分平均',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextDivider,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              left: ui(70),
              right: 0,
              bottom: ui(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(20)),
                child: Stack(
                  children: [
                    Container(height: ui(8), color: const Color(0xFFF4F4FF)),
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      child: Container(height: ui(8), color: _kPurpleLight),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard.classRank()
    : title = '最近班级',
      value = '8',
      gradient = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x239346FF), Color(0x00FFFFFF)],
        stops: [0.0, 1.0],
      ),
      badgeIcon = null,
      badgeText = '持平',
      badgeColor = _kPurple,
      badgeIconAsHorizontalLine = true;

  const _TrendCard.gradeRank()
    : title = '最近年级',
      value = '62',
      gradient = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x2E46FF77), Color(0x00FFFFFF)],
        stops: [0.0, 1.0],
      ),
      badgeIcon = Icons.trending_up_rounded,
      badgeText = '上升3名',
      badgeColor = _kRiseGreen,
      badgeIconAsHorizontalLine = false;

  final String title;
  final String value;
  final Gradient gradient;
  final IconData? badgeIcon;
  final String badgeText;
  final Color badgeColor;
  final bool badgeIconAsHorizontalLine;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        gradient: gradient,
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(44),
            child: Text(
              value,
              style: TextStyle(
                fontSize: ui(32),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(14),
            child: Container(
              height: ui(24),
              padding: EdgeInsets.symmetric(horizontal: ui(8)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badgeIconAsHorizontalLine)
                    Container(width: ui(8), height: 1, color: badgeColor)
                  else if (badgeIcon != null)
                    Icon(badgeIcon, size: ui(12), color: badgeColor),
                  SizedBox(width: ui(4)),
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: badgeColor,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 双列：均分柱形 + 分数段分布
// =============================================================================

class _DualPanelRow extends StatelessWidget {
  const _DualPanelRow({
    required this.chartGroup,
    required this.onChartGroupChanged,
  });

  final _ChartGroup chartGroup;
  final ValueChanged<_ChartGroup> onChartGroupChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('均分柱形'),
              SizedBox(height: ui(12)),
              _AverageBarChartCard(
                group: chartGroup,
                onGroupChanged: onChartGroupChanged,
              ),
              SizedBox(height: ui(20)),
              _SectionTitle('分数段分布'),
              SizedBox(height: ui(12)),
              _ScoreDistributionCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('均分柱形'),
                  SizedBox(height: ui(12)),
                  _AverageBarChartCard(
                    group: chartGroup,
                    onGroupChanged: onChartGroupChanged,
                  ),
                ],
              ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              flex: 318,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('分数段分布'),
                  SizedBox(height: ui(12)),
                  _ScoreDistributionCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _ChartGroup { bySubject, byTeacher }

class _AverageBarChartCard extends StatelessWidget {
  const _AverageBarChartCard({
    required this.group,
    required this.onGroupChanged,
  });

  final _ChartGroup group;
  final ValueChanged<_ChartGroup> onGroupChanged;

  static const _bars = <_BarItem>[
    _BarItem(label: '音乐', value: 92),
    _BarItem(label: '鉴赏', value: 88),
    _BarItem(label: '视唱', value: 89),
    _BarItem(label: '形体', value: 87),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(400),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SegmentedControl<_ChartGroup>(
            value: group,
            options: const [
              (_ChartGroup.bySubject, '按科目'),
              (_ChartGroup.byTeacher, '按老师'),
            ],
            onChanged: onGroupChanged,
          ),
          SizedBox(height: ui(12)),
          Expanded(child: _BarChart(bars: _bars)),
        ],
      ),
    );
  }
}

class _BarItem {
  const _BarItem({required this.label, required this.value});

  final String label;
  final double value;
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars});

  final List<_BarItem> bars;

  /// Y 轴刻度（自上而下）
  static const _ticks = <int>[100, 95, 90, 85, 80, 0];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const minVal = 73.0;
    const maxVal = 100.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        // Y 轴左侧 28 宽，下方 X 轴 28 高。
        final chartLeft = ui(28);
        final chartBottom = ui(28);
        final chartW = w - chartLeft;
        final chartH = (h - chartBottom).clamp(0.0, double.infinity);
        // 刻度位置：100 在最上，80 在 (5/6)*chartH，0 在底；
        // 80→0 用最后 1/6 高度压缩。
        const tickCount = 6;
        final tickGap = chartH / (tickCount - 1);

        double yForValue(double v) {
          if (v >= 80) {
            // 80→100 映射到 0→ (5/6)*chartH（实际是 5 个 tick 间）
            final ratio = (100 - v) / 20.0;
            return ratio * (chartH * 5 / (tickCount - 1));
          }
          return chartH;
        }

        final barW = ui(35);
        final cellW = chartW / bars.length;

        return Stack(
          children: [
            // Y 轴标签
            for (var i = 0; i < tickCount; i++)
              Positioned(
                left: 0,
                top: i * tickGap - ui(10),
                width: ui(20),
                child: Text(
                  '${_ticks[i]}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                ),
              ),
            // 柱子
            for (var i = 0; i < bars.length; i++)
              Positioned(
                left: chartLeft + cellW * i + (cellW - barW) / 2,
                top: yForValue(bars[i].value),
                width: barW,
                height: (chartH - yForValue(bars[i].value)).clamp(
                  0.0,
                  double.infinity,
                ),
                child: _Bar(value: bars[i].value, valueRange: (minVal, maxVal)),
              ),
            // 柱顶数值
            for (var i = 0; i < bars.length; i++)
              Positioned(
                left: chartLeft + cellW * i + (cellW - barW) / 2,
                top: yForValue(bars[i].value) - ui(20),
                width: barW,
                child: Text(
                  '${bars[i].value.toInt()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            // X 轴标签
            for (var i = 0; i < bars.length; i++)
              Positioned(
                left: chartLeft + cellW * i,
                bottom: 0,
                width: cellW,
                child: Text(
                  bars[i].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.valueRange});

  final double value;
  final (double, double) valueRange;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kPurpleLight, Color(0x66A773FF)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(8)),
          topRight: Radius.circular(ui(8)),
        ),
      ),
    );
  }
}

class _ScoreDistributionCard extends StatelessWidget {
  static const _items = <_ScoreSegment>[
    _ScoreSegment(label: '90-100分', percent: 33, count: 3),
    _ScoreSegment(label: '80-90分', percent: 33, count: 3),
    _ScoreSegment(label: '70-80分', percent: 15, count: 1),
    _ScoreSegment(label: '<70分', percent: 0, count: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(400),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(16)),
            _ScoreSegmentTile(item: _items[i]),
          ],
        ],
      ),
    );
  }
}

class _ScoreSegment {
  const _ScoreSegment({
    required this.label,
    required this.percent,
    required this.count,
  });

  final String label;
  final int percent;
  final int count;
}

class _ScoreSegmentTile extends StatelessWidget {
  const _ScoreSegmentTile({required this.item});

  final _ScoreSegment item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(82),
      padding: EdgeInsets.fromLTRB(ui(16), ui(10), ui(16), ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${item.percent}%',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(20)),
            child: Stack(
              children: [
                Container(height: ui(8), color: _kBorderHair),
                FractionallySizedBox(
                  widthFactor: (item.percent / 50).clamp(0.0, 1.0),
                  child: Container(
                    height: ui(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [_kPurple, Color(0xFFE2D0FF)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(4)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${item.count}场',
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 状态 tabs
// =============================================================================

enum _StatusTab { all, pending, submitted, reviewed }

class _StatusTabsRow extends StatelessWidget {
  const _StatusTabsRow({required this.selected, required this.onSelected});

  final _StatusTab selected;
  final ValueChanged<_StatusTab> onSelected;

  static const _options = <(_StatusTab, String)>[
    (_StatusTab.all, '全部'),
    (_StatusTab.pending, '待提交'),
    (_StatusTab.submitted, '已提交'),
    (_StatusTab.reviewed, '已批阅'),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (tab, label) in _options) ...[
            _TabChip(
              label: label,
              active: tab == selected,
              onTap: () => onSelected(tab),
              activeBg: _kTextDark,
            ),
            SizedBox(width: ui(16)),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeBg,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeBg;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        decoration: BoxDecoration(
          color: active ? activeBg : null,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (tab, label) in options) ...[
            InkWell(
              onTap: () => onChanged(tab),
              borderRadius: BorderRadius.circular(ui(6)),
              child: Container(
                height: ui(32),
                padding: EdgeInsets.symmetric(horizontal: ui(16)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tab == value ? Colors.white : null,
                  borderRadius: BorderRadius.circular(ui(6)),
                  boxShadow: tab == value
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: ui(20),
                            offset: Offset(0, ui(8)),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: tab == value ? _kTextDark : _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: ui(8)),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 作业卡（数据 + 网格 + 单卡）
// =============================================================================

enum _HomeworkSubject { music, vocal, vocalRed }

enum _HomeworkStatus { pending, overdue, submitted, reviewed }

enum _HomeworkBodyType {
  // 待提交：占位文字 + 提交作业按钮
  pending,
  // 已提交（批阅中）：提交链接 + "教师批阅中，请留意通知"
  submittedReviewing,
  // 已批阅：提交链接 + 教师点评（语音/视频气泡）+ 可能含分数
  reviewed,
}

enum _ReviewMediaType { audio, video, none }

class _HomeworkData {
  const _HomeworkData({
    required this.title,
    required this.subject,
    required this.status,
    required this.bodyType,
    required this.teacher,
    required this.deadline,
    this.score,
    this.submittedFile,
    this.reviewMedia = _ReviewMediaType.none,
    this.reviewMediaDuration,
    this.reviewText,
  });

  final String title;
  final _HomeworkSubject subject;
  final _HomeworkStatus status;
  final _HomeworkBodyType bodyType;
  final String teacher;
  final String deadline;
  final String? score;
  final String? submittedFile;
  final _ReviewMediaType reviewMedia;
  final String? reviewMediaDuration;
  final String? reviewText;

  _HomeworkData copyWith({
    String? title,
    _HomeworkSubject? subject,
    _HomeworkStatus? status,
    _HomeworkBodyType? bodyType,
    String? teacher,
    String? deadline,
    String? score,
    String? submittedFile,
    _ReviewMediaType? reviewMedia,
    String? reviewMediaDuration,
    String? reviewText,
  }) {
    return _HomeworkData(
      title: title ?? this.title,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      bodyType: bodyType ?? this.bodyType,
      teacher: teacher ?? this.teacher,
      deadline: deadline ?? this.deadline,
      score: score ?? this.score,
      submittedFile: submittedFile ?? this.submittedFile,
      reviewMedia: reviewMedia ?? this.reviewMedia,
      reviewMediaDuration: reviewMediaDuration ?? this.reviewMediaDuration,
      reviewText: reviewText ?? this.reviewText,
    );
  }
}

class _HomeworkGrid extends StatelessWidget {
  const _HomeworkGrid({
    required this.records,
    required this.onSubmit,
    required this.onDetail,
  });

  final List<_HomeworkData> records;
  final ValueChanged<_HomeworkData> onSubmit;
  final ValueChanged<_HomeworkData> onDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        final cols = isCompact ? 1 : 2;
        final gap = ui(10);
        final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardW,
                child: _HomeworkCard(
                  data: r,
                  onSubmit: () => onSubmit(r),
                  onDetail: () => onDetail(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.data,
    required this.onSubmit,
    required this.onDetail,
  });

  final _HomeworkData data;
  final VoidCallback onSubmit;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFFAF0FF), Colors.white],
        ),
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeaderRow(data: data),
          SizedBox(height: ui(8)),
          _CardMetaRow(
            teacher: data.teacher,
            deadline: data.deadline,
            deadlineHighlight:
                data.status == _HomeworkStatus.pending ||
                data.status == _HomeworkStatus.overdue,
          ),
          SizedBox(height: ui(8)),
          _CardBody(data: data),
          SizedBox(height: ui(8)),
          _CardActionRow(
            showSubmit:
                data.status == _HomeworkStatus.pending ||
                data.status == _HomeworkStatus.overdue,
            onSubmit: onSubmit,
            onDetail: onDetail,
          ),
        ],
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.data});

  final _HomeworkData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _SubjectTag(subject: data.subject),
        SizedBox(width: ui(4)),
        _StatusTag(status: data.status),
        if (data.score != null) ...[
          SizedBox(width: ui(8)),
          Text(
            data.score!,
            style: TextStyle(
              fontSize: ui(14),
              color: _kBlueLink,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.subject});

  final _HomeworkSubject subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg, text) = switch (subject) {
      _HomeworkSubject.music => (_kSubmittedGreenBg, _kSubmittedGreen, '乐理'),
      _HomeworkSubject.vocal => (_kPurpleSoftBg, _kPurple, '声乐'),
      _HomeworkSubject.vocalRed => (_kVocalTagBgRed, _kVocalTagFgRed, '声乐'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final _HomeworkStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final items = <(Color bg, Color fg, String text)>[];
    switch (status) {
      case _HomeworkStatus.pending:
        items.add((_kPendingOrangeBg, _kPendingOrange, '待提交'));
        break;
      case _HomeworkStatus.overdue:
        items.add((_kPendingOrangeBg, _kPendingOrange, '待提交'));
        items.add((_kOverdueRedBg, _kOverdueRed, '已逾期'));
        break;
      case _HomeworkStatus.submitted:
        items.add((_kSubmittedGreenBg, _kSubmittedGreen, '已提交'));
        break;
      case _HomeworkStatus.reviewed:
        items.add((_kSubmittedGreenBg, _kSubmittedGreen, '已提交'));
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: ui(4)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
            decoration: BoxDecoration(
              color: items[i].$1,
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            child: Text(
              items[i].$3,
              style: TextStyle(
                fontSize: ui(12),
                color: items[i].$2,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 15.24 / 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardMetaRow extends StatelessWidget {
  const _CardMetaRow({
    required this.teacher,
    required this.deadline,
    required this.deadlineHighlight,
  });

  final String teacher;
  final String deadline;
  final bool deadlineHighlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          teacher,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        SizedBox(width: ui(8)),
        Container(width: 1, height: ui(10), color: _kTextHint),
        SizedBox(width: ui(8)),
        Text(
          '截止时间：',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        Text(
          deadline,
          style: TextStyle(
            fontSize: ui(12),
            color: deadlineHighlight ? _kPurple : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.data});

  final _HomeworkData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    switch (data.bodyType) {
      case _HomeworkBodyType.pending:
        return Padding(
          padding: EdgeInsets.only(top: ui(4), bottom: ui(8)),
          child: Text(
            '寒假回课状态好，咬字再收',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        );
      case _HomeworkBodyType.submittedReviewing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubmittedFileRow(file: data.submittedFile ?? ''),
            SizedBox(height: ui(8)),
            Text(
              '教师批阅中，请留意通知',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        );
      case _HomeworkBodyType.reviewed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubmittedFileRow(file: data.submittedFile ?? ''),
            SizedBox(height: ui(8)),
            _ReviewBubble(
              media: data.reviewMedia,
              duration: data.reviewMediaDuration ?? '',
              text: data.reviewText ?? '',
            ),
          ],
        );
    }
  }
}

class _SubmittedFileRow extends StatelessWidget {
  const _SubmittedFileRow({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '提交：',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        Flexible(
          child: Text(
            file,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kBlueLink,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
              decoration: TextDecoration.underline,
              decorationColor: _kBlueLink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewBubble extends StatelessWidget {
  const _ReviewBubble({
    required this.media,
    required this.duration,
    required this.text,
  });

  final _ReviewMediaType media;
  final String duration;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewMediaTile(media: media),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '教师点评',
                      style: TextStyle(
                        fontSize: ui(10),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: -ui(8),
            top: -ui(8),
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
                '${media == _ReviewMediaType.video ? '视频' : '语音'} $duration',
                style: TextStyle(
                  fontSize: ui(10),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMediaTile extends StatelessWidget {
  const _ReviewMediaTile({required this.media});

  final _ReviewMediaType media;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (media == _ReviewMediaType.video) {
      return Container(
        width: ui(40),
        height: ui(40),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE5FF),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: BorderRadius.circular(ui(2)),
          ),
          child: Text(
            '视频',
            style: TextStyle(
              fontSize: ui(9),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      );
    }
    return Container(
      width: ui(40),
      height: ui(40),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EFFF),
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFE5EFFF)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.graphic_eq_rounded,
                size: ui(16),
                color: _kPurple,
              ),
            ),
          ),
          Positioned(
            left: ui(6),
            right: ui(6),
            bottom: ui(6),
            child: Container(
              height: ui(11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                '语音',
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionRow extends StatelessWidget {
  const _CardActionRow({
    required this.showSubmit,
    required this.onSubmit,
    required this.onDetail,
  });

  final bool showSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _SmallButton(
          label: '查看详情',
          background: _kInnerGray,
          foreground: _kTextDark,
          onTap: onDetail,
        ),
        if (showSubmit) ...[
          SizedBox(width: ui(12)),
          _SmallButton(
            label: '提交作业',
            useGradient: true,
            foreground: Colors.white,
            onTap: onSubmit,
          ),
        ],
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.foreground,
    required this.onTap,
    this.background,
    this.useGradient = false,
  });

  final String label;
  final Color foreground;
  final VoidCallback onTap;
  final Color? background;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(80),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: useGradient ? null : background,
          gradient: useGradient
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: foreground,
            fontFamily: 'PingFang SC',
            fontWeight: useGradient ? FontWeight.w600 : FontWeight.w500,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 通用：段标题
// =============================================================================

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
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }
}

// =============================================================================
// Demo 数据
// =============================================================================

const String _kDeadline = '04-02 22:00';

const List<_HomeworkData> _kDemoHomework = [
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.music,
    status: _HomeworkStatus.overdue,
    bodyType: _HomeworkBodyType.pending,
    teacher: '陈老师',
    deadline: _kDeadline,
  ),
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.vocal,
    status: _HomeworkStatus.submitted,
    bodyType: _HomeworkBodyType.submittedReviewing,
    teacher: '陈老师',
    deadline: _kDeadline,
    submittedFile: '音频 ·vocal_practice_0331.mp3',
  ),
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.vocal,
    status: _HomeworkStatus.submitted,
    bodyType: _HomeworkBodyType.reviewed,
    teacher: '陈老师',
    deadline: _kDeadline,
    submittedFile: '音频 ·vocal_practice_0331.mp3',
    reviewMedia: _ReviewMediaType.audio,
    reviewMediaDuration: '1:12',
    reviewText: '节奏较稳，后半段可放松手腕；注意弱拍不要抢。',
  ),
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.vocal,
    status: _HomeworkStatus.reviewed,
    bodyType: _HomeworkBodyType.reviewed,
    teacher: '陈老师',
    deadline: _kDeadline,
    score: '88分',
    submittedFile: '音频 ·vocal_practice_0331.mp3',
    reviewMedia: _ReviewMediaType.video,
    reviewMediaDuration: '1:12',
    reviewText: '节奏较稳，后半段可放松手腕；注意弱拍不要抢。',
  ),
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.vocalRed,
    status: _HomeworkStatus.submitted,
    bodyType: _HomeworkBodyType.reviewed,
    teacher: '陈老师',
    deadline: _kDeadline,
    submittedFile: '音频 ·vocal_practice_0331.mp3',
    reviewMedia: _ReviewMediaType.audio,
    reviewMediaDuration: '1:12',
    reviewText: '节奏较稳，后半段可放松手腕；注意弱拍不要抢。',
  ),
  _HomeworkData(
    title: '音程听辨练习03',
    subject: _HomeworkSubject.vocalRed,
    status: _HomeworkStatus.submitted,
    bodyType: _HomeworkBodyType.reviewed,
    teacher: '陈老师',
    deadline: _kDeadline,
    submittedFile: '音频 ·vocal_practice_0331.mp3',
    reviewMedia: _ReviewMediaType.video,
    reviewMediaDuration: '1:12',
    reviewText: '节奏较稳，后半段可放松手腕；注意弱拍不要抢。',
  ),
];

// =============================================================================
// 弹窗：提交作业
// =============================================================================

/// 提交作业弹窗的提交结果（确认按钮 = 已上传 + 已校验）。
class _SubmitHomeworkResult {
  const _SubmitHomeworkResult({
    required this.kind,
    required this.fileName,
    required this.note,
    this.remoteUrl,
  });

  final _SubmitKind kind;
  final String fileName;
  final String note;
  final String? remoteUrl;

  String get kindLabel => switch (kind) {
    _SubmitKind.video => '视频',
    _SubmitKind.audio => '音频',
    _SubmitKind.photo => '照片',
    _SubmitKind.doc => '文档',
  };
}

enum _SubmitKind { video, audio, photo, doc }

class _SubmitHomeworkDialog extends ConsumerStatefulWidget {
  const _SubmitHomeworkDialog({required this.data});

  final _HomeworkData data;

  @override
  ConsumerState<_SubmitHomeworkDialog> createState() =>
      _SubmitHomeworkDialogState();
}

class _SubmitHomeworkDialogState extends ConsumerState<_SubmitHomeworkDialog> {
  _SubmitKind _kind = _SubmitKind.video;
  late final TextEditingController _noteCtrl;

  CoursewarePickedFile? _picked;
  double _progress = 0;
  String? _remotePath;
  String? _errorText;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _ready =>
      _picked != null && _remotePath != null && !_uploading && !_submitting;

  Future<void> _pickFile() async {
    if (_uploading) return;
    final files = await pickCoursewareFiles(allowMultiple: false);
    if (files.isEmpty) return;
    final f = files.first;
    if (!f.canUpload) {
      setState(() => _errorText = '所选文件不可读，请重试');
      return;
    }
    setState(() {
      _picked = f;
      _progress = 0;
      _remotePath = null;
      _errorText = null;
      _uploading = true;
    });
    try {
      final controller = ref.read(cloudDriveControllerProvider.notifier);
      String? saved;
      if (f.hasPath) {
        saved = await controller.uploadFilePathRaw(
          filePath: f.path!,
          filename: f.name,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
        );
      } else {
        saved = await controller.uploadFileRaw(
          bytes: f.bytes ?? Uint8List(0),
          filename: f.name,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (saved == null || saved.isEmpty) {
          _errorText = '上传失败，请重试';
          _remotePath = null;
        } else {
          _remotePath = saved;
          _progress = 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorText = '上传异常，请重试';
        _remotePath = null;
      });
    }
  }

  void _removeFile() {
    if (_uploading) return;
    setState(() {
      _picked = null;
      _progress = 0;
      _remotePath = null;
      _errorText = null;
    });
  }

  void _submit() {
    if (!_ready || _picked == null) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      _SubmitHomeworkResult(
        kind: _kind,
        fileName: _picked!.name,
        note: _noteCtrl.text.trim(),
        remoteUrl: _remotePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '提交作业',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      width: 428,
      contentPadding: EdgeInsets.fromLTRB(ui(24), ui(60), ui(24), ui(20)),
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: _uploading ? '上传中…' : '确认',
        confirmEnabled: _ready,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.data.title,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            '${_subjectLabelOf(widget.data.subject)}·截止${widget.data.deadline}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 20 / 12,
            ),
          ),
          SizedBox(height: ui(12)),
          _DialogLabel('提交类型'),
          SizedBox(height: ui(8)),
          _SubmitKindRow(
            value: _kind,
            onChanged: (k) => setState(() => _kind = k),
          ),
          SizedBox(height: ui(12)),
          _DialogLabel('上传文件'),
          SizedBox(height: ui(8)),
          if (_picked == null)
            _UploadDropZone(onTap: _pickFile)
          else
            _UploadFileTile(
              file: _picked!,
              progress: _progress,
              uploading: _uploading,
              errorText: _errorText,
              done: _remotePath != null,
              onRetry: _pickFile,
              onRemove: _removeFile,
            ),
          SizedBox(height: ui(12)),
          _DialogLabel('备注（选填）'),
          SizedBox(height: ui(8)),
          _NoteInput(controller: _noteCtrl),
        ],
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _SubmitKindRow extends StatelessWidget {
  const _SubmitKindRow({required this.value, required this.onChanged});

  final _SubmitKind value;
  final ValueChanged<_SubmitKind> onChanged;

  static const _items = <(_SubmitKind, String)>[
    (_SubmitKind.video, '视频'),
    (_SubmitKind.audio, '音频'),
    (_SubmitKind.photo, '照片'),
    (_SubmitKind.doc, '文档'),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) SizedBox(width: ui(12)),
          _SubmitKindChip(
            label: _items[i].$2,
            active: _items[i].$1 == value,
            onTap: () => onChanged(_items[i].$1),
          ),
        ],
      ],
    );
  }
}

class _SubmitKindChip extends StatelessWidget {
  const _SubmitKindChip({
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
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(24)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(64),
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kPurpleLight, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, size: ui(16), color: _kPurple),
            SizedBox(width: ui(8)),
            Text(
              '上传文件',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadFileTile extends StatelessWidget {
  const _UploadFileTile({
    required this.file,
    required this.progress,
    required this.uploading,
    required this.errorText,
    required this.done,
    required this.onRetry,
    required this.onRemove,
  });

  final CoursewarePickedFile file;
  final double progress;
  final bool uploading;
  final String? errorText;
  final bool done;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasError = errorText != null;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(8), ui(10)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kPurpleLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: ui(16),
                color: _kPurple,
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              if (uploading)
                SizedBox(
                  width: ui(14),
                  height: ui(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
                  ),
                )
              else
                InkWell(
                  onTap: hasError ? onRetry : onRemove,
                  child: Padding(
                    padding: EdgeInsets.all(ui(2)),
                    child: Icon(
                      hasError ? Icons.refresh_rounded : Icons.close_rounded,
                      size: ui(16),
                      color: hasError ? _kPurple : _kTextHint,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(20)),
            child: LinearProgressIndicator(
              minHeight: ui(4),
              value: hasError ? 0 : (uploading ? progress : (done ? 1 : 0)),
              backgroundColor: _kBorderHair,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasError ? _kOverdueRed : _kPurple,
              ),
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            hasError
                ? errorText!
                : (uploading
                      ? '上传中 ${(progress * 100).toStringAsFixed(0)}%'
                      : (done ? '上传完成' : '准备上传')),
            style: TextStyle(
              fontSize: ui(11),
              color: hasError ? _kOverdueRed : _kTextHint,
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

class _NoteInput extends StatelessWidget {
  const _NoteInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: '请输入',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextDivider,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 弹窗：作业详情
// =============================================================================

class _HomeworkDetailDialog extends StatelessWidget {
  const _HomeworkDetailDialog({required this.data});

  final _HomeworkData data;

  String get _statusLabel => switch (data.status) {
    _HomeworkStatus.pending => '待提交',
    _HomeworkStatus.overdue => '已逾期',
    _HomeworkStatus.submitted => '已提交',
    _HomeworkStatus.reviewed => '已批阅',
  };

  String? get _submittedAt {
    if (data.bodyType == _HomeworkBodyType.pending) return null;
    return data.deadline;
  }

  String get _requirement => switch (data.subject) {
    _HomeworkSubject.music => '完成本节音程听辨练习曲目，注意大小三度区分。',
    _HomeworkSubject.vocal ||
    _HomeworkSubject.vocalRed => '录制指定练声曲+一首艺术歌曲主歌，注意气息与咬字。',
  };

  String get _feedback {
    if (data.bodyType == _HomeworkBodyType.reviewed &&
        (data.reviewText?.isNotEmpty ?? false)) {
      return data.reviewText!;
    }
    return '无';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '作业详情',
      titleFontSize: 24,
      titleFontWeight: FontWeight.w500,
      width: 428,
      contentPadding: EdgeInsets.fromLTRB(ui(24), ui(60), ui(24), ui(20)),
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '确认',
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
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
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              _SubjectTag(subject: data.subject),
              SizedBox(width: ui(8)),
              _DetailStatusTag(label: _statusLabel),
            ],
          ),
          SizedBox(height: ui(12)),
          _DetailKeyValueRow(label: '发布老师', value: data.teacher),
          SizedBox(height: ui(12)),
          _DetailKeyValueRow(label: '截止时间', value: data.deadline),
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '作业要求',
            children: [_DetailGrayLine(text: _requirement, primary: true)],
          ),
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '提交情况',
            children: [
              _DetailGrayLine(
                text: data.submittedFile?.isNotEmpty == true
                    ? data.submittedFile!
                    : '尚未提交',
                primary: data.submittedFile?.isNotEmpty == true,
              ),
              if (_submittedAt != null) ...[
                SizedBox(height: ui(6)),
                _DetailGrayLine(text: '提交时间：${_submittedAt!}'),
              ],
            ],
          ),
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '教师反馈',
            children: [
              _DetailGrayLine(text: _feedback, primary: _feedback != '无'),
            ],
          ),
        ],
      ),
    );
  }
}

String _subjectLabelOf(_HomeworkSubject s) => switch (s) {
  _HomeworkSubject.music => '乐理',
  _HomeworkSubject.vocal => '声乐',
  _HomeworkSubject.vocalRed => '声乐',
};

class _DetailStatusTag extends StatelessWidget {
  const _DetailStatusTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg) = switch (label) {
      '已提交' || '已批阅' => (_kSubmittedGreenBg, _kSubmittedGreen),
      '已逾期' => (_kOverdueRedBg, _kOverdueRed),
      _ => (_kPendingOrangeBg, _kPendingOrange),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _DetailKeyValueRow extends StatelessWidget {
  const _DetailKeyValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _DetailGrayPanel extends StatelessWidget {
  const _DetailGrayPanel({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          ...children,
        ],
      ),
    );
  }
}

class _DetailGrayLine extends StatelessWidget {
  const _DetailGrayLine({required this.text, this.primary = true});
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(12),
        color: primary ? _kTextDark : _kTextHint,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }
}

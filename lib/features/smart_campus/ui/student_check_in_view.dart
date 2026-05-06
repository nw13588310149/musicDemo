// =============================================================================
// 学生端「课堂签到」独立页面
//
// 入口：学生 dashboard 快捷区「课堂签到」按钮 → controller.openCheckIn()
//      → mainView == checkIn + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变；左 32 返回；居中 "课堂签到" /
//      "教学周第 12 周"；右上 "缺勤未补签：1次"（1次 #FF323C）；远右 32 高
//      "历史记录" 按钮
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

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';

import '../../../core/widgets/app_text.dart';
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

class StudentCheckInView extends StatelessWidget {
  const StudentCheckInView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckInBanner(
            week: 12,
            unsignedCount: 1,
            onBack: onBack,
            onOpenHistory: () {},
          ),
          SizedBox(height: ui(16)),
          _StatsRow(stats: _kDemoStats),
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
                      title: '2026年4月2日 周三',
                      items: _kDemoTodayClasses,
                    ),
                    SizedBox(height: ui(20)),
                    _SectionTitle('签到操作'),
                    SizedBox(height: ui(12)),
                    _CheckInActionPanel(data: _kDemoCheckInAction),
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
                          title: '2026年4月2日 周三',
                          items: _kDemoTodayClasses,
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
                        _CheckInActionPanel(data: _kDemoCheckInAction),
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
          _RecentRecordsGrid(records: _kDemoRecentRecords),
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 banner
// =============================================================================

class _CheckInBanner extends StatelessWidget {
  const _CheckInBanner({
    required this.week,
    required this.unsignedCount,
    required this.onBack,
    required this.onOpenHistory,
  });

  final int week;
  final int unsignedCount;
  final VoidCallback onBack;
  final VoidCallback onOpenHistory;

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
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          // 居中标题 + 副标题
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  '课堂签到',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(4)),
                AppText(
                  '教学周第 $week 周',
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
          // 缺勤未补签：左侧紧贴 "历史记录" 按钮
          Positioned(
            right: ui(120),
            top: ui(21),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
                children: [
                  const TextSpan(
                    text: '缺勤未补签：',
                    style: TextStyle(color: _kTextDark),
                  ),
                  TextSpan(
                    text: '$unsignedCount次',
                    style: const TextStyle(color: _kAttendRed),
                  ),
                ],
              ),
            ),
          ),
          // 历史记录按钮
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
                    AppText(
                      '历史记录',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
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
          AppText(
            item.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              color: item.valueColor,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
          AppText(
            item.label,
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
// 今日课程面板（左侧 340 宽）
// =============================================================================

class _TodayClassData {
  const _TodayClassData({
    required this.timeStart,
    required this.timeEnd,
    required this.studentName,
    required this.duration,
    required this.location,
    required this.status, // ended / inProgress
  });

  final String timeStart;
  final String timeEnd;
  final String studentName;
  final String duration;
  final String location;
  final _ClassStatus status;
}

enum _ClassStatus { ended, inProgress }

class _TodayClassesPanel extends StatelessWidget {
  const _TodayClassesPanel({required this.title, required this.items});

  final String title;
  final List<_TodayClassData> items;

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
          AppText(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextSection,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(12)),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: ui(8)),
            _TodayClassCard(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({required this.item});

  final _TodayClassData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEnded = item.status == _ClassStatus.ended;
    return Container(
      width: double.infinity,
      height: ui(104),
      decoration: BoxDecoration(
        color: isEnded ? _kInnerGray : const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          // 状态角标
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(68),
              height: ui(22),
              decoration: BoxDecoration(
                color: isEnded ? _kEndedTagBg : _kPurpleSoftBg,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(ui(12)),
                  bottomLeft: Radius.circular(ui(12)),
                ),
              ),
              alignment: Alignment.center,
              child: AppText(
                isEnded ? '已结束' : '进行中',
                style: TextStyle(
                  fontSize: ui(12),
                  color: isEnded ? _kTextHint : _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          // 时间段
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
                    text: '${item.timeStart} ',
                    style: const TextStyle(color: _kTextSection),
                  ),
                  const TextSpan(
                    text: '- ',
                    style: TextStyle(color: _kTextHint),
                  ),
                  TextSpan(
                    text: item.timeEnd,
                    style: const TextStyle(color: _kTextSection),
                  ),
                ],
              ),
            ),
          ),
          // 头像
          Positioned(
            left: ui(16),
            top: ui(48),
            child: _Avatar(seed: item.studentName, size: ui(40)),
          ),
          // 学生信息
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
                    AppText(
                      item.studentName,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    _CourseGreenTag(),
                    SizedBox(width: ui(4)),
                    _SmallClassTag(palette: _TagPalette.green),
                  ],
                ),
                SizedBox(height: ui(4)),
                AppText(
                  '${item.duration}·${item.location}',
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
        ],
      ),
    );
  }
}

// =============================================================================
// 签到操作面板（614×274）
// =============================================================================

class _CheckInActionData {
  const _CheckInActionData({
    required this.periodLabel, // "第3节"
    required this.timeRange, // "10:00-10:45"
    required this.studentName, // "郝江"
    required this.duration, // "45分钟"
    required this.location, // "艺术楼 报告厅"
    required this.fenceLabel, // "已在「艺术楼」电子围栏范围"
    required this.method, // "按键打卡"
    required this.teacherStartTime, // "15:08:12"
    required this.teacherEndTime, // "15:58:12"
    required this.canCheckIn, // 是否允许"上课签到"
    required this.canCheckOut, // 是否允许"下课签到"
  });

  final String periodLabel;
  final String timeRange;
  final String studentName;
  final String duration;
  final String location;
  final String fenceLabel;
  final String method;
  final String teacherStartTime;
  final String teacherEndTime;
  final bool canCheckIn;
  final bool canCheckOut;
}

class _CheckInActionPanel extends StatelessWidget {
  const _CheckInActionPanel({required this.data});

  final _CheckInActionData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
      child: Stack(
        children: [
          // 标题
          Positioned(
            left: ui(12),
            top: ui(12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(16),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
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
          // 灰底面板
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
                // 电子围栏角标
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
                    child: AppText(
                      data.fenceLabel,
                      style: TextStyle(
                        fontSize: ui(10),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                // 学生信息
                Positioned(
                  left: ui(12),
                  top: ui(11),
                  child: Row(
                    children: [
                      _Avatar(seed: data.studentName, size: ui(40)),
                      SizedBox(width: ui(10)),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(
                                data.studentName,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: ui(4)),
                              _CourseGreenTag(),
                              SizedBox(width: ui(4)),
                              _SmallClassTag(palette: _TagPalette.green),
                            ],
                          ),
                          SizedBox(height: ui(4)),
                          AppText(
                            '${data.duration}·${data.location}',
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
                    ],
                  ),
                ),
                // 教师指定的打卡方式
                Positioned(
                  left: ui(12),
                  top: ui(64),
                  child: Row(
                    children: [
                      AppText(
                        '教师指定的打卡方式：',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: ui(36)),
                      AppText(
                        data.method,
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
                // 教师需先签，学生后签
                Positioned(
                  left: ui(12),
                  top: ui(89),
                  child: AppText(
                    '教师需先签，学生后签',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
                // 时间轴：教师上课签 + 教师下课签
                Positioned(
                  left: ui(170),
                  top: ui(89),
                  right: ui(12),
                  child: _TeacherSignTimeline(
                    startTime: data.teacherStartTime,
                    endTime: data.teacherEndTime,
                  ),
                ),
                // 底部签到按钮
                Positioned(
                  left: ui(12),
                  bottom: ui(0),
                  right: ui(12),
                  child: _CheckInButtons(
                    canCheckIn: data.canCheckIn,
                    canCheckOut: data.canCheckOut,
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
                  AppText(
                    '教师上课签',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
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
                  AppText(
                    '教师下课签',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
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
          AppText(
            time,
            style: TextStyle(
              fontSize: ui(12),
              color: _kPurple,
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

class _CheckInButtons extends StatelessWidget {
  const _CheckInButtons({required this.canCheckIn, required this.canCheckOut});

  final bool canCheckIn;
  final bool canCheckOut;

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
              onTap: () {},
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: _ActionButton(
              label: '下课签到',
              enabled: canCheckOut,
              onTap: () {},
            ),
          ),
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
            AppText(
              label,
              style: TextStyle(
                fontSize: ui(16),
                color: foreground,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
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
  const _RecentRecordsGrid({required this.records});

  final List<_RecentRecordData> records;

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
            child: _RecentRecordCard(data: r),
          ),
      ],
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.data});

  final _RecentRecordData data;

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
                child: AppText(
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
                child: AppText(
                  isAbsent ? '缺勤' : '正常',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
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
                          AppText(
                            data.studentName,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          _CourseTag(palette: data.tagPalette),
                          _SmallClassTag(palette: data.tagPalette),
                        ],
                      )
                    else
                      AppText(
                        data.studentName,
                        style: TextStyle(
                          fontSize: ui(14),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    SizedBox(height: ui(4)),
                    AppText(
                      '${data.duration}·${data.location}',
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
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: ui(16),
                  color: const Color(0xFF1C274C),
                ),
                SizedBox(width: ui(8)),
                AppText(
                  '申请补签',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: Colors.black,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ] else
            _AttendStatsRow(
              startCard: data.startCard,
              endCard: data.endCard,
              method: data.method,
            ),
          SizedBox(height: ui(8)),
          AppText(
            '备注：${data.note}',
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
        AppText(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        AppText(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
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
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kCourseTagGreenBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: AppText(
        '古筝课',
        style: TextStyle(
          fontSize: ui(11),
          color: _kStatusGreen,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
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
      child: AppText(
        '古筝课',
        style: TextStyle(
          fontSize: isGreen ? ui(11) : ui(12),
          color: isGreen ? _kStatusGreen : _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
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
          AppText(
            '小课',
            style: TextStyle(
              fontSize: ui(11),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
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
      child: AppText(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w500,
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
    return AppText(
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

const List<_StatItem> _kDemoStats = [
  _StatItem(value: '6', label: '小课应签课次'),
  _StatItem(value: '6', label: '大课一键入册'),
  _StatItem(value: '86.5', label: '小课打卡（合计）'),
  _StatItem(value: '4', label: '迟到'),
  _StatItem(value: '96.5%', label: '小课准时率', valueColor: _kPurple),
];

const List<_TodayClassData> _kDemoTodayClasses = [
  _TodayClassData(
    timeStart: '07:00',
    timeEnd: '07:45',
    studentName: '陈江凯',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    status: _ClassStatus.ended,
  ),
  _TodayClassData(
    timeStart: '08:35',
    timeEnd: '09:25',
    studentName: '郝江',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    status: _ClassStatus.inProgress,
  ),
];

const _CheckInActionData _kDemoCheckInAction = _CheckInActionData(
  periodLabel: '第3节',
  timeRange: '10:00-10:45',
  studentName: '郝江',
  duration: '45分钟',
  location: '艺术楼 报告厅',
  fenceLabel: '已在「艺术楼」电子围栏范围',
  method: '按键打卡',
  teacherStartTime: '15:08:12',
  teacherEndTime: '15:58:12',
  canCheckIn: true,
  canCheckOut: false,
);

const List<_RecentRecordData> _kDemoRecentRecords = [
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.normal,
    studentName: '郝江',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.green,
    tagInline: true,
    startCard: '-',
    endCard: '-',
    method: '签到',
    note: '教师一键签到入册',
  ),
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.absent,
    studentName: '陈江凯',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.green,
    tagInline: true,
    startCard: null,
    endCard: null,
    method: null,
    note: '未检测到上下课打卡，记为缺勤',
  ),
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.normal,
    studentName: '李梓燕',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.green,
    tagInline: true,
    startCard: '08:00:02',
    endCard: '08:55:02',
    method: '扫码',
    note: '无',
  ),
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.normal,
    studentName: '郝江',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.yellow,
    tagInline: false,
    startCard: '/',
    endCard: '/',
    method: '教师一键签到',
    note: '教师一键签到入册',
  ),
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.normal,
    studentName: '李梓燕',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.yellow,
    tagInline: false,
    startCard: '08:00:02',
    endCard: '08:55:02',
    method: '扫码',
    note: '无',
  ),
  _RecentRecordData(
    date: '2026-03-29',
    status: _AttendanceStatus.normal,
    studentName: '李梓燕',
    duration: '45分钟',
    location: '艺术楼 报告厅',
    tagPalette: _TagPalette.yellow,
    tagInline: false,
    startCard: '08:00:02',
    endCard: '08:55:02',
    method: '扫码',
    note: '无',
  ),
];

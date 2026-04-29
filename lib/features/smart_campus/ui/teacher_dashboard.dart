import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import '../data/smart_campus_dashboard_data.dart';
import '../state/smart_campus_state.dart';

/// 任课老师 / 班主任端的智慧校园首页布局。
///
/// 与学生端 / 管理员端走的是不同的视觉系统：
/// - 顶部 6 张统计卡（4 个数值 + 「本周课时」 + 紫色「下一节」）
/// - 中间为 `#EFF3FC` 浅紫面板，承载 8 宫功能矩阵
/// - 右栏 256 宽白底面板：头像 + 在岗胶囊 + 主项/副项/带班 +
///   任课老师 / 班主任 tab 切换 + 通知列表
///
/// `selectedRole` 来自全局 `smartCampusControllerProvider`，但 tab 切换在本组件内
/// 用本地状态维护，不会通过 `selectRole` 改写全局身份（避免普通教师没有
/// 「班主任」可用身份导致 tab 点击没反应）。管理员可通过外部继续切换其他角色。
class TeacherDashboardLayout extends StatefulWidget {
  const TeacherDashboardLayout({
    super.key,
    required this.selectedRole,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.roleSwitcher,
  });

  final SmartCampusRole selectedRole;
  final String shellDisplayName;
  final String avatarUrl;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;

  /// 班主任专属：进入「班级工作台」三 Tab 页面（与学生「我的班级」分开）。
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;

  /// 管理员等多身份用户使用的悬浮身份切换器；教师/班主任传 null。
  final Widget? roleSwitcher;

  @override
  State<TeacherDashboardLayout> createState() => _TeacherDashboardLayoutState();
}

class _TeacherDashboardLayoutState extends State<TeacherDashboardLayout> {
  late SmartCampusRole _localTab;

  @override
  void initState() {
    super.initState();
    _localTab = _coerceRole(widget.selectedRole);
  }

  @override
  void didUpdateWidget(covariant TeacherDashboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      _localTab = _coerceRole(widget.selectedRole);
    }
  }

  // 仅允许 tab 在 teacher / headTeacher 之间切换；其他角色容错回退到 teacher。
  SmartCampusRole _coerceRole(SmartCampusRole role) {
    if (role == SmartCampusRole.teacher ||
        role == SmartCampusRole.headTeacher) {
      return role;
    }
    return SmartCampusRole.teacher;
  }

  void _selectTab(SmartCampusRole role) {
    if (role != SmartCampusRole.teacher &&
        role != SmartCampusRole.headTeacher) {
      return;
    }
    if (_localTab == role) {
      return;
    }
    setState(() {
      _localTab = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(_localTab);

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.roleSwitcher != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.roleSwitcher,
                  ),
                  SizedBox(height: ui(12)),
                ],
                _TeacherMainColumn(
                  data: data,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  onOpenMyClass: widget.onOpenMyClass,
                  onOpenClassWorkbench: widget.onOpenClassWorkbench,
                  onOpenMySchedule: widget.onOpenMySchedule,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  width: cw,
                  selectedTab: _localTab,
                  onTabSelected: _selectTab,
                  shellDisplayName: widget.shellDisplayName,
                  avatarUrl: widget.avatarUrl,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _TeacherMainColumn(
                data: data,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                onOpenMyClass: widget.onOpenMyClass,
                onOpenClassWorkbench: widget.onOpenClassWorkbench,
                onOpenMySchedule: widget.onOpenMySchedule,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                width: sidebarWidth,
                selectedTab: _localTab,
                onTabSelected: _selectTab,
                shellDisplayName: widget.shellDisplayName,
                avatarUrl: widget.avatarUrl,
                fillHeight: true,
              ),
            ),
            if (widget.roleSwitcher != null)
              Positioned(
                top: ui(6),
                right: sidebarWidth + ui(8),
                child: widget.roleSwitcher!,
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 主区：顶部统计行 + 中间浅紫面板（功能矩阵）
// =============================================================================

class _TeacherMainColumn extends StatelessWidget {
  const _TeacherMainColumn({
    required this.data,
    required this.width,
    required this.fillRemaining,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
  });

  final SmartCampusDashboardData data;
  final double width;
  final bool fillRemaining;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final actionPanel = _TeacherActionPanel(
      data: data,
      onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      onOpenMyClass: onOpenMyClass,
      onOpenClassWorkbench: onOpenClassWorkbench,
      onOpenMySchedule: onOpenMySchedule,
    );

    // 任课老师：当前课程 + 今日课表；班主任：当前事项 + 班务
    Widget bottomSection({required bool fill}) {
      if (data.role == SmartCampusRole.headTeacher) {
        return _HeadTeacherBoardSection(
          onOpenWorkbench: onOpenClassWorkbench,
          fillRemaining: fill,
        );
      }
      return _TeacherScheduleSection(
        onOpenMySchedule: onOpenMySchedule,
        fillRemaining: fill,
      );
    }

    if (fillRemaining) {
      // 父级 (Stack > Positioned(top:0,bottom:0)) 提供了有界高度。
      // 让底部双卡 Expanded 撑满剩余空间。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          _TeacherStatRow(stats: data.stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          Expanded(child: bottomSection(fill: true)),
        ],
      );
    }

    // 紧凑模式（compact）：父级高度无界，整个主列交给滚动容器承载。
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherStatRow(stats: data.stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          bottomSection(fill: false),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _TeacherStatRow extends StatelessWidget {
  const _TeacherStatRow({required this.stats, required this.width});

  final List<SmartCampusStatCardData> stats;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    final ui = DashboardScaleScope.of(context).ui;
    // 父级（Column / ScrollView）纵向高度通常无界；这里先用 SizedBox 给一个
    // 有界高度（68），Row 内部就可以安全使用 stretch 让 6 张卡等高铺满。
    return SizedBox(
      width: width.isFinite && width > 0 ? width : null,
      height: ui(68),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            Expanded(child: _TeacherStatCard(item: stats[i])),
          ],
        ],
      ),
    );
  }
}

class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard({required this.item});

  final SmartCampusStatCardData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    // 紫色「下一节 15:30」卡 / 班主任端「待办 9」卡：紫字 24px 在上、灰色 12px 标签在下。
    final isNextLesson = item.label == '下一节' || item.label == '待办';
    // 「本周课时 / 周五」卡 / 班主任端「关注学生 / 周五」卡：黑色 16px 在上、灰色 12px 标签在下。
    final isWeekly = item.label == '本周课时' || item.label == '关注学生';

    Widget value;
    if (isNextLesson) {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(24),
          color: const Color(0xFF8741FF),
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
    } else if (isWeekly) {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(16),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
      );
    } else {
      value = Text(
        item.value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(24),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.07),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          value,
          SizedBox(height: ui(6)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF6D6B75),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionPanel extends StatelessWidget {
  const _TeacherActionPanel({
    required this.data,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
  });

  final SmartCampusDashboardData data;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final VoidCallback onOpenMySchedule;

  VoidCallback? _onTapForLabel(String label) {
    switch (label) {
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '我的班级':
        return onOpenMyClass;
      case '班级工作台':
        // 班主任专属入口：进入独立三 Tab 工作台（概况 / 学生管理 / 成绩），
        // 与学生「我的班级」简版页面分开，避免 selectedRole 误判路由到学生页。
        return onOpenClassWorkbench;
      case '授课课表':
        return onOpenMySchedule;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 一行 5 个；超过 5 个的项目自动进入下一行（教师端目前共 8 项 -> 5 + 3）。
    const cross = 5;
    final actions = data.actions;
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += cross) {
      final rowItems = <Widget>[];
      for (var j = 0; j < cross; j++) {
        if (j > 0) rowItems.add(SizedBox(width: ui(12)));
        final idx = i + j;
        if (idx < actions.length) {
          final item = actions[idx];
          rowItems.add(
            Expanded(
              child: _TeacherActionTile(
                item: item,
                onTap: _onTapForLabel(item.label),
              ),
            ),
          );
        } else {
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: ui(20)));
      }
      rows.add(
        SizedBox(
          height: ui(86),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowItems,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

class _TeacherActionTile extends StatelessWidget {
  const _TeacherActionTile({required this.item, this.onTap});

  final SmartCampusQuickActionData item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final box = ui(38);

    Widget iconBox;
    if (item.imagePath != null) {
      iconBox = Image.asset(
        item.imagePath!,
        width: box,
        height: box,
        fit: BoxFit.contain,
      );
    } else {
      iconBox = Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: item.background,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Icon(item.icon, size: ui(22), color: item.foreground),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(ui(12)),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              iconBox,
              if (item.badge > 0)
                Positioned(
                  right: ui(-10),
                  top: ui(-4),
                  child: Container(
                    constraints: BoxConstraints(minWidth: ui(24)),
                    height: ui(16),
                    padding: EdgeInsets.symmetric(horizontal: ui(5)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF04545),
                      borderRadius: BorderRadius.circular(ui(20)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.badge > 99 ? '99+' : '${item.badge}+',
                      style: TextStyle(
                        fontSize: ui(9),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 右栏：头像 + 在岗 + 标签 + 主项/副项/带班 + Tab + 通知
// =============================================================================

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.data,
    required this.width,
    required this.selectedTab,
    required this.onTabSelected,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.fillHeight,
  });

  final SmartCampusDashboardData data;
  final double width;
  final SmartCampusRole selectedTab;
  final ValueChanged<SmartCampusRole> onTabSelected;
  final String shellDisplayName;
  final String avatarUrl;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final card = Container(
      width: width.isFinite && width > 0 ? width : ui(256),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.06),
            blurRadius: ui(12),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeacherProfileBlock(
              data: data,
              shellDisplayName: shellDisplayName,
              avatarUrl: avatarUrl,
            ),
            SizedBox(height: ui(20)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(20)),
              child: _TeacherRoleTabs(
                selected: selectedTab,
                onChanged: onTabSelected,
              ),
            ),
            SizedBox(height: ui(28)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              child: Text(
                '通知',
                style: TextStyle(
                  fontSize: ui(16),
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            if (fillHeight)
              Expanded(
                child: _TeacherNoticeList(
                  notices: data.notices,
                  scrollable: true,
                ),
              )
            else
              _TeacherNoticeList(notices: data.notices, scrollable: false),
            SizedBox(height: ui(16)),
          ],
        ),
      ),
    );
    return card;
  }
}

class _TeacherProfileBlock extends StatelessWidget {
  const _TeacherProfileBlock({
    required this.data,
    required this.shellDisplayName,
    required this.avatarUrl,
  });

  final SmartCampusDashboardData data;
  final String shellDisplayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final profile = data.profile;
    final displayName = shellDisplayName.isNotEmpty
        ? shellDisplayName
        : profile.name;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), ui(24), ui(20), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TeacherAvatar(avatarUrl: avatarUrl, size: ui(72)),
                  SizedBox(width: ui(12)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: ui(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(16),
                                    color: const Color(0xFF0B081A),
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              SizedBox(width: ui(6)),
                              _TeacherStatusChip(label: profile.title),
                            ],
                          ),
                          SizedBox(height: ui(6)),
                          Text(
                            profile.organization,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: const Color(0xFF6D6B75),
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(14)),
              _TeacherDetailLines(lines: profile.detailLines),
            ],
          ),
          // 头像右下方的「老师」黄色胶囊
          Positioned(
            left: ui(58),
            top: ui(62),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(7),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEE49),
                borderRadius: BorderRadius.circular(ui(10)),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                profile.badgeLabel,
                style: TextStyle(
                  fontSize: ui(11),
                  color: const Color(0xFF0B081A),
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

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({required this.avatarUrl, required this.size});

  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget child;
    if (avatarUrl.isNotEmpty) {
      child = Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(ui),
      );
    } else {
      child = _fallback(ui);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: child),
    );
  }

  Widget _fallback(double Function(double) ui) {
    return Container(
      color: const Color(0xFFEAE5FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(36),
        color: const Color(0xFF8F63FF),
      ),
    );
  }
}

class _TeacherStatusChip extends StatelessWidget {
  const _TeacherStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: const Color(0xFFF3F2F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: const BoxDecoration(
              color: Color(0xFF12C58A),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDetailLines extends StatelessWidget {
  const _TeacherDetailLines({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) ...[
          _TeacherDetailLine(line: line),
          SizedBox(height: ui(4)),
        ],
      ],
    );
  }
}

class _TeacherDetailLine extends StatelessWidget {
  const _TeacherDetailLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final idx = line.indexOf('：');
    final label = idx >= 0 ? line.substring(0, idx + 1) : '';
    final value = idx >= 0 ? line.substring(idx + 1) : line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabs extends StatelessWidget {
  const _TeacherRoleTabs({required this.selected, required this.onChanged});

  final SmartCampusRole selected;
  final ValueChanged<SmartCampusRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _TeacherRoleTabButton(
            label: '任课老师',
            active: selected == SmartCampusRole.teacher,
            onTap: () => onChanged(SmartCampusRole.teacher),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _TeacherRoleTabButton(
            label: '班主任',
            active: selected == SmartCampusRole.headTeacher,
            onTap: () => onChanged(SmartCampusRole.headTeacher),
          ),
        ),
      ],
    );
  }
}

class _TeacherRoleTabButton extends StatelessWidget {
  const _TeacherRoleTabButton({
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
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : const Color(0xFF0B081A),
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TeacherNoticeList extends StatelessWidget {
  const _TeacherNoticeList({required this.notices, required this.scrollable});

  final List<SmartCampusNoticeData> notices;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final children = <Widget>[];
    for (var i = 0; i < notices.length; i++) {
      if (i > 0) children.add(SizedBox(height: ui(8)));
      children.add(_TeacherNoticeCard(item: notices[i]));
    }
    final list = Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
    if (scrollable) {
      return SingleChildScrollView(child: list);
    }
    return list;
  }
}

class _TeacherNoticeCard extends StatelessWidget {
  const _TeacherNoticeCard({required this.item});

  final SmartCampusNoticeData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(10), ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(right: ui(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(4),
                        vertical: ui(2),
                      ),
                      decoration: BoxDecoration(
                        color: item.tagBackground,
                        borderRadius: BorderRadius.circular(ui(4)),
                      ),
                      child: Text(
                        item.tag,
                        style: TextStyle(
                          fontSize: ui(10),
                          color: item.tagForeground,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: const Color(0xFF0B081A),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(4)),
                Text(
                  item.time,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFCECED1),
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(6),
              height: ui(6),
              decoration: BoxDecoration(
                color: item.unread
                    ? const Color(0xFFFF323C)
                    : const Color(0xFFCECED1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 当前课程 + 今日课表（白色双卡区）
//
// 视觉与学生端 `_StudentDualSection` 保持一致：
//   - 标题在白卡之外（"当前课程" / "今日课表"），「今日课表」右侧带「查看完整课表 >」入口
//   - 标题→白卡间距 ui(20)
//   - 白卡 padding 12 / radius 16 / 浅阴影
//   - 白卡内部为灰底（#F5F6FA, radius 12）子卡，子卡右上 L 型角标承载状态色
//   - 子卡时段用 Text.rich 三段式（起 #1A1A1A 600 / "- " #B6B5BB 600 / 止 #0B081A 600）
//   - 老师行：渐变首字头像 + 姓名 14 600 + 课程标签（颜色背景）+ 圆点+大小课白底标签
//   - 数据为空时白卡保留，并展示占位文案
// =============================================================================

class _LessonRowData {
  const _LessonRowData({
    required this.avatarSeed,
    required this.teacherName,
    required this.courseName,
    required this.courseColor,
    required this.courseBg,
    required this.tag,
    required this.tagDotColor,
    required this.hint,
  });

  final String avatarSeed;
  final String teacherName;
  final String courseName;
  final Color courseColor;
  final Color courseBg;
  final String tag;
  final Color tagDotColor;
  final String hint;
}

class _LessonScheduleData {
  const _LessonScheduleData({
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.teachers,
  });

  final String time;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final List<_LessonRowData> teachers;
}

// 教师端示例数据（与学生端示例配色一致）。
// TODO：接入真实接口后改由 dashboard data + controller 注入。
const List<_LessonRowData> _kCurrentLessonTeachers = [
  _LessonRowData(
    avatarSeed: '贾',
    teacherName: '贾恩海',
    courseName: '视唱课',
    courseColor: Color(0xFF8741FF),
    courseBg: Color(0xFFEAE5FF),
    tag: '大课',
    tagDotColor: Color(0xFFA773FF),
    hint: '45分钟·艺术楼 报告厅',
  ),
  _LessonRowData(
    avatarSeed: '李',
    teacherName: '李泽芮',
    courseName: '竹笛课',
    courseColor: Color(0xFF0CAC40),
    courseBg: Color(0xFFDFFCF0),
    tag: '小课',
    tagDotColor: Color(0xFF0CAC40),
    hint: '45分钟·音乐体验课',
  ),
];

const _LessonScheduleData _kCurrentLesson = _LessonScheduleData(
  time: '07:00 - 07:45',
  status: '正在进行',
  statusColor: Color(0xFF0B081A),
  statusBg: Color(0xFFEAE5FF),
  teachers: _kCurrentLessonTeachers,
);

const List<_LessonScheduleData> _kTodayLessons = [
  _LessonScheduleData(
    time: '08:00 - 08:30',
    status: '即将开始',
    statusColor: Color(0xFF0B081A),
    statusBg: Color(0xFFEAE5FF),
    teachers: [
      _LessonRowData(
        avatarSeed: '陈',
        teacherName: '陈江凯',
        courseName: '视唱课',
        courseColor: Color(0xFF8741FF),
        courseBg: Color(0xFFEAE5FF),
        tag: '大课',
        tagDotColor: Color(0xFFA773FF),
        hint: '45分钟·艺术楼 报告厅',
      ),
      _LessonRowData(
        avatarSeed: '李',
        teacherName: '李梓燕',
        courseName: '竹笛课',
        courseColor: Color(0xFF0CAC40),
        courseBg: Color(0xFFDFFCF0),
        tag: '小课',
        tagDotColor: Color(0xFF0CAC40),
        hint: '45分钟·音乐体验课',
      ),
    ],
  ),
  _LessonScheduleData(
    time: '07:00 - 07:45',
    status: '已结束',
    statusColor: Color(0xFFB6B5BB),
    statusBg: Color(0xFFE6E9F1),
    teachers: [
      _LessonRowData(
        avatarSeed: '郝',
        teacherName: '郝江',
        courseName: '竹笛课',
        courseColor: Color(0xFF0CAC40),
        courseBg: Color(0xFFDFFCF0),
        tag: '小课',
        tagDotColor: Color(0xFF0CAC40),
        hint: '45分钟·艺术楼 报告厅',
      ),
    ],
  ),
];

class _TeacherScheduleSection extends StatelessWidget {
  const _TeacherScheduleSection({
    this.onOpenMySchedule,
    this.fillRemaining = false,
  });

  final VoidCallback? onOpenMySchedule;

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
          title,
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        );

    Widget scheduleTitle() => Row(
          children: [
            Text(
              '今日课表',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onOpenMySchedule,
              borderRadius: BorderRadius.circular(ui(6)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(2),
                  vertical: ui(2),
                ),
                child: Text(
                  '查看完整课表 >',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF6D6B75),
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          // 紧凑模式：标题→白卡顺序堆叠（不撑满，沿用 SingleChildScrollView 滚动）。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionTitle('当前课程'),
              SizedBox(height: ui(20)),
              const _CurrentLessonPanel(lesson: _kCurrentLesson),
              SizedBox(height: ui(20)),
              scheduleTitle(),
              SizedBox(height: ui(20)),
              const _TodaySchedulePanel(lessons: _kTodayLessons),
            ],
          );
        }

        // 宽屏：标题行 + 双卡行
        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: _CurrentLessonPanel(lesson: _kCurrentLesson),
            ),
            SizedBox(width: ui(16)),
            const Expanded(
              child: _TodaySchedulePanel(lessons: _kTodayLessons),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillRemaining ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sectionTitle('当前课程')),
                SizedBox(width: ui(16)),
                Expanded(child: scheduleTitle()),
              ],
            ),
            SizedBox(height: ui(20)),
            if (fillRemaining)
              // 父级有界高度：白卡撑满剩余高度
              Expanded(child: cardsRow)
            else
              // 父级高度无界：用 IntrinsicHeight 让两侧等高
              IntrinsicHeight(child: cardsRow),
          ],
        );
      },
    );
  }
}

class _CurrentLessonPanel extends StatelessWidget {
  const _CurrentLessonPanel({required this.lesson});

  final _LessonScheduleData? lesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: lesson == null
          ? const _LessonEmptyHint(text: '暂无当前课程')
          : _LessonScheduleCard(data: lesson!),
    );
  }
}

class _TodaySchedulePanel extends StatelessWidget {
  const _TodaySchedulePanel({required this.lessons});

  final List<_LessonScheduleData> lessons;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: lessons.isEmpty
          ? const _LessonEmptyHint(text: '今日暂无课表')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lessons.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(8)),
                  _LessonScheduleCard(data: lessons[i]),
                ],
              ],
            ),
    );
  }
}

class _LessonEmptyHint extends StatelessWidget {
  const _LessonEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(36)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: ui(28),
            color: const Color(0xFFB6B5BB),
          ),
          SizedBox(height: ui(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF9A99A1),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonScheduleCard extends StatelessWidget {
  const _LessonScheduleCard({required this.data});

  final _LessonScheduleData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(12);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: _splitTime(data.time, ui)),
              ),
              SizedBox(height: ui(14)),
              for (var i = 0; i < data.teachers.length; i++) ...[
                _LessonTeacherRow(data: data.teachers[i]),
                if (i != data.teachers.length - 1) SizedBox(height: ui(14)),
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            height: ui(22),
            padding: EdgeInsets.symmetric(
              horizontal: ui(10),
              vertical: ui(2),
            ),
            decoration: BoxDecoration(
              color: data.statusBg,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              data.status,
              style: TextStyle(
                fontSize: ui(12),
                color: data.statusColor,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _splitTime(String time, double Function(double) ui) {
    final parts = time.split('-');
    if (parts.length != 2) {
      return [
        TextSpan(
          text: time,
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ];
    }
    final start = parts[0].trim();
    final end = parts[1].trim();
    return [
      TextSpan(
        text: '$start ',
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: '- ',
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFFB6B5BB),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      TextSpan(
        text: end,
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF0B081A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
}

class _LessonTeacherRow extends StatelessWidget {
  const _LessonTeacherRow({required this.data});

  final _LessonRowData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LessonSeedAvatar(seed: data.avatarSeed, size: ui(40)),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      data.teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: const Color(0xFF0B081A),
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Container(
                    height: ui(16),
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: data.courseBg,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      data.courseName,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: data.courseColor,
                        fontWeight: FontWeight.w400,
                        height: 14 / 11,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Container(
                    height: ui(16),
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(4),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(4)),
                      border: Border.all(color: const Color(0xFFF3F2F3)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: ui(6),
                          height: ui(6),
                          decoration: BoxDecoration(
                            color: data.tagDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Text(
                          data.tag,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: const Color(0xFF0B081A),
                            fontWeight: FontWeight.w400,
                            height: 14 / 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                data.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFFB6B5BB),
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 与学生端 `_SeedAvatar` 视觉一致的渐变首字头像。
/// 各取首字 `seed.codeUnitAt(0)` 在 5 套调色盘中循环。
class _LessonSeedAvatar extends StatelessWidget {
  const _LessonSeedAvatar({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palettes = <List<Color>>[
      const [Color(0xFFFFD9E3), Color(0xFFFFBFD0)],
      const [Color(0xFFD8E4FF), Color(0xFFB9D0FF)],
      const [Color(0xFFE8DCFF), Color(0xFFD5BCFF)],
      const [Color(0xFFE6FFF6), Color(0xFFB7F0DC)],
      const [Color(0xFFFFF0D9), Color(0xFFFFD09B)],
    ];
    final index = seed.isEmpty ? 0 : (seed.codeUnitAt(0) % palettes.length);
    final palette = palettes[index];
    final initial = seed.isEmpty ? '?' : seed.substring(0, 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          color: const Color(0xFF5B536D),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 班主任端：当前事项 + 班务（白色双卡区）
//
// 与「当前课程 / 今日课表」共用同一外层布局（标题行 + 白卡 + Expanded 撑满），
// 子卡视觉简化为 时间(Barlow 18 600 三段式) + 标题 + 紫色标签：
//   - 白卡 padding 12 / radius 16 / 浅阴影；子卡灰底 #F5F6FA / radius 12
//   - 「班务」标题右侧带「班级工作台 >」入口
// =============================================================================

class _BoardItemData {
  const _BoardItemData({
    required this.time,
    required this.title,
    required this.tag,
    required this.tagForeground,
    required this.tagBackground,
  });

  final String time;
  final String title;
  final String tag;
  final Color tagForeground;
  final Color tagBackground;
}

const Color _kBoardTagPurple = Color(0xFF8741FF);
const Color _kBoardTagPurpleSoft = Color(0xFFDAD2FF);

const List<_BoardItemData> _kHeadTeacherCurrentItems = [
  _BoardItemData(
    time: '07:00 - 07:45',
    title: '班会材料·校考志愿说明',
    tag: '班会',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '07:50 - 08:35',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
];

const List<_BoardItemData> _kHeadTeacherBoardItems = [
  _BoardItemData(
    time: '07:00 - 07:45',
    title: '班会材料·校考志愿说明',
    tag: '班会',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '09:00 - 09:45',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
  _BoardItemData(
    time: '10:00 - 10:45',
    title: '校考志愿说明演讲',
    tag: '演讲',
    tagForeground: _kBoardTagPurple,
    tagBackground: _kBoardTagPurpleSoft,
  ),
];

class _HeadTeacherBoardSection extends StatelessWidget {
  const _HeadTeacherBoardSection({
    this.onOpenWorkbench,
    this.fillRemaining = false,
  });

  /// 「班级工作台 >」入口（班务白卡标题右侧）。
  final VoidCallback? onOpenWorkbench;

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
          title,
          style: TextStyle(
            fontSize: ui(18),
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        );

    Widget boardTitle() => Row(
          children: [
            Text(
              '班务',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onOpenWorkbench,
              borderRadius: BorderRadius.circular(ui(6)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(2),
                  vertical: ui(2),
                ),
                child: Text(
                  '班级工作台 >',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF6D6B75),
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionTitle('当前事项'),
              SizedBox(height: ui(20)),
              const _BoardPanel(items: _kHeadTeacherCurrentItems),
              SizedBox(height: ui(20)),
              boardTitle(),
              SizedBox(height: ui(20)),
              const _BoardPanel(items: _kHeadTeacherBoardItems),
            ],
          );
        }

        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: _BoardPanel(items: _kHeadTeacherCurrentItems),
            ),
            SizedBox(width: ui(16)),
            const Expanded(
              child: _BoardPanel(items: _kHeadTeacherBoardItems),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillRemaining ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sectionTitle('当前事项')),
                SizedBox(width: ui(16)),
                Expanded(child: boardTitle()),
              ],
            ),
            SizedBox(height: ui(20)),
            if (fillRemaining)
              Expanded(child: cardsRow)
            else
              IntrinsicHeight(child: cardsRow),
          ],
        );
      },
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.items});

  final List<_BoardItemData> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.08),
            blurRadius: ui(14),
            offset: Offset(0, ui(6)),
          ),
        ],
      ),
      child: items.isEmpty
          ? const _LessonEmptyHint(text: '暂无事项')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(8)),
                  _BoardItemCard(data: items[i]),
                ],
              ],
            ),
    );
  }
}

class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({required this.data});

  final _BoardItemData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(TextSpan(children: _splitBoardTime(data.time, ui))),
          SizedBox(height: ui(12)),
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
                    color: const Color(0xFF0B081A),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: data.tagBackground,
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  data.tag,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: data.tagForeground,
                    fontWeight: FontWeight.w400,
                    height: 15.24 / 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 复用 `_LessonScheduleCard._splitTime` 同款时间三段式样式，
/// 提到顶层方便 `_BoardItemCard` 直接使用。
List<InlineSpan> _splitBoardTime(String time, double Function(double) ui) {
  final parts = time.split('-');
  if (parts.length != 2) {
    return [
      TextSpan(
        text: time,
        style: TextStyle(
          fontSize: ui(18),
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ];
  }
  final start = parts[0].trim();
  final end = parts[1].trim();
  return [
    TextSpan(
      text: '$start ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: '- ',
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFFB6B5BB),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    TextSpan(
      text: end,
      style: TextStyle(
        fontSize: ui(18),
        color: const Color(0xFF0B081A),
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
  ];
}

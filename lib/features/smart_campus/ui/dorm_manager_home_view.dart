import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../data/dormitory_repository.dart';
import '../data/teacher_notice_data.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
/// 宿管端 · 智慧校园首页。
///
/// 970×~820 双栏布局，参考 Figma 设计稿：
///
/// 左主栏（约 697 宽）自上而下：
/// 1. **顶部统计行**：5 张小白卡（今日批次 / 待审补卡 / 晚归登记 / 异常未闭环 /
///    在寝率 98%）+ 1 张「待处理 12」紫色高亮卡，共占 697 宽。
/// 2. **宿管 6 项快捷入口卡**（697×255）：5+1 网格，每格 44×44 `#EAE5FF`
///    圆角底 + 28×28 图标 + 14/500 文案。
///    - 按宿舍查寝（16.png）/ 查寝历史（17.png）/ 宿管请假（19.png）/
///      校圈（adminHome/10.png）
///    - 群聊（adminHome/8.png）/ 校长信箱（adminHome/9.png）
/// 3. **当前事项 + 今日值班** 两张 340×340 大白卡并排：
///    - 当前事项：单一灰底 92 高时间卡（紫色「晚查」徽标 + 21:50-22:25 +
///      "晚查寝预备·设备与名单核对"）
///    - 今日值班：右上「按宿舍查寝 ›」link + 多条灰底 92 高时间卡，每条
///      紫色「晨检 / 晚查」徽标 + Barlow 时间段 + 14/600 标题。
///
/// 右栏（256 宽）固定单张白卡：
/// - 顶部 72 圆形头像 + 「Grey黎」16/500 + 绿点「在岗」+
///   「生活辅导员·宿管值班」+ 蓝底「宿管老师」徽章；
/// - 「区域：男生公寓1-3号楼 / 女生公寓A区」两行；
/// - 「通知」title + 滚动通知列表（后勤 / 联动 / 制度 / 大师课 等）。
///
/// 不带 `onBack` —— 这就是 dormManager 角色下 `mainView == dashboard` 的根
/// 视图，不会被 `controller.backToDashboard()` 弹出。
class DormManagerHomeView extends ConsumerStatefulWidget {
  const DormManagerHomeView({
    super.key,
    required this.shellDisplayName,
    required this.avatarUrl,
    this.availableRoles = const [SmartCampusRole.dormManager],
    this.selectedRole = SmartCampusRole.dormManager,
    this.onSelectRole,
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenDormCheckByRoom,
    this.onOpenDormCheckHistory,
    this.onOpenDormManagerLeave,
  });

  final String shellDisplayName;
  final String avatarUrl;

  /// 当前用户在校内可切换的全部身份。一般来自
  /// `SmartCampusState.availableRoles`，由 `myInfo.role + teacherRole`
  /// 接口共同决定。仅含 `[dormManager]` 时右栏隐藏「身份切换」区。
  final List<SmartCampusRole> availableRoles;

  /// 当前已选身份，用于右栏切换按钮高亮当前所在的身份（dormManager 默认）。
  final SmartCampusRole selectedRole;

  /// 切换身份回调。一般直接传 `SmartCampusController.selectRole`，
  /// state 写入后由 [SmartCampusPage] 重新路由到目标身份的大 dashboard。
  /// 为 `null` 时右栏隐藏「身份切换」区。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 五端共用：群聊 / 校长信箱 / 校圈。
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;

  /// 宿管专属快捷入口；后续按需要可接入对应独立视图（目前先保留回调）。
  final VoidCallback? onOpenDormCheckByRoom;
  final VoidCallback? onOpenDormCheckHistory;
  final VoidCallback? onOpenDormManagerLeave;

  @override
  ConsumerState<DormManagerHomeView> createState() =>
      _DormManagerHomeViewState();
}

class _DormManagerHomeViewState extends ConsumerState<DormManagerHomeView> {
  DormitoryCheckStat _stat = DormitoryCheckStat.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStat());
  }

  Future<void> _loadStat() async {
    final response = await ref
        .read(dormitoryRepositoryProvider)
        .dormitoryCheckStat(date: dormitoryCheckDateParam());
    if (!mounted || !response.isSuccess) return;
    setState(() => _stat = parseDormitoryCheckStat(response.data));
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: ui(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DormStatsRow(stat: _stat),
                SizedBox(height: ui(16)),
                _DormQuickActionsCard(
                  onOpenGroupChat: widget.onOpenGroupChat,
                  onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  onOpenSchoolCircle: widget.onOpenSchoolCircle,
                  onOpenDormCheckByRoom: widget.onOpenDormCheckByRoom,
                  onOpenDormCheckHistory: widget.onOpenDormCheckHistory,
                  onOpenDormManagerLeave: widget.onOpenDormManagerLeave,
                ),
                SizedBox(height: ui(16)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(title: '当前事项'),
                          SizedBox(height: 12),
                          _CurrentTaskCard(),
                        ],
                      ),
                    ),
                    SizedBox(width: ui(16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TodayDutyHeader(
                            onOpenDormCheckByRoom: widget.onOpenDormCheckByRoom,
                          ),
                          SizedBox(height: ui(12)),
                          const _TodayDutyCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          SizedBox(
            width: ui(256),
            child: _DormManagerSidePanel(
              displayName: widget.shellDisplayName,
              avatarUrl: widget.avatarUrl,
              availableRoles: widget.availableRoles,
              selectedRole: widget.selectedRole,
              onSelectRole: widget.onSelectRole,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 数据
// ============================================================================

class _StatItem {
  const _StatItem(this.value, this.label, {this.bigValue = true});

  final String value;
  final String label;

  /// 是否使用大数值字体（24/500）。在寝率 "98%" 用 16/500 小字号。
  final bool bigValue;
}

class _QuickAction {
  const _QuickAction(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}

const _dormQuickActions = <_QuickAction>[
  _QuickAction('按宿舍查寝', 'assets/images/schoolA/16.png'),
  _QuickAction('查寝历史', 'assets/images/schoolA/17.png'),
  _QuickAction('宿管请假', 'assets/images/schoolA/19.png'),
  _QuickAction('校圈', 'assets/images/adminHome/10.png'),
  _QuickAction('群聊', 'assets/images/adminHome/8.png'),
  _QuickAction('校长信箱', 'assets/images/adminHome/9.png'),
];

class _DutyTask {
  const _DutyTask({
    required this.tag,
    required this.title,
    required this.timeFrom,
    required this.timeTo,
  });

  final String tag;
  final String title;
  final String timeFrom;
  final String timeTo;
}

const _todayDutyTasks = <_DutyTask>[
  _DutyTask(
    tag: '晨检',
    title: '晨检开门 离检统计同步',
    timeFrom: '06:30',
    timeTo: '07:15',
  ),
  _DutyTask(
    tag: '晨检',
    title: '晨检开门 离检统计同步',
    timeFrom: '07:30',
    timeTo: '08:00',
  ),
  _DutyTask(
    tag: '晚查',
    title: '晚自习宿舍秩序巡查',
    timeFrom: '19:30',
    timeTo: '20:00',
  ),
];

// ============================================================================
// 通用：Section Title
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        height: 1.2,
        fontWeight: AppFont.w500,
        color: const Color(0xFF1A1A1A),
        fontFamily: 'PingFang SC',
      ),
    );
  }
}

// ============================================================================
// 1. 顶部统计行：5 项小卡 + 1 张待处理紫卡
// ============================================================================

class _DormStatsRow extends StatelessWidget {
  const _DormStatsRow({required this.stat});

  final DormitoryCheckStat stat;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rate = stat.bedCount == 0
        ? '—'
        : '${(stat.normalCount * 100 / stat.bedCount).round()}%';
    final items = <_StatItem>[
      _StatItem('${stat.bedCount}', '在册床位'),
      _StatItem('${stat.normalCount}', '正常在寝'),
      _StatItem('${stat.lateCount}', '晚归登记'),
      _StatItem('${stat.notCheckedCount}', '未打卡'),
      _StatItem(rate, '在寝率', bigValue: false),
    ];
    // 用 IntrinsicHeight 让 Row 取「最高子卡」的内在高度作为有界纵向约束，
    // 所有 stat 卡再用 CrossAxisAlignment.stretch 等高对齐。
    // 避免写死高度时不同字号 / 字体的实际行高造成 overflow。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _StatCard(item: items[i])),
            SizedBox(width: ui(16)),
          ],
          SizedBox(
            width: ui(123),
            child: _PendingCard(
              value: '${stat.notCheckedCount}',
              label: '待处理',
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: item.bigValue ? ui(24) : ui(16),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF6D6B75),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

/// 「待处理」紫高亮卡：24/500 紫色数值 + 12 灰色文案，居中布局。
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(24),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF8741FF),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF6D6B75),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. 宿管 6 项快捷入口
// ============================================================================

class _DormQuickActionsCard extends StatelessWidget {
  const _DormQuickActionsCard({
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenDormCheckByRoom,
    this.onOpenDormCheckHistory,
    this.onOpenDormManagerLeave,
  });

  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenDormCheckByRoom;
  final VoidCallback? onOpenDormCheckHistory;
  final VoidCallback? onOpenDormManagerLeave;

  VoidCallback? _resolveTap(String label) {
    switch (label) {
      case '群聊':
        return onOpenGroupChat;
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '校圈':
        return onOpenSchoolCircle;
      case '按宿舍查寝':
        return onOpenDormCheckByRoom;
      case '查寝历史':
        return onOpenDormCheckHistory;
      case '宿管请假':
        return onOpenDormManagerLeave;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const rowSize = 5;
    final rowCount = (_dormQuickActions.length / rowSize).ceil();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(28)),
      child: Column(
        children: [
          for (var ri = 0; ri < rowCount; ri++) ...[
            if (ri > 0) SizedBox(height: ui(24)),
            Row(
              children: [
                for (var ci = 0; ci < rowSize; ci++) ...[
                  if (ci > 0) SizedBox(width: ui(12)),
                  Expanded(
                    child: () {
                      final idx = ri * rowSize + ci;
                      if (idx < _dormQuickActions.length) {
                        return _QuickActionCell(
                          action: _dormQuickActions[idx],
                          onTap: _resolveTap(_dormQuickActions[idx].label),
                        );
                      }
                      return const SizedBox();
                    }(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionCell extends StatelessWidget {
  const _QuickActionCell({required this.action, this.onTap});

  final _QuickAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ui(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ui(48),
              height: ui(48),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: ui(44),
                    height: ui(44),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE5FF),
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                  ),
                  Image.asset(
                    action.iconAsset,
                    width: ui(28),
                    height: ui(28),
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              action.label,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                fontWeight: AppFont.w500,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. 当前事项卡（左 340 大白卡）
// ============================================================================

class _CurrentTaskCard extends StatelessWidget {
  const _CurrentTaskCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(340),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: const _DutyTaskTile(
        task: _DutyTask(
          tag: '晚查',
          title: '晚查寝预备·设备与名单核对',
          timeFrom: '21:50',
          timeTo: '22:25',
        ),
      ),
    );
  }
}

// ============================================================================
// 4. 今日值班 header（右上「按宿舍查寝 ›」link）
// ============================================================================

class _TodayDutyHeader extends StatelessWidget {
  const _TodayDutyHeader({this.onOpenDormCheckByRoom});

  final VoidCallback? onOpenDormCheckByRoom;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: _SectionTitle(title: '今日值班')),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpenDormCheckByRoom,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '按宿舍查寝',
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: const Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(width: ui(4)),
              Icon(
                Icons.chevron_right_rounded,
                size: ui(16),
                color: const Color(0xFFCECED1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayDutyCard extends StatelessWidget {
  const _TodayDutyCard();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(340),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _todayDutyTasks.length,
        separatorBuilder: (_, _) => SizedBox(height: ui(12)),
        itemBuilder: (_, i) => _DutyTaskTile(task: _todayDutyTasks[i]),
      ),
    );
  }
}

/// 单条值班 / 当前事项灰底 92 高时间卡。
///
/// 视觉：灰底 `#F5F6FA` 圆角 12；左上紫色 4 圆角标签（晨检 / 晚查 / …）；
/// 时间段 18/600 Barlow（"-" 用 `#B6B5BB`，前后用 `#1A1A1A`）；
/// 标题 14/600 `#0B081A`。
class _DutyTaskTile extends StatelessWidget {
  const _DutyTaskTile({required this.task});

  final _DutyTask task;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(4),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFDAD2FF),
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                task.tag,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.27,
                  color: const Color(0xFF8741FF),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: ui(18),
                fontWeight: FontWeight.w600,
                fontFamily: 'Barlow',
                height: 1.1,
                color: const Color(0xFF1A1A1A),
              ),
              children: [
                TextSpan(text: '${task.timeFrom} '),
                const TextSpan(
                  text: '- ',
                  style: TextStyle(color: Color(0xFFB6B5BB)),
                ),
                TextSpan(text: task.timeTo),
              ],
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            task.title,
            style: TextStyle(
              fontSize: ui(14),
              height: 1.3,
              fontWeight: AppFont.w600,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. 右侧栏：宿管档案 + 区域 + 通知
// ============================================================================

class _DormManagerSidePanel extends StatelessWidget {
  const _DormManagerSidePanel({
    required this.displayName,
    required this.avatarUrl,
    required this.availableRoles,
    required this.selectedRole,
    required this.onSelectRole,
  });

  final String displayName;
  final String avatarUrl;
  final List<SmartCampusRole> availableRoles;
  final SmartCampusRole selectedRole;
  final ValueChanged<SmartCampusRole>? onSelectRole;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 多身份用户才显示「身份切换」区块；单身份宿管直接隐藏。
    final showRoleSwitcher =
        onSelectRole != null && availableRoles.length > 1;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(24), ui(16), ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(displayName: displayName, avatarUrl: avatarUrl),
          SizedBox(height: ui(16)),
          const _ProfileAreaRows(),
          if (showRoleSwitcher) ...[
            SizedBox(height: ui(20)),
            Text(
              '身份切换',
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                fontWeight: AppFont.w500,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
              ),
            ),
            SizedBox(height: ui(10)),
            RoleSwitcherButtons(
              availableRoles: availableRoles,
              selectedRole: selectedRole,
              onSelectRole: onSelectRole!,
            ),
          ],
          SizedBox(height: ui(24)),
          Text(
            '通知',
            style: TextStyle(
              fontSize: ui(16),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          SizedBox(
            height: ui(500),
            child: const _DormNoticePanel(),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ui(72),
              height: ui(72),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAE5FF),
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? Center(
                      child: Text(
                        displayName.isEmpty
                            ? 'D'
                            : displayName.characters.first,
                        style: TextStyle(
                          fontSize: ui(28),
                          height: 1.0,
                          color: const Color(0xFF8741FF),
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ui(8)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty ? '宿管老师' : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(16),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                      SizedBox(width: ui(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(6),
                          vertical: ui(3),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ui(4)),
                          border: Border.all(
                            color: const Color(0xFFF3F2F3),
                            width: 0.5,
                          ),
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
                              '在岗',
                              style: TextStyle(
                                fontSize: ui(11),
                                height: 1.0,
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    '生活辅导员·宿管值班',
                    style: TextStyle(
                      fontSize: ui(12),
                      height: 1.2,
                      color: const Color(0xFF6D6B75),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // 蓝色「宿管老师」徽章：贴在头像底部
        Positioned(
          left: ui(18),
          top: ui(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(2)),
            decoration: BoxDecoration(
              color: const Color(0xFF325BFF),
              borderRadius: BorderRadius.circular(ui(10)),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              '宿管老师',
              style: TextStyle(
                fontSize: ui(11),
                height: 1.0,
                color: Colors.white,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAreaRows extends StatelessWidget {
  const _ProfileAreaRows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AreaLine(label: '区域：', value: '男生公寓1-3号楼'),
        SizedBox(height: 4),
        _AreaLine(label: '区域：', value: '女生公寓A区'),
      ],
    );
  }
}

class _AreaLine extends StatelessWidget {
  const _AreaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            height: 1.2,
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ],
    );
  }
}

class _DormNoticePanel extends ConsumerStatefulWidget {
  const _DormNoticePanel();

  @override
  ConsumerState<_DormNoticePanel> createState() => _DormNoticePanelState();
}

class _DormNoticePanelState extends ConsumerState<_DormNoticePanel> {
  List<TeacherNoticeListItem> _notices = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadNotices());
    });
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    final resp = await ref.read(dormitoryRepositoryProvider).noticeList(size: 20);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _notices = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _notices = parseTeacherNoticeList(resp.data);
      _loading = false;
    });
  }

  Future<void> _openNoticeDetail(TeacherNoticeListItem item) async {
    final resp =
        await ref.read(dormitoryRepositoryProvider).noticeDetail(id: item.id);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isNotEmpty ? resp.msg : '通知详情加载失败',
      );
      return;
    }
    final detail = parseTeacherNoticeDetail(resp.data);
    if (detail == null) {
      AppToast.show(context, '通知详情加载失败');
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '通知详情',
        width: 460,
        child: _DormNoticeDetailBody(notice: detail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_notices.isEmpty) {
      return Center(
        child: Text(
          '暂无通知',
          style: TextStyle(
            fontSize: ui(12),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _notices.length,
      separatorBuilder: (_, _) => SizedBox(height: ui(8)),
      itemBuilder: (_, i) {
        final item = _notices[i];
        return _SchoolNoticeCard(
          item: item,
          onTap: () => unawaited(_openNoticeDetail(item)),
        );
      },
    );
  }
}

class _DormNoticeDetailBody extends StatelessWidget {
  const _DormNoticeDetailBody({required this.notice});

  final TeacherNoticeListItem notice;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = notice.tagStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          notice.title,
          style: TextStyle(
            fontSize: ui(15),
            color: const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: ui(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(6),
                vertical: ui(2),
              ),
              decoration: BoxDecoration(
                color: tagStyle.background,
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                notice.tag,
                style: TextStyle(
                  fontSize: ui(12),
                  color: tagStyle.foreground,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (notice.author.isNotEmpty && notice.author != '—') ...[
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  notice.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ui(16)),
        _DormNoticeDetailRow(label: '类型', value: notice.type),
        if (notice.priority.isNotEmpty)
          _DormNoticeDetailRow(label: '优先级', value: notice.priority),
        if (notice.scopeLabel.isNotEmpty && notice.scopeLabel != '—')
          _DormNoticeDetailRow(label: '推送范围', value: notice.scopeLabel),
        _DormNoticeDetailRow(
          label: '时间',
          value: notice.publishedAt.isNotEmpty ? notice.publishedAt : notice.time,
          isLast: true,
        ),
        SizedBox(height: ui(12)),
        Text(
          '内容',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            notice.content.isEmpty ? '（暂无正文）' : notice.content,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DormNoticeDetailRow extends StatelessWidget {
  const _DormNoticeDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : ui(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(64),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolNoticeCard extends StatelessWidget {
  const _SchoolNoticeCard({required this.item, this.onTap});

  final TeacherNoticeListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = item.tagStyle;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(20), ui(10)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: tagStyle.background,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: ui(10),
                        height: 1.2,
                        fontWeight: AppFont.w500,
                        color: tagStyle.foreground,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.4,
                        color: const Color(0xFF0B081A),
                        fontFamily: 'Source Han Sans SC',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                item.time,
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.2,
                  color: const Color(0xFFCECED1),
                  fontFamily: 'Source Han Sans SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

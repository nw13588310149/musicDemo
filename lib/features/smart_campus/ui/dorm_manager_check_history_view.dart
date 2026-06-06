// =============================================================================
// 宿管端「查寝历史」独立页面
//
// 入口：宿管 dashboard 快捷区「查寝历史」按钮 → controller.openDormHistory()
//      → mainView == dormHistory + role == dormManager → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 设计原则：与「按宿舍查寝」(`dorm_manager_check_by_room_view.dart`) 保持
// 视觉语言的一致性，但因为本页是审计场景、单日动辄 50+ 条记录，所以
// **正文区采用表格列表**而非卡片网格 —— 让宿管在一屏内能扫到尽可能多的
// 记录。共用语言：
//   - banner 白→#F9EDFF 渐变 + 居中标题 + 副标题
//   - 14 天日历条（白底 16 圆角 + 灰底 8 圆角 cells，今日紫底白字）
//   - 4 张 100 高彩色渐变统计卡（橙 / 绿 / 红 / 紫 + 右上 32×32 白底图标）
//   - 状态徽章配色：正常 #A773FF / 请假免检 #1CD097 / 迟到 #325BFF /
//     未打卡 #FF323C
//
// 表格区列：
//   场次（晨/晚）| 宿舍 | 状态 | 规定时间 | 打卡时间 | 备注
//
// 在 by-room 视图基础之上额外补充的「历史能力」：
//   1. 日期切换 → 即时刷新统计卡 + 列表
//   2. 日内晨/晚两轮**混在同一列表**里通过「场次」列区分（用户反馈不再做
//      tab 切换，直接横铺更高效）
//   3. 当日无记录时显示空状态卡片
//
// 数据流：按日期、宿舍楼和楼层调用宿舍端查寝统计与房间列表接口。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../data/dormitory_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE5E7EB);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kCalendarHint = Color(0xFFE6E9F1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSolid = Color(0xFFA773FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);

// —— 历史卡状态徽章（与 by-room 视图底部完全一致）—————————————————
enum _HistoryStatus {
  normal('正常', _kPurpleSolid),
  absent('未打卡', _kRed),
  late_('晚归', _kBlue);

  const _HistoryStatus(this.label, this.bg);
  final String label;
  final Color bg;

  static _HistoryStatus fromCheckStatus(DormitoryStudentCheckStatus status) {
    return switch (status) {
      DormitoryStudentCheckStatus.normal => _HistoryStatus.normal,
      DormitoryStudentCheckStatus.lateReturn => _HistoryStatus.late_,
      DormitoryStudentCheckStatus.unchecked => _HistoryStatus.absent,
    };
  }
}

class _HistoryStudent {
  const _HistoryStudent({required this.name, required this.status});

  final String name;
  final _HistoryStatus status;
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.weekdayLabel,
    required this.dayLabel,
  });

  final DateTime date;
  final String weekdayLabel; // 一 / 二 / 今 等
  final String dayLabel; // 02 / 17 等

  String get isoDate {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckHistoryView extends ConsumerStatefulWidget {
  const DormManagerCheckHistoryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<DormManagerCheckHistoryView> createState() =>
      _DormManagerCheckHistoryViewState();
}

class _DormManagerCheckHistoryViewState
    extends ConsumerState<DormManagerCheckHistoryView> {
  late List<_CalendarDay> _days;
  late int _selectedDayIndex;

  DormitoryCheckStat _stat = DormitoryCheckStat.zero;
  List<DormitoryRoomCheck> _rooms = const [];
  List<DormitoryBuildingOption> _buildingOptions = const [
    DormitoryBuildingOption.all,
  ];
  List<DormitoryFloorOption> _floorOptions = const [
    DormitoryFloorOption.all,
  ];
  DormitoryBuildingOption _selectedBuilding = DormitoryBuildingOption.all;
  DormitoryFloorOption _selectedFloor = DormitoryFloorOption.all;

  bool _loading = false;
  bool _loadingFloors = false;
  String? _loadError;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _days = _buildDays(DateTime.now());
    _selectedDayIndex = 6;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  String get _selectedDateText => _days[_selectedDayIndex].isoDate;

  Future<void> _bootstrap() async {
    await _loadBuildings();
    await _reloadAll();
  }

  Future<void> _loadBuildings() async {
    final resp =
        await ref.read(dormitoryRepositoryProvider).dormitoryManagedBuildingList();
    if (!mounted) return;
    setState(() {
      _buildingOptions = resp.isSuccess
          ? parseDormitoryManagedBuildingList(resp.data)
          : const [DormitoryBuildingOption.all];
    });
  }

  Future<void> _loadFloors(String buildingId) async {
    if (buildingId.isEmpty) {
      setState(() {
        _floorOptions = const [DormitoryFloorOption.all];
        _selectedFloor = DormitoryFloorOption.all;
        _loadingFloors = false;
      });
      return;
    }
    setState(() => _loadingFloors = true);
    final resp = await ref
        .read(dormitoryRepositoryProvider)
        .dormitoryFloorList(buildingId: buildingId);
    if (!mounted) return;
    setState(() {
      _floorOptions = resp.isSuccess
          ? parseDormitoryFloorList(resp.data)
          : const [DormitoryFloorOption.all];
      _selectedFloor = DormitoryFloorOption.all;
      _loadingFloors = false;
    });
  }

  Future<void> _reloadAll() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final repo = ref.read(dormitoryRepositoryProvider);
    final buildingId =
        _selectedBuilding.id.isEmpty ? null : _selectedBuilding.id;
    final floorId = _selectedFloor.id.isEmpty ? null : _selectedFloor.id;
    final results = await Future.wait([
      repo.dormitoryCheckStat(
        buildingId: buildingId,
        floorId: floorId,
        date: _selectedDateText,
      ),
      repo.dormitoryCheckRoomList(
        buildingId: buildingId,
        floorId: floorId,
        date: _selectedDateText,
      ),
    ]);
    if (!mounted || token != _loadToken) return;

    final statResp = results[0];
    final roomResp = results[1];
    if (!statResp.isSuccess || !roomResp.isSuccess) {
      setState(() {
        _stat = DormitoryCheckStat.zero;
        _rooms = const [];
        _loading = false;
        _loadError = !statResp.isSuccess
            ? statResp.displayMsg
            : roomResp.displayMsg;
      });
      return;
    }

    setState(() {
      _stat = parseDormitoryCheckStat(statResp.data);
      _rooms = parseDormitoryCheckRoomList(roomResp.data);
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _onBuildingChanged(DormitoryBuildingOption option) async {
    setState(() {
      _selectedBuilding = option;
      _selectedFloor = DormitoryFloorOption.all;
    });
    await _loadFloors(option.id);
    await _reloadAll();
  }

  Future<void> _onFloorChanged(DormitoryFloorOption option) async {
    setState(() => _selectedFloor = option);
    await _reloadAll();
  }

  void _onTapDay(int index) {
    setState(() => _selectedDayIndex = index);
    unawaited(_reloadAll());
  }

  List<_HistoryStudent> _studentsOf(DormitoryRoomCheck room) {
    return [
      for (final s in room.students)
        _HistoryStudent(
          name: s.name,
          status: _HistoryStatus.fromCheckStatus(s.status),
        ),
    ];
  }

  String _roomTitle(DormitoryRoomCheck room) {
    if (room.buildingDesc.isEmpty || room.buildingDesc == '—') {
      return room.roomName;
    }
    return '${room.buildingDesc} ${room.roomName}';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _FilterRow(
              buildingOptions: _buildingOptions,
              floorOptions: _floorOptions,
              selectedBuilding: _selectedBuilding,
              selectedFloor: _selectedFloor,
              floorEnabled: _selectedBuilding.id.isNotEmpty && !_loadingFloors,
              onBuildingChanged: (v) => unawaited(_onBuildingChanged(v)),
              onFloorChanged: (v) => unawaited(_onFloorChanged(v)),
            ),
            SizedBox(height: ui(16)),
            _DateStripCard(
              days: _days,
              selectedIndex: _selectedDayIndex,
              dateText: _selectedDateText,
              statText: '共 ${_rooms.length} 个寝室',
              onTapDay: _onTapDay,
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              beds: _stat.bedCount,
              normal: _stat.normalCount,
              lateReturn: _stat.lateCount,
              absent: _stat.notCheckedCount,
            ),
            SizedBox(height: ui(16)),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: ui(40)),
                child: const Center(child: AppLoadingIndicator()),
              )
            else if (_loadError != null)
              _LoadErrorHint(
                message: _loadError!,
                onRetry: _reloadAll,
              )
            else if (_rooms.isEmpty)
              const _EmptyState()
            else
              _HistoryList(
                rooms: _rooms,
                roomTitle: _roomTitle,
                studentsOf: _studentsOf,
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

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

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
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
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
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '查寝历史',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.buildingOptions,
    required this.floorOptions,
    required this.selectedBuilding,
    required this.selectedFloor,
    required this.floorEnabled,
    required this.onBuildingChanged,
    required this.onFloorChanged,
  });

  final List<DormitoryBuildingOption> buildingOptions;
  final List<DormitoryFloorOption> floorOptions;
  final DormitoryBuildingOption selectedBuilding;
  final DormitoryFloorOption selectedFloor;
  final bool floorEnabled;
  final ValueChanged<DormitoryBuildingOption> onBuildingChanged;
  final ValueChanged<DormitoryFloorOption> onFloorChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _DormitorySelectField<DormitoryBuildingOption>(
          value: selectedBuilding,
          items: buildingOptions,
          itemLabel: (o) => o.label,
          icon: Icons.apartment_outlined,
          width: ui(220),
          menuWidth: ui(280),
          onChanged: onBuildingChanged,
        ),
        SizedBox(width: ui(12)),
        _DormitorySelectField<DormitoryFloorOption>(
          value: selectedFloor,
          items: floorOptions,
          itemLabel: (o) => o.label,
          icon: Icons.layers_outlined,
          width: ui(220),
          menuWidth: ui(280),
          enabled: floorEnabled,
          onChanged: onFloorChanged,
        ),
      ],
    );
  }
}

class _DormitorySelectField<T> extends StatefulWidget {
  const _DormitorySelectField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.icon,
    required this.width,
    required this.menuWidth,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final IconData icon;
  final double width;
  final double menuWidth;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  State<_DormitorySelectField<T>> createState() =>
      _DormitorySelectFieldState<T>();
}

class _DormitorySelectFieldState<T> extends State<_DormitorySelectField<T>> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    if (!widget.enabled) return;
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<T>(
      anchorContext: fieldCtx,
      items: widget.items,
      value: widget.value,
      itemLabel: widget.itemLabel,
      width: widget.menuWidth,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: widget.width,
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: ui(16),
              color: const Color(0xFFC6C6C6),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Text(
                widget.itemLabel(widget.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(18),
                color: const Color(0xFFC6C6C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorHint extends StatelessWidget {
  const _LoadErrorHint({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(32), horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          InkWell(
            onTap: () => unawaited(onRetry()),
            child: Text(
              '重试',
              style: TextStyle(
                fontSize: ui(13),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 14 天日期条
// =============================================================================

class _DateStripCard extends StatelessWidget {
  const _DateStripCard({
    required this.days,
    required this.selectedIndex,
    required this.dateText,
    required this.statText,
    required this.onTapDay,
  });

  final List<_CalendarDay> days;
  final int selectedIndex;
  final String dateText;
  final String statText;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(width: ui(6)),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: _kTextDarker,
              ),
              const Spacer(),
              Text(
                statText,
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
          SizedBox(height: ui(14)),
          LayoutBuilder(
            builder: (context, c) {
              const cellCount = 14;
              final gap = ui(6);
              final totalGap = gap * (cellCount - 1);
              final cellW = (c.maxWidth - totalGap) / cellCount;
              return Row(
                children: List.generate(cellCount, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cellCount - 1 ? 0 : gap,
                    ),
                    child: SizedBox(
                      width: cellW,
                      child: _CalendarCell(
                        day: days[i],
                        selected: i == selectedIndex,
                        onTap: () => onTapDay(i),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _CalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = selected ? _kPurple : _kCardGreyBg;
    final weekdayColor = selected ? _kCalendarHint : _kTextHint;
    final dayColor = selected ? Colors.white : _kTextDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(59),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.weekdayLabel,
              style: TextStyle(
                fontSize: ui(12),
                color: weekdayColor,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(7)),
            Text(
              day.dayLabel,
              style: TextStyle(
                fontSize: ui(16),
                color: dayColor,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4 张统计卡（沿用 by-room 视图的彩色渐变 + 右上图标容器风格）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.beds,
    required this.normal,
    required this.lateReturn,
    required this.absent,
  });

  final int beds;
  final int normal;
  final int lateReturn;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '在册床位',
            value: beds,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x29FFA846), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '正常口径',
            value: normal,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1746FF77), Color(0x00FFFFFF)],
            ),
            iconColor: _kGreen,
            iconKind: _StatIconKind.home,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '晚归',
            value: lateReturn,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1CFF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            label: '未打卡',
            value: absent,
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x1CFF4646), Color(0x00FFFFFF)],
            ),
            iconColor: _kPurple,
            iconKind: _StatIconKind.alert,
          ),
        ),
      ],
    );
  }
}

enum _StatIconKind { home, alert }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.iconColor,
    required this.iconKind,
  });

  final String label;
  final int value;
  final LinearGradient gradient;
  final Color iconColor;
  final _StatIconKind iconKind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            right: ui(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ui(12)),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: ui(32),
                    color: _kTextDark,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(16),
            top: ui(34),
            child: Container(
              width: ui(32),
              height: ui(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderHair, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                iconKind == _StatIconKind.home
                    ? Icons.home_rounded
                    : Icons.error_outline_rounded,
                size: ui(16),
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 历史记录表格列表（白底圆角 + 表头 + 寝室行 + 学生 chip）
//
// 列：宿舍（固定 240）| 学生状态（Expanded，wrap 多个 chip）
// 每个 chip 显示「[状态色点] 学生姓名 · 状态」，可一眼看清该宿舍各成员的
// 当日打卡情况；行高随学生数量自适应（Wrap），保证 4–8 人都能完整展示。
// =============================================================================

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.rooms,
    required this.roomTitle,
    required this.studentsOf,
  });

  final List<DormitoryRoomCheck> rooms;
  final String Function(DormitoryRoomCheck room) roomTitle;
  final List<_HistoryStudent> Function(DormitoryRoomCheck room) studentsOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HistoryListHeader(),
          for (var i = 0; i < rooms.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: _kBorderSoft),
            _HistoryListRow(
              title: roomTitle(rooms[i]),
              session: rooms[i].session,
              deadline: rooms[i].deadline,
              students: studentsOf(rooms[i]),
              zebra: i.isOdd,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryListHeader extends StatelessWidget {
  const _HistoryListHeader();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: const BoxDecoration(color: _kCardGreyBg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: ui(240), child: const _HeaderText('宿舍')),
          const Expanded(child: _HeaderText('学生状态')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(12),
        color: _kTextSecondary,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.2,
      ),
    );
  }
}

class _HistoryListRow extends StatelessWidget {
  const _HistoryListRow({
    required this.title,
    required this.session,
    required this.deadline,
    required this.students,
    required this.zebra,
  });

  final String title;
  final String session;
  final String deadline;
  final List<_HistoryStudent> students;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      color: zebra ? const Color(0xFFFAFAFC) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  '${students.length} 名在校学生 · $session · $deadline',
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
          Expanded(
            child: Wrap(
              spacing: ui(8),
              runSpacing: ui(8),
              children: [
                for (final s in students) _StudentChip(student: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 学生 chip：圆角矩形 + 左侧状态色点 + 名字 + 状态文字。
///
/// 背景使用状态颜色的浅色版（10% 透明度），文字用纯色 + 深色名字，保证多
/// chip 横排时视觉上每个学生的状态色一眼可辨，但又不会过于花哨。
class _StudentChip extends StatelessWidget {
  const _StudentChip({required this.student});

  final _HistoryStudent student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final statusColor = student.status.bg;
    final bg = statusColor.withValues(alpha: 0.10);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(5)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(999)),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(6)),
          Text(
            student.name,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            '· ${student.status.label}',
            style: TextStyle(
              fontSize: ui(12),
              color: statusColor,
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
// 空状态（当日 + 当前 session 无记录）
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: ui(40),
            color: const Color(0xFFD4D6D9),
          ),
          SizedBox(height: ui(8)),
          Text(
            '当日暂无查寝记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
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
// 14 天日历构建
// =============================================================================

List<_CalendarDay> _buildDays(DateTime today) {
  // 沿用 teacher 端布局：今日固定在 index 6，前 6 天 + 今 + 后 7 天，共 14 天。
  const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  return List<_CalendarDay>.generate(14, (i) {
    final d = today.add(Duration(days: i - 6));
    final isToday = i == 6;
    final wd = (d.weekday - 1) % 7;
    return _CalendarDay(
      date: d,
      weekdayLabel: isToday ? '今' : weekdayLabels[wd],
      dayLabel: d.day.toString().padLeft(2, '0'),
    );
  });
}

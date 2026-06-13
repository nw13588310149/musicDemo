// =============================================================================
// 学生端「我的课表」独立页面
//
// 入口：学生 dashboard 快捷区「我的课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中「教学周第 12 周
//      03/12-03/17」（12 用 #8741FF 紫色）；右侧 [◀ 本周 ▶] 周切换器
//   2. 网格容器（930×632，1px #F3F2F3 描边，12 圆角）：
//      - 时间列（120 宽，冻结）：60 高表头（"日期 / 节次" + 27° 斜分割线，
//        #F5F6FA 底）；下方 5 个时段，每个时段中间显示 `08:00 ── 08:40`
//      - 日期区（横滚动 7 列 × 200 宽 = 1400，可视约 810）：60 高 7 个日期
//        表头（周一白底，其余 #F5F6FA）；下方 5 行课卡（高度 120/120/222/
//        128/128，222 行允许 2 卡纵向堆叠）
//   3. 课卡（176 宽 × 96/120 高）四种主题：
//      - 小课·橙：#FFEDD3 底，#774B09 标题，绿色状态点 + "小课" 白标签
//      - 小课·蓝：#D9EBFF 底，#0D3A6D 标题，绿色状态点 + "小课"
//      - 大课·紫标准：#E8D4FF 底（96h），#7535BE 标题，紫色点 + "大课"
//      - 大课·紫加长：#F6EFFE 底（120h），#7535BE 标题，紫色点 + "大课"
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示
// 字体：PingFang SC（标题 16/正文 12-14）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_repository.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色 ---------------------------------------------------------------

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFEFEFEF);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);

// 4 种课卡主题
const Color _kSmallOrangeBg = Color(0xFFFFEDD3);
const Color _kSmallOrangeTitle = Color(0xFF774B09);
const Color _kSmallBlueBg = Color(0xFFD9EBFF);
const Color _kSmallBlueTitle = Color(0xFF0D3A6D);
const Color _kBigStandardBg = Color(0xFFE8D4FF);
const Color _kBigExtendedBg = Color(0xFFF6EFFE);
const Color _kBigTitle = Color(0xFF7535BE);

const Color _kStatusGreen = Color(0xFF0CAC40);
const Color _kStatusPurple = Color(0xFFA773FF);

// 列与行尺寸
const double _kTimeColWidth = 120;
const double _kDayColWidth = 200;
const double _kHeaderHeight = 60;

class _TimeConfig {
  const _TimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

class StudentMyScheduleView extends ConsumerStatefulWidget {
  const StudentMyScheduleView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyScheduleView> createState() =>
      _StudentMyScheduleViewState();
}

class _StudentMyScheduleViewState extends ConsumerState<StudentMyScheduleView> {
  late DateTime _weekStart;
  int _currentWeek = 1;
  static const int _baseWeek = 1;

  List<_TimeConfig> _timeConfigs = const [];
  List<List<List<_ScheduleCardData>>>? _serverCells;
  bool _scheduleLoading = true;

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  String get _dateRangeLabel {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    return '${_fmt(start)} - ${_fmt(end)}';
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) {
    final pure = DateTime(d.year, d.month, d.day);
    return pure.subtract(Duration(days: pure.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _currentWeek = _baseWeek;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadTimeConfigs();
    await _loadSchedule();
  }

  Future<void> _loadTimeConfigs({String? classId}) async {
    var resolvedClassId = classId;
    if (resolvedClassId == null || resolvedClassId.isEmpty) {
      final classResp = await ref
          .read(studentRepositoryProvider)
          .mySchoolClass();
      if (classResp.isSuccess) {
        final map = _asMap(classResp.data);
        final schoolClass = _asMap(map?['schoolClass']);
        resolvedClassId = _pickString(schoolClass ?? {}, ['id', 'classId'], '');
      }
    }
    if (resolvedClassId == null || resolvedClassId.isEmpty) return;

    final resp = await ref
        .read(schoolRepositoryProvider)
        .schoolTimeConfigList(classId: resolvedClassId);
    if (!mounted || !resp.isSuccess) return;

    final list = <_TimeConfig>[];
    for (final m in _extractList(resp)) {
      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      final start = _trimHm(
        _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
      );
      final end = _trimHm(
        _pickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
      );
      if (start.isEmpty || end.isEmpty) continue;
      list.add(_TimeConfig(lineNum: lineNum, start: start, end: end));
    }
    list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
    if (!mounted || list.isEmpty) return;
    setState(() => _timeConfigs = list);
  }

  Future<void> _loadSchedule() async {
    if (!mounted) return;
    setState(() => _scheduleLoading = true);

    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final resp = await ref
        .read(studentRepositoryProvider)
        .courseList(beginDate: _isoDate(start), endDate: _isoDate(end));
    if (!mounted) return;

    if (!resp.isSuccess) {
      if (resp.msg.isNotEmpty) {
        AppToast.show(context, resp.msg);
      }
      setState(() {
        _serverCells = _emptyCells();
        _scheduleLoading = false;
      });
      return;
    }

    final rows = _extractCourseRows(resp);
    if (rows.isNotEmpty) {
      final first = _flattenCourseRow(rows.first.row);
      final classId = _pickString(first, ['classId'], '');
      if (classId.isNotEmpty && _timeConfigs.isEmpty) {
        await _loadTimeConfigs(classId: classId);
      }
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final smallSeq = <int, int>{};

    for (final entry in rows) {
      final flat = _flattenCourseRow(entry.row);
      final dateStr = entry.dateKey.isNotEmpty
          ? entry.dateKey
          : _pickString(flat, ['date', 'classDate', 'courseDate'], '');
      final dayIdx = _dayIndex(dateStr);
      if (dayIdx < 0) continue;

      final lineNumRaw = flat['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = _parseCourseCard(flat, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);
    }

    setState(() {
      _serverCells = cells;
      _scheduleLoading = false;
    });
  }

  void _gotoPrev() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _currentWeek -= 1;
    });
    _loadSchedule();
  }

  void _gotoNext() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _currentWeek += 1;
    });
    _loadSchedule();
  }

  void _gotoCurrent() {
    setState(() {
      _weekStart = _mondayOf(DateTime.now());
      _currentWeek = _baseWeek;
    });
    _loadSchedule();
  }

  List<_DayHeaderData> _buildDayHeaders() {
    final today = DateTime.now();
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = _weekStart.add(Duration(days: i));
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return _DayHeaderData(
            weekdayLabel: labels[i],
            dateLabel:
                '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
            today: isToday,
          );
        }(),
    ];
  }

  List<_TimeSlotData> _buildSlots(List<List<List<_ScheduleCardData>>> cells) {
    final configs = _activeTimeConfigs;
    return [
      for (var i = 0; i < configs.length; i++)
        _TimeSlotData(
          start: configs[i].start,
          end: configs[i].end,
          height: _calcSlotHeight(i, cells),
        ),
    ];
  }

  double _calcSlotHeight(
    int slotIdx,
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    var maxCards = 1;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final n = cells[d][slotIdx].length;
        if (n > maxCards) maxCards = n;
      }
    }
    return 120.0 + (maxCards - 1) * 102.0;
  }

  List<List<List<_ScheduleCardData>>> _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <_ScheduleCardData>[]],
    ];
  }

  int _dayIndex(String dateStr) {
    if (dateStr.isEmpty) return -1;
    DateTime? d = DateTime.tryParse(dateStr);
    if (d == null) {
      final iso = dateStr.split('T').first;
      d = DateTime.tryParse(iso);
    }
    if (d == null) return -1;
    final dn = DateTime(d.year, d.month, d.day);
    final ws = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    final diff = dn.difference(ws).inDays;
    return (diff < 0 || diff > 6) ? -1 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cells = _serverCells ?? _emptyCells();
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

    return SmartCampusSchedulePageShell(
      backgroundColor: _kCardBg,
      header: _ScheduleBanner(
        week: _currentWeek,
        dateRange: _dateRangeLabel,
        onBack: widget.onBack,
        onPrevWeek: _gotoPrev,
        onNextWeek: _gotoNext,
        onGotoCurrent: _gotoCurrent,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(ui(20), ui(11), ui(20), ui(20)),
        child: _ScheduleGrid(
          slots: slots,
          days: days,
          cells: cells,
          loading: _scheduleLoading,
        ),
      ),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  dynamic raw = resp.data;
  if (raw is Map && raw.containsKey('data')) {
    final d = raw['data'];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = d;
    }
  }
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : const []));
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _trimHm(String value) {
  if (value.isEmpty) return value;
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return value;
}

Map<String, dynamic> _flattenCourseRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(String key, List<MapEntry<String, String>> fieldMap) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      flat.putIfAbsent(entry.value, () => s);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
  ]);

  return flat;
}

List<({String dateKey, Map<String, dynamic> row})> _extractCourseRows(
  ApiResponse resp,
) {
  final raw = resp.data;
  final list = <({String dateKey, Map<String, dynamic> row})>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final v = entry.value;
      final key = entry.key.toString();
      if (v is List) {
        for (final item in v) {
          if (item is Map) {
            list.add((dateKey: key, row: Map<String, dynamic>.from(item)));
          }
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        list.add((dateKey: '', row: Map<String, dynamic>.from(item)));
      }
    }
  }
  return list;
}

String? _pickCapacityLabel(Map<String, dynamic> json) {
  final current = _pickString(json, [
    'studentCount',
    'currentCount',
    'selectedCount',
    'usedCapacity',
    'actualCount',
  ]);
  final total = _pickString(json, [
    'capacity',
    'maxCapacity',
    'totalCount',
    'studentTotal',
    'limitCount',
    'peopleNum',
  ]);
  if (current.isNotEmpty && total.isNotEmpty) {
    return '$current/$total人';
  }
  if (total.isNotEmpty) return '$total人';
  if (current.isNotEmpty) return '$current人';
  return null;
}

_ScheduleCardData _parseCourseCard(
  Map<String, dynamic> json,
  int smallIdxInCell,
) {
  final typeRaw = json['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

  final location = _pickString(json, [
    'classroomName',
    'roomName',
    'classroom',
  ], '—');
  final name = _pickString(json, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ], '—');
  final teacher = _pickString(json, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ], '');
  final className = _pickString(json, ['className', 'class'], '');

  if (isSmall) {
    final kind = smallIdxInCell.isEven
        ? _CardKind.smallOrange
        : _CardKind.smallBlue;
    return _ScheduleCardData(
      kind: kind,
      location: location,
      name: name,
      subline: teacher.isNotEmpty
          ? teacher
          : (className.isNotEmpty ? className : '—'),
      capacity: _pickCapacityLabel(json),
    );
  }

  final subline = teacher.isEmpty
      ? (className.isEmpty ? '—' : className)
      : (className.isEmpty ? teacher : '$teacher · $className');
  return _ScheduleCardData(
    kind: _CardKind.bigStandard,
    location: location,
    name: name,
    subline: subline,
  );
}

// =============================================================================
// 顶部 banner：68 高，白→紫淡色渐变
// =============================================================================

class _ScheduleBanner extends StatelessWidget {
  const _ScheduleBanner({
    required this.week,
    required this.dateRange,
    required this.onBack,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onGotoCurrent,
  });

  final int week;
  final String dateRange;
  final VoidCallback onBack;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onGotoCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusScheduleTopBar(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 返回按钮
          Positioned(
              left: ui(20),
              top: ui(20),
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
            // 居中标题：教学周第 12 周 / 03/12 - 03/17
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(16),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                      children: [
                        const TextSpan(text: '教学周第 '),
                        TextSpan(
                          text: '$week',
                          style: const TextStyle(color: _kPurple),
                        ),
                        const TextSpan(text: ' 周'),
                      ],
                    ),
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    dateRange,
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
            // 右侧周切换器
            Positioned(
              right: ui(20),
              top: ui(14),
              child: _WeekSwitcher(
                onPrev: onPrevWeek,
                onNext: onNextWeek,
                onCurrent: onGotoCurrent,
              ),
            ),
          ],
        ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.onPrev,
    required this.onNext,
    required this.onCurrent,
  });

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChevronButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
          SizedBox(width: ui(12)),
          InkWell(
            onTap: onCurrent,
            borderRadius: BorderRadius.circular(ui(4)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(2)),
              child: Text(
                '本周',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          _ChevronButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: SizedBox(
        width: ui(32),
        height: ui(32),
        child: Icon(icon, size: ui(18), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

// =============================================================================
// 网格主体：时间列（左，冻结）+ 日期区（右，横滚动）
// =============================================================================

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.slots,
    required this.days,
    required this.cells,
    this.loading = false,
  });

  final List<_TimeSlotData> slots;

  /// 7 个日期表头数据
  final List<_DayHeaderData> days;

  /// 7 列 × N 行的格子数据。`cells[dayIndex][slotIndex]` 是该格的课卡列表
  /// （0、1 或 2 张；2 张时纵向堆叠，需要对应 slot 的高度足以容纳）。
  final List<List<List<_ScheduleCardData>>> cells;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (loading) {
      return Container(
        height: ui(420),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: const AppLoadingIndicator(),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间列：完全冻结，不横滚
            _TimeColumn(slots: slots),
            // 日期区：横向滚动 7 × 200 宽
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: ui(_kDayColWidth) * days.length,
                  child: _DaysArea(slots: slots, days: days, cells: cells),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 时间列（冻结）
// =============================================================================

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.slots});

  final List<_TimeSlotData> slots;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(_kTimeColWidth),
      child: Column(
        children: [
          // 表头：60 高，#F5F6FA 底，"日期" / "节次" + 斜分割线
          _TimeHeader(),
          // 各时段
          for (final slot in slots)
            Container(
              width: double.infinity,
              height: ui(slot.height),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: _kBorderSoft),
                  bottom: BorderSide(color: _kBorderSoft),
                ),
              ),
              alignment: Alignment.center,
              child: _TimeRange(start: slot.start, end: slot.end),
            ),
        ],
      ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(_kHeaderHeight),
      decoration: const BoxDecoration(
        color: _kInnerGray,
        border: Border(
          right: BorderSide(color: _kBorderSoft),
          bottom: BorderSide(color: _kBorderSoft),
        ),
      ),
      child: Stack(
        children: [
          // 27° 斜分割线
          Positioned.fill(child: CustomPaint(painter: _DiagonalLinePainter())),
          Positioned(
            right: ui(20),
            top: ui(10),
            child: Text(
              '日期',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(20),
            bottom: ui(12),
            child: Text(
              '节次',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kBorderHair
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_DiagonalLinePainter oldDelegate) => false;
}

class _TimeRange extends StatelessWidget {
  const _TimeRange({required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          start,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
        SizedBox(height: ui(8)),
        Container(width: ui(12), height: 1, color: _kTextDivider),
        SizedBox(height: ui(8)),
        Text(
          end,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 日期区：表头 + 多行课卡
// =============================================================================

class _DaysArea extends StatelessWidget {
  const _DaysArea({
    required this.slots,
    required this.days,
    required this.cells,
  });

  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DaysHeaderRow(days: days),
        for (var slotIdx = 0; slotIdx < slots.length; slotIdx++)
          _DayBodyRow(
            height: slots[slotIdx].height,
            // cells 第一维是 day，第二维是 slot；按行收集 7 列在该 slot 的卡片
            rowCells: [
              for (var dayIdx = 0; dayIdx < days.length; dayIdx++)
                cells[dayIdx][slotIdx],
            ],
          ),
      ],
    );
  }
}

class _DaysHeaderRow extends StatelessWidget {
  const _DaysHeaderRow({required this.days});

  final List<_DayHeaderData> days;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(_kHeaderHeight),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++)
            Container(
              width: ui(_kDayColWidth),
              height: ui(_kHeaderHeight),
              decoration: BoxDecoration(
                // 当天（默认 i==0 周一）走白底，其余 #F5F6FA
                color: days[i].today ? Colors.white : _kInnerGray,
                border: Border(
                  bottom: BorderSide(color: _kBorderHair),
                  // 第一列在最左侧不需要左边框
                  left: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: _kBorderHair),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[i].weekdayLabel,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    days[i].dateLabel,
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
  }
}

class _DayBodyRow extends StatelessWidget {
  const _DayBodyRow({required this.height, required this.rowCells});

  final double height;
  final List<List<_ScheduleCardData>> rowCells;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(height),
      child: Row(
        children: [
          for (var i = 0; i < rowCells.length; i++)
            SizedBox(
              width: ui(_kDayColWidth),
              height: ui(height),
              // 用 Stack overlay 画底/左边线，避免 BoxDecoration.border 把
              // 子可用高度从 slot.height 减掉 1px——精确填满（120/222
              // 等行）时会触发 "BOTTOM OVERFLOWED BY 1.00 PIXELS"。
              child: Stack(
                children: [
                  Positioned.fill(child: _CellContent(cards: rowCells[i])),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(height: 1, color: _kBorderSoft),
                  ),
                  if (i != 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: _kBorderSoft),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CellContent extends StatelessWidget {
  const _CellContent({required this.cards});

  final List<_ScheduleCardData> cards;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (cards.isEmpty) {
      return const ScheduleIdleSlot();
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: ui(6)),
            _ClassCard(data: cards[i]),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 课卡（4 种主题）
// =============================================================================

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data});

  final _ScheduleCardData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final theme = _themeFor(data.kind);
    final cardHeight = data.kind == _CardKind.bigExtended ? 120.0 : 96.0;
    return Container(
      width: ui(176),
      height: ui(cardHeight),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        children: [
          // 顶部地点
          Positioned(
            left: ui(16),
            top: ui(8),
            child: SizedBox(
              width: ui(108),
              child: Text(
                data.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: theme.titleColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 16 / 12,
                ),
              ),
            ),
          ),
          // 右上：状态点 + "小课/大课" 标签（96h 卡片）
          if (data.kind != _CardKind.bigExtended)
            Positioned(
              left: ui(126),
              top: ui(6),
              child: _ClassKindTag(isSmall: theme.isSmall, outlined: false),
            ),
          // 中部白色面板（容纳课名 + 副信息）
          Positioned(
            left: ui(4),
            top: ui(32),
            child: Container(
              width: ui(168),
              height: ui(data.kind == _CardKind.bigExtended ? 84 : 60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
            ),
          ),
          // 课名
          Positioned(
            left: ui(16),
            top: ui(44),
            child: SizedBox(
              width: ui(140),
              child: Text(
                data.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 16 / 14,
                ),
              ),
            ),
          ),
          // 副信息（小课：班级 + 人数；大课标准：教师·合班；大课加长：年级·合班）
          if (data.kind == _CardKind.bigExtended) ...[
            // 加长卡：subline 在更下方（top:64），加长卡的"大课"标签放在底部 left:16, top:86
            Positioned(
              left: ui(16),
              top: ui(64),
              child: Text(
                data.subline,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 16 / 12,
                ),
              ),
            ),
            Positioned(
              left: ui(16),
              top: ui(86),
              child: _ClassKindTag(isSmall: false, outlined: true),
            ),
          ] else ...[
            // 标准卡（96h）：subline 在 top:62-64，右侧可能有 11/23人
            Positioned(
              left: ui(16),
              top: ui(64),
              child: SizedBox(
                width: ui(theme.isSmall && data.capacity != null ? 100 : 140),
                child: Text(
                  data.subline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 16 / 12,
                  ),
                ),
              ),
            ),
            if (theme.isSmall && data.capacity != null)
              Positioned(
                right: ui(16),
                top: ui(64),
                child: Text(
                  data.capacity!,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDivider,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 16 / 12,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  _CardTheme _themeFor(_CardKind kind) {
    switch (kind) {
      case _CardKind.smallOrange:
        return const _CardTheme(
          bg: _kSmallOrangeBg,
          titleColor: _kSmallOrangeTitle,
          isSmall: true,
        );
      case _CardKind.smallBlue:
        return const _CardTheme(
          bg: _kSmallBlueBg,
          titleColor: _kSmallBlueTitle,
          isSmall: true,
        );
      case _CardKind.bigStandard:
        return const _CardTheme(
          bg: _kBigStandardBg,
          titleColor: _kBigTitle,
          isSmall: false,
        );
      case _CardKind.bigExtended:
        return const _CardTheme(
          bg: _kBigExtendedBg,
          titleColor: _kBigTitle,
          isSmall: false,
        );
    }
  }
}

class _ClassKindTag extends StatelessWidget {
  const _ClassKindTag({required this.isSmall, required this.outlined});

  final bool isSmall;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final dotColor = isSmall ? _kStatusGreen : _kStatusPurple;
    final label = isSmall ? '小课' : '大课';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: outlined ? Border.all(color: _kBorderSoft, width: 1.4) : null,
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
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTheme {
  const _CardTheme({
    required this.bg,
    required this.titleColor,
    required this.isSmall,
  });

  final Color bg;
  final Color titleColor;
  final bool isSmall;
}

// =============================================================================
// 数据模型
// =============================================================================

enum _CardKind { smallOrange, smallBlue, bigStandard, bigExtended }

class _ScheduleCardData {
  const _ScheduleCardData({
    required this.kind,
    required this.location,
    required this.name,
    required this.subline,
    this.capacity,
  });

  final _CardKind kind;
  final String location;
  final String name;

  /// 副行：小课填班级（如"高三音乐实验班"）；
  /// 大课标准填教师（如"赵老师-大班合班"）；大课加长填年级（"高三年级-大班合班"）。
  final String subline;

  /// 仅小课用，右侧"11/23人"。
  final String? capacity;
}

class _TimeSlotData {
  const _TimeSlotData({
    required this.start,
    required this.end,
    required this.height,
  });

  final String start;
  final String end;
  final double height;
}

class _DayHeaderData {
  const _DayHeaderData({
    required this.weekdayLabel,
    required this.dateLabel,
    this.today = false,
  });

  final String weekdayLabel;
  final String dateLabel;
  final bool today;
}

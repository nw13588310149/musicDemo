// =============================================================================
// 任课老师端「授课课表」独立页面
//
// 入口：教师 dashboard 快捷区「授课课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中 16/600
//      "授课课表" + 12/B6B5BB 副标题；右上角 "查看 / 编辑" 分段控制
//      （32 高白底 + #F3F2F3 边；激活段紫底 #8741FF / 白字）。
//   2. 控制条（64 高 #F5F6FA 灰底 12 圆角）：
//      - 左上：教学周第 N 周（16/600，N 用 #8741FF 紫）。
//      - 左下：legend 两枚 pill：⚫ #A773FF "大课"·灰副标"不可编辑"；
//             ⚫ #0CAC40 "小课"·灰副标"编辑模式下可点击"。
//      - 右侧：[◀ 本周 ▶] 周切换器 + "YYYY/MM/DD" 日历 pill。
//   3. 网格（930×N，1px #F3F2F3 描边，12 圆角）：与学生 / 管理员端共用同
//      4 主题课卡 + 时间冻结列 + 横滚日期区。左侧时间列由
//      `schoolTimeConfigList` 接口返回；课表数据来自任课老师端
//      `/app/school/v2/teacher/courseList`，已按 token 过滤为当前老师的课。
//   4. 编辑模式：
//      - 大课（紫）原样展示，不可编辑（与 admin 端不同：admin 端可拖动）；
//      - 小课（橙 / 蓝）变可点击；
//      - 不论本节当前是空、是小课、还是已经排了大课，卡片下方都会挂一枚
//        48 高 "申请小课" pill：教师可以直接在大课同节申请加排一节小课
//        （高三艺考生加练等场景）→ 打开右侧 [_ApplySmallLessonDrawer]，
//        提交触发 `/app/school/v2/teacher/schoolSmallCourseApplySave`。
//   5. 查看模式空格画 "空闲" 灰边占位；编辑模式下空格走"申请小课"。
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示 / #774B09 橙文 / #0D3A6D 蓝文 / #7535BE 紫文
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色（与学生 / 管理员端 schedule 保持一致）----------------------

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
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

enum _ScheduleMode { view, edit }

// ---- 数据模型 -----------------------------------------------------------

enum _CardKind { smallOrange, smallBlue, bigStandard, bigExtended }

class _ScheduleCardData {
  const _ScheduleCardData({
    required this.kind,
    required this.location,
    required this.name,
    required this.subline,
    this.capacity,
    this.bgColor,
    this.raw,
  });

  final _CardKind kind;
  final String location;
  final String name;
  final String subline;
  final String? capacity;

  /// API `color` 字段（hex 解析后）覆盖默认主题底色；为空则按 [kind] 走预设。
  final Color? bgColor;

  /// `courseList` 单条原始记录（保留以备后续扩展，例如详情弹窗等）。
  final Map<String, dynamic>? raw;
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

/// 节次时间配置（来自 `schoolTimeConfigList`）。
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

/// 兜底节次：API 拉不到 / 无配置时显示 5 节，与原 demo 节奏保持一致。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

/// 本学期总教学周数（与 admin 端约定一致：18 周）。"本学期所有教学周"
/// 复用模式从当前 `currentWeek` 起补到第 [_kTermTotalWeeks] 周。
const int _kTermTotalWeeks = 18;

// =============================================================================
// 入口 widget
// =============================================================================

class TeacherLessonScheduleView extends ConsumerStatefulWidget {
  const TeacherLessonScheduleView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherLessonScheduleView> createState() =>
      _TeacherLessonScheduleViewState();
}

class _TeacherLessonScheduleViewState
    extends ConsumerState<TeacherLessonScheduleView> {
  /// 当前显示的周一（用于日期范围 / 标签 / API begin/end）。
  late DateTime _weekStart;

  /// "教学周第 N 周" 的展示数字。本地维护：默认 12 周（"本周"），每翻一周 ±1。
  /// 后端 swagger 没单独返回教学周编号，仅作 UI 展示。
  int _currentWeek = 12;
  static const int _baseWeek = 12;

  _ScheduleMode _mode = _ScheduleMode.view;

  /// 班级列表第一项 id（来自 admin `classList`）。仅用于驱动
  /// `schoolTimeConfigList` 拉对应班级的节次时间表 + 抽屉默认班级回填。
  /// 抽屉自身会再调一次 `classList` 拿最新选项，无需在这里整张缓存。
  String? _firstClassId;

  /// 课表左侧节次时间表（按 `lineNum` 升序）。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  /// 当前周的网格数据，[7 天][N 节] → 多张课卡。null = 尚未加载。
  List<List<List<_ScheduleCardData>>>? _serverCells;
  bool _scheduleLoading = false;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) {
    final pure = DateTime(d.year, d.month, d.day);
    return pure.subtract(Duration(days: pure.weekday - 1));
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: '选择教学日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPurple,
              onPrimary: Colors.white,
              onSurface: _kTextDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    final newWeekStart = _mondayOf(picked);
    final delta = newWeekStart.difference(_mondayOf(DateTime.now())).inDays;
    setState(() {
      _weekStart = newWeekStart;
      _currentWeek = _baseWeek + (delta / 7).round();
    });
    _loadSchedule();
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 先拉班级列表（驱动 timeConfig 用），再拉时间表 + 课表。
      await _loadClasses();
      if (!mounted) return;
      await _loadTimeConfig();
      if (!mounted) return;
      _loadSchedule();
    });
  }

  // —— 数据加载 ————————————————————————————————————————————————

  Future<void> _loadClasses() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    String? firstId;
    for (final m in rows) {
      final id = _pickString(m, ['id', 'classId'], '');
      if (id.isNotEmpty) {
        firstId = id;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _firstClassId = firstId);
  }

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口要求 `classId` 必填，
  /// 用班级列表第一项作为基准；为空时回退到 [_kDefaultTimeConfigs]。
  Future<void> _loadTimeConfig() async {
    final classId = _firstClassId;
    if (classId == null || classId.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: classId);
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    final list = <_TimeConfig>[];
    for (final m in rows) {
      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      final start = _trimToHm(
        _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
      );
      final end = _trimToHm(
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
    setState(() => _scheduleLoading = true);
    final repo = ref.read(teacherRepositoryProvider);
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final resp = await repo.courseList(
      beginDate: _isoDate(start),
      endDate: _isoDate(end),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _serverCells = _emptyCells();
        _scheduleLoading = false;
      });
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final rows = _extractCourseRows(resp);
    final smallSeq = <int, int>{};
    for (final entry in rows) {
      final m = entry.row;
      final dateStr = entry.dateKey.isNotEmpty
          ? entry.dateKey
          : _pickString(m, ['date', 'classDate', 'courseDate'], '');
      final dayIdx = _dayIndex(dateStr);
      if (dayIdx < 0) continue;

      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = _parseCourseCard(m, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);
    }

    setState(() {
      _serverCells = cells;
      _scheduleLoading = false;
    });
  }

  /// `courseList` 的 `data` 既可能是按日期分组的 Map（新格式：
  /// `{"2026-05-11": [{...}, ...]}`），也可能是扁平 List（老格式）。
  /// 统一摊平成 `(dateKey, row)` 元组。
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
              list.add((dateKey: key, row: item.cast<String, dynamic>()));
            }
          }
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add((dateKey: '', row: item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  List<List<List<_ScheduleCardData>>> _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <_ScheduleCardData>[]],
    ];
  }

  /// 根据当前格子内最多课卡数算出每行高度（动态适配 1 / 2 / N 张课卡叠放）。
  /// 编辑模式下额外预留 56px：8 间距 + 48 高 "申请小课" pill，让"大课下方
  /// 也能申请小课"在每一节都成立。
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
    // 1 张：96 + 24 padding = 120；2 张：96 + 6 + 96 + 24 = 222；
    // N 张：120 + (N - 1) × 102（102 = 96 卡高 + 6 间距）。
    final base = 120.0 + (maxCards - 1) * 102.0;
    // 编辑模式下不论是否已有课卡，都在卡片下方挂"申请小课" pill（8 + 48）。
    if (_mode == _ScheduleMode.edit) return base + 56;
    return base;
  }

  /// 把后端返回的日期字符串归一化到当前周内的 [0..6]，否则返回 -1。
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

  /// 把 courseList 单条记录翻译成 [_ScheduleCardData]。
  ///
  /// `type == 2` → 小课（同一格里第 0 张橙、第 1 张蓝循环）；其它值 → 大课。
  /// `color` 是 hex（含 `#`），存到卡片做背景覆盖；标题色按 kind 走语义色。
  _ScheduleCardData _parseCourseCard(
    Map<String, dynamic> json,
    int smallIdxInCell,
  ) {
    final typeRaw = json['type'];
    final type = typeRaw is int
        ? typeRaw
        : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
    final isSmall = type == 2;

    final location = _pickString(json, [
      'classroomName',
      'roomName',
      'classroom',
    ], '');
    final name = _pickString(json, [
      'subjectName',
      'courseName',
      'subject',
      'name',
    ], '');
    final teacher = _pickString(json, [
      'teacherRealname',
      'teacherName',
      'realname',
      'realName',
      'teacherNickname',
      'teacher',
    ], '');
    final className = _pickString(json, ['className', 'class'], '');
    final colorOverride = _parseHexColor(_pickString(json, ['color'], ''));

    final rawCopy = Map<String, dynamic>.from(json);
    if (isSmall) {
      final kind = smallIdxInCell.isEven
          ? _CardKind.smallOrange
          : _CardKind.smallBlue;
      final attendCount = json['attendCount'] ?? json['signCount'];
      final totalCount =
          json['totalCount'] ?? json['capacity'] ?? json['classSize'];
      String? cap;
      if (attendCount != null && totalCount != null) {
        cap = '$attendCount/$totalCount人';
      }
      return _ScheduleCardData(
        kind: kind,
        location: location,
        name: name,
        subline: className.isNotEmpty ? className : teacher,
        capacity: cap,
        bgColor: colorOverride,
        raw: rawCopy,
      );
    }
    return _ScheduleCardData(
      kind: _CardKind.bigStandard,
      location: location,
      name: name,
      subline: teacher.isEmpty
          ? className
          : (className.isEmpty ? teacher : '$teacher-$className'),
      bgColor: colorOverride,
      raw: rawCopy,
    );
  }

  /// 解析 `#RRGGBB` / `#AARRGGBB` 形式的 hex；非法则返回 null。
  Color? _parseHexColor(String hex) {
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  /// 根据 `_weekStart` 拼出 7 天的 header（标签 + MM/DD + 是否今天）。
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

  /// 把节次/日期组合成 "第N节 HH:MM-HH:MM· 周X yyyy-MM-dd" 形式（抽屉只读项）。
  String _slotLabel(int dayIdx, int slotIdx) {
    final configs = _activeTimeConfigs;
    final cfg = configs[slotIdx.clamp(0, configs.length - 1)];
    final day = _weekStart.add(Duration(days: dayIdx));
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '第${cfg.lineNum}节 ${cfg.start}-${cfg.end}· ${labels[dayIdx]} '
        '${_isoDate(day)}';
  }

  /// 编辑模式空格落点要传给抽屉的 lineNum：取该 slot 对应的 lineNum
  /// （API 配置可能是 1/2/3/5/6 这种非连续序列）。
  int _lineNumOf(int slotIdx) {
    final configs = _activeTimeConfigs;
    return configs[slotIdx.clamp(0, configs.length - 1)].lineNum;
  }

  /// 编辑模式下点击空格 → 弹右侧 [_ApplySmallLessonDrawer]，提交时调
  /// `schoolSmallCourseApplySave` 写入一条申请，成功后重新拉取本周课表。
  Future<void> _onApplySmallLesson(int dayIdx, int slotIdx) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final day = _weekStart.add(Duration(days: dayIdx));

    final submitted = await showGeneralDialog<bool>(
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
              child: _ApplySmallLessonDrawer(
                slotLabel: _slotLabel(dayIdx, slotIdx),
                baseDateIso: _isoDate(day),
                lineNum: _lineNumOf(slotIdx),
                currentWeek: _currentWeek,
                initialClassId: _firstClassId,
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmitted: () => Navigator.of(ctx).pop(true),
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

    if (submitted != true || !mounted) return;
    AppToast.show(context, '已提交教务审核');
    await _loadSchedule();
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cells = _serverCells ?? _emptyCells();
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(20)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeacherScheduleHeader(
              onBack: widget.onBack,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(12)),
              child: _TeacherScheduleControlBar(
                week: _currentWeek,
                weekDateLabel: _fmtDate(_weekStart),
                onPrev: _gotoPrev,
                onCurrent: _gotoCurrent,
                onNext: _gotoNext,
                onPickDate: _pickDate,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(20)),
              child: Stack(
                children: [
                  _ScheduleGrid(
                    mode: _mode,
                    slots: slots,
                    days: days,
                    cells: cells,
                    onApplySmallLesson: _onApplySmallLesson,
                  ),
                  if (_scheduleLoading)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(ui(12)),
                          ),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: _kPurple,
                          ),
                        ),
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

// =============================================================================
// 顶部 banner：68 高，白→紫淡色渐变；居中标题 + 副标题；右上"查看/编辑"分段
// =============================================================================

class _TeacherScheduleHeader extends StatelessWidget {
  const _TeacherScheduleHeader({
    required this.onBack,
    required this.mode,
    required this.onModeChanged,
  });

  final VoidCallback onBack;
  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(68),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          topRight: Radius.circular(ui(16)),
        ),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
      ),
      child: Stack(
        children: [
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
          Positioned.fill(
            child: Center(
              child: Text(
                '授课课表',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(20),
            top: ui(18),
            child: _ViewEditSegment(mode: mode, onChanged: onModeChanged),
          ),
        ],
      ),
    );
  }
}

class _ViewEditSegment extends StatelessWidget {
  const _ViewEditSegment({required this.mode, required this.onChanged});

  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(32),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentChip(
            label: '查看',
            active: mode == _ScheduleMode.view,
            onTap: () => onChanged(_ScheduleMode.view),
          ),
          _SegmentChip(
            label: '编辑',
            active: mode == _ScheduleMode.edit,
            onTap: () => onChanged(_ScheduleMode.edit),
          ),
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
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: active ? Colors.white : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: active ? AppFont.w500 : AppFont.w400,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 控制条：教学周 + legend + 周切换 + 当周日期
// =============================================================================

class _TeacherScheduleControlBar extends StatelessWidget {
  const _TeacherScheduleControlBar({
    required this.week,
    required this.weekDateLabel,
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
    required this.onPickDate,
  });

  final int week;
  final String weekDateLabel;
  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                SizedBox(height: ui(8)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LegendItem(
                      dotColor: _kStatusPurple,
                      label: '大课',
                      tail: '不可编辑',
                    ),
                    SizedBox(width: ui(16)),
                    const _LegendItem(
                      dotColor: _kStatusGreen,
                      label: '小课',
                      tail: '编辑模式下可点击',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WeekSwitcher(onPrev: onPrev, onCurrent: onCurrent, onNext: onNext),
          SizedBox(width: ui(8)),
          _ControlPill(
            onTap: onPickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekDateLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(width: ui(8)),
                Icon(
                  Icons.calendar_today_rounded,
                  size: ui(14),
                  color: const Color(0xFF1C274C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.dotColor,
    required this.label,
    required this.tail,
  });

  final Color dotColor;
  final String label;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ui(6),
                height: ui(6),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ui(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          tail,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ],
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: child,
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
  });

  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ui(8))),
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
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
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
    required this.mode,
    required this.slots,
    required this.days,
    required this.cells,
    required this.onApplySmallLesson,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final totalHeight =
        ui(_kHeaderHeight) + slots.fold<double>(0, (s, e) => s + ui(e.height));
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimeColumn(slots: slots),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: ui(_kDayColWidth) * days.length,
                        child: _DaysArea(
                          mode: mode,
                          slots: slots,
                          days: days,
                          cells: cells,
                          onApplySmallLesson: onApplySmallLesson,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderSoft),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          const _TimeHeader(),
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
  const _TimeHeader();

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
      ..color = _kBorderSoft
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

class _DaysArea extends StatelessWidget {
  const _DaysArea({
    required this.mode,
    required this.slots,
    required this.days,
    required this.cells,
    required this.onApplySmallLesson,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DaysHeaderRow(days: days),
        for (var slotIdx = 0; slotIdx < slots.length; slotIdx++)
          _DayBodyRow(
            slotIdx: slotIdx,
            height: slots[slotIdx].height,
            mode: mode,
            rowCells: [
              for (var dayIdx = 0; dayIdx < days.length; dayIdx++)
                cells[dayIdx][slotIdx],
            ],
            onApplySmallLesson: onApplySmallLesson,
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
                color: days[i].today ? Colors.white : _kInnerGray,
                border: Border(
                  bottom: const BorderSide(color: _kBorderSoft),
                  left: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: _kBorderSoft),
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
                  SizedBox(height: ui(4)),
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
  const _DayBodyRow({
    required this.slotIdx,
    required this.height,
    required this.mode,
    required this.rowCells,
    required this.onApplySmallLesson,
  });

  final int slotIdx;
  final double height;
  final _ScheduleMode mode;
  final List<List<_ScheduleCardData>> rowCells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CellContent(
                      slotIdx: slotIdx,
                      slotHeight: height,
                      mode: mode,
                      cards: rowCells[i],
                      onApplySmallLesson: () => onApplySmallLesson(i, slotIdx),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(height: 1, color: _kBorderSoft),
                    ),
                  ),
                  if (i != 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(width: 1, color: _kBorderSoft),
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

class _CellContent extends StatelessWidget {
  const _CellContent({
    required this.slotIdx,
    required this.slotHeight,
    required this.mode,
    required this.cards,
    required this.onApplySmallLesson,
  });

  final int slotIdx;
  final double slotHeight;
  final _ScheduleMode mode;
  final List<_ScheduleCardData> cards;
  final VoidCallback onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEditing = mode == _ScheduleMode.edit;
    if (cards.isEmpty) {
      // 查看模式所有空格画 "空闲" 占位；编辑模式画 "申请小课" pill。
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
        child: isEditing
            ? Align(
                alignment: Alignment.topCenter,
                child: _ApplySmallLessonButton(onTap: onApplySmallLesson),
              )
            : const _IdleSlotPlaceholder(),
      );
    }
    // 编辑模式：无论本格当前是大课还是小课，都允许在卡片下方继续"申请小课"。
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: ui(6)),
            _ClassCard(
              data: cards[i],
              editable: isEditing && _isSmall(cards[i].kind),
            ),
          ],
          if (isEditing) ...[
            SizedBox(height: ui(8)),
            _ApplySmallLessonButton(onTap: onApplySmallLesson),
          ],
        ],
      ),
    );
  }

  bool _isSmall(_CardKind k) =>
      k == _CardKind.smallOrange || k == _CardKind.smallBlue;
}

class _IdleSlotPlaceholder extends StatelessWidget {
  const _IdleSlotPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kTextDivider, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        '空闲',
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 14,
        ),
      ),
    );
  }
}

class _ApplySmallLessonButton extends StatelessWidget {
  const _ApplySmallLessonButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ui(14),
              height: ui(14),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kTextHint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: ui(10), color: Colors.white),
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请小课',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 课卡（4 主题）
// =============================================================================

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data, required this.editable});

  final _ScheduleCardData data;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final theme = _themeFor(data);
    final cardHeight = data.kind == _CardKind.bigExtended ? 120.0 : 96.0;
    return MouseRegion(
      cursor: editable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Container(
        width: ui(176),
        height: ui(cardHeight),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Stack(
          children: [
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
            if (data.kind != _CardKind.bigExtended)
              Positioned(
                left: ui(126),
                top: ui(6),
                child: _ClassKindTag(isSmall: theme.isSmall, outlined: false),
              ),
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
            if (data.kind == _CardKind.bigExtended) ...[
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
                child: const _ClassKindTag(isSmall: false, outlined: true),
              ),
            ] else ...[
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
      ),
    );
  }

  _CardTheme _themeFor(_ScheduleCardData data) {
    switch (data.kind) {
      case _CardKind.smallOrange:
        return _CardTheme(
          bg: data.bgColor ?? _kSmallOrangeBg,
          titleColor: _kSmallOrangeTitle,
          isSmall: true,
        );
      case _CardKind.smallBlue:
        return _CardTheme(
          bg: data.bgColor ?? _kSmallBlueBg,
          titleColor: _kSmallBlueTitle,
          isSmall: true,
        );
      case _CardKind.bigStandard:
        return _CardTheme(
          bg: data.bgColor ?? _kBigStandardBg,
          titleColor: _kBigTitle,
          isSmall: false,
        );
      case _CardKind.bigExtended:
        return _CardTheme(
          bg: data.bgColor ?? _kBigExtendedBg,
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
// 申请「小课」右侧抽屉
//
// 入口：编辑模式格子内的"申请小课" pill → _onApplySmallLesson →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 设计：宽 600，全高，白底；顶部 62 高 _DrawerHeader（3×15 紫竖条 + "申请小课"
// 16/600 标题 + 关闭 X，底部 1px #F3F2F3 边）；表单 6 段：
//   1. 课程时间：只读 #F5F6FA 灰底 48 高
//   2. 班级：调 admin.classList，String id 下拉
//   3. 教室：调 admin.classroomList，int id 下拉
//   4. 科目：调 user.subjectList(classId)，int id 下拉
//   5. 颜色：13 色色板 + 当前 hex chip
//   6. 是否复用：不复用 / 本学期所有 / 后续 4 周 / 后续 8 周
// 底部：560×48 紫色横向渐变 (#B68EFF→#8640FF) "提交教务审核" 按钮。
//
// 提交：调 `/app/school/v2/teacher/schoolSmallCourseApplySave`，
// 字段格式：
// ```json
// {
//   "classId": "...",       // String，雪花
//   "classroomId": 1,       // int
//   "subjectId": 1,         // int
//   "color": "#xxxxxx",
//   "lineNum": 1,
//   "startDate": "2026-05-08",
//   "endDate": "2026-05-08",
//   "courseList": [
//     {
//       "classId": "...",
//       "classroomId": 1,
//       "subjectId": 1,
//       "color": "#xxxxxx",
//       "date": "2026-05-08",
//       "lineNum": 1
//     }
//   ]
// }
// ```
//
// 时间字段全部使用 `yyyy-MM-dd`（不带时区后缀，按需求统一）。
// =============================================================================

class _ApplySmallLessonDrawer extends ConsumerStatefulWidget {
  const _ApplySmallLessonDrawer({
    required this.slotLabel,
    required this.baseDateIso,
    required this.lineNum,
    required this.currentWeek,
    required this.onCancel,
    required this.onSubmitted,
    this.initialClassId,
  });

  /// 抽屉顶部只读"课程时间"展示，例如
  /// `第 1 节 08:00-08:40· 周一 2026-05-04`。
  final String slotLabel;

  /// 用户点击空格对应的当周日期（`yyyy-MM-dd`）。
  final String baseDateIso;

  /// 节次（与 schoolTimeConfigList.lineNum 对齐）。
  final int lineNum;

  /// 父页面当前显示的"教学周第 N 周"，复用模式按它计算还剩多少周。
  final int currentWeek;

  /// 父页面已知的默认班级（班级列表第一项）；非空时直接预选。
  final String? initialClassId;

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ApplySmallLessonDrawer> createState() =>
      _ApplySmallLessonDrawerState();
}

class _ApplySmallLessonDrawerState
    extends ConsumerState<_ApplySmallLessonDrawer> {
  // 班级 / 教室 / 科目下拉的 cache：(label, id)。
  List<({String id, String name})> _classes = const [];
  List<({String id, String name})> _classrooms = const [];
  List<({String id, String name})> _subjects = const [];

  String? _classId;
  String? _classroomId;
  String? _subjectId;
  bool _loadingSubjects = false;

  static const List<Color> _palette = <Color>[
    Color(0xFF1E1E1E),
    Color(0xFFE6D0FF),
    Color(0xFFD0E6FE),
    Color(0xFFFFEDD3),
    Color(0xFFD5CEC5),
    Color(0xFFD2C4FF),
    Color(0xFFADBFFF),
    Color(0xFFAAEBDD),
    Color(0xFFB1FFCE),
    Color(0xFFA894EB),
    Color(0xFF5EA9FF),
    Color(0xFF40E9A6),
    Color(0xFF74F0FE),
  ];

  Color _color = _palette[1];
  bool _customMode = false;
  String _reuse = '不复用';
  bool _submitting = false;

  static const List<String> _reuseOptions = <String>[
    '不复用',
    '本学期所有教学周',
    '后续 4 周',
    '后续 8 周',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  Future<void> _loadOptions() async {
    final adminRepo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      adminRepo.classList(),
      adminRepo.classroomList(),
    ]);
    if (!mounted) return;
    setState(() {
      _classes = _toOptions(
        results[0],
        idKeys: const ['id', 'classId', 'cId'],
        nameKeys: const ['className', 'class', 'name', 'fullName'],
      );
      _classrooms = _toOptions(
        results[1],
        idKeys: const ['id', 'classroomId', 'roomId'],
        nameKeys: const ['classroomName', 'roomName', 'name'],
      );
      // 父页面已选班级时优先回填；否则取列表第 1 项。
      final initial = widget.initialClassId;
      if (initial != null &&
          initial.isNotEmpty &&
          _classes.any((c) => c.id == initial)) {
        _classId = initial;
      } else {
        _classId ??= _classes.isNotEmpty ? _classes.first.id : null;
      }
      _classroomId ??= _classrooms.isNotEmpty ? _classrooms.first.id : null;
    });
    _loadSubjects(_classId);
  }

  Future<void> _loadSubjects(String? classId) async {
    setState(() => _loadingSubjects = true);
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.subjectList(classId: classId);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _subjects = const [];
        _subjectId = null;
        _loadingSubjects = false;
      });
      return;
    }
    final list = _toOptions(
      resp,
      idKeys: const ['id', 'subjectId'],
      nameKeys: const ['name', 'subjectName'],
    );
    setState(() {
      _subjects = list;
      if (_subjectId == null || !list.any((s) => s.id == _subjectId)) {
        _subjectId = list.isNotEmpty ? list.first.id : null;
      }
      _loadingSubjects = false;
    });
  }

  List<({String id, String name})> _toOptions(
    ApiResponse resp, {
    required List<String> idKeys,
    required List<String> nameKeys,
  }) {
    if (!resp.isSuccess) return const [];
    final rows = _extractList(resp);
    return [
      for (final m in rows)
        if (_pickString(m, idKeys, '').isNotEmpty &&
            _pickString(m, nameKeys, '').isNotEmpty)
          (id: _pickString(m, idKeys, ''), name: _pickString(m, nameKeys, '')),
    ];
  }

  String get _hexLabel {
    final argb = _color.toARGB32();
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// 根据 `_reuse` 选项展开成多个排课日期：
  ///   - 不复用 → 仅基准日 1 行
  ///   - 本学期所有教学周 → 从当前周开始补到第 [_kTermTotalWeeks] 周
  ///   - 后续 4 周 → 基准日 + 4 个连续周（共 5 行）
  ///   - 后续 8 周 → 基准日 + 8 个连续周（共 9 行）
  List<DateTime> _computeReuseDates() {
    final base = DateTime.tryParse(widget.baseDateIso) ?? DateTime.now();
    int extraWeeks;
    switch (_reuse) {
      case '本学期所有教学周':
        extraWeeks = (_kTermTotalWeeks - widget.currentWeek).clamp(
          0,
          _kTermTotalWeeks,
        );
        break;
      case '后续 4 周':
        extraWeeks = 4;
        break;
      case '后续 8 周':
        extraWeeks = 8;
        break;
      case '不复用':
      default:
        extraWeeks = 0;
    }
    return [
      for (var i = 0; i <= extraWeeks; i++) base.add(Duration(days: i * 7)),
    ];
  }

  /// `2026-05-04` 格式（无时间，无时区）。
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (_classId == null || _classId!.isEmpty) {
      AppToast.show(context, '请先选择班级');
      return;
    }
    if (_classroomId == null || _classroomId!.isEmpty) {
      AppToast.show(context, '请先选择教室');
      return;
    }
    if (_subjectId == null || _subjectId!.isEmpty) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    setState(() => _submitting = true);

    // classroomId / subjectId 后端期望 int；雪花长 classId 走 String。
    final classroomNum = int.tryParse(_classroomId!);
    final subjectNum = int.tryParse(_subjectId!);

    final dates = _computeReuseDates();
    final color = _hexLabel;
    final courseList = <Map<String, dynamic>>[
      for (final d in dates)
        <String, dynamic>{
          'classId': _classId,
          'classroomId': classroomNum ?? _classroomId,
          'subjectId': subjectNum ?? _subjectId,
          'color': color,
          'date': _ymd(d),
          'lineNum': widget.lineNum,
        },
    ];

    final body = <String, dynamic>{
      'classId': _classId,
      'classroomId': classroomNum ?? _classroomId,
      'subjectId': subjectNum ?? _subjectId,
      'color': color,
      'lineNum': widget.lineNum,
      'startDate': _ymd(dates.first),
      'endDate': _ymd(dates.last),
      'courseList': courseList,
    };

    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplySave(body);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '提交失败' : resp.msg);
      return;
    }
    if (courseList.length > 1) {
      AppToast.show(context, '已提交申请（共 ${courseList.length} 周）');
    }
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(600),
      height: double.infinity,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _DrawerHeader(title: '申请小课', onClose: widget.onCancel),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(
                      icon: Icons.access_time_rounded,
                      label: '课程时间',
                    ),
                    SizedBox(height: ui(12)),
                    _ReadonlyField(text: widget.slotLabel),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(label: '班级'),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classId ?? '',
                      items: [for (final c in _classes) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择班级';
                        return _classes
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) {
                        setState(() => _classId = v);
                        _loadSubjects(v);
                      },
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      '课表展示为「小班·班级名」，无需再选教学组织形式。',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDivider,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.meeting_room_outlined,
                      label: '教室',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classroomId ?? '',
                      items: [for (final c in _classrooms) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择教室';
                        return _classrooms
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _classroomId = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.menu_book_outlined,
                      label: '科目',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _subjectId ?? '',
                      items: [for (final s in _subjects) s.id],
                      itemLabel: (id) {
                        if (id.isEmpty) {
                          return _loadingSubjects ? '加载中…' : '选择科目';
                        }
                        return _subjects
                            .firstWhere(
                              (s) => s.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _subjectId = v),
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.palette_outlined,
                      label: '颜色',
                    ),
                    SizedBox(height: ui(12)),
                    _ColorSwatchRow(
                      colors: _palette,
                      selected: _customMode ? null : _color,
                      onSelect: (c) => setState(() {
                        _color = c;
                        _customMode = false;
                      }),
                    ),
                    SizedBox(height: ui(12)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ColorModeChip(
                          label: _hexLabel,
                          selected: !_customMode,
                          onTap: () => setState(() => _customMode = false),
                        ),
                        SizedBox(width: ui(12)),
                        _ColorModeChip(
                          label: '取色',
                          selected: _customMode,
                          onTap: () => setState(() => _customMode = true),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    const _SectionLabel(
                      icon: Icons.copy_outlined,
                      label: '是否复用',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _reuse,
                      items: _reuseOptions,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _reuse = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
              child: _SubmitGradientButton(
                label: _submitting ? '提交中…' : '提交教务审核',
                onTap: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉顶部 62 高 header：3×15 紫竖条 + 标题 + 关闭 X。
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(3.25),
            height: ui(15),
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: ui(16),
          height: ui(16),
          child: icon == null
              ? null
              : Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kInnerGray, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            _ColorSwatch(
              color: colors[i],
              isSelected: selected == colors[i],
              onTap: () => onSelect(colors[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: ui(20),
        height: ui(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white : color,
          border: Border.all(
            color: isSelected ? color : _kBorderSoft,
            width: 1,
          ),
        ),
        child: isSelected
            ? Container(
                width: ui(14),
                height: ui(14),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              )
            : null,
      ),
    );
  }
}

class _ColorModeChip extends StatelessWidget {
  const _ColorModeChip({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(48), vertical: ui(12)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFE5FF) : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: selected ? Border.all(color: _kPurple, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(16),
            color: selected ? _kPurple : Colors.black,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SubmitGradientButton extends StatelessWidget {
  const _SubmitGradientButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(16),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 通用 helpers（与 admin / 学生端一致的解析函数）
// =============================================================================

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  dynamic raw = resp.data;
  // 兼容 `{ data: [...] }` / `{ data: { records, total } }` 多包一层。
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
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

/// `09:00:00` → `09:00`（兼容已经是 `09:00` 的情况）。
String _trimToHm(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return s;
}

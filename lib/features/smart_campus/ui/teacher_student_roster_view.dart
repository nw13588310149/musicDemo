// =============================================================================
// 任课老师 / 班主任端「学生名册」独立页面
//
// 入口：教师 dashboard 快捷区「学生名册」按钮 → controller.openStudentRoster()
//      → mainView == studentRoster + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：背景图 xiaoquan/bg.png；左返回；居中 "学生名册"
//   2. 筛选行：班级 dropdown + 搜索框
//   3. 三张统计卡：当前列表 / 男 / 女
//   4. 学生卡 3 列网格（对齐管理员「学生管理」）：姓名+学号 / 班级 / 住宿 +
//      右上角学籍状态徽章；整卡可点 → 右侧「学生档案」抽屉（含成绩走势）。
// =============================================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../data/teacher_repository.dart';
import '../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 配色 -------------------------------------------------------------------
const Color _kCardBg = Colors.white;
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextPrimary = Color(0xFF0B081A);
const Color _kTextSub = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kSearchIcon = Color(0xFFC6C6C6);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoft = Color(0xFFDAD2FF);
const Color _kPageBgChip = Color(0xFFF5F6FA);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kPurpleTag = Color(0xFFA773FF);

// ---- 学籍状态 ---------------------------------------------------------------

enum _StudentStatus { enrolled, suspended, transferring, graduated }

_StudentStatus _parseStudentStatus(dynamic raw) {
  if (raw == null) return _StudentStatus.enrolled;
  final s = raw.toString().toLowerCase();
  if (s == '1' || s == 'enrolled' || raw.toString().contains('在籍')) {
    return _StudentStatus.enrolled;
  }
  if (s == '2' || s == 'suspended' || raw.toString().contains('休学')) {
    return _StudentStatus.suspended;
  }
  if (s == '3' || s == 'transferring' || raw.toString().contains('转学')) {
    return _StudentStatus.transferring;
  }
  if (s == '4' || s == 'graduated' || raw.toString().contains('毕业')) {
    return _StudentStatus.graduated;
  }
  return _StudentStatus.enrolled;
}

extension on _StudentStatus {
  String get label {
    switch (this) {
      case _StudentStatus.enrolled:
        return '在籍';
      case _StudentStatus.suspended:
        return '休学';
      case _StudentStatus.transferring:
        return '转学';
      case _StudentStatus.graduated:
        return '毕业';
    }
  }

  Color get bg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurpleSoft;
      case _StudentStatus.suspended:
        return const Color(0xFFFFE7C2);
      case _StudentStatus.transferring:
        return const Color(0xFFD2EAFF);
      case _StudentStatus.graduated:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get fg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurple;
      case _StudentStatus.suspended:
        return const Color(0xFFE89B30);
      case _StudentStatus.transferring:
        return const Color(0xFF1F77E0);
      case _StudentStatus.graduated:
        return const Color(0xFF6D6B75);
    }
  }
}

// ---- 数据模型 ---------------------------------------------------------------

class _Student {
  const _Student({
    required this.userId,
    required this.name,
    required this.studentId,
    required this.classInfo,
    required this.dormInfo,
    required this.status,
    this.avatarUrl = '',
    this.faceImgUrl = '',
    this.tags = const [],
    this.direction = '—',
    this.adminClass = '—',
    this.dorm = '—',
    this.phone = '—',
    this.parentPhone = '—',
    this.recentChange = '无',
    this.remark = '—',
    this.gender = '',
  });

  final String userId;
  final String name;
  final String studentId;
  final String classInfo;
  final String dormInfo;
  final _StudentStatus status;
  final String avatarUrl;
  final String faceImgUrl;
  final List<String> tags;
  final String direction;
  final String adminClass;
  final String dorm;
  final String phone;
  final String parentPhone;
  final String recentChange;
  final String remark;
  final String gender;

  bool get isMale {
    final g = gender.trim();
    return g == '1' || g == '男';
  }

  factory _Student.fromJson(Map<String, dynamic> json) {
    final nickname = _pickString(json, ['nickname', 'nickName'], '');
    final realname = _pickString(json, ['realname', 'realName'], '');
    final name = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty
            ? realname
            : _pickString(json, ['name', 'stuName', 'studentName'], '未命名'));

    final headUrlRaw =
        _pickString(json, ['headUrl', 'avatar', 'avatarUrl'], '');
    final avatarUrl =
        headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : '';

    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'studentId',
      'stuNo',
      'stuId',
      'code',
      'studentCode',
    ], '');

    var className = '';
    final bigClass = json['bigClass'];
    if (bigClass is Map) {
      className = _pickString(
        Map<String, dynamic>.from(bigClass),
        ['name', 'className', 'groupName', 'fullName'],
        '',
      );
    }
    if (className.isEmpty) {
      className = _pickString(json, [
        'className',
        'class',
        'gradeName',
        'classFullName',
      ], '');
    }

    final directionName = _pickString(json, [
      'directionName',
      'direction',
      'directionText',
      'majorDirection',
    ], '—');

    final bedInfo = _pickString(json, ['bedInfo'], '');
    final bedIdRaw = json['bedId'];
    final hasBedId = bedIdRaw != null &&
        '$bedIdRaw'.trim().isNotEmpty &&
        '$bedIdRaw' != '0' &&
        bedIdRaw != 0;
    final isLiving = hasBedId || bedInfo.isNotEmpty;
    final dormName = bedInfo.isNotEmpty
        ? bedInfo
        : _pickString(json, [
            'dorm',
            'dormName',
            'roomName',
            'apartment',
            'dormitory',
          ], '');

    final phone = _pickString(json, [
      'phone',
      'mobile',
      'studentPhone',
      'stuPhone',
      'tel',
    ], '');
    final parentPhone = _pickString(json, [
      'parentPhone',
      'parentMobile',
      'fatherPhone',
      'motherPhone',
      'guardianPhone',
      'guardianMobile',
    ], phone);
    final remark = _pickString(json, [
      'remark',
      'comment',
      'description',
      'note',
      'introduce',
    ], '');
    final gender = _pickString(json, ['gender', 'sex'], '');
    final faceImgRaw = _pickString(json, ['faceImg'], '');
    final tags = _parseTags(json['tags']);

    final classInfo = className.isEmpty ? '—' : className;
    final dormInfo = isLiving
        ? (dormName.isEmpty ? '宿舍' : '宿舍·$dormName')
        : '走读';

    final userId =
        readSnowflakeId(json['id'] ?? json['userId'] ?? json['stuId']) ?? '';

    return _Student(
      userId: userId,
      name: name,
      studentId: studentNo,
      classInfo: classInfo,
      dormInfo: dormInfo,
      status: _parseStudentStatus(
        json['studentStatus'] ?? json['status'] ?? json['stuStatus'],
      ),
      avatarUrl: avatarUrl,
      faceImgUrl: faceImgRaw,
      tags: tags,
      direction: directionName,
      adminClass: className.isEmpty ? '—' : className,
      dorm: isLiving ? (dormName.isEmpty ? '宿舍' : dormName) : '走读',
      phone: phone.isEmpty ? '—' : phone,
      parentPhone: parentPhone.isEmpty ? '—' : parentPhone,
      recentChange: _pickString(json, [
        'lastChange',
        'recentChange',
        'changeDesc',
        'transferRemark',
      ], '无'),
      remark: remark.isEmpty ? '—' : remark,
      gender: gender,
    );
  }
}

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

List<String> _parseTags(dynamic raw) {
  if (raw == null) return const [];
  final s = raw.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return const [];
  return s
      .split(RegExp(r'[,，]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

String? _nonEmptyStr(dynamic v) {
  final s = v?.toString().trim();
  return (s != null && s.isNotEmpty) ? s : null;
}

Map<String, dynamic>? _mapDataToStringKeyed(dynamic raw) {
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(
    raw.map((k, v) => MapEntry(k.toString(), v)),
  );
}

String _detailPick(
  Map<String, dynamic>? m,
  List<String> keys, [
  String fallback = '',
]) {
  if (m == null) return fallback;
  for (final k in keys) {
    final v = _nonEmptyStr(m[k]);
    if (v != null) return v;
  }
  return fallback;
}

String _resolveHeadUrl(_Student row, Map<String, dynamic>? d) {
  final raw = _nonEmptyStr(d?['headUrl']) ?? _nonEmptyStr(d?['avatar']);
  if (raw != null) return MediaUrl.resolve(raw);
  return row.avatarUrl;
}

const _kAllClassesLabel = '全部班级';

class _RosterClassOption {
  const _RosterClassOption({required this.id, required this.label});
  final String id;
  final String label;
}

List<Map<dynamic, dynamic>> _coerceRecords(dynamic raw) {
  if (raw is Map) {
    final inner = raw['records'] ?? raw['list'] ?? raw['data'];
    if (inner is List) {
      return inner.whereType<Map>().toList();
    }
    return const [];
  }
  if (raw is List) return raw.whereType<Map>().toList();
  return const [];
}

// =============================================================================
// 入口 view
// =============================================================================

class TeacherStudentRosterView extends ConsumerStatefulWidget {
  const TeacherStudentRosterView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherStudentRosterView> createState() =>
      _TeacherStudentRosterViewState();
}

class _TeacherStudentRosterViewState extends ConsumerState<TeacherStudentRosterView> {
  static const int _pageSize = 50;
  String _query = '';
  String _debouncedKeyword = '';
  Timer? _searchDebounce;

  List<_RosterClassOption> _classOptions = [
    const _RosterClassOption(id: '', label: _kAllClassesLabel),
  ];
  String _selectedClassId = '';
  String _selectedClassLabel = _kAllClassesLabel;

  List<_Student> _all = [];
  int _listTotal = 0;
  bool _loadingClasses = true;
  bool _loadingStudents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _loadingClasses = true);
    final res = await ref.read(teacherRepositoryProvider).classList();
    if (!mounted) return;
    final opts = <_RosterClassOption>[
      const _RosterClassOption(id: '', label: _kAllClassesLabel),
    ];
    if (res.isSuccess) {
      final raw = res.data;
      final list = raw is Map ? (raw['records'] ?? raw['list'] ?? raw['data']) : raw;
      if (list is List) {
        for (final row in list.whereType<Map>()) {
          final id = row['id']?.toString().trim() ?? row['classId']?.toString().trim() ?? '';
          final name = row['name']?.toString().trim() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            opts.add(_RosterClassOption(id: id, label: name));
          }
        }
      }
    }
    setState(() {
      _classOptions = opts;
      _loadingClasses = false;
    });
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() => _loadingStudents = true);
    final res = await ref.read(teacherRepositoryProvider).studentList(
          classId: _selectedClassId,
          current: 1,
          size: _pageSize,
          keyword: _debouncedKeyword,
        );
    if (!mounted) return;
    var rows = <Map<dynamic, dynamic>>[];
    var total = 0;
    if (res.isSuccess) {
      final raw = res.data;
      if (raw is Map) {
        total = int.tryParse(raw['total']?.toString() ?? '') ?? 0;
        rows = _coerceRecords(raw);
      } else {
        rows = _coerceRecords(raw);
      }
    } else if (res.msg.isNotEmpty) {
      AppToast.show(context, res.msg);
    }
    setState(() {
      _all = rows
          .map((m) => _Student.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _listTotal = total > 0 ? total : _all.length;
      _loadingStudents = false;
    });
  }

  void _openProfile(_Student s) {
    _openStudentDetailDrawer(context, s);
  }

  void _onClassPicked(_RosterClassOption opt) {
    setState(() {
      _selectedClassId = opt.id;
      _selectedClassLabel = opt.label;
    });
    _loadStudents();
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _debouncedKeyword = v.trim());
      _loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _all;
    final maleCount = list.where((s) => s.isMale).length;
    final femaleCount = list.length - maleCount;
    final totalForStats = _listTotal > 0 ? _listTotal : list.length;
    final pageLoading = _loadingClasses || (_loadingStudents && list.isEmpty);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RosterBanner(onBack: widget.onBack),
          SizedBox(height: ui(16)),
          MainContentLoadingShell(
            loading: pageLoading,
            preserveChrome: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterRow(
                  classOptions: _classOptions,
                  selectedLabel: _selectedClassLabel,
                  onClassPicked: _onClassPicked,
                  query: _query,
                  onQueryChanged: _onQueryChanged,
                ),
                SizedBox(height: ui(16)),
                _StatsRow(
                  total: totalForStats,
                  male: maleCount,
                  female: femaleCount,
                ),
                SizedBox(height: ui(20)),
                if (!_loadingStudents && list.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: ui(48)),
                      child: Text(
                        '暂无学生数据',
                        style: TextStyle(fontSize: ui(14), color: _kTextHint),
                      ),
                    ),
                  )
                else if (!pageLoading)
                  _StudentCardsGrid(
                    students: list,
                    onTap: _openProfile,
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
// 顶部 banner（背景图 xiaoquan/bg.png，居中标题 + 左返回）
// =============================================================================

class _RosterBanner extends StatelessWidget {
  const _RosterBanner({required this.onBack});

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
                '学生名册',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1.2,
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
// 筛选行：班级 dropdown + 搜索框
// =============================================================================

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.classOptions,
    required this.selectedLabel,
    required this.onClassPicked,
    required this.query,
    required this.onQueryChanged,
  });

  final List<_RosterClassOption> classOptions;
  final String selectedLabel;
  final ValueChanged<_RosterClassOption> onClassPicked;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ClassFilterButton(
          value: selectedLabel,
          options: classOptions,
          onChanged: onClassPicked,
        ),
        SizedBox(
          width: ui(324),
          child: _RosterSearchField(value: query, onChanged: onQueryChanged),
        ),
      ],
    );
  }
}

class _ClassFilterButton extends StatefulWidget {
  const _ClassFilterButton({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_RosterClassOption> options;
  final ValueChanged<_RosterClassOption> onChanged;

  @override
  State<_ClassFilterButton> createState() => _ClassFilterButtonState();
}

class _ClassFilterButtonState extends State<_ClassFilterButton> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    final renderBox = fieldCtx.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = renderBox.size;
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    setState(() => _open = true);
    final selected = await showMenu<_RosterClassOption>(
      context: context,
      elevation: 0,
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // 班级名称比按钮长，菜单宽度放到 180，避免长 label 截断。
      constraints: BoxConstraints.tightFor(width: ui(180)),
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + size.height + ui(4),
        overlayBox.size.width - origin.dx - ui(180),
        overlayBox.size.height - origin.dy - size.height,
      ),
      items: <PopupMenuEntry<_RosterClassOption>>[
        PopupMenuItem<_RosterClassOption>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: DashboardScaleScope(
            data: scale,
            child: _ClassFilterMenuPanel(
              options: widget.options,
              value: widget.value,
              onPick: (opt) => Navigator.of(context).pop<_RosterClassOption>(opt),
            ),
          ),
        ),
      ],
    );
    if (mounted) setState(() => _open = false);
    if (selected != null && selected.label != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        key: _fieldKey,
        width: ui(120),
        height: ui(44),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: _kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassFilterMenuPanel extends StatelessWidget {
  const _ClassFilterMenuPanel({
    required this.options,
    required this.value,
    required this.onPick,
  });

  final List<_RosterClassOption> options;
  final String value;
  final ValueChanged<_RosterClassOption> onPick;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF95A6C8).withValues(alpha: 0.10),
            blurRadius: ui(20),
            offset: Offset(0, ui(8)),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: ui(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            _ClassFilterMenuRow(
              label: opt.label,
              selected: opt.label == value,
              onTap: () => onPick(opt),
            ),
        ],
      ),
    );
  }
}

class _ClassFilterMenuRow extends StatelessWidget {
  const _ClassFilterMenuRow({
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
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: selected ? _kPurple : _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: selected ? AppFont.w500 : AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: ui(16), color: _kPurple),
          ],
        ),
      ),
    );
  }
}

class _RosterSearchField extends StatefulWidget {
  const _RosterSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_RosterSearchField> createState() => _RosterSearchFieldState();
}

class _RosterSearchFieldState extends State<_RosterSearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _RosterSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级清空 query 时同步到 controller，避免外部 reset 时输入框残留旧值。
    if (widget.value != _ctrl.text) {
      _ctrl.text = widget.value;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: ui(16), color: _kSearchIcon),
          SizedBox(width: ui(8)),
          Expanded(
            child: AppTextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '搜索姓名、工号、任课方向',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextPlaceholder,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
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
// 三张统计卡（当前列表 / 男 / 女）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.male,
    required this.female,
  });

  final int total;
  final int male;
  final int female;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(100),
      child: Row(
        children: [
          Expanded(
            child: _StatTrioCard(
              label: '当前列表',
              value: '$total',
              gradientColor: const Color(0xFFE7DCFF),
              decoColor: const Color(0xFFD5BEFF),
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: _StatTrioCard(
              label: '男',
              value: '$male',
              gradientColor: const Color(0xFFDCFFE7),
              decoColor: const Color(0xFF85FFAD),
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: _StatTrioCard(
              label: '女',
              value: '$female',
              gradientColor: const Color(0xFFFFE2DC),
              decoColor: const Color(0xFFFFB199),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTrioCard extends StatelessWidget {
  const _StatTrioCard({
    required this.label,
    required this.value,
    required this.gradientColor,
    required this.decoColor,
  });

  final String label;
  final String value;
  final Color gradientColor;
  final Color decoColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      // 装饰圆刻意贴右下且尺寸偏大，超出 Stack 内层 paint 区会触发 paint 期
      // overflow 警告；让 Container 自身按圆角裁剪，过界部分静默裁掉即可。
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        gradient: LinearGradient(
          // Figma：196° 渐变；Flutter Alignment 对应大致从右下偏左 → 左上偏右。
          begin: const Alignment(0.4, 1.0),
          end: const Alignment(-0.2, -1.0),
          stops: const [0.0, 0.73],
          colors: [gradientColor, Colors.white],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(14)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
              SizedBox(height: ui(14)),
              Text(
                value,
                style: TextStyle(
                  fontSize: ui(32),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          // 右下半透柔和装饰圈（Figma 上是渐变方块，我们用半透圆形近似）。
          Positioned(
            right: ui(8),
            top: ui(20),
            child: Container(
              width: ui(54),
              height: ui(54),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    decoColor.withValues(alpha: 0.40),
                    decoColor.withValues(alpha: 0.06),
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
// 学生卡 3 列网格（对齐管理员「学生管理」）
// =============================================================================

class _StudentCardsGrid extends StatelessWidget {
  const _StudentCardsGrid({
    required this.students,
    required this.onTap,
  });

  final List<_Student> students;
  final ValueChanged<_Student> onTap;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return _RosterEmptyState();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cols = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 600 ? 2 : 1);
        final cardWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in students)
              SizedBox(
                width: cardWidth,
                child: _StudentCard(student: s, onTap: () => onTap(s)),
              ),
          ],
        );
      },
    );
  }
}

class _RosterEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, size: ui(40), color: _kTextHint),
          SizedBox(height: ui(8)),
          Text(
            '没有匹配的学生',
            style: TextStyle(
              fontSize: ui(14),
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

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final _Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(78),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(46), ui(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: student.name, avatarUrl: student.avatarUrl),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: TextStyle(
                                  fontSize: ui(14),
                                  height: 1.0,
                                  fontWeight: AppFont.w500,
                                  color: _kTextPrimary,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ),
                            if (student.studentId.isNotEmpty) ...[
                              SizedBox(width: ui(8)),
                              Text(
                                student.studentId,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: ui(4)),
                        Text(
                          student.classInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextPrimary,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(4)),
                        Text(
                          student.dormInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextSub,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                height: ui(22),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: student.status.bg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(12)),
                    bottomLeft: Radius.circular(ui(12)),
                  ),
                ),
                child: Text(
                  student.status.label,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.0,
                    color: student.status.fg,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl = '', this.size = 40});

  final String name;
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    final placeholder = Container(
      width: ui(size),
      height: ui(size),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kPurpleSoft,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(size * 0.4),
          fontWeight: AppFont.w500,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    if (avatarUrl.trim().isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(size),
        height: ui(size),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

// =============================================================================
// 学生档案右侧抽屉
//
// 触发：学生卡 "详情 ›" 链接。视觉对齐 Figma 600 宽×自适应高（820 设计高）：
//   1. 顶部 "学生档案" 标题（紫条 + 16/600 黑字 + 1px #F3F2F3 底分隔线）
//   2. Profile：avatar 40 + 姓名 16/600 + 学号 12/400 #B6B5BB + 主项 "声乐 ·
//      民族唱法" 12/400 #6D6B75
//   3. 信息列表（每行 14/400 标签 #B6B5BB + 14/400 值 #0B081A）：
//      性别 / 住宿 / 本人手机 / 家长手机 / 所在班级（灰底 tag）/ 标签（紫底 badge）
//   4. "教师备注" 灰底卡（16/600 标题 + 14/400 备注）
//   5. "我教科目 · 分数走势" 灰底卡（顶部副标 + 科目切换 [声乐/乐理] +
//      6 期 X 轴（2-6月+期中）+ Y 轴 100/95/90/85/80/0 + 紫色 outline
//      polyline + 渐变填充 + 6 个白底紫边圆点 + 数值标签）
//   6. "联系家长" 紫色 #B68EFF→#8640FF 渐变 CTA（48 高，圆角 12，phone icon）
//
// 接口：barrierDismissible = true，从右侧滑入；底层用 showGeneralDialog +
//      Align(centerRight) + SlideTransition，与"申请小课"右抽屉同一套模式。
// =============================================================================

void _openStudentDetailDrawer(BuildContext context, _Student data) {
  final scale = DashboardScaleScope.of(context);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭学生档案',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim, sec) {
      return Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _StudentDetailDrawer(data: data),
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

class _StudentDetailDrawer extends ConsumerStatefulWidget {
  const _StudentDetailDrawer({required this.data});

  final _Student data;

  @override
  ConsumerState<_StudentDetailDrawer> createState() =>
      _StudentDetailDrawerState();
}

class _StudentDetailDrawerState extends ConsumerState<_StudentDetailDrawer> {
  // 0 = 声乐 / 1 = 乐理（与 Figma toggle 顺序一致）。
  int _subjectIdx = 0;

  Map<String, dynamic>? _detail;
  List<String> _scoreSubjects = const [];
  Map<String, List<double>> _scoresBySubject = const {};
  Map<String, List<String>> _periodsBySubject = const {};
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = widget.data.userId.trim();
    if (id.isEmpty) return;
    setState(() => _detailLoading = true);
    final repo = ref.read(teacherRepositoryProvider);
    final results = await Future.wait([
      repo.studentDetail(id: id),
      repo.studentExamRecordList(studentId: id),
    ]);
    if (!mounted) return;
    final res = results[0];
    final scoreRes = results[1];
    final scoreData = scoreRes.isSuccess
        ? _parseStudentScoreSeries(scoreRes.data)
        : const _StudentScoreSeries();
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _detailLoading = false;
        _detail = _mapDataToStringKeyed(res.data);
        _scoreSubjects = scoreData.subjects;
        _scoresBySubject = scoreData.scores;
        _periodsBySubject = scoreData.periods;
        _subjectIdx = 0;
      });
    } else {
      setState(() => _detailLoading = false);
      if (!res.isSuccess) {
        AppToast.show(
          context,
          res.msg.isNotEmpty ? res.msg : '加载学生详情失败',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = widget.data;
    final d = _detail;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_detailLoading)
                  LinearProgressIndicator(
                    minHeight: ui(2),
                    color: _kPurple,
                    backgroundColor: _kPageBgChip,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: ui(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DrawerTitleBar(),
                        SizedBox(height: ui(16)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ui(20)),
                          child: _ProfileBlock(data: data, detail: d),
                        ),
                        SizedBox(height: ui(16)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ui(20)),
                          child: _InfoList(data: data, detail: d),
                        ),
                        SizedBox(height: ui(20)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ui(20)),
                          child: _TeacherRemarksBlock(
                            remark: _detailPick(d, const ['remark'], ''),
                          ),
                        ),
                        SizedBox(height: ui(12)),
                        if (_scoreSubjects.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: ui(20)),
                            child: _ScoreChartBlock(
                              subjects: _scoreSubjects,
                              subjectIdx: _subjectIdx,
                              onSubjectChanged: (i) =>
                                  setState(() => _subjectIdx = i),
                              values:
                                  _scoresBySubject[_scoreSubjects[_subjectIdx]]!,
                              periods:
                                  _periodsBySubject[_scoreSubjects[_subjectIdx]]!,
                            ),
                          ),
                        SizedBox(height: ui(20)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ui(20)),
                          child: _ContactParentButton(
                            onTap: () => _showParentContactDialog(
                              context,
                              data,
                              detail: d,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(16)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
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
            '学生档案',
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.data, this.detail});

  final _Student data;
  final Map<String, dynamic>? detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final d = detail;
    final displayName = _nonEmptyStr(d?['realname']) ??
        _nonEmptyStr(d?['nickname']) ??
        data.name;
    final idLine = _nonEmptyStr(d?['studentNo']) ??
        _nonEmptyStr(d?['code']) ??
        data.studentId;
    final subtitle = _nonEmptyStr(d?['major']) ??
        _nonEmptyStr(d?['introduce']) ??
        (data.direction != '—' ? data.direction : null);
    final head = _resolveHeadUrl(data, d);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(name: displayName, avatarUrl: head, size: 40),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: Colors.black,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Text(
                    idLine,
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
              SizedBox(height: ui(6)),
              Text(
                subtitle ?? '—',
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
        ),
      ],
    );
  }
}

class _InfoList extends StatelessWidget {
  const _InfoList({required this.data, this.detail});

  final _Student data;
  final Map<String, dynamic>? detail;

  String _genderLine() {
    final g = _nonEmptyStr(detail?['gender']) ?? '';
    if (g == '1' || g == '男' || g == 'm' || g == 'M') return '男';
    if (g == '2' || g == '女' || g == 'f' || g == 'F') return '女';
    return data.isMale ? '男' : '女';
  }

  String _dormLine() {
    final v = _detailPick(
      detail,
      const ['dormitory', 'dorm'],
      data.dorm,
    );
    return v.trim().isEmpty ? '—' : v;
  }

  List<String> _classTags() {
    final d = detail;
    final cn = _nonEmptyStr(d?['className']);
    if (cn != null) {
      final role =
          _nonEmptyStr(d?['classRole']) ?? _nonEmptyStr(d?['role']);
      return role != null ? <String>[cn, role] : <String>[cn];
    }
    if (data.classInfo.isNotEmpty && data.classInfo != '—') {
      return [data.classInfo];
    }
    return const [];
  }

  List<String> _badgeTags() {
    final raw = _nonEmptyStr(detail?['tags']);
    if (raw != null) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return data.tags;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final d = detail;
    final mobile = _detailPick(
      d,
      const ['mobile', 'phone'],
      data.phone,
    );
    final parentPhone = _detailPick(
      d,
      const ['parentMobile', 'guardianMobile', 'parentPhone'],
      data.parentPhone,
    );
    final classTags = _classTags();
    final badges = _badgeTags();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: '性别：', value: _genderLine()),
        SizedBox(height: ui(8)),
        _InfoRow(label: '住宿：', value: _dormLine()),
        SizedBox(height: ui(8)),
        _InfoRow(label: '本人手机：', value: mobile.isEmpty ? '—' : mobile),
        SizedBox(height: ui(8)),
        _InfoRow(
          label: '家长手机：',
          value: parentPhone.isEmpty ? '—' : parentPhone,
        ),
        SizedBox(height: ui(8)),
        if (classTags.isNotEmpty)
          _InfoTagRow(label: '所在班级：', tags: classTags, isAccent: false),
        if (classTags.isNotEmpty) SizedBox(height: ui(8)),
        if (badges.isNotEmpty)
          _InfoTagRow(label: '标签：', tags: badges, isAccent: true),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTagRow extends StatelessWidget {
  const _InfoTagRow({
    required this.label,
    required this.tags,
    required this.isAccent,
  });

  final String label;
  final List<String> tags;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pills = <Widget>[
      for (final t in tags) _DrawerTagPill(label: t, isAccent: isAccent),
    ];
    final children = <Widget>[];
    for (var i = 0; i < pills.length; i++) {
      if (i > 0) children.add(SizedBox(width: ui(4)));
      children.add(pills[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        // 单行 tag 流：与学生卡一致，溢出时静默水平裁剪，不换行也不报
        // BOTTOM OVERFLOWED；高度统一 20 容纳 12px tag 文本。
        Expanded(
          child: SizedBox(
            height: ui(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ],
    );
  }
}

/// 抽屉中 12px 字体的 tag（与卡片上 11px tag 区分；颜色配置一致）。
class _DrawerTagPill extends StatelessWidget {
  const _DrawerTagPill({required this.label, required this.isAccent});

  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isAccent ? _kPurpleTag : _kPageBgChip,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: isAccent ? Colors.white : _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.27,
        ),
      ),
    );
  }
}

class _TeacherRemarksBlock extends StatelessWidget {
  const _TeacherRemarksBlock({required this.remark});

  final String remark;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final text = remark.trim().isEmpty ? '暂无教师备注。' : remark.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPageBgChip,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '教师备注',
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 我教科目 · 分数走势（灰底卡 + 副标 + 科目切换 + 折线图）
// =============================================================================

class _StudentScoreSeries {
  const _StudentScoreSeries({
    this.subjects = const [],
    this.scores = const {},
    this.periods = const {},
  });

  final List<String> subjects;
  final Map<String, List<double>> scores;
  final Map<String, List<String>> periods;
}

_StudentScoreSeries _parseStudentScoreSeries(dynamic raw) {
  dynamic value = raw;
  if (value is Map) {
    value = value['records'] ?? value['list'] ?? value['rows'] ?? value['data'];
  }
  if (value is! List) return const _StudentScoreSeries();
  final scores = <String, List<double>>{};
  final periods = <String, List<String>>{};
  for (final item in value.whereType<Map>()) {
    final subject = _firstScoreString(item, const [
      'subjectName',
      'subject',
      'courseName',
    ]);
    final score = double.tryParse(
      _firstScoreString(item, const ['score', 'studentScore', 'examScore']),
    );
    if (subject.isEmpty || score == null) continue;
    scores.putIfAbsent(subject, () => <double>[]).add(score);
    periods.putIfAbsent(subject, () => <String>[]).add(
          _firstScoreString(
            item,
            const ['examName', 'name', 'examDate', 'createTime'],
            fallback: '考试${scores[subject]!.length}',
          ),
        );
  }
  final subjects = scores.keys.where((key) => scores[key]!.isNotEmpty).toList();
  return _StudentScoreSeries(
    subjects: subjects,
    scores: scores,
    periods: periods,
  );
}

String _firstScoreString(
  Map<dynamic, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

class _ScoreChartBlock extends StatelessWidget {
  const _ScoreChartBlock({
    required this.subjects,
    required this.subjectIdx,
    required this.onSubjectChanged,
    required this.values,
    required this.periods,
  });

  final List<String> subjects;
  final int subjectIdx;
  final ValueChanged<int> onSubjectChanged;
  final List<double> values;
  final List<String> periods;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(12), ui(14), ui(12), ui(12)),
      decoration: BoxDecoration(
        color: _kPageBgChip,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '我教科目 · 分数走势',
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
                      '${subjects[subjectIdx]} · 考试成绩',
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
              ),
              _SubjectToggle(
                subjects: subjects,
                activeIdx: subjectIdx,
                onTap: onSubjectChanged,
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          SizedBox(
            height: ui(220),
            child: _ScoreLineChart(values: values, periods: periods),
          ),
        ],
      ),
    );
  }
}

class _SubjectToggle extends StatelessWidget {
  const _SubjectToggle({
    required this.subjects,
    required this.activeIdx,
    required this.onTap,
  });

  final List<String> subjects;
  final int activeIdx;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < subjects.length; i++)
            InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(ui(6)),
              child: Container(
                height: ui(36),
                padding: EdgeInsets.symmetric(horizontal: ui(16)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == activeIdx ? _kTextDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Text(
                  subjects[i],
                  style: TextStyle(
                    fontSize: ui(14),
                    color: i == activeIdx ? Colors.white : _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
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

/// 折线图：左侧 30 宽 Y 轴标签列（100/95/90/85/80/0）；下方 28 高 X 轴标签
/// 行（2-6 月 + 期中）；中间 plot 区域用 [_ScoreLinePainter] 画渐变填充 +
/// outline polyline + 6 圆点 + 圆点上方数值标签。
class _ScoreLineChart extends StatelessWidget {
  const _ScoreLineChart({required this.values, required this.periods});

  final List<double> values;
  final List<String> periods;

  static const List<int> _kYLabels = [100, 95, 90, 85, 80, 0];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        // Y 轴标签列。100/95/90/85/80 等距分布在上半部分，0 单独贴底，
        // 与 Figma 一致（视觉强调 80-100 分数段）。
        SizedBox(
          width: ui(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: ui(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in _kYLabels)
                  Text(
                    '$l',
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
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _ScoreLinePainter(values: values, ui: ui),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(8)),
              SizedBox(
                height: ui(20),
                child: Row(
                  children: [
                    for (final p in periods)
                      Expanded(
                        child: Center(
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextSecondary,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1,
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
      ],
    );
  }
}

class _ScoreLinePainter extends CustomPainter {
  _ScoreLinePainter({required this.values, required this.ui});

  final List<double> values;
  final double Function(num) ui;

  // 数值映射：80~100 区间映射到 plot 高度的上半部分，下半留给 0 缓冲。
  static const double _kVMin = 78;
  static const double _kVMax = 100;

  double _normalize(double v) {
    final t = ((v - _kVMin) / (_kVMax - _kVMin)).clamp(0.0, 1.0);
    return 1 - t; // 顶部对应高分，所以反转。
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 2) return;

    // X 等距分布；首尾留 8% 内缩，避免圆点贴边。
    final innerLeft = size.width * 0.04;
    final innerRight = size.width * 0.96;
    final innerWidth = innerRight - innerLeft;
    final xs = List<double>.generate(
      n,
      (i) => innerLeft + innerWidth * (i / (n - 1)),
    );
    // Y 区间使用整个 plot 高度的 75% 上半部分；底部 25% 视觉留白。
    final plotTop = size.height * 0.05;
    final plotBottom = size.height * 0.78;
    final plotHeight = plotBottom - plotTop;
    final ys = values.map((v) => plotTop + plotHeight * _normalize(v)).toList();

    // 1. 渐变填充：从 polyline 到 plotBottom。
    final fillPath = Path()..moveTo(xs[0], plotBottom);
    for (var i = 0; i < n; i++) {
      fillPath.lineTo(xs[i], ys[i]);
    }
    fillPath
      ..lineTo(xs.last, plotBottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE7D9FF),
          const Color(0xFFE7D9FF).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, plotTop, size.width, plotHeight));
    canvas.drawPath(fillPath, fillPaint);

    // 2. polyline outline：圆角 cap + 2px 紫色描边。
    final linePath = Path()..moveTo(xs[0], ys[0]);
    for (var i = 1; i < n; i++) {
      linePath.lineTo(xs[i], ys[i]);
    }
    final linePaint = Paint()
      ..color = _kPurple
      ..strokeWidth = ui(2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 3. 6 个圆点：白底 + 1px 紫边。
    final dotFill = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = _kPurple
      ..strokeWidth = ui(1)
      ..style = PaintingStyle.stroke;
    final dotR = ui(4);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(xs[i], ys[i]), dotR, dotFill);
      canvas.drawCircle(Offset(xs[i], ys[i]), dotR, dotBorder);
    }

    // 4. 圆点上方数值标签（12/500 #6D6B75，距点 14px）。
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final label = v == v.roundToDouble() ? v.toInt().toString() : '$v';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (xs[i] - tp.width / 2).clamp(0.0, size.width - tp.width);
      final dy = ys[i] - dotR - ui(4) - tp.height;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreLinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _ContactParentButton extends StatelessWidget {
  const _ContactParentButton({required this.onTap});

  final VoidCallback onTap;

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
          borderRadius: BorderRadius.circular(ui(12)),
          gradient: const LinearGradient(
            // Figma：270° 渐变（从右到左）；Flutter 用 centerRight→centerLeft。
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_rounded, size: ui(16), color: Colors.white),
            SizedBox(width: ui(8)),
            Text(
              '联系家长',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
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
// 「家长联系方式」弹窗
//
// 触发：学生档案抽屉底部 "联系家长" CTA。
// 视觉：紫白渐变 360 宽 [GradientHeaderDialog]，顶部居中标题；中部展示当前
//      学生缩略 + 家长卡（紫色头像 / 家长姓名+关系 / 大字电话）。
//      纯展示弹窗，点击遮罩关闭，不带任何操作按钮。
// =============================================================================

void _showParentContactDialog(
  BuildContext context,
  _Student data, {
  Map<String, dynamic>? detail,
}) {
  final d = detail;
  final pickedName = _detailPick(
    d,
    const ['guardianName', 'parentName', 'contactName'],
    '',
  ).trim();
  final parentName = pickedName.isNotEmpty
      ? pickedName
      : () {
          final parentSurname =
              data.name.isEmpty ? '家' : data.name.characters.first;
          return '$parentSurname家长';
        }();
  final parentRelation = _detailPick(
    d,
    const ['guardianRelation', 'parentRelation', 'relation'],
    '家长',
  );
  final parentPhone = _detailPick(
    d,
    const ['parentMobile', 'guardianMobile', 'parentPhone'],
    data.parentPhone,
  );
  // 弹窗使用 root navigator + showScaledDialog，自动堆叠在右抽屉之上，
  // 关闭时不会连带关掉抽屉。
  showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (ctx) {
      final ui = DashboardScaleScope.of(ctx).ui;
      return GradientHeaderDialog(
        title: '家长联系方式',
        headerAsset: null,
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 学生缩略
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(name: data.name, avatarUrl: data.avatarUrl, size: 40),
                SizedBox(width: ui(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.name,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kTextDark,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w600,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: ui(4)),
                      Text(
                        data.studentId,
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
              ],
            ),
            SizedBox(height: ui(16)),
            // 家长信息卡
            Container(
              padding: EdgeInsets.all(ui(14)),
              decoration: BoxDecoration(
                color: _kPageBgChip,
                borderRadius: BorderRadius.circular(ui(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: ui(36),
                        height: ui(36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kPurple.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: _kPurple,
                          size: ui(20),
                        ),
                      ),
                      SizedBox(width: ui(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              parentName,
                              style: TextStyle(
                                fontSize: ui(15),
                                color: _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w500,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: ui(4)),
                            Text(
                              parentRelation,
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
                    ],
                  ),
                  SizedBox(height: ui(14)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(12),
                      vertical: ui(10),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(10)),
                      border: Border.all(color: _kBorderSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          color: _kPurple,
                          size: ui(18),
                        ),
                        SizedBox(width: ui(8)),
                        Expanded(
                          child: Text(
                            parentPhone,
                            style: TextStyle(
                              fontSize: ui(20),
                              color: _kTextDark,
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                              letterSpacing: ui(0.5),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

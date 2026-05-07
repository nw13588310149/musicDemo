// 部分卡片只覆盖了部分模型可选字段，analyzer 误报为
// unused_element_parameter，整体忽略。
// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ============================================================================
// 颜色常量
// ============================================================================

const Color _kBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kSubBg = Color(0xFFF5F6FA);
const Color _kPanelHeaderBg = Color(0xFFF4F4FF);
const Color _kTextPrimary = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextSub = Color(0xFF6D6B75);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLightTag = Color(0xFFDAD2FF);
const Color _kPurpleAvatarBg = Color(0xFFE7D9FF);
const Color _kBorder = Color(0xFFF3F2F3);
const Color _kFieldBorder = Color(0xFFF5F6FA);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kCheckboxBorder = Color(0xFFCECED1);
const Color _kCancelBg = Color(0xFFE6E9F1);

// ============================================================================
// 数据模型
// ============================================================================

enum _ClassKind { largeClass, smallClass }

extension on _ClassKind {
  String get label => this == _ClassKind.largeClass ? '大课' : '小课';
  Color get dotColor =>
      this == _ClassKind.largeClass ? const Color(0xFFA773FF) : _kGreen;

  /// 与后端 `type` 字段的双向映射：1 = 大班，2 = 小班。
  int get apiCode => this == _ClassKind.largeClass ? 1 : 2;
}

_ClassKind _parseKind(String raw) {
  if (raw.isEmpty) return _ClassKind.largeClass;
  if (raw.contains('大') || raw == '1' || raw.toLowerCase() == 'large') {
    return _ClassKind.largeClass;
  }
  return _ClassKind.smallClass;
}

class _StudentRecord {
  const _StudentRecord({
    required this.id,
    required this.name,
    required this.studentNo,
    this.major = '乐理',
    this.fullMajor = '音乐专业部·乐理·视唱练耳·和声基础',
  });

  factory _StudentRecord.fromJson(Map<String, dynamic> json) {
    final id = _pickString(json, ['id', 'studentId', 'userId'], '');
    // 后端实际返回 realname / nickname；保留旧字段名做兜底。
    final name = _pickString(json, [
      'realname',
      'realName',
      'nickname',
      'name',
      'studentName',
      'userName',
    ], '');
    final no = _pickString(json, [
      'no',
      'studentNo',
      'studentCode',
      'code',
    ], '—');
    final major = _pickString(json, [
      'major',
      'majorName',
      'subject',
      'subjectName',
    ], '');
    final fullMajor = _pickString(json, [
      'fullMajor',
      'majorFullName',
      'archiveName',
      'professional',
    ], major);
    return _StudentRecord(
      id: id,
      name: name,
      studentNo: no,
      major: major.isEmpty ? '—' : major,
      fullMajor: fullMajor.isEmpty ? '—' : fullMajor,
    );
  }

  final String id;
  final String name;
  final String studentNo;
  final String major;
  final String fullMajor;
}

class _TeacherOption {
  const _TeacherOption({
    required this.id,
    required this.name,
    this.workNo = '',
    this.subject = '',
    this.dept = '',
  });

  factory _TeacherOption.fromJson(Map<String, dynamic> json) {
    return _TeacherOption(
      id: _pickString(json, ['id', 'teacherId', 'userId'], ''),
      // 后端实际返回 realname / nickname；保留旧字段名做兜底。
      name: _pickString(json, [
        'realname',
        'realName',
        'nickname',
        'name',
        'teacherName',
        'userName',
      ], ''),
      workNo: _pickString(json, [
        'no',
        'workNo',
        'teacherNo',
        'jobNo',
        'code',
      ], ''),
      subject: _pickString(json, [
        'subject',
        'subjectName',
        'discipline',
        'disciplineName',
      ], ''),
      dept: _pickString(json, [
        'dept',
        'department',
        'departmentName',
        'orgName',
        'archiveName',
      ], ''),
    );
  }

  final String id;
  final String name;
  final String workNo;
  final String subject;
  final String dept;
}

class _ClassroomOption {
  const _ClassroomOption({required this.id, required this.name});

  factory _ClassroomOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['classroomId'] ?? json['roomId'];
    final id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}') ?? 0;
    return _ClassroomOption(
      id: id,
      name: _pickString(json, [
        'name',
        'classroomName',
        'roomName',
        'fullName',
      ], '—'),
    );
  }

  final int id;
  final String name;
}

class _ClassEntry {
  const _ClassEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.code,
    required this.headTeacher,
    required this.classroom,
    this.headTeacherId,
    this.classroomId,
    this.campusId,
    this.teacherIds,
    this.students = const [],
  });

  factory _ClassEntry.fromJson(
    Map<String, dynamic> json, {
    int fallbackIdx = 0,
  }) {
    // id 为雪花 long，使用字符串避免 JS number 精度丢失。
    final id = _pickString(json, ['id', 'classId', 'cId'], 'srv-$fallbackIdx');
    final name = _pickString(json, [
      'className',
      'class',
      'name',
      'classFullName',
      'fullName',
    ], '');
    final code = _pickString(json, ['classCode', 'code', 'no'], '—');
    final teacher = _pickString(json, [
      'headTeacherName',
      'classTeacher',
      'teacherName',
      'masterName',
    ], '—');
    final classroom = _pickString(json, [
      'classroomName',
      'roomName',
      'classroom',
      'room',
    ], '—');
    final kindRaw = _pickString(json, ['classType', 'type', 'kind'], '');

    int? classroomId;
    final rawRoom = json['classroomId'] ?? json['roomId'];
    if (rawRoom is int) {
      classroomId = rawRoom;
    } else if (rawRoom != null) {
      classroomId = int.tryParse('$rawRoom');
    }

    int? campusId;
    final rawCampus = json['campusId'];
    if (rawCampus is int) {
      campusId = rawCampus;
    } else if (rawCampus != null) {
      campusId = int.tryParse('$rawCampus');
    }

    final headTeacherId = _pickString(json, [
      'headTeacherId',
      'classTeacherId',
      'masterId',
    ], '');

    final teacherIdsRaw = _pickString(json, ['teacherIds', 'teacherId'], '');

    return _ClassEntry(
      id: id,
      name: name,
      kind: _parseKind(kindRaw),
      code: code,
      headTeacher: teacher,
      headTeacherId: headTeacherId.isEmpty ? null : headTeacherId,
      classroom: classroom,
      classroomId: classroomId,
      campusId: campusId,
      teacherIds: teacherIdsRaw.isEmpty ? null : teacherIdsRaw,
    );
  }

  /// 班级 id：雪花 long，全程以 String 存储 / 透传，禁止 `int.parse`，
  /// 否则 web 端 JS number 精度截断会改写后几位。
  final String id;
  final String name;
  final _ClassKind kind;
  final String code;
  final String headTeacher;
  final String? headTeacherId;
  final String classroom;
  final int? classroomId;
  final int? campusId;
  final String? teacherIds;
  final List<_StudentRecord> students;

  /// 副标题：「编码·年级·班主任·教学楼·教室」单行展示。
  String get metaLine => '$code·高三·班主任$headTeacher·艺术楼·$classroom';

  int get studentCount => students.length;

  _ClassEntry copyWith({List<_StudentRecord>? students}) {
    return _ClassEntry(
      id: id,
      name: name,
      kind: kind,
      code: code,
      headTeacher: headTeacher,
      headTeacherId: headTeacherId,
      classroom: classroom,
      classroomId: classroomId,
      campusId: campusId,
      teacherIds: teacherIds,
      students: students ?? this.students,
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

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  final raw = resp.data;
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

// ============================================================================
// 入口视图
// ============================================================================

/// 管理员端「班级编组」总览页。
///
/// 自上而下：
/// 1. **顶部白色 banner**（970×62，白→#F9EDFF 微紫渐变 + 16 圆角）：
///    左 32 返回按钮 + 居中标题「班级编组」16/600 + 12 灰副标题；右上
///    并排 2 枚胶囊按钮 — 「创建班级」+「人员调班」。
/// 2. **4 张彩色渐变统计卡**（100 高 + 12 圆角）：行政班数（紫）/ 在籍
///    人数（橙）/ 可调班在籍（绿）/ 调班记录（红）。
/// 3. **「行政班一览」18/500 标题**。
/// 4. **行政班卡片堆叠列表**：每张白卡（16 圆角 + 12 padding）含
///    - **header**：F5F6FA 圆角条，左 36 紫色图标 + 班级名 14/500 +
///      白色 大课(紫点)/小课(绿点) pill + 「编码·年级·班主任·教学楼·
///      教室」灰色 meta + 右侧「共 N 人」+ chevron 折叠按钮；
///    - **expanded**：3 列学生迷你卡（40 头像 + 名 + 学号 + 专业），
///      右上紫色 #DAD2FF cut-corner「在籍」徽章。
///
/// 顶部按钮：
///   - 「创建班级」→ 右抽屉 [_CreateClassDrawer]：大班/小班 toggle +
///     班级名称 + 班级编码 + 班主任/固定教室 dropdown + 学生名册穿梭框
///     (人员库 ↔ 本班名单)；底部 取消 / 创建 按钮。
///   - 「人员调班」→ 右抽屉 [_TransferClassDrawer]：班级名称 dropdown +
///     学生库 ↔ 本班学生 穿梭框；底部 取消 / 创建 按钮。
///
/// 数据接入：进入页面立即调
///   - `POST /app/school/v2/manager/classList`     → 班级总览
///   - `POST /app/school/v2/manager/teacherList`   → 班主任 / 任课老师下拉
///   - `POST /app/school/v2/manager/classroomList` → 固定教室下拉
///
/// 展开班级卡片时按需调
///   - `POST /app/school/v2/manager/studentList?classId=…` → 该班学生
///
/// 抽屉内：
///   - `POST /app/school/v2/manager/studentList` → 全量学生池
///   - 「创建」按钮 → `classSave`（type / studentIds / teacherIds 见下方 spec）
///   - 「人员调班·创建」按钮 → `classUpdate`（id + studentIds 必填）
///
/// 已彻底移除 mock / demo 数据；接口失败或为空时显示空状态。
class AdminClassManagementView extends ConsumerStatefulWidget {
  const AdminClassManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminClassManagementView> createState() =>
      _AdminClassManagementViewState();
}

class _AdminClassManagementViewState
    extends ConsumerState<AdminClassManagementView> {
  List<_ClassEntry> _classes = const [];
  bool _loading = true;

  /// 班级 id → 已加载的学生名单。`null` 表示尚未拉取，空 List 表示已拉取且为空。
  final Map<String, List<_StudentRecord>?> _classStudents = {};
  final Set<String> _classStudentsLoading = {};

  /// 用于穿梭框「人员库」的所有学生（懒加载，drawer 打开时拉一次）。
  List<_StudentRecord>? _studentPool;
  bool _poolLoading = false;

  List<_TeacherOption> _teachers = const [];
  List<_ClassroomOption> _classrooms = const [];
  bool _optionsLoaded = false;

  /// 哪些班级处于展开状态。
  Set<String> _expanded = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _ensureOptions();
    });
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted) return;

    if (!resp.isSuccess || resp.data == null) {
      setState(() {
        _classes = const [];
        _loading = false;
      });
      return;
    }

    final rows = _extractList(resp);
    final parsed = <_ClassEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final entry = _ClassEntry.fromJson(rows[i], fallbackIdx: i);
      if (entry.name.isEmpty) continue;
      parsed.add(entry);
    }

    setState(() {
      _classes = parsed;
      _loading = false;
      _classStudents.clear();
      _classStudentsLoading.clear();
      // 默认展开第一张，便于快速预览。
      _expanded = parsed.isNotEmpty ? {parsed.first.id} : const {};
    });

    if (parsed.isNotEmpty) {
      _ensureClassStudents(parsed.first);
    }
  }

  Future<({List<_TeacherOption> teachers, List<_ClassroomOption> classrooms})>?
  _optionsFuture;

  /// 缓存 teachers / classrooms：parent 与抽屉共享同一份；多次调用只发 1 次请求。
  Future<({List<_TeacherOption> teachers, List<_ClassroomOption> classrooms})>
  _ensureOptions() {
    if (_optionsLoaded) {
      return Future.value((teachers: _teachers, classrooms: _classrooms));
    }
    return _optionsFuture ??= _loadOptionsImpl();
  }

  Future<({List<_TeacherOption> teachers, List<_ClassroomOption> classrooms})>
  _loadOptionsImpl() async {
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.teacherList(),
      repo.classroomList(),
    ]);

    final teacherResp = results[0];
    final classroomResp = results[1];

    final teachers = <_TeacherOption>[];
    if (teacherResp.isSuccess) {
      for (final m in _extractList(teacherResp)) {
        final t = _TeacherOption.fromJson(m);
        if (t.name.isNotEmpty) teachers.add(t);
      }
    }

    final classrooms = <_ClassroomOption>[];
    if (classroomResp.isSuccess) {
      for (final m in _extractList(classroomResp)) {
        final r = _ClassroomOption.fromJson(m);
        if (r.name.isNotEmpty && r.name != '—') classrooms.add(r);
      }
    }

    if (!mounted) {
      _optionsFuture = null;
      return (teachers: teachers, classrooms: classrooms);
    }

    setState(() {
      _teachers = teachers;
      _classrooms = classrooms;
      _optionsLoaded = true;
    });
    return (teachers: teachers, classrooms: classrooms);
  }

  Future<List<_StudentRecord>> _ensureStudentPool() async {
    if (_studentPool != null) return _studentPool!;
    if (_poolLoading) {
      // 简单等待已有的请求完成。
      while (_poolLoading && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return _studentPool ?? const [];
    }
    _poolLoading = true;
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.studentList(size: 500);
    if (!mounted) {
      _poolLoading = false;
      return const [];
    }
    final pool = <_StudentRecord>[];
    if (resp.isSuccess) {
      for (final m in _extractList(resp)) {
        final s = _StudentRecord.fromJson(m);
        if (s.name.isNotEmpty) pool.add(s);
      }
    }
    setState(() {
      _studentPool = pool;
      _poolLoading = false;
    });
    return pool;
  }

  /// 拉取指定班级的学生名单：默认走 cache，cache 命中直接返回；force=true
  /// 时绕过 cache 强制重新调 `studentList(classId:)` 并刷新缓存。
  /// 调班抽屉切换班级 → 必须 force，确保拿到最新名单。
  Future<List<_StudentRecord>> _ensureClassStudents(
    _ClassEntry entry, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _classStudents[entry.id];
      if (cached != null) return cached;
      if (_classStudentsLoading.contains(entry.id)) return const [];
    }
    _classStudentsLoading.add(entry.id);

    // classId 必须是原始字符串，禁止经过 `int.parse`。
    final cid = entry.id;
    final repo = ref.read(adminRepositoryProvider);
    final resp = cid.isNotEmpty
        ? await repo.studentList(classId: cid, size: 500)
        : ApiResponse.failure('班级 id 缺失');
    if (!mounted) return const [];

    final list = <_StudentRecord>[];
    if (resp.isSuccess) {
      for (final m in _extractList(resp)) {
        final s = _StudentRecord.fromJson(m);
        if (s.name.isNotEmpty) list.add(s);
      }
    }

    setState(() {
      _classStudents[entry.id] = list;
      _classStudentsLoading.remove(entry.id);
      _classes = [
        for (final c in _classes)
          if (c.id == entry.id) c.copyWith(students: list) else c,
      ];
    });
    return list;
  }

  Future<List<_StudentRecord>> _reloadClassStudents(_ClassEntry entry) =>
      _ensureClassStudents(entry, force: true);

  void _toggle(String id) {
    final entry = _classes.firstWhere(
      (c) => c.id == id,
      orElse: () => const _ClassEntry(
        id: '',
        name: '',
        kind: _ClassKind.largeClass,
        code: '',
        headTeacher: '',
        classroom: '',
      ),
    );
    setState(() {
      if (_expanded.contains(id)) {
        _expanded = {..._expanded}..remove(id);
      } else {
        _expanded = {..._expanded, id};
      }
    });
    if (_expanded.contains(id) && entry.id.isNotEmpty) {
      _ensureClassStudents(entry);
    }
  }

  void _openCreateClassDrawer() {
    final scale = DashboardScaleScope.of(context);
    final pool = _studentPool ?? const <_StudentRecord>[];
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭创建班级',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _CreateClassDrawer(
            initialPool: pool,
            initialTeachers: _teachers,
            initialClassrooms: _classrooms,
            ensurePool: _ensureStudentPool,
            ensureOptions: _ensureOptions,
            onSubmit: _submitCreateClass,
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
    if (_studentPool == null) {
      _ensureStudentPool();
    }
  }

  void _openTransferClassDrawer() {
    if (_classes.isEmpty) {
      AppToast.show(context, '暂无班级数据，无法调班');
      return;
    }
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭人员调班',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _TransferClassDrawer(
            classes: _classes,
            ensurePool: _ensureStudentPool,
            ensureClassStudents: _ensureClassStudents,
            reloadClassStudents: _reloadClassStudents,
            onSubmit: _submitClassUpdate,
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
    if (_studentPool == null) {
      _ensureStudentPool();
    }
  }

  Future<bool> _submitCreateClass({
    required _ClassKind kind,
    required String name,
    required String classCode,
    required _TeacherOption? headTeacher,
    required _ClassroomOption? classroom,
    required List<_TeacherOption> teachers,
    required List<_StudentRecord> students,
  }) async {
    if (name.trim().isEmpty) {
      AppToast.show(context, '请填写班级名称');
      return false;
    }
    if (classCode.trim().isEmpty) {
      AppToast.show(context, '请填写班级编码');
      return false;
    }
    final body = <String, dynamic>{
      'campusId': 0,
      'name': name.trim(),
      'classCode': classCode.trim(),
      'type': kind.apiCode,
      // 学生 id 是雪花算法生成的 long（如 1795667363756507137）；用 int
      // 序列化会被 JS / JSON number 精度截断，必须按 string 发送。
      'studentIds': [
        for (final s in students)
          if (s.id.isNotEmpty) s.id,
      ],
    };

    // 任课老师：后端期望逗号分隔的 string；空则不带。
    final teacherIds = teachers
        .map((t) => t.id)
        .where((id) => id.isNotEmpty)
        .join(',');
    if (teacherIds.isNotEmpty) {
      body['teacherIds'] = teacherIds;
    }

    // 班主任 / 固定教室仅大班需要。
    if (kind == _ClassKind.largeClass) {
      if (headTeacher != null && headTeacher.id.isNotEmpty) {
        body['headTeacherId'] = headTeacher.id;
      }
      if (classroom != null) {
        body['classroomId'] = classroom.id;
      }
    }

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classSave(body);
    if (!mounted) return false;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '创建班级失败' : resp.msg);
      return false;
    }
    AppToast.show(context, '班级创建成功');
    await _loadClasses();
    return true;
  }

  Future<bool> _submitClassUpdate({
    required _ClassEntry target,
    required List<_StudentRecord> students,
  }) async {
    if (target.id.isEmpty) {
      AppToast.show(context, '班级 id 不可用');
      return false;
    }
    final body = <String, dynamic>{
      // 同 studentList：班级 id 用 string，避免雪花 long 被精度截断。
      'id': target.id,
      'campusId': target.campusId ?? 0,
      'name': target.name,
      'classCode': target.code,
      // 同 classSave：学生 id 用 string，避免雪花 long 被精度截断。
      'studentIds': [
        for (final s in students)
          if (s.id.isNotEmpty) s.id,
      ],
    };
    if (target.headTeacherId != null && target.headTeacherId!.isNotEmpty) {
      body['headTeacherId'] = target.headTeacherId;
    }
    if (target.classroomId != null) {
      body['classroomId'] = target.classroomId;
    }
    if (target.teacherIds != null && target.teacherIds!.isNotEmpty) {
      body['teacherIds'] = target.teacherIds;
    } else if (target.headTeacherId != null &&
        target.headTeacherId!.isNotEmpty) {
      body['teacherIds'] = target.headTeacherId;
    }

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classUpdate(body);
    if (!mounted) return false;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isEmpty ? '调班保存失败' : resp.msg);
      return false;
    }
    AppToast.show(context, '调班保存成功');
    // 强制刷新该班级名单。
    _classStudents.remove(target.id);
    await _loadClasses();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final adminClassCount = _classes.length;
    final enrolledCount = _classes.fold<int>(
      0,
      (acc, c) => acc + c.studentCount,
    );

    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: ui(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(
              onBack: widget.onBack,
              onCreateClass: _openCreateClassDrawer,
              onTransferClass: _openTransferClassDrawer,
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              classCount: adminClassCount,
              enrolledCount: enrolledCount,
              transferableCount: enrolledCount,
              transferRecordCount: 1,
            ),
            SizedBox(height: ui(20)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '行政班一览',
                  style: TextStyle(
                    fontSize: ui(18),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: _kTextSection,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                if (_loading) ...[
                  SizedBox(width: ui(8)),
                  SizedBox(
                    width: ui(14),
                    height: ui(14),
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: ui(12)),
            if (!_loading && _classes.isEmpty)
              _EmptyState(label: '暂无班级数据')
            else
              for (final c in _classes) ...[
                _ClassCard(
                  entry: c,
                  expanded: _expanded.contains(c.id),
                  loadingStudents: _classStudentsLoading.contains(c.id),
                  onToggle: () => _toggle(c.id),
                ),
                SizedBox(height: ui(12)),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(14),
          height: 1.4,
          color: _kTextHint,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

// ============================================================================
// Banner
// ============================================================================

class _Banner extends StatelessWidget {
  const _Banner({
    required this.onBack,
    required this.onCreateClass,
    required this.onTransferClass,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateClass;
  final VoidCallback onTransferClass;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                width: ui(32),
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorder, width: 1),
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: ui(20),
                  color: _kTextPrimary,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '班级编辑',
                  style: TextStyle(
                    fontSize: ui(16),
                    height: 1.2,
                    fontWeight: AppFont.w600,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '人事档案、部门归属、任课与角色；与教师端登录权限、班主任带班关系对齐',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.2,
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BannerActionButton(
                  label: '创建班级',
                  icon: Icons.dashboard_customize_outlined,
                  iconColor: _kTextPrimary,
                  onTap: onCreateClass,
                ),
                SizedBox(width: ui(8)),
                _BannerActionButton(
                  label: '人员调班',
                  icon: Icons.swap_horiz,
                  iconColor: _kPurple,
                  onTap: onTransferClass,
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
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: ui(16), color: iconColor),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                height: 1.2,
                fontWeight: AppFont.w600,
                color: Colors.black,
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
// 4 列统计
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.classCount,
    required this.enrolledCount,
    required this.transferableCount,
    required this.transferRecordCount,
  });

  final int classCount;
  final int enrolledCount;
  final int transferableCount;
  final int transferRecordCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cards = <_StatCard>[
      _StatCard(
        label: '行政班数',
        value: classCount,
        gradientStart: const Color(0xFFE7DCFF),
        icon: Icons.dashboard_outlined,
        iconColor: const Color(0xFFA985FF),
      ),
      _StatCard(
        label: '在籍人数',
        value: enrolledCount,
        gradientStart: const Color(0xFFFFF0DC),
        icon: Icons.people_alt_outlined,
        iconColor: const Color(0xFFFFB85C),
      ),
      _StatCard(
        label: '可调班在籍',
        value: transferableCount,
        gradientStart: const Color(0xFFDCFFE7),
        icon: Icons.shuffle_rounded,
        iconColor: const Color(0xFF52C49A),
      ),
      _StatCard(
        label: '调班记录',
        value: transferRecordCount,
        gradientStart: const Color(0xFFFFE2DC),
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xFFFF8A75),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) SizedBox(width: ui(12)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.gradientStart,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final int value;
  final Color gradientStart;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [gradientStart, Colors.white],
          stops: const [0, 0.73],
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(12), ui(12)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  fontWeight: AppFont.w500,
                  color: Colors.black,
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(8)),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: ui(32),
                  height: 1.0,
                  fontWeight: FontWeight.w500,
                  color: _kTextPrimary,
                  fontFamily: 'Barlow',
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              icon,
              size: ui(54),
              color: iconColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 行政班卡片：header + 折叠 / 展开 学生网格
// ============================================================================

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.entry,
    required this.expanded,
    required this.onToggle,
    this.loadingStudents = false,
  });

  final _ClassEntry entry;
  final bool expanded;
  final bool loadingStudents;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClassHeader(entry: entry, expanded: expanded, onToggle: onToggle),
          if (expanded) ...[
            SizedBox(height: ui(12)),
            if (loadingStudents)
              SizedBox(
                height: ui(64),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                    ),
                  ),
                ),
              )
            else if (entry.students.isEmpty)
              SizedBox(
                height: ui(64),
                child: Center(
                  child: Text(
                    '暂无学生',
                    style: TextStyle(
                      fontSize: ui(13),
                      height: 1.4,
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              )
            else
              _StudentMiniGrid(students: entry.students),
          ],
        ],
      ),
    );
  }
}

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  final _ClassEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 不写死 height —— Figma 给的 65px 在中文字体（PingFang SC）下会被
    // 标题行 + 6 间距 + meta 行的 line-height 吃掉 1~2px 形成 BOTTOM OVERFLOWED；
    // 改用 minHeight + 自然高度，让卡片头随内容撑开，与 Figma 视觉等效。
    return Container(
      constraints: BoxConstraints(minHeight: ui(65)),
      decoration: BoxDecoration(
        color: _kSubBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: ui(36),
            height: ui(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kPurpleAvatarBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1C274D), _kPurple],
              ).createShader(rect),
              blendMode: BlendMode.srcIn,
              child: Icon(
                Icons.groups_outlined,
                size: ui(20),
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(14),
                          height: 1.2,
                          fontWeight: AppFont.w500,
                          color: _kTextPrimary,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ),
                    SizedBox(width: ui(8)),
                    _KindPill(kind: entry.kind),
                  ],
                ),
                SizedBox(height: ui(6)),
                Text(
                  entry.metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.2,
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          Text(
            '共${entry.studentCount}人',
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: _kTextSub,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(width: ui(12)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              width: ui(32),
              height: ui(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorder, width: 1),
              ),
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: ui(16),
                  color: _kTextPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});

  final _ClassKind kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 不写死 height —— 12px PingFang SC 字形高度本身 ≈ 17px，
    // 再叠加 2px vertical padding 会被原来的 16 高度截掉「小课/大课」下半截。
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(3)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: kind.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            kind.label,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: _kTextPrimary,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentMiniGrid extends StatelessWidget {
  const _StudentMiniGrid({required this.students});

  final List<_StudentRecord> students;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 11.0;
        final cols = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 600 ? 2 : 1);
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in students)
              SizedBox(
                width: cardWidth,
                child: _StudentMiniCard(student: s),
              ),
          ],
        );
      },
    );
  }
}

class _StudentMiniCard extends StatelessWidget {
  const _StudentMiniCard({required this.student});

  final _StudentRecord student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      constraints: BoxConstraints(minHeight: ui(64)),
      decoration: BoxDecoration(
        color: _kSubBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(50), ui(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MiniAvatar(name: student.name),
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
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(14),
                                height: 1.2,
                                fontWeight: AppFont.w500,
                                color: _kTextPrimary,
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ),
                          SizedBox(width: ui(8)),
                          Text(
                            student.studentNo,
                            style: TextStyle(
                              fontSize: ui(12),
                              height: 1.2,
                              color: _kTextHint,
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ui(2)),
                      Text(
                        student.major,
                        style: TextStyle(
                          fontSize: ui(12),
                          height: 1.2,
                          color: _kTextPrimary,
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
                color: _kPurpleLightTag,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(ui(12)),
                  bottomLeft: Radius.circular(ui(12)),
                ),
              ),
              child: Text(
                '在籍',
                style: TextStyle(
                  fontSize: ui(12),
                  height: 1.0,
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    return Container(
      width: ui(40),
      height: ui(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(16),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

// ============================================================================
// 「创建行政班」右抽屉
// ============================================================================

typedef _CreateClassSubmit =
    Future<bool> Function({
      required _ClassKind kind,
      required String name,
      required String classCode,
      required _TeacherOption? headTeacher,
      required _ClassroomOption? classroom,
      required List<_TeacherOption> teachers,
      required List<_StudentRecord> students,
    });

typedef _OptionsResult = ({
  List<_TeacherOption> teachers,
  List<_ClassroomOption> classrooms,
});

class _CreateClassDrawer extends StatefulWidget {
  const _CreateClassDrawer({
    required this.initialPool,
    required this.initialTeachers,
    required this.initialClassrooms,
    required this.ensurePool,
    required this.ensureOptions,
    required this.onSubmit,
  });

  final List<_StudentRecord> initialPool;
  final List<_TeacherOption> initialTeachers;
  final List<_ClassroomOption> initialClassrooms;
  final Future<List<_StudentRecord>> Function() ensurePool;
  final Future<_OptionsResult> Function() ensureOptions;
  final _CreateClassSubmit onSubmit;

  @override
  State<_CreateClassDrawer> createState() => _CreateClassDrawerState();
}

class _CreateClassDrawerState extends State<_CreateClassDrawer> {
  _ClassKind _kind = _ClassKind.largeClass;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  _TeacherOption? _headTeacher;
  _ClassroomOption? _classroom;

  // 学生穿梭框
  late List<_StudentRecord> _pool = [...widget.initialPool];
  List<_StudentRecord> _selected = const [];
  Set<String> _poolChecked = {};
  Set<String> _selectedChecked = {};
  bool _poolLoading = false;

  // 班主任 / 教室下拉的全量数据（不会被穿梭操作改动）
  late List<_TeacherOption> _allTeachers = [...widget.initialTeachers];
  late List<_ClassroomOption> _classrooms = [...widget.initialClassrooms];

  // 任课老师穿梭框
  late List<_TeacherOption> _teacherPool = [...widget.initialTeachers];
  List<_TeacherOption> _selectedTeachers = const [];
  Set<String> _teacherPoolChecked = {};
  Set<String> _teacherSelectedChecked = {};
  bool _teachersLoading = false;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPool.isEmpty) {
      _poolLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final pool = await widget.ensurePool();
        if (!mounted) return;
        setState(() {
          _pool = [...pool];
          _poolLoading = false;
        });
      });
    }
    if (widget.initialTeachers.isEmpty || widget.initialClassrooms.isEmpty) {
      _teachersLoading = widget.initialTeachers.isEmpty;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await widget.ensureOptions();
        if (!mounted) return;
        setState(() {
          _allTeachers = [...result.teachers];
          _classrooms = [...result.classrooms];
          // 用户尚未做任何穿梭操作时，刷新左侧教师库。
          if (_selectedTeachers.isEmpty) {
            _teacherPool = [...result.teachers];
          }
          _teachersLoading = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _moveToSelected() {
    if (_poolChecked.isEmpty) return;
    setState(() {
      final moving = _pool.where((s) => _poolChecked.contains(s.id)).toList();
      _pool = _pool.where((s) => !_poolChecked.contains(s.id)).toList();
      _selected = [..._selected, ...moving];
      _poolChecked = {};
    });
  }

  void _moveToPool() {
    if (_selectedChecked.isEmpty) return;
    setState(() {
      final moving = _selected
          .where((s) => _selectedChecked.contains(s.id))
          .toList();
      _selected = _selected
          .where((s) => !_selectedChecked.contains(s.id))
          .toList();
      _pool = [..._pool, ...moving];
      _selectedChecked = {};
    });
  }

  void _moveTeacherToSelected() {
    if (_teacherPoolChecked.isEmpty) return;
    setState(() {
      final moving = _teacherPool
          .where((t) => _teacherPoolChecked.contains(t.id))
          .toList();
      _teacherPool = _teacherPool
          .where((t) => !_teacherPoolChecked.contains(t.id))
          .toList();
      _selectedTeachers = [..._selectedTeachers, ...moving];
      _teacherPoolChecked = {};
    });
  }

  void _moveTeacherToPool() {
    if (_teacherSelectedChecked.isEmpty) return;
    setState(() {
      final moving = _selectedTeachers
          .where((t) => _teacherSelectedChecked.contains(t.id))
          .toList();
      _selectedTeachers = _selectedTeachers
          .where((t) => !_teacherSelectedChecked.contains(t.id))
          .toList();
      _teacherPool = [..._teacherPool, ...moving];
      _teacherSelectedChecked = {};
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit(
      kind: _kind,
      name: _nameCtrl.text,
      classCode: _codeCtrl.text,
      headTeacher: _headTeacher,
      classroom: _classroom,
      teachers: _selectedTeachers,
      students: _selected,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isLarge = _kind == _ClassKind.largeClass;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: ui(840),
        height: double.infinity,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DrawerTitleBar(title: '创建行政班'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ClassKindSelector(
                          value: _kind,
                          onChanged: (v) => setState(() => _kind = v),
                        ),
                        SizedBox(height: ui(20)),
                        _FormRowDouble(
                          leftLabel: '班级名称',
                          leftField: _PlainInput(controller: _nameCtrl),
                          rightLabel: '班级编码（唯一）',
                          rightField: _PlainInput(controller: _codeCtrl),
                        ),
                        if (isLarge) ...[
                          SizedBox(height: ui(20)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _FormColumn(
                                  label: '班主任',
                                  child: PopupSelectorField<_TeacherOption?>(
                                    value: _headTeacher,
                                    items: <_TeacherOption?>[
                                      null,
                                      ..._allTeachers,
                                    ],
                                    itemLabel: (t) =>
                                        t == null ? '请选择' : t.name,
                                    onChanged: (t) =>
                                        setState(() => _headTeacher = t),
                                  ),
                                ),
                              ),
                              SizedBox(width: ui(32)),
                              Expanded(
                                child: _FormColumn(
                                  label: '固定教室',
                                  child: PopupSelectorField<_ClassroomOption?>(
                                    value: _classroom,
                                    items: <_ClassroomOption?>[
                                      null,
                                      ..._classrooms,
                                    ],
                                    itemLabel: (r) =>
                                        r == null ? '请选择' : r.name,
                                    onChanged: (r) =>
                                        setState(() => _classroom = r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: ui(20)),
                        Text(
                          '任课老师',
                          style: TextStyle(
                            fontSize: ui(14),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: Colors.black,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(12)),
                        _TeacherTransferPanel(
                          leftTitle: '教师库',
                          rightTitle: '本班任课',
                          leftTeachers: _teacherPool,
                          rightTeachers: _selectedTeachers,
                          leftChecked: _teacherPoolChecked,
                          rightChecked: _teacherSelectedChecked,
                          leftLoading: _teachersLoading,
                          onLeftCheck: (id) {
                            setState(() {
                              if (_teacherPoolChecked.contains(id)) {
                                _teacherPoolChecked.remove(id);
                              } else {
                                _teacherPoolChecked.add(id);
                              }
                            });
                          },
                          onRightCheck: (id) {
                            setState(() {
                              if (_teacherSelectedChecked.contains(id)) {
                                _teacherSelectedChecked.remove(id);
                              } else {
                                _teacherSelectedChecked.add(id);
                              }
                            });
                          },
                          onMoveRight: _moveTeacherToSelected,
                          onMoveLeft: _moveTeacherToPool,
                        ),
                        SizedBox(height: ui(20)),
                        Text(
                          '班级学生名册',
                          style: TextStyle(
                            fontSize: ui(14),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: Colors.black,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(12)),
                        _TransferPanel(
                          leftTitle: '人员库',
                          rightTitle: '本班名单',
                          leftStudents: _pool,
                          rightStudents: _selected,
                          leftChecked: _poolChecked,
                          rightChecked: _selectedChecked,
                          leftLoading: _poolLoading,
                          onLeftCheck: (id) {
                            setState(() {
                              if (_poolChecked.contains(id)) {
                                _poolChecked.remove(id);
                              } else {
                                _poolChecked.add(id);
                              }
                            });
                          },
                          onRightCheck: (id) {
                            setState(() {
                              if (_selectedChecked.contains(id)) {
                                _selectedChecked.remove(id);
                              } else {
                                _selectedChecked.add(id);
                              }
                            });
                          },
                          onMoveRight: _moveToSelected,
                          onMoveLeft: _moveToPool,
                        ),
                      ],
                    ),
                  ),
                ),
                _DrawerFooter(
                  cancelLabel: '取消',
                  confirmLabel: _submitting ? '提交中…' : '创建',
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: _submitting ? () {} : _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 「人员调班」右抽屉
// ============================================================================

typedef _TransferClassSubmit =
    Future<bool> Function({
      required _ClassEntry target,
      required List<_StudentRecord> students,
    });

class _TransferClassDrawer extends StatefulWidget {
  const _TransferClassDrawer({
    required this.classes,
    required this.ensurePool,
    required this.ensureClassStudents,
    required this.reloadClassStudents,
    required this.onSubmit,
  });

  final List<_ClassEntry> classes;
  final Future<List<_StudentRecord>> Function() ensurePool;

  /// 首次进入时拉取本班名单：可走 cache。
  final Future<List<_StudentRecord>> Function(_ClassEntry entry)
  ensureClassStudents;

  /// 切换班级时强制重新调 `studentList(classId:)`，确保拿到最新数据。
  final Future<List<_StudentRecord>> Function(_ClassEntry entry)
  reloadClassStudents;
  final _TransferClassSubmit onSubmit;

  @override
  State<_TransferClassDrawer> createState() => _TransferClassDrawerState();
}

class _TransferClassDrawerState extends State<_TransferClassDrawer> {
  late _ClassEntry _selectedClass = widget.classes.first;

  List<_StudentRecord> _pool = const [];
  List<_StudentRecord> _selected = const [];
  Set<String> _poolChecked = {};
  Set<String> _selectedChecked = {};
  bool _poolLoading = true;
  bool _classLoading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      widget.ensurePool(),
      widget.ensureClassStudents(_selectedClass),
    ]);
    if (!mounted) return;
    final pool = results[0];
    final inClass = results[1];
    setState(() {
      _pool = _filterPool(pool, inClass);
      _selected = [...inClass];
      _poolChecked = {};
      _selectedChecked = {};
      _poolLoading = false;
      _classLoading = false;
    });
  }

  Future<void> _switchClass(_ClassEntry next) async {
    if (next.id == _selectedClass.id) return;
    // 先清空两侧 + 同时把左右穿梭框置 loading，避免上个班级的学生
    // 短暂残留在右侧造成视觉错位。
    setState(() {
      _selectedClass = next;
      _selected = const [];
      _pool = const [];
      _poolChecked = {};
      _selectedChecked = {};
      _classLoading = true;
      _poolLoading = true;
    });
    // 切换班级强制重新拉取 → 确保是后端最新名单（而非缓存）。
    final inClass = await widget.reloadClassStudents(next);
    if (!mounted || next.id != _selectedClass.id) return;
    final pool = await widget.ensurePool();
    if (!mounted || next.id != _selectedClass.id) return;
    setState(() {
      _pool = _filterPool(pool, inClass);
      _selected = [...inClass];
      _classLoading = false;
      _poolLoading = false;
    });
  }

  List<_StudentRecord> _filterPool(
    List<_StudentRecord> pool,
    List<_StudentRecord> inClass,
  ) {
    final ids = {for (final s in inClass) s.id};
    return [
      for (final s in pool)
        if (!ids.contains(s.id)) s,
    ];
  }

  void _moveToSelected() {
    if (_poolChecked.isEmpty) return;
    setState(() {
      final moving = _pool.where((s) => _poolChecked.contains(s.id)).toList();
      _pool = _pool.where((s) => !_poolChecked.contains(s.id)).toList();
      _selected = [..._selected, ...moving];
      _poolChecked = {};
    });
  }

  void _moveToPool() {
    if (_selectedChecked.isEmpty) return;
    setState(() {
      final moving = _selected
          .where((s) => _selectedChecked.contains(s.id))
          .toList();
      _selected = _selected
          .where((s) => !_selectedChecked.contains(s.id))
          .toList();
      _pool = [..._pool, ...moving];
      _selectedChecked = {};
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.onSubmit(
      target: _selectedClass,
      students: _selected,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: ui(840),
        height: double.infinity,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DrawerTitleBar(title: '人员调班'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabeledInline(
                          label: '班级名称',
                          field: PopupSelectorField<_ClassEntry>(
                            value: _selectedClass,
                            items: widget.classes,
                            itemLabel: (c) => c.name,
                            onChanged: _switchClass,
                          ),
                        ),
                        SizedBox(height: ui(20)),
                        Text(
                          '任课老师',
                          style: TextStyle(
                            fontSize: ui(14),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: Colors.black,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(12)),
                        _TransferPanel(
                          leftTitle: '学生库',
                          rightTitle: '本班学生',
                          searchPlaceholder: '输入内容搜索过滤',
                          leftStudents: _pool,
                          rightStudents: _selected,
                          leftChecked: _poolChecked,
                          rightChecked: _selectedChecked,
                          leftLoading: _poolLoading,
                          rightLoading: _classLoading,
                          onLeftCheck: (id) {
                            setState(() {
                              if (_poolChecked.contains(id)) {
                                _poolChecked.remove(id);
                              } else {
                                _poolChecked.add(id);
                              }
                            });
                          },
                          onRightCheck: (id) {
                            setState(() {
                              if (_selectedChecked.contains(id)) {
                                _selectedChecked.remove(id);
                              } else {
                                _selectedChecked.add(id);
                              }
                            });
                          },
                          onMoveRight: _moveToSelected,
                          onMoveLeft: _moveToPool,
                        ),
                      ],
                    ),
                  ),
                ),
                _DrawerFooter(
                  cancelLabel: '取消',
                  confirmLabel: _submitting ? '提交中…' : '保存',
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: _submitting ? () {} : _confirm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 抽屉公用：标题栏 / 底部按钮 / 表单组件 / 穿梭框
// ============================================================================

class _DrawerTitleBar extends StatelessWidget {
  const _DrawerTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(ui(12), ui(20), ui(20), ui(20)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
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
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextPrimary,
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

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: Container(
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kCancelBg,
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: Text(
                  cancelLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.4,
                    fontWeight: AppFont.w500,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(24)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onConfirm,
              child: Container(
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                  ),
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.4,
                    fontWeight: AppFont.w500,
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
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

class _ClassKindSelector extends StatelessWidget {
  const _ClassKindSelector({required this.value, required this.onChanged});

  final _ClassKind value;
  final ValueChanged<_ClassKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget cell(_ClassKind kind, String label) {
      final selected = kind == value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(kind),
        child: Container(
          width: ui(195),
          height: ui(64),
          padding: EdgeInsets.symmetric(horizontal: ui(20)),
          decoration: BoxDecoration(
            color: selected ? _kPanelHeaderBg : _kSubBg,
            borderRadius: BorderRadius.circular(ui(16)),
            border: Border.all(
              color: selected ? _kPurple : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _PurpleCheckbox(checked: selected),
              SizedBox(width: ui(12)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 24 / 14,
                    fontWeight: AppFont.w500,
                    color: Colors.black,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        cell(_ClassKind.largeClass, '大班（班主任+教室）'),
        SizedBox(width: ui(20)),
        cell(_ClassKind.smallClass, '小班（任课老师）'),
      ],
    );
  }
}

class _PurpleCheckbox extends StatelessWidget {
  const _PurpleCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(16),
      height: ui(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? _kPurple : Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(
          color: checked ? _kPurple : _kCheckboxBorder,
          width: 1,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: ui(10), color: Colors.white)
          : null,
    );
  }
}

class _FormRowDouble extends StatelessWidget {
  const _FormRowDouble({
    required this.leftLabel,
    required this.leftField,
    required this.rightLabel,
    required this.rightField,
  });

  final String leftLabel;
  final Widget leftField;
  final String rightLabel;
  final Widget rightField;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Label(text: leftLabel),
        SizedBox(width: ui(20)),
        Expanded(child: leftField),
        SizedBox(width: ui(20)),
        _Label(text: rightLabel),
        SizedBox(width: ui(20)),
        Expanded(child: rightField),
      ],
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label),
        SizedBox(height: ui(12)),
        child,
      ],
    );
  }
}

class _LabeledInline extends StatelessWidget {
  const _LabeledInline({required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: ui(115),
          child: _Label(text: label),
        ),
        SizedBox(width: ui(20)),
        Expanded(child: field),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        height: 20 / 14,
        fontWeight: AppFont.w500,
        color: Colors.black,
        fontFamily: 'PingFang SC',
      ),
    );
  }
}

class _PlainInput extends StatelessWidget {
  const _PlainInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kFieldBorder, width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        cursorColor: _kPurple,
        style: TextStyle(
          fontSize: ui(14),
          height: 20 / 14,
          color: _kTextPrimary,
          fontFamily: 'PingFang SC',
        ),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _TransferPanel extends StatelessWidget {
  const _TransferPanel({
    required this.leftTitle,
    required this.rightTitle,
    required this.leftStudents,
    required this.rightStudents,
    required this.leftChecked,
    required this.rightChecked,
    required this.onLeftCheck,
    required this.onRightCheck,
    required this.onMoveRight,
    required this.onMoveLeft,
    this.searchPlaceholder = '搜索姓名/学号/专业',
    this.leftLoading = false,
    this.rightLoading = false,
  });

  final String leftTitle;
  final String rightTitle;
  final List<_StudentRecord> leftStudents;
  final List<_StudentRecord> rightStudents;
  final Set<String> leftChecked;
  final Set<String> rightChecked;
  final ValueChanged<String> onLeftCheck;
  final ValueChanged<String> onRightCheck;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveLeft;
  final String searchPlaceholder;
  final bool leftLoading;
  final bool rightLoading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _TransferList(
            title: leftTitle,
            students: leftStudents,
            checked: leftChecked,
            onCheck: onLeftCheck,
            searchPlaceholder: searchPlaceholder,
            loading: leftLoading,
          ),
        ),
        SizedBox(width: ui(24)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TransferArrow(
              direction: _ArrowDir.right,
              active: leftChecked.isNotEmpty,
              onTap: onMoveRight,
            ),
            SizedBox(height: ui(16)),
            _TransferArrow(
              direction: _ArrowDir.left,
              active: rightChecked.isNotEmpty,
              onTap: onMoveLeft,
            ),
          ],
        ),
        SizedBox(width: ui(24)),
        Expanded(
          child: _TransferList(
            title: rightTitle,
            students: rightStudents,
            checked: rightChecked,
            onCheck: onRightCheck,
            searchPlaceholder: searchPlaceholder,
            loading: rightLoading,
          ),
        ),
      ],
    );
  }
}

enum _ArrowDir { left, right }

class _TransferArrow extends StatelessWidget {
  const _TransferArrow({
    required this.direction,
    required this.active,
    required this.onTap,
  });

  final _ArrowDir direction;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = active ? _kPanelHeaderBg : _kSubBg;
    final fg = active ? _kPurple : _kTextHint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: ui(36),
        height: ui(36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Icon(
          direction == _ArrowDir.right
              ? Icons.chevron_right
              : Icons.chevron_left,
          size: ui(16),
          color: fg,
        ),
      ),
    );
  }
}

class _TransferList extends StatelessWidget {
  const _TransferList({
    required this.title,
    required this.students,
    required this.checked,
    required this.onCheck,
    required this.searchPlaceholder,
    this.loading = false,
  });

  final String title;
  final List<_StudentRecord> students;
  final Set<String> checked;
  final ValueChanged<String> onCheck;
  final String searchPlaceholder;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(406),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: _kBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: ui(48),
            color: _kPanelHeaderBg,
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(width: ui(6)),
                Text(
                  '(${students.length})',
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(8), ui(16), ui(0)),
            child: _SearchBar(placeholder: searchPlaceholder),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                      ),
                    ),
                  )
                : students.isEmpty
                ? Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(
                        fontSize: ui(13),
                        height: 1.4,
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      ui(16),
                      ui(12),
                      ui(16),
                      ui(12),
                    ),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                    itemBuilder: (ctx, idx) {
                      final s = students[idx];
                      final on = checked.contains(s.id);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onCheck(s.id),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _PurpleCheckbox(checked: on),
                            SizedBox(width: ui(12)),
                            Text(
                              s.studentNo,
                              style: TextStyle(
                                fontSize: ui(12),
                                height: 1.2,
                                color: _kTextHint,
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                            SizedBox(width: ui(12)),
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: ui(14),
                                height: 1.2,
                                fontWeight: AppFont.w500,
                                color: _kTextPrimary,
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                            SizedBox(width: ui(12)),
                            Expanded(
                              child: Text(
                                s.fullMajor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextPrimary,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.placeholder});

  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorder, width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Row(
        children: [
          Icon(Icons.search, size: ui(16), color: const Color(0xFFC6C6C6)),
          SizedBox(width: ui(10)),
          Expanded(
            child: TextField(
              cursorColor: _kPurple,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                color: _kTextPrimary,
                fontFamily: 'PingFang SC',
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 任课老师穿梭框
// ============================================================================

/// 与 [_TransferPanel] 同样的左右两列 + 中间双向箭头布局，行内容针对教师：
/// `[checkbox][姓名 + 工号][学科]………[部门]`。
class _TeacherTransferPanel extends StatelessWidget {
  const _TeacherTransferPanel({
    required this.leftTitle,
    required this.rightTitle,
    required this.leftTeachers,
    required this.rightTeachers,
    required this.leftChecked,
    required this.rightChecked,
    required this.onLeftCheck,
    required this.onRightCheck,
    required this.onMoveRight,
    required this.onMoveLeft,
    this.searchPlaceholder = '搜索姓名/工号/学科',
    this.leftLoading = false,
    this.rightLoading = false,
  });

  final String leftTitle;
  final String rightTitle;
  final List<_TeacherOption> leftTeachers;
  final List<_TeacherOption> rightTeachers;
  final Set<String> leftChecked;
  final Set<String> rightChecked;
  final ValueChanged<String> onLeftCheck;
  final ValueChanged<String> onRightCheck;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveLeft;
  final String searchPlaceholder;
  final bool leftLoading;
  final bool rightLoading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _TeacherTransferList(
            title: leftTitle,
            teachers: leftTeachers,
            checked: leftChecked,
            onCheck: onLeftCheck,
            searchPlaceholder: searchPlaceholder,
            loading: leftLoading,
          ),
        ),
        SizedBox(width: ui(24)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TransferArrow(
              direction: _ArrowDir.right,
              active: leftChecked.isNotEmpty,
              onTap: onMoveRight,
            ),
            SizedBox(height: ui(16)),
            _TransferArrow(
              direction: _ArrowDir.left,
              active: rightChecked.isNotEmpty,
              onTap: onMoveLeft,
            ),
          ],
        ),
        SizedBox(width: ui(24)),
        Expanded(
          child: _TeacherTransferList(
            title: rightTitle,
            teachers: rightTeachers,
            checked: rightChecked,
            onCheck: onRightCheck,
            searchPlaceholder: searchPlaceholder,
            loading: rightLoading,
          ),
        ),
      ],
    );
  }
}

class _TeacherTransferList extends StatelessWidget {
  const _TeacherTransferList({
    required this.title,
    required this.teachers,
    required this.checked,
    required this.onCheck,
    required this.searchPlaceholder,
    this.loading = false,
  });

  final String title;
  final List<_TeacherOption> teachers;
  final Set<String> checked;
  final ValueChanged<String> onCheck;
  final String searchPlaceholder;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(406),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: _kBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: ui(48),
            color: _kPanelHeaderBg,
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(width: ui(6)),
                Text(
                  '(${teachers.length})',
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(8), ui(16), ui(0)),
            child: _SearchBar(placeholder: searchPlaceholder),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                      ),
                    ),
                  )
                : teachers.isEmpty
                ? Center(
                    child: Text(
                      '暂无教师',
                      style: TextStyle(
                        fontSize: ui(13),
                        height: 1.4,
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      ui(16),
                      ui(12),
                      ui(16),
                      ui(12),
                    ),
                    itemCount: teachers.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(16)),
                    itemBuilder: (ctx, idx) {
                      final t = teachers[idx];
                      final on = checked.contains(t.id);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onCheck(t.id),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _PurpleCheckbox(checked: on),
                            SizedBox(width: ui(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          t.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: ui(14),
                                            height: 1.2,
                                            fontWeight: AppFont.w500,
                                            color: _kTextPrimary,
                                            fontFamily: 'PingFang SC',
                                          ),
                                        ),
                                      ),
                                      if (t.workNo.isNotEmpty) ...[
                                        SizedBox(width: ui(8)),
                                        Text(
                                          t.workNo,
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
                                  if (t.subject.isNotEmpty) ...[
                                    SizedBox(height: ui(4)),
                                    Text(
                                      t.subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        height: 1.2,
                                        color: _kTextPrimary,
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (t.dept.isNotEmpty) ...[
                              SizedBox(width: ui(8)),
                              Text(
                                t.dept,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  height: 1.2,
                                  color: _kTextSub,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

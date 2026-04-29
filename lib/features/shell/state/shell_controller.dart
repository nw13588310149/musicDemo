import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../data/shell_repository.dart';
import 'shell_state.dart';

final shellControllerProvider =
    StateNotifierProvider<ShellController, ShellState>((ref) {
      final repository = ref.watch(shellRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      final controller = ShellController(
        repository: repository,
        storage: storage,
      );
      return controller;
    });

class ShellController extends StateNotifier<ShellState> {
  ShellController({
    required ShellRepository repository,
    required AppStorage storage,
  }) : _repository = repository,
       _storage = storage,
       super(createInitialShellState(storage)) {
    _init();
  }

  final ShellRepository _repository;
  final AppStorage _storage;

  Timer? _logoTimer;
  Timer? _noticeTimer;

  void toggleCollapse() {
    state = state.copyWith(collapsed: !state.collapsed);
  }

  void toggleFloatingMenu() {
    state = state.copyWith(showFloatingMenu: !state.showFloatingMenu);
  }

  void closeFloatingMenu() {
    state = state.copyWith(showFloatingMenu: false);
  }

  Future<void> logout() async {
    await _repository.logout();
    await _storage.clearToken();
  }

  Future<void> markAllNoticeRead() async {
    final ids = state.noticeItems.map((e) => e.id).toList();
    if (ids.isEmpty) {
      return;
    }
    final response = await _repository.markRead(ids);
    if (response.code == 0) {
      state = state.copyWith(unreadCount: 0, noticeItems: const []);
    }
  }

  Future<void> refreshNoticeData() async {
    final countResponse = await _repository.getUnreadCount();
    if (countResponse.code != 0) {
      return;
    }

    final count = _readUnreadCount(countResponse.data);
    if (count <= 0) {
      state = state.copyWith(unreadCount: 0, noticeItems: const []);
      _syncCampusBadge(0);
      return;
    }

    final listResponse = await _repository.getMessageList();
    if (listResponse.code != 0) {
      return;
    }

    final notices = _parseNoticeList(listResponse.data);
    state = state.copyWith(unreadCount: count, noticeItems: notices);
    _syncCampusBadge(count);
  }

  Future<void> refreshUserAndSchool() async {
    // 并行请求用户信息与学校信息，总耗时降为单次 RTT
    final responses = await Future.wait([
      _repository.getMyInfo(),
      _repository.getSchoolInfo(),
    ]);
    final myInfoResponse = responses[0];
    final schoolResponse = responses[1];

    if (myInfoResponse.code == 0) {
      final userMap = _extractUser(myInfoResponse.data);
      state = state.copyWith(
        user: ShellUser(
          nickname: userMap['nickname']?.toString() ?? '',
          realname: userMap['realname']?.toString() ?? '',
          avatarUrl: userMap['headUrl']?.toString() ?? '',
          province: userMap['province']?.toString() ?? '',
          role: userMap['role']?.toString() ?? '',
          identity: userMap['identity']?.toString() ?? '',
        ),
      );
    }

    if (schoolResponse.code == 0 &&
        schoolResponse.data is Map<String, dynamic>) {
      final data = schoolResponse.data as Map<String, dynamic>;
      final logo = data['logo']?.toString() ?? '';
      final switchFlag = data['coursewareSwitch'];
      final schoolCoursewareEnabled = switchFlag == true || switchFlag == 1;
      state = state.copyWith(
        logoUrl: logo,
        schoolCoursewareEnabled: schoolCoursewareEnabled,
        navItems: buildDefaultNavItems(
          schoolCoursewareEnabled: schoolCoursewareEnabled,
        ),
      );
      _syncCampusBadge(state.unreadCount);
    }
  }

  @override
  void dispose() {
    _logoTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // 用户+学校数据优先到位（菜单/头像依赖它），消息数据后台并行，不阻塞首帧
    await refreshUserAndSchool();
    unawaited(refreshNoticeData());

    _logoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshUserAndSchool());
    });
    _noticeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refreshNoticeData());
    });
  }

  int _readUnreadCount(dynamic data) {
    if (data is Map<String, dynamic>) {
      final value = data['unReadMsgCount'];
      if (value is int) {
        return value;
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  List<ShellNoticeItem> _parseNoticeList(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <ShellNoticeItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      result.add(
        ShellNoticeItem(
          id: _toInt(item['id']),
          targetType: _toInt(item['targetType']),
          content: item['content']?.toString() ?? '',
          createTime: item['createTime']?.toString() ?? '',
        ),
      );
    }
    return result;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    return const {};
  }

  void _syncCampusBadge(int unreadCount) {
    final updated = state.navItems.map((item) {
      if (item.route == RoutePaths.smartCampus) {
        return item.copyWith(badge: unreadCount);
      }
      return item;
    }).toList();
    state = state.copyWith(navItems: updated);
  }
}

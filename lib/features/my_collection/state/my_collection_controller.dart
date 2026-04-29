import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/my_collection_repository.dart';
import 'my_collection_state.dart';

final myCollectionControllerProvider =
    StateNotifierProvider.autoDispose<
      MyCollectionController,
      MyCollectionState
    >((ref) {
      final repository = ref.watch(myCollectionRepositoryProvider);
      return MyCollectionController(repository: repository);
    });

class MyCollectionController extends StateNotifier<MyCollectionState> {
  MyCollectionController({required MyCollectionRepository repository})
    : _repository = repository,
      super(const MyCollectionState()) {
    unawaited(refresh());
  }

  final MyCollectionRepository _repository;

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);
      final categoryResponse = await _repository.getCategories();
      final tabs = _parseTabs(categoryResponse.data);
      final activeType = _resolveActiveType(tabs, state.activeType);
      final itemResponse = await _repository.getItems(type: activeType);
      state = state.copyWith(
        loading: false,
        tabs: tabs,
        activeType: activeType,
        items: _parseItems(itemResponse.data, activeType),
        errorMessage: itemResponse.isSuccess
            ? null
            : _fallbackMessage(itemResponse.msg),
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载收藏失败，请稍后重试');
    }
  }

  Future<void> selectType(int type) async {
    if (type == state.activeType) {
      return;
    }
    try {
      state = state.copyWith(
        activeType: type,
        loading: true,
        clearError: true,
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
      final response = await _repository.getItems(type: type);
      state = state.copyWith(
        loading: false,
        items: _parseItems(response.data, type),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg),
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载收藏失败，请稍后重试');
    }
  }

  Future<String?> removeFavorite(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.removeFavorite(
      targetId: item.targetId,
      type: item.type,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg);
    }
    state = state.copyWith(
      items: state.items.where((entry) => entry.id != item.id).toList(),
    );
    return null;
  }

  Future<String?> openShare(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, fallback: '鍔犺浇鐝骇鍒楄〃澶辫触');
    }
    final classes = <CollectionShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      classes.add(CollectionShareClass(id: id, name: name));
    }
    state = state.copyWith(shareTarget: item, shareClasses: classes);
    return null;
  }

  void toggleShareClass(int id) {
    state = state.copyWith(
      shareClasses: state.shareClasses.map((item) {
        if (item.id != id) {
          return item;
        }
        return item.copyWith(selected: !item.selected);
      }).toList(),
    );
  }

  void closeShare() {
    state = state.copyWith(
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
  }

  Future<String?> sendShare() async {
    final target = state.shareTarget;
    if (target == null) {
      return '璇峰厛閫夋嫨瑕佸垎浜殑鏀惰棌';
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return '璇峰厛閫夋嫨瑕佸垎浜殑鐝骇';
    }

    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareToClass(
        classId: item.id,
        type: target.type,
        payload: target.rawPayload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(response.msg, fallback: '鍒嗕韩澶辫触');
      }
    }
    state = state.copyWith(
      busy: false,
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
    return null;
  }

  List<CollectionTabItem> _parseTabs(dynamic data) {
    final result = <CollectionTabItem>[];
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final label = item['name']?.toString().trim() ?? '';
        final type = kCollectionTypeByLabel[label];
        if (type == null) {
          continue;
        }
        result.add(CollectionTabItem(type: type, label: label));
      }
    }
    if (result.isEmpty) {
      return kCollectionTypeByLabel.entries
          .map((item) => CollectionTabItem(type: item.value, label: item.key))
          .toList();
    }
    result.sort((a, b) => a.type.compareTo(b.type));
    return result;
  }

  List<CollectionEntry> _parseItems(dynamic data, int activeType) {
    if (data is! List) {
      return const <CollectionEntry>[];
    }
    final result = <CollectionEntry>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final target = raw['target'];
      if (target is! Map<String, dynamic>) {
        continue;
      }
      final title = (target['title'] ?? target['name'] ?? '').toString().trim();
      if (title.isEmpty) {
        continue;
      }
      result.add(
        CollectionEntry(
          id: _toInt(raw['id']),
          targetId: _toInt(raw['targetId']),
          type: _toInt(raw['type']) == 0 ? activeType : _toInt(raw['type']),
          title: title,
          subtitle: _resolveSubtitle(target, activeType),
          coverUrl: (target['coverImg'] ?? target['param1'] ?? '').toString(),
          authorName: _resolveAuthor(target),
          avatarUrl: (target['avatarUrl'] ?? target['headImg'] ?? '')
              .toString(),
          metricText: _resolveMetric(target),
          durationText: (target['duration'] ?? '5:32').toString(),
          rawPayload: Map<String, dynamic>.from(target),
        ),
      );
    }
    return result;
  }

  int _resolveActiveType(List<CollectionTabItem> tabs, int current) {
    if (tabs.any((item) => item.type == current)) {
      return current;
    }
    return tabs.firstOrNull?.type ?? 4;
  }

  String _resolveSubtitle(Map<String, dynamic> target, int type) {
    final raw = (target['subtitle'] ?? target['param2'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return switch (type) {
      1 => '鏍囧噯闊充笂涓嬭浜屽害',
      2 => '鍩虹涔愮悊鐭ヨ瘑姊崇悊',
      3 => '鍚煶鍗曢煶涓撻」缁冧範',
      4 => '澹颁箰璁粌閲嶇偣鏁寸悊',
      5 => '鍣ㄤ箰瀛︿範缁冧範瑕佺偣',
      _ => '',
    };
  }

  String _resolveAuthor(Map<String, dynamic> target) {
    for (final key in <String>[
      'nickname',
      'realname',
      'teacherName',
      'author',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '闊充箰涔嬭矾';
  }

  String _resolveMetric(Map<String, dynamic> target) {
    final count = _toInt(target['playCount']);
    if (count > 0) {
      return '$count';
    }
    return '723';
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fallbackMessage(String raw, {String fallback = '鎿嶄綔澶辫触锛岃绋嶅悗閲嶈瘯'}) {
    return raw.trim().isEmpty ? fallback : raw.trim();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

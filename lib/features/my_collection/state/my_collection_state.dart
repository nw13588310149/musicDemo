import 'package:flutter/material.dart';

class CollectionTabItem {
  const CollectionTabItem({
    required this.type,
    required this.label,
  });

  final int type;
  final String label;
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.targetId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.authorName,
    required this.avatarUrl,
    required this.metricText,
    required this.durationText,
    required this.rawPayload,
  });

  final int id;
  final int targetId;
  final int type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String authorName;
  final String avatarUrl;
  final String metricText;
  final String durationText;
  final Map<String, dynamic> rawPayload;

  bool get isVideo => type == 6;
}

class CollectionShareClass {
  const CollectionShareClass({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final int id;
  final String name;
  final bool selected;

  CollectionShareClass copyWith({int? id, String? name, bool? selected}) {
    return CollectionShareClass(
      id: id ?? this.id,
      name: name ?? this.name,
      selected: selected ?? this.selected,
    );
  }
}

class MyCollectionState {
  const MyCollectionState({
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.tabs = const <CollectionTabItem>[],
    this.activeType = 4,
    this.items = const <CollectionEntry>[],
    this.shareClasses = const <CollectionShareClass>[],
    this.shareTarget,
  });

  final bool loading;
  final bool busy;
  final String? errorMessage;
  final List<CollectionTabItem> tabs;
  final int activeType;
  final List<CollectionEntry> items;
  final List<CollectionShareClass> shareClasses;
  final CollectionEntry? shareTarget;

  MyCollectionState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    List<CollectionTabItem>? tabs,
    int? activeType,
    List<CollectionEntry>? items,
    List<CollectionShareClass>? shareClasses,
    CollectionEntry? shareTarget,
    bool clearShareTarget = false,
  }) {
    return MyCollectionState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tabs: tabs ?? this.tabs,
      activeType: activeType ?? this.activeType,
      items: items ?? this.items,
      shareClasses: shareClasses ?? this.shareClasses,
      shareTarget: clearShareTarget ? null : (shareTarget ?? this.shareTarget),
    );
  }
}

const Map<String, int> kCollectionTypeByLabel = <String, int>{
  '视唱': 1,
  '乐理': 2,
  '听写': 3,
  '声乐': 4,
  '器乐': 5,
  '视频': 6,
};

const List<Color> kCollectionAccentPalette = <Color>[
  Color(0xFFE8D9FF),
  Color(0xFFD9F0FF),
  Color(0xFFFFE6D8),
  Color(0xFFE1F7E9),
];

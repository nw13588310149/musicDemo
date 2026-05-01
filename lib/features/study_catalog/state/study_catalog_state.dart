import 'package:flutter/foundation.dart';

import '../../../app/router/route_paths.dart';

enum StudyCatalogGroupField { none, shortText1, shortText2 }

enum StudyCatalogSubtitleField { none, shortText1, shortText2 }

enum StudyCatalogArtworkLabel {
  dictation,
  sightSinging,
  musicTheory,
  answer,
  voice,
  instrumental,
}

@immutable
class StudyCatalogConfig {
  const StudyCatalogConfig({
    required this.key,
    required this.title,
    required this.type,
    required this.defaultFirstMenuId,
    required this.groupField,
    required this.subtitleField,
    required this.artworkLabel,
    required this.targetRoute,
    this.allowSecondMenu = false,
    this.targetArgsBuilder,
  });

  final String key;
  final String title;
  final int type;
  final String defaultFirstMenuId;
  final bool allowSecondMenu;
  final StudyCatalogGroupField groupField;
  final StudyCatalogSubtitleField subtitleField;
  final StudyCatalogArtworkLabel artworkLabel;
  final String targetRoute;
  final Map<String, dynamic> Function(
    StudyCatalogState state,
    StudyCatalogLesson lesson,
  )?
  targetArgsBuilder;

  static const dictation = StudyCatalogConfig(
    key: 'dictation',
    title: '听写',
    type: 3,
    defaultFirstMenuId: '8',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.shortText1,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.dictation,
    targetRoute: RoutePaths.musicPlay,
  );

  static const sightSinging = StudyCatalogConfig(
    key: 'sightSinging',
    title: '视唱',
    type: 1,
    defaultFirstMenuId: '1',
    groupField: StudyCatalogGroupField.shortText2,
    subtitleField: StudyCatalogSubtitleField.shortText1,
    artworkLabel: StudyCatalogArtworkLabel.sightSinging,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildSightSingingArgs,
  );

  static const musicTheory = StudyCatalogConfig(
    key: 'musicTheory',
    title: '乐理',
    type: 2,
    defaultFirstMenuId: '5',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.none,
    artworkLabel: StudyCatalogArtworkLabel.musicTheory,
    targetRoute: RoutePaths.theory,
    targetArgsBuilder: _buildMusicTheoryArgs,
  );

  static const answerQuestions = StudyCatalogConfig(
    key: 'answerQuestions',
    title: '试题',
    type: 10,
    defaultFirstMenuId: '63',
    allowSecondMenu: true,
    groupField: StudyCatalogGroupField.shortText1,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.answer,
    targetRoute: RoutePaths.answerEnd,
    targetArgsBuilder: _buildAnswerArgs,
  );

  static const voice = StudyCatalogConfig(
    key: 'voice',
    title: '声乐',
    type: 4,
    defaultFirstMenuId: '16',
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.shortText2,
    artworkLabel: StudyCatalogArtworkLabel.voice,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildVoiceInstrumentArgs,
  );

  static const instrumental = StudyCatalogConfig(
    key: 'instrumental',
    title: '器乐',
    type: 5,
    defaultFirstMenuId: '20',
    groupField: StudyCatalogGroupField.none,
    subtitleField: StudyCatalogSubtitleField.none,
    artworkLabel: StudyCatalogArtworkLabel.instrumental,
    targetRoute: RoutePaths.musicPlay,
    targetArgsBuilder: _buildVoiceInstrumentArgs,
  );
}

@immutable
class StudyCatalogPageArgs {
  const StudyCatalogPageArgs({
    required this.config,
    this.schoolMode = false,
    this.initialFirstMenuId,
    this.initialSecondMenuId,
  });

  final StudyCatalogConfig config;
  final bool schoolMode;
  final String? initialFirstMenuId;
  final String? initialSecondMenuId;

  @override
  bool operator ==(Object other) {
    return other is StudyCatalogPageArgs &&
        other.config.key == config.key &&
        other.schoolMode == schoolMode &&
        other.initialFirstMenuId == initialFirstMenuId &&
        other.initialSecondMenuId == initialSecondMenuId;
  }

  @override
  int get hashCode => Object.hash(
    config.key,
    schoolMode,
    initialFirstMenuId,
    initialSecondMenuId,
  );
}

@immutable
class StudyCatalogMenu {
  const StudyCatalogMenu({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<StudyCatalogMenuChild> children;
}

@immutable
class StudyCatalogMenuChild {
  const StudyCatalogMenuChild({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class StudyCatalogLesson {
  const StudyCatalogLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.groupTitle,
    required this.vip,
  });

  final String id;
  final String title;
  final String subtitle;
  final String groupTitle;
  final bool vip;
}

@immutable
class StudyCatalogLessonGroup {
  const StudyCatalogLessonGroup({required this.title, required this.lessons});

  final String title;
  final List<StudyCatalogLesson> lessons;
}

@immutable
class StudyCatalogState {
  const StudyCatalogState({
    required this.bootstrapping,
    required this.loading,
    required this.schoolMode,
    required this.showVipBadge,
    required this.province,
    required this.config,
    required this.menus,
    required this.selectedMenuId,
    required this.selectedChildId,
    required this.lessonGroups,
    required this.errorMessage,
    required this.vipExpireDate,
  });

  final bool bootstrapping;
  final bool loading;
  final bool schoolMode;
  final bool showVipBadge;
  final String province;
  final StudyCatalogConfig config;
  final List<StudyCatalogMenu> menus;
  final String? selectedMenuId;
  final String? selectedChildId;
  final List<StudyCatalogLessonGroup> lessonGroups;
  final String errorMessage;
  final DateTime? vipExpireDate;

  StudyCatalogMenu? get selectedMenu {
    for (final menu in menus) {
      if (menu.id == selectedMenuId) {
        return menu;
      }
    }
    return menus.isEmpty ? null : menus.first;
  }

  List<StudyCatalogMenuChild> get selectedChildren =>
      selectedMenu?.children ?? const <StudyCatalogMenuChild>[];

  List<StudyCatalogLesson> get flatLessons {
    final result = <StudyCatalogLesson>[];
    for (final group in lessonGroups) {
      result.addAll(group.lessons);
    }
    return result;
  }

  StudyCatalogState copyWith({
    bool? bootstrapping,
    bool? loading,
    bool? schoolMode,
    bool? showVipBadge,
    String? province,
    StudyCatalogConfig? config,
    List<StudyCatalogMenu>? menus,
    String? selectedMenuId,
    bool clearSelectedMenuId = false,
    String? selectedChildId,
    bool clearSelectedChildId = false,
    List<StudyCatalogLessonGroup>? lessonGroups,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? vipExpireDate,
    bool clearVipExpireDate = false,
  }) {
    return StudyCatalogState(
      bootstrapping: bootstrapping ?? this.bootstrapping,
      loading: loading ?? this.loading,
      schoolMode: schoolMode ?? this.schoolMode,
      showVipBadge: showVipBadge ?? this.showVipBadge,
      province: province ?? this.province,
      config: config ?? this.config,
      menus: menus ?? this.menus,
      selectedMenuId: clearSelectedMenuId
          ? null
          : (selectedMenuId ?? this.selectedMenuId),
      selectedChildId: clearSelectedChildId
          ? null
          : (selectedChildId ?? this.selectedChildId),
      lessonGroups: lessonGroups ?? this.lessonGroups,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      vipExpireDate: clearVipExpireDate
          ? null
          : (vipExpireDate ?? this.vipExpireDate),
    );
  }

  static StudyCatalogState initial(StudyCatalogConfig config) =>
      StudyCatalogState(
        bootstrapping: true,
        loading: false,
        schoolMode: false,
        showVipBadge: false,
        province: '甘肃',
        config: config,
        menus: const <StudyCatalogMenu>[],
        selectedMenuId: null,
        selectedChildId: null,
        lessonGroups: const <StudyCatalogLessonGroup>[],
        errorMessage: '',
        vipExpireDate: null,
      );
}

Map<String, dynamic> _buildSightSingingArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  return <String, dynamic>{
    'id': lesson.id,
    'type': 3,
    'all': state.flatLessons.map((item) => item.id).toList(growable: false),
  };
}

Map<String, dynamic> _buildMusicTheoryArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  final needsType = state.selectedMenuId == '6';
  return <String, dynamic>{'id': lesson.id, if (needsType) 'type': '1'};
}

Map<String, dynamic> _buildAnswerArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  final usesAnswerEnd2 =
      state.selectedMenuId == '63' || state.selectedMenuId == '64';
  return <String, dynamic>{
    'id': lesson.id,
    if (!usesAnswerEnd2) 'answerEndMode': true,
  };
}

Map<String, dynamic> _buildVoiceInstrumentArgs(
  StudyCatalogState state,
  StudyCatalogLesson lesson,
) {
  return <String, dynamic>{'id': lesson.id, 'type': 2};
}

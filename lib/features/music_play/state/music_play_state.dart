import 'package:flutter/foundation.dart';

@immutable
class MusicPlayPageArgs {
  const MusicPlayPageArgs({
    required this.id,
    this.type,
    this.allLessonIds = const <int>[],
  });

  final int id;
  final int? type;
  final List<int> allLessonIds;

  factory MusicPlayPageArgs.fromRaw(dynamic raw) {
    if (raw is MusicPlayPageArgs) {
      return raw;
    }
    if (raw is Map) {
      final all = <int>[];
      final rawAll = raw['all'];
      if (rawAll is List) {
        for (final value in rawAll) {
          final parsed = int.tryParse(value?.toString() ?? '');
          if (parsed != null && parsed > 0) {
            all.add(parsed);
          }
        }
      }
      final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
      final type = int.tryParse(raw['type']?.toString() ?? '');
      return MusicPlayPageArgs(id: id, type: type, allLessonIds: all);
    }
    return const MusicPlayPageArgs(id: 0);
  }

  @override
  bool operator ==(Object other) {
    return other is MusicPlayPageArgs &&
        other.id == id &&
        other.type == type &&
        listEquals(other.allLessonIds, allLessonIds);
  }

  @override
  int get hashCode => Object.hash(id, type, Object.hashAll(allLessonIds));
}

@immutable
class MusicPlayTrack {
  const MusicPlayTrack({required this.url, required this.title});

  final String url;
  final String title;
}

@immutable
class MusicPlayDetail {
  const MusicPlayDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.favorite,
    required this.vipOnly,
    required this.questionImages,
    required this.answerImages,
    required this.tracks,
    required this.longTextHtml,
  });

  final int id;
  final int type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final bool favorite;
  final bool vipOnly;
  final List<String> questionImages;
  final List<String> answerImages;
  final List<MusicPlayTrack> tracks;
  final String longTextHtml;
}

@immutable
class MusicPlayShareClass {
  const MusicPlayShareClass({
    required this.id,
    required this.name,
    required this.checked,
  });

  final String id;
  final String name;
  final bool checked;

  MusicPlayShareClass copyWith({bool? checked}) =>
      MusicPlayShareClass(id: id, name: name, checked: checked ?? this.checked);

  factory MusicPlayShareClass.fromJson(Map raw) {
    return MusicPlayShareClass(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      checked: false,
    );
  }
}

@immutable
class MusicPlayState {
  const MusicPlayState({
    required this.args,
    required this.loading,
    required this.ready,
    required this.detail,
    required this.errorMessage,
    required this.showAnswer,
    required this.activeImageIndex,
    required this.activeTrackIndex,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.activePianoNotes,
    required this.frequencyBands,
    required this.shareDialogVisible,
    required this.classLoading,
    required this.sending,
    required this.classList,
  });

  final MusicPlayPageArgs args;
  final bool loading;
  final bool ready;
  final MusicPlayDetail? detail;
  final String errorMessage;
  final bool showAnswer;
  final int activeImageIndex;
  final int activeTrackIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final Set<String> activePianoNotes;
  final List<double> frequencyBands;
  final bool shareDialogVisible;
  final bool classLoading;
  final bool sending;
  final List<MusicPlayShareClass> classList;

  bool get hasDetail => detail != null;

  List<String> get visibleImages {
    final current = detail;
    if (current == null) {
      return const <String>[];
    }
    if (showAnswer) {
      return current.answerImages;
    }
    return current.questionImages;
  }

  MusicPlayTrack? get activeTrack {
    final current = detail;
    if (current == null || current.tracks.isEmpty) {
      return null;
    }
    final safeIndex = activeTrackIndex.clamp(0, current.tracks.length - 1);
    return current.tracks[safeIndex];
  }

  bool get showsKeyboard {
    final current = detail;
    if (current == null) {
      return true;
    }
    return current.type != 4 && current.type != 5;
  }

  /// 声乐(type=4) 或 器乐(type=5) 课程，使用与 1.0 一致的"五线谱/简谱"布局。
  bool get isVocalOrInstrumental {
    final t = detail?.type;
    return t == 4 || t == 5;
  }

  MusicPlayState copyWith({
    MusicPlayPageArgs? args,
    bool? loading,
    bool? ready,
    MusicPlayDetail? detail,
    bool clearDetail = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? showAnswer,
    int? activeImageIndex,
    int? activeTrackIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    Set<String>? activePianoNotes,
    List<double>? frequencyBands,
    bool? shareDialogVisible,
    bool? classLoading,
    bool? sending,
    List<MusicPlayShareClass>? classList,
  }) {
    return MusicPlayState(
      args: args ?? this.args,
      loading: loading ?? this.loading,
      ready: ready ?? this.ready,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      showAnswer: showAnswer ?? this.showAnswer,
      activeImageIndex: activeImageIndex ?? this.activeImageIndex,
      activeTrackIndex: activeTrackIndex ?? this.activeTrackIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      activePianoNotes: activePianoNotes ?? this.activePianoNotes,
      frequencyBands: frequencyBands ?? this.frequencyBands,
      shareDialogVisible: shareDialogVisible ?? this.shareDialogVisible,
      classLoading: classLoading ?? this.classLoading,
      sending: sending ?? this.sending,
      classList: classList ?? this.classList,
    );
  }

  static MusicPlayState initial(MusicPlayPageArgs args) => MusicPlayState(
    args: args,
    loading: true,
    ready: false,
    detail: null,
    errorMessage: '',
    showAnswer: true,
    activeImageIndex: 0,
    activeTrackIndex: 0,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    speed: 1,
    activePianoNotes: const <String>{},
    frequencyBands: const <double>[],
    shareDialogVisible: false,
    classLoading: false,
    sending: false,
    classList: const <MusicPlayShareClass>[],
  );
}

import 'dart:typed_data';

enum RecordingViewMode { list, record, preview }

enum RecordingPhase { idle, recording, paused }

class RecordingCategoryItem {
  const RecordingCategoryItem({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;
}

class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.url,
    required this.durationLabel,
    required this.waveform,
    required this.payload,
    this.isLocalDraft = false,
  });

  final int id;
  final int categoryId;
  final String name;
  final String url;
  final String durationLabel;
  final List<double> waveform;
  final Map<String, dynamic> payload;
  final bool isLocalDraft;
}

class RecordingShareClass {
  const RecordingShareClass({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final int id;
  final String name;
  final bool selected;

  RecordingShareClass copyWith({int? id, String? name, bool? selected}) {
    return RecordingShareClass(
      id: id ?? this.id,
      name: name ?? this.name,
      selected: selected ?? this.selected,
    );
  }
}

class RecordingSystemState {
  const RecordingSystemState({
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.viewMode = RecordingViewMode.list,
    this.categories = const <RecordingCategoryItem>[],
    this.selectedCategoryId = 0,
    this.items = const <RecordingEntry>[],
    this.searchQuery = '',
    this.recordingPhase = RecordingPhase.idle,
    this.elapsedMs = 0,
    this.liveWaveform = const <double>[],
    this.previewItem,
    this.previewSource,
    this.previewPositionMs = 0,
    this.previewDurationMs = 0,
    this.previewPlaying = false,
    this.previewPlaybackRate = 1,
    this.previewCollected = false,
    this.recordedBytes,
    this.showSaveDialog = false,
    this.showShareDialog = false,
    this.shareClasses = const <RecordingShareClass>[],
    this.selectedSaveCategoryId = 0,
    this.pendingTitle = '',
    this.selectedEffectIndex = 0,
  });

  final bool loading;
  final bool busy;
  final String? errorMessage;
  final RecordingViewMode viewMode;
  final List<RecordingCategoryItem> categories;
  final int selectedCategoryId;
  final List<RecordingEntry> items;
  final String searchQuery;
  final RecordingPhase recordingPhase;
  final int elapsedMs;
  final List<double> liveWaveform;
  final RecordingEntry? previewItem;
  final String? previewSource;
  final int previewPositionMs;
  final int previewDurationMs;
  final bool previewPlaying;
  final double previewPlaybackRate;
  final bool previewCollected;
  final Uint8List? recordedBytes;
  final bool showSaveDialog;
  final bool showShareDialog;
  final List<RecordingShareClass> shareClasses;
  final int selectedSaveCategoryId;
  final String pendingTitle;
  final int selectedEffectIndex;

  List<RecordingEntry> get visibleItems {
    final keyword = searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
  }

  RecordingSystemState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    RecordingViewMode? viewMode,
    List<RecordingCategoryItem>? categories,
    int? selectedCategoryId,
    List<RecordingEntry>? items,
    String? searchQuery,
    RecordingPhase? recordingPhase,
    int? elapsedMs,
    List<double>? liveWaveform,
    RecordingEntry? previewItem,
    bool clearPreviewItem = false,
    String? previewSource,
    bool clearPreviewSource = false,
    int? previewPositionMs,
    int? previewDurationMs,
    bool? previewPlaying,
    double? previewPlaybackRate,
    bool? previewCollected,
    Uint8List? recordedBytes,
    bool clearRecordedBytes = false,
    bool? showSaveDialog,
    bool? showShareDialog,
    List<RecordingShareClass>? shareClasses,
    int? selectedSaveCategoryId,
    String? pendingTitle,
    int? selectedEffectIndex,
  }) {
    return RecordingSystemState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      viewMode: viewMode ?? this.viewMode,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      recordingPhase: recordingPhase ?? this.recordingPhase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      liveWaveform: liveWaveform ?? this.liveWaveform,
      previewItem: clearPreviewItem ? null : (previewItem ?? this.previewItem),
      previewSource: clearPreviewSource
          ? null
          : (previewSource ?? this.previewSource),
      previewPositionMs: previewPositionMs ?? this.previewPositionMs,
      previewDurationMs: previewDurationMs ?? this.previewDurationMs,
      previewPlaying: previewPlaying ?? this.previewPlaying,
      previewPlaybackRate: previewPlaybackRate ?? this.previewPlaybackRate,
      previewCollected: previewCollected ?? this.previewCollected,
      recordedBytes: clearRecordedBytes ? null : (recordedBytes ?? this.recordedBytes),
      showSaveDialog: showSaveDialog ?? this.showSaveDialog,
      showShareDialog: showShareDialog ?? this.showShareDialog,
      shareClasses: shareClasses ?? this.shareClasses,
      selectedSaveCategoryId: selectedSaveCategoryId ?? this.selectedSaveCategoryId,
      pendingTitle: pendingTitle ?? this.pendingTitle,
      selectedEffectIndex: selectedEffectIndex ?? this.selectedEffectIndex,
    );
  }
}

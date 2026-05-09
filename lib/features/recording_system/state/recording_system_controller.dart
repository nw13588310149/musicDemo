import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../audio/recording_bytes_loader.dart';
import '../data/recording_system_repository.dart';
import 'recording_system_state.dart';

// IMPORTANT - encoding note for maintainers:
// Strings AND comments in this file are pure ASCII / English. CJK strings
// shown in the UI are kept here as `\uXXXX` escapes; the UI layer renders
// them with `fontFamily: 'PingFang SC'`. This keeps the file binary-safe
// regardless of editor codepage and avoids the historical "?????" mojibake
// we hit when saving Chinese in this controller through Cursor on Windows.

/// How fast the recorder polls amplitude. ~12 samples / second is enough
/// for a smooth scrolling waveform without hammering the platform channel.
const Duration _kAmplitudePollInterval = Duration(milliseconds: 80);

/// How fast we tick the elapsed-time stopwatch. 30 fps is plenty for the
/// `00:00.00` (centisecond) display and avoids a microtask flood.
const Duration _kStopwatchTickInterval = Duration(milliseconds: 33);

/// Maximum number of amplitude samples we keep around for the live
/// scrolling waveform notification. Roughly 6.5s @ 80ms/sample.
const int _kLiveWaveSampleCap = 80;

/// Amplitude (dBFS) ? linear 0..1 normalization for the waveform painter.
/// dBFS values are negative; -60 is "very quiet", 0 is "peak". Clamp into
/// a 60 dB range so room-noise samples don't render as flat zeros.
double _normalizeAmplitudeDb(double current) {
  if (!current.isFinite) return 0;
  final clamped = current.clamp(-60.0, 0.0);
  return ((clamped + 60.0) / 60.0).toDouble();
}

/// Recording system controller, backed by:
///   * `record` (`AudioRecorder`) for capture on every platform we ship to,
///     including Web (browser MediaRecorder).
///   * `just_audio` (`AudioPlayer`) for playback. Single instance, single
///     codepath; works the same on iOS/Android/macOS/Windows/Web.
///
/// The controller exposes three [ValueNotifier]s for UI surfaces that update
/// at high frequency. The Riverpod state itself only carries low-frequency
/// fields (current view mode, recording phase, error banner ?) so opening
/// the recording page doesn't kick off a 30Hz `state.copyWith` storm.
final recordingSystemControllerProvider =
    StateNotifierProvider<RecordingSystemController, RecordingSystemState>((
      ref,
    ) {
      final repository = ref.watch(recordingSystemRepositoryProvider);
      return RecordingSystemController(repository: repository);
    });

class RecordingSystemController extends StateNotifier<RecordingSystemState> {
  RecordingSystemController({required RecordingSystemRepository repository})
    : _repository = repository,
      super(const RecordingSystemState()) {
    unawaited(refresh());
  }

  final RecordingSystemRepository _repository;

  // ?? Native handles, lazily created ????????????????????????????????????
  // Lazy because (a) we don't want to ask for mic permission until the
  // user actually taps record, and (b) some platforms (CI / desktop) lack
  // either binary and would crash a sync constructor.
  AudioRecorder? _recorder;
  AudioPlayer? _player;

  // ?? High-frequency notifiers ??????????????????????????????????????????
  /// Elapsed milliseconds during recording. Driven by [Stopwatch] +
  /// `Timer.periodic(33ms)` (?30fps) and pushed only when the int value
  /// changes (so identical ticks short-circuit at the notifier).
  final ValueNotifier<int> elapsedMs = ValueNotifier<int>(0);

  /// Recent amplitude samples for the live scrolling wave (0..1 each).
  /// Capped at [_kLiveWaveSampleCap]; we drop oldest so newest stays right.
  final ValueNotifier<List<double>> liveAmplitudes =
      ValueNotifier<List<double>>(const <double>[]);

  /// Preview playback position. Driven by [AudioPlayer.positionStream] and
  /// pushed only on `inMilliseconds` change.
  final ValueNotifier<int> previewPositionMs = ValueNotifier<int>(0);

  /// Preview playback total duration. Driven by [AudioPlayer.durationStream]
  /// (or seeded from the backend `duration` string before the player
  /// resolves it).
  final ValueNotifier<int> previewDurationMs = ValueNotifier<int>(0);

  // ?? Stopwatch + amplitude wiring ??????????????????????????????????????
  Stopwatch? _stopwatch;
  Timer? _stopwatchTicker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<RecordState>? _recordStateSub;

  /// Full amplitude history of the active recording, snapshotted onto the
  /// preview entry on stop. We keep the full list (not just the recent N)
  /// so the preview wave always covers the entire clip.
  final List<double> _amplitudeHistory = <double>[];

  // ?? Player wiring ?????????????????????????????????????????????????????
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  /// Last URL we successfully prepared the player with. Used to short-
  /// circuit re-prepare when the user taps play/pause repeatedly.
  String? _preparedPlayerSource;

  /// Local file path / blob URL of the just-finalized recording. Needed
  /// after stop() for upload + as the fallback preview source.
  String? _currentRecordingPath;

  bool _disposed = false;

  /// Set to true the first time we detect the platform refuses to record
  /// (web without permission, MissingPluginException on desktop, ?). We
  /// surface a clear error and short-circuit subsequent attempts.
  bool _audioFeatureBroken = false;

  // ?? Localized message bank (Unicode-escaped to stay binary-safe) ??????
  static const _zhUnsupported =
      '\u5f53\u524d\u5e73\u53f0\u6682\u4e0d\u652f\u6301\u5f55\u97f3\uff0c\u8bf7\u5728 iPad / \u79fb\u52a8\u7aef\u4f7f\u7528\u3002';
  static const _zhLoadListFailed =
      '\u52a0\u8f7d\u5f55\u97f3\u5217\u8868\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  static const _zhLoadFoldersFailed = '\u52a0\u8f7d\u6587\u4ef6\u5939\u5931\u8d25';
  static const _zhLoadRecordingsFailed = '\u52a0\u8f7d\u5f55\u97f3\u5931\u8d25';
  static const _zhSwitchCategoryFailed = '\u5207\u6362\u5206\u7c7b\u5931\u8d25';
  static const _zhBackToFoldersFailed =
      '\u8fd4\u56de\u6587\u4ef6\u5939\u5217\u8868\u5931\u8d25';
  static const _zhEnterCategoryName = '\u8bf7\u8f93\u5165\u5206\u7c7b\u540d\u79f0';
  static const _zhCreateCategoryFailed = '\u65b0\u5efa\u5206\u7c7b\u5931\u8d25';
  static const _zhDeleteCategoryFailed = '\u5220\u9664\u5206\u7c7b\u5931\u8d25';
  static const _zhRenameCategoryFailed = '\u91cd\u547d\u540d\u5206\u7c7b\u5931\u8d25';
  static const _zhInvalidCategory = '\u65e0\u6548\u7684\u5206\u7c7b';
  static const _zhEnterFolderName = '\u8bf7\u8f93\u5165\u6587\u4ef6\u5939\u540d\u79f0';
  static const _zhPickCategoryFirst =
      '\u8bf7\u5148\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b';
  static const _zhCreateFolderFailed = '\u65b0\u5efa\u6587\u4ef6\u5939\u5931\u8d25';
  static const _zhRenameFolderFailed = '\u91cd\u547d\u540d\u6587\u4ef6\u5939\u5931\u8d25';
  static const _zhDeleteFolderFailed = '\u5220\u9664\u6587\u4ef6\u5939\u5931\u8d25';
  static const _zhInvalidFolder = '\u65e0\u6548\u7684\u6587\u4ef6\u5939';
  static const _zhMicPermission =
      '\u8bf7\u5728\u8bbe\u7f6e\u4e2d\u6388\u4e88\u9ea6\u514b\u98ce\u6743\u9650';
  static const _zhStartRecordingFailed =
      '\u5f00\u59cb\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u9ea6\u514b\u98ce\u6743\u9650';
  static const _zhStartRecordingFailedShort = '\u5f00\u59cb\u5f55\u97f3\u5931\u8d25';
  static const _zhPauseRecordingFailed = '\u6682\u505c\u5f55\u97f3\u5931\u8d25';
  static const _zhResumeRecordingFailed = '\u7ee7\u7eed\u5f55\u97f3\u5931\u8d25';
  static const _zhMinFiveSeconds =
      '\u5f55\u5236\u65f6\u957f\u4e0d\u80fd\u5c11\u4e8e 5 \u79d2';
  static const _zhRecordSomethingFirst =
      '\u8bf7\u5148\u5f55\u5236\u4e00\u6bb5\u97f3\u9891';
  static const _zhNoValidRecording =
      '\u672a\u751f\u6210\u6709\u6548\u7684\u5f55\u97f3\u6587\u4ef6\uff0c\u8bf7\u91cd\u8bd5';
  static const _zhFinishRecordingFailed =
      '\u7ed3\u675f\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
  static const _zhReadRecordingFailed = '\u8bfb\u53d6\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  static const _zhRecordingEmpty =
      '\u5f55\u97f3\u6587\u4ef6\u4e3a\u7a7a\uff0c\u8bf7\u91cd\u65b0\u5f55\u5236';
  static const _zhDefaultRecordingName = '\u672a\u547d\u540d\u5f55\u97f3';
  static const _zhRecordingPrefix = '\u5f55\u97f3';
  static const _zhNoSourceToPlay =
      '\u6ca1\u6709\u53ef\u64ad\u653e\u7684\u5f55\u97f3\u6587\u4ef6';
  static const _zhLoadAudioFailed = '\u52a0\u8f7d\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  static const _zhPlayFailed = '\u64ad\u653e\u5931\u8d25';
  static const _zhSeekFailed = '\u8df3\u8f6c\u5931\u8d25';
  static const _zhNoRecordingToSave =
      '\u6ca1\u6709\u53ef\u4fdd\u5b58\u7684\u5f55\u97f3\u6587\u4ef6';
  static const _zhPickCategory = '\u8bf7\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b';
  static const _zhEnterTitle = '\u8bf7\u8f93\u5165\u4f5c\u54c1\u540d\u79f0';
  static const _zhUploadFailed = '\u4e0a\u4f20\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  static const _zhUploadNoPath =
      '\u4e0a\u4f20\u6210\u529f\u4f46\u672a\u8fd4\u56de\u6587\u4ef6\u8def\u5f84';
  static const _zhSaveRecordingFailed = '\u4fdd\u5b58\u5f55\u97f3\u5931\u8d25';
  static const _zhDeleteRecordingFailed = '\u5220\u9664\u5f55\u97f3\u5931\u8d25';
  static const _zhInvalidRecording = '\u65e0\u6548\u7684\u5f55\u97f3\u4f5c\u54c1';
  static const _zhRecordingPathMissing = '\u5f55\u97f3\u6587\u4ef6\u8def\u5f84\u7f3a\u5931';
  static const _zhRenameFailed = '\u91cd\u547d\u540d\u5931\u8d25';
  static const _zhSaveBeforeShare = '\u8bf7\u5148\u4fdd\u5b58\u5f55\u97f3\u518d\u5206\u4eab';
  static const _zhLoadClassesFailed = '\u52a0\u8f7d\u73ed\u7ea7\u5217\u8868\u5931\u8d25';
  static const _zhPickAtLeastOneClass =
      '\u8bf7\u9009\u62e9\u81f3\u5c11\u4e00\u4e2a\u73ed\u7ea7';
  static const _zhShareFailed = '\u5206\u4eab\u5931\u8d25';

  // ?????????????????????????????????????????????????????????????????????
  // List / folder / category catalog (unchanged from the previous
  // implementation ? this is purely metadata fetching, no audio engine).
  // ?????????????????????????????????????????????????????????????????????

  Future<void> refresh() async {
    try {
      _preparedPlayerSource = null;
      state = state.copyWith(loading: true, clearError: true);
      final categoryResponse = await _repository.getCategories();
      final categories = _parseCategories(categoryResponse.data);
      final selectedCategoryId = _resolveSelectedCategory(
        categories,
        state.selectedCategoryId,
      );
      final folderResponse = selectedCategoryId > 0
          ? await _repository.getFolderList(categoryId: selectedCategoryId)
          : null;
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        folders: folderResponse == null
            ? const <RecordingFolderItem>[]
            : _parseFolders(folderResponse.data, selectedCategoryId),
        items: const <RecordingEntry>[],
        currentFolderId: 0,
        currentFolderName: '',
        listView: RecordingListView.folders,
        viewMode: RecordingViewMode.list,
        recordingPhase: RecordingPhase.idle,
        elapsedMs: 0,
        liveWaveform: const <double>[],
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        previewPlaying: false,
        previewPositionMs: 0,
        previewDurationMs: 0,
        previewPlaybackRate: 1,
        selectedSaveCategoryId: selectedCategoryId,
        pendingTitle: '',
        errorMessage: folderResponse == null || folderResponse.isSuccess
            ? null
            : _fallbackMessage(folderResponse.msg, _zhLoadFoldersFailed),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loading: false, errorMessage: _zhLoadListFailed);
    }
  }

  Future<void> selectCategory(int id) async {
    if (id == state.selectedCategoryId) return;
    try {
      _preparedPlayerSource = null;
      state = state.copyWith(
        selectedCategoryId: id,
        loading: true,
        clearError: true,
        searchQuery: '',
        listView: RecordingListView.folders,
        currentFolderId: 0,
        currentFolderName: '',
        items: const <RecordingEntry>[],
      );
      final response = await _repository.getFolderList(categoryId: id);
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        folders: _parseFolders(response.data, id),
        viewMode: RecordingViewMode.list,
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, _zhLoadFoldersFailed),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: _zhSwitchCategoryFailed,
      );
    }
  }

  Future<void> openFolder(RecordingFolderItem folder) async {
    if (folder.id <= 0) return;
    try {
      _preparedPlayerSource = null;
      state = state.copyWith(
        loading: true,
        clearError: true,
        searchQuery: '',
        currentFolderId: folder.id,
        currentFolderName: folder.name,
        listView: RecordingListView.files,
      );
      final response = await _repository.getRecordings(
        folder.categoryId,
        folderId: folder.id,
      );
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        items: _parseRecordings(response.data, folder.categoryId),
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, _zhLoadRecordingsFailed),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: _zhLoadRecordingsFailed,
      );
    }
  }

  Future<void> backToFolderOverview() async {
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) {
      state = state.copyWith(
        listView: RecordingListView.folders,
        currentFolderId: 0,
        currentFolderName: '',
        items: const <RecordingEntry>[],
        searchQuery: '',
      );
      return;
    }
    try {
      _preparedPlayerSource = null;
      state = state.copyWith(
        loading: true,
        clearError: true,
        searchQuery: '',
        listView: RecordingListView.folders,
        currentFolderId: 0,
        currentFolderName: '',
        items: const <RecordingEntry>[],
      );
      final response = await _repository.getFolderList(categoryId: categoryId);
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        folders: _parseFolders(response.data, categoryId),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, _zhLoadFoldersFailed),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: _zhBackToFoldersFailed,
      );
    }
  }

  Future<void> _reloadFolders(int categoryId) async {
    if (categoryId <= 0) return;
    final response = await _repository.getFolderList(categoryId: categoryId);
    if (!mounted) return;
    state = state.copyWith(
      folders: response.isSuccess
          ? _parseFolders(response.data, categoryId)
          : state.folders,
    );
  }

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _zhEnterCategoryName;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhCreateCategoryFailed);
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhDeleteCategoryFailed);
    }
    await refresh();
    return null;
  }

  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _zhEnterCategoryName;
    if (id <= 0) return _zhInvalidCategory;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.renameCategory(id, trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhRenameCategoryFailed);
    }
    await refresh();
    return null;
  }

  Future<String?> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _zhEnterFolderName;
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) return _zhPickCategoryFirst;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addFolder(
      categoryId: categoryId,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhCreateFolderFailed);
    }
    await _reloadFolders(categoryId);
    return null;
  }

  Future<String?> renameFolder(RecordingFolderItem folder, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _zhEnterFolderName;
    if (folder.id <= 0) return _zhInvalidFolder;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.renameFolder(
      categoryId: folder.categoryId,
      id: folder.id,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhRenameFolderFailed);
    }
    await _reloadFolders(folder.categoryId);
    return null;
  }

  Future<String?> deleteFolder(RecordingFolderItem folder) async {
    if (folder.id <= 0) return _zhInvalidFolder;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteFolder(folder.id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhDeleteFolderFailed);
    }
    await _reloadFolders(folder.categoryId);
    return null;
  }

  // ?????????????????????????????????????????????????????????????????????
  // View transitions
  // ?????????????????????????????????????????????????????????????????????

  /// Leave the recording / preview pages and reset to the list home.
  Future<void> enterListHome() async {
    await abandonActiveSession();
    if (!mounted) return;
    state = state.copyWith(
      viewMode: RecordingViewMode.list,
      recordingPhase: RecordingPhase.idle,
      elapsedMs: 0,
      liveWaveform: const <double>[],
      clearPreviewItem: true,
      clearPreviewSource: true,
      clearRecordedBytes: true,
      showSaveDialog: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
      previewPlaying: false,
      previewPositionMs: 0,
      previewDurationMs: 0,
    );
  }

  /// Open the "record" stage with a fresh canvas.
  Future<void> openNewRecording() async {
    await _stopPreviewPlayback();
    await _stopRecorder(discard: true);
    _preparedPlayerSource = null;
    _resetWaveform();
    _resetTimers();
    state = state.copyWith(
      viewMode: RecordingViewMode.record,
      recordingPhase: RecordingPhase.idle,
      elapsedMs: 0,
      liveWaveform: const <double>[],
      previewPlaying: false,
      previewPlaybackRate: 1,
      previewPositionMs: 0,
      previewDurationMs: 0,
      clearPreviewItem: true,
      clearPreviewSource: true,
      clearRecordedBytes: true,
      showSaveDialog: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
      selectedSaveCategoryId: state.selectedCategoryId,
      pendingTitle: '',
      selectedEffectIndex: 0,
      previewCollected: false,
      clearError: true,
    );
  }

  Future<void> resetRecording() async {
    await _stopRecorder(discard: true);
    _resetWaveform();
    _resetTimers();
    _currentRecordingPath = null;
    state = state.copyWith(
      recordingPhase: RecordingPhase.idle,
      elapsedMs: 0,
      liveWaveform: const <double>[],
      clearPreviewItem: true,
      clearPreviewSource: true,
      clearRecordedBytes: true,
      previewPlaying: false,
      previewPositionMs: 0,
      previewDurationMs: 0,
      clearError: true,
    );
  }

  /// Snap the UI back to the list immediately; the engine cleanup happens
  /// in the background. We deliberately don't await ? iPad pause/cancel
  /// can take a beat and we don't want the back button feeling stuck.
  Future<void> backToList() async {
    if (mounted) {
      state = state.copyWith(
        viewMode: RecordingViewMode.list,
        recordingPhase: RecordingPhase.idle,
        elapsedMs: 0,
        liveWaveform: const <double>[],
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        previewPlaying: false,
        previewPositionMs: 0,
        previewDurationMs: 0,
      );
    }
    unawaited(abandonActiveSession());
  }

  /// Tear down all native engine state: stop the recorder, stop the
  /// player, drop the prepared source. Called on page dispose / app
  /// background. Doesn't dispose the AudioRecorder/AudioPlayer instances
  /// themselves ? we keep them around for the next session to skip the
  /// platform-channel cold start.
  Future<void> abandonActiveSession() async {
    await _stopRecorder(discard: true);
    _resetWaveform();
    _resetTimers();
    _currentRecordingPath = null;

    final player = _player;
    if (player != null) {
      await _safeAsync(player.pause);
      await _safeAsync(() => player.seek(Duration.zero));
    }
    _preparedPlayerSource = null;
    if (mounted && state.previewPlaying) {
      state = state.copyWith(previewPlaying: false);
    }
    previewPositionMs.value = 0;
  }

  // ?????????????????????????????????????????????????????????????????????
  // Recording engine
  // ?????????????????????????????????????????????????????????????????????

  AudioRecorder _ensureRecorder() {
    final existing = _recorder;
    if (existing != null) return existing;
    final created = AudioRecorder();
    _recorder = created;
    _recordStateSub?.cancel();
    // We attach an onStateChanged subscription mainly to keep the platform
    // channel hot (some platforms don't deliver amplitude events until
    // somebody is listening) and to swallow late events without crashing.
    // We DO NOT mirror RecordState into the Riverpod phase: our phase is
    // driven by explicit user intent (start/pause/resume tapped), and a
    // stale platform notification during a stop->start race could
    // otherwise flip the UI back into "recording" right after a stop.
    _recordStateSub = created.onStateChanged().listen(
      (_) {},
      onError: (_) {},
    );
    return created;
  }

  Future<String?> startRecording() async {
    if (_audioFeatureBroken) return _zhUnsupported;
    try {
      final recorder = _ensureRecorder();

      // Defensive: if the previous session didn't close cleanly, force-
      // stop before requesting a new recording. record() will throw
      // PlatformException("already recording") otherwise.
      if (await recorder.isRecording() || await recorder.isPaused()) {
        await _safeAsync(recorder.stop);
      }
      _resetWaveform();
      _resetTimers();

      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) return _zhMicPermission;

      // Encoder: AAC-LC ? .m4a on every native platform we ship to. The
      // browser MediaRecorder will silently fall back to opus/webm on
      // platforms where AAC isn't available; the upload step below
      // resolves the actual extension from the path returned by stop().
      final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
      final path = _buildRecordingPath();
      _currentRecordingPath = path;
      await recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        // record's web shim ignores the path argument; native uses it.
        path: path,
      );

      // Wire up amplitude + stopwatch only AFTER start() resolves, so we
      // don't leak listeners on a recorder that never actually went hot.
      _amplitudeSub = recorder
          .onAmplitudeChanged(_kAmplitudePollInterval)
          .listen(_onAmplitude, onError: (_) {});
      _startStopwatch();

      state = state.copyWith(
        recordingPhase: RecordingPhase.recording,
        clearError: true,
        elapsedMs: 0,
        liveWaveform: const <double>[],
      );
      _preparedPlayerSource = null;
      return null;
    } on MissingPluginException {
      _audioFeatureBroken = true;
      if (mounted) state = state.copyWith(recordingPhase: RecordingPhase.idle);
      return _zhUnsupported;
    } on PlatformException catch (error) {
      if (mounted) state = state.copyWith(recordingPhase: RecordingPhase.idle);
      return _platformMessage(error, _zhStartRecordingFailed);
    } catch (error) {
      await _stopRecorder(discard: true);
      if (mounted) state = state.copyWith(recordingPhase: RecordingPhase.idle);
      return '$_zhStartRecordingFailedShort: $error';
    }
  }

  Future<String?> pauseRecording() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    try {
      await recorder.pause();
      _stopwatch?.stop();
      state = state.copyWith(recordingPhase: RecordingPhase.paused);
      return null;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhPauseRecordingFailed);
    } catch (error) {
      return '$_zhPauseRecordingFailed: $error';
    }
  }

  Future<String?> resumeRecording() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    try {
      await recorder.resume();
      _stopwatch?.start();
      state = state.copyWith(recordingPhase: RecordingPhase.recording);
      return null;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhResumeRecordingFailed);
    } catch (error) {
      return '$_zhResumeRecordingFailed: $error';
    }
  }

  Future<String?> finishRecording() {
    return _finalizeRecordingToPreview(minElapsedMs: 5000);
  }

  /// "Listen now" button: lower threshold (1s) so the user can hear what
  /// they just recorded before deciding to keep going or re-record.
  Future<String?> finalizeRecordingForListening() {
    return _finalizeRecordingToPreview(minElapsedMs: 1000);
  }

  /// Manually open the save dialog from the preview header.
  void requestSaveDialog() {
    state = state.copyWith(showSaveDialog: true);
  }

  Future<String?> _finalizeRecordingToPreview({
    required int minElapsedMs,
  }) async {
    final stopwatch = _stopwatch;
    final recorder = _recorder;
    final elapsedFromStopwatch = stopwatch?.elapsedMilliseconds ?? 0;
    final elapsedMillis = elapsedFromStopwatch > 0
        ? elapsedFromStopwatch
        : elapsedMs.value;

    if (elapsedMillis < minElapsedMs) {
      return minElapsedMs >= 5000 ? _zhMinFiveSeconds : _zhRecordSomethingFirst;
    }

    String? resolvedSource;
    try {
      final stopped = await recorder?.stop();
      resolvedSource = (stopped != null && stopped.isNotEmpty)
          ? stopped
          : _currentRecordingPath;
    } on PlatformException catch (error) {
      _resetTimers();
      return _platformMessage(error, _zhFinishRecordingFailed);
    } catch (error) {
      _resetTimers();
      return '$_zhFinishRecordingFailed: $error';
    }

    // Stop wallclock + amplitude listeners now that the engine is stopped.
    _resetTimers();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    if (resolvedSource == null || resolvedSource.isEmpty) {
      return _zhNoValidRecording;
    }

    Uint8List bytes;
    try {
      bytes = await loadRecordedBytes(resolvedSource);
    } on FileSystemException catch (error) {
      return '$_zhReadRecordingFailed: ${error.osError?.message ?? error.message}';
    } catch (error) {
      return '$_zhReadRecordingFailed: $error';
    }
    if (bytes.isEmpty) return _zhRecordingEmpty;

    final waveformSnapshot = _amplitudeHistory.isEmpty
        ? _fallbackWaveform(resolvedSource.hashCode)
        : List<double>.unmodifiable(_amplitudeHistory);

    final durationLabel = _formatDurationLabel(elapsedMillis);
    final defaultName = _zhDefaultRecordingName;
    final draft = RecordingEntry(
      id: -1,
      categoryId: state.selectedSaveCategoryId > 0
          ? state.selectedSaveCategoryId
          : state.selectedCategoryId,
      name: state.pendingTitle.isEmpty ? defaultName : state.pendingTitle,
      url: resolvedSource,
      durationLabel: durationLabel,
      waveform: waveformSnapshot,
      payload: <String, dynamic>{
        'name': state.pendingTitle.isEmpty ? defaultName : state.pendingTitle,
        'duration': durationLabel,
        'url': resolvedSource,
      },
      isLocalDraft: true,
    );

    // Prepare the player off the just-finalized source. We don't surface
    // errors here ? the user gets a clear toast on the explicit play tap.
    await _preparePreviewPlayer(resolvedSource);

    final now = DateTime.now();
    final autoTitle =
        '$_zhRecordingPrefix${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    previewDurationMs.value = elapsedMillis;
    previewPositionMs.value = 0;

    state = state.copyWith(
      viewMode: RecordingViewMode.preview,
      recordingPhase: RecordingPhase.idle,
      elapsedMs: elapsedMillis,
      liveWaveform: waveformSnapshot,
      previewItem: draft,
      previewSource: resolvedSource,
      previewDurationMs: elapsedMillis,
      previewPositionMs: 0,
      previewPlaying: false,
      previewPlaybackRate: 1,
      recordedBytes: bytes,
      showSaveDialog: false,
      selectedSaveCategoryId: draft.categoryId,
      pendingTitle: draft.name == defaultName ? autoTitle : draft.name,
    );
    return null;
  }

  void _onAmplitude(Amplitude amp) {
    if (_disposed) return;
    final normalized = _normalizeAmplitudeDb(amp.current);
    _amplitudeHistory.add(normalized);

    // Update the live notifier with the most recent N samples. We allocate
    // a fresh List so equality comparison fires the listener.
    final history = _amplitudeHistory;
    final start = history.length > _kLiveWaveSampleCap
        ? history.length - _kLiveWaveSampleCap
        : 0;
    liveAmplitudes.value = List<double>.unmodifiable(history.sublist(start));
  }

  void _startStopwatch() {
    _stopwatchTicker?.cancel();
    final sw = _stopwatch ?? Stopwatch();
    sw
      ..reset()
      ..start();
    _stopwatch = sw;
    elapsedMs.value = 0;
    _stopwatchTicker = Timer.periodic(_kStopwatchTickInterval, (_) {
      if (_disposed) return;
      final ms = sw.elapsedMilliseconds;
      if (ms != elapsedMs.value) {
        elapsedMs.value = ms;
      }
    });
  }

  void _resetTimers() {
    _stopwatchTicker?.cancel();
    _stopwatchTicker = null;
    _stopwatch?.stop();
    _stopwatch?.reset();
    elapsedMs.value = 0;
  }

  void _resetWaveform() {
    _amplitudeHistory.clear();
    if (liveAmplitudes.value.isNotEmpty) {
      liveAmplitudes.value = const <double>[];
    }
  }

  Future<void> _stopRecorder({bool discard = false}) async {
    final recorder = _recorder;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (recorder == null) return;
    try {
      final isActive = await recorder.isRecording() || await recorder.isPaused();
      if (!isActive) return;
      if (discard) {
        await recorder.cancel();
      } else {
        await recorder.stop();
      }
    } catch (_) {}
  }

  // ?????????????????????????????????????????????????????????????????????
  // Preview / playback (just_audio)
  // ?????????????????????????????????????????????????????????????????????

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;

    _positionSub = player.positionStream.listen((duration) {
      if (_disposed || !mounted) return;
      final ms = duration.inMilliseconds;
      if (previewPositionMs.value != ms) previewPositionMs.value = ms;
    }, onError: (_) {});

    _durationSub = player.durationStream.listen((duration) {
      if (_disposed || !mounted) return;
      if (duration == null) return;
      final ms = duration.inMilliseconds;
      if (ms <= 0) return;
      if (previewDurationMs.value != ms) previewDurationMs.value = ms;
      if (state.previewDurationMs != ms) {
        state = state.copyWith(previewDurationMs: ms);
      }
    }, onError: (_) {});

    _playerStateSub = player.playerStateStream.listen((playerState) async {
      if (_disposed || !mounted) return;
      final playing = playerState.playing &&
          playerState.processingState != ProcessingState.completed;
      if (state.previewPlaying != playing) {
        state = state.copyWith(previewPlaying: playing);
      }
      if (playerState.processingState == ProcessingState.completed) {
        // Snap back to the start, leave paused. Match the iOS feel users
        // expect from a one-shot voice memo player.
        await _safeAsync(() => player.pause());
        await _safeAsync(() => player.seek(Duration.zero));
        if (mounted && state.previewPlaying) {
          state = state.copyWith(previewPlaying: false);
        }
        previewPositionMs.value = 0;
      }
    }, onError: (_) {});

    return player;
  }

  Future<void> openPreview(RecordingEntry item) async {
    await _stopPreviewPlayback();
    final resolved = _resolveMediaUrl(item.url);
    final initialDuration = _parseDuration(item.durationLabel);
    previewPositionMs.value = 0;
    previewDurationMs.value = initialDuration;
    state = state.copyWith(
      viewMode: RecordingViewMode.preview,
      previewItem: item,
      previewSource: resolved,
      previewDurationMs: initialDuration,
      previewPositionMs: 0,
      previewPlaying: false,
      previewPlaybackRate: 1,
      previewCollected: false,
      clearRecordedBytes: true,
      showSaveDialog: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
    // Pre-buffer so the user gets near-instant playback on tap. Fire and
    // forget; errors surface on the actual play tap.
    unawaited(_preparePreviewPlayer(resolved));
  }

  /// Toggle preview play/pause. Same code path on every platform now.
  Future<void> togglePreviewPlayback() async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) return;
    final prepareError = await _preparePreviewPlayerForUI(source);
    if (prepareError != null) {
      if (mounted) state = state.copyWith(errorMessage: prepareError);
      return;
    }
    final player = _ensurePlayer();
    try {
      if (player.playing) {
        await player.pause();
      } else {
        // If we already played to the end, seek to 0 first so the user
        // tapping play after completion actually replays.
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: _platformMessage(error, _zhPlayFailed),
        );
      }
    } catch (error) {
      if (mounted) state = state.copyWith(errorMessage: '$_zhPlayFailed: $error');
    }
  }

  /// Seek by [deltaMs] from current position.
  Future<void> seekPreviewBy(int deltaMs) async {
    final base = previewPositionMs.value;
    return seekPreviewTo(base + deltaMs);
  }

  /// Seek to absolute [targetMs] (clamped to [0, maxDuration]).
  Future<void> seekPreviewTo(int targetMs) async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) return;
    final prepareError = await _preparePreviewPlayerForUI(source);
    if (prepareError != null) {
      if (mounted) state = state.copyWith(errorMessage: prepareError);
      return;
    }
    final player = _ensurePlayer();
    final maxMs = previewDurationMs.value > 0
        ? previewDurationMs.value
        : (player.duration?.inMilliseconds ?? state.previewDurationMs);
    final clamped = targetMs.clamp(0, math.max(maxMs, 0)).toInt();
    try {
      await player.seek(Duration(milliseconds: clamped));
      if (previewPositionMs.value != clamped) {
        previewPositionMs.value = clamped;
      }
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: _platformMessage(error, _zhSeekFailed),
        );
      }
    } catch (error) {
      if (mounted) state = state.copyWith(errorMessage: '$_zhSeekFailed: $error');
    }
  }

  Future<void> _stopPreviewPlayback() async {
    final player = _player;
    if (player == null) return;
    await _safeAsync(player.pause);
    await _safeAsync(() => player.seek(Duration.zero));
    if (mounted && state.previewPlaying) {
      state = state.copyWith(previewPlaying: false);
    }
    if (previewPositionMs.value != 0) previewPositionMs.value = 0;
  }

  /// UI-facing prepare. Returns null on success, or a localized error.
  Future<String?> _preparePreviewPlayerForUI(String source) async {
    if (source.isEmpty) return _zhNoSourceToPlay;
    if (_audioFeatureBroken) return _zhUnsupported;
    if (_preparedPlayerSource == source) return null;
    final player = _ensurePlayer();
    try {
      await player.stop();
      // setUrl resolves the duration and surfaces it via durationStream.
      // It accepts http(s), file://, blob: ? everything we ever put in
      // `previewSource`.
      final dur = await player.setUrl(source);
      _preparedPlayerSource = source;
      if (dur != null) {
        final ms = dur.inMilliseconds;
        if (ms > 0) {
          previewDurationMs.value = ms;
          if (mounted && state.previewDurationMs != ms) {
            state = state.copyWith(previewDurationMs: ms);
          }
        }
      }
      return null;
    } on MissingPluginException {
      _audioFeatureBroken = true;
      return _zhUnsupported;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhLoadAudioFailed);
    } on PlayerException catch (error) {
      return '$_zhLoadAudioFailed: ${error.message ?? error.code}';
    } catch (error) {
      return '$_zhLoadAudioFailed: $error';
    }
  }

  Future<bool> _preparePreviewPlayer(String source) async {
    final error = await _preparePreviewPlayerForUI(source);
    return error == null;
  }

  // ?????????????????????????????????????????????????????????????????????
  // Save / delete / rename / share (unchanged business logic)
  // ?????????????????????????????????????????????????????????????????????

  void closeSaveDialog() {
    state = state.copyWith(showSaveDialog: false);
  }

  void openSaveDialog() {
    state = state.copyWith(showSaveDialog: true);
  }

  void updatePendingTitle(String value) {
    state = state.copyWith(pendingTitle: value);
  }

  void selectEffect(int index) {
    state = state.copyWith(selectedEffectIndex: index);
  }

  void togglePreviewCollected() {
    state = state.copyWith(previewCollected: !state.previewCollected);
  }

  /// Upload + persist the active draft. On success returns null; on any
  /// failure returns a localized error string.
  ///
  /// IMPORTANT ? this method intentionally does NOT close the save dialog
  /// or flip viewMode back to list. Doing both inside one call has been
  /// the source of the historical iPad save crash ("This exception was
  /// thrown because the deactivated widget's ancestor was looked up...").
  /// Cleanup is the UI's responsibility (see `_DialogActionButton`):
  ///   1. await saveCurrentRecording() ? message
  ///   2. if message == null: closeSaveDialog()
  ///   3. addPostFrameCallback(() => finishSaveAndReturnToList())
  Future<String?> saveCurrentRecording() async {
    if (state.busy) return null; // re-entrancy guard for double-tap
    final bytes = state.recordedBytes;
    final categoryId = state.selectedSaveCategoryId;
    if (bytes == null || bytes.isEmpty) return _zhNoRecordingToSave;
    if (categoryId <= 0) return _zhPickCategory;

    final title = state.pendingTitle.trim();
    if (title.isEmpty) return _zhEnterTitle;

    state = state.copyWith(busy: true, clearError: true);
    try {
      // Pick a server-friendly filename. Native records as .m4a (AAC-LC),
      // Web's MediaRecorder produces opus inside webm ? use .webm there
      // so playback later picks the right MIME type / codec.
      final ext = kIsWeb ? 'webm' : 'm4a';
      final filename =
          'recording_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final uploadResponse = await _repository.uploadRecording(
        bytes: bytes,
        filename: filename,
      );
      if (!uploadResponse.isSuccess) {
        if (mounted) state = state.copyWith(busy: false);
        return _fallbackMessage(uploadResponse.msg, _zhUploadFailed);
      }
      final filePath = parseUploadResult(uploadResponse.data).savable;
      if (filePath.isEmpty) {
        if (mounted) state = state.copyWith(busy: false);
        return _zhUploadNoPath;
      }

      final saveResponse = await _repository.saveRecording(
        categoryId: categoryId,
        name: title,
        duration: _formatDurationLabel(state.previewDurationMs),
        filePath: filePath,
        folderId: state.currentFolderId,
      );
      if (!saveResponse.isSuccess) {
        if (mounted) state = state.copyWith(busy: false);
        return _fallbackMessage(saveResponse.msg, _zhSaveRecordingFailed);
      }

      if (mounted) state = state.copyWith(busy: false);
      return null;
    } on PlatformException catch (error) {
      if (mounted) state = state.copyWith(busy: false);
      return _platformMessage(error, _zhSaveRecordingFailed);
    } catch (error) {
      if (mounted) state = state.copyWith(busy: false);
      return '$_zhSaveRecordingFailed: $error';
    }
  }

  /// Called by the UI ONE FRAME AFTER a successful save. Switches back to
  /// the list view and reloads the folder/category contents so the new
  /// recording shows up. Deferring via `addPostFrameCallback` matters:
  /// the dialog dismissal animation needs at least one frame to start
  /// before we tear down the parent _RecordingStage by flipping viewMode.
  Future<void> finishSaveAndReturnToList() async {
    final folderId = state.currentFolderId;
    final categoryId = state.selectedSaveCategoryId > 0
        ? state.selectedSaveCategoryId
        : state.selectedCategoryId;
    if (mounted) {
      state = state.copyWith(
        viewMode: RecordingViewMode.list,
        recordingPhase: RecordingPhase.idle,
        elapsedMs: 0,
        liveWaveform: const <double>[],
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        previewPlaying: false,
        previewPositionMs: 0,
        previewDurationMs: 0,
      );
    }
    if (folderId > 0) {
      await openFolder(
        RecordingFolderItem(
          id: folderId,
          categoryId: categoryId > 0 ? categoryId : state.selectedCategoryId,
          name: state.currentFolderName,
        ),
      );
    } else if (categoryId > 0 && categoryId != state.selectedCategoryId) {
      await selectCategory(categoryId);
    } else if (categoryId > 0) {
      await _reloadFolders(categoryId);
    }
  }

  Future<String?> deleteRecording(RecordingEntry item) async {
    if (item.id <= 0 || item.isLocalDraft) {
      await _stopPreviewPlayback();
      _preparedPlayerSource = null;
      await openNewRecording();
      return null;
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteRecording(item.id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhDeleteRecordingFailed);
    }
    final remaining = state.items
        .where((entry) => entry.id != item.id)
        .toList();
    state = state.copyWith(
      items: remaining,
      viewMode: RecordingViewMode.list,
      clearPreviewItem: true,
      clearPreviewSource: true,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
    return null;
  }

  Future<String?> renameRecording(RecordingEntry item, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _zhEnterTitle;
    if (trimmed == item.name) return null;
    if (item.id <= 0) return _zhInvalidRecording;
    final payload = item.payload;
    final filePath = (payload['filePath'] ?? payload['url'] ?? '').toString();
    if (filePath.isEmpty) return _zhRecordingPathMissing;
    final duration = (payload['duration'] ?? item.durationLabel).toString();
    final folderId = _toInt(payload['folderId']);
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.saveRecording(
      id: item.id,
      categoryId: item.categoryId,
      name: trimmed,
      duration: duration,
      filePath: filePath,
      folderId: folderId,
      param1: (payload['param1'] ?? '').toString(),
      param2: (payload['param2'] ?? '').toString(),
      param3: (payload['param3'] ?? '').toString(),
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhRenameFailed);
    }
    final currentFolderId = state.currentFolderId;
    if (currentFolderId > 0) {
      await openFolder(
        RecordingFolderItem(
          id: currentFolderId,
          categoryId: state.selectedCategoryId,
          name: state.currentFolderName,
        ),
      );
    } else if (state.selectedCategoryId > 0) {
      await selectCategory(state.selectedCategoryId);
    }
    return null;
  }

  Future<String?> openShare() async {
    final target = state.previewItem;
    if (target == null || target.isLocalDraft) return _zhSaveBeforeShare;
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, _zhLoadClassesFailed);
    }
    final classes = <RecordingShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) continue;
      final id = _toIdString(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      classes.add(RecordingShareClass(id: id, name: name));
    }
    state = state.copyWith(showShareDialog: true, shareClasses: classes);
    return null;
  }

  void closeShareDialog() {
    state = state.copyWith(
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
  }

  void toggleShareClass(String id) {
    state = state.copyWith(
      shareClasses: state.shareClasses.map((item) {
        if (item.id != id) return item;
        return item.copyWith(selected: !item.selected);
      }).toList(),
    );
  }

  Future<String?> sendShare() async {
    final target = state.previewItem;
    if (target == null || target.isLocalDraft) return _zhSaveBeforeShare;
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) return _zhPickAtLeastOneClass;
    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareRecording(
        classId: item.id,
        payload: target.payload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(response.msg, _zhShareFailed);
      }
    }
    state = state.copyWith(
      busy: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
    return null;
  }

  // ?????????????????????????????????????????????????????????????????????
  // Helpers
  // ?????????????????????????????????????????????????????????????????????

  Future<void> _safeAsync(Future<dynamic> Function() op) async {
    try {
      await op();
    } catch (_) {}
  }

  String _buildRecordingPath() {
    if (kIsWeb) return ''; // record's web shim ignores path
    final base = buildTemporaryRecordingPath();
    if (base.isEmpty) return base;
    final dot = base.lastIndexOf('.');
    if (dot < 0) return '$base.m4a';
    return '${base.substring(0, dot)}.m4a';
  }

  List<RecordingCategoryItem> _parseCategories(dynamic data) {
    if (data is! List) return const <RecordingCategoryItem>[];
    final result = <RecordingCategoryItem>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) continue;
      final count = _toInt(
        raw['count'] ??
            raw['recordingCount'] ??
            raw['fileCount'] ??
            raw['total'] ??
            raw['num'],
      );
      result.add(RecordingCategoryItem(id: id, name: name, count: count));
    }
    return result;
  }

  List<RecordingFolderItem> _parseFolders(dynamic data, int categoryId) {
    final sourceList = switch (data) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['records'] is List<dynamic> =>
        map['records'] as List<dynamic>,
      _ => const <dynamic>[],
    };
    final result = <RecordingFolderItem>[];
    for (final raw in sourceList) {
      if (raw is! Map<String, dynamic>) continue;
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) continue;
      final count = _toInt(
        raw['count'] ??
            raw['recordingCount'] ??
            raw['fileCount'] ??
            raw['total'] ??
            raw['num'],
      );
      final size = raw['sizeLabel']?.toString() ?? raw['size']?.toString() ?? '';
      final date =
          raw['updateTime']?.toString() ??
          raw['createTime']?.toString() ??
          raw['date']?.toString() ??
          '';
      result.add(
        RecordingFolderItem(
          id: id,
          categoryId: categoryId,
          name: name,
          count: count,
          sizeLabel: size,
          dateLabel: _formatFolderDate(date),
        ),
      );
    }
    return result;
  }

  String _formatFolderDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})')
        .firstMatch(trimmed);
    if (match == null) return trimmed;
    final y = match.group(1)!;
    final m = match.group(2)!.padLeft(2, '0');
    final d = match.group(3)!.padLeft(2, '0');
    return '$y.$m.$d';
  }

  List<RecordingEntry> _parseRecordings(dynamic data, int categoryId) {
    final sourceList = switch (data) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['records'] is List<dynamic> =>
        map['records'] as List<dynamic>,
      _ => const <dynamic>[],
    };
    final result = <RecordingEntry>[];
    for (final raw in sourceList) {
      if (raw is! Map<String, dynamic>) continue;
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      final rawPath = (raw['filePath'] ?? raw['url'] ?? '').toString();
      final url = _resolveMediaUrl(rawPath);
      if (id <= 0 || name.isEmpty || url.isEmpty) continue;
      final ownerCategoryId = _toInt(raw['categoryId']);
      result.add(
        RecordingEntry(
          id: id,
          categoryId: ownerCategoryId > 0 ? ownerCategoryId : categoryId,
          name: name,
          url: url,
          durationLabel: (raw['duration'] ?? '00:00.00').toString(),
          waveform: _fallbackWaveform(id),
          payload: Map<String, dynamic>.from(raw),
          sizeLabel: _resolveSizeLabel(raw),
          dateLabel: _resolveDateLabel(raw),
        ),
      );
    }
    return result;
  }

  String _resolveSizeLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['sizeLabel'],
      item['size'],
      item['fileSize'],
      item['totalFileSize'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isEmpty || value == 'null') continue;
      final asNumber = double.tryParse(value);
      if (asNumber != null && !value.contains(RegExp(r'[a-zA-Z]'))) {
        return _formatBytesLabel(asNumber);
      }
      return value;
    }
    return '';
  }

  String _resolveDateLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['createTime'],
      item['createDate'],
      item['updateTime'],
    ];
    for (final candidate in candidates) {
      final raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') continue;
      final normalized = raw.contains(' ') && !raw.contains('T')
          ? raw.replaceFirst(' ', 'T')
          : raw;
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        final month = parsed.month.toString().padLeft(2, '0');
        final day = parsed.day.toString().padLeft(2, '0');
        return '$month.$day.${parsed.year}';
      }
      return raw;
    }
    return '';
  }

  String _formatBytesLabel(double bytes) {
    if (bytes <= 0) return '0KB';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (bytes >= gb) {
      final value = bytes / gb;
      return '${value.toStringAsFixed(value < 10 ? 1 : 0)}GB';
    }
    if (bytes >= mb) {
      final value = bytes / mb;
      return '${value.toStringAsFixed(value < 10 ? 1 : 0)}MB';
    }
    final value = bytes / kb;
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)}KB';
  }

  int _resolveSelectedCategory(
    List<RecordingCategoryItem> categories,
    int currentId,
  ) {
    if (categories.any((item) => item.id == currentId)) return currentId;
    return categories.firstOrNull?.id ?? 0;
  }

  int _parseDuration(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return 0;
    final dotMatch = RegExp(r'^(\d+):(\d+)\.(\d+)$').firstMatch(cleaned);
    if (dotMatch != null) {
      final minutes = int.tryParse(dotMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(dotMatch.group(2)!) ?? 0;
      final centiseconds = int.tryParse(dotMatch.group(3)!) ?? 0;
      return minutes * 60000 + seconds * 1000 + centiseconds * 10;
    }
    final parts = cleaned.split(':');
    if (parts.length == 3) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      final centiseconds = int.tryParse(parts[2]) ?? 0;
      return minutes * 60000 + seconds * 1000 + centiseconds * 10;
    }
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return minutes * 60000 + seconds * 1000;
    }
    return 0;
  }

  String _formatDurationLabel(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final centiseconds =
        ((milliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$centiseconds';
  }

  List<double> _fallbackWaveform(int seed) {
    final random = math.Random(seed);
    return List<double>.generate(
      72,
      (index) => 0.12 + random.nextDouble() * (index % 9 == 0 ? 0.78 : 0.48),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _toIdString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == '0' || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  String _fallbackMessage(String raw, String fallback) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _platformMessage(PlatformException error, String fallback) {
    final candidates = <String?>[
      error.message,
      error.details?.toString(),
      error.code.isNotEmpty ? error.code : null,
    ];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
        return '$fallback: $trimmed';
      }
    }
    return fallback;
  }

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  @override
  void dispose() {
    _disposed = true;
    try {
      _stopwatchTicker?.cancel();
    } catch (_) {}
    try {
      _stopwatch?.stop();
    } catch (_) {}
    try {
      _amplitudeSub?.cancel();
    } catch (_) {}
    try {
      _recordStateSub?.cancel();
    } catch (_) {}
    try {
      _positionSub?.cancel();
    } catch (_) {}
    try {
      _durationSub?.cancel();
    } catch (_) {}
    try {
      _playerStateSub?.cancel();
    } catch (_) {}
    try {
      _recorder?.dispose();
    } catch (_) {}
    try {
      _player?.dispose();
    } catch (_) {}
    try {
      elapsedMs.dispose();
    } catch (_) {}
    try {
      liveAmplitudes.dispose();
    } catch (_) {}
    try {
      previewPositionMs.dispose();
    } catch (_) {}
    try {
      previewDurationMs.dispose();
    } catch (_) {}
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

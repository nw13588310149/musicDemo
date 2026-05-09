import 'dart:async';
import 'dart:math' as math;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../audio/recording_bytes_loader.dart';
import '../data/recording_system_repository.dart';
import 'recording_system_state.dart';

/// ???????????
///
/// ?? / ???????? Simform ? `audio_waveforms` ???
/// - [recorderController]??? + ???? + elapsedDuration ??????
///   `ChangeNotifier`?UI ? `AnimatedBuilder` ?????????????
///   ?????????????????????
/// - [playerController]????????? / ??????? `AudioFileWaveforms`
///   ???????????????????????? `_DarkWavePainter` +
///   ???? + ????????????????? + ??????????
///
/// ???????? android / ios ?????Windows / macOS ??????
/// ????? [MissingPluginException]????????????????
/// [_safeAsync] ?? try-catch????????????? / ??????
/// ?????????????????????????
final recordingSystemControllerProvider =
    StateNotifierProvider<RecordingSystemController, RecordingSystemState>((
      ref,
    ) {
      final repository = ref.watch(recordingSystemRepositoryProvider);
      return RecordingSystemController(repository: repository);
    });

class RecordingSystemController extends StateNotifier<RecordingSystemState> {
  RecordingSystemController({
    required RecordingSystemRepository repository,
    RecorderController? recorderController,
    PlayerController? playerController,
  }) : _repository = repository,
       recorderController = recorderController ?? RecorderController(),
       playerController = playerController ?? PlayerController(),
       super(const RecordingSystemState()) {
    // PlayerController ?? onCurrentDurationChanged ?????~5Hz????
    // high ?? 10Hz?? 60fps ??????????????????
    try {
      this.playerController.updateFrequency = UpdateFrequency.high;
    } catch (_) {}
    // FinishMode.pause???????? loop / stop?stop ??? resource?
    // ???????? prepare??setFinishMode ? async??????
    // MissingPluginException?
    unawaited(_safeAsync(() => this.playerController.setFinishMode()));
    _bindPlayerStreams();
    unawaited(refresh());
  }

  final RecordingSystemRepository _repository;

  /// ??????UI ??? `AudioWaveforms(recorderController: ...)` /
  /// `AnimatedBuilder(animation: recorderController, ...)` ???
  final RecorderController recorderController;

  /// ????????UI ??? `AudioFileWaveforms(playerController: ...)` /
  /// `AnimatedBuilder(animation: playerController, ...)` ???
  final PlayerController playerController;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _completionSub;

  /// ????????????stop ????????????
  String? _currentRecordingPath;

  /// ? prepareplayer ??????????? url??????? prepare?
  /// ?? / ?? preview ??????
  String? _preparedPlayerSource;

  bool _disposed = false;

  /// ??? / ???????? true?UI ???????????????
  bool _audioFeatureBroken = false;

  static const _unsupportedAudioMessage =
      'Recording is not supported on Web. Please use the iPad or mobile app.';

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
            : _fallbackMessage(folderResponse.msg, 'Failed to load folders'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: 'Failed to load recordings. Please try again.');
    }
  }

  Future<void> selectCategory(int id) async {
    if (id == state.selectedCategoryId) {
      return;
    }
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
      if (!mounted) {
        return;
      }
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
            : _fallbackMessage(response.msg, 'Failed to load folders'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: 'Failed to switch category.');
    }
  }

  /// ?????????????????????
  Future<void> openFolder(RecordingFolderItem folder) async {
    if (folder.id <= 0) {
      return;
    }
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
      if (!mounted) {
        return;
      }
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
            : _fallbackMessage(response.msg, 'Failed to load recordings'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: 'Failed to load recordings.');
    }
  }

  /// ?????????????????????
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
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        folders: _parseFolders(response.data, categoryId),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, 'Failed to load folders'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: 'Failed to return to folders.');
    }
  }

  /// ??????????????
  Future<void> _reloadFolders(int categoryId) async {
    if (categoryId <= 0) {
      return;
    }
    final response = await _repository.getFolderList(categoryId: categoryId);
    if (!mounted) {
      return;
    }
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
    if (trimmed.isEmpty) {
      return 'Please enter a category name';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to create category');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to delete category');
    }
    await refresh();
    return null;
  }

  /// ?????????? `recordingCategorySave` ??????? id +
  /// ??????? id ????????????????????????
  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a category name';
    }
    if (id <= 0) {
      return 'Invalid category';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.renameCategory(id, trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to rename category');
    }
    await refresh();
    return null;
  }

  // ?? Folder CRUD ????????????????????????????????????????????????????????????

  /// ????????????
  Future<String?> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a folder name';
    }
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) {
      return 'Please select a category first';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addFolder(
      categoryId: categoryId,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to create folder');
    }
    await _reloadFolders(categoryId);
    return null;
  }

  /// ????????? `recordingFolderSave` ??????? id + ????
  Future<String?> renameFolder(RecordingFolderItem folder, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a folder name';
    }
    if (folder.id <= 0) {
      return 'Invalid folder';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.renameFolder(
      categoryId: folder.categoryId,
      id: folder.id,
      name: trimmed,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to rename folder');
    }
    await _reloadFolders(folder.categoryId);
    return null;
  }

  /// ?????????????????????
  Future<String?> deleteFolder(RecordingFolderItem folder) async {
    if (folder.id <= 0) {
      return 'Invalid folder';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteFolder(folder.id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, 'Failed to delete folder');
    }
    await _reloadFolders(folder.categoryId);
    return null;
  }

  /// ?????????????????????? / ?? tab ???????
  /// ??????????????????????? list ???
  Future<void> enterListHome() async {
    await abandonActiveSession();
    if (!mounted) {
      return;
    }
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

  Future<void> openNewRecording() async {
    await _safeAsync(() async {
      if (playerController.playerState != PlayerState.stopped) {
        await playerController.stopPlayer();
      }
    });
    _preparedPlayerSource = null;
    _resetRecorderWaveform();
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
    if (recorderController.recorderState != RecorderState.stopped) {
      await _safeAsync(() => recorderController.stop());
    }
    _resetRecorderWaveform();
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

  /// ??????????? UI ???????????????????
  /// ?? / ????????????????????????????
  /// ????iPad ? cancel/pause ??????????????????
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

  /// ??????????? / ????????????????????
  /// ??????????????????
  ///   - ??? widget dispose????? /recording??
  ///   - App ???? / ???????????
  Future<void> abandonActiveSession() async {
    if (recorderController.recorderState != RecorderState.stopped) {
      await _safeAsync(() => recorderController.stop());
    }
    _resetRecorderWaveform();
    _currentRecordingPath = null;

    if (playerController.playerState != PlayerState.stopped) {
      await _safeAsync(() => playerController.stopPlayer());
    }
    _preparedPlayerSource = null;
  }

  Future<String?> startRecording() async {
    if (kIsWeb || _audioFeatureBroken) {
      return _unsupportedAudioMessage;
    }
    try {
      // ?????????????? / ???????? stop???????
      // ?? recording / paused?? record() ????? stop ????? stopped?
      if (recorderController.recorderState != RecorderState.stopped) {
        await _safeAsync(() => recorderController.stop());
      }
      _resetRecorderWaveform();

      final hasPermission = await recorderController.checkPermission();
      if (!hasPermission) {
        return 'Microphone permission is required.';
      }
      // audio_waveforms ??? Android / iOS ?? mpeg4 ?? + AAC ???
      // ??? record ?? wav ????? upload ????????????
      // ??????????? m4a ????? / ?????
      final tmpPath = _buildRecordingPath();
      _currentRecordingPath = tmpPath;
      await recorderController.record(
        path: tmpPath,
        recorderSettings: const RecorderSettings(
          sampleRate: 44100,
          bitRate: 128000,
        ),
      );
      // recordingPhase ?????????????????????????
      // ???? state ?????? / ??????? recorderController ??
      // ChangeNotifier ???UI ? AnimatedBuilder ???????? state?
      state = state.copyWith(
        recordingPhase: RecordingPhase.recording,
        clearError: true,
      );
      _preparedPlayerSource = null;
      return null;
    } on MissingPluginException {
      _audioFeatureBroken = true;
      if (mounted) {
        state = state.copyWith(recordingPhase: RecordingPhase.idle);
      }
      return _unsupportedAudioMessage;
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(recordingPhase: RecordingPhase.idle);
      }
      return error.message?.trim().isNotEmpty == true
          ? error.message
          : 'Failed to start recording. Please check microphone permission.';
    } catch (_) {
      // ?????????? idle??? UI ????????
      await _safeAsync(() => recorderController.stop());
      _resetRecorderWaveform();
      if (mounted) {
        state = state.copyWith(recordingPhase: RecordingPhase.idle);
      }
      return 'Failed to start recording. Please try again.';
    }
  }

  Future<String?> pauseRecording() async {
    try {
      await recorderController.pause();
      state = state.copyWith(recordingPhase: RecordingPhase.paused);
      return null;
    } catch (_) {
      return 'Failed to pause recording';
    }
  }

  Future<String?> resumeRecording() async {
    try {
      // RecorderController.record() ?? path ?????????
      await recorderController.record();
      state = state.copyWith(recordingPhase: RecordingPhase.recording);
      return null;
    } catch (_) {
      return 'Failed to resume recording';
    }
  }

  Future<String?> finishRecording() async {
    return _finalizeRecordingToPreview(minElapsedMs: 5000);
  }

  /// ??? 5 ?????????? ? 1 ??< 5 ???????????
  /// ????????????????????????????????
  Future<String?> finalizeRecordingForListening() async {
    return _finalizeRecordingToPreview(minElapsedMs: 1000);
  }

  /// ????????????????????????
  /// ???????????????????????????????
  void requestSaveDialog() {
    state = state.copyWith(showSaveDialog: true);
  }

  Future<String?> _finalizeRecordingToPreview({
    required int minElapsedMs,
  }) async {
    final elapsedMs = recorderController.elapsedDuration.inMilliseconds;
    if (elapsedMs < minElapsedMs) {
      return minElapsedMs >= 5000
          ? 'Recording must be at least 5 seconds'
          : 'Please record audio first';
    }
    try {
      // RecorderController.stop() ?? nullable ????iOS ?????? null
      // ????????????? _currentRecordingPath ???
      final source = await recorderController.stop();
      final resolvedSource = source ?? _currentRecordingPath;
      if (resolvedSource == null || resolvedSource.isEmpty) {
        return 'Failed to create recording file. Please record again.';
      }
      final bytes = await loadRecordedBytes(resolvedSource);
      final durationMs = elapsedMs;
      // ??? waveData?live ?????????????? [RecordingEntry]?
      // ??? fallback ????????? [AudioFileWaveforms] ????
      // ???????????????
      final waveformSnapshot = recorderController.waveData.isEmpty
          ? _fallbackWaveform(resolvedSource.hashCode)
          : List<double>.unmodifiable(recorderController.waveData);
      _resetRecorderWaveform();

      final durationLabel = _formatDurationLabel(durationMs);
      const defaultName = 'Untitled recording';
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
      // ???????? PlayerController ???????????????
      // ??? build ? AudioFileWaveforms ?????? maxDuration / waveform?
      // ????????
      await _preparePreviewPlayer(resolvedSource);
      state = state.copyWith(
        viewMode: RecordingViewMode.preview,
        recordingPhase: RecordingPhase.idle,
        elapsedMs: durationMs,
        liveWaveform: waveformSnapshot,
        previewItem: draft,
        previewSource: resolvedSource,
        previewDurationMs: durationMs,
        previewPositionMs: 0,
        previewPlaying: false,
        previewPlaybackRate: 1,
        recordedBytes: bytes,
        showSaveDialog: false,
        selectedSaveCategoryId: draft.categoryId,
        pendingTitle: draft.name == defaultName
            ? 'Recording${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}'
            : draft.name,
      );
      return null;
    } catch (_) {
      return 'Failed to finish recording. Please record again.';
    }
  }

  Future<void> openPreview(RecordingEntry item) async {
    await _stopPreviewPlayback();
    final resolved = _resolveMediaUrl(item.url);
    final initialDuration = _parseDuration(item.durationLabel);
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
    // ?? prepare????????AudioFileWaveforms ??????????
    // ????????prepare ???????? notify?UI ??????
    unawaited(_preparePreviewPlayer(resolved));
  }

  /// ???? / ?????? [PlayerController]?audio_waveforms ? native
  /// ?? AVPlayer / ExoPlayer?pause/play ???? mpv ?? click ???
  /// ??????????
  Future<void> togglePreviewPlayback() async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    if (kIsWeb) {
      if (mounted) {
        state = state.copyWith(errorMessage: _unsupportedAudioMessage);
      }
      return;
    }
    final ready = await _preparePreviewPlayer(source);
    if (!ready) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Failed to prepare audio.');
      }
      return;
    }
    try {
      if (playerController.playerState == PlayerState.playing) {
        await playerController.pausePlayer();
      } else {
        await playerController.startPlayer();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: error.message?.trim().isNotEmpty == true
              ? error.message
              : 'Playback failed.',
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Playback failed.');
      }
    }
  }

  /// ???????????? [deltaMs] ???
  Future<void> seekPreviewBy(int deltaMs) async {
    int base;
    try {
      base = await playerController.getDuration(DurationType.current);
    } catch (_) {
      base = 0;
    }
    if (base < 0) base = 0;
    return seekPreviewTo(base + deltaMs);
  }

  /// ?????????????????????????????
  Future<void> seekPreviewTo(int targetMs) async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    final ready = await _preparePreviewPlayer(source);
    if (!ready) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Failed to prepare audio.');
      }
      return;
    }
    final maxDur = playerController.maxDuration > 0
        ? playerController.maxDuration
        : state.previewDurationMs;
    final clamped = targetMs.clamp(0, math.max(maxDur, 0)).toInt();
    try {
      await playerController.seekTo(clamped);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(errorMessage: 'Failed to seek audio.');
      }
    }
  }

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

  Future<String?> saveCurrentRecording() async {
    final bytes = state.recordedBytes;
    final categoryId = state.selectedSaveCategoryId;
    if (bytes == null || bytes.isEmpty) {
      return 'No recording file to save';
    }
    if (categoryId <= 0) {
      return 'Please select a category';
    }

    final title = state.pendingTitle.trim();
    if (title.isEmpty) {
      return 'Please enter a title';
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final uploadResponse = await _repository.uploadRecording(
        bytes: bytes,
        filename: 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      if (!uploadResponse.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(uploadResponse.msg, 'Failed to upload recording');
      }
      // ?????????? path?? app/upload/.../xxx.m4a??????????
      // ?????????????????????? URL?
      final filePath = parseUploadResult(uploadResponse.data).savable;
      if (filePath.isEmpty) {
        state = state.copyWith(busy: false);
        return 'Upload succeeded but no file path was returned';
      }

      final folderId = state.currentFolderId;
      final saveResponse = await _repository.saveRecording(
        categoryId: categoryId,
        name: title,
        duration: _formatDurationLabel(state.previewDurationMs),
        filePath: filePath,
        folderId: folderId,
      );
      state = state.copyWith(busy: false);
      if (!saveResponse.isSuccess) {
        return _fallbackMessage(saveResponse.msg, 'Failed to save recording');
      }

      if (folderId > 0) {
        await openFolder(
          RecordingFolderItem(
            id: folderId,
            categoryId: categoryId,
            name: state.currentFolderName,
          ),
        );
      } else {
        await selectCategory(categoryId);
      }
      return null;
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
      return error.message?.trim().isNotEmpty == true
          ? error.message
          : 'Failed to save recording.';
    } catch (_) {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
      return 'Failed to save recording. Please check the network and try again.';
    }
  }

  Future<String?> deleteRecording(RecordingEntry item) async {
    // ????????????????????????????
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
      return _fallbackMessage(response.msg, 'Failed to delete recording');
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

  /// ?????????? `recordingSave` ???id > 0 ??????????
  /// ??? payload ?? filePath / duration / folderId / paramN ?????
  /// ??? name ???????????????????
  Future<String?> renameRecording(RecordingEntry item, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a title';
    }
    if (trimmed == item.name) {
      return null;
    }
    if (item.id <= 0) {
      return 'Invalid recording';
    }
    final payload = item.payload;
    final filePath = (payload['filePath'] ?? payload['url'] ?? '').toString();
    if (filePath.isEmpty) {
      return 'Missing recording file path';
    }
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
      return _fallbackMessage(response.msg, 'Rename failed');
    }
    // ????????????? / ????????????????
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
    if (target == null || target.isLocalDraft) {
      return 'Please save the recording before sharing';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, 'Failed to load class list');
    }
    final classes = <RecordingShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
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
        if (item.id != id) {
          return item;
        }
        return item.copyWith(selected: !item.selected);
      }).toList(),
    );
  }

  Future<String?> sendShare() async {
    final target = state.previewItem;
    if (target == null || target.isLocalDraft) {
      return 'Please save the recording before sharing';
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return 'Please select a class';
    }
    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareRecording(
        classId: item.id,
        payload: target.payload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(response.msg, 'Share failed');
      }
    }
    state = state.copyWith(
      busy: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
    return null;
  }

  /// ??????????????? audio_waveforms ??????
  /// ????? [MissingPluginException]????? / ???????
  /// PlatformException ???????????????????????
  Future<void> _safeAsync(Future<dynamic> Function() op) async {
    try {
      await op();
    } catch (_) {}
  }

  /// ?? RecorderController ??????? / ????????????
  /// ?? / ?????????????????
  void _resetRecorderWaveform() {
    try {
      recorderController.reset();
    } catch (_) {}
  }

  Future<void> _stopPreviewPlayback() async {
    if (playerController.playerState == PlayerState.stopped) {
      return;
    }
    await _safeAsync(() => playerController.pausePlayer());
    await _safeAsync(() => playerController.seekTo(0));
  }

  /// ?? [PlayerController] ????????????? url?????
  /// ???? true ??? prepare?????????????160 ???
  /// ?????????? [AudioFileWaveforms] ??????
  Future<bool> _preparePreviewPlayer(String source) async {
    if (kIsWeb || source.isEmpty) {
      return false;
    }
    if (_preparedPlayerSource == source &&
        playerController.playerState != PlayerState.stopped) {
      return true;
    }
    if (_preparedPlayerSource != null && _preparedPlayerSource != source) {
      await _safeAsync(() => playerController.stopPlayer());
      await _safeAsync(() => playerController.release());
      _preparedPlayerSource = null;
    }
    try {
      await playerController.preparePlayer(
        path: source,
        shouldExtractWaveform: true,
        noOfSamples: 160,
      );
      _preparedPlayerSource = source;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// ?? PlayerController ????????????????????????
  /// ??? Riverpod state?previewPlaying??high-frequency ? position
  /// ????????UI ?? AnimatedBuilder ?? controller????? 10
  /// ?? state.copyWith ????????
  void _bindPlayerStreams() {
    _playerStateSub?.cancel();
    _completionSub?.cancel();

    _playerStateSub = playerController.onPlayerStateChanged.listen((s) {
      if (_disposed) {
        return;
      }
      final playing = s == PlayerState.playing;
      if (state.previewPlaying != playing) {
        state = state.copyWith(previewPlaying: playing);
      }
    });

    // FinishMode.pause ? PlayerController ?????????????
    // ????? seek ? 0?? UI ??????????????????
    _completionSub = playerController.onCompletion.listen((_) async {
      if (_disposed) {
        return;
      }
      await _safeAsync(() => playerController.seekTo(0));
      if (mounted && state.previewPlaying) {
        state = state.copyWith(previewPlaying: false);
      }
    });
  }

  /// ?????????audio_waveforms ???? m4a (mpeg4 + AAC)???
  /// ????? .m4a??? / ??????????????????
  String _buildRecordingPath() {
    final base = buildTemporaryRecordingPath();
    final dot = base.lastIndexOf('.');
    if (dot < 0) {
      return '$base.m4a';
    }
    return '${base.substring(0, dot)}.m4a';
  }

  List<RecordingCategoryItem> _parseCategories(dynamic data) {
    if (data is! List) {
      return const <RecordingCategoryItem>[];
    }
    final result = <RecordingCategoryItem>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      // Count may be returned under several keys depending on backend version.
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

  /// `recordingFolderList` ???????? `List` ????? `{ records: [...] }`?
  /// ?????????????????????
  List<RecordingFolderItem> _parseFolders(dynamic data, int categoryId) {
    final sourceList = switch (data) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['records'] is List<dynamic> =>
        map['records'] as List<dynamic>,
      _ => const <dynamic>[],
    };
    final result = <RecordingFolderItem>[];
    for (final raw in sourceList) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
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

  /// ?????????? `2026-04-07 12:34:56`???? `2026.04.07`?
  /// ?????????????????????????????
  String _formatFolderDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final match = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})').firstMatch(
      trimmed,
    );
    if (match == null) {
      return trimmed;
    }
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
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      // recordingList ??????? `filePath`????????
      // `app/upload/.../xxx.wav`??`url` ???????????
      final rawPath = (raw['filePath'] ?? raw['url'] ?? '').toString();
      final url = _resolveMediaUrl(rawPath);
      if (id <= 0 || name.isEmpty || url.isEmpty) {
        continue;
      }
      // ????? record ????? `categoryId`???????????
      // ????????????? id?
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

  /// ??? record ?????????????
  /// ?????????? "507914"??????????? "1.2MB"??
  String _resolveSizeLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['sizeLabel'],
      item['size'],
      item['fileSize'],
      item['totalFileSize'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isEmpty || value == 'null') {
        continue;
      }
      final asNumber = double.tryParse(value);
      if (asNumber != null && !value.contains(RegExp(r'[a-zA-Z]'))) {
        return _formatBytesLabel(asNumber);
      }
      return value;
    }
    return '';
  }

  /// ??? record ??????????????????? `MM.dd.yyyy`?
  /// ?????????????????????
  String _resolveDateLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['createTime'],
      item['createDate'],
      item['updateTime'],
    ];
    for (final candidate in candidates) {
      final raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') {
        continue;
      }
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
    if (bytes <= 0) {
      return '0KB';
    }
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
    if (categories.any((item) => item.id == currentId)) {
      return currentId;
    }
    return categories.firstOrNull?.id ?? 0;
  }

  int _parseDuration(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return 0;
    }
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
    final centiseconds = ((milliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
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
    if (value is int) {
      return value;
    }
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

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  @override
  void dispose() {
    _disposed = true;
    // ?????????StateNotifier.dispose ??? await??? cancel
    // ???????????????? cancel ???
    try {
      _playerStateSub?.cancel();
    } catch (_) {}
    try {
      _completionSub?.cancel();
    } catch (_) {}
    try {
      recorderController.dispose();
    } catch (_) {}
    try {
      playerController.dispose();
    } catch (_) {}
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

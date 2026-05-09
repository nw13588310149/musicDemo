import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Web-compatible audio player. media_kit is already initialized in main.dart
// (MediaKit.ensureInitialized) and is the same library used by the cloud
// drive / music-play features. We use it ONLY on Web as a fallback for
// preview playback, since `audio_waveforms` doesn't ship a Web backend.
import 'package:media_kit/media_kit.dart' as mk;

import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../audio/recording_bytes_loader.dart';
import '../data/recording_system_repository.dart';
import 'recording_system_state.dart';

// IMPORTANT - Encoding note for maintainers:
// All strings AND comments in this file are intentionally pure ASCII / English
// (no CJK characters). Reason: the Cursor `Write` tool on Windows has been
// observed to mangle UTF-8 multibyte chars when persisting files (every
// Chinese char becomes `?`), which then leaks to the UI as e.g.
// "?????????????? iPad / ??????" in error banners. Keeping this file ASCII
// guarantees error messages render correctly on every platform regardless of
// font availability (Flutter Web's default Roboto has no CJK glyphs either,
// so even if encoding survived, Chinese without an explicit `PingFang SC`
// fontFamily would still render as `?` boxes on Web).
//
// User-facing Chinese is handled in the UI layer (recording_system_page.dart),
// which was authored manually and uses `fontFamily: 'PingFang SC'` everywhere.

/// Recording feature controller, backed by Simform's `audio_waveforms`.
///
/// Architecture:
/// - [recorderController] drives recording + live amplitude + elapsedDuration
///   (it's a ChangeNotifier itself). The UI subscribes via AnimatedBuilder so
///   only the stopwatch / wave panel rebuilds, never the whole subtree.
/// - [playerController] drives preview playback via native AVAudioPlayer /
///   ExoPlayer + AudioFileWaveforms widget for waveform & draggable cursor.
///
/// Platform support:
/// - iOS / Android: full support (recording + preview playback).
/// - Web: recording is NOT supported (audio_waveforms has no Web backend);
///   the user gets a clear "use the iPad / mobile app" banner if they try
///   to record. Preview playback OF ALREADY-SAVED recordings IS supported
///   on Web via a media_kit fallback player ([_webPreviewPlayer]).
/// - Windows / macOS desktop: native channels throw [MissingPluginException];
///   every native call is wrapped in [_safeAsync] / try-catch so the UI never
///   crashes - only recording / playback are unavailable.
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
    // PlayerController.onCurrentDurationChanged defaults to ~5Hz; high yields
    // ~10Hz which makes the preview cursor smoother on iPad.
    try {
      this.playerController.updateFrequency = UpdateFrequency.high;
    } catch (_) {}
    _bindPlayerStreams();
    unawaited(refresh());
  }

  final RecordingSystemRepository _repository;

  /// Recording controller. UI binds via `AudioWaveforms(recorderController:)`
  /// or `AnimatedBuilder(animation: recorderController, ...)`.
  final RecorderController recorderController;

  /// Playback controller. UI binds via `AudioFileWaveforms(playerController:)`
  /// or `AnimatedBuilder(animation: playerController, ...)`.
  final PlayerController playerController;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _completionSub;

  /// Local file path of the active recording. Needed after stop() for upload
  /// and preview playback.
  String? _currentRecordingPath;

  /// Last source we successfully prepared the player with. Used to short-
  /// circuit re-prepare for the same source.
  String? _preparedPlayerSource;

  bool _disposed = false;

  /// Set to true once we've detected the audio plugin is unavailable on this
  /// platform (web/desktop). All subsequent entry points fail fast.
  bool _audioFeatureBroken = false;

  // ---------------------------------------------------------------------------
  // Web fallback playback (media_kit)
  //
  // On Flutter Web `audio_waveforms` is unsupported (the plugin only
  // registers iOS / Android native channels). We can't record on Web - that
  // would require Web Audio's MediaRecorder API which is a sizeable lift -
  // but we DO want users to be able to listen to recordings that were
  // previously uploaded from the iPad. media_kit ships a Web backend
  // (libmpv-wasm + HTMLMediaElement fallback), so we plug it in for the
  // preview-playback codepath.
  //
  // Lifecycle: the player is lazily created on the first preview, reused
  // across sources (we just call player.open(...) for each new source), and
  // disposed in [dispose].
  // ---------------------------------------------------------------------------
  mk.Player? _webPlayer;
  StreamSubscription<bool>? _webPlayingSub;
  StreamSubscription<Duration>? _webPositionSub;
  StreamSubscription<Duration>? _webDurationSub;
  StreamSubscription<bool>? _webCompletedSub;
  String? _webPreparedSource;

  // ---------------------------------------------------------------------------
  // Friendly Chinese versions of every user-visible string. Defined as ASCII
  // unicode escapes so this file stays binary-safe regardless of the editor /
  // terminal codepage. The UI layer uses `fontFamily: 'PingFang SC'` so these
  // render correctly on iOS / Android / desktop. On Flutter Web, where the
  // browser may not have PingFang SC, the toast / banner widgets fall back to
  // the system Chinese font which is bundled in the host OS.
  //
  // To add a new message: pick an ASCII identifier, then put the Chinese
  // characters as `\u` escapes in the value. Use https://www.branah.com/unicode
  // or `dart -e "print('\\u${'\u4f60'.codeUnits.first.toRadixString(16)}');"`
  // (or just rely on a small helper script) to convert.
  // ---------------------------------------------------------------------------

  // "\u5f53\u524d\u5e73\u53f0\u6682\u4e0d\u652f\u6301\u5f55\u97f3\uff0c\u8bf7\u5728 iPad / \u79fb\u52a8\u7aef\u4f7f\u7528\u3002"
  static const _zhUnsupported =
      '\u5f53\u524d\u5e73\u53f0\u6682\u4e0d\u652f\u6301\u5f55\u97f3\uff0c\u8bf7\u5728 iPad / \u79fb\u52a8\u7aef\u4f7f\u7528\u3002';
  // "\u52a0\u8f7d\u5f55\u97f3\u5217\u8868\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5"
  static const _zhLoadListFailed =
      '\u52a0\u8f7d\u5f55\u97f3\u5217\u8868\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  // "\u52a0\u8f7d\u6587\u4ef6\u5939\u5931\u8d25"
  static const _zhLoadFoldersFailed = '\u52a0\u8f7d\u6587\u4ef6\u5939\u5931\u8d25';
  // "\u52a0\u8f7d\u5f55\u97f3\u5931\u8d25"
  static const _zhLoadRecordingsFailed = '\u52a0\u8f7d\u5f55\u97f3\u5931\u8d25';
  // "\u5207\u6362\u5206\u7c7b\u5931\u8d25"
  static const _zhSwitchCategoryFailed = '\u5207\u6362\u5206\u7c7b\u5931\u8d25';
  // "\u8fd4\u56de\u6587\u4ef6\u5939\u5217\u8868\u5931\u8d25"
  static const _zhBackToFoldersFailed = '\u8fd4\u56de\u6587\u4ef6\u5939\u5217\u8868\u5931\u8d25';
  // "\u8bf7\u8f93\u5165\u5206\u7c7b\u540d\u79f0"
  static const _zhEnterCategoryName = '\u8bf7\u8f93\u5165\u5206\u7c7b\u540d\u79f0';
  // "\u65b0\u5efa\u5206\u7c7b\u5931\u8d25"
  static const _zhCreateCategoryFailed = '\u65b0\u5efa\u5206\u7c7b\u5931\u8d25';
  // "\u5220\u9664\u5206\u7c7b\u5931\u8d25"
  static const _zhDeleteCategoryFailed = '\u5220\u9664\u5206\u7c7b\u5931\u8d25';
  // "\u91cd\u547d\u540d\u5206\u7c7b\u5931\u8d25"
  static const _zhRenameCategoryFailed = '\u91cd\u547d\u540d\u5206\u7c7b\u5931\u8d25';
  // "\u65e0\u6548\u7684\u5206\u7c7b"
  static const _zhInvalidCategory = '\u65e0\u6548\u7684\u5206\u7c7b';
  // "\u8bf7\u8f93\u5165\u6587\u4ef6\u5939\u540d\u79f0"
  static const _zhEnterFolderName = '\u8bf7\u8f93\u5165\u6587\u4ef6\u5939\u540d\u79f0';
  // "\u8bf7\u5148\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b"
  static const _zhPickCategoryFirst = '\u8bf7\u5148\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b';
  // "\u65b0\u5efa\u6587\u4ef6\u5939\u5931\u8d25"
  static const _zhCreateFolderFailed = '\u65b0\u5efa\u6587\u4ef6\u5939\u5931\u8d25';
  // "\u91cd\u547d\u540d\u6587\u4ef6\u5939\u5931\u8d25"
  static const _zhRenameFolderFailed = '\u91cd\u547d\u540d\u6587\u4ef6\u5939\u5931\u8d25';
  // "\u5220\u9664\u6587\u4ef6\u5939\u5931\u8d25"
  static const _zhDeleteFolderFailed = '\u5220\u9664\u6587\u4ef6\u5939\u5931\u8d25';
  // "\u65e0\u6548\u7684\u6587\u4ef6\u5939"
  static const _zhInvalidFolder = '\u65e0\u6548\u7684\u6587\u4ef6\u5939';
  // "\u8bf7\u5728\u8bbe\u7f6e\u4e2d\u6388\u4e88\u9ea6\u514b\u98ce\u6743\u9650"
  static const _zhMicPermission =
      '\u8bf7\u5728\u8bbe\u7f6e\u4e2d\u6388\u4e88\u9ea6\u514b\u98ce\u6743\u9650';
  // "\u5f00\u59cb\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u9ea6\u514b\u98ce\u6743\u9650"
  static const _zhStartRecordingFailed =
      '\u5f00\u59cb\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u9ea6\u514b\u98ce\u6743\u9650';
  // "\u5f00\u59cb\u5f55\u97f3\u5931\u8d25"
  static const _zhStartRecordingFailedShort = '\u5f00\u59cb\u5f55\u97f3\u5931\u8d25';
  // "\u6682\u505c\u5f55\u97f3\u5931\u8d25"
  static const _zhPauseRecordingFailed = '\u6682\u505c\u5f55\u97f3\u5931\u8d25';
  // "\u7ee7\u7eed\u5f55\u97f3\u5931\u8d25"
  static const _zhResumeRecordingFailed = '\u7ee7\u7eed\u5f55\u97f3\u5931\u8d25';
  // "\u5f55\u5236\u65f6\u957f\u4e0d\u80fd\u5c11\u4e8e 5 \u79d2"
  static const _zhMinFiveSeconds = '\u5f55\u5236\u65f6\u957f\u4e0d\u80fd\u5c11\u4e8e 5 \u79d2';
  // "\u8bf7\u5148\u5f55\u5236\u4e00\u6bb5\u97f3\u9891"
  static const _zhRecordSomethingFirst = '\u8bf7\u5148\u5f55\u5236\u4e00\u6bb5\u97f3\u9891';
  // "\u672a\u751f\u6210\u6709\u6548\u7684\u5f55\u97f3\u6587\u4ef6\uff0c\u8bf7\u91cd\u8bd5"
  static const _zhNoValidRecording =
      '\u672a\u751f\u6210\u6709\u6548\u7684\u5f55\u97f3\u6587\u4ef6\uff0c\u8bf7\u91cd\u8bd5';
  // "\u7ed3\u675f\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5"
  static const _zhFinishRecordingFailed =
      '\u7ed3\u675f\u5f55\u97f3\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
  // "\u8bfb\u53d6\u5f55\u97f3\u6587\u4ef6\u5931\u8d25"
  static const _zhReadRecordingFailed = '\u8bfb\u53d6\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  // "\u5f55\u97f3\u6587\u4ef6\u4e3a\u7a7a\uff0c\u8bf7\u91cd\u65b0\u5f55\u5236"
  static const _zhRecordingEmpty =
      '\u5f55\u97f3\u6587\u4ef6\u4e3a\u7a7a\uff0c\u8bf7\u91cd\u65b0\u5f55\u5236';
  // "\u672a\u547d\u540d\u5f55\u97f3"
  static const _zhDefaultRecordingName = '\u672a\u547d\u540d\u5f55\u97f3';
  // "\u5f55\u97f3"
  static const _zhRecordingPrefix = '\u5f55\u97f3';
  // "\u6ca1\u6709\u53ef\u64ad\u653e\u7684\u5f55\u97f3\u6587\u4ef6"
  static const _zhNoSourceToPlay = '\u6ca1\u6709\u53ef\u64ad\u653e\u7684\u5f55\u97f3\u6587\u4ef6';
  // "\u52a0\u8f7d\u5f55\u97f3\u6587\u4ef6\u5931\u8d25"
  static const _zhLoadAudioFailed = '\u52a0\u8f7d\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  // "\u64ad\u653e\u5931\u8d25"
  static const _zhPlayFailed = '\u64ad\u653e\u5931\u8d25';
  // "\u8df3\u8f6c\u5931\u8d25"
  static const _zhSeekFailed = '\u8df3\u8f6c\u5931\u8d25';
  // "\u6ca1\u6709\u53ef\u4fdd\u5b58\u7684\u5f55\u97f3\u6587\u4ef6"
  static const _zhNoRecordingToSave =
      '\u6ca1\u6709\u53ef\u4fdd\u5b58\u7684\u5f55\u97f3\u6587\u4ef6';
  // "\u8bf7\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b"
  static const _zhPickCategory = '\u8bf7\u9009\u62e9\u4e00\u4e2a\u5206\u7c7b';
  // "\u8bf7\u8f93\u5165\u4f5c\u54c1\u540d\u79f0"
  static const _zhEnterTitle = '\u8bf7\u8f93\u5165\u4f5c\u54c1\u540d\u79f0';
  // "\u4e0a\u4f20\u5f55\u97f3\u6587\u4ef6\u5931\u8d25"
  static const _zhUploadFailed = '\u4e0a\u4f20\u5f55\u97f3\u6587\u4ef6\u5931\u8d25';
  // "\u4e0a\u4f20\u6210\u529f\u4f46\u672a\u8fd4\u56de\u6587\u4ef6\u8def\u5f84"
  static const _zhUploadNoPath =
      '\u4e0a\u4f20\u6210\u529f\u4f46\u672a\u8fd4\u56de\u6587\u4ef6\u8def\u5f84';
  // "\u4fdd\u5b58\u5f55\u97f3\u5931\u8d25"
  static const _zhSaveRecordingFailed = '\u4fdd\u5b58\u5f55\u97f3\u5931\u8d25';
  // "\u5220\u9664\u5f55\u97f3\u5931\u8d25"
  static const _zhDeleteRecordingFailed = '\u5220\u9664\u5f55\u97f3\u5931\u8d25';
  // "\u65e0\u6548\u7684\u5f55\u97f3\u4f5c\u54c1"
  static const _zhInvalidRecording = '\u65e0\u6548\u7684\u5f55\u97f3\u4f5c\u54c1';
  // "\u5f55\u97f3\u6587\u4ef6\u8def\u5f84\u7f3a\u5931"
  static const _zhRecordingPathMissing = '\u5f55\u97f3\u6587\u4ef6\u8def\u5f84\u7f3a\u5931';
  // "\u91cd\u547d\u540d\u5931\u8d25"
  static const _zhRenameFailed = '\u91cd\u547d\u540d\u5931\u8d25';
  // "\u8bf7\u5148\u4fdd\u5b58\u5f55\u97f3\u518d\u5206\u4eab"
  static const _zhSaveBeforeShare = '\u8bf7\u5148\u4fdd\u5b58\u5f55\u97f3\u518d\u5206\u4eab';
  // "\u52a0\u8f7d\u73ed\u7ea7\u5217\u8868\u5931\u8d25"
  static const _zhLoadClassesFailed = '\u52a0\u8f7d\u73ed\u7ea7\u5217\u8868\u5931\u8d25';
  // "\u8bf7\u9009\u62e9\u81f3\u5c11\u4e00\u4e2a\u73ed\u7ea7"
  static const _zhPickAtLeastOneClass =
      '\u8bf7\u9009\u62e9\u81f3\u5c11\u4e00\u4e2a\u73ed\u7ea7';
  // "\u5206\u4eab\u5931\u8d25"
  static const _zhShareFailed = '\u5206\u4eab\u5931\u8d25';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: _zhLoadListFailed);
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
            : _fallbackMessage(response.msg, _zhLoadFoldersFailed),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        errorMessage: _zhSwitchCategoryFailed,
      );
    }
  }

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
            : _fallbackMessage(response.msg, _zhLoadRecordingsFailed),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        folders: _parseFolders(response.data, categoryId),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, _zhLoadFoldersFailed),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        errorMessage: _zhBackToFoldersFailed,
      );
    }
  }

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
      return _zhEnterCategoryName;
    }
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

  /// Backend's `recordingCategorySave` doubles as create/update: when id > 0
  /// it updates by id.
  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _zhEnterCategoryName;
    }
    if (id <= 0) {
      return _zhInvalidCategory;
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.renameCategory(id, trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhRenameCategoryFailed);
    }
    await refresh();
    return null;
  }

  // ?? Folder CRUD ????????????????????????????????????????????????????????????

  Future<String?> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _zhEnterFolderName;
    }
    final categoryId = state.selectedCategoryId;
    if (categoryId <= 0) {
      return _zhPickCategoryFirst;
    }
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
    if (trimmed.isEmpty) {
      return _zhEnterFolderName;
    }
    if (folder.id <= 0) {
      return _zhInvalidFolder;
    }
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
    if (folder.id <= 0) {
      return _zhInvalidFolder;
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteFolder(folder.id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, _zhDeleteFolderFailed);
    }
    await _reloadFolders(folder.categoryId);
    return null;
  }

  /// Leave the recording / preview pages and reset to the list home. Native
  /// resources are released in the background.
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
      // On Web, surface the unsupported notice up-front so the user doesn't
      // tap the record button only to be told nothing happens. On native we
      // start fresh with no error.
      errorMessage: kIsWeb ? _zhUnsupported : null,
      clearError: !kIsWeb,
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

  /// Leave the recording / preview pages: UI snaps back to list immediately,
  /// native cleanup happens in the background. We deliberately don't await
  /// the cleanup because cancel/pause on iPad can take a beat and we don't
  /// want the user to feel the back button is stuck.
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

  /// Tear down all native resources for both recorder and player. Called when
  /// the page is disposed or when the app goes to background / locks.
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

    // Web player: pause + reset position. Don't dispose() yet - reuse it
    // for the next preview to avoid the multi-second media_kit cold-start.
    final webPlayer = _webPlayer;
    if (webPlayer != null) {
      await _safeAsync(() => webPlayer.pause());
      await _safeAsync(() => webPlayer.seek(Duration.zero));
    }
  }

  Future<String?> startRecording() async {
    if (kIsWeb || _audioFeatureBroken) {
      return _zhUnsupported;
    }
    try {
      // Defensive cleanup: if a previous session didn't close cleanly the
      // recorder might still be in recording / paused state, in which case
      // record() will throw. Force-stop first.
      if (recorderController.recorderState != RecorderState.stopped) {
        await _safeAsync(() => recorderController.stop());
      }
      _resetRecorderWaveform();

      final hasPermission = await recorderController.checkPermission();
      if (!hasPermission) {
        return _zhMicPermission;
      }
      // audio_waveforms records mpeg4 + AAC by default on iOS / Android.
      // The file extension MUST be .m4a, otherwise iOS AVAudioPlayer can't
      // recognize the container during preview playback.
      final tmpPath = _buildRecordingPath();
      _currentRecordingPath = tmpPath;
      await recorderController.record(
        path: tmpPath,
        recorderSettings: const RecorderSettings(
          sampleRate: 44100,
          bitRate: 128000,
        ),
      );
      // Flip recordingPhase to recording. The stopwatch / wave panel
      // subscribe to recorderController directly via AnimatedBuilder, so this
      // single state.copyWith only triggers a low-frequency rebuild of the
      // outer view shell.
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
      return _zhUnsupported;
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(recordingPhase: RecordingPhase.idle);
      }
      return _platformMessage(error, _zhStartRecordingFailed);
    } catch (error) {
      // Last-resort cleanup so the UI returns to idle and the user can try
      // again.
      await _safeAsync(() => recorderController.stop());
      _resetRecorderWaveform();
      if (mounted) {
        state = state.copyWith(recordingPhase: RecordingPhase.idle);
      }
      return '$_zhStartRecordingFailedShort: $error';
    }
  }

  Future<String?> pauseRecording() async {
    try {
      await recorderController.pause();
      state = state.copyWith(recordingPhase: RecordingPhase.paused);
      return null;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhPauseRecordingFailed);
    } catch (error) {
      return '$_zhPauseRecordingFailed: $error';
    }
  }

  Future<String?> resumeRecording() async {
    try {
      // RecorderController.record() called without a path resumes from where
      // it left off when in paused state.
      await recorderController.record();
      state = state.copyWith(recordingPhase: RecordingPhase.recording);
      return null;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhResumeRecordingFailed);
    } catch (error) {
      return '$_zhResumeRecordingFailed: $error';
    }
  }

  Future<String?> finishRecording() async {
    return _finalizeRecordingToPreview(minElapsedMs: 5000);
  }

  /// "Listen now" button: lower threshold (1s) so the user can hear what they
  /// just recorded before deciding to keep going or re-record.
  Future<String?> finalizeRecordingForListening() async {
    return _finalizeRecordingToPreview(minElapsedMs: 1000);
  }

  /// Open the "save recording" dialog. Wired to the Save button on the
  /// preview page header.
  void requestSaveDialog() {
    state = state.copyWith(showSaveDialog: true);
  }

  Future<String?> _finalizeRecordingToPreview({
    required int minElapsedMs,
  }) async {
    final elapsedMs = recorderController.elapsedDuration.inMilliseconds;
    if (elapsedMs < minElapsedMs) {
      return minElapsedMs >= 5000 ? _zhMinFiveSeconds : _zhRecordSomethingFirst;
    }
    String? resolvedSource;
    try {
      // RecorderController.stop() can return null on iOS in edge cases; fall
      // back to the path we passed into record().
      final source = await recorderController.stop();
      resolvedSource = source ?? _currentRecordingPath;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhFinishRecordingFailed);
    } catch (error) {
      return '$_zhFinishRecordingFailed: $error';
    }

    if (resolvedSource == null || resolvedSource.isEmpty) {
      return _zhNoValidRecording;
    }

    // Read the recorded bytes for upload + as a fallback source for preview.
    // loadRecordedBytes handles both bare paths and file:// URIs.
    Uint8ListBytes bytesResult;
    try {
      bytesResult = Uint8ListBytes(await loadRecordedBytes(resolvedSource));
    } on FileSystemException catch (error) {
      return '$_zhReadRecordingFailed: ${error.osError?.message ?? error.message}';
    } catch (error) {
      return '$_zhReadRecordingFailed: $error';
    }
    if (bytesResult.bytes.isEmpty) {
      return _zhRecordingEmpty;
    }

    final durationMs = elapsedMs;
    // Snapshot the live amplitude data into an unmodifiable list so the
    // RecordingEntry can carry it forward. If empty (rare) we fall back to a
    // seeded pseudo-random waveform so the list card never shows a flat line.
    final waveformSnapshot = recorderController.waveData.isEmpty
        ? _fallbackWaveform(resolvedSource.hashCode)
        : List<double>.unmodifiable(recorderController.waveData);
    _resetRecorderWaveform();

    final durationLabel = _formatDurationLabel(durationMs);
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
    // Pre-prepare the player so AudioFileWaveforms has maxDuration / waveform
    // ready as soon as the preview view builds. If prepare fails we still
    // proceed - the user will get a clear error toast when they tap play.
    await _preparePreviewPlayer(resolvedSource);
    final now = DateTime.now();
    final autoTitle =
        '$_zhRecordingPrefix${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
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
      recordedBytes: bytesResult.bytes,
      showSaveDialog: false,
      selectedSaveCategoryId: draft.categoryId,
      pendingTitle: draft.name == defaultName ? autoTitle : draft.name,
    );
    return null;
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
    if (kIsWeb) {
      // Web: pre-open the source in media_kit so the duration / metadata is
      // ready by the time the user taps play. Errors are intentionally
      // swallowed - they'll surface clearly on the explicit play tap.
      unawaited(() async {
        try {
          final player = _ensureWebPlayer();
          await player.open(mk.Media(resolved), play: false);
          _webPreparedSource = resolved;
        } catch (_) {}
      }());
      return;
    }
    // Native: prepare audio_waveforms player so AudioFileWaveforms has the
    // extracted waveform ready when the user taps play.
    unawaited(_preparePreviewPlayer(resolved));
  }

  /// Toggle preview play/pause. On iOS / Android backed by audio_waveforms
  /// (native AVPlayer / ExoPlayer); on Web backed by media_kit's Player which
  /// internally uses HTMLAudioElement.
  Future<void> togglePreviewPlayback() async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    if (kIsWeb) {
      await _toggleWebPlayback(source);
      return;
    }
    final prepareError = await _preparePreviewPlayerForUI(source);
    if (prepareError != null) {
      if (mounted) {
        state = state.copyWith(errorMessage: prepareError);
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
          errorMessage: _platformMessage(error, _zhPlayFailed),
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: '$_zhPlayFailed: $error');
      }
    }
  }

  /// Seek by [deltaMs] from the current position.
  Future<void> seekPreviewBy(int deltaMs) async {
    if (kIsWeb) {
      final base = state.previewPositionMs;
      return seekPreviewTo(base + deltaMs);
    }
    int base;
    try {
      base = await playerController.getDuration(DurationType.current);
    } catch (_) {
      base = 0;
    }
    if (base < 0) base = 0;
    return seekPreviewTo(base + deltaMs);
  }

  /// Seek to an absolute position [targetMs] (clamped to [0, maxDuration]).
  Future<void> seekPreviewTo(int targetMs) async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    if (kIsWeb) {
      await _seekWebPlayback(source, targetMs);
      return;
    }
    final prepareError = await _preparePreviewPlayerForUI(source);
    if (prepareError != null) {
      if (mounted) {
        state = state.copyWith(errorMessage: prepareError);
      }
      return;
    }
    final maxDur = playerController.maxDuration > 0
        ? playerController.maxDuration
        : state.previewDurationMs;
    final clamped = targetMs.clamp(0, math.max(maxDur, 0)).toInt();
    try {
      await playerController.seekTo(clamped);
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: _platformMessage(error, _zhSeekFailed),
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: '$_zhSeekFailed: $error');
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

  /// Upload the in-memory recording bytes and persist a recordingSave row.
  /// On success returns null, on any failure returns a localized error string.
  ///
  /// IMPORTANT - this method intentionally does NOT close the save dialog or
  /// flip `viewMode` back to list. Doing both inside one call has been the
  /// source of the iPad save crash ("This exception was thrown because the
  /// deactivated widget's ancestor was looked up..."): tearing down the
  /// dialog AND the parent _RecordingStage at the same time leaves the
  /// dialog mid-rebuild on an already-deactivated tree.
  ///
  /// Cleanup is the UI's responsibility:
  ///   1. await saveCurrentRecording() -> message
  ///   2. if message == null: controller.closeSaveDialog()
  ///   3. addPostFrameCallback(() => controller.finishSaveAndReturnToList())
  /// See `_DialogActionButton` for the actual choreography.
  Future<String?> saveCurrentRecording() async {
    // Re-entrancy guard: if the user double-taps the confirm button, ignore
    // the second tap rather than firing a second upload + saveRecording
    // (would create a duplicate row).
    if (state.busy) {
      return null;
    }
    final bytes = state.recordedBytes;
    final categoryId = state.selectedSaveCategoryId;
    if (bytes == null || bytes.isEmpty) {
      return _zhNoRecordingToSave;
    }
    if (categoryId <= 0) {
      return _zhPickCategory;
    }

    final title = state.pendingTitle.trim();
    if (title.isEmpty) {
      return _zhEnterTitle;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final uploadResponse = await _repository.uploadRecording(
        bytes: bytes,
        filename: 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      if (!uploadResponse.isSuccess) {
        if (mounted) {
          state = state.copyWith(busy: false);
        }
        return _fallbackMessage(uploadResponse.msg, _zhUploadFailed);
      }
      // Backend returns both `path` (relative, like app/upload/.../xxx.m4a)
      // and `url` (absolute URL). The save endpoint wants the relative path,
      // not the URL.
      final filePath = parseUploadResult(uploadResponse.data).savable;
      if (filePath.isEmpty) {
        if (mounted) {
          state = state.copyWith(busy: false);
        }
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
        if (mounted) {
          state = state.copyWith(busy: false);
        }
        return _fallbackMessage(saveResponse.msg, _zhSaveRecordingFailed);
      }

      // Success: just clear busy. The UI will close the dialog and call
      // finishSaveAndReturnToList() in the next frame.
      if (mounted) {
        state = state.copyWith(busy: false);
      }
      return null;
    } on PlatformException catch (error) {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
      return _platformMessage(error, _zhSaveRecordingFailed);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
      return '$_zhSaveRecordingFailed: $error';
    }
  }

  /// Called by the UI ONE FRAME AFTER a successful save (see
  /// _DialogActionButton). Switches back to the list view and reloads the
  /// folder / category contents so the new recording shows up.
  ///
  /// The deferral via `addPostFrameCallback` is essential: the dialog
  /// dismissal animation triggered by `closeSaveDialog()` needs at least
  /// one frame to start before we tear down the parent _RecordingStage by
  /// flipping `viewMode` to list. Doing both in the same frame is what
  /// caused the iPad "deactivated widget's ancestor" exception.
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
      // Same category, just reload its folder list so the new file's
      // counter (if any) refreshes.
      await _reloadFolders(categoryId);
    }
  }

  Future<String?> deleteRecording(RecordingEntry item) async {
    // Local draft (not yet uploaded): just clear local state, don't hit the
    // backend.
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

  /// Rename an existing recording. Backend uses the same `recordingSave`
  /// endpoint - id > 0 means update. We carry forward filePath / duration /
  /// folderId / paramN from the original payload and only swap the name.
  Future<String?> renameRecording(RecordingEntry item, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _zhEnterTitle;
    }
    if (trimmed == item.name) {
      return null;
    }
    if (item.id <= 0) {
      return _zhInvalidRecording;
    }
    final payload = item.payload;
    final filePath = (payload['filePath'] ?? payload['url'] ?? '').toString();
    if (filePath.isEmpty) {
      return _zhRecordingPathMissing;
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
    if (target == null || target.isLocalDraft) {
      return _zhSaveBeforeShare;
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, _zhLoadClassesFailed);
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
      return _zhSaveBeforeShare;
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return _zhPickAtLeastOneClass;
    }
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

  /// Wraps a Future-returning native call. audio_waveforms throws
  /// MissingPluginException on web / desktop; this swallows it so the UI
  /// never crashes.
  Future<void> _safeAsync(Future<dynamic> Function() op) async {
    try {
      await op();
    } catch (_) {}
  }

  /// Clears RecorderController.waveData / labels so the next session starts
  /// from an empty canvas.
  void _resetRecorderWaveform() {
    try {
      recorderController.reset();
    } catch (_) {}
  }

  Future<void> _stopPreviewPlayback() async {
    if (kIsWeb) {
      final player = _webPlayer;
      if (player == null) {
        return;
      }
      await _safeAsync(() => player.pause());
      await _safeAsync(() => player.seek(Duration.zero));
      if (mounted && state.previewPlaying) {
        state = state.copyWith(previewPlaying: false, previewPositionMs: 0);
      } else if (mounted && state.previewPositionMs != 0) {
        state = state.copyWith(previewPositionMs: 0);
      }
      return;
    }
    if (playerController.playerState == PlayerState.stopped) {
      return;
    }
    await _safeAsync(() => playerController.pausePlayer());
    await _safeAsync(() => playerController.seekTo(0));
  }

  // ---------------------------------------------------------------------------
  // Web playback helpers (media_kit)
  // ---------------------------------------------------------------------------

  /// Lazily create the media_kit player and bind its low-frequency state
  /// streams (playing / position / duration / completion) into Riverpod
  /// state. Position is mirrored at media_kit's default 250ms tick which is
  /// fine for a preview cursor (we don't render a high-FPS waveform on Web).
  mk.Player _ensureWebPlayer() {
    final existing = _webPlayer;
    if (existing != null) {
      return existing;
    }
    final player = mk.Player();
    _webPlayer = player;
    _webPlayingSub = player.stream.playing.listen((playing) {
      if (_disposed || !mounted) return;
      if (state.previewPlaying != playing) {
        state = state.copyWith(previewPlaying: playing);
      }
    });
    _webPositionSub = player.stream.position.listen((position) {
      if (_disposed || !mounted) return;
      final ms = position.inMilliseconds;
      if (state.previewPositionMs != ms) {
        state = state.copyWith(previewPositionMs: ms);
      }
    });
    _webDurationSub = player.stream.duration.listen((duration) {
      if (_disposed || !mounted) return;
      final ms = duration.inMilliseconds;
      // Only adopt the player-reported duration when we don't already have a
      // sensible one from the backend - otherwise the brief "0ms" tick that
      // media_kit emits between source switches would shrink the seek bar.
      if (ms > 0 && state.previewDurationMs <= 0) {
        state = state.copyWith(previewDurationMs: ms);
      }
    });
    _webCompletedSub = player.stream.completed.listen((completed) async {
      if (!completed || _disposed) return;
      // Match the iOS / Android behaviour: snap back to start, leave paused.
      await _safeAsync(() => player.seek(Duration.zero));
      if (mounted) {
        state = state.copyWith(previewPlaying: false, previewPositionMs: 0);
      }
    });
    return player;
  }

  Future<void> _toggleWebPlayback(String source) async {
    try {
      final player = _ensureWebPlayer();
      if (_webPreparedSource != source) {
        // Open the new source paused; the user's tap will start playback
        // immediately after via the play() call below.
        await player.open(mk.Media(source), play: false);
        _webPreparedSource = source;
      }
      if (player.state.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: '$_zhPlayFailed: $error');
      }
    }
  }

  Future<void> _seekWebPlayback(String source, int targetMs) async {
    try {
      final player = _ensureWebPlayer();
      if (_webPreparedSource != source) {
        await player.open(mk.Media(source), play: false);
        _webPreparedSource = source;
      }
      final maxMs = state.previewDurationMs > 0
          ? state.previewDurationMs
          : player.state.duration.inMilliseconds;
      final clamped = targetMs.clamp(0, math.max(maxMs, 0)).toInt();
      await player.seek(Duration(milliseconds: clamped));
      if (mounted) {
        state = state.copyWith(previewPositionMs: clamped);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: '$_zhSeekFailed: $error');
      }
    }
  }

  /// UI-facing prepare. Returns null on success, or a user-displayable error
  /// message (already localized) on failure.
  ///
  /// CRITICAL FIX: setFinishMode(pause) MUST be called AFTER each prepare.
  /// audio_waveforms's native AudioPlayer is lazy-created on first
  /// preparePlayer call, so any setFinishMode call before that is a no-op.
  /// And the default FinishMode is `stop`, which releases the native player
  /// after the first playback completes - meaning the user hears it once,
  /// then subsequent play taps do nothing. Setting `pause` keeps the player
  /// alive so it can be replayed.
  Future<String?> _preparePreviewPlayerForUI(String source) async {
    if (source.isEmpty) {
      return _zhNoSourceToPlay;
    }
    if (kIsWeb || _audioFeatureBroken) {
      return _zhUnsupported;
    }
    if (_preparedPlayerSource == source &&
        playerController.playerState != PlayerState.stopped) {
      return null;
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
      // Apply pause finish mode AFTER the native player exists; otherwise
      // the call is a no-op and the player gets disposed after first play.
      await _safeAsync(
        () => playerController.setFinishMode(finishMode: FinishMode.pause),
      );
      return null;
    } on MissingPluginException {
      _audioFeatureBroken = true;
      return _zhUnsupported;
    } on PlatformException catch (error) {
      return _platformMessage(error, _zhLoadAudioFailed);
    } catch (error) {
      return '$_zhLoadAudioFailed: $error';
    }
  }

  /// finalize-time prepare: doesn't surface errors directly to UI; the user
  /// will see a clear error if they tap play later.
  Future<bool> _preparePreviewPlayer(String source) async {
    final error = await _preparePreviewPlayerForUI(source);
    return error == null;
  }

  /// Mirror low-frequency player state (previewPlaying) into Riverpod state.
  /// High-frequency position is consumed directly by AnimatedBuilder /
  /// StreamBuilder in the UI, never via state.copyWith.
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

    // FinishMode.pause already seeks back to 0 + pauses on completion. We do
    // a defensive re-seek so the progress bar visibly snaps to 0.
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

  /// Build a temp file path for the new recording. audio_waveforms records
  /// m4a (mpeg4 + AAC) by default, so the suffix MUST be .m4a or both record
  /// and preview playback will fail.
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
      // Different backend versions return the count under different keys.
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

  /// recordingFolderList may return either a plain List or
  /// `{ records: [...] }` envelope. Tolerate both.
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

  /// Format `2026-04-07 12:34:56`-style timestamps as `2026.04.07` to match
  /// the cloud drive folder card style.
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
      // recordingList stores the relative path under `filePath` (e.g.
      // `app/upload/.../xxx.m4a`); older backends use `url`. Accept both.
      final rawPath = (raw['filePath'] ?? raw['url'] ?? '').toString();
      final url = _resolveMediaUrl(rawPath);
      if (id <= 0 || name.isEmpty || url.isEmpty) {
        continue;
      }
      // Prefer the categoryId returned by the backend; fall back to current.
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

  /// File size from the backend is sometimes a numeric string (e.g. "507914")
  /// and sometimes already-formatted (e.g. "1.2MB"). Both are accepted.
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

  /// Normalize createTime / createDate / updateTime to MM.dd.yyyy to match
  /// the cloud drive file card style.
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

  /// Translate a PlatformException into a user-friendly message: prefer the
  /// plugin-provided message / details, fall back to the supplied label.
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
    // StateNotifier.dispose is sync; we can't await any of these cancels.
    // try-catch guards each one so super.dispose still runs.
    try {
      _playerStateSub?.cancel();
    } catch (_) {}
    try {
      _completionSub?.cancel();
    } catch (_) {}
    try {
      _webPlayingSub?.cancel();
    } catch (_) {}
    try {
      _webPositionSub?.cancel();
    } catch (_) {}
    try {
      _webDurationSub?.cancel();
    } catch (_) {}
    try {
      _webCompletedSub?.cancel();
    } catch (_) {}
    try {
      recorderController.dispose();
    } catch (_) {}
    try {
      playerController.dispose();
    } catch (_) {}
    try {
      _webPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Lightweight wrapper used inside _finalizeRecordingToPreview so the
/// `late` local variable's type inference works cleanly across the try/catch
/// boundary on older Dart analyzer versions.
class Uint8ListBytes {
  const Uint8ListBytes(this.bytes);
  final Uint8List bytes;
}

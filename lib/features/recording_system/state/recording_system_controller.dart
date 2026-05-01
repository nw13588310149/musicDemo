import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:record/record.dart';

import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../audio/recording_bytes_loader.dart';
import '../data/recording_system_repository.dart';
import 'recording_system_state.dart';

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
    AudioRecorder? recorder,
    Player? player,
  }) : _repository = repository,
       _recorder = recorder,
       _player = player,
       super(const RecordingSystemState()) {
    if (_player != null) {
      _bindPlayerStreams(_player!);
    }
    unawaited(refresh());
  }

  final RecordingSystemRepository _repository;
  AudioRecorder? _recorder;
  Player? _player;

  Timer? _recordTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _durationSub;

  String? _currentRecordingSource;
  String? _openedPreviewSource;
  bool _recorderUnavailable = false;
  bool _playerUnavailable = false;

  Future<void> refresh() async {
    try {
      _openedPreviewSource = null;
      state = state.copyWith(loading: true, clearError: true);
      final categoryResponse = await _repository.getCategories();
      final categories = _parseCategories(categoryResponse.data);
      final selectedCategoryId = _resolveSelectedCategory(
        categories,
        state.selectedCategoryId,
      );
      final itemsResponse = selectedCategoryId > 0
          ? await _repository.getRecordings(selectedCategoryId)
          : null;
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        items: itemsResponse == null
            ? const <RecordingEntry>[]
            : _parseRecordings(itemsResponse.data, selectedCategoryId),
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
        errorMessage: itemsResponse == null || itemsResponse.isSuccess
            ? null
            : _fallbackMessage(itemsResponse.msg, '加载录音列表失败'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        errorMessage: '加载录音列表失败，请稍后重试',
      );
    }
  }

  Future<void> selectCategory(int id) async {
    if (id == state.selectedCategoryId) {
      return;
    }
    try {
      _openedPreviewSource = null;
      state = state.copyWith(
        selectedCategoryId: id,
        loading: true,
        clearError: true,
        searchQuery: '',
      );
      final response = await _repository.getRecordings(id);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        items: _parseRecordings(response.data, id),
        viewMode: RecordingViewMode.list,
        clearPreviewItem: true,
        clearPreviewSource: true,
        clearRecordedBytes: true,
        showSaveDialog: false,
        showShareDialog: false,
        shareClasses: const <RecordingShareClass>[],
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, '加载录音列表失败'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        errorMessage: '加载录音列表失败，请稍后重试',
      );
    }
  }

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入分类名称';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '新增分类失败');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除分类失败');
    }
    await refresh();
    return null;
  }

  Future<void> openNewRecording() async {
    final player = _player;
    if (player != null) {
      await player.stop();
    }
    _openedPreviewSource = null;
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
    await _stopRecordingTimer();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (state.recordingPhase != RecordingPhase.idle) {
      try {
        await _recorder?.stop();
      } catch (_) {}
    }
    _currentRecordingSource = null;
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

  Future<void> backToList() async {
    await _stopRecordingTimer();
    await _stopPreviewPlayback();
    _openedPreviewSource = null;
    if (state.recordingPhase != RecordingPhase.idle) {
      try {
        await _recorder?.cancel();
      } catch (_) {}
    }
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
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
    );
  }

  Future<String?> startRecording() async {
    try {
      final recorder = _ensureRecorder();
      if (recorder == null) {
        return '当前设备暂不支持录音，或录音组件初始化失败';
      }
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        return '录音需要麦克风权限，请先授权';
      }
      _currentRecordingSource = buildTemporaryRecordingPath();
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingSource!,
      );
      await _amplitudeSub?.cancel();
      _amplitudeSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen(_appendAmplitude);
      _startRecordingTimer();
      state = state.copyWith(
        recordingPhase: RecordingPhase.recording,
        clearError: true,
      );
      _openedPreviewSource = null;
      return null;
    } catch (_) {
      return '录音启动失败，请检查设备状态';
    }
  }

  Future<String?> pauseRecording() async {
    try {
      final recorder = _ensureRecorder();
      if (recorder == null) {
        return '录音组件不可用';
      }
      await recorder.pause();
      await _stopRecordingTimer();
      state = state.copyWith(recordingPhase: RecordingPhase.paused);
      return null;
    } catch (_) {
      return '暂停录音失败';
    }
  }

  Future<String?> resumeRecording() async {
    try {
      final recorder = _ensureRecorder();
      if (recorder == null) {
        return '录音组件不可用';
      }
      await recorder.resume();
      _startRecordingTimer();
      state = state.copyWith(recordingPhase: RecordingPhase.recording);
      return null;
    } catch (_) {
      return '继续录音失败';
    }
  }

  Future<String?> finishRecording() async {
    if (state.elapsedMs < 5000) {
      return '录制时长不能低于 5 秒';
    }
    try {
      final recorder = _ensureRecorder();
      if (recorder == null) {
        return '录音组件不可用';
      }
      final source = await recorder.stop();
      await _stopRecordingTimer();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      final resolvedSource = source ?? _currentRecordingSource;
      if (resolvedSource == null || resolvedSource.isEmpty) {
        return '录音文件生成失败，请重新录制';
      }
      final bytes = await loadRecordedBytes(resolvedSource);
      final durationMs = state.elapsedMs;
      final durationLabel = _formatDurationLabel(durationMs);
      const defaultName = '新录音';
      final draft = RecordingEntry(
        id: -1,
        categoryId: state.selectedSaveCategoryId > 0
            ? state.selectedSaveCategoryId
            : state.selectedCategoryId,
        name: state.pendingTitle.isEmpty ? defaultName : state.pendingTitle,
        url: resolvedSource,
        durationLabel: durationLabel,
        waveform: state.liveWaveform.isEmpty
            ? _fallbackWaveform(resolvedSource.hashCode)
            : state.liveWaveform,
        payload: <String, dynamic>{
          'name': state.pendingTitle.isEmpty ? defaultName : state.pendingTitle,
          'duration': durationLabel,
          'url': resolvedSource,
        },
        isLocalDraft: true,
      );
      state = state.copyWith(
        viewMode: RecordingViewMode.preview,
        recordingPhase: RecordingPhase.idle,
        previewItem: draft,
        previewSource: resolvedSource,
        previewDurationMs: durationMs,
        previewPositionMs: 0,
        previewPlaying: false,
        previewPlaybackRate: 1,
        recordedBytes: bytes,
        showSaveDialog: true,
        selectedSaveCategoryId: draft.categoryId,
        pendingTitle: draft.name == defaultName
            ? '录音作品${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}'
            : draft.name,
      );
      return null;
    } catch (_) {
      return '结束录音失败，请重试';
    }
  }

  Future<void> openPreview(RecordingEntry item) async {
    await _stopPreviewPlayback();
    _openedPreviewSource = null;
    state = state.copyWith(
      viewMode: RecordingViewMode.preview,
      previewItem: item,
      previewSource: _resolveMediaUrl(item.url),
      previewDurationMs: _parseDuration(item.durationLabel),
      previewPositionMs: 0,
      previewPlaying: false,
      previewPlaybackRate: 1,
      previewCollected: false,
      clearRecordedBytes: true,
      showSaveDialog: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
  }

  Future<void> togglePreviewPlayback() async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    final player = _ensurePlayer();
    if (player == null) {
      state = state.copyWith(errorMessage: '当前设备暂不支持音频预览');
      return;
    }
    if (state.previewPlaying) {
      await player.pause();
      return;
    }
    if (_openedPreviewSource == source) {
      await player.play();
    } else {
      await player.open(Media(source), play: true);
      _openedPreviewSource = source;
    }
    await player.setRate(state.previewPlaybackRate);
  }

  Future<void> seekPreviewBy(int deltaMs) async {
    final source = state.previewSource;
    if (source == null || source.isEmpty) {
      return;
    }
    final player = _ensurePlayer();
    if (player == null) {
      state = state.copyWith(errorMessage: '当前设备暂不支持音频预览');
      return;
    }
    final maxPosition = math.max(
      state.previewDurationMs,
      state.previewPositionMs,
    );
    final targetMs = (state.previewPositionMs + deltaMs).clamp(0, maxPosition);
    if (_openedPreviewSource != source) {
      await player.open(Media(source), play: false);
      _openedPreviewSource = source;
      await player.pause();
    }
    await player.seek(Duration(milliseconds: targetMs.toInt()));
    state = state.copyWith(previewPositionMs: targetMs.toInt());
  }

  Future<void> togglePlaybackRate() async {
    const options = <double>[1, 1.5, 2];
    final currentIndex = options.indexOf(state.previewPlaybackRate);
    final next = options[(currentIndex + 1) % options.length];
    state = state.copyWith(previewPlaybackRate: next);
    final player = _ensurePlayer();
    if (player != null) {
      await player.setRate(next);
    }
  }

  void toggleCollected() {
    state = state.copyWith(previewCollected: !state.previewCollected);
  }

  void reopenSaveDialog() {
    if (state.previewItem == null) {
      return;
    }
    state = state.copyWith(showSaveDialog: true);
  }

  void closeSaveDialog() {
    state = state.copyWith(showSaveDialog: false);
  }

  void updatePendingTitle(String value) {
    state = state.copyWith(pendingTitle: value);
  }

  void updateSelectedSaveCategory(int id) {
    state = state.copyWith(selectedSaveCategoryId: id);
  }

  void selectEffect(int index) {
    state = state.copyWith(selectedEffectIndex: index);
  }

  Future<String?> saveCurrentRecording() async {
    final bytes = state.recordedBytes;
    final categoryId = state.selectedSaveCategoryId;
    if (bytes == null || bytes.isEmpty) {
      return '录音文件为空，请重新录制';
    }
    if (categoryId <= 0) {
      return '请先选择录音所属分类';
    }

    final title = state.pendingTitle.trim();
    if (title.isEmpty) {
      return '请输入录音名称';
    }

    state = state.copyWith(busy: true, clearError: true);
    final uploadResponse = await _repository.uploadRecording(
      bytes: bytes,
      filename: 'recording_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    if (!uploadResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return _fallbackMessage(uploadResponse.msg, '上传录音失败');
    }
    // 上传成功后保存的是相对 `path`（例如 `app/upload/.../xxx.wav`），不再
    // 写入完整 url；后端在读取时再根据 path 拼出可访问地址。
    final filePath = parseUploadResult(uploadResponse.data).savable;
    if (filePath.isEmpty) {
      state = state.copyWith(busy: false);
      return '上传结果异常，未拿到录音地址';
    }

    final saveResponse = await _repository.saveRecording(
      categoryId: categoryId,
      name: title,
      duration: _formatDurationLabel(state.previewDurationMs),
      url: filePath,
    );
    state = state.copyWith(busy: false);
    if (!saveResponse.isSuccess) {
      return _fallbackMessage(saveResponse.msg, '保存录音失败');
    }

    await selectCategory(categoryId);
    return null;
  }

  Future<String?> deleteRecording(RecordingEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteRecording(item.id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除录音失败');
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

  Future<String?> openShare() async {
    final target = state.previewItem;
    if (target == null || target.isLocalDraft) {
      return '请先保存录音，再分享到班级';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _fallbackMessage(response.msg, '加载班级列表失败');
    }
    final classes = <RecordingShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(raw['id']);
      final name = raw['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
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

  Future<String?> sendShare() async {
    final target = state.previewItem;
    if (target == null || target.isLocalDraft) {
      return '请先保存录音，再分享到班级';
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return '请先选择要分享的班级';
    }
    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareRecording(
        classId: item.id,
        payload: target.payload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _fallbackMessage(response.msg, '分享失败');
      }
    }
    state = state.copyWith(
      busy: false,
      showShareDialog: false,
      shareClasses: const <RecordingShareClass>[],
    );
    return null;
  }

  void _startRecordingTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      state = state.copyWith(elapsedMs: state.elapsedMs + 100);
    });
  }

  Future<void> _stopRecordingTimer() async {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  void _appendAmplitude(Amplitude amplitude) {
    final normalized = ((amplitude.current + 60) / 60).clamp(0.08, 1.0);
    final next = <double>[...state.liveWaveform, normalized];
    if (next.length > 160) {
      next.removeRange(0, next.length - 160);
    }
    state = state.copyWith(liveWaveform: next);
  }

  Future<void> _stopPreviewPlayback() async {
    final player = _player;
    if (player == null) {
      return;
    }
    await player.pause();
    await player.seek(Duration.zero);
  }

  AudioRecorder? _ensureRecorder() {
    if (_recorder != null) {
      return _recorder;
    }
    if (_recorderUnavailable) {
      return null;
    }
    try {
      _recorder = AudioRecorder();
      return _recorder;
    } catch (_) {
      _recorderUnavailable = true;
      return null;
    }
  }

  Player? _ensurePlayer() {
    if (_player != null) {
      return _player;
    }
    if (_playerUnavailable) {
      return null;
    }
    try {
      final player = Player();
      _player = player;
      _bindPlayerStreams(player);
      return player;
    } catch (_) {
      _playerUnavailable = true;
      return null;
    }
  }

  void _bindPlayerStreams(Player player) {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _positionSub = player.stream.position.listen((position) {
      state = state.copyWith(previewPositionMs: position.inMilliseconds);
    });
    _playingSub = player.stream.playing.listen((playing) {
      state = state.copyWith(previewPlaying: playing);
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (duration == Duration.zero) {
        return;
      }
      state = state.copyWith(previewDurationMs: duration.inMilliseconds);
    });
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
      final rawUrl = raw['url']?.toString() ?? '';
      final url = _resolveMediaUrl(rawUrl);
      if (id <= 0 || name.isEmpty || url.isEmpty) {
        continue;
      }
      result.add(
        RecordingEntry(
          id: id,
          categoryId: categoryId,
          name: name,
          url: url,
          durationLabel: (raw['duration'] ?? '00:00.00').toString(),
          waveform: _fallbackWaveform(id),
          payload: Map<String, dynamic>.from(raw),
        ),
      );
    }
    return result;
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

  String _fallbackMessage(String raw, String fallback) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  @override
  void dispose() {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _recorder?.dispose();
    _player?.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

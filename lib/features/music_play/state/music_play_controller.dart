import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../music_companion/audio/music_companion_audio_engine.dart';
import '../data/music_play_repository.dart';
import 'music_play_state.dart';

final musicPlayControllerProvider = StateNotifierProvider.autoDispose
    .family<MusicPlayController, MusicPlayState, MusicPlayPageArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(musicPlayRepositoryProvider);
      final controller = MusicPlayController(
        repository: repository,
        args: args,
      );
      return controller;
    });

class MusicPlayController extends StateNotifier<MusicPlayState> {
  MusicPlayController({
    required this.repository,
    required MusicPlayPageArgs args,
  }) : _pianoEngine = MusicCompanionAudioEngine(),
       super(MusicPlayState.initial(args)) {
    unawaited(_initialize());
  }

  final MusicPlayRepository repository;
  final MusicCompanionAudioEngine _pianoEngine;
  final SoLoud _soLoud = SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  AudioData? _audioData;
  Timer? _audioTicker;
  Player? _webPlayer;
  StreamSubscription<Duration>? _webPositionSub;
  StreamSubscription<Duration>? _webDurationSub;
  StreamSubscription<bool>? _webPlayingSub;
  StreamSubscription<bool>? _webCompletedSub;
  bool _recordSaved = false;

  /// 已经 dispose 的标志位。
  ///
  /// `dispose()` 中第一时间置位，让任何还在 await 的异步链（[togglePlay]、
  /// [pressPianoKey]、[_openActiveTrack] 等）都能在拿到 `_soLoud.play(...)`
  /// 之前 short-circuit 退出，避免页面消失之后还冒出一声 "ding"。
  bool _disposed = false;

  /// `_openActiveTrack` 并发自增票据。
  ///
  /// iPad 上动作较快时，用户连点 1 次播放或快速翻页，会让两次
  /// `_openActiveTrack` 并发：两次都各自下载、各自 `_soLoud.play(...)`，
  /// 出现"两个音频同时在响"。这里用最经典的 ticket 方案：每次进入
  /// 自增 1，await 之后比对，落后的那次直接放弃（并清理已加载源）。
  int _openTicket = 0;

  Future<void> _initialize() async {
    unawaited(_warmUpPiano());
    try {
      await loadDetail(state.args.id, preserveShowAnswer: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '页面初始化失败，请稍后重试');
    }
  }

  Future<void> _warmUpPiano() async {
    try {
      await _pianoEngine.ensurePianoInitialized();
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: false);
    }
  }

  Future<void> loadDetail(int id, {required bool preserveShowAnswer}) async {
    if (id <= 0) {
      state = state.copyWith(loading: false, errorMessage: '教材参数无效，无法打开播放页');
      return;
    }

    state = state.copyWith(
      loading: true,
      errorMessage: '',
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: false,
      frequencyBands: const <double>[],
    );

    final responses = await Future.wait<ApiResponse>(<Future<ApiResponse>>[
      repository.getDetail(id),
      repository.getMyInfo(),
    ]);
    if (!mounted) {
      return;
    }

    final detailResponse = responses[0];
    final infoResponse = responses[1];
    if (!detailResponse.isSuccess ||
        detailResponse.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        errorMessage: detailResponse.msg.isEmpty
            ? '加载教材详情失败'
            : detailResponse.msg,
      );
      return;
    }

    final detailMap = detailResponse.data as Map<String, dynamic>;
    final detail = _parseDetail(detailMap);
    if (detail.vipOnly && !_hasVipAccess(infoResponse.data)) {
      state = state.copyWith(
        loading: false,
        errorMessage: '当前内容需要会员权限，请先开通或续费会员',
      );
      return;
    }

    final nextShowAnswer = preserveShowAnswer
        ? state.showAnswer
        : _defaultShowAnswer(state.args.type, detail);

    state = state.copyWith(
      loading: false,
      detail: detail,
      showAnswer: nextShowAnswer,
      activeImageIndex: 0,
      activeTrackIndex: 0,
      clearErrorMessage: true,
    );

    _recordSaved = false;
    await _openActiveTrack(play: false);
  }

  Future<void> togglePlay() async {
    if (_disposed) return;
    final track = state.activeTrack;
    if (track == null) {
      return;
    }

    if (kIsWeb) {
      final player = _ensureWebPlayer();
      if (_webPlayer == null || state.duration == Duration.zero) {
        await _openActiveTrack(play: true);
        return;
      }
      if (state.isPlaying) {
        await player.pause();
      } else {
        await player.play();
      }
      return;
    }

    if (_source == null) {
      await _openActiveTrack(play: true);
      return;
    }

    final handle = _handle;
    if (state.isPlaying) {
      if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
        _soLoud.setPause(handle, true);
      }
      state = state.copyWith(
        isPlaying: false,
        frequencyBands: const <double>[],
      );
    } else {
      if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
        _soLoud.setPause(handle, false);
        state = state.copyWith(isPlaying: true);
      } else {
        _startHandle();
      }
    }
  }

  Future<void> previous() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(-1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    final previousIndex = state.activeTrackIndex <= 0
        ? detail.tracks.length - 1
        : state.activeTrackIndex - 1;
    state = state.copyWith(
      activeTrackIndex: previousIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> next() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    final nextIndex = state.activeTrackIndex >= detail.tracks.length - 1
        ? 0
        : state.activeTrackIndex + 1;
    state = state.copyWith(
      activeTrackIndex: nextIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final nextSpeed = speed.clamp(0.5, 2.0);
    if (kIsWeb) {
      await _ensureWebPlayer().setRate(nextSpeed);
      if (!mounted) {
        return;
      }
      state = state.copyWith(speed: nextSpeed);
      return;
    }

    final handle = _handle;
    if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
      _soLoud.setRelativePlaySpeed(handle, nextSpeed);
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(speed: nextSpeed);
  }

  Future<void> seek(Duration position) async {
    final max = state.duration;
    final safe = max == Duration.zero
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
          );
    if (kIsWeb) {
      await _ensureWebPlayer().seek(safe);
      if (!mounted) {
        return;
      }
      state = state.copyWith(position: safe);
      return;
    }

    final handle = _handle;
    if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
      _soLoud.seek(handle, safe);
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(position: safe);
  }

  Future<void> toggleFavorite() async {
    final detail = state.detail;
    if (detail == null) {
      return;
    }
    final nextFavorite = !detail.favorite;
    final response = await repository.setFavorite(
      targetId: detail.id,
      type: detail.type,
      favorite: nextFavorite,
    );
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        errorMessage: response.msg.isEmpty ? '收藏状态更新失败' : response.msg,
      );
      return;
    }
    state = state.copyWith(
      detail: MusicPlayDetail(
        id: detail.id,
        type: detail.type,
        title: detail.title,
        subtitle: detail.subtitle,
        coverUrl: detail.coverUrl,
        favorite: nextFavorite,
        vipOnly: detail.vipOnly,
        questionImages: detail.questionImages,
        answerImages: detail.answerImages,
        tracks: detail.tracks,
        longTextHtml: detail.longTextHtml,
      ),
    );
  }

  void setShowAnswer(bool value) {
    if (value == state.showAnswer) {
      return;
    }
    state = state.copyWith(showAnswer: value, activeImageIndex: 0);
  }

  void setImageIndex(int index) {
    final images = state.visibleImages;
    if (images.isEmpty) {
      return;
    }
    final safe = index.clamp(0, images.length - 1);
    state = state.copyWith(activeImageIndex: safe);
  }

  Future<void> pressPianoKey(String note) async {
    if (_disposed) return;
    final active = Set<String>.from(state.activePianoNotes)..add(note);
    state = state.copyWith(activePianoNotes: active);
    await _pianoEngine.ensurePianoInitialized();
    if (!mounted || _disposed) {
      return;
    }
    await _pianoEngine.activateByUserGesture();
    if (!mounted || _disposed) {
      return;
    }
    if (!state.ready) {
      state = state.copyWith(ready: true);
    }
    await _pianoEngine.playNote(note);
  }

  void releasePianoKey(String note) {
    final active = Set<String>.from(state.activePianoNotes)..remove(note);
    state = state.copyWith(activePianoNotes: active);
  }

  void clearError() {
    if (state.errorMessage.isEmpty) {
      return;
    }
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> openShareDialog() async {
    state = state.copyWith(
      shareDialogVisible: true,
      classLoading: state.classList.isEmpty,
      clearErrorMessage: true,
    );
    final response = await repository.getClassList();
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        classLoading: false,
        errorMessage: response.msg.isEmpty ? '获取班级群失败' : response.msg,
      );
      return;
    }
    final raw = response.data;
    final list = <MusicPlayShareClass>[];
    if (raw is List) {
      for (final node in raw) {
        if (node is Map) {
          list.add(MusicPlayShareClass.fromJson(node));
        }
      }
    }
    state = state.copyWith(classList: list, classLoading: false);
  }

  void closeShareDialog() {
    state = state.copyWith(shareDialogVisible: false);
  }

  void toggleClass(String classId) {
    state = state.copyWith(
      classList: <MusicPlayShareClass>[
        for (final cls in state.classList)
          if (cls.id == classId) cls.copyWith(checked: !cls.checked) else cls,
      ],
    );
  }

  Future<bool> sendShare() async {
    final detail = state.detail;
    if (detail == null) {
      return false;
    }
    final selected = state.classList
        .where((cls) => cls.checked && cls.id.isNotEmpty)
        .toList();
    if (selected.isEmpty) {
      final hasChecked = state.classList.any((cls) => cls.checked);
      state = state.copyWith(
        errorMessage: hasChecked ? '所选班级数据异常，请刷新后重试' : '请先选择要分享的班级群',
      );
      return false;
    }

    state = state.copyWith(sending: true, clearErrorMessage: true);
    final content = jsonEncode(<String, dynamic>{
      'id': detail.id,
      'title': detail.title,
      'type': detail.type,
      'shortText3': detail.coverUrl,
      'subtitle': detail.subtitle,
    });

    for (final cls in selected) {
      final response = await repository.sendMsg(
        classId: cls.id,
        content: content,
      );
      if (!mounted) {
        return false;
      }
      if (!response.isSuccess) {
        state = state.copyWith(
          sending: false,
          errorMessage: response.msg.isEmpty ? '发送失败' : response.msg,
        );
        return false;
      }
    }

    state = state.copyWith(
      sending: false,
      shareDialogVisible: false,
      errorMessage: '消息已成功发送',
    );
    return true;
  }

  Future<void> _switchLesson(int delta) async {
    final ids = state.args.allLessonIds;
    if (ids.isEmpty) {
      return;
    }
    final currentIndex = ids.indexOf(state.args.id);
    if (currentIndex == -1) {
      return;
    }
    final nextIndex = (currentIndex + delta) % ids.length;
    final safeIndex = nextIndex < 0 ? ids.length - 1 : nextIndex;
    final nextId = ids[safeIndex];
    final nextArgs = MusicPlayPageArgs(
      id: nextId,
      type: state.args.type,
      allLessonIds: ids,
    );
    state = state.copyWith(args: nextArgs);
    await loadDetail(nextId, preserveShowAnswer: false);
  }

  Future<void> _openActiveTrack({required bool play}) async {
    final track = state.activeTrack;
    if (track == null || track.url.isEmpty) {
      return;
    }

    // 每次进入即抢占 ticket；之后任何一个 await 之后都比一下当前 ticket，
    // 不一致就当成"自己已被新一次 open 取代"处理。
    final ticket = ++_openTicket;
    bool isStale() => _disposed || ticket != _openTicket;

    try {
      if (kIsWeb) {
        if (isStale()) return;
        await _openWebTrack(track.url, play: play);
        return;
      }
      await _releaseCurrentSource();
      if (isStale()) return;
      final source = await _loadAudioSource(track.url);
      if (isStale()) {
        // 自己已经过期：把多下载/loadMem 出来的 source 处理掉，避免内存泄漏。
        try {
          await _soLoud.disposeSource(source);
        } catch (_) {}
        return;
      }
      _source = source;
      final duration = _soLoud.getLength(source);
      if (mounted && !_disposed) {
        state = state.copyWith(duration: duration);
      }
      if (play && !isStale()) {
        _startHandle();
      }
    } catch (error) {
      if (isStale()) return;
      debugPrint('MusicPlay audio load failed: $error');
      state = state.copyWith(errorMessage: '音频加载失败，请稍后重试');
    }
  }

  Future<void> _openWebTrack(String url, {required bool play}) async {
    final player = _ensureWebPlayer();
    await player.open(Media(url), play: play);
    await player.setRate(state.speed);
  }

  Player _ensureWebPlayer() {
    final current = _webPlayer;
    if (current != null) {
      return current;
    }
    final player = Player();
    _webPlayer = player;
    _bindWebPlayerStreams(player);
    return player;
  }

  void _bindWebPlayerStreams(Player player) {
    _webPositionSub?.cancel();
    _webDurationSub?.cancel();
    _webPlayingSub?.cancel();
    _webCompletedSub?.cancel();

    _webPositionSub = player.stream.position.listen((position) {
      if (mounted) {
        state = state.copyWith(position: position);
      }
    });
    _webDurationSub = player.stream.duration.listen((duration) {
      if (mounted) {
        state = state.copyWith(duration: duration);
      }
    });
    _webPlayingSub = player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(
          isPlaying: playing,
          frequencyBands: const <double>[],
        );
      }
    });
    _webCompletedSub = player.stream.completed.listen((completed) async {
      if (completed && mounted) {
        await _handleTrackCompleted();
      }
    });
  }

  Future<AudioSource> _loadAudioSource(String url) async {
    debugPrint('MusicPlay audio request: $url');
    final bytes = await repository.downloadAudio(url);
    await _ensureAudioEngine();
    return _soLoud.loadMem(
      _audioFileNameFromUrl(url),
      bytes,
      mode: LoadMode.memory,
    );
  }

  String _audioFileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final name = uri == null || uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last;
    if (name.contains('.') && !name.endsWith('.')) {
      return name;
    }
    return 'music_play_audio.mp3';
  }

  Future<void> _ensureAudioEngine() async {
    if (!_soLoud.isInitialized) {
      await _soLoud.init(bufferSize: 1024, channels: Channels.mono);
    }
    _soLoud.setVisualizationEnabled(true);
    _soLoud.setFftSmoothing(0.90);
    _audioData ??= AudioData(GetSamplesKind.linear);
    _startAudioTicker();
  }

  void _startHandle() {
    if (_disposed) return;
    final source = _source;
    if (source == null) {
      return;
    }
    // 防御：若上一个 handle 还活着，先停掉它，避免同一个 source 被叠播两次。
    final prev = _handle;
    if (prev != null && _soLoud.getIsValidVoiceHandle(prev)) {
      try {
        unawaited(_soLoud.stop(prev));
      } catch (_) {}
    }
    final handle = _soLoud.play(source, paused: false);
    _handle = handle;
    _soLoud.setRelativePlaySpeed(handle, state.speed);
    if (state.position > Duration.zero) {
      _soLoud.seek(handle, state.position);
    }
    if (mounted && !_disposed) {
      state = state.copyWith(isPlaying: true);
    }
  }

  void _startAudioTicker() {
    if (_audioTicker != null) {
      return;
    }
    _audioTicker = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (!mounted || _disposed) {
        return;
      }
      final handle = _handle;
      final handleIsValid =
          handle != null && _soLoud.getIsValidVoiceHandle(handle);
      final playing = handleIsValid && !_soLoud.getPause(handle);
      final nextPosition = handleIsValid
          ? _soLoud.getPosition(handle)
          : state.position;
      final bands = playing ? _readFrequencyBands() : const <double>[];

      state = state.copyWith(
        isPlaying: playing,
        position: nextPosition,
        frequencyBands: bands,
      );

      if (handleIsValid ||
          state.duration == Duration.zero ||
          nextPosition < state.duration - const Duration(milliseconds: 180)) {
        return;
      }
      unawaited(_handleTrackCompleted());
    });
  }

  List<double> _readFrequencyBands() {
    final audioData = _audioData;
    if (audioData == null) {
      return const <double>[];
    }
    try {
      audioData.updateSamples();
      final samples = audioData.getAudioData(alwaysReturnData: false);
      if (samples.length < 256) {
        return const <double>[];
      }
      return _compressFft(samples.sublist(0, 256));
    } catch (_) {
      return const <double>[];
    }
  }

  List<double> _compressFft(Float32List fft) {
    const bands = 46;
    final result = List<double>.filled(bands, 0);
    for (var i = 0; i < bands; i++) {
      final start = math.pow(i / bands, 1.55) * (fft.length - 1);
      final end = math.pow((i + 1) / bands, 1.55) * (fft.length - 1);
      final from = start.floor().clamp(0, fft.length - 1);
      final to = math.max(from + 1, end.ceil().clamp(0, fft.length));
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += fft[j].abs();
      }
      final average = sum / (to - from);
      result[i] = math.pow((average * 7.5).clamp(0.0, 1.0), 0.55) as double;
    }
    return result;
  }

  Future<void> _releaseCurrentSource() async {
    final handle = _handle;
    if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
      await _soLoud.stop(handle);
    }
    _handle = null;

    final source = _source;
    if (source != null) {
      await _soLoud.disposeSource(source);
    }
    _source = null;
  }

  Future<void> _handleTrackCompleted() async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null) {
      return;
    }

    if (!_recordSaved && (state.args.type == 3 || detail.type == 1)) {
      _recordSaved = true;
      unawaited(repository.saveStudyRecord(detail.id));
    }

    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(1);
      return;
    }

    if (detail.tracks.length > 1) {
      await next();
      return;
    }

    final handle = _handle;
    if (handle != null && _soLoud.getIsValidVoiceHandle(handle)) {
      _soLoud.seek(handle, Duration.zero);
      _soLoud.setPause(handle, true);
    }
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
      frequencyBands: const <double>[],
    );
    if (kIsWeb) {
      final player = _webPlayer;
      if (player != null) {
        await player.seek(Duration.zero);
        await player.pause();
      }
    }
  }

  bool _hasVipAccess(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }
    // myInfo 接口返回结构：{ user: { vipExpireDate, ... }, ... }
    final user = data['user'];
    final source = user is Map<String, dynamic> ? user : data;
    final raw = source['vipExpireDate']?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return false;
    }
    final expire = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (expire == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDate = DateTime(expire.year, expire.month, expire.day);
    return !vipDate.isBefore(today);
  }

  MusicPlayDetail _parseDetail(Map<String, dynamic> raw) {
    final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
    final type = int.tryParse(raw['type']?.toString() ?? '') ?? 0;
    final title = raw['title']?.toString().trim().isNotEmpty == true
        ? raw['title'].toString().trim()
        : '未命名教材';
    final coverUrl = _resolveMediaUrl(
      raw['img']?.toString() ??
          raw['cover']?.toString() ??
          raw['icon']?.toString() ??
          '',
    );

    return MusicPlayDetail(
      id: id,
      type: type,
      title: title,
      subtitle:
          raw['shortText1']?.toString() ?? raw['shortText2']?.toString() ?? '',
      coverUrl: coverUrl,
      favorite:
          raw['isFavorite'] == true ||
          raw['isFavorite']?.toString() == '1' ||
          raw['favorite']?.toString() == '1',
      vipOnly: raw['vip']?.toString() == '1',
      questionImages: _parseImageList(raw['img2']),
      answerImages: _parseImageList(raw['img1']),
      tracks: _parseTracks(raw['file1']),
      longTextHtml: raw['longText1']?.toString() ?? '',
    );
  }

  List<MusicPlayTrack> _parseTracks(dynamic raw) {
    final values = _normalizeToList(raw);
    if (values.isEmpty) {
      final fallbackUrl = _extractUrl(raw);
      return fallbackUrl.isEmpty
          ? const <MusicPlayTrack>[]
          : <MusicPlayTrack>[MusicPlayTrack(url: fallbackUrl, title: '主音频')];
    }

    final tracks = <MusicPlayTrack>[];
    for (var i = 0; i < values.length; i++) {
      final entry = values[i];
      final url = _extractUrl(entry);
      if (url.isEmpty) continue;
      final title = _extractTitle(entry);
      tracks.add(
        MusicPlayTrack(
          url: url,
          title: (title == null || title.isEmpty) ? '音频 ${i + 1}' : title,
        ),
      );
    }
    return tracks;
  }

  List<String> _parseImageList(dynamic raw) {
    final values = _normalizeToList(raw);
    final result = <String>[];
    for (final entry in values) {
      final url = _extractUrl(entry);
      if (url.isNotEmpty) {
        result.add(url);
      }
    }
    return result;
  }

  /// 解析 `filename` 字段（用于音轨标题），与 [_extractUrl] 对应。
  String? _extractTitle(dynamic entry) {
    if (entry is Map) {
      final raw = entry['filename']?.toString();
      return raw?.split('.').first.trim();
    }
    return null;
  }

  /// 从一项资源中提取一个完整的可访问 URL。
  ///
  /// 兼容三类后端返回：
  ///  - 标准 JSON：`{"url":"https://...","path":"app/upload/..."}`
  ///  - 后端 `Map.toString()` 序列化（key/value 都没有引号）：
  ///    `{path: app/upload/..., url: https://...}`
  ///  - 纯字符串（绝对 URL 或相对 path）。
  ///
  /// 优先取已经带域名的 `url`，否则把 `path` 等字段交给 [MediaUrl.resolve]
  /// 拼接 fileServerUrl，避免在域名后再拼一段 Map 调试字符串。
  String _extractUrl(dynamic entry) {
    if (entry == null) return '';

    if (entry is Map) {
      final url = (entry['url'] ?? entry['fileUrl'])?.toString().trim() ?? '';
      if (url.isNotEmpty) return _resolveMediaUrl(url);
      final path =
          (entry['path'] ?? entry['img'] ?? entry['filePath'])
              ?.toString()
              .trim() ??
          '';
      if (path.isNotEmpty) return _resolveMediaUrl(path);
      return '';
    }

    final text = entry.toString().trim();
    if (text.isEmpty) return '';

    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return _extractUrl(decoded);
        if (decoded is List && decoded.isNotEmpty) {
          return _extractUrl(decoded.first);
        }
      } catch (_) {
        // 落到下面的 Dart 风格解析。
      }
    }

    if (text.startsWith('{') && text.endsWith('}')) {
      final urlMatch = RegExp(r'url:\s*([^,}\s][^,}]*)').firstMatch(text);
      if (urlMatch != null) {
        return _resolveMediaUrl(urlMatch.group(1)!.trim());
      }
      final pathMatch = RegExp(r'path:\s*([^,}\s][^,}]*)').firstMatch(text);
      if (pathMatch != null) {
        return _resolveMediaUrl(pathMatch.group(1)!.trim());
      }
      return '';
    }

    return _resolveMediaUrl(text);
  }

  List<dynamic> _normalizeToList(dynamic raw) {
    if (raw == null) {
      return const <dynamic>[];
    }
    final decoded = _decodeJsonLike(raw);
    if (decoded is List) {
      if (decoded.length == 1 && decoded.first is List) {
        return List<dynamic>.from(decoded.first as List);
      }
      return List<dynamic>.from(decoded);
    }
    if (decoded is Map) {
      return <dynamic>[decoded];
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return const <dynamic>[];
    }
    return <dynamic>[raw];
  }

  dynamic _decodeJsonLike(dynamic value) {
    if (value is List || value is Map) {
      return value;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return value;
    }
    if (!(text.startsWith('{') || text.startsWith('['))) {
      return value;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return value;
    }
  }

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  bool _defaultShowAnswer(int? pageType, MusicPlayDetail detail) {
    if (pageType == 3) {
      return true;
    }
    if (pageType == 2) {
      return detail.type == 4 || detail.answerImages.isNotEmpty;
    }
    return detail.answerImages.isNotEmpty;
  }

  @override
  void dispose() {
    // 关键：以下所有"同步停声"的动作必须在 super.dispose() 之前完成，
    // 并且要在任何 await/unawaited 之前先把 _disposed 置位，让其它异步
    // 链路（包括 piano 的 playNote）能立刻 short-circuit。
    _disposed = true;
    _audioTicker?.cancel();
    _audioTicker = null;
    _audioData?.dispose();
    _audioData = null;

    // 同步停掉主音频 handle。`_soLoud.stop` 虽然返回 Future，但底层在被
    // 调用瞬间就把 stop 命令推给 audio 线程，几乎是即刻静音；不 await，
    // 避免 dispose 阻塞，但比 unawaited(_releaseCurrentSource()) 更早静音。
    final handle = _handle;
    if (handle != null) {
      try {
        if (_soLoud.getIsValidVoiceHandle(handle)) {
          unawaited(_soLoud.stop(handle));
        }
      } catch (_) {}
    }
    _handle = null;

    final source = _source;
    if (source != null) {
      try {
        unawaited(_soLoud.disposeSource(source));
      } catch (_) {}
    }
    _source = null;

    _webPositionSub?.cancel();
    _webDurationSub?.cancel();
    _webPlayingSub?.cancel();
    _webCompletedSub?.cancel();
    final webPlayer = _webPlayer;
    if (webPlayer != null) {
      try {
        unawaited(webPlayer.pause());
      } catch (_) {}
      unawaited(webPlayer.dispose());
    }

    // 同步把所有钢琴声 stop 掉，再 unawaited dispose。前者立刻静音，
    // 后者负责释放资源；引擎内部的 _disposed 也已经在 .dispose() 调用瞬间
    // 同步置位（见 MusicCompanionAudioEngine.dispose 头部），因此就算
    // pressPianoKey 的异步链此时还在挂起，最终 _soLoud.play 也不会被调到。
    _pianoEngine.stopAllImmediately();
    unawaited(_pianoEngine.dispose());
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// 主音频播放器：使用 `media_kit` 在 native（iOS/Android/Desktop）
  /// 与 Web 上提供"倍速 + 升降调"双独立旋钮：
  /// - [Player.setRate] —— 变速保音高（mpv 默认开启 audio-pitch-correction）；
  /// - [Player.setPitch] —— 独立的半音变调（speed 不动）。
  /// 钢琴弹奏仍然走 [MusicCompanionAudioEngine]（基于 SoLoud），与此处互不影响。
  Player? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  bool _recordSaved = false;

  /// 已经 dispose 的标志位。
  ///
  /// `dispose()` 中第一时间置位，让任何还在 await 的异步链（[togglePlay]、
  /// [pressPianoKey]、[_openActiveTrack] 等）都能在拿到 `player.open(...)`
  /// 之前 short-circuit 退出，避免页面消失之后还冒出一声 "ding"。
  bool _disposed = false;

  /// `_openActiveTrack` 并发自增票据。
  ///
  /// iPad 上动作较快时，用户连点 1 次播放或快速翻页，会让两次
  /// `_openActiveTrack` 并发：两次都各自调 `player.open(...)`，
  /// 出现"两个音频同时在响"。这里用最经典的 ticket 方案：每次进入
  /// 自增 1，await 之后比对，落后的那次直接放弃。
  int _openTicket = 0;

  /// 把半音数转为 [Player.setPitch] 接受的频率倍率（2^(n/12)）。
  static double _pitchRatio(int semitones) =>
      math.pow(2, semitones / 12.0).toDouble();

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

    final player = _player;
    if (player == null || state.duration == Duration.zero) {
      await _openActiveTrack(play: true);
      return;
    }
    if (state.isPlaying) {
      await player.pause();
    } else {
      await player.play();
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
    final player = _player;
    if (player != null) {
      try {
        // mpv 默认 audio-pitch-correction=yes：变速不变调。
        // Web 端 HTML5 audio 的浏览器默认也保留音高。
        await player.setRate(nextSpeed);
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(speed: nextSpeed);
  }

  /// 独立的"升降调"控制（半音）。与 [setPlaybackSpeed] 完全解耦：
  /// 内部走 [Player.setPitch]，半音 N → 频率倍率 2^(N/12)。
  Future<void> setPitchSemitones(int semitones) async {
    final next = semitones.clamp(-12, 12);
    final player = _player;
    if (player != null) {
      try {
        await player.setPitch(_pitchRatio(next));
      } catch (_) {
        // Web/部分平台对 setPitch 不一定支持，静默吞掉，
        // UI 层依旧按照所选半音数显示。
      }
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(pitchSemitones: next);
  }

  /// 切换"循环模式"：顺序 → 单曲循环 → 随机循环 → 顺序。
  /// 仅在多曲目场景下有意义，单曲目时也允许调用但不会影响实际行为。
  void togglePlayMode() {
    final next = switch (state.playMode) {
      MusicPlayMode.sequence => MusicPlayMode.single,
      MusicPlayMode.single => MusicPlayMode.shuffle,
      MusicPlayMode.shuffle => MusicPlayMode.sequence,
    };
    state = state.copyWith(playMode: next);
  }

  /// 直接跳到曲目列表中的指定索引并播放。
  /// 用户在"播放列表"菜单中点击某一项时调用；与 [previous] / [next] 共享
  /// 同一套 ticket 化的 `_openActiveTrack`，避免连点产生双声。
  Future<void> selectTrack(int index) async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null || detail.tracks.isEmpty) {
      return;
    }
    final safe = index.clamp(0, detail.tracks.length - 1);
    if (safe == state.activeTrackIndex) {
      // 同一首：从头重播（同时承担"单曲循环"自动续播的语义）。
      await seek(Duration.zero);
      final player = _player;
      if (player != null) {
        try {
          await player.play();
        } catch (_) {}
      }
      return;
    }
    state = state.copyWith(
      activeTrackIndex: safe,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> seek(Duration position) async {
    final max = state.duration;
    final safe = max == Duration.zero
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
          );
    final player = _player;
    if (player != null) {
      try {
        await player.seek(safe);
      } catch (_) {}
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
      if (isStale()) return;
      final player = _ensurePlayer();
      debugPrint('MusicPlay audio open: ${track.url}');
      await player.open(Media(track.url), play: play);
      if (isStale()) return;
      // 应用当前的速度/音高（用户在切歌前可能已经调过）。
      try {
        await player.setRate(state.speed);
      } catch (_) {}
      try {
        await player.setPitch(_pitchRatio(state.pitchSemitones));
      } catch (_) {}
    } catch (error) {
      if (isStale()) return;
      debugPrint('MusicPlay audio load failed: $error');
      if (mounted) {
        state = state.copyWith(errorMessage: '音频加载失败，请稍后重试');
      }
    }
  }

  Player _ensurePlayer() {
    final current = _player;
    if (current != null) {
      return current;
    }
    // 关键：必须把 PlayerConfiguration.pitch 打开，
    // 否则 [Player.setPitch] 会抛 `ArgumentError('PlayerConfiguration.pitch is false')`，
    // 导致升降调在 native 端无效（UI 变了但声音不变）。
    // 该选项会让 mpv 关闭 audio-pitch-correction 并改用 scaletempo 滤镜，
    // 实现"独立倍速 + 独立音高"。Web 端 setPitch 仍然不支持，会被 try/catch 吞掉。
    final player = Player(
      configuration: const PlayerConfiguration(pitch: true),
    );
    _player = player;
    _bindPlayerStreams(player);
    return player;
  }

  void _bindPlayerStreams(Player player) {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();

    _positionSub = player.stream.position.listen((position) {
      if (mounted) {
        state = state.copyWith(position: position);
      }
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (mounted) {
        state = state.copyWith(duration: duration);
      }
    });
    _playingSub = player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    });
    _completedSub = player.stream.completed.listen((completed) async {
      if (completed && mounted) {
        await _handleTrackCompleted();
      }
    });
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
      // 多曲目：完全对齐 1.0 中 `sxType` 的三段语义。
      switch (state.playMode) {
        case MusicPlayMode.single:
          await selectTrack(state.activeTrackIndex);
          return;
        case MusicPlayMode.shuffle:
          final length = detail.tracks.length;
          int target = state.activeTrackIndex;
          if (length > 1) {
            final random = math.Random();
            do {
              target = random.nextInt(length);
            } while (target == state.activeTrackIndex);
          }
          await selectTrack(target);
          return;
        case MusicPlayMode.sequence:
          await next();
          return;
      }
    }

    final player = _player;
    if (player != null) {
      try {
        await player.seek(Duration.zero);
        await player.pause();
      } catch (_) {}
    }
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
    );
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
    // 试题（answerEnd2）模块明确要求进入时默认"关闭状态"，
    // 即先展示题面，由用户主动切到答案。
    if (state.args.closedByDefault) {
      return false;
    }
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
    // 关键：所有"同步停声"动作必须在 super.dispose() 之前完成，
    // 并先把 _disposed 置位，让任何还在 await 的异步链（[togglePlay]、
    // [pressPianoKey]、[_openActiveTrack] 等）都能 short-circuit。
    _disposed = true;

    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();

    final player = _player;
    if (player != null) {
      try {
        unawaited(player.pause());
      } catch (_) {}
      try {
        unawaited(player.dispose());
      } catch (_) {}
    }
    _player = null;

    // 同步把所有钢琴声 stop 掉，再 unawaited dispose。前者立刻静音，
    // 后者负责释放资源；引擎内部的 _disposed 也已经在 .dispose() 调用瞬间
    // 同步置位（见 MusicCompanionAudioEngine.dispose 头部），因此就算
    // pressPianoKey 的异步链此时还在挂起，最终 SoLoud.play 也不会被调到。
    _pianoEngine.stopAllImmediately();
    unawaited(_pianoEngine.dispose());
    super.dispose();
  }
}

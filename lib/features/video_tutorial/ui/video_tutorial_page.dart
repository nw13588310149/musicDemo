// ─────────────────────────────────────────────────────────────────────────────
// video_tutorial_page.dart
// 视频中心 - 腾讯视频交互 + 全屏修复 + 画中画 2026-04-16
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/video_tutorial_controller.dart';
import '../state/video_tutorial_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A. 主页 — 视频列表
// ─────────────────────────────────────────────────────────────────────────────

class VideoTutorialV2Page extends ConsumerStatefulWidget {
  const VideoTutorialV2Page({super.key});

  @override
  ConsumerState<VideoTutorialV2Page> createState() =>
      _VideoTutorialV2PageState();
}

class _VideoTutorialV2PageState extends ConsumerState<VideoTutorialV2Page> {
  final ScrollController _scrollController = ScrollController();
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  int _bannerCount = 0;
  bool _isDetailOpening = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 360) {
      ref.read(videoTutorialControllerProvider.notifier).loadMore();
    }
  }

  void _syncBannerAutoPlay(int count) {
    if (_bannerCount == count) return;
    _bannerCount = count;
    _bannerIndex = 0;
    _bannerTimer?.cancel();
    if (count <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients || _bannerCount <= 1) return;
      _bannerIndex = (_bannerIndex + 1) % _bannerCount;
      _bannerController.animateToPage(
        _bannerIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      setState(() {});
    });
  }

  Future<void> _openVideoDetail(VideoListItem item) async {
    if (_isDetailOpening) return;
    _isDetailOpening = true;

    final notifier = ref.read(videoTutorialControllerProvider.notifier);
    final message = await notifier.openDetail(item);

    if (!mounted) {
      _isDetailOpening = false;
      return;
    }
    if (message != null && message.isNotEmpty) {
      _showSnackBar(message);
      _isDetailOpening = false;
      return;
    }

    final detail = ref.read(videoTutorialControllerProvider).detail;
    if (detail == null) {
      _isDetailOpening = false;
      return;
    }

    await Navigator.of(context, rootNavigator: true).push<void>(
      _VideoDetailRoute(detail: detail, resolveUrl: _resolveUrl),
    );

    _isDetailOpening = false;
    if (mounted) {
      ref.read(videoTutorialControllerProvider.notifier).closeDetail();
    }
  }

  void _showSnackBar(String msg) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _resolveUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == 'null') return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    if (v.startsWith('//')) return 'https:$v';
    final base = AppConstants.apiBaseUrl.endsWith('/')
        ? AppConstants.apiBaseUrl.substring(
            0,
            AppConstants.apiBaseUrl.length - 1,
          )
        : AppConstants.apiBaseUrl;
    return v.startsWith('/') ? '$base$v' : '$base/$v';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoTutorialControllerProvider);
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    _syncBannerAutoPlay(state.banners.length);

    return Container(
      padding: EdgeInsets.only(bottom: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          // ── 固定头部：分类 / Banner / 子分类（不随列表滚动）─────────────
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
            child: Column(
              children: [
                _VideoCategoryHeader(
                  scale: scale,
                  menus: state.menus,
                  selectedMenuId: state.selectedMenuId,
                  onSelectMenu: (id) => ref
                      .read(videoTutorialControllerProvider.notifier)
                      .selectMenu(id),
                ),
                SizedBox(height: ui(16)),
                _BannerAndLatestSection(
                  scale: scale,
                  banners: state.banners,
                  activeIndex: _bannerIndex,
                  pageController: _bannerController,
                  latestVideos: state.videoList.take(3).toList(),
                  resolveUrl: _resolveUrl,
                  onBannerChanged: (i) => setState(() => _bannerIndex = i),
                  onOpenVideo: _openVideoDetail,
                ),
                SizedBox(height: ui(16)),
                _SubCategoryBar(
                  scale: scale,
                  items: state.selectedMenu?.children ?? const [],
                  selectedId: state.selectedChildId,
                  onSelect: (id) => ref
                      .read(videoTutorialControllerProvider.notifier)
                      .selectChildMenu(id),
                ),
              ],
            ),
          ),
          // ── 视频列表区：仅此区域可滚动 ──────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(videoTutorialControllerProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (state.loading && state.videoList.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.videoList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          state.errorMessage.isEmpty
                              ? '暂无视频数据'
                              : state.errorMessage,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: const Color(0xFFB6B5BB),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(ui(16), 0, ui(16), ui(16)),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: ui(16),
                          crossAxisSpacing: ui(16),
                          childAspectRatio: 220 / 180,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _VideoGridCard(
                            scale: scale,
                            item: state.videoList[index],
                            resolveUrl: _resolveUrl,
                            onTap: () => _openVideoDetail(state.videoList[index]),
                          ),
                          childCount: state.videoList.length,
                        ),
                      ),
                    ),
                  if (state.loadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: ui(18)),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (!state.loadingMore &&
                      !state.hasMore &&
                      state.videoList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: ui(18)),
                        child: Center(
                          child: Text(
                            '没有更多了',
                            style: TextStyle(
                              fontSize: ui(12),
                              color: const Color(0xFFB6B5BB),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. 全局详情覆盖路由
// ─────────────────────────────────────────────────────────────────────────────

class _VideoDetailRoute extends PageRouteBuilder<void> {
  _VideoDetailRoute({
    required this.detail,
    required this.resolveUrl,
    this.handoffPlayer,
    this.handoffController,
  }) : super(
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondary) => _VideoDetailOverlay(
            detail: detail,
            resolveUrl: resolveUrl,
            animation: animation,
            handoffPlayer: handoffPlayer,
            handoffController: handoffController,
          ),
          transitionsBuilder: (context, animation, secondary, child) => child,
        );

  final VideoDetail detail;
  final String Function(String) resolveUrl;
  // 从画中画展开时，直接接管已有播放器，避免重新加载
  final Player? handoffPlayer;
  final VideoController? handoffController;
}

class _VideoDetailOverlay extends StatelessWidget {
  const _VideoDetailOverlay({
    required this.detail,
    required this.resolveUrl,
    required this.animation,
    this.handoffPlayer,
    this.handoffController,
  });

  final VideoDetail detail;
  final String Function(String) resolveUrl;
  final Animation<double> animation;
  final Player? handoffPlayer;
  final VideoController? handoffController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FadeTransition(
          opacity: animation,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFF3F2F3), width: 1),
                  ),
                ),
                child: Material(
                  elevation: 32,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  child: _VideoDetailSheet(
                    initialDetail: detail,
                    resolveUrl: resolveUrl,
                    handoffPlayer: handoffPlayer,
                    handoffController: handoffController,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C. 详情面板 — 管理播放器生命周期
// ─────────────────────────────────────────────────────────────────────────────

class _VideoDetailSheet extends ConsumerStatefulWidget {
  const _VideoDetailSheet({
    required this.initialDetail,
    required this.resolveUrl,
    this.handoffPlayer,
    this.handoffController,
  });

  final VideoDetail initialDetail;
  final String Function(String) resolveUrl;
  // 从画中画展开时传入已在播放的播放器，跳过重新加载
  final Player? handoffPlayer;
  final VideoController? handoffController;

  @override
  ConsumerState<_VideoDetailSheet> createState() => _VideoDetailSheetState();
}

class _VideoDetailSheetState extends ConsumerState<_VideoDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Player? _player;
  VideoController? _videoController;
  String _playingUrl = '';
  VideoDetail _currentDetail = const VideoDetail(
    id: '',
    name: '',
    url: '',
    coverImg: '',
    description: '',
    vip: 0,
    isFavorite: false,
    scoreImages: [],
    seriesVideoList: [],
    duration: '',
    playCount: 0,
  );
  bool _loadingSwitch = false;
  bool _pipTransferred = false; // 画中画时不 dispose 播放器

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentDetail = widget.initialDetail;
    if (widget.handoffPlayer != null && widget.handoffController != null) {
      // 从画中画展开：直接接管播放器，无需重新加载，视频从当前进度继续
      _player = widget.handoffPlayer;
      _videoController = widget.handoffController;
      _playingUrl = widget.resolveUrl(widget.initialDetail.url);
    } else {
      _prepareVideo(widget.initialDetail.url);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 若已转移给画中画，播放器生命周期由 _FloatingMiniPlayer 接管
    if (!_pipTransferred) {
      _player?.dispose();
    }
    super.dispose();
  }

  Future<void> _prepareVideo(String url) async {
    final resolved = widget.resolveUrl(url);
    if (resolved.isEmpty || resolved == _playingUrl) return;

    await _player?.dispose();
    _player = null;
    _videoController = null;
    _playingUrl = '';

    try {
      final player = Player();
      final ctrl = VideoController(player);
      await player.open(Media(resolved), play: true);
      if (mounted) {
        setState(() {
          _player = player;
          _videoController = ctrl;
          _playingUrl = resolved;
        });
      }
    } catch (_) {
      if (mounted) _showMsg('视频加载失败，请稍后重试');
    }
  }

  Future<void> _switchToVideo(VideoListItem item) async {
    if (_loadingSwitch) return;
    setState(() => _loadingSwitch = true);
    final msg = await ref
        .read(videoTutorialControllerProvider.notifier)
        .openDetail(item);
    if (!mounted) return;
    if (msg != null && msg.isNotEmpty) {
      _showMsg(msg);
      setState(() => _loadingSwitch = false);
      return;
    }
    final detail = ref.read(videoTutorialControllerProvider).detail;
    if (detail != null) {
      setState(() {
        _currentDetail = detail;
        _loadingSwitch = false;
      });
      await _prepareVideo(detail.url);
    } else {
      setState(() => _loadingSwitch = false);
    }
  }

  // ── 画中画：转移播放器所有权，显示悬浮窗 ──────────────────────────
  Future<void> _enterPip() async {
    final player = _player;
    final ctrl = _videoController;
    if (player == null || ctrl == null) return;

    // 先获取 overlay state（路由关闭后 context 失效）
    final overlayState = Overlay.of(context, rootOverlay: true);
    final title = _currentDetail.name;
    final detail = _currentDetail;
    final resolveUrl = widget.resolveUrl;

    // 标记已转移，dispose() 将跳过 player.dispose()
    _pipTransferred = true;

    // ① 先插入悬浮窗（Mini Player 的 Video widget 与主 Video widget 同时存在，
    //   保证 VideoController 的渲染纹理不会因主 Video 先卸载而重置）
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FloatingMiniPlayer(
        player: player,
        videoController: ctrl,
        title: title,
        onDismiss: () {
          entry.remove();
          entry.dispose();
          player.dispose();
        },
        onExpand: () {
          // 从画中画展开回详情面板
          entry.remove();
          entry.dispose();
          if (overlayState.context.mounted) {
            _openDetailFromPip(player, ctrl, detail, resolveUrl, overlayState);
          }
        },
      ),
    );
    overlayState.insert(entry);

    // ② 等一帧，让 Mini Player 的 Video widget 完成首次 layout & attach
    await Future.delayed(const Duration(milliseconds: 80));

    // ③ 关闭详情面板（主 Video widget 卸载，Mini Player 已接管渲染）
    if (mounted) Navigator.of(context).pop();
  }

  // 从画中画展开：重新打开详情路由，移交播放器所有权，视频从当前进度继续
  void _openDetailFromPip(
    Player player,
    VideoController ctrl,
    VideoDetail detail,
    String Function(String) resolveUrl,
    OverlayState overlayState,
  ) {
    Navigator.of(overlayState.context, rootNavigator: true).push<void>(
      _VideoDetailRoute(
        detail: detail,
        resolveUrl: resolveUrl,
        handoffPlayer: player,
        handoffController: ctrl,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final msg = await ref
        .read(videoTutorialControllerProvider.notifier)
        .toggleFavorite();
    if (!mounted) return;
    if (msg != null && msg.isNotEmpty) {
      _showMsg(msg);
    } else {
      final isFav =
          ref.read(videoTutorialControllerProvider).detail?.isFavorite ?? false;
      _showMsg(isFav ? '收藏成功' : '已取消收藏');
    }
  }

  Future<void> _showShareSheet() async {
    final notifier = ref.read(videoTutorialControllerProvider.notifier);
    final classes = await notifier.fetchShareClasses();
    if (!mounted) return;
    if (classes.isEmpty) {
      _showMsg('暂无可分享班级');
      return;
    }
    final selected = <int>{};
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ShareSheet(
        classes: classes,
        selected: selected,
        onSubmit: () async {
          final msg = await notifier.shareCurrentVideo(selected.toList());
          if (!ctx.mounted) return;
          if (msg != null && msg.isNotEmpty) {
            _showMsg(msg);
            return;
          }
          Navigator.of(ctx).pop();
          _showMsg('发送成功');
        },
      ),
    );
  }

  Future<void> _previewScoreImage(String url) async {
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              widget.resolveUrl(url),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('图片加载失败', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMsg(String msg) {
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final ctrlState = ref.watch(videoTutorialControllerProvider);
    final detail = ctrlState.detail ?? _currentDetail;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _player != null && _videoController != null
              ? _ProfessionalPlayer(
                  player: _player!,
                  videoController: _videoController!,
                  videoTitle: detail.name,
                  videoId: detail.id,
                  seriesVideos: detail.seriesVideoList,
                  onSwitchVideo: _switchToVideo,
                  onClose: () => Navigator.of(context).pop(),
                  onEnterPip: _enterPip,
                )
              : _PlayerPlaceholder(
                  coverUrl: widget.resolveUrl(detail.coverImg),
                  loading: ctrlState.detailLoading || _loadingSwitch,
                ),
        ),
        _DetailActionBar(
          isFavorite: detail.isFavorite,
          tabController: _tabController,
          onFavorite: _toggleFavorite,
          onShare: _showShareSheet,
        ),
        const Divider(height: 1, color: Color(0xFFF3F2F3)),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DetailInfoTab(
                detail: detail,
                resolveUrl: widget.resolveUrl,
                onOpenSeriesVideo: _switchToVideo,
              ),
              _ScoreTab(
                scoreImages: detail.scoreImages,
                resolveUrl: widget.resolveUrl,
                onPreviewImage: _previewScoreImage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// D. 专业播放器组件
// ─────────────────────────────────────────────────────────────────────────────

enum _GestureMode { none, seeking, volume, brightness }

class _ProfessionalPlayer extends StatefulWidget {
  const _ProfessionalPlayer({
    required this.player,
    required this.videoController,
    required this.videoTitle,
    required this.videoId,
    required this.seriesVideos,
    required this.onSwitchVideo,
    required this.onClose,
    required this.onEnterPip,
  });

  final Player player;
  final VideoController videoController;
  final String videoTitle;
  final String videoId;
  final List<VideoListItem> seriesVideos;
  final ValueChanged<VideoListItem> onSwitchVideo;
  final VoidCallback onClose;
  final VoidCallback onEnterPip;

  @override
  State<_ProfessionalPlayer> createState() => _ProfessionalPlayerState();
}

class _ProfessionalPlayerState extends State<_ProfessionalPlayer> {
  final List<StreamSubscription<Object?>> _subs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _volume = 100;
  double _rate = 1.0;
  bool _isCompleted = false;

  bool _showControls = true;
  Timer? _hideTimer;

  bool _isDraggingProgress = false;
  double? _dragProgressMs;

  bool _showSpeedPanel = false;

  bool _isLongPressSpeed = false;

  String? _tapSeekHint;
  Timer? _tapSeekHintTimer;
  double _lastTapX = 0;

  _GestureMode _activeGesture = _GestureMode.none;
  double _panStartX = 0;
  double _panStartY = 0;
  double _panStartVolume = 0;
  double _panStartBrightness = 0;
  Duration _panStartPosition = Duration.zero;
  double _gestureSeekPreviewMs = 0;

  double _brightnessOverlay = 0;

  int _autoplayCountdown = 0;
  Timer? _autoplayTimer;

  // 全屏退出后用于强制 Video widget 重新 mount，恢复渲染纹理
  int _videoRemountKey = 0;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    // 直接从 player.state 读取当前值，避免因流只推送新事件而错过已有状态
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _isPlaying = widget.player.state.playing;
    _isBuffering = widget.player.state.buffering;
    _volume = widget.player.state.volume;
    _rate = widget.player.state.rate;
    _subscribeToStreams(widget.player);
    _startAutoHide();
  }

  @override
  void didUpdateWidget(_ProfessionalPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
      _subscribeToStreams(widget.player);
      _autoplayTimer?.cancel();
      setState(() {
        _position = widget.player.state.position;
        _duration = widget.player.state.duration;
        _isPlaying = widget.player.state.playing;
        _isBuffering = widget.player.state.buffering;
        _volume = widget.player.state.volume;
        _rate = widget.player.state.rate;
        _isCompleted = false;
        _autoplayCountdown = 0;
      });
    }
  }

  void _subscribeToStreams(Player p) {
    _subs.add(p.stream.position.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subs.add(p.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    }));
    _subs.add(p.stream.playing.listen((v) {
      if (mounted) setState(() => _isPlaying = v);
    }));
    _subs.add(p.stream.buffering.listen((v) {
      if (mounted) setState(() => _isBuffering = v);
    }));
    _subs.add(p.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    }));
    _subs.add(p.stream.rate.listen((v) {
      if (mounted) setState(() => _rate = v);
    }));
    _subs.add(p.stream.completed.listen((v) {
      if (!mounted || !v) return;
      setState(() => _isCompleted = true);
      _startAutoplayCountdown();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _hideTimer?.cancel();
    _tapSeekHintTimer?.cancel();
    _autoplayTimer?.cancel();
    super.dispose();
  }

  void _startAutoHide() {
    _hideTimer?.cancel();
    if (!_showControls || _isDraggingProgress) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDraggingProgress && !_showSpeedPanel) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startAutoHide();
  }

  void _toggleControls() {
    if (_showSpeedPanel) {
      setState(() => _showSpeedPanel = false);
      _startAutoHide();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startAutoHide();
  }

  void _handleDoubleTap(double totalWidth) {
    final isLeft = _lastTapX < totalWidth / 2;
    final seconds = isLeft ? -10 : 10;
    final target = _position + Duration(seconds: seconds);
    final clamped = target.isNegative
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
            ? _duration
            : target);
    widget.player.seek(clamped);
    setState(() => _tapSeekHint = isLeft ? '← -10s' : '+10s →');
    _tapSeekHintTimer?.cancel();
    _tapSeekHintTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _tapSeekHint = null);
    });
    _showControlsTemporarily();
  }

  Future<void> _openFullscreen() async {
    // 进入/退出全屏均保持播放状态：记录当前是否正在播放
    final wasPlaying = widget.player.state.playing;

    setState(() {
      _showControls = false;
      _showSpeedPanel = false;
    });
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, animation, secondary) => _FullscreenPage(
          player: widget.player,
          videoController: widget.videoController,
          title: widget.videoTitle,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    // 全屏 Video widget 卸载后，渲染纹理已被释放；
    // 递增 key 强制主播放器的 Video widget 重新挂载，重新绑定纹理，消除黑屏。
    setState(() => _videoRemountKey++);
    // 纹理重绑定后恢复播放状态（重新挂载 Video widget 可能导致播放器暂停）
    if (wasPlaying && mounted) {
      // 等待下一帧确保 Video widget 完成重新挂载后再恢复播放
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.player.play();
      });
    }
    _showControlsTemporarily();
  }

  VideoListItem? get _nextVideo {
    final idx = widget.seriesVideos.indexWhere((v) => v.id == widget.videoId);
    if (idx < 0 || idx >= widget.seriesVideos.length - 1) return null;
    return widget.seriesVideos[idx + 1];
  }

  void _startAutoplayCountdown() {
    final next = _nextVideo;
    if (next == null) return;
    setState(() => _autoplayCountdown = 5);
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _autoplayCountdown--);
      if (_autoplayCountdown <= 0) {
        t.cancel();
        widget.onSwitchVideo(next);
      }
    });
  }

  void _cancelAutoplay() {
    _autoplayTimer?.cancel();
    setState(() => _autoplayCountdown = 0);
  }

  void _onPanStart(DragStartDetails d) {
    _panStartX = d.localPosition.dx;
    _panStartY = d.localPosition.dy;
    _panStartVolume = _volume;
    _panStartBrightness = _brightnessOverlay;
    _panStartPosition = _position;
    _activeGesture = _GestureMode.none;
    _hideTimer?.cancel();
  }

  void _onPanUpdate(DragUpdateDetails d, double w, double h) {
    final dx = d.localPosition.dx - _panStartX;
    final dy = d.localPosition.dy - _panStartY;

    if (_activeGesture == _GestureMode.none) {
      if (dx.abs() < 8 && dy.abs() < 8) return;
      _activeGesture = dx.abs() > dy.abs()
          ? _GestureMode.seeking
          : (_panStartX < w / 2
              ? _GestureMode.brightness
              : _GestureMode.volume);
    }

    switch (_activeGesture) {
      case _GestureMode.seeking:
        final delta = (dx / w * _duration.inMilliseconds)
            .clamp(-120000.0, 120000.0);
        final target = (_panStartPosition.inMilliseconds + delta)
            .clamp(0.0, _duration.inMilliseconds.toDouble());
        setState(() => _gestureSeekPreviewMs = target);

      case _GestureMode.volume:
        final newVol =
            (_panStartVolume + (-dy / h * 100)).clamp(0.0, 100.0);
        widget.player.setVolume(newVol);

      case _GestureMode.brightness:
        final newBrightness =
            (_panStartBrightness + (dy / h * 0.7)).clamp(0.0, 0.7);
        setState(() => _brightnessOverlay = newBrightness);

      case _GestureMode.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_activeGesture == _GestureMode.seeking) {
      widget.player.seek(
        Duration(milliseconds: _gestureSeekPreviewMs.toInt()),
      );
    }
    setState(() => _activeGesture = _GestureMode.none);
    _startAutoHide();
  }

  static String _fmt(Duration d) {
    if (d == Duration.zero) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(_duration.inMilliseconds.toDouble(), 1.0);
    final currentMs = (_isDraggingProgress
            ? (_dragProgressMs ?? _position.inMilliseconds.toDouble())
            : _position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _lastTapX = d.localPosition.dx,
          onTap: _toggleControls,
          onDoubleTapDown: (d) => _lastTapX = d.localPosition.dx,
          onDoubleTap: () => _handleDoubleTap(w),
          onLongPressStart: (_) async {
            setState(() => _isLongPressSpeed = true);
            await widget.player.setRate(2.0);
          },
          onLongPressEnd: (_) async {
            setState(() => _isLongPressSpeed = false);
            await widget.player.setRate(_rate == 2.0 ? 1.0 : _rate);
          },
          onPanStart: _onPanStart,
          onPanUpdate: (d) => _onPanUpdate(d, w, h),
          onPanEnd: _onPanEnd,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Video(
                    key: ValueKey(_videoRemountKey),
                    controller: widget.videoController,
                    controls: NoVideoControls,
                    fill: Colors.black,
                  ),
                ),

                if (_brightnessOverlay > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black
                            .withValues(alpha: _brightnessOverlay),
                      ),
                    ),
                  ),

                if (_isBuffering && !_isCompleted)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                if (_isLongPressSpeed)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: _Badge(text: '▶▶ 2x 快速播放中')),
                  ),

                if (_tapSeekHint != null)
                  Positioned.fill(
                    child: Center(child: _Badge(text: _tapSeekHint!)),
                  ),

                if (_activeGesture != _GestureMode.none)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _GestureIndicator(
                        mode: _activeGesture,
                        volume: _volume,
                        brightness: 1.0 - _brightnessOverlay / 0.7,
                        seekMs: _gestureSeekPreviewMs,
                        seekStartMs:
                            _panStartPosition.inMilliseconds.toDouble(),
                        fmt: _fmt,
                      ),
                    ),
                  ),

                // 控制层
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _PlayerTopBar(
                            onClose: widget.onClose,
                          ),
                        ),

                        Positioned.fill(
                          child: Center(
                            child: _CenterPlayBtn(
                              isPlaying: _isPlaying,
                              onTap: () async {
                                if (_isPlaying) {
                                  await widget.player.pause();
                                } else {
                                  await widget.player.play();
                                }
                                _showControlsTemporarily();
                              },
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _PlayerBottomBar(
                            isPlaying: _isPlaying,
                            currentMs: currentMs,
                            totalMs: totalMs,
                            position: _position,
                            duration: _duration,
                            rate: _rate,
                            fmt: _fmt,
                            onTogglePlay: () async {
                              if (_isPlaying) {
                                await widget.player.pause();
                              } else {
                                if (_isCompleted) {
                                  setState(() => _isCompleted = false);
                                  await widget.player.seek(Duration.zero);
                                }
                                await widget.player.play();
                              }
                              _showControlsTemporarily();
                            },
                            onSeekBack: () {
                              final t = _position - const Duration(seconds: 10);
                              widget.player.seek(
                                t.isNegative ? Duration.zero : t,
                              );
                              _showControlsTemporarily();
                            },
                            onSeekForward: () {
                              final t = _position + const Duration(seconds: 10);
                              widget.player.seek(
                                _duration > Duration.zero && t > _duration
                                    ? _duration
                                    : t,
                              );
                              _showControlsTemporarily();
                            },
                            onEnterPip: () {
                              widget.onEnterPip();
                              _showControlsTemporarily();
                            },
                            onFullscreen: () {
                              _openFullscreen();
                              _showControlsTemporarily();
                            },
                            onShowSpeedPanel: () {
                              setState(
                                () => _showSpeedPanel = !_showSpeedPanel,
                              );
                              _hideTimer?.cancel();
                            },
                            onDragStart: () {
                              setState(() {
                                _isDraggingProgress = true;
                                _dragProgressMs =
                                    _position.inMilliseconds.toDouble();
                              });
                              _hideTimer?.cancel();
                            },
                            onDragUpdate: (v) =>
                                setState(() => _dragProgressMs = v),
                            onDragEnd: (v) async {
                              await widget.player.seek(
                                Duration(milliseconds: v.toInt()),
                              );
                              if (!mounted) return;
                              setState(() {
                                _dragProgressMs = null;
                                _isDraggingProgress = false;
                              });
                              _startAutoHide();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 速度面板
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  right: _showSpeedPanel ? 0 : -150,
                  width: 150,
                  child: _SpeedPanel(
                    currentRate: _rate,
                    speeds: _speeds,
                    onSelect: (rate) async {
                      await widget.player.setRate(rate);
                      setState(() => _showSpeedPanel = false);
                      _startAutoHide();
                    },
                    onClose: () {
                      setState(() => _showSpeedPanel = false);
                      _startAutoHide();
                    },
                  ),
                ),

                // 播放完成
                if (_isCompleted)
                  Positioned.fill(
                    child: _CompletedOverlay(
                      nextVideo: _nextVideo,
                      countdown: _autoplayCountdown,
                      onReplay: () async {
                        _cancelAutoplay();
                        setState(() => _isCompleted = false);
                        await widget.player.seek(Duration.zero);
                        await widget.player.play();
                      },
                      onPlayNext: _nextVideo != null
                          ? () {
                              _cancelAutoplay();
                              widget.onSwitchVideo(_nextVideo!);
                            }
                          : null,
                      onCancelAutoplay: _cancelAutoplay,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 播放器子组件
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GestureIndicator extends StatelessWidget {
  const _GestureIndicator({
    required this.mode,
    required this.volume,
    required this.brightness,
    required this.seekMs,
    required this.seekStartMs,
    required this.fmt,
  });

  final _GestureMode mode;
  final double volume;
  final double brightness;
  final double seekMs;
  final double seekStartMs;
  final String Function(Duration) fmt;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case _GestureMode.volume:
        return Align(
          alignment: const Alignment(0.7, 0),
          child: _VerticalProgressBadge(
            icon: volume > 0
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            value: volume / 100,
            label: '${volume.toInt()}%',
          ),
        );
      case _GestureMode.brightness:
        return Align(
          alignment: const Alignment(-0.7, 0),
          child: _VerticalProgressBadge(
            icon: Icons.brightness_6_rounded,
            value: brightness,
            label: '${(brightness * 100).toInt()}%',
          ),
        );
      case _GestureMode.seeking:
        final delta = seekMs - seekStartMs;
        final sign = delta >= 0 ? '+' : '';
        return Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmt(Duration(milliseconds: seekMs.toInt())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sign${fmt(Duration(milliseconds: delta.abs().toInt()))}',
                  style: TextStyle(
                    color: delta >= 0
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      case _GestureMode.none:
        return const SizedBox.shrink();
    }
  }
}

class _VerticalProgressBadge extends StatelessWidget {
  const _VerticalProgressBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF212028).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                AppAssets.videoV2Back,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPlayBtn extends StatelessWidget {
  const _CenterPlayBtn({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          isPlaying ? AppAssets.videoV2CenterPause : AppAssets.videoV2CenterPlay,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PlayerBottomBar extends StatelessWidget {
  const _PlayerBottomBar({
    required this.isPlaying,
    required this.currentMs,
    required this.totalMs,
    required this.position,
    required this.duration,
    required this.rate,
    required this.fmt,
    required this.onTogglePlay,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onEnterPip,
    required this.onFullscreen,
    required this.onShowSpeedPanel,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool isPlaying;
  final double currentMs;
  final double totalMs;
  final Duration position;
  final Duration duration;
  final double rate;
  final String Function(Duration) fmt;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onEnterPip;
  final VoidCallback onFullscreen;
  final VoidCallback onShowSpeedPanel;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final progress = totalMs <= 0 ? 0.0 : (currentMs / totalMs).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.88),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 16, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackW = constraints.maxWidth;
                final activeW = trackW * progress;
                final thumbX = (trackW * progress).clamp(6.0, trackW - 6.0);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      child: Container(
                        width: activeW,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                    Positioned(
                      left: thumbX - 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8741FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 20,
                        thumbShape: SliderComponentShape.noThumb,
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: currentMs,
                        min: 0,
                        max: totalMs,
                        onChangeStart: (_) => onDragStart(),
                        onChanged: onDragUpdate,
                        onChangeEnd: onDragEnd,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onSeekBack,
                icon: Image.asset(
                  AppAssets.videoV2SeekBack10,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              GestureDetector(
                onTap: onTogglePlay,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  child: Image.asset(
                    isPlaying
                        ? AppAssets.videoV2CenterPause
                        : AppAssets.videoV2SmallPlay,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              IconButton(
                onPressed: onSeekForward,
                icon: Image.asset(
                  AppAssets.videoV2SeekForward10,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 6),
              Text(
                '${fmt(position)} / ${fmt(duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEnterPip,
                icon: Image.asset(
                  AppAssets.videoV2Pip,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              GestureDetector(
                onTap: onShowSpeedPanel,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  child: Image.asset(
                    AppAssets.videoV2Setting,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFullscreen,
                icon: Image.asset(
                  AppAssets.videoV2Fullscreen,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({
    required this.currentRate,
    required this.speeds,
    required this.onSelect,
    required this.onClose,
  });

  final double currentRate;
  final List<double> speeds;
  final ValueChanged<double> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '倍  速',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 4),
            ...speeds.map((rate) {
              final selected = (currentRate - rate).abs() < 0.01;
              return GestureDetector(
                onTap: () => onSelect(rate),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  color: selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_rounded,
                            color: Color(0xFF8741FF),
                            size: 14,
                          ),
                        )
                      else
                        const SizedBox(width: 20),
                      Text(
                        rate == 1.0
                            ? '1.0x  (正常)'
                            : '${rate.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x',
                        style: TextStyle(
                          color:
                              selected ? const Color(0xFF8741FF) : Colors.white,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CompletedOverlay extends StatelessWidget {
  const _CompletedOverlay({
    required this.nextVideo,
    required this.countdown,
    required this.onReplay,
    required this.onPlayNext,
    required this.onCancelAutoplay,
  });

  final VideoListItem? nextVideo;
  final int countdown;
  final VoidCallback onReplay;
  final VoidCallback? onPlayNext;
  final VoidCallback onCancelAutoplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onReplay,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.replay_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '重播',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (nextVideo != null) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white24, indent: 40, endIndent: 40),
            const SizedBox(height: 16),
            Text(
              '下一集',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                nextVideo!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (countdown > 0) ...[
                  GestureDetector(
                    onTap: onCancelAutoplay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                GestureDetector(
                  onTap: onPlayNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8741FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countdown > 0 ? '${countdown}s 后播放' : '立即播放',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// E. 全屏播放页（修复：NoVideoControls + Positioned 布局，消除溢出）
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.player,
    required this.videoController,
    required this.title,
  });

  final Player player;
  final VideoController videoController;
  final String title;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  final List<StreamSubscription<Object?>> _subs = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _volume = 100;
  double _rate = 1.0;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _isDragging = false;
  double? _dragMs;

  // 手势
  double _lastTapX = 0;
  String? _tapSeekHint;
  Timer? _tapSeekHintTimer;
  bool _isLongPressSpeed = false;

  _GestureMode _activeGesture = _GestureMode.none;
  double _panStartX = 0;
  double _panStartY = 0;
  double _panStartVolume = 0;
  double _panStartBrightness = 0;
  Duration _panStartPosition = Duration.zero;
  double _gestureSeekMs = 0;
  double _brightnessOverlay = 0;

  @override
  void initState() {
    super.initState();
    // 全屏页打开时，流不会重播已发出的值，必须先从 player.state 同步当前状态，
    // 否则 _duration 永远是 Duration.zero，进度条 max=1ms，进度显示错误。
    final s = widget.player.state;
    _position = s.position;
    _duration = s.duration;
    _isPlaying = s.playing;
    _isBuffering = s.buffering;
    _volume = s.volume;
    _rate = s.rate;
    _subscribe();
    _autoHide();
    // 全屏 Video widget 挂载后确保播放状态不因纹理重绑而中断
    if (s.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.player.play();
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _tapSeekHintTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  void _subscribe() {
    final p = widget.player;
    _subs.add(p.stream.position.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subs.add(p.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    }));
    _subs.add(p.stream.playing.listen((v) {
      if (mounted) setState(() => _isPlaying = v);
    }));
    _subs.add(p.stream.buffering.listen((v) {
      if (mounted) setState(() => _isBuffering = v);
    }));
    _subs.add(p.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    }));
    _subs.add(p.stream.rate.listen((v) {
      if (mounted) setState(() => _rate = v);
    }));
  }

  void _autoHide() {
    _hideTimer?.cancel();
    if (_isDragging) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDragging) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _autoHide();
  }

  void _handleDoubleTap(double totalWidth) {
    final isLeft = _lastTapX < totalWidth / 2;
    final delta = Duration(seconds: isLeft ? -10 : 10);
    final target = _position + delta;
    final clamped = target.isNegative
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    widget.player.seek(clamped);
    setState(() => _tapSeekHint = isLeft ? '← -10s' : '+10s →');
    _tapSeekHintTimer?.cancel();
    _tapSeekHintTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _tapSeekHint = null);
    });
    _autoHide();
  }

  void _onPanStart(DragStartDetails d, double w) {
    _panStartX = d.localPosition.dx;
    _panStartY = d.localPosition.dy;
    _panStartVolume = _volume;
    _panStartBrightness = _brightnessOverlay;
    _panStartPosition = _position;
    _activeGesture = _GestureMode.none;
    _hideTimer?.cancel();
  }

  void _onPanUpdate(DragUpdateDetails d, double w, double h) {
    final dx = d.localPosition.dx - _panStartX;
    final dy = d.localPosition.dy - _panStartY;
    if (_activeGesture == _GestureMode.none) {
      if (dx.abs() < 8 && dy.abs() < 8) return;
      _activeGesture = dx.abs() > dy.abs()
          ? _GestureMode.seeking
          : (_panStartX < w / 2 ? _GestureMode.brightness : _GestureMode.volume);
    }
    switch (_activeGesture) {
      case _GestureMode.seeking:
        final delta = (dx / w * _duration.inMilliseconds).clamp(-120000.0, 120000.0);
        final t = (_panStartPosition.inMilliseconds + delta)
            .clamp(0.0, _duration.inMilliseconds.toDouble());
        setState(() => _gestureSeekMs = t);
      case _GestureMode.volume:
        final nv = (_panStartVolume + (-dy / h * 100)).clamp(0.0, 100.0);
        widget.player.setVolume(nv);
      case _GestureMode.brightness:
        final nb = (_panStartBrightness + (dy / h * 0.7)).clamp(0.0, 0.7);
        setState(() => _brightnessOverlay = nb);
      case _GestureMode.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_activeGesture == _GestureMode.seeking) {
      widget.player.seek(Duration(milliseconds: _gestureSeekMs.toInt()));
    }
    setState(() => _activeGesture = _GestureMode.none);
    _autoHide();
  }

  static String _fmt(Duration d) {
    if (d == Duration.zero) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(_duration.inMilliseconds.toDouble(), 1.0);
    final currentMs = (_isDragging
            ? (_dragMs ?? _position.inMilliseconds.toDouble())
            : _position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);

    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _lastTapX = d.localPosition.dx,
            onTap: _toggleControls,
            onDoubleTapDown: (d) => _lastTapX = d.localPosition.dx,
            onDoubleTap: () => _handleDoubleTap(w),
            onLongPressStart: (_) async {
              setState(() => _isLongPressSpeed = true);
              await widget.player.setRate(2.0);
            },
            onLongPressEnd: (_) async {
              setState(() => _isLongPressSpeed = false);
              await widget.player.setRate(_rate == 2.0 ? 1.0 : _rate);
            },
            onPanStart: (d) => _onPanStart(d, w),
            onPanUpdate: (d) => _onPanUpdate(d, w, h),
            onPanEnd: _onPanEnd,
            child: Stack(
              children: [
                // ① 视频
                Positioned.fill(
                  child: Video(
                    controller: widget.videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                    fill: Colors.black,
                  ),
                ),

                // ② 亮度蒙层
                if (_brightnessOverlay > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: _brightnessOverlay),
                      ),
                    ),
                  ),

                // ③ 缓冲
                if (_isBuffering && _activeGesture == _GestureMode.none)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                // ④ 长按快速播放提示
                if (_isLongPressSpeed)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(child: _Badge(text: '▶▶ 2x 快速播放中')),
                  ),

                // ⑤ 双击快进/快退提示
                if (_tapSeekHint != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: _Badge(text: _tapSeekHint!)),
                    ),
                  ),

                // ⑥ 手势指示器
                if (_activeGesture != _GestureMode.none)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _GestureIndicator(
                        mode: _activeGesture,
                        volume: _volume,
                        brightness: 1.0 - _brightnessOverlay / 0.7,
                        seekMs: _gestureSeekMs,
                        seekStartMs: _panStartPosition.inMilliseconds.toDouble(),
                        fmt: _fmt,
                      ),
                    ),
                  ),

                // ⑦ 控制层（渐隐）
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      children: [
                        // 顶部渐变 + 返回/标题
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.only(top: safeTop),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Image.asset(
                                    AppAssets.videoV2Back,
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // 倍速徽章
                                if (((_rate - 1.0).abs() > 0.01) && !_isLongPressSpeed)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8741FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_rate.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // 中央播放/暂停
                        Positioned.fill(
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                if (_isPlaying) {
                                  widget.player.pause();
                                } else {
                                  widget.player.play();
                                }
                                _autoHide();
                              },
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    _isPlaying
                                        ? AppAssets.videoV2CenterPause
                                        : AppAssets.videoV2CenterPlay,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 底部进度条 + 按钮
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.only(bottom: safeBottom),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.88),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 12),
                                      activeTrackColor: const Color(0xFF8741FF),
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.3),
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: currentMs,
                                      min: 0,
                                      max: totalMs,
                                      onChangeStart: (_) {
                                        setState(() => _isDragging = true);
                                        _hideTimer?.cancel();
                                      },
                                      onChanged: (v) =>
                                          setState(() => _dragMs = v),
                                      onChangeEnd: (v) async {
                                        await widget.player.seek(
                                          Duration(milliseconds: v.toInt()),
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          _dragMs = null;
                                          _isDragging = false;
                                        });
                                        _autoHide();
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          final t = _position -
                                              const Duration(seconds: 10);
                                          widget.player.seek(
                                              t.isNegative ? Duration.zero : t);
                                          _autoHide();
                                        },
                                        icon: Image.asset(
                                          AppAssets.videoV2SeekBack10,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.contain,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (_isPlaying) {
                                            widget.player.pause();
                                          } else {
                                            widget.player.play();
                                          }
                                          _autoHide();
                                        },
                                        child: Image.asset(
                                          _isPlaying
                                              ? AppAssets.videoV2CenterPause
                                              : AppAssets.videoV2SmallPlay,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          final t = _position +
                                              const Duration(seconds: 10);
                                          widget.player.seek(
                                            _duration > Duration.zero &&
                                                    t > _duration
                                                ? _duration
                                                : t,
                                          );
                                          _autoHide();
                                        },
                                        icon: Image.asset(
                                          AppAssets.videoV2SeekForward10,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.contain,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_fmt(_position)} / ${_fmt(_duration)}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13),
                                      ),
                                      const Spacer(),
                                      // 音量静音
                                      IconButton(
                                        onPressed: () =>
                                            widget.player.setVolume(
                                                _volume > 0 ? 0 : 100),
                                        icon: Icon(
                                          _volume > 0
                                              ? Icons.volume_up_rounded
                                              : Icons.volume_off_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                      ),
                                      // 退出全屏
                                      IconButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        icon: Image.asset(
                                          AppAssets.videoV2FullscreenExit,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.contain,
                                        ),
                                        tooltip: '退出全屏',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F. 悬浮画中画小窗
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingMiniPlayer extends StatefulWidget {
  const _FloatingMiniPlayer({
    required this.player,
    required this.videoController,
    required this.title,
    required this.onDismiss,
    this.onExpand,
  });

  final Player player;
  final VideoController videoController;
  final String title;
  final VoidCallback onDismiss;
  final VoidCallback? onExpand;

  @override
  State<_FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<_FloatingMiniPlayer> {
  static const double _w = 240;
  static const double _h = 135; // 16:9

  Offset _position = Offset.zero;
  bool _initialized = false;
  bool _isPlaying = false;
  StreamSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state.playing;
    _playSub = widget.player.stream.playing.listen((v) {
      if (mounted) setState(() => _isPlaying = v);
    });
  }

  @override
  void dispose() {
    _playSub?.cancel();
    super.dispose();
  }

  void _initPosition(Size screen) {
    if (_initialized) return;
    _initialized = true;
    // 默认右下角
    _position = Offset(screen.width - _w - 16, screen.height - _h - 80);
  }

  Offset _clamp(Offset pos, Size screen) {
    return Offset(
      pos.dx.clamp(0, screen.width - _w),
      pos.dy.clamp(0, screen.height - _h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    _initPosition(screen);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _position = _clamp(_position + d.delta, screen);
          });
        },
        // 双击展开回详情面板
        onDoubleTap: widget.onExpand,
        child: Material(
          color: Colors.transparent,
          elevation: 16,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(
                children: [
                  // 视频画面
                  Positioned.fill(
                    child: Video(
                      controller: widget.videoController,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                  ),

                  // 点击切换播放/暂停
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (_isPlaying) {
                          widget.player.pause();
                        } else {
                          widget.player.play();
                        }
                      },
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),

                  // 暂停时中心播放图标
                  if (!_isPlaying)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 底部渐变 + 标题
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.70),
                            ],
                          ),
                        ),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 右上：关闭 & 展开按钮
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onExpand != null)
                          GestureDetector(
                            onTap: widget.onExpand,
                            child: Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.60),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.60),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// G. 播放器占位
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder({required this.coverUrl, required this.loading});

  final String coverUrl;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Colors.black),
                )
              : const ColoredBox(color: Colors.black),
        ),
        if (loading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// H. 详情面板 UI
// ─────────────────────────────────────────────────────────────────────────────

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.isFavorite,
    required this.tabController,
    required this.onFavorite,
    required this.onShare,
  });

  final bool isFavorite;
  final TabController tabController;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: tabController,
              indicatorColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              labelColor: const Color(0xFF0B081A),
              unselectedLabelColor: const Color(0xFF6D6B75),
              labelPadding: const EdgeInsets.only(right: 24),
              padding: EdgeInsets.zero,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '视频详情'), Tab(text: '查看谱例')],
            ),
          ),
          _ActionBtn(
            icon: AppAssets.videoV2Share,
            label: '分享',
            onTap: onShare,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: AppAssets.videoV2Star,
            label: isFavorite ? '已收藏' : '收藏',
            highlighted: isFavorite,
            onTap: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(12, 4, 13, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F2F3),
          borderRadius: BorderRadius.circular(8),
          border: highlighted
              ? Border.all(
                  color: const Color(0xFF8741FF).withValues(alpha: 0.4),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 20, height: 20, fit: BoxFit.contain),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: highlighted
                    ? const Color(0xFF8741FF)
                    : const Color(0xFF0B081A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoTab extends StatelessWidget {
  const _DetailInfoTab({
    required this.detail,
    required this.resolveUrl,
    required this.onOpenSeriesVideo,
  });

  final VideoDetail detail;
  final String Function(String) resolveUrl;
  final ValueChanged<VideoListItem> onOpenSeriesVideo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF0B081A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.expand_less_rounded,
                size: 24,
                color: Color(0xFF333333),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.description.isEmpty ? '暂无简介' : detail.description,
            style: const TextStyle(
              fontSize: 13,
              height: 2.0,
              color: Color(0xFF6D6B75),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '视频来源用户上传，如有侵权，请立即联系删除。',
              style: const TextStyle(
                fontSize: 10,
                height: 2.0,
                color: Color(0xFFB6B5BB),
              ),
            ),
          ),
          if (detail.seriesVideoList.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '相关视频',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B081A),
              ),
            ),
            const SizedBox(height: 12),
            ...detail.seriesVideoList.take(6).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SeriesCard(
                      item: item,
                      resolveUrl: resolveUrl,
                      onTap: () => onOpenSeriesVideo(item),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ScoreTab extends StatelessWidget {
  const _ScoreTab({
    required this.scoreImages,
    required this.resolveUrl,
    required this.onPreviewImage,
  });

  final List<String> scoreImages;
  final String Function(String) resolveUrl;
  final ValueChanged<String> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    if (scoreImages.isEmpty) {
      return const Center(
        child: Text(
          '暂无谱例',
          style: TextStyle(fontSize: 14, color: Color(0xFFB6B5BB)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: scoreImages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final url = scoreImages[index];
        return GestureDetector(
          onTap: () => onPreviewImage(url),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF3F2F3)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.network(
              resolveUrl(url),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    '图片加载失败',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB6B5BB),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.item,
    required this.resolveUrl,
    required this.onTap,
  });

  final VideoListItem item;
  final String Function(String) resolveUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  SizedBox(
                    width: 148,
                    height: 80,
                    child: Image.network(
                      resolveUrl(item.coverImg),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFEDEDF2),
                        child: Center(
                          child: Icon(
                            Icons.ondemand_video_rounded,
                            color: Color(0xFFB6B5BB),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 5,
                    child: Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          item.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0B081A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB6B5BB),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF856FE2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.videoV2SeriesPlay,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                  const Text(
                    '播放',
                    style: TextStyle(color: Colors.white, fontSize: 12, height: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// I. 主列表 UI 组件
// ─────────────────────────────────────────────────────────────────────────────

class _VideoCategoryHeader extends StatelessWidget {
  const _VideoCategoryHeader({
    required this.scale,
    required this.menus,
    required this.selectedMenuId,
    required this.onSelectMenu,
  });

  final DashboardScaleData scale;
  final List<VideoMenu> menus;
  final String? selectedMenuId;
  final ValueChanged<String?> onSelectMenu;

  @override
  Widget build(BuildContext context) {
    final ui = scale.ui;
    return SizedBox(
      height: ui(44),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: menus.length,
              separatorBuilder: (_, _) => SizedBox(width: ui(8)),
              itemBuilder: (context, index) {
                final menu = menus[index];
                final active = menu.id == selectedMenuId;
                return InkWell(
                  borderRadius: BorderRadius.circular(ui(8)),
                  onTap: () => onSelectMenu(menu.id),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: ui(14)),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF212028)
                          : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      menu.name,
                      style: TextStyle(
                        fontSize: ui(15),
                        color: active
                            ? Colors.white
                            : const Color(0xFF6D6B75),
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: ui(220),
            height: ui(40),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            child: Row(
              children: [
                AppAssetGraphic(
                  AppAssets.shellV2Search,
                  width: ui(14),
                  height: ui(14),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: ui(8)),
                Text(
                  '搜索视频',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFFD1D1D1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerAndLatestSection extends StatelessWidget {
  const _BannerAndLatestSection({
    required this.scale,
    required this.banners,
    required this.activeIndex,
    required this.pageController,
    required this.latestVideos,
    required this.resolveUrl,
    required this.onBannerChanged,
    required this.onOpenVideo,
  });

  final DashboardScaleData scale;
  final List<VideoBannerItem> banners;
  final int activeIndex;
  final PageController pageController;
  final List<VideoListItem> latestVideos;
  final String Function(String) resolveUrl;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<VideoListItem> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final ui = scale.ui;
    final hasBanner = banners.isNotEmpty;
    return SizedBox(
      height: ui(264),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(16)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: hasBanner
                        ? PageView.builder(
                            controller: pageController,
                            itemCount: banners.length,
                            onPageChanged: onBannerChanged,
                            itemBuilder: (context, index) => Image.network(
                              resolveUrl(banners[index].imageUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Image.asset(
                                AppAssets.videoBanner,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Image.asset(
                            AppAssets.videoBanner,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: ui(70),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasBanner && banners.length > 1)
                    Positioned(
                      right: ui(16),
                      bottom: ui(12),
                      child: Row(
                        children: List.generate(banners.length, (index) {
                          final active = index == activeIndex;
                          return Container(
                            width: active ? ui(20) : ui(8),
                            height: ui(4),
                            margin: EdgeInsets.only(left: ui(4)),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: active ? 1 : 0.6,
                              ),
                              borderRadius: BorderRadius.circular(ui(12)),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          _LatestVideoListCard(
            scale: scale,
            items: latestVideos,
            resolveUrl: resolveUrl,
            onOpenVideo: onOpenVideo,
          ),
        ],
      ),
    );
  }
}

class _LatestVideoListCard extends StatelessWidget {
  const _LatestVideoListCard({
    required this.scale,
    required this.items,
    required this.resolveUrl,
    required this.onOpenVideo,
  });

  final DashboardScaleData scale;
  final List<VideoListItem> items;
  final String Function(String) resolveUrl;
  final ValueChanged<VideoListItem> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final ui = scale.ui;
    return Container(
      width: ui(200),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最新视频',
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF0B081A),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      '暂无视频',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFFB6B5BB),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: math.min(items.length, 3),
                    separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: () => onOpenVideo(item),
                        borderRadius: BorderRadius.circular(ui(8)),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ui(6)),
                              child: SizedBox(
                                width: ui(56),
                                height: ui(44),
                                child: Image.network(
                                  resolveUrl(item.coverImg),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFFEDEDF2),
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: const Color(0xFFB6B5BB),
                                      size: ui(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: ui(8)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(12),
                                      color: const Color(0xFF0B081A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: ui(2)),
                                  Text(
                                    '播放量 ${item.playCount}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: ui(10),
                                      color: const Color(0xFFB6B5BB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubCategoryBar extends StatelessWidget {
  const _SubCategoryBar({
    required this.scale,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final DashboardScaleData scale;
  final List<VideoMenuChild> items;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = scale.ui;
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: ui(40),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: ui(8)),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item.id == selectedId;
          return InkWell(
            borderRadius: BorderRadius.circular(ui(8)),
            onTap: () => onSelect(item.id),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(14)),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF212028)
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              alignment: Alignment.center,
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: ui(14),
                  color: active ? Colors.white : const Color(0xFF212028),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 视频网格卡片 — 严格按 Figma HTML 参考实现
// 封面: 220:124 比例；缩略图 52×70 叠放在封面左下角延伸至信息区
class _VideoGridCard extends StatelessWidget {
  const _VideoGridCard({
    required this.scale,
    required this.item,
    required this.resolveUrl,
    required this.onTap,
  });

  final DashboardScaleData scale;
  final VideoListItem item;
  final String Function(String) resolveUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = scale.ui;
    // LayoutBuilder 获取实际卡片宽度，按 220px 设计基准等比缩放所有尺寸
    return LayoutBuilder(
      builder: (context, box) {
        final cw = box.maxWidth; // 实际卡片宽度
        final s = cw / 220.0; // 缩放因子

        // 封面高度按 220:124 比例
        final coverH = 124.0 * s;
        // 缩略图：52×70，左距10，顶距95（从封面顶部算起，即在封面底部上方29px开始）
        final thumbL = 10.0 * s;
        final thumbTop = 95.0 * s; // 相对于卡片顶部
        final thumbW = 52.0 * s;
        final thumbH = 70.0 * s;
        // 信息区左侧预留宽度（缩略图右边缘 + 4px 间距 = (10+52+4)*s = 66s）
        final infoLeft = 66.0 * s;

        return Material(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(12)),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // ── 卡片主体：封面 + 信息区 ──────────────────────────────
                SizedBox.expand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 封面区（保持 220:124 比例）
                      SizedBox(
                        height: coverH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                resolveUrl(item.coverImg),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFEDEDF2),
                                  child: Icon(
                                    Icons.ondemand_video_rounded,
                                    color: const Color(0xFFB6B5BB),
                                    size: ui(28),
                                  ),
                                ),
                              ),
                            ),
                            // 时长角标：右下角
                            Positioned(
                              right: 8.0 * s,
                              bottom: 8.0 * s,
                              child: Container(
                                height: 18.0 * s,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.0 * s,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(18.0 * s),
                                ),
                                child: Center(
                                  child: Text(
                                    item.duration,
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: Colors.white,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w400,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 信息区（Expanded 自动填满剩余高度）
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            infoLeft, // 左边为缩略图预留空间
                            4.0 * s,
                            10.0 * s,
                            6.0 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.0 * s,
                                  color: const Color(0xFF0B081A),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'PingFang SC',
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              // 作者 + 播放量
                              Row(
                                children: [
                                  // 作者头像（圆形占位）
                                  Container(
                                    width: 16.0 * s,
                                    height: 16.0 * s,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0DEFF),
                                      borderRadius: BorderRadius.circular(
                                        8.0 * s,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  // 作者名
                                  Expanded(
                                    child: Text(
                                      '音乐之路',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.0 * s,
                                        color: const Color(0xFFB6B5BB),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  // 播放量图标 + 数字
                                  AppAssetGraphic(
                                    AppAssets.videoV2CardViews,
                                    width: 12.0 * s,
                                    height: 12.0 * s,
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  Text(
                                    '${item.playCount}',
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: const Color(0xFFB6B5BB),
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 缩略图：叠在封面左下角，延伸至信息区 ─────────────────
                Positioned(
                  left: thumbL,
                  top: thumbTop,
                  width: thumbW,
                  height: thumbH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.0 * s),
                      child: Image.network(
                        resolveUrl(item.coverImg),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFEDEDF2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// J. 分享弹窗
// ─────────────────────────────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.classes,
    required this.selected,
    required this.onSubmit,
  });

  final List<VideoShareClassItem> classes;
  final Set<int> selected;
  final Future<void> Function() onSubmit;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 480),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分享视频',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B081A),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: widget.classes.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFFF3F2F3)),
                itemBuilder: (context, index) {
                  final item = widget.classes[index];
                  final checked = widget.selected.contains(item.id);
                  return InkWell(
                    onTap: () => setState(() {
                      if (checked) {
                        widget.selected.remove(item.id);
                      } else {
                        widget.selected.add(item.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0B081A),
                              ),
                            ),
                          ),
                          Checkbox(
                            value: checked,
                            activeColor: const Color(0xFF8741FF),
                            onChanged: (_) => setState(() {
                              if (checked) {
                                widget.selected.remove(item.id);
                              } else {
                                widget.selected.add(item.id);
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: const Color(0xFF8741FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onSubmit();
                        if (mounted) setState(() => _submitting = false);
                      },
                child: Text(
                  _submitting ? '发送中...' : '发送',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

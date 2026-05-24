import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 沉浸模式下的统一媒体播放壳：
/// - **图片**：盖一张大图 + 加载/失败兜底
/// - **视频**：`media_kit` 全屏 cover + 抖音式播放/暂停与全屏进度拖动
/// - **音频**：同款交互（AnimatedIcons.play_pause + 全屏/底部进度条）
class CircleMediaPlayer extends StatefulWidget {
  const CircleMediaPlayer({
    super.key,
    required this.post,
    this.autoPlay = true,
  });

  final CirclePost post;
  final bool autoPlay;

  @override
  State<CircleMediaPlayer> createState() => _CircleMediaPlayerState();
}

class _CircleMediaPlayerState extends State<CircleMediaPlayer> {
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    _setupForCurrentPost();
  }

  @override
  void didUpdateWidget(covariant CircleMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.primaryMediaUrl != widget.post.primaryMediaUrl ||
        oldWidget.post.mediaKind != widget.post.mediaKind) {
      _teardownPlayer();
      _setupForCurrentPost();
    }
  }

  void _setupForCurrentPost() {
    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty) return;
    if (widget.post.mediaKind == PostMediaKind.image) return;

    final player = Player();
    _player = player;
    if (widget.post.mediaKind == PostMediaKind.video) {
      _videoController = VideoController(player);
    }
    unawaited(_openAndLoop(player, url));
  }

  Future<void> _openAndLoop(Player player, String url) async {
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(url), play: widget.autoPlay);
  }

  void _teardownPlayer() {
    final player = _player;
    if (player != null) {
      try {
        unawaited(player.pause());
      } catch (_) {}
      unawaited(player.dispose());
    }
    _player = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _teardownPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.post.mediaKind) {
      PostMediaKind.image => _ImageBackdrop(url: widget.post.imageUrl),
      PostMediaKind.video => _buildVideoBody(),
      PostMediaKind.audio => _buildAudioBody(),
    };
  }

  Widget _buildVideoBody() {
    final controller = _videoController;
    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty || controller == null) {
      return _ImageBackdrop(url: widget.post.imageUrl);
    }
    return Video(
      controller: controller,
      fit: BoxFit.cover,
      controls: _douyinVideoControls,
    );
  }

  Widget _buildAudioBody() {
    final player = _player;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.imageUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: const ColorFilter.mode(
              Color(0x55000000),
              BlendMode.darken,
            ),
            child: Image.network(
              widget.post.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _AudioBackdrop(),
            ),
          )
        else
          const _AudioBackdrop(),
        if (player != null)
          Positioned.fill(
            child: _DouyinMediaControls(player: player),
          ),
      ],
    );
  }
}

/// 视频层控件：全屏手势 + 底部进度条。
Widget _douyinVideoControls(VideoState state) {
  return _DouyinMediaControls(player: state.widget.controller.player);
}

/// 抖音式全屏媒体控件：
/// - **单击**任意位置：播放 / 暂停
/// - **全屏横向滑动**：拖动进度（拖动时暂停，松手恢复）
/// - **纵向滑动**：不拦截，交给外层 PageView 翻页
/// - 底部细进度条随播放更新；拖动时变粗并显示时间
class _DouyinMediaControls extends StatefulWidget {
  const _DouyinMediaControls({required this.player});

  final Player player;

  @override
  State<_DouyinMediaControls> createState() => _DouyinMediaControlsState();
}

class _DouyinMediaControlsState extends State<_DouyinMediaControls>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playingSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  bool _dragging = false;
  double _dragRatio = 0;
  bool _resumeAfterDrag = false;

  late final AnimationController _iconAnimation = AnimationController(
    vsync: this,
    value: widget.player.state.playing ? 1 : 0,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    _playing = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _posSub = widget.player.stream.position.listen((p) {
      if (mounted && !_dragging) setState(() => _position = p);
    });
    _durSub = widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playingSub = widget.player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      if (p) {
        _iconAnimation.forward();
      } else {
        _iconAnimation.reverse();
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _iconAnimation.dispose();
    super.dispose();
  }

  double get _displayRatio {
    if (_dragging) return _dragRatio;
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (TapGestureRecognizer instance) {
                instance.onTap = () {
                  if (!_dragging) widget.player.playOrPause();
                };
              },
            ),
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
              (HorizontalDragGestureRecognizer instance) {
                instance.onStart = (d) => _onDragStart(d.localPosition.dx, width);
                instance.onUpdate = (d) =>
                    _onDragUpdate(d.localPosition.dx, width);
                instance.onEnd = (_) => unawaited(_onDragEnd());
                instance.onCancel = _onDragCancel;
              },
            ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_dragging)
                ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
              if (!_dragging && !_playing)
                Center(
                  child: AnimatedIcon(
                    progress: _iconAnimation,
                    icon: AnimatedIcons.play_pause,
                    size: ui(56),
                    color: Colors.white,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildProgressBar(ui, width),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(double Function(double) ui, double width) {
    final barHeight = _dragging ? ui(6) : ui(2);
    return Padding(
      padding: EdgeInsets.only(bottom: _dragging ? ui(4) : 0),
      child: SizedBox(
        height: ui(44),
        width: double.infinity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: barHeight,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _displayRatio,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ),
                if (_dragging)
                  Positioned(
                    left: (width * _displayRatio).clamp(0.0, width) - ui(6),
                    top: (barHeight - ui(12)) / 2,
                    child: Container(
                      width: ui(12),
                      height: ui(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onDragStart(double dx, double width) {
    if (width <= 0 || _duration.inMilliseconds <= 0) return;
    _resumeAfterDrag = widget.player.state.playing;
    if (_resumeAfterDrag) {
      unawaited(widget.player.pause());
    }
    final ratio = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _dragRatio = ratio;
    });
    unawaited(_seekToRatio(ratio));
  }

  void _onDragUpdate(double dx, double width) {
    if (!_dragging || width <= 0 || _duration.inMilliseconds <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    if (ratio == _dragRatio) return;
    setState(() => _dragRatio = ratio);
    unawaited(_seekToRatio(ratio));
  }

  Future<void> _onDragEnd() async {
    if (!_dragging) return;
    final ratio = _dragRatio;
    final resume = _resumeAfterDrag;
    setState(() {
      _dragging = false;
      _resumeAfterDrag = false;
    });
    await _seekToRatio(ratio);
    if (resume && mounted) {
      await widget.player.play();
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    final resume = _resumeAfterDrag;
    setState(() {
      _dragging = false;
      _resumeAfterDrag = false;
    });
    if (resume) {
      unawaited(widget.player.play());
    }
  }

  Future<void> _seekToRatio(double ratio) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * ratio).round(),
    );
    await widget.player.seek(target);
  }
}

class _ImageBackdrop extends StatelessWidget {
  const _ImageBackdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(color: Color(0xFF1B1530));
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) =>
          const ColoredBox(color: Color(0xFF1B1530)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: Color(0xFF1B1530));
      },
    );
  }
}

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1E66), Color(0xFF0B081A)],
        ),
      ),
    );
  }
}

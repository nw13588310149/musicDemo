import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../piano/ui/piano_keyboard.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/music_play_controller.dart';
import '../state/music_play_state.dart';

final Set<String> _musicPlayPrecachedImages = <String>{};

class MusicPlayPage extends ConsumerStatefulWidget {
  const MusicPlayPage({super.key});

  @override
  ConsumerState<MusicPlayPage> createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends ConsumerState<MusicPlayPage> {
  bool _shareDialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final args = MusicPlayPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    final state = ref.watch(musicPlayControllerProvider(args));
    final controller = ref.read(musicPlayControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;
    _precacheMusicPlayImages(context, state);

    ref.listen<MusicPlayState>(musicPlayControllerProvider(args), (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.show(context, message);
        controller.clearError();
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    // Padding is moved INSIDE each layout so that the bottom piano keyboard
    // can sit flush against the surface edges (full-bleed) for a more
    // immersive look. ClipRRect respects the panel's rounded corners so the
    // piano's drop shadow does not bleed past them.
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: state.loading && !state.hasDetail
            ? Padding(
                padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (state.isVocalOrInstrumental
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui(12),
                        ui(12),
                        ui(12),
                        ui(12),
                      ),
                      child: _buildVocalLayout(context, state, controller),
                    )
                  : _buildDefaultLayout(context, state, controller)),
      ),
    );
  }

  void _precacheMusicPlayImages(BuildContext context, MusicPlayState state) {
    final urls = <String>[
      'assets/images/home/plyabj.png',
      'assets/images/home/play1.png',
      'assets/images/home/left.png',
      'assets/images/home/right.png',
      'assets/images/home/chevron-down.png',
      'assets/images/home/feng.png',
      'assets/images/home/dictation/8.png',
      'assets/images/home/dictation/9.png',
      'assets/images/home/dictation/10.png',
      'assets/images/404/wx.png',
      'assets/images/404/jp.png',
      ...?state.detail?.questionImages,
      ...?state.detail?.answerImages,
      if (state.detail?.coverUrl.isNotEmpty == true) state.detail!.coverUrl,
    ];

    for (final url in urls) {
      if (url.isEmpty || !_musicPlayPrecachedImages.add(url)) {
        continue;
      }
      final provider = url.startsWith('http://') || url.startsWith('https://')
          ? NetworkImage(url)
          : AssetImage(url) as ImageProvider;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          precacheImage(provider, context);
        }
      });
    }
  }

  Widget _buildDefaultLayout(
    BuildContext context,
    MusicPlayState state,
    MusicPlayController controller,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    // Top half (turntable + answer + playback bar) keeps the original page
    // padding. The bottom half – the piano keyboard, when shown – is rendered
    // edge-to-edge so it visually merges into the panel's bottom rounded
    // corners. When the keyboard is hidden the long-text panel reapplies the
    // standard padding so the original layout is preserved.
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), 0),
          child: Column(
            children: [
              SizedBox(
                height: ui(332),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: ui(320),
                      child: _TurntablePanel(
                        state: state,
                        onBack: () => Navigator.of(context).maybePop(),
                        onShare: controller.openShareDialog,
                      ),
                    ),
                    Container(
                      width: ui(1),
                      margin: EdgeInsets.only(left: ui(12), right: ui(14)),
                      color: const Color(0xFFF3F2F3),
                    ),
                    Expanded(
                      child: _AnswerPanel(
                        state: state,
                        onToggleAnswer: controller.setShowAnswer,
                        onImageChanged: controller.setImageIndex,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui(18)),
              _PlaybackBar(
                state: state,
                onSkipBackward: () => _skipSeconds(controller, state, -5),
                onTogglePlay: controller.togglePlay,
                onSkipForward: () => _skipSeconds(controller, state, 5),
                onSeekRatio: (ratio) {
                  final target = Duration(
                    milliseconds: (state.duration.inMilliseconds * ratio)
                        .round(),
                  );
                  controller.seek(target);
                },
                onSpeedChanged: controller.setPlaybackSpeed,
                onToggleFavorite: controller.toggleFavorite,
              ),
              SizedBox(height: ui(12)),
            ],
          ),
        ),
        Expanded(
          child: state.showsKeyboard
              ? PianoKeyboard(
                  activeNotes: state.activePianoNotes,
                  onPress: controller.pressPianoKey,
                  onRelease: controller.releasePianoKey,
                  height: 220,
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(ui(12), 0, ui(12), ui(12)),
                  child: _LongTextPanel(
                    htmlText: state.detail?.longTextHtml ?? '',
                  ),
                ),
        ),
      ],
    );
  }

  /// 声乐/器乐布局：左侧为转盘 + 简介卡片，右侧为乐谱（五线谱/简谱）。
  /// 没有底部钢琴/长文区域；播放控制条沉到页面底部。
  Widget _buildVocalLayout(
    BuildContext context,
    MusicPlayState state,
    MusicPlayController controller,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: ui(320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TurntablePanel(
                      state: state,
                      onBack: () => Navigator.of(context).maybePop(),
                      onShare: controller.openShareDialog,
                    ),
                    SizedBox(height: ui(12)),
                    Expanded(
                      child: _DescriptionCard(
                        htmlText: state.detail?.longTextHtml ?? '',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: ui(1),
                margin: EdgeInsets.only(left: ui(12), right: ui(14)),
                color: const Color(0xFFF3F2F3),
              ),
              Expanded(
                child: _AnswerPanel(
                  state: state,
                  onToggleAnswer: controller.setShowAnswer,
                  onImageChanged: controller.setImageIndex,
                  useStaffSimplifiedToggle: true,
                  onTranspose: () {
                    AppToast.show(context, '升降调功能即将上线');
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ui(18)),
        _PlaybackBar(
          state: state,
          onSkipBackward: () => _skipSeconds(controller, state, -5),
          onTogglePlay: controller.togglePlay,
          onSkipForward: () => _skipSeconds(controller, state, 5),
          onSeekRatio: (ratio) {
            final target = Duration(
              milliseconds: (state.duration.inMilliseconds * ratio).round(),
            );
            controller.seek(target);
          },
          onSpeedChanged: controller.setPlaybackSpeed,
          onToggleFavorite: controller.toggleFavorite,
        ),
      ],
    );
  }

  Future<void> _skipSeconds(
    MusicPlayController controller,
    MusicPlayState state,
    int deltaSeconds,
  ) async {
    final maxMs = state.duration.inMilliseconds;
    final currentMs = state.position.inMilliseconds;
    final targetMs = maxMs > 0
        ? (currentMs + deltaSeconds * 1000).clamp(0, maxMs)
        : math.max(0, currentMs + deltaSeconds * 1000);
    await controller.seek(Duration(milliseconds: targetMs));
  }

  Future<void> _showShareDialog(
    BuildContext context,
    MusicPlayPageArgs args,
  ) async {
    if (!mounted) {
      return;
    }
    final scale = DashboardScaleScope.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: true,
      barrierLabel: '关闭分享',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DashboardScaleScope(
          data: scale,
          child: _ShareDrawer(args: args),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref.read(musicPlayControllerProvider(args).notifier).closeShareDialog();
    }
  }
}

class _ShareDrawer extends ConsumerWidget {
  const _ShareDrawer({required this.args});

  final MusicPlayPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayControllerProvider(args));
    final controller = ref.read(musicPlayControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: ui(600),
          height: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DrawerTitle(title: '分享课件'),
                SizedBox(height: ui(20)),
                const Divider(height: 1, color: Color(0xFFF3F2F3)),
                SizedBox(height: ui(24)),
                _ShareTargetCard(detail: state.detail),
                SizedBox(height: ui(28)),
                Text(
                  '您的班级群',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: ui(16)),
                Expanded(
                  child: state.classLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.classList.isEmpty
                      ? const _ShareDrawerEmpty()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: state.classList.length,
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemBuilder: (context, index) {
                            final cls = state.classList[index];
                            return _ClassRow(
                              cls: cls,
                              onTap: () => controller.toggleClass(cls.id),
                            );
                          },
                        ),
                ),
                SizedBox(height: ui(12)),
                _SendButton(
                  loading: state.sending,
                  onTap: () async {
                    final success = await controller.sendShare();
                    if (!context.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTitle extends StatelessWidget {
  const _DrawerTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF8741FF),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ShareTargetCard extends StatelessWidget {
  const _ShareTargetCard({required this.detail});

  final MusicPlayDetail? detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final coverUrl = detail?.coverUrl ?? '';
    final imageProvider =
        coverUrl.startsWith('http://') || coverUrl.startsWith('https://')
        ? NetworkImage(coverUrl)
        : (coverUrl.isNotEmpty ? AssetImage(coverUrl) : null) as ImageProvider?;

    return Container(
      height: ui(106),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '您将分享的课件',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(10)),
                Text(
                  detail?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: ui(75.76),
            height: ui(55.27),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1E8FD), Color(0xFFDDC4FF)],
              ),
              borderRadius: BorderRadius.circular(ui(6.82)),
            ),
            child: imageProvider == null
                ? const Icon(
                    Icons.library_music_rounded,
                    color: Color(0xFFA773FF),
                  )
                : Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.library_music_rounded,
                      color: Color(0xFFA773FF),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.onTap});

  final MusicPlayShareClass cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checked = cls.checked;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Container(
          height: ui(80),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              Container(
                width: ui(24),
                height: ui(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFCECED1),
                    width: 1,
                  ),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: ui(16),
                        color: const Color(0xFF8741FF),
                      )
                    : null,
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: Text(
                  cls.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareDrawerEmpty extends StatelessWidget {
  const _ShareDrawerEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Text(
        '暂无班级群',
        style: TextStyle(
          color: const Color(0xFFB6B5BB),
          fontSize: ui(14),
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: loading
            ? SizedBox(
                width: ui(20),
                height: ui(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 24 / 14,
                ),
              ),
      ),
    );
  }
}

class _TurntablePanel extends StatelessWidget {
  const _TurntablePanel({
    required this.state,
    required this.onBack,
    required this.onShare,
  });

  final MusicPlayState state;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            _SecondaryChipButton(
              iconAsset: 'assets/images/home/dictation/10.png',
              label: '分享',
              onTap: onShare,
            ),
          ],
        ),
        SizedBox(height: ui(22)),
        Center(child: _TurntableDisc(playing: state.isPlaying)),
        SizedBox(height: ui(14)),
        Center(
          child: Container(
            width: ui(129),
            height: ui(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              child: _MarqueeTitleText(
                text: detail?.title ?? '未命名听写',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: ui(11),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 18 / 11,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: ui(16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(22)),
          child: RepaintBoundary(
            child: _FrequencyVisualizer(
              frequencyBands: state.frequencyBands,
              playing: state.isPlaying,
              height: ui(38),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarqueeTitleText extends StatefulWidget {
  const _MarqueeTitleText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MarqueeTitleText> createState() => _MarqueeTitleTextState();
}

class _MarqueeTitleTextState extends State<_MarqueeTitleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _durationMs = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _MarqueeTitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final gap = ui(28);
    final pixelsPerSecond = ui(40);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        final textWidth = painter.width;
        final viewportWidth = constraints.maxWidth;

        if (widget.text.isEmpty || viewportWidth <= 0) {
          _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: widget.style,
          );
        }

        final textSlotWidth = math.max(textWidth, viewportWidth);
        final distance = textSlotWidth + gap;
        final durationMs = math.max(
          1800,
          (distance / pixelsPerSecond * 1000).round(),
        );
        _ensureScrolling(durationMs);

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final left = -distance * _controller.value;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  _buildPositionedText(left, textSlotWidth),
                  _buildPositionedText(left + distance, textSlotWidth),
                  _buildPositionedText(left + distance * 2, textSlotWidth),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _ensureScrolling(int durationMs) {
    if (_durationMs == durationMs && _controller.isAnimating) {
      return;
    }
    _durationMs = durationMs;
    _controller.duration = Duration(milliseconds: durationMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    });
  }

  Widget _buildPositionedText(double left, double width) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: widget.style,
        ),
      ),
    );
  }
}

class _TurntableDisc extends StatelessWidget {
  const _TurntableDisc({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(180),
      height: ui(180),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/home/plyabj.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: ui(102),
            top: ui(10),
            child: AnimatedRotation(
              turns: playing ? 0 : -0.075,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              alignment: const Alignment(0.64, -0.79),
              child: Image.asset(
                'assets/images/home/play1.png',
                width: ui(65),
                height: ui(138),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPanel extends StatefulWidget {
  const _AnswerPanel({
    required this.state,
    required this.onToggleAnswer,
    required this.onImageChanged,
    this.useStaffSimplifiedToggle = false,
    this.onTranspose,
  });

  final MusicPlayState state;
  final ValueChanged<bool> onToggleAnswer;
  final ValueChanged<int> onImageChanged;

  /// 声乐/器乐课程使用 五线谱/简谱 切换；其他课程使用 关闭/答案。
  final bool useStaffSimplifiedToggle;

  /// 是否显示左上角"升降调"按钮（仅声乐/器乐）。
  final VoidCallback? onTranspose;

  @override
  State<_AnswerPanel> createState() => _AnswerPanelState();
}

class _AnswerPanelState extends State<_AnswerPanel> {
  final Set<int> _failedImageIndexes = <int>{};
  List<String> _lastImages = const <String>[];

  @override
  void didUpdateWidget(covariant _AnswerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final images = widget.state.visibleImages;
    if (!_listEquals(images, _lastImages)) {
      _lastImages = List<String>.from(images);
      _failedImageIndexes.clear();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _markImageFailed(int index) {
    if (_failedImageIndexes.contains(index)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _failedImageIndexes.add(index);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = widget.state;
    final images = state.visibleImages;
    if (!_listEquals(images, _lastImages)) {
      _lastImages = List<String>.from(images);
      _failedImageIndexes.clear();
    }
    final activeIndex = state.activeImageIndex.clamp(
      0,
      math.max(0, images.length - 1),
    );
    final showCounter =
        images.isNotEmpty && !_failedImageIndexes.contains(activeIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            if (widget.onTranspose != null) ...[
              _OutlinedChipButton(
                iconAsset: 'assets/images/home/dictation/9.png',
                label: '升降调',
                onTap: widget.onTranspose!,
              ),
              SizedBox(width: ui(10)),
            ],
            Container(
              height: ui(28),
              padding: EdgeInsets.all(ui(2)),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Row(
                children: widget.useStaffSimplifiedToggle
                    ? [
                        _TogglePill(
                          label: '五线谱',
                          active: state.showAnswer,
                          onTap: () => widget.onToggleAnswer(true),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '简谱',
                          active: !state.showAnswer,
                          onTap: () => widget.onToggleAnswer(false),
                        ),
                      ]
                    : [
                        _TogglePill(
                          label: '关闭',
                          active: !state.showAnswer,
                          onTap: () => widget.onToggleAnswer(false),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '答案',
                          active: state.showAnswer,
                          onTap: () => widget.onToggleAnswer(true),
                        ),
                      ],
              ),
            ),
          ],
        ),
        SizedBox(height: ui(18)),
        Expanded(
          child: images.isEmpty
              ? _AnswerEmptyState(
                  useStaffSimplifiedToggle: widget.useStaffSimplifiedToggle,
                  showStaff: state.showAnswer,
                )
              : Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: widget.onImageChanged,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        final failed = _failedImageIndexes.contains(index);
                        // 答案图保留原始细节：宽度铺满，超出高度允许上下滑动查看；
                        // 双击仍可调起全屏画廊（PhotoView）做缩放/拖拽。
                        if (failed) {
                          return _AnswerEmptyState(
                            useStaffSimplifiedToggle:
                                widget.useStaffSimplifiedToggle,
                            showStaff: state.showAnswer,
                          );
                        }
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: ui(16)),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: () => showImageGallery(
                              context,
                              images: images,
                              initialIndex: index,
                              heroTagPrefix: 'music_play_answer',
                            ),
                            child: Scrollbar(
                              thumbVisibility: false,
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.only(bottom: ui(36)),
                                child: Hero(
                                  tag: 'music_play_answer_${image}_$index',
                                  child: Image.network(
                                    image,
                                    width: double.infinity,
                                    fit: BoxFit.fitWidth,
                                    errorBuilder: (context, error, stackTrace) {
                                      _markImageFailed(index);
                                      return Center(
                                        child: _AnswerEmptyState(
                                          useStaffSimplifiedToggle:
                                              widget.useStaffSimplifiedToggle,
                                          showStaff: state.showAnswer,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (showCounter)
                      Positioned(
                        right: ui(10),
                        bottom: ui(6),
                        child: Container(
                          height: ui(24),
                          padding: EdgeInsets.symmetric(horizontal: ui(8)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F2F3),
                            borderRadius: BorderRadius.circular(ui(6)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${activeIndex + 1}/${images.length}',
                            style: TextStyle(
                              color: const Color(0xFF0B081A),
                              fontSize: ui(12),
                              fontFamily: 'PingFang SC',
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AnswerEmptyState extends StatelessWidget {
  const _AnswerEmptyState({
    this.useStaffSimplifiedToggle = false,
    this.showStaff = true,
  });

  final bool useStaffSimplifiedToggle;
  final bool showStaff;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = useStaffSimplifiedToggle
        ? (showStaff ? 'assets/images/404/wx.png' : 'assets/images/404/jp.png')
        : 'assets/images/home/dictation/8.png';
    final isStaffMode = useStaffSimplifiedToggle;
    final message = isStaffMode
        ? (showStaff ? '暂无五线谱' : '暂无简谱')
        : '同学加油！不看答案的样子真的很棒！';
    final messageStyle = isStaffMode
        ? TextStyle(
            color: const Color.fromARGB(255, 22, 22, 22),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
          )
        : TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(13),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 2 / 13,
          );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            width: ui(200),
            height: ui(200),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(0)),
          isStaffMode
              ? Text(message, style: messageStyle)
              : Transform.translate(
                  offset: Offset(0, -ui(25)),
                  child: Text(message, style: messageStyle),
                ),
        ],
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.state,
    required this.onSkipBackward,
    required this.onTogglePlay,
    required this.onSkipForward,
    required this.onSeekRatio,
    required this.onSpeedChanged,
    required this.onToggleFavorite,
  });

  final MusicPlayState state;
  final Future<void> Function() onSkipBackward;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function() onSkipForward;
  final ValueChanged<double> onSeekRatio;
  final ValueChanged<double> onSpeedChanged;
  final Future<void> Function() onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;
    final track = state.activeTrack;
    final durationMs = math.max(state.duration.inMilliseconds, 1);
    final ratio = (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    final favorite = detail?.favorite == true;

    return Container(
      height: ui(72),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: ui(12)),
          Container(
            width: ui(48),
            height: ui(48),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: detail?.coverUrl.isNotEmpty == true
                ? Image.network(
                    detail!.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/home/feng.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset('assets/images/home/feng.png', fit: BoxFit.cover),
          ),
          SizedBox(width: ui(12)),
          SizedBox(
            width: ui(70),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail?.title ?? '未命名音频',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(15),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: ui(6)),
                Text(
                  track?.title ?? '听写',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 12 / 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(67)),
          _InlineImageIcon(
            asset: 'assets/images/home/left.png',
            onTap: onSkipBackward,
            size: 24,
          ),
          SizedBox(width: ui(8)),
          GestureDetector(
            onTap: onTogglePlay,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: ui(44),
              height: ui(44),
              child: Center(
                child: Container(
                  width: ui(36.67),
                  height: ui(36.67),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8741FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: ui(22),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          _InlineImageIcon(
            asset: 'assets/images/home/right.png',
            onTap: onSkipForward,
            size: 24,
          ),
          SizedBox(width: ui(12)),
          _SpeedChip(speed: state.speed, onSpeedChanged: onSpeedChanged),
          SizedBox(width: ui(14)),
          Expanded(
            child: _ProgressTrack(
              ratio: ratio,
              durationLabel:
                  '${_formatDuration(state.position)}/${_formatDuration(state.duration)}',
              onSeekRatio: onSeekRatio,
            ),
          ),
          SizedBox(width: ui(19)),
          GestureDetector(
            onTap: onToggleFavorite,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: ui(24),
                  color: favorite
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFB6B5BB),
                ),
                SizedBox(width: ui(4)),
                Text(
                  '收藏',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 12 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    if (value == Duration.zero) {
      return '00:00';
    }
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 进度条与时间标签：上方右对齐显示 `当前/总时长`，下方为带紫色渐变填充与圆形
/// thumb 的轨道。相比一开始的版本去掉了左侧当前时间，并将右侧时间整体下移
/// 约 10px（通过收紧时间行与滑块之间的间距实现）。
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.ratio,
    required this.durationLabel,
    required this.onSeekRatio,
  });

  final double ratio;
  final String durationLabel;
  final ValueChanged<double> onSeekRatio;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: ui(0)),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              durationLabel,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 3 / 8,
              ),
            ),
          ),
        ),
        SizedBox(height: ui(4)),
        _GradientSlider(ratio: ratio, onSeekRatio: onSeekRatio),
      ],
    );
  }
}

/// 自绘的紫色渐变进度条（带阴影 thumb），不依赖 Material Slider，
/// 以严格匹配设计稿中 #E2D0FF → #8741FF 的渐变填充与 12×12 thumb。
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({required this.ratio, required this.onSeekRatio});

  final double ratio;
  final ValueChanged<double> onSeekRatio;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trackHeight = ui(4);
    final thumbSize = ui(12);
    final hitHeight = ui(20);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final clamped = ratio.clamp(0.0, 1.0);
        final fillWidth = width * clamped;
        final thumbLeft = (width - thumbSize) * clamped;

        void emit(Offset localPosition) {
          if (width <= 0) return;
          final r = (localPosition.dx / width).clamp(0.0, 1.0);
          onSeekRatio(r);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => emit(d.localPosition),
          onHorizontalDragStart: (d) => emit(d.localPosition),
          onHorizontalDragUpdate: (d) => emit(d.localPosition),
          child: SizedBox(
            height: hitHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E2E5),
                    borderRadius: BorderRadius.circular(ui(23)),
                  ),
                ),
                Container(
                  height: trackHeight,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
                    ),
                    borderRadius: BorderRadius.circular(ui(23)),
                  ),
                ),
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8741FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          offset: const Offset(0, 4),
                          blurRadius: 4,
                        ),
                      ],
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

class _LongTextPanel extends StatelessWidget {
  const _LongTextPanel({required this.htmlText});

  final String htmlText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(18)),
      decoration: BoxDecoration(
        color: const Color(0xFF101218),
        borderRadius: BorderRadius.circular(ui(14)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SelectableText(
          htmlText
              .replaceAll(RegExp(r'<[^>]+>'), ' ')
              .replaceAll('&nbsp;', ' '),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: ui(14),
            height: 1.7,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

/// 声乐/器乐课程左侧使用的浅色简介卡片。
/// 复用 detail.longTextHtml，剥离 HTML 标签后展示。
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.htmlText});

  final String htmlText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final plain = htmlText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SelectableText(
                plain.isEmpty ? '暂无简介' : plain,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 26 / 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

class _SecondaryChipButton extends StatelessWidget {
  const _SecondaryChipButton({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onTap,
  }) : assert(
         icon != null || iconAsset != null,
         'Either icon or iconAsset must be provided',
       );

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final leading = iconAsset != null
        ? Image.asset(
            iconAsset!,
            width: ui(20),
            height: ui(20),
            fit: BoxFit.contain,
          )
        : Icon(icon!, size: ui(16), color: const Color(0xFF1C274C));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          children: [
            leading,
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 白底描边的 chip 按钮，对应图稿"升降调"等次要操作。
class _OutlinedChipButton extends StatelessWidget {
  const _OutlinedChipButton({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.fromLTRB(ui(12), ui(4), ui(13), ui(4)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(50),
        height: ui(24),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8741FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFB6B5BB),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _InlineImageIcon extends StatelessWidget {
  const _InlineImageIcon({
    required this.asset,
    required this.onTap,
    this.size = 19,
  });

  final String asset;
  final Future<void> Function() onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: ui(size),
        height: ui(size),
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 倍速选择 chip。点击后唤起一个极简风格的下拉浮窗：
/// - 白底、圆角 12、柔和阴影
/// - 选项行高紧凑、文字居中
/// - 当前倍速文字使用品牌紫并加粗
class _SpeedChip extends StatefulWidget {
  const _SpeedChip({required this.speed, required this.onSpeedChanged});

  final double speed;
  final ValueChanged<double> onSpeedChanged;

  static const List<double> options = <double>[2.0, 1.5, 1.25, 1.0, 0.75, 0.5];

  static String formatSpeed(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) {
        text = '${text}0';
      }
    }
    return '${text}x';
  }

  @override
  State<_SpeedChip> createState() => _SpeedChipState();
}

class _SpeedChipState extends State<_SpeedChip> {
  bool _open = false;

  Future<void> _showMenu(BuildContext context) async {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final double menuWidth = ui(96);
    final double itemHeight = ui(34);
    final double padding = ui(6);
    final double menuHeight =
        _SpeedChip.options.length * itemHeight + padding * 2;
    final double gap = ui(8);

    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final Size overlaySize = overlay.size;

    double left = topLeft.dx + (size.width - menuWidth) / 2;
    left = left.clamp(ui(8), overlaySize.width - menuWidth - ui(8));
    final double topAbove = topLeft.dy - menuHeight - gap;
    final double topBelow = topLeft.dy + size.height + gap;
    final bool above = topAbove >= ui(8);
    final double top = above ? topAbove : topBelow;

    setState(() => _open = true);

    final selected = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'speed_menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondary) {
        return DashboardScaleScope(
          data: scale,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                child: _SpeedMenuCard(
                  options: _SpeedChip.options,
                  current: widget.speed,
                  itemHeight: itemHeight,
                  padding: padding,
                  onPick: (value) => Navigator.of(dialogContext).pop(value),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final offsetTween = above
            ? Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetTween.animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() => _open = false);
    if (selected != null && selected != widget.speed) {
      widget.onSpeedChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMenu(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          color: _open ? const Color(0xFFF5F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _SpeedChip.formatSpeed(widget.speed),
              style: TextStyle(
                color: _open
                    ? const Color(0xFF8741FF)
                    : const Color(0xFF7F7F7F),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 12 / 12,
              ),
            ),
            SizedBox(width: ui(2)),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              turns: _open ? 0.5 : 0,
              child: Image.asset(
                'assets/images/home/chevron-down.png',
                width: ui(12),
                height: ui(12),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedMenuCard extends StatelessWidget {
  const _SpeedMenuCard({
    required this.options,
    required this.current,
    required this.itemHeight,
    required this.padding,
    required this.onPick,
  });

  final List<double> options;
  final double current;
  final double itemHeight;
  final double padding;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8741FF).withValues(alpha: 0.10),
              blurRadius: ui(20),
              spreadRadius: 0,
              offset: Offset(0, ui(8)),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: ui(8),
              spreadRadius: 0,
              offset: Offset(0, ui(2)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in options)
              _SpeedMenuItem(
                label: _SpeedChip.formatSpeed(value),
                height: itemHeight,
                selected: value == current,
                onTap: () => onPick(value),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedMenuItem extends StatefulWidget {
  const _SpeedMenuItem({
    required this.label,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SpeedMenuItem> createState() => _SpeedMenuItemState();
}

class _SpeedMenuItemState extends State<_SpeedMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = widget.selected;
    final highlighted = selected || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          margin: EdgeInsets.symmetric(horizontal: ui(6)),
          padding: EdgeInsets.symmetric(horizontal: ui(10)),
          decoration: BoxDecoration(
            color: highlighted ? const Color(0xFFF5F2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF8741FF)
                        : const Color(0xFF0B081A),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: ui(14),
                  color: const Color(0xFF8741FF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyVisualizer extends StatelessWidget {
  const _FrequencyVisualizer({
    required this.frequencyBands,
    required this.playing,
    required this.height,
  });

  final List<double> frequencyBands;
  final bool playing;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (frequencyBands.isNotEmpty || !playing) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FrequencyVisualizerPainter(
            frequencyBands: frequencyBands,
            time: 0,
            playing: playing,
          ),
        ),
      );
    }
    return _AnimatedFrequencyFallback(height: height);
  }
}

class _AnimatedFrequencyFallback extends StatefulWidget {
  const _AnimatedFrequencyFallback({required this.height});

  final double height;

  @override
  State<_AnimatedFrequencyFallback> createState() =>
      _AnimatedFrequencyFallbackState();
}

class _AnimatedFrequencyFallbackState extends State<_AnimatedFrequencyFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _FrequencyVisualizerPainter(
              frequencyBands: const <double>[],
              time: _controller.value,
              playing: true,
            ),
          );
        },
      ),
    );
  }
}

class _FrequencyVisualizerPainter extends CustomPainter {
  const _FrequencyVisualizerPainter({
    required this.frequencyBands,
    required this.time,
    required this.playing,
  });

  final List<double> frequencyBands;
  final double time;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final count = frequencyBands.isEmpty ? 46 : frequencyBands.length;
    const gap = 3.0;
    final barWidth = math.max(1.2, (size.width - gap * (count - 1)) / count);
    final centerY = size.height * 0.62;
    final maxUp = size.height * 0.58;
    final maxDown = size.height * 0.30;
    final radius = Radius.circular(barWidth / 2);
    final idlePaint = Paint()..color = const Color(0xFFE4E1EC);

    for (var i = 0; i < count; i++) {
      final raw = frequencyBands.isEmpty
          ? (playing ? _fallbackLevel(i, count, time) : 0.0)
          : frequencyBands[i];
      final level = raw.clamp(0.0, 1.0);
      final x = i * (barWidth + gap);
      final up = math.max(size.height * 0.08, maxUp * level);
      final down = math.max(size.height * 0.03, maxDown * level);
      final active = level > 0.015;

      final topRect = Rect.fromLTRB(x, centerY - up, x + barWidth, centerY);
      final topPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF8741FF), Color(0xFFC8AEFF)],
              ).createShader(topRect))
          : idlePaint;
      canvas.drawRRect(RRect.fromRectAndRadius(topRect, radius), topPaint);

      final bottomRect = Rect.fromLTRB(
        x,
        centerY,
        x + barWidth,
        centerY + down,
      );
      final bottomPaint = active
          ? (Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x668741FF), Color(0x00C8AEFF)],
              ).createShader(bottomRect))
          : idlePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bottomRect, radius),
        bottomPaint,
      );
    }
  }

  double _fallbackLevel(int index, int count, double t) {
    final phase = t * math.pi * 2;
    final waveA = math.sin(phase * 1.4 + index * 0.52);
    final waveB = math.sin(phase * 2.1 + index * 0.21);
    final envelope = math.sin(index / (count - 1) * math.pi);
    return (0.18 + (waveA * 0.18 + waveB * 0.12 + 0.30) * envelope).clamp(
      0.04,
      0.88,
    );
  }

  @override
  bool shouldRepaint(covariant _FrequencyVisualizerPainter oldDelegate) {
    return oldDelegate.frequencyBands != frequencyBands ||
        oldDelegate.time != time ||
        oldDelegate.playing != playing;
  }
}

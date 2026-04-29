import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/image_gallery_viewer.dart';
import '../../piano/ui/piano_keyboard.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/music_play_controller.dart';
import '../state/music_play_state.dart';

class MusicPlayPage extends ConsumerWidget {
  const MusicPlayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = MusicPlayPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    final state = ref.watch(musicPlayControllerProvider(args));
    final controller = ref.read(musicPlayControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<MusicPlayState>(musicPlayControllerProvider(args), (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      controller.clearError();
    });

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      child: state.loading && !state.hasDetail
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (state.isVocalOrInstrumental
                ? _buildVocalLayout(context, state, controller)
                : _buildDefaultLayout(context, state, controller)),
    );
  }

  Widget _buildDefaultLayout(
    BuildContext context,
    MusicPlayState state,
    MusicPlayController controller,
  ) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
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
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分享功能稍后补齐')),
                    );
                  },
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
          onPrevious: controller.previous,
          onTogglePlay: controller.togglePlay,
          onNext: controller.next,
          onSeekRatio: (ratio) {
            final target = Duration(
              milliseconds: (state.duration.inMilliseconds * ratio).round(),
            );
            controller.seek(target);
          },
          onSpeedChanged: controller.setPlaybackSpeed,
          onToggleFavorite: controller.toggleFavorite,
        ),
        SizedBox(height: ui(12)),
        Expanded(
          child: state.showsKeyboard
              ? PianoKeyboard(
                  activeNotes: state.activePianoNotes,
                  onPress: controller.pressPianoKey,
                  onRelease: controller.releasePianoKey,
                  height: 220,
                )
              : _LongTextPanel(htmlText: state.detail?.longTextHtml ?? ''),
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
                      onShare: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('分享功能稍后补齐')),
                        );
                      },
                    ),
                    SizedBox(height: ui(12)),
                    Expanded(
                      child: _DescriptionCard(
                        title: state.detail?.title ?? '',
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('升降调功能稍后补齐')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ui(18)),
        _PlaybackBar(
          state: state,
          onPrevious: controller.previous,
          onTogglePlay: controller.togglePlay,
          onNext: controller.next,
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
    final progress = state.duration.inMilliseconds == 0
        ? 0.0
        : state.position.inMilliseconds / state.duration.inMilliseconds;

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
        Center(
          child: _TurntableDisc(
            coverUrl: detail?.coverUrl ?? '',
            playing: state.isPlaying,
          ),
        ),
        SizedBox(height: ui(14)),
        Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: ui(160)),
            height: ui(24),
            padding: EdgeInsets.symmetric(horizontal: ui(18)),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4FF),
              borderRadius: BorderRadius.circular(ui(999)),
            ),
            alignment: Alignment.center,
            child: Text(
              detail?.title ?? '未命名听写',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(13),
                fontFamily: 'Harmony',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
        ),
        SizedBox(height: ui(16)),
        _MiniWaveform(progress: progress),
      ],
    );
  }
}

class _TurntableDisc extends StatelessWidget {
  const _TurntableDisc({required this.coverUrl, required this.playing});

  final String coverUrl;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(180),
      height: ui(180),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui(16)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD9DDE6), Color(0xFFC6CAD4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x24000000),
                  blurRadius: ui(12),
                  offset: Offset(0, ui(6)),
                ),
              ],
            ),
          ),
          Positioned(
            left: ui(18),
            top: ui(18),
            right: ui(18),
            bottom: ui(18),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF242833), Color(0xFF0B0E15)],
                ),
                border: Border.all(
                  color: const Color(0xFF9499A7),
                  width: ui(5),
                ),
              ),
            ),
          ),
          Positioned(
            left: ui(37),
            top: ui(37),
            right: ui(37),
            bottom: ui(37),
            child: AnimatedRotation(
              turns: playing ? 1 : 0,
              duration: const Duration(seconds: 8),
              curve: Curves.linear,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF856FE2),
                      Color(0x33201A20),
                      Color(0xFF856FE2),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(ui(22)),
                  child: ClipOval(
                    child: coverUrl.isEmpty
                        ? Container(
                            color: const Color(0xFF0A0D15),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFFFFD84D),
                              size: 40,
                            ),
                          )
                        : Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF0A0D15),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFFFFD84D),
                                  size: 40,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(11),
            top: ui(8),
            child: Container(
              width: ui(22),
              height: ui(22),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7B7D84), Color(0xFF45474D)],
                ),
              ),
              child: Center(
                child: Container(
                  width: ui(16),
                  height: ui(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1D2027),
                    border: Border.all(
                      color: const Color(0xFF626978),
                      width: ui(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(46),
            top: ui(18),
            child: Transform.rotate(
              angle: math.pi / 11,
              child: Container(
                width: ui(8),
                height: ui(124),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(99)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF9EA3AE), Color(0xFF2E3137)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: ui(60),
            bottom: ui(37),
            child: Transform.rotate(
              angle: -math.pi / 3.6,
              child: Container(
                width: ui(16),
                height: ui(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(4)),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF303133),
                      Color(0xFFA4A9B2),
                      Color(0xFF303133),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: ui(10),
            bottom: ui(10),
            child: Container(
              width: ui(28),
              height: ui(12),
              decoration: BoxDecoration(
                color: const Color(0xFFB8BCCC),
                borderRadius: BorderRadius.circular(ui(99)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: ui(7),
                  margin: EdgeInsets.only(right: ui(3)),
                  height: ui(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF856FE2),
                    borderRadius: BorderRadius.circular(ui(99)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final images = state.visibleImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            if (onTranspose != null) ...[
              _OutlinedChipButton(
                iconAsset: 'assets/images/home/dictation/9.png',
                label: '升降调',
                onTap: onTranspose!,
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
                children: useStaffSimplifiedToggle
                    ? [
                        _TogglePill(
                          label: '五线谱',
                          active: state.showAnswer,
                          onTap: () => onToggleAnswer(true),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '简谱',
                          active: !state.showAnswer,
                          onTap: () => onToggleAnswer(false),
                        ),
                      ]
                    : [
                        _TogglePill(
                          label: '关闭',
                          active: !state.showAnswer,
                          onTap: () => onToggleAnswer(false),
                        ),
                        SizedBox(width: ui(4)),
                        _TogglePill(
                          label: '答案',
                          active: state.showAnswer,
                          onTap: () => onToggleAnswer(true),
                        ),
                      ],
              ),
            ),
          ],
        ),
        SizedBox(height: ui(18)),
        Expanded(
          child: images.isEmpty
              ? const _AnswerEmptyState()
              : Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: onImageChanged,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        // 答案图保留原始细节：宽度铺满，超出高度允许上下滑动查看；
                        // 双击仍可调起全屏画廊（PhotoView）做缩放/拖拽。
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
                                      return SizedBox(
                                        height: ui(260),
                                        child: const _AnswerEmptyState(),
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
                          '${state.activeImageIndex + 1}/${images.length}',
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
  const _AnswerEmptyState();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/home/dictation/8.png',
            width: ui(200),
            height: ui(86),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(10)),
          Text(
            '同学加油，不看答案的样子真的很棒！',
            style: TextStyle(
              color: const Color(0xFFC9C6D8),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.state,
    required this.onPrevious,
    required this.onTogglePlay,
    required this.onNext,
    required this.onSeekRatio,
    required this.onSpeedChanged,
    required this.onToggleFavorite,
  });

  final MusicPlayState state;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function() onNext;
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

    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(36),
            height: ui(36),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: detail?.coverUrl.isNotEmpty == true
                ? Image.network(
                    detail!.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.music_note_rounded, color: Colors.white),
          ),
          SizedBox(width: ui(10)),
          SizedBox(
            width: ui(120),
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
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: ui(3)),
                Text(
                  track?.title ?? '听写',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(10),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _InlineIcon(icon: Icons.skip_previous_rounded, onTap: onPrevious),
          SizedBox(width: ui(6)),
          GestureDetector(
            onTap: onTogglePlay,
            child: Container(
              width: ui(28),
              height: ui(28),
              decoration: BoxDecoration(
                color: const Color(0xFF8741FF),
                borderRadius: BorderRadius.circular(ui(999)),
              ),
              child: Icon(
                state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: ui(18),
              ),
            ),
          ),
          SizedBox(width: ui(6)),
          _InlineIcon(icon: Icons.skip_next_rounded, onTap: onNext),
          SizedBox(width: ui(10)),
          PopupMenuButton<double>(
            initialValue: state.speed,
            padding: EdgeInsets.zero,
            onSelected: onSpeedChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0.75, child: Text('0.75x')),
              PopupMenuItem(value: 1.0, child: Text('1.0x')),
              PopupMenuItem(value: 1.25, child: Text('1.25x')),
              PopupMenuItem(value: 1.5, child: Text('1.5x')),
            ],
            child: Text(
              '${state.speed.toStringAsFixed(1)}×',
              style: TextStyle(
                color: const Color(0xFF6D6B75),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          SizedBox(width: ui(10)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: ui(3),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: ui(4)),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: const Color(0xFF9C6DFF),
                inactiveTrackColor: const Color(0xFFD9D6E9),
                thumbColor: const Color(0xFF8741FF),
              ),
              child: Slider(
                value: ratio,
                min: 0,
                max: 1,
                onChanged: onSeekRatio,
              ),
            ),
          ),
          SizedBox(width: ui(10)),
          Text(
            '${_formatDuration(state.position)}/${_formatDuration(state.duration)}',
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(11),
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: ui(12)),
          GestureDetector(
            onTap: onToggleFavorite,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  detail?.favorite == true
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: ui(18),
                  color: detail?.favorite == true
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFB6B5BB),
                ),
                SizedBox(width: ui(3)),
                Text(
                  detail?.favorite == true ? '已收藏' : '收藏',
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(11),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
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

/// 声乐/器乐课程左侧使用的浅色简介卡片：标题 + 长文本。
/// 复用 detail.longTextHtml，剥离 HTML 标签后展示。
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.title, required this.htmlText});

  final String title;
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
          Text(
            title.isEmpty ? '曲目简介' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(15),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
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

class _InlineIcon extends StatelessWidget {
  const _InlineIcon({required this.icon, required this.onTap});

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: ui(19), color: const Color(0xFF8741FF)),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const bars = <double>[
      6,
      9,
      12,
      16,
      14,
      8,
      5,
      4,
      6,
      8,
      10,
      12,
      16,
      10,
      8,
      6,
      5,
      4,
      6,
      8,
      12,
      14,
      16,
      12,
      10,
      8,
      6,
      5,
      4,
      7,
      10,
      12,
      11,
      8,
      6,
      5,
    ];

    return SizedBox(
      height: ui(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++)
            Container(
              width: ui(i == 0 ? 39 : 3),
              height: ui(bars[i]),
              margin: EdgeInsets.only(right: ui(3)),
              decoration: BoxDecoration(
                gradient: i == 0 || i / bars.length <= progress
                    ? const LinearGradient(
                        colors: [Color(0xFFE2D0FF), Color(0xFF8741FF)],
                      )
                    : null,
                color: i != 0 && i / bars.length > progress
                    ? const Color(0xFFD9D9D9)
                    : null,
                borderRadius: BorderRadius.circular(ui(9)),
              ),
            ),
        ],
      ),
    );
  }
}

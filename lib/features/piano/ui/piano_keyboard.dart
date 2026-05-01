import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import '../data/piano_key_specs.dart';

/// 全局共享的虚拟钢琴键盘组件。
///
/// 行为对齐 `the-road-of-music/pages/music/VirtualPiano.vue`：
///
/// - 35 白键 + 25 黑键的全键盘（C2-B6），可水平滚动。
/// - 顶部工具条：缩小、mini 预览滚动条、放大、显示/隐藏标签开关。
/// - 多指按下、跨键拖动（按下→滑入下一键自动 release 旧键 + press 新键）。
/// - 中央 C 红色高亮、可选简谱+音名标签。
///
/// 使用方只需提供 [activeNotes] 用于高亮显示，以及 [onPress]/[onRelease] 用于
/// 触发音频播放。Widget 内部维护缩放、滚动、标签开关等纯 UI 状态。
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    required this.activeNotes,
    required this.onPress,
    required this.onRelease,
    this.height = 220,
    this.borderRadius = 16,
    this.showChrome = true,
    this.minWhiteKeyWidth = 36,
    this.maxWhiteKeyWidth = 92,
    this.zoomStep = 8,
    this.initialWhiteKeyWidth,
    this.initialLabelsVisible = false,
    this.initialScrollToCenterC = true,
    this.whiteKeys = kPianoFullWhiteKeys,
    this.blackKeys = kPianoFullBlackKeys,
    super.key,
  });

  /// 当前被按下的 token 集合（如 {"C4", "F#4"}），用于渲染高亮。
  final Set<String> activeNotes;

  /// 按下回调，可异步（用于解锁音频上下文等）。
  final Future<void> Function(String token) onPress;

  /// 抬起回调，应保证幂等（同一 token 多次 release 不出错）。
  final void Function(String token) onRelease;

  /// 键盘内容（不含顶部工具条）的高度。
  final double height;

  /// 整体外框圆角。
  final double borderRadius;

  /// 是否显示顶部工具条（- / 滚动条 / + / 切换）。
  final bool showChrome;

  /// 白键宽度的最小/最大限制以及每次缩放步长。
  final double minWhiteKeyWidth;
  final double maxWhiteKeyWidth;
  final double zoomStep;

  /// 初始白键宽度。为 null 时按视口尽量铺满 17 个白键。
  final double? initialWhiteKeyWidth;

  /// 是否初始显示音名 / 简谱标签。
  final bool initialLabelsVisible;

  /// 初始是否将视口滚动到中央 C 附近。
  final bool initialScrollToCenterC;

  /// 自定义键位（默认全键盘 C2-B6）。
  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  /// 用 ScrollController 来双向同步：键盘滚动 ↔ mini 预览缩略图的 thumb。
  final ScrollController _scroll = ScrollController();

  /// pointerId → 当前所按 key token，用于跨键滑动时正确 release。
  final Map<int, String> _pointerToken = <int, String>{};

  /// 命中测试缓存。在 LayoutBuilder 阶段重建。
  final List<_KeyHitRect> _hitRects = <_KeyHitRect>[];

  /// 当前白键宽度（逻辑像素），决定整个键盘内容宽度。
  double? _whiteKeyWidth;

  late bool _labelsVisible;

  bool _appliedInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _labelsVisible = widget.initialLabelsVisible;
    _whiteKeyWidth = widget.initialWhiteKeyWidth;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _zoomIn() {
    if (_whiteKeyWidth == null) {
      return;
    }
    final next = math.min(
      _whiteKeyWidth! + widget.zoomStep,
      widget.maxWhiteKeyWidth,
    );
    if (next == _whiteKeyWidth) {
      return;
    }
    setState(() => _whiteKeyWidth = next);
  }

  void _zoomOut() {
    if (_whiteKeyWidth == null) {
      return;
    }
    final next = math.max(
      _whiteKeyWidth! - widget.zoomStep,
      widget.minWhiteKeyWidth,
    );
    if (next == _whiteKeyWidth) {
      return;
    }
    setState(() => _whiteKeyWidth = next);
  }

  void _toggleLabels() {
    setState(() => _labelsVisible = !_labelsVisible);
  }

  /// 让 scroll 跳到某个 token 居中。在缩放后用于保持视口稳定。
  void _scrollToToken(String token, {required double viewportWidth}) {
    final whiteKeys = widget.whiteKeys;
    final whiteKeyWidth = _whiteKeyWidth!;
    int idx = whiteKeys.indexWhere((k) => k.token == token);
    if (idx < 0) {
      // 黑键回退到所属白键
      final black = widget.blackKeys.firstWhere(
        (k) => k.token == token,
        orElse: () => widget.whiteKeys[kPianoCenterCWhiteIndex],
      );
      idx = black.afterWhiteIndex;
    }
    final contentWidth = whiteKeys.length * whiteKeyWidth;
    final maxOffset = math.max(0.0, contentWidth - viewportWidth);
    final target = (idx + 0.5) * whiteKeyWidth - viewportWidth / 2;
    final clamped = target.clamp(0.0, maxOffset);
    if (_scroll.hasClients) {
      _scroll.jumpTo(clamped);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final token = _hitTest(event.localPosition);
    if (token == null) {
      return;
    }
    _pointerToken[event.pointer] = token;
    widget.onPress(token);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final token = _hitTest(event.localPosition);
    final old = _pointerToken[event.pointer];
    if (token == old) {
      return;
    }
    if (old != null) {
      widget.onRelease(old);
    }
    if (token != null) {
      _pointerToken[event.pointer] = token;
      widget.onPress(token);
    } else {
      _pointerToken.remove(event.pointer);
    }
  }

  void _onPointerUpOrCancel(int pointer) {
    final token = _pointerToken.remove(pointer);
    if (token != null) {
      widget.onRelease(token);
    }
  }

  /// 命中测试：先黑键（在上层），后白键。
  ///
  /// `Listener` 位于 `SingleChildScrollView` 的内层 `SizedBox` 里，
  /// 其 `localPosition` 已包含滚动量（即内容坐标），不要再叠加 `scroll.offset`。
  String? _hitTest(Offset localPos) {
    final x = localPos.dx;
    final y = localPos.dy;
    // 黑键优先
    for (final hit in _hitRects) {
      if (!hit.isBlack) {
        continue;
      }
      if (hit.rect.contains(Offset(x, y))) {
        return hit.token;
      }
    }
    for (final hit in _hitRects) {
      if (hit.isBlack) {
        continue;
      }
      if (hit.rect.contains(Offset(x, y))) {
        return hit.token;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final chromeHeight = widget.showChrome ? ui(38) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 父级未限制高度时（比如直接放在 Column 里），用 widget.height 作为兜底，
        // 否则白键填满父级给到的全部高度。
        final fallbackTotal = ui(widget.height) + chromeHeight;
        final totalHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fallbackTotal;

        return SizedBox(
          height: totalHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui(widget.borderRadius)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0x1F111827),
                  blurRadius: ui(14),
                  offset: Offset(0, ui(8)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(widget.borderRadius)),
              child: Container(
                color: const Color(0xFF1A1C21),
                child: Column(
                  children: <Widget>[
                    if (widget.showChrome) _buildChrome(context, chromeHeight),
                    Expanded(child: _buildKeyboardArea(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChrome(BuildContext context, double height) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ui(10),
          vertical: ui(6),
        ),
        child: Row(
          children: [
            _PianoChromeImageButton(
              asset: 'assets/images/home/dictation/3.png',
              size: ui(26),
              onTap: _zoomOut,
              tooltip: '缩小',
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  return _PianoMiniScrollTrack(
                    whiteKeys: widget.whiteKeys,
                    blackKeys: widget.blackKeys,
                    contentWidth: (_whiteKeyWidth ?? 0) * widget.whiteKeys.length,
                    viewportWidth: _scroll.hasClients
                        ? _scroll.position.viewportDimension
                        : 0,
                    scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
                    onThumbDrag: (deltaFraction) {
                      if (!_scroll.hasClients) {
                        return;
                      }
                      final maxOffset = _scroll.position.maxScrollExtent;
                      final next = (_scroll.offset + deltaFraction * maxOffset)
                          .clamp(0.0, maxOffset);
                      _scroll.jumpTo(next);
                    },
                    onTrackTap: (fraction) {
                      if (!_scroll.hasClients) {
                        return;
                      }
                      final maxOffset = _scroll.position.maxScrollExtent;
                      _scroll.jumpTo((fraction * maxOffset).clamp(0.0, maxOffset));
                    },
                  );
                },
              ),
            ),
            SizedBox(width: ui(8)),
            _PianoChromeImageButton(
              asset: 'assets/images/home/dictation/4.png',
              size: ui(26),
              onTap: _zoomIn,
              tooltip: '放大',
            ),
            SizedBox(width: ui(8)),
            _PianoLabelToggle(
              active: _labelsVisible,
              onTap: _toggleLabels,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 视口宽度
        final viewport = constraints.maxWidth;
        // 默认白键宽度：尽量铺满 17 个键
        final whiteKeyWidth = _whiteKeyWidth ??= () {
          if (widget.initialWhiteKeyWidth != null) {
            return widget.initialWhiteKeyWidth!;
          }
          final guess = viewport / 17.0;
          return guess
              .clamp(widget.minWhiteKeyWidth, widget.maxWhiteKeyWidth)
              .toDouble();
        }();

        final contentWidth =
            math.max(viewport, whiteKeyWidth * widget.whiteKeys.length);
        final keysHeight = constraints.maxHeight;
        final blackKeyWidth = whiteKeyWidth * 0.62;
        final blackKeyHeight = keysHeight * 0.6;

        // 重建命中区
        _hitRects
          ..clear()
          ..addAll(_buildHitRects(
            whiteKeyWidth: whiteKeyWidth,
            blackKeyWidth: blackKeyWidth,
            blackKeyHeight: blackKeyHeight,
            keysHeight: keysHeight,
          ));

        // 应用初始滚动到中央 C
        if (!_appliedInitialScroll && widget.initialScrollToCenterC) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) {
              return;
            }
            _appliedInitialScroll = true;
            _scrollToToken('C4', viewportWidth: viewport);
          });
        }

        return ScrollConfiguration(
          behavior: const _PianoScrollBehavior(),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // 用户手指拖动用于按键滑奏（在 Listener 中处理），
            // 滚动只通过顶部 mini-thumb 控制。
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: contentWidth,
              height: keysHeight,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
                onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
                onPointerPanZoomEnd: (e) => _onPointerUpOrCancel(e.pointer),
                child: Stack(
                  children: <Widget>[
                    // 白键铺满整块区域
                    for (var i = 0; i < widget.whiteKeys.length; i++)
                      Positioned(
                        left: i * whiteKeyWidth,
                        top: 0,
                        width: whiteKeyWidth,
                        height: keysHeight,
                        child: _PianoWhiteKey(
                          spec: widget.whiteKeys[i],
                          index: i,
                          isPressed: widget.activeNotes
                              .contains(widget.whiteKeys[i].token),
                          showLabel: _labelsVisible,
                        ),
                      ),
                    // 黑键按比例占用上方 60%
                    for (final spec in widget.blackKeys)
                      Positioned(
                        left: (spec.afterWhiteIndex + 1) * whiteKeyWidth -
                            blackKeyWidth / 2,
                        top: 0,
                        width: blackKeyWidth,
                        height: blackKeyHeight,
                        child: _PianoBlackKey(
                          spec: spec,
                          isPressed: widget.activeNotes.contains(spec.token),
                          showLabel: _labelsVisible,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<_KeyHitRect> _buildHitRects({
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double blackKeyHeight,
    required double keysHeight,
  }) sync* {
    for (var i = 0; i < widget.whiteKeys.length; i++) {
      yield _KeyHitRect(
        token: widget.whiteKeys[i].token,
        rect: Rect.fromLTWH(
          i * whiteKeyWidth,
          0,
          whiteKeyWidth,
          keysHeight,
        ),
        isBlack: false,
      );
    }
    for (final spec in widget.blackKeys) {
      final left =
          (spec.afterWhiteIndex + 1) * whiteKeyWidth - blackKeyWidth / 2;
      yield _KeyHitRect(
        token: spec.token,
        rect: Rect.fromLTWH(left, 0, blackKeyWidth, blackKeyHeight),
        isBlack: true,
      );
    }
  }
}

class _KeyHitRect {
  const _KeyHitRect({
    required this.token,
    required this.rect,
    required this.isBlack,
  });

  final String token;
  final Rect rect;
  final bool isBlack;
}

/// 顶部圆形 chrome 按钮，使用 3.png / 4.png 资源。
class _PianoChromeImageButton extends StatelessWidget {
  const _PianoChromeImageButton({
    required this.asset,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  final String asset;
  final double size;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// 顶部 mini 缩略键盘 + 滚动条。
///
/// 视觉上是一条横排的小键盘，半透明 thumb 覆盖在当前可见区域上；
/// 拖动 thumb 或点击空白区都能改变滚动位置。
class _PianoMiniScrollTrack extends StatelessWidget {
  const _PianoMiniScrollTrack({
    required this.whiteKeys,
    required this.blackKeys,
    required this.contentWidth,
    required this.viewportWidth,
    required this.scrollOffset,
    required this.onThumbDrag,
    required this.onTrackTap,
  });

  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;
  final double contentWidth;
  final double viewportWidth;
  final double scrollOffset;

  /// 拖动 thumb 的相对偏移（占可滚动范围的比例 0..1）。
  final ValueChanged<double> onThumbDrag;

  /// 点击空白区跳到的位置（占可滚动范围的比例 0..1）。
  final ValueChanged<double> onTrackTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;

        // thumb 占比 / 位置
        final ratio = contentWidth <= 0
            ? 1.0
            : (viewportWidth / contentWidth).clamp(0.05, 1.0);
        final thumbWidth = trackWidth * ratio;
        final maxThumbOffset = math.max(0.0, trackWidth - thumbWidth);
        final maxScroll = math.max(0.0, contentWidth - viewportWidth);
        final thumbLeft =
            maxScroll <= 0 ? 0.0 : (scrollOffset / maxScroll) * maxThumbOffset;

        return SizedBox(
          height: ui(26),
          child: Stack(
            children: [
              // 5.png 风格的轨道背景
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (maxThumbOffset <= 0) {
                      return;
                    }
                    final localX = details.localPosition.dx - thumbWidth / 2;
                    final clamped = localX.clamp(0.0, maxThumbOffset);
                    onTrackTap(clamped / maxThumbOffset);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ui(6)),
                    child: _PianoMiniKeysStrip(
                      whiteKeys: whiteKeys,
                      blackKeys: blackKeys,
                    ),
                  ),
                ),
              ),
              // 透明 thumb：仅描边 + 微调亮度，便于看到下方 mini 键盘
              Positioned(
                left: thumbLeft,
                top: 0,
                bottom: 0,
                width: thumbWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (maxThumbOffset <= 0) {
                      return;
                    }
                    onThumbDrag(details.delta.dx / maxThumbOffset);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ui(6)),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: ui(1.0),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 顶部缩略图：把所有黑白键画成横向一条缩小版，用于背景。
class _PianoMiniKeysStrip extends StatelessWidget {
  const _PianoMiniKeysStrip({
    required this.whiteKeys,
    required this.blackKeys,
  });

  final List<PianoKeySpec> whiteKeys;
  final List<PianoKeySpec> blackKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final whiteW = w / whiteKeys.length;
        final blackW = whiteW * 0.62;
        final blackH = h * 0.62;
        return Stack(
          children: <Widget>[
            // 整体黑底
            Positioned.fill(
              child: Container(color: const Color(0xFF11141A)),
            ),
            // 白键缩略
            for (var i = 0; i < whiteKeys.length; i++)
              Positioned(
                left: i * whiteW + 0.5,
                top: 1,
                width: whiteW - 1,
                height: h - 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFFFDFEFF), Color(0xFFD7DAE6)],
                    ),
                  ),
                ),
              ),
            // 黑键缩略
            for (final b in blackKeys)
              Positioned(
                left: (b.afterWhiteIndex + 1) * whiteW - blackW / 2,
                top: 0,
                width: blackW,
                height: blackH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF2E323D), Color(0xFF0A0C12)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 显示 / 隐藏标签的 toggle。
///
/// - `active = false`（标签隐藏）→ 显示 `piano1.png`（暗色状态）
/// - `active = true`（标签显示）→ 显示 `piano2.png`（紫色高亮 C4 状态）
///
/// 两张图片之间做 200ms 淡入淡出切换，逻辑对齐 VirtualPiano.vue 的 `isShow` 开关。
class _PianoLabelToggle extends StatelessWidget {
  const _PianoLabelToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final height = ui(26);
    final width = ui(68);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // piano1.png — 标签隐藏状态（暗色）
            AnimatedOpacity(
              opacity: active ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Image.asset(
                'assets/images/home/piano1.png',
                fit: BoxFit.contain,
              ),
            ),
            // piano2.png — 标签显示状态（紫色高亮）
            AnimatedOpacity(
              opacity: active ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Image.asset(
                'assets/images/home/piano2.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个白键。
///
/// 还原 Figma 设计稿的两层堆叠结构：
/// - 后层（top: 5.71px）：暗色基底 #222A38 加底部白边，模拟键背阴影。
/// - 前层（top: 0）：白色渐变面，浅色描边，承载点击/标签。
class _PianoWhiteKey extends StatelessWidget {
  const _PianoWhiteKey({
    required this.spec,
    required this.index,
    required this.isPressed,
    required this.showLabel,
  });

  final PianoKeySpec spec;

  /// 白键在键盘中的下标（0 = C2，14 = C4 ……），用于 label 取颜色分组。
  final int index;
  final bool isPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final faceRadius = BorderRadius.only(
      topLeft: Radius.circular(ui(1.28)),
      topRight: Radius.circular(ui(1.28)),
      bottomLeft: Radius.circular(ui(7.67)),
      bottomRight: Radius.circular(ui(7.67)),
    );
    // 未按下：键面下边距 ~14px（露出底部暗边给 3D 厚度感）
    // 按下：键面下沉，只露 ~5px 暗边
    final faceBottomReserve = isPressed ? ui(4.55) : ui(13.96);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(0.5)),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // 后层：键背阴影底盘（top: 5.71, 高度铺到底）+ 底部白色脚线
          Positioned(
            left: 0,
            right: 0,
            top: ui(5.71),
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: faceRadius,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x33222A38), Color(0x33CFD6F6)],
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: ui(1.3)),
                ),
              ),
            ),
          ),
          // 前层：白键键面（按下时下沉、变深、加内阴影）
          AnimatedPositioned(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: 0,
            bottom: faceBottomReserve,
            child: isPressed
                ? _PianoWhiteKeyPressedFace(
                    faceRadius: faceRadius,
                    showLabel: showLabel,
                    spec: spec,
                    index: index,
                  )
                : _PianoWhiteKeyIdleFace(
                    faceRadius: faceRadius,
                    showLabel: showLabel,
                    spec: spec,
                    index: index,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 未按下的白键面：保持最早的简洁白色 + 微弱阴影
class _PianoWhiteKeyIdleFace extends StatelessWidget {
  const _PianoWhiteKeyIdleFace({
    required this.faceRadius,
    required this.showLabel,
    required this.spec,
    required this.index,
  });

  final BorderRadius faceRadius;
  final bool showLabel;
  final PianoKeySpec spec;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: faceRadius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFF1F2F8),
            Color(0xFFD8DBE6),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFEFF7FF),
          width: ui(0.6),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14111827),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: showLabel
          ? Padding(
              padding: EdgeInsets.only(bottom: ui(10)),
              child: _PianoWhiteKeyLabel(spec: spec, index: index),
            )
          : null,
    );
  }
}

/// 按下态白键面：底色 #A4ABB7 + 多层冷光叠加 + 顶部内阴影
class _PianoWhiteKeyPressedFace extends StatelessWidget {
  const _PianoWhiteKeyPressedFace({
    required this.faceRadius,
    required this.showLabel,
    required this.spec,
    required this.index,
  });

  final BorderRadius faceRadius;
  final bool showLabel;
  final PianoKeySpec spec;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: faceRadius,
      child: Stack(
        children: <Widget>[
          // 1. 底色 #A4ABB7
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFFA4ABB7)),
          ),
          // 2. 自上而下：深蓝 → 冷白（gradient #4，47% 透明）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x78131B38),
                    Color(0x78CFD7F7),
                  ],
                ),
              ),
            ),
          ),
          // 3. 自上透明 → 下方淡紫光（gradient #3）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00DDD7FF),
                    Color(0x70DDD7FF),
                  ],
                ),
              ),
            ),
          ),
          // 4. 高光横带（gradient #2）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00FFFFFF),
                    Color(0x26FFFFFF),
                    Color(0x36FFFFFF),
                    Color(0x2BFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: <double>[0.0, 0.23, 0.30, 0.50, 1.0],
                ),
              ),
            ),
          ),
          // 5. 整体冷蓝薄雾（gradient #1，9% 透明度）
          const Positioned.fill(
            child: ColoredBox(color: Color(0x179EA9CE)),
          ),
          // 6. 顶部内阴影模拟（box-shadow inset）
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: ui(36),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xB35E667F),
                    Color(0x005E667F),
                  ],
                ),
              ),
            ),
          ),
          // 7. 描边
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: faceRadius,
                border: Border.all(
                  color: const Color(0xFFE9F0F6),
                  width: ui(0.64),
                ),
              ),
            ),
          ),
          // 8. 标签
          if (showLabel)
            Positioned(
              left: 0,
              right: 0,
              bottom: ui(10),
              child: _PianoWhiteKeyLabel(spec: spec, index: index),
            ),
        ],
      ),
    );
  }
}

/// 白键标签。布局严格对齐 1.0 Vue（VirtualPiano.vue + notes.js）：
///
/// ```
///  ┌─────────────┐
///  │   [c¹]      │  ← 顶部音名胶囊（colored pill，中央 C 特殊高亮）
///  │     ⋅       │  ← 高八度点（octaveDots > 0，画在数字上方）
///  │     1       │  ← 简谱 1..7
///  │     ⋅       │  ← 低八度点（octaveDots < 0，画在数字下方）
///  └─────────────┘
/// ```
///
/// 音名规则（来自 Vue 的 name2/name3）：
/// - 大字组（C2-B2）：大写字母 `C`/`D`/...
/// - 小字组（C3-B3）：小写字母 `c`/`d`/...
/// - 小字一/二/三组（C4+）：小写字母 + 上标数字（C4→`c¹`，C5→`c²`，C6→`c³`）。
///
/// 胶囊背景按白键下标分 5 组（与 `bgComputed` 一致），中央 C 单独使用高亮色。
class _PianoWhiteKeyLabel extends StatelessWidget {
  const _PianoWhiteKeyLabel({required this.spec, required this.index});

  final PianoKeySpec spec;

  /// 白键在键盘中的下标（0..34）。
  final int index;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    // ---- 解析 token "C4" / "F#3" → 字母 + 八度 ----
    final octave =
        int.tryParse(spec.token.substring(spec.token.length - 1)) ?? 4;
    final rawLetter = spec.token
        .substring(0, spec.token.length - 1)
        .replaceAll('#', '');
    // 大字组用大写，其余小写。
    final mainText =
        octave <= 2 ? rawLetter.toUpperCase() : rawLetter.toLowerCase();
    // C4→1，C5→2，C6→3；C2/C3 不带上标。
    final superscript = octave >= 4 ? '${octave - 3}' : '';

    final bgColor = spec.isCenterC
        ? const Color(0xFFC4F25E) // 中央 C：黄绿高亮
        : _capsuleColor(index);
    final textColor = spec.isCenterC
        ? const Color(0xFF0B081A)
        : const Color(0xFF1A1A1A);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 顶部音名胶囊
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: ui(3), vertical: ui(1.5)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(2.5)),
            color: bgColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mainText,
                style: TextStyle(
                  color: textColor,
                  fontSize: ui(11),
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              if (superscript.isNotEmpty) ...<Widget>[
                SizedBox(width: ui(0.5)),
                Transform.translate(
                  offset: Offset(0, -ui(2.0)),
                  child: Text(
                    superscript,
                    style: TextStyle(
                      color: textColor,
                      fontSize: ui(7),
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: ui(3)),
        // 高八度点（数字上方）
        if (spec.octaveDots > 0)
          Padding(
            padding: EdgeInsets.only(bottom: ui(1.5)),
            child: _OctaveDots(
              count: spec.octaveDots,
              color: const Color(0xFF6D6B75),
            ),
          ),
        // 简谱 1..7
        Text(
          spec.solfege == 0 ? '' : '${spec.solfege}',
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: ui(13),
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        // 低八度点（数字下方）
        if (spec.octaveDots < 0)
          Padding(
            padding: EdgeInsets.only(top: ui(1.5)),
            child: _OctaveDots(
              count: -spec.octaveDots,
              color: const Color(0xFF6D6B75),
            ),
          ),
      ],
    );
  }

  /// 与 Vue `bgComputed` 一致的 5 段分组配色（按白键下标）。
  Color _capsuleColor(int idx) {
    if (idx < 7) {
      return const Color(0xCCFDBCD2); // 粉
    }
    if (idx < 14) {
      return const Color(0xCCACAFFE); // 浅紫
    }
    if (idx < 21) {
      return const Color(0xCCFEE5C6); // 米
    }
    if (idx < 28) {
      return const Color(0xCCA6FFFB); // 浅青
    }
    return const Color(0xCCA4FEBE); // 浅绿
  }
}

/// 简谱八度点：竖向堆叠，体现 Chinese 简谱"加点表示高低八度"的写法。
class _OctaveDots extends StatelessWidget {
  const _OctaveDots({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(0.5)),
            child: Container(
              width: ui(3),
              height: ui(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
      ],
    );
  }
}

/// 单个黑键。
///
/// 按 Figma 切图严格对齐：
/// - 主体：暗色 #191C24 + 顶部 #06070A→透明 渐变 + 灰色描边 + 双重投影。
/// - 内嵌"凹槽"：左右两条 1px 立柱、中部 28×106 凹陷面。
/// - 底部金属垫片 35×24 + 中间 1px pinstripe。
class _PianoBlackKey extends StatelessWidget {
  const _PianoBlackKey({
    required this.spec,
    required this.isPressed,
    required this.showLabel,
  });

  final PianoKeySpec spec;
  final bool isPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Figma 中黑键基础尺寸：39.5 × 136.13。所有比例都基于这个原始数值，
          // 这样可以无缝缩放至当前布局给到的实际宽高。
          final scale = constraints.maxWidth / 39.5;
          final h = constraints.maxHeight;
          final radius = BorderRadius.only(
            bottomLeft: Radius.circular(6.39 * scale),
            bottomRight: Radius.circular(6.39 * scale),
          );

          return AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            decoration: BoxDecoration(
              borderRadius: radius,
              // 主体：上深下浅的两层叠加，按下时整体提亮
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isPressed
                    ? const <Color>[
                        Color(0xFF222631),
                        Color(0xFF101319),
                      ]
                    : const <Color>[
                        Color(0xFF06070A),
                        Color(0xFF191C24),
                      ],
              ),
              border: Border.all(
                color: const Color(0xFF999999),
                width: 0.64 * scale,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x8A11213A),
                  blurRadius: 13,
                  spreadRadius: -9,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: Color(0x7D5D6E9F),
                  blurRadius: 13,
                  offset: Offset(0, 2.6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                // 顶端 outline 高光（HTML 中 outline 1.28px white@.28）
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 1.3 * scale,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                // 凹槽中心矩形 #2F3442
                Positioned(
                  left: 5.63 * scale,
                  right: (39.5 - 5.63 - 28.25) * scale,
                  top: (2.80 / 136.13) * h,
                  height: (105.68 / 136.13) * h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x9411131C),
                          Color(0x002F3442),
                        ],
                      ),
                      color: const Color(0xFF2F3442),
                      border: Border.all(
                        color: const Color(0x99999999),
                        width: 0.32 * scale,
                      ),
                    ),
                  ),
                ),
                // 凹槽右立柱（顶部高光向下衰减）
                Positioned(
                  left: 34.81 * scale,
                  top: (12.42 / 136.13) * h,
                  width: 3.37 * scale,
                  height: (119.95 / 136.13) * h,
                  child: Opacity(
                    opacity: 0.67,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: <Color>[
                            Color(0xB50B0D14),
                            Color(0x00393E4B),
                          ],
                        ),
                        color: const Color(0xFF393E4B),
                        border: Border.all(
                          color: const Color(0x99999999),
                          width: 0.32 * scale,
                        ),
                      ),
                    ),
                  ),
                ),
                // 凹槽左立柱：与右立柱镜像，所以渐变方向反过来
                Positioned(
                  left: 1.33 * scale,
                  top: (12.42 / 136.13) * h,
                  width: 3.37 * scale,
                  height: (119.95 / 136.13) * h,
                  child: Opacity(
                    opacity: 0.67,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            Color(0xB50B0D14),
                            Color(0x00393E4B),
                          ],
                        ),
                        color: const Color(0xFF393E4B),
                        border: Border.all(
                          color: const Color(0x99999999),
                          width: 0.32 * scale,
                        ),
                      ),
                    ),
                  ),
                ),
                // 底部金属垫片
                Positioned(
                  left: 2.15 * scale,
                  width: 35.20 * scale,
                  top: (109.61 / 136.13) * h,
                  height: (24.05 / 136.13) * h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(2.56 * scale),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0xB50B0D14),
                          Color(0x00393E4B),
                        ],
                      ),
                      color: const Color(0xFF393E4B),
                      border: Border.all(
                        color: const Color(0x99999999),
                        width: 0.32 * scale,
                      ),
                    ),
                  ),
                ),
                // 金属垫片中央 pinstripe
                Positioned(
                  left: 19.39 * scale,
                  width: 1.80 * scale,
                  top: (113.21 / 136.13) * h,
                  height: (20.49 / 136.13) * h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x001A1D25),
                          Color(0xFF191C24),
                        ],
                      ),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0x33E4E9F5),
                          width: 0.64 * scale,
                        ),
                        right: BorderSide(
                          color: const Color(0x33E4E9F5),
                          width: 0.64 * scale,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showLabel)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6 * scale,
                    child: Text(
                      spec.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 9 * scale,
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        height: 1,
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

/// 让滚动行为不显示桌面端默认的 scrollbar，并允许鼠标拖动。
class _PianoScrollBehavior extends ScrollBehavior {
  const _PianoScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

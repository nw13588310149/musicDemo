import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 列表态「已点赞 / 已收藏」资源画布边长；未激活资源为 80px，需等比放大对齐。
const _kListActiveCanvasExtent = 94.0;
const _kListInactiveCanvasExtent = 80.0;

/// 点赞 / 收藏 GIF 播放时长（与资源帧率对齐的近似值）。
const Duration kCircleToggleAnimDuration = Duration(milliseconds: 750);

/// 列表态图标尺寸计算（与 [CircleActionButton] 一致）。
({double visualSize, double boxSize}) circleListActionIconSizes(
  double Function(double) ui, {
  required bool active,
  double? iconSize,
}) {
  final baseSize = iconSize ?? ui(20);
  final boxSize =
      baseSize * _kListActiveCanvasExtent / _kListInactiveCanvasExtent;
  final visualSize = active ? baseSize : boxSize;
  return (visualSize: visualSize, boxSize: boxSize);
}

/// 沉浸态图标尺寸计算。
({double visualSize, double boxSize}) circleImmersiveActionIconSizes(
  double Function(double) ui, {
  double? iconSize,
}) {
  final baseSize = iconSize ?? ui(28);
  return (visualSize: baseSize, boxSize: baseSize);
}

/// 评论点赞图标尺寸计算。
({double visualSize, double boxSize}) circleCommentLikeIconSizes(
  double Function(double) ui,
) {
  const activeCanvasExtent = 94.0;
  const inactiveCanvasExtent = 80.0;
  final baseSize = ui(20);
  final iconBoxSize = baseSize * activeCanvasExtent / inactiveCanvasExtent;
  return (visualSize: iconBoxSize, boxSize: iconBoxSize);
}

class _CircleAnimToggleIcon extends StatefulWidget {
  const _CircleAnimToggleIcon({
    required this.active,
    required this.onTap,
    required this.animAsset,
    required this.visualSize,
    required this.boxSize,
    required this.activeAsset,
    required this.inactiveAsset,
    this.animVisualSize,
  });

  final bool active;
  final VoidCallback onTap;
  final String animAsset;
  final double visualSize;
  final double? animVisualSize;
  final double boxSize;
  final String activeAsset;
  final String inactiveAsset;

  @override
  State<_CircleAnimToggleIcon> createState() => _CircleAnimToggleIconState();
}

class _CircleAnimToggleIconState extends State<_CircleAnimToggleIcon> {
  bool _playingAnim = false;
  Timer? _animTimer;

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CircleAnimToggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _playingAnim) {
      _stopAnim();
    }
  }

  void _stopAnim() {
    _animTimer?.cancel();
    _animTimer = null;
    if (_playingAnim) {
      setState(() => _playingAnim = false);
    }
  }

  void _startAnim() {
    setState(() => _playingAnim = true);
    _animTimer?.cancel();
    _animTimer = Timer(kCircleToggleAnimDuration, () {
      if (mounted) {
        setState(() => _playingAnim = false);
      }
    });
  }

  void _handleTap() {
    if (!widget.active && !_playingAnim) {
      _startAnim();
    } else if (widget.active) {
      _stopAnim();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_playingAnim) {
      final animSize = widget.animVisualSize ?? widget.visualSize;
      child = Image.asset(
        widget.animAsset,
        width: animSize,
        height: animSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } else {
      child = AppAssetGraphic(
        widget.active ? widget.activeAsset : widget.inactiveAsset,
        width: widget.visualSize,
        height: widget.visualSize,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: widget.boxSize,
        height: widget.boxSize,
        child: Center(child: child),
      ),
    );
  }
}

/// 列表模式帖子点赞（图标 + 数量，横向排列）。
class CircleListLikeButton extends StatelessWidget {
  const CircleListLikeButton({
    super.key,
    required this.post,
    required this.onTap,
  });

  final CirclePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final sizes = circleListActionIconSizes(ui, active: post.liked);
    final animVisualSize =
        circleListActionIconSizes(ui, active: false).visualSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CircleAnimToggleIcon(
          active: post.liked,
          onTap: onTap,
          animAsset: AppAssets.homeLikeAnim,
          visualSize: sizes.visualSize,
          animVisualSize: animVisualSize,
          boxSize: sizes.boxSize,
          activeAsset: AppAssets.circleFav1,
          inactiveAsset: AppAssets.circleFav2,
        ),
        SizedBox(width: ui(4)),
        Text(
          formatCircleCount(post.likeCount),
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
      ],
    );
  }
}

/// 列表模式帖子收藏（图标 + 数量，横向排列）。
class CircleListFavoriteButton extends StatelessWidget {
  const CircleListFavoriteButton({
    super.key,
    required this.post,
    required this.onTap,
  });

  final CirclePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final sizes = circleListActionIconSizes(ui, active: post.favorited);
    final animVisualSize =
        circleListActionIconSizes(ui, active: false).visualSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CircleAnimToggleIcon(
          active: post.favorited,
          onTap: onTap,
          animAsset: AppAssets.homeFavoriteAnim,
          visualSize: sizes.visualSize,
          animVisualSize: animVisualSize,
          boxSize: sizes.boxSize,
          activeAsset: AppAssets.circleSc1,
          inactiveAsset: AppAssets.circleSc2,
        ),
        SizedBox(width: ui(4)),
        Text(
          formatCircleCount(post.favoriteCount),
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
      ],
    );
  }
}

/// 沉浸模式帖子点赞（图标在上、数量在下）。
class CircleImmersiveLikeButton extends StatelessWidget {
  const CircleImmersiveLikeButton({
    super.key,
    required this.post,
    required this.onTap,
    this.iconSize,
  });

  final CirclePost post;
  final VoidCallback onTap;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final sizes = circleImmersiveActionIconSizes(ui, iconSize: iconSize);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleAnimToggleIcon(
          active: post.liked,
          onTap: onTap,
          animAsset: AppAssets.homeLikeAnim,
          visualSize: sizes.visualSize,
          boxSize: sizes.boxSize,
          activeAsset: AppAssets.circleFav1,
          inactiveAsset: AppAssets.circleFav,
        ),
        SizedBox(height: ui(4)),
        Text(
          formatCircleCount(post.likeCount),
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
      ],
    );
  }
}

/// 沉浸模式帖子收藏（图标在上、数量在下）。
class CircleImmersiveFavoriteButton extends StatelessWidget {
  const CircleImmersiveFavoriteButton({
    super.key,
    required this.post,
    required this.onTap,
    this.iconSize,
  });

  final CirclePost post;
  final VoidCallback onTap;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final sizes = circleImmersiveActionIconSizes(ui, iconSize: iconSize);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleAnimToggleIcon(
          active: post.favorited,
          onTap: onTap,
          animAsset: AppAssets.homeFavoriteAnim,
          visualSize: sizes.visualSize,
          boxSize: sizes.boxSize,
          activeAsset: AppAssets.circleSc1,
          inactiveAsset: AppAssets.circleSc,
        ),
        SizedBox(height: ui(4)),
        Text(
          formatCircleCount(post.favoriteCount),
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
      ],
    );
  }
}

/// 评论点赞（图标在上、数量在下）。
class CircleCommentLikeButton extends StatelessWidget {
  const CircleCommentLikeButton({
    super.key,
    required this.comment,
    required this.onTap,
  });

  final CircleComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final sizes = circleCommentLikeIconSizes(ui);
    final visualSize = comment.liked ? ui(20) : sizes.visualSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleAnimToggleIcon(
          active: comment.liked,
          onTap: onTap,
          animAsset: AppAssets.homeLikeAnim,
          visualSize: visualSize,
          animVisualSize: sizes.visualSize,
          boxSize: sizes.boxSize,
          activeAsset: AppAssets.circleFav1,
          inactiveAsset: AppAssets.circleFav2,
        ),
        SizedBox(height: ui(2)),
        Text(
          formatCircleCount(comment.likeCount),
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            height: 1,
          ),
        ),
      ],
    );
  }
}

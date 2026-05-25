import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

/// 列表态「已点赞 / 已收藏」资源画布边长；未激活资源为 80px，需等比放大对齐。
const _kListActiveCanvasExtent = 94.0;
const _kListInactiveCanvasExtent = 80.0;

bool _usesListInactiveCanvas(String asset) {
  return asset == AppAssets.circleFav2 ||
      asset == AppAssets.circleMsg1 ||
      asset == AppAssets.circleSc2;
}

/// 单个操作按钮（点赞 / 评论 / 收藏），支持 light / dark 两种调色。
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.iconAsset,
    required this.count,
    required this.onTap,
    this.dark = false,
    this.iconSize,
    this.coloredIcon,
  });

  final String iconAsset;
  final int count;
  final VoidCallback onTap;

  /// 沉浸模式（黑色背景）下使用白色文字与放大的图标。
  final bool dark;
  final double? iconSize;

  /// 当 dark=true 但仍需要保留资源原色（例如已点赞的红心）时填 null；
  /// 否则可通过 [Color] 让 png 转为指定颜色（如沉浸态默认白）。
  final Color? coloredIcon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final baseSize = iconSize ?? (dark ? ui(28) : ui(20));
    final listIconBoxSize =
        baseSize * _kListActiveCanvasExtent / _kListInactiveCanvasExtent;
    final visualSize = !dark && _usesListInactiveCanvas(iconAsset)
        ? listIconBoxSize
        : baseSize;
    final boxSize = dark ? baseSize : listIconBoxSize;

    final graphic = coloredIcon == null
        ? AppAssetGraphic(iconAsset, width: visualSize, height: visualSize)
        : ColorFiltered(
            colorFilter: ColorFilter.mode(coloredIcon!, BlendMode.srcIn),
            child: AppAssetGraphic(
              iconAsset,
              width: visualSize,
              height: visualSize,
            ),
          );
    final iconWidget = SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(child: graphic),
    );
    final textWidget = Text(
      formatCircleCount(count),
      style: TextStyle(
        color: dark ? Colors.white : const Color(0xFF0B081A),
        fontSize: ui(14),
        fontFamily: 'PingFang SC',
        height: 24 / 14,
      ),
    );

    // 沉浸态（dark=true）保持纵向：图标在上、数量在下；
    // 列表态（dark=false）按设计稿改为横向：图标 + 4px 间距 + 数量。
    final body = dark
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              SizedBox(height: ui(4)),
              textWidget,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              SizedBox(width: ui(4)),
              textWidget,
            ],
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// 列表模式下的一行三个操作按钮。
class CircleActionRow extends StatelessWidget {
  const CircleActionRow({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        CircleActionButton(
          iconAsset: post.liked ? AppAssets.circleFav1 : AppAssets.circleFav2,
          count: post.likeCount,
          onTap: onLike,
        ),
        SizedBox(width: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.circleMsg1,
          count: post.commentCount,
          onTap: onComment,
        ),
        SizedBox(width: ui(16)),
        CircleActionButton(
          iconAsset:
              post.favorited ? AppAssets.circleSc1 : AppAssets.circleSc2,
          count: post.favoriteCount,
          onTap: onFavorite,
        ),
      ],
    );
  }
}

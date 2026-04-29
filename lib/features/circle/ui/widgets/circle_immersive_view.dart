import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'circle_comment_panel.dart';

/// 沉浸模式：全屏单帖，纵向 PageView 翻页，右侧操作按钮，下方文字浮层；
/// 评论面板从右侧滑入，覆盖在沉浸面板之上。
class CircleImmersiveView extends StatefulWidget {
  const CircleImmersiveView({
    super.key,
    required this.state,
    required this.controller,
  });

  final CircleState state;
  final CircleController controller;

  @override
  State<CircleImmersiveView> createState() => _CircleImmersiveViewState();
}

class _CircleImmersiveViewState extends State<CircleImmersiveView> {
  late final PageController _pageController = PageController(
    initialPage: widget.state.immersiveIndex,
  );

  @override
  void didUpdateWidget(covariant CircleImmersiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.state.immersiveIndex;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = widget.state;
    final controller = widget.controller;

    return Container(
      color: const Color(0xFF0B081A),
      child: Stack(
        children: [
          // 主翻页区
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: state.posts.length,
            onPageChanged: controller.setImmersiveIndex,
            itemBuilder: (context, index) {
              return _ImmersiveSlide(
                post: state.posts[index],
                onLike: () => controller.toggleLike(state.posts[index].id),
                onComment: () =>
                    controller.openCommentPanel(state.posts[index].id),
                onFavorite: () =>
                    controller.toggleFavorite(state.posts[index].id),
              );
            },
          ),

          // 右侧滑入评论面板
          _AnimatedCommentPanel(
            visible: state.commentPanelOpen,
            child: CircleCommentPanel(
              post: state.commentTargetPost ?? state.currentImmersivePost,
              onClose: controller.closeCommentPanel,
              onSubmit: (text) {
                final id = state.commentTargetPostId.isNotEmpty
                    ? state.commentTargetPostId
                    : state.currentImmersivePost?.id;
                if (id != null) controller.addComment(id, text);
              },
              onCommentLikeTap: (commentId) {
                final id = state.commentTargetPostId.isNotEmpty
                    ? state.commentTargetPostId
                    : state.currentImmersivePost?.id;
                if (id != null) controller.toggleCommentLike(id, commentId);
              },
            ),
          ),

          // 评论面板打开时，左侧主区域加一层点击关闭的遮罩
          if (state.commentPanelOpen)
            Positioned.fill(
              right: ui(420),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.closeCommentPanel,
                child: const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单帖：背景图 + 底部渐变 + 文本 + 右侧操作。
class _ImmersiveSlide extends StatelessWidget {
  const _ImmersiveSlide({
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景图
        Positioned.fill(
          child: Image.network(
            post.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const ColoredBox(color: Color(0xFF1B1530)),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const ColoredBox(color: Color(0xFF1B1530));
            },
          ),
        ),

        // 底部渐变遮罩
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: ui(220),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x000B081A),
                  Color(0xCC0B081A),
                  Color(0xFF0B081A),
                ],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),

        // 左下：作者 / 标签 / 文字 / 时间
        Positioned(
          left: ui(32),
          right: ui(160),
          bottom: ui(28),
          child: _ImmersiveTextBlock(post: post),
        ),

        // 右下：操作按钮列
        Positioned(
          right: ui(28),
          bottom: ui(32),
          child: _ImmersiveActions(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onFavorite: onFavorite,
          ),
        ),
      ],
    );
  }
}

class _ImmersiveTextBlock extends StatelessWidget {
  const _ImmersiveTextBlock({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ui(12),
          runSpacing: ui(6),
          children: [
            Text(
              '@${post.author.name}',
              style: TextStyle(
                color: Colors.white,
                fontSize: ui(20),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            Text(
              post.author.role,
              style: TextStyle(
                color: const Color(0xFFCECED1),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                height: 1.2,
              ),
            ),
            for (final b in post.badges) CircleBadgeChip(badge: b),
          ],
        ),
        SizedBox(height: ui(12)),
        Text(
          post.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
        SizedBox(height: ui(6)),
        Text(
          post.timeLabel,
          style: TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
          ),
        ),
      ],
    );
  }
}

class _ImmersiveActions extends StatelessWidget {
  const _ImmersiveActions({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAvatar(url: post.author.avatarUrl, size: ui(44)),
        SizedBox(height: ui(20)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconLiked,
          count: post.likeCount,
          onTap: onLike,
          dark: true,
          coloredIcon: post.liked
              ? const Color(0xFFFF323C)
              : Colors.white,
        ),
        SizedBox(height: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconComment,
          count: post.commentCount,
          onTap: onComment,
          dark: true,
          coloredIcon: Colors.white,
        ),
        SizedBox(height: ui(16)),
        CircleActionButton(
          iconAsset: AppAssets.schoolIconFavorite,
          count: post.favoriteCount,
          onTap: onFavorite,
          dark: true,
          coloredIcon: post.favorited
              ? const Color(0xFFFFB400)
              : Colors.white,
        ),
      ],
    );
  }
}

class _ImmersiveAvatar extends StatelessWidget {
  const _ImmersiveAvatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF6D6B75), width: 1),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFF252035),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: Colors.white.withValues(alpha: 0.6),
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

/// 用 AnimatedPositioned 包装的右侧滑入面板。
class _AnimatedCommentPanel extends StatelessWidget {
  const _AnimatedCommentPanel({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: visible ? 0 : -ui(440),
      width: ui(420),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: child,
      ),
    );
  }
}

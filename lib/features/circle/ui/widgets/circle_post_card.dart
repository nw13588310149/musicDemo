import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';

/// 列表模式下的单个帖子卡片：作者 / 文字 / 配图 / 操作按钮。
class CirclePostCard extends StatelessWidget {
  const CirclePostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.onTap,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardAuthor(post: post),
              SizedBox(height: ui(8)),
              Text(
                post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  height: 19.6 / 14,
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
              SizedBox(height: ui(13)),
              _CardImage(post: post),
              SizedBox(height: ui(12)),
              CircleActionRow(
                post: post,
                onLike: onLike,
                onComment: onComment,
                onFavorite: onFavorite,
              ),
              SizedBox(height: ui(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAuthor extends StatelessWidget {
  const _CardAuthor({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(url: post.author.avatarUrl, size: ui(44)),
        SizedBox(width: ui(11)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0B081A),
                        fontSize: ui(18),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (post.badges.isNotEmpty) ...[
                    SizedBox(width: ui(12)),
                    CircleBadgeRow(badges: post.badges),
                  ],
                ],
              ),
              SizedBox(height: ui(2)),
              Text(
                post.author.role,
                style: TextStyle(
                  color: const Color(0xFFB6B5BB),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFFEAE5FF),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: const Color(0xFF8741FF),
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(12)),
      child: AspectRatio(
        aspectRatio: post.imageAspectRatio,
        child: Image.network(
          post.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: const Color(0xFFD9D9D9),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFEFEFF4),
              alignment: Alignment.center,
              child: SizedBox(
                width: ui(20),
                height: ui(20),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/circle_mock_data.dart';
import 'circle_state.dart';

final circleControllerProvider =
    StateNotifierProvider.autoDispose<CircleController, CircleState>(
      (ref) => CircleController(),
    );

class CircleController extends StateNotifier<CircleState> {
  CircleController()
    : super(CircleState.initial(posts: CircleMockData.buildPosts()));

  // ── 模式切换 ────────────────────────────────────────────────────────
  void setMode(CircleMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(
      mode: mode,
      // 切换到列表模式时关闭评论面板。
      commentPanelOpen: mode == CircleMode.list ? false : state.commentPanelOpen,
    );
  }

  // ── 搜索框 ─────────────────────────────────────────────────────────
  void setSearchKeyword(String keyword) {
    state = state.copyWith(searchKeyword: keyword);
  }

  // ── 沉浸模式翻页 ───────────────────────────────────────────────────
  void setImmersiveIndex(int index) {
    if (state.posts.isEmpty) return;
    final next = index.clamp(0, state.posts.length - 1);
    if (next == state.immersiveIndex) return;
    state = state.copyWith(immersiveIndex: next);
  }

  // ── 点赞 / 收藏 ────────────────────────────────────────────────────
  void toggleLike(String postId) {
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final liked = !p.liked;
        return p.copyWith(
          liked: liked,
          likeCount: (p.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30),
        );
      }),
    );
  }

  void toggleFavorite(String postId) {
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final favorited = !p.favorited;
        return p.copyWith(
          favorited: favorited,
          favoriteCount: (p.favoriteCount + (favorited ? 1 : -1)).clamp(
            0,
            1 << 30,
          ),
        );
      }),
    );
  }

  // ── 评论面板 ──────────────────────────────────────────────────────
  /// 打开右侧评论面板，定位到具体帖子。
  void openCommentPanel(String postId) {
    state = state.copyWith(
      commentPanelOpen: true,
      commentTargetPostId: postId,
    );
  }

  void closeCommentPanel() {
    state = state.copyWith(commentPanelOpen: false);
  }

  /// 评论面板中点击点赞。
  void toggleCommentLike(String postId, String commentId) {
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        final updated = <CircleComment>[
          for (final c in p.comments)
            if (c.id == commentId)
              c.copyWith(
                liked: !c.liked,
                likeCount: (c.likeCount + (c.liked ? -1 : 1)).clamp(
                  0,
                  1 << 30,
                ),
              )
            else
              c,
        ];
        return p.copyWith(comments: updated);
      }),
    );
  }

  /// 在评论面板提交一条新评论。
  void addComment(String postId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final newComment = CircleComment(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      author: const CircleAuthor(
        id: 'u_self',
        name: 'Grey_黎',
        role: '艺术学院 · 学生',
        avatarUrl: 'https://i.pravatar.cc/120?img=64',
      ),
      text: trimmed,
      timeLabel: '刚刚',
      likeCount: 0,
    );
    state = state.copyWith(
      posts: _mapPosts(postId, (p) {
        return p.copyWith(
          comments: [newComment, ...p.comments],
          commentCount: p.commentCount + 1,
        );
      }),
    );
  }

  // ── 内部工具 ──────────────────────────────────────────────────────
  List<CirclePost> _mapPosts(
    String postId,
    CirclePost Function(CirclePost) update,
  ) {
    return [
      for (final p in state.posts) if (p.id == postId) update(p) else p,
    ];
  }
}

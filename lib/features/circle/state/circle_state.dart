import 'package:flutter/foundation.dart';

/// 校圈页面的两种展示模式：沉浸（抖音风全屏单帖）/ 列表（瀑布流多帖）。
enum CircleMode { immersive, list }

/// 帖子标签：置顶 / 热门。
enum CircleBadge { pinned, hot }

@immutable
class CircleAuthor {
  const CircleAuthor({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final String avatarUrl;
}

@immutable
class CircleComment {
  const CircleComment({
    required this.id,
    required this.author,
    required this.text,
    required this.timeLabel,
    required this.likeCount,
    this.liked = false,
  });

  final String id;
  final CircleAuthor author;
  final String text;
  final String timeLabel;
  final int likeCount;
  final bool liked;

  CircleComment copyWith({int? likeCount, bool? liked}) => CircleComment(
    id: id,
    author: author,
    text: text,
    timeLabel: timeLabel,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
  );
}

@immutable
class CirclePost {
  const CirclePost({
    required this.id,
    required this.author,
    required this.badges,
    required this.text,
    required this.timeLabel,
    required this.imageUrl,
    required this.imageAspectRatio,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.liked,
    required this.favorited,
    required this.comments,
  });

  final String id;
  final CircleAuthor author;
  final List<CircleBadge> badges;
  final String text;
  final String timeLabel;
  final String imageUrl;

  /// 列表瀑布流所需的图片宽高比（width / height），用于决定卡片高度。
  final double imageAspectRatio;
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final bool liked;
  final bool favorited;
  final List<CircleComment> comments;

  CirclePost copyWith({
    int? likeCount,
    int? commentCount,
    int? favoriteCount,
    bool? liked,
    bool? favorited,
    List<CircleComment>? comments,
  }) {
    return CirclePost(
      id: id,
      author: author,
      badges: badges,
      text: text,
      timeLabel: timeLabel,
      imageUrl: imageUrl,
      imageAspectRatio: imageAspectRatio,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      liked: liked ?? this.liked,
      favorited: favorited ?? this.favorited,
      comments: comments ?? this.comments,
    );
  }
}

@immutable
class CircleState {
  const CircleState({
    required this.mode,
    required this.posts,
    required this.searchKeyword,
    required this.unreadCount,
    required this.immersiveIndex,
    required this.commentPanelOpen,
    required this.commentTargetPostId,
  });

  factory CircleState.initial({required List<CirclePost> posts}) {
    return CircleState(
      mode: CircleMode.list,
      posts: posts,
      searchKeyword: '',
      unreadCount: 12,
      immersiveIndex: 0,
      commentPanelOpen: false,
      commentTargetPostId: '',
    );
  }

  final CircleMode mode;
  final List<CirclePost> posts;
  final String searchKeyword;
  final int unreadCount;
  final int immersiveIndex;
  final bool commentPanelOpen;
  final String commentTargetPostId;

  CirclePost? get currentImmersivePost {
    if (posts.isEmpty) return null;
    final i = immersiveIndex.clamp(0, posts.length - 1);
    return posts[i];
  }

  CirclePost? get commentTargetPost {
    if (commentTargetPostId.isEmpty) return null;
    for (final p in posts) {
      if (p.id == commentTargetPostId) return p;
    }
    return null;
  }

  CircleState copyWith({
    CircleMode? mode,
    List<CirclePost>? posts,
    String? searchKeyword,
    int? unreadCount,
    int? immersiveIndex,
    bool? commentPanelOpen,
    String? commentTargetPostId,
  }) {
    return CircleState(
      mode: mode ?? this.mode,
      posts: posts ?? this.posts,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      unreadCount: unreadCount ?? this.unreadCount,
      immersiveIndex: immersiveIndex ?? this.immersiveIndex,
      commentPanelOpen: commentPanelOpen ?? this.commentPanelOpen,
      commentTargetPostId: commentTargetPostId ?? this.commentTargetPostId,
    );
  }
}

/// 把数字格式化为 "12.3w" 这样的展示形式。
String formatCircleCount(int count) {
  if (count < 10000) return count.toString();
  final value = count / 10000;
  if (value >= 100) return '${value.toStringAsFixed(0)}w';
  return '${value.toStringAsFixed(1)}w';
}

import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_post_card.dart';

/// 列表模式：3 列瀑布流。沿 Y 方向按列累计高度，把每个卡片填到当前最矮的那一列。
class CircleListView extends StatelessWidget {
  const CircleListView({
    super.key,
    required this.state,
    required this.controller,
  });

  final CircleState state;
  final CircleController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (state.posts.isEmpty) {
      return const Center(
        child: Text(
          '暂无动态',
          style: TextStyle(
            color: Color(0xFFB6B5BB),
            fontSize: 14,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return Container(
      // 与 DashboardScaffold 背景同色：白色卡片才能"漂浮"在浅蓝灰底上，
      // 让卡片之间的 16px 间距清晰可见。
      color: const Color(0xFFEFF3FC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 3;
          final gap = ui(16);
          // 卡片靠面板四周对齐：左 / 右 / 上 都不留间距，
          // 仅底部预留 16 让最后一行卡片在滚到底时仍有呼吸空间。
          final available = constraints.maxWidth;
          final colWidth =
              (available - gap * (columns - 1)) / columns;

          // 使用瀑布流布局：根据每张图片的纵横比，把 post 依次填到当前最矮的一列。
          final columnsContent = List<List<CirclePost>>.generate(
            columns,
            (_) => <CirclePost>[],
          );
          final columnsHeight = List<double>.filled(columns, 0);

          for (final post in state.posts) {
            // 估算卡片总高 = 顶部作者(44+8)+文字(~3行*19.6+6+14)+图(colW/aspect+12)+操作行(20+24)+底 padding(8+12)
            final estTextH = ui(72);
            final estImgH = colWidth / post.imageAspectRatio;
            final estCardH =
                ui(12) + ui(44) + ui(8) + estTextH + estImgH + ui(60);
            int target = 0;
            for (var i = 1; i < columns; i++) {
              if (columnsHeight[i] < columnsHeight[target]) target = i;
            }
            columnsContent[target].add(post);
            columnsHeight[target] += estCardH + gap;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final post in columnsContent[i]) ...[
                          CirclePostCard(
                            post: post,
                            onLike: () => controller.toggleLike(post.id),
                            onComment: () => _onCommentTap(post.id),
                            onFavorite: () =>
                                controller.toggleFavorite(post.id),
                            onTap: () => _onCardTap(post.id),
                          ),
                          SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _onCardTap(String postId) {
    // 列表中点击卡片：进入沉浸模式定位到该帖。
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive);
  }

  void _onCommentTap(String postId) {
    // 列表态点评论也跳到沉浸态并自动展开评论面板。
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive)
      ..openCommentPanel(postId);
  }
}

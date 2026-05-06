import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../../video_tutorial/data/video_publisher_data.dart';
import '../state/my_collection_controller.dart';
import '../state/my_collection_state.dart';

import '../../../core/widgets/app_text.dart';
/// 我的收藏页：
/// - 顶部 6 个 Tab（声乐 / 器乐 / 听写 / 视唱 / 乐理 / 视频），样式与设计稿
///   分段控件一致：#F5F6FA 胶囊容器 + 选中态白色卡片+阴影。
/// - 主体区域根据 [activeType] 渲染三种网格之一：
///     * 声乐 / 器乐：仿首页 `_VoiceSongCard`（173×182、#F4F4FF 卡片）
///     * 听写 / 视唱 / 乐理：仿学习目录 `_LessonCard`（220×100、左侧 60×80 紫色封面）
///     * 视频：仿视频中心 `_VideoGridCard`（220×180，封面+缩略图+作者）
class MyCollectionPage extends ConsumerWidget {
  const MyCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: Stack(
            children: [
              // 顶部 Tab 与下方网格区分别绝对定位，与设计稿 left:20 / top:20 / 84 对齐。
              Positioned(
                left: ui(20),
                top: ui(20),
                child: _CollectionTabs(
                  tabs: state.tabs,
                  activeType: state.activeType,
                  onSelect: controller.selectType,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(ui(20), ui(82), ui(20), ui(20)),
                  child: state.loading && state.items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.items.isEmpty
                      ? const _CollectionEmpty()
                      : _CollectionGrid(
                          state: state,
                          onOpenItem: (item) => _openItem(context, item),
                          onRemove: (item) => _removeItem(context, ref, item),
                          onShare: (item) => _openShare(context, ref, item),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (state.busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (state.shareTarget != null)
          Positioned.fill(
            child: _ShareSheet(
              state: state,
              onClose: controller.closeShare,
              onToggle: controller.toggleShareClass,
              onSend: () async {
                final message = await controller.sendShare();
                if (context.mounted) {
                  AppToast.show(context, message ?? '分享成功');
                }
              },
            ),
          ),
      ],
    );
  }

  void _openItem(BuildContext context, CollectionEntry item) {
    final targetId = item.targetId > 0 ? item.targetId : item.id;
    if (targetId <= 0) {
      AppToast.show(context, '收藏内容已失效');
      return;
    }
    switch (item.type) {
      case 1: // 视唱
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId', 'type': 3},
        );
      case 2: // 乐理
        Navigator.pushNamed(
          context,
          RoutePaths.theory,
          arguments: <String, dynamic>{'id': '$targetId'},
        );
      case 3: // 听写
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId'},
        );
      case 4: // 声乐
      case 5: // 器乐
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: <String, dynamic>{'id': '$targetId', 'type': 2},
        );
      case 6: // 视频
        // 视频中心目前从列表页内部唤起播放，跳转到列表页方便用户继续观看。
        Navigator.pushNamed(context, RoutePaths.videoTutorial);
      default:
        AppToast.show(context, '暂不支持的收藏类型');
    }
  }

  Future<void> _openShare(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .openShare(item);
    if (context.mounted && message != null) {
      AppToast.show(context, message);
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('取消收藏'),
        content: AppText('确定将“${item.title}”从收藏中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(item);
    if (context.mounted) {
      AppToast.show(context, message ?? '已取消收藏');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 顶部 Tab 分段控件
// ──────────────────────────────────────────────────────────────────────────────

class _CollectionTabs extends StatelessWidget {
  const _CollectionTabs({
    required this.tabs,
    required this.activeType,
    required this.onSelect,
  });

  final List<CollectionTabItem> tabs;
  final int activeType;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 不设固定总高度：固定 44px + 上下 padding 后，留给文字的垂直空间不足，
    // 中文（尤其 PingFang）笔画底部会被裁切；高度交给 Row + Tab 子项撑开。
    return Container(
      padding: EdgeInsets.fromLTRB(ui(4), ui(6), ui(3), ui(6)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            _CollectionTabItemView(
              label: tabs[i].label,
              active: tabs[i].type == activeType,
              onTap: () => onSelect(tabs[i].type),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionTabItemView extends StatelessWidget {
  const _CollectionTabItemView({
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: active
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59B5B5B5),
                    blurRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
        alignment: Alignment.center,
        child: AppText(
          label,
          maxLines: 1,
          softWrap: false,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w500,
            height: 1.25,
            leadingDistribution: TextLeadingDistribution.even,
            color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 主体网格（根据当前 Tab 切换三种卡片布局）
// ──────────────────────────────────────────────────────────────────────────────

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.state,
    required this.onOpenItem,
    required this.onRemove,
    required this.onShare,
  });

  final MyCollectionState state;
  final ValueChanged<CollectionEntry> onOpenItem;
  final ValueChanged<CollectionEntry> onRemove;
  final ValueChanged<CollectionEntry> onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final activeType = state.activeType;

    // 设计稿三种卡片的栅格规格：
    //   - 声乐/器乐：5 列 / 173×182 / 间距 16,14
    //   - 听写/视唱/乐理：4 列 / 220×100 / 间距 16
    //   - 视频：4 列 / 220×180 / 间距 16
    if (activeType == 4 || activeType == 5) {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: ui(189),
          childAspectRatio: 173 / 182,
          crossAxisSpacing: ui(16),
          mainAxisSpacing: ui(14),
        ),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return _SongCollectionCard(
            item: item,
            onTap: () => onOpenItem(item),
            onMenu: () =>
                _showItemActionSheet(context, item, onRemove, onShare),
          );
        },
      );
    }

    if (activeType == 6) {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: ui(236),
          childAspectRatio: 220 / 180,
          crossAxisSpacing: ui(16),
          mainAxisSpacing: ui(16),
        ),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return _VideoCollectionCard(
            item: item,
            onTap: () => onOpenItem(item),
            onMenu: () =>
                _showItemActionSheet(context, item, onRemove, onShare),
          );
        },
      );
    }

    // 听写 / 视唱 / 乐理
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ui(236),
        mainAxisExtent: ui(100),
        crossAxisSpacing: ui(16),
        mainAxisSpacing: ui(16),
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _LessonCollectionCard(
          item: item,
          onOpen: () => onOpenItem(item),
          onMenu: () => _showItemActionSheet(context, item, onRemove, onShare),
        );
      },
    );
  }
}

Future<void> _showItemActionSheet(
  BuildContext context,
  CollectionEntry item,
  ValueChanged<CollectionEntry> onRemove,
  ValueChanged<CollectionEntry> onShare,
) async {
  final ui = DashboardScaleScope.of(context).ui;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const AppText('分享给班级'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onShare(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const AppText('取消收藏'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRemove(item);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// 声乐 / 器乐 卡片：173×182，对齐首页 _VoiceSongCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _SongCollectionCard extends StatelessWidget {
  const _SongCollectionCard({
    required this.item,
    required this.onTap,
    required this.onMenu,
  });

  final CollectionEntry item;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(ui(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(8)),
                child: _SongCover(coverUrl: item.coverUrl),
              ),
            ),
            SizedBox(height: ui(10)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: ui(14),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0B081A),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: ui(7)),
                      AppText(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: ui(12),
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFB6B5BB),
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui(8)),
                _SongActionButton(onTap: onMenu),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SongCover extends StatelessWidget {
  const _SongCover({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveRemoteUrl(coverUrl);
    if (resolved != null) {
      return CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      AppAssets.homeFmCover,
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }
}

/// 设计稿中右下角 28×28 播放图标，点击仍打开更多操作（分享 / 取消收藏）。
class _SongActionButton extends StatelessWidget {
  const _SongActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ui(28),
        height: ui(28),
        child: Image.asset(
          AppAssets.soundPlay,
          width: ui(28),
          height: ui(28),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 听写 / 视唱 / 乐理 卡片：220×100，对齐学习目录 _LessonCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _LessonCollectionCard extends StatelessWidget {
  const _LessonCollectionCard({
    required this.item,
    required this.onOpen,
    required this.onMenu,
  });

  final CollectionEntry item;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return GestureDetector(
      onTap: onOpen,
      onLongPress: onMenu,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(ui(10)),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LessonArtwork(type: item.type, title: item.title),
            SizedBox(width: ui(8)),
            Expanded(
              child: SizedBox(
                height: ui(80),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(13),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              height: 1.2,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            SizedBox(height: ui(6)),
                            AppText(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(11),
                                color: const Color(0xFFB6B5BB),
                                fontFamily: 'PingFang SC',
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _LessonStudyButton(onTap: onOpen),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: onMenu,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(left: ui(6), bottom: ui(6)),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: ui(16),
                            color: const Color(0xFFB6B5BB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonStudyButton extends StatelessWidget {
  const _LessonStudyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: const Color(0xFF292151),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: AppText(
          '去学习',
          style: TextStyle(
            fontSize: ui(11),
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFamily: 'PingFang SC',
            height: 12 / 11,
          ),
        ),
      ),
    );
  }
}

class _LessonArtwork extends StatelessWidget {
  const _LessonArtwork({required this.type, required this.title});

  final int type;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(60),
        height: ui(80),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeDictationBookCover,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ui(10),
              child: AppText(
                _coverText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB16AFF),
                  fontFamily: 'Alimama ShuHeiTi',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 与首页 _LessonArtwork 同款两行封面文字：
  ///   听写 → "听选\n单音"
  ///   视唱 → "视唱\n训练"
  ///   乐理 → "乐理\n练习"
  String _coverText() {
    return switch (type) {
      1 => '视唱\n训练',
      2 => '乐理\n练习',
      3 => '听选\n单音',
      _ => '收藏\n内容',
    };
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 视频 卡片：220×180，对齐视频中心 _VideoGridCard 设计
// ──────────────────────────────────────────────────────────────────────────────

class _VideoCollectionCard extends StatelessWidget {
  const _VideoCollectionCard({
    required this.item,
    required this.onTap,
    required this.onMenu,
  });

  final CollectionEntry item;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cw = box.maxWidth;
        final s = cw / 220.0;
        final coverH = 124.0 * s;
        final thumbL = 10.0 * s;
        final thumbTop = 95.0 * s;
        final thumbW = 52.0 * s;
        final thumbH = 70.0 * s;
        final infoLeft = 66.0 * s;

        final coverUrl = MediaUrl.resolve(item.coverUrl);
        final publisher = item.authorName.isNotEmpty
            ? _StaticPublisher(
                nickname: item.authorName,
                avatarAsset: 'assets/images/avtor/1.jpg',
              )
            : _publisherFor(item);

        return Material(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12.0 * s),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMenu,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: coverH,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _CollectionImage(
                                url: coverUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 8.0 * s,
                              bottom: 8.0 * s,
                              child: Container(
                                height: 18.0 * s,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.0 * s,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(18.0 * s),
                                ),
                                child: Center(
                                  child: AppText(
                                    item.durationText,
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: Colors.white,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w400,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            infoLeft,
                            4.0 * s,
                            10.0 * s,
                            15.0 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.0 * s,
                                  color: const Color(0xFF0B081A),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'PingFang SC',
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      publisher.avatarAsset,
                                      width: 16.0 * s,
                                      height: 16.0 * s,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 16.0 * s,
                                        height: 16.0 * s,
                                        color: const Color(0xFFE0DEFF),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  Expanded(
                                    child: AppText(
                                      publisher.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.0 * s,
                                        color: const Color(0xFFB6B5BB),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w500,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  Image.asset(
                                    AppAssets.videoV2CardViews,
                                    width: 12.0 * s,
                                    height: 12.0 * s,
                                  ),
                                  SizedBox(width: 4.0 * s),
                                  AppText(
                                    item.metricText,
                                    style: TextStyle(
                                      fontSize: 12.0 * s,
                                      color: const Color(0xFFB6B5BB),
                                      fontFamily: 'PingFang SC',
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: thumbL,
                  top: thumbTop,
                  width: thumbW,
                  height: thumbH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.0 * s),
                      child: _CollectionImage(url: coverUrl, fit: BoxFit.cover),
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

class _StaticPublisher {
  const _StaticPublisher({required this.nickname, required this.avatarAsset});

  final String nickname;
  final String avatarAsset;
}

_StaticPublisher _publisherFor(CollectionEntry item) {
  final id = item.targetId > 0 ? item.targetId : item.id;
  final info = videoPublisherFor('$id');
  return _StaticPublisher(
    nickname: info.nickname,
    avatarAsset: info.avatarAsset,
  );
}

class _CollectionImage extends StatelessWidget {
  const _CollectionImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _fallback();
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => _fallback(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFEDEDF2),
      alignment: Alignment.center,
      child: const Icon(
        Icons.ondemand_video_rounded,
        color: Color(0xFFB6B5BB),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 共用：URL 解析、空态、分享面板
// ──────────────────────────────────────────────────────────────────────────────

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }
  final resolved = MediaUrl.resolve(value);
  return resolved.isEmpty ? null : resolved;
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.emptyCoursePlaceholder,
            width: ui(163),
            height: ui(163),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(4)),
          AppText(
            '暂无收藏',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: ui(16),
              fontWeight: FontWeight.w400,
              color: const Color(0xFF0B081A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.state,
    required this.onClose,
    required this.onToggle,
    required this.onSend,
  });

  final MyCollectionState state;
  final VoidCallback onClose;
  final ValueChanged<int> onToggle;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(
        child: Container(
          width: ui(420),
          padding: EdgeInsets.all(ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppText(
                    '分享到班级',
                    style: TextStyle(
                      fontSize: ui(20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              AppText(
                state.shareTarget?.title ?? '',
                style: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFF7D8396),
                ),
              ),
              SizedBox(height: ui(16)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(260)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.shareClasses.length,
                  separatorBuilder: (context, index) => SizedBox(height: ui(8)),
                  itemBuilder: (context, index) {
                    final item = state.shareClasses[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(ui(12)),
                      onTap: () => onToggle(item.id),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(14),
                          vertical: ui(12),
                        ),
                        decoration: BoxDecoration(
                          color: item.selected
                              ? const Color(0xFFF1ECFF)
                              : const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(ui(12)),
                          border: Border.all(
                            color: item.selected
                                ? const Color(0xFF8B5CFF)
                                : const Color(0xFFE7EBF7),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded),
                            SizedBox(width: ui(10)),
                            Expanded(child: AppText(item.name)),
                            Icon(
                              item.selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item.selected
                                  ? const Color(0xFF8B5CFF)
                                  : const Color(0xFFA0A6B7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(18)),
              SizedBox(
                width: double.infinity,
                height: ui(44),
                child: FilledButton(
                  onPressed: onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const AppText('发送'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
